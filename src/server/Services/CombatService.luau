--!nonstrict
-- Server-authoritative shooting. The client only sends "I fired from here in this direction".
-- The server owns weapon ownership, equipped weapon, ammo, fire rate, reloads, hit detection and damage.
-- Replicated to the client as player attributes: Weapon, Ammo, MagSize, Reloading, Owns<WeaponId>.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local WeaponData = require(Shared.WeaponDefinitions)

local EnemyService = require(script.Parent.EnemyService)
local PlayerService = require(script.Parent.PlayerService)

local Weapons = WeaponData.Weapons

local CombatService = {}

type State = {
	Owned: { [string]: boolean },
	Equipped: string,
	Ammo: { [string]: number },
	NextFire: number,
	Reloading: boolean,
	ReloadToken: number,
	WindowStart: number,
	WindowCount: number,
}

local states: { [Player]: State } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function publish(player: Player, state: State)
	local weapon = Weapons[state.Equipped]
	player:SetAttribute("Weapon", state.Equipped)
	player:SetAttribute("Ammo", state.Ammo[state.Equipped])
	player:SetAttribute("MagSize", weapon.MagSize)
	player:SetAttribute("Reloading", state.Reloading)
	for id in Weapons do
		player:SetAttribute("Owns" .. id, state.Owned[id] == true)
	end
end

local function newState(): State
	local ammo = {}
	for id, weapon in Weapons do
		ammo[id] = weapon.MagSize
	end
	return {
		Owned = { [Config.Player.StartingWeapon] = true },
		Equipped = Config.Player.StartingWeapon,
		Ammo = ammo,
		NextFire = 0,
		Reloading = false,
		ReloadToken = 0,
		WindowStart = 0,
		WindowCount = 0,
	}
end

local function getState(player: Player): State
	local state = states[player]
	if not state then
		state = newState()
		states[player] = state
		publish(player, state)
	end
	return state
end

-- Simple per-player remote budget (all combat remotes share it).
local function allowRemote(state: State): boolean
	local now = os.clock()
	if now - state.WindowStart >= 1 then
		state.WindowStart = now
		state.WindowCount = 0
	end
	state.WindowCount += 1
	return state.WindowCount <= Config.Combat.MaxRemotesPerSecond
end

local function isFinite(v: Vector3): boolean
	local m = v.Magnitude
	return m == m and m < 1e6
end

local function getLiveCharacter(player: Player): (Model?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return character, humanoid
	end
	return nil, nil
end

-- Placeholder gun built from parts, welded to the right hand. Rebuilt on equip and respawn.
local function buildGun(player: Player, state: State)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("Gun")
	if old then
		old:Destroy()
	end

	local hand = character:FindFirstChild("RightHand")
	local handOffset = CFrame.new(0, -0.15, -0.45)
	if not hand then
		hand = character:FindFirstChild("Right Arm") -- R6 fallback
		handOffset = CFrame.new(0, -1.05, -0.45)
	end
	if not hand then
		return
	end

	local look = Weapons[state.Equipped].Look
	local gun = Instance.new("Model")
	gun.Name = "Gun"

	local function gunPart(name: string, size: Vector3, offset: CFrame, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		local weld = Instance.new("Weld")
		weld.Part0 = hand
		weld.Part1 = part
		weld.C0 = handOffset * offset
		weld.Parent = part
		part.CFrame = hand.CFrame * weld.C0
		part.Parent = gun
		return part
	end

	local size = look.Size
	local handle = gunPart("Handle", size, CFrame.new(0, 0, -size.Z / 2 + 0.3), look.BodyColor)
	gunPart("Accent", Vector3.new(size.X + 0.04, size.Y * 0.35, size.Z * 0.45), CFrame.new(0, -size.Y * 0.1, -size.Z / 2 + 0.3), look.AccentColor)
	gunPart("Grip", Vector3.new(size.X * 0.9, 0.55, 0.3), CFrame.new(0, -size.Y / 2 - 0.2, 0.1), look.BodyColor)

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, size.Y * 0.2, -size.Z / 2)
	muzzle.Parent = handle

	gun.PrimaryPart = handle
	gun.Parent = character
end

local function cancelReload(state: State)
	state.ReloadToken += 1
	state.Reloading = false
end

local function startReload(player: Player, state: State)
	local weapon = Weapons[state.Equipped]
	if state.Reloading or state.Ammo[weapon.Id] >= weapon.MagSize then
		return
	end
	state.Reloading = true
	state.ReloadToken += 1
	local token = state.ReloadToken
	publish(player, state)
	task.delay(weapon.ReloadTime, function()
		if states[player] ~= state or state.ReloadToken ~= token then
			return -- cancelled (weapon switch, respawn, left)
		end
		state.Ammo[weapon.Id] = weapon.MagSize
		state.Reloading = false
		publish(player, state)
	end)
end

local function getRayParams(): RaycastParams
	local include = { EnemyService.Folder }
	local map = workspace:FindFirstChild("Map")
	if map then
		table.insert(include, map)
	end
	rayParams.FilterDescendantsInstances = include
	return rayParams
end

-- Random direction inside a cone of `degrees` around `direction`.
local function spreadDirection(direction: Vector3, degrees: number): Vector3
	if degrees <= 0 then
		return direction
	end
	local angle = math.rad(degrees) * math.sqrt(math.random())
	local roll = math.random() * math.pi * 2
	return (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

local function onFire(player: Player, origin: any, direction: any)
	local state = states[player]
	if not state or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if not isFinite(origin) or not isFinite(direction) or direction.Magnitude < 0.1 then
		return
	end
	if not allowRemote(state) then
		return
	end
	local character = getLiveCharacter(player)
	local head = character and character:FindFirstChild("Head")
	if not head or (origin - head.Position).Magnitude > Config.Combat.MaxShotOriginDistance then
		return
	end

	local weapon = Weapons[state.Equipped]
	local now = os.clock()
	if state.Reloading or now < state.NextFire - Config.Combat.FireToleranceSeconds then
		return
	end
	if state.Ammo[weapon.Id] <= 0 then
		startReload(player, state)
		return
	end
	state.NextFire = now + weapon.FireCooldown
	state.Ammo[weapon.Id] -= 1

	-- hit detection: one ray per pellet, damage summed per enemy
	local params = getRayParams()
	local aim = direction.Unit
	local damageByEnemy: { [number]: number } = {}
	local hitPosition: { [number]: Vector3 } = {}
	local firstEnd: Vector3? = nil
	for _ = 1, weapon.Pellets do
		local dir = spreadDirection(aim, weapon.SpreadDegrees)
		local result = workspace:Raycast(origin, dir * weapon.Range, params)
		local endPosition = if result then result.Position else origin + dir * weapon.Range
		firstEnd = firstEnd or endPosition
		if result then
			local enemyId = EnemyService.GetEnemyIdFromInstance(result.Instance)
			if enemyId then
				damageByEnemy[enemyId] = (damageByEnemy[enemyId] or 0) + weapon.Damage
				hitPosition[enemyId] = result.Position
			end
		end
	end

	local feedback = Remotes.Get("HitFeedback")
	for enemyId, damage in damageByEnemy do
		local hit, killed = EnemyService.Damage(enemyId, damage, player)
		if hit then
			feedback:FireClient(player, hitPosition[enemyId], damage, killed)
		end
	end

	-- tracer for everyone else (the shooter already drew its own)
	local shotFx = Remotes.Get("ShotFx")
	for _, other in Players:GetPlayers() do
		if other ~= player then
			shotFx:FireClient(other, player.UserId, weapon.Id, origin, firstEnd)
		end
	end

	if state.Ammo[weapon.Id] <= 0 then
		startReload(player, state)
	else
		publish(player, state)
	end
end

local function onReload(player: Player)
	local state = states[player]
	if not state or not allowRemote(state) or not getLiveCharacter(player) then
		return
	end
	startReload(player, state)
end

local function onEquip(player: Player, weaponId: any)
	local state = states[player]
	if not state or typeof(weaponId) ~= "string" or not allowRemote(state) then
		return
	end
	if not Weapons[weaponId] or not state.Owned[weaponId] or state.Equipped == weaponId then
		return
	end
	cancelReload(state)
	state.Equipped = weaponId
	state.NextFire = math.max(state.NextFire, os.clock() + 0.2) -- small swap delay
	publish(player, state)
	buildGun(player, state)
end

-- Gives a weapon (used by the shop). Returns false if already owned.
function CombatService.GrantWeapon(player: Player, weaponId: string): boolean
	local state = getState(player)
	if not Weapons[weaponId] or state.Owned[weaponId] then
		return false
	end
	state.Owned[weaponId] = true
	publish(player, state)
	return true
end

function CombatService.OwnsWeapon(player: Player, weaponId: string): boolean
	local state = states[player]
	return state ~= nil and state.Owned[weaponId] == true
end

-- New match: back to the starting weapon only.
function CombatService.ResetLoadout(player: Player)
	local state = states[player]
	if state then
		cancelReload(state)
	end
	state = newState()
	states[player] = state
	publish(player, state)
	buildGun(player, state)
end

function CombatService.Init()
	Remotes.Get("Fire").OnServerEvent:Connect(onFire)
	Remotes.Get("Reload").OnServerEvent:Connect(onReload)
	Remotes.Get("Equip").OnServerEvent:Connect(onEquip)

	PlayerService.CharacterSpawned:Connect(function(player: Player)
		local state = getState(player)
		cancelReload(state)
		for id, weapon in Weapons do
			state.Ammo[id] = weapon.MagSize
		end
		publish(player, state)
		buildGun(player, state)
	end)

	Players.PlayerAdded:Connect(getState)
	Players.PlayerRemoving:Connect(function(player)
		local state = states[player]
		if state then
			cancelReload(state)
		end
		states[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		getState(player)
	end
end

return CombatService
