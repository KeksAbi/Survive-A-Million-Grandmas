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
local GunModels = require(Shared.GunModels)

local EnemyService = require(script.Parent.EnemyService)
local PlayerService = require(script.Parent.PlayerService)

local Weapons = WeaponData.Weapons

local CombatService = {}

type State = {
	Owned: { [string]: boolean },
	Equipped: string,
	Ammo: { [string]: number },
	FireCredit: { [string]: number }, -- per weapon, so swapping guns never refills a shot
	CreditTime: { [string]: number },
	SwapReadyAt: number,
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
	local owned = { [Config.Player.StartingWeapon] = true }
	if Config.Debug.GiveAllWeapons then
		for id in Weapons do
			owned[id] = true
		end
	end
	return {
		Owned = owned,
		Equipped = Config.Player.StartingWeapon,
		Ammo = ammo,
		FireCredit = {},
		CreditTime = {},
		SwapReadyAt = 0,
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

-- The gun is welded to the chest (UpperTorso), pointing where the character faces, so it never depends on
-- the avatar's arm shape. Both hands reach for it with IKControls (right hand on the grip, left hand on the
-- pump / handguard). Long guns sit at the right shoulder; the pistol is held out at arm's length.
-- Distances and the gun size follow the avatar's torso and arm size. Rebuilt on equip, skin and respawn.
local function addHandIK(humanoid: Humanoid, name: string, chainRoot: Instance?, hand: Instance?, target: Attachment?, pole: Attachment?)
	local old = humanoid:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	if not chainRoot or not hand or not target then
		return
	end
	local ik = Instance.new("IKControl")
	ik.Name = name
	ik.Type = Enum.IKControlType.Position -- position only: forcing a hand rotation twisted the arms into knots
	ik.ChainRoot = chainRoot
	ik.EndEffector = hand
	ik.Target = target
	ik.Pole = pole -- which way the elbow points
	ik.Weight = 1
	ik.Parent = humanoid
end

-- Elbow guide attachments on the torso (created once per character).
local function elbowPole(torso: BasePart, name: string, position: Vector3): Attachment
	local pole = torso:FindFirstChild(name)
	if not pole then
		pole = Instance.new("Attachment")
		pole.Name = name
		pole.Parent = torso
	end
	pole.Position = position
	return pole :: Attachment
end

-- Bladed stance for long guns: the upper body turns right (left shoulder forward, stock shoulder back),
-- the head turns back so it still looks forward. 0 = square stance (pistol). Joint C0s are restored from
-- the original values stored on the joints.
local function setStance(character: Model, twist: number)
	local upperTorso = character:FindFirstChild("UpperTorso")
	local head = character:FindFirstChild("Head")
	local waist = upperTorso and upperTorso:FindFirstChild("Waist")
	local neck = head and head:FindFirstChild("Neck")
	for _, entry in { { waist, -twist }, { neck, twist } } do
		local joint = entry[1]
		if joint and joint:IsA("Motor6D") then
			local base = joint:GetAttribute("BaseC0")
			if typeof(base) ~= "CFrame" then
				base = joint.C0
				joint:SetAttribute("BaseC0", base)
			end
			joint.C0 = base * CFrame.Angles(0, entry[2], 0)
		end
	end
end

-- R6 (blocky): blocks cannot bend, so each arm turns around the top of the shoulder and points straight at
-- its target (torso space); if the target is beyond the arm, the arm slides forward up to R6_MAX_SLIDE so the
-- hand still lands on the gun. The animated shoulder Motor6D is switched off and a fixed Weld holds the arm
-- instead, so the walk animation can never swing the gun arms.
local R6_PIVOT_TO_HAND = 1.65 -- arm turns 0.1 below its top; the hand (lower end) is ~1.65 further
local R6_MAX_SLIDE = 0.9
local function aimArmR6(torso: BasePart, jointName: string, side: number, target: Vector3)
	local motor = torso:FindFirstChild(jointName)
	if not motor or not motor:IsA("Motor6D") then
		return
	end
	local joint = torso:FindFirstChild(jointName .. " Gun")
	if not joint then
		joint = Instance.new("Weld")
		joint.Name = jointName .. " Gun"
		joint.Part0 = motor.Part0
		joint.Part1 = motor.Part1
		joint.Parent = torso
	end
	motor.Enabled = false
	local shoulder = Vector3.new(side * 1.5, 0.9, 0)
	local toTarget = target - shoulder
	if toTarget.Magnitude < 0.05 then
		return
	end
	local up = -toTarget.Unit -- the arm's +Y points back to the shoulder, its bottom (hand) to the target
	local look = Vector3.yAxis - up * Vector3.yAxis:Dot(up) -- the arm's front faces up-ish (like a raised arm)
	if look.Magnitude < 0.05 then
		look = Vector3.new(0, 0, -1)
	end
	local back = -look.Unit
	local slide = math.clamp(toTarget.Magnitude - R6_PIVOT_TO_HAND, 0, R6_MAX_SLIDE)
	joint.C0 = CFrame.new(shoulder - up * slide) * CFrame.fromMatrix(Vector3.zero, up:Cross(back), up)
	joint.C1 = CFrame.new(0, 0.9, 0)
end

local function buildGun(player: Player, state: State)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("Gun")
	if old then
		old:Destroy()
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not humanoid or not torso or not torso:IsA("BasePart") then
		return
	end

	-- avatar size: arm length (shoulder to hand) and torso size
	local upperArm = character:FindFirstChild("RightUpperArm")
	local lowerArm = character:FindFirstChild("RightLowerArm")
	local armLength = if upperArm and lowerArm then upperArm.Size.Y + lowerArm.Size.Y else 2
	local scale = Config.Combat.HeldGunScale * math.clamp(armLength / 2.2, 0.85, 1.2)
	local torsoSize = torso.Size

	local weapon = Weapons[state.Equipped]
	local gun = GunModels.Build(weapon, tostring(player:GetAttribute("Skin") or "Default"))
	local size = scale * weapon.HoldScale
	if math.abs(size - 1) > 0.02 then
		gun:ScaleTo(size)
	end
	local handle = gun:FindFirstChild("Handle") :: BasePart

	-- how far the gun reaches back behind the hand (the stock), in grip space
	local back = 0
	for _, part in gun:GetDescendants() do
		if part:IsA("BasePart") then
			local cf = part.CFrame
			local halfZ = (math.abs(cf.RightVector.Z) * part.Size.X + math.abs(cf.UpVector.Z) * part.Size.Y
				+ math.abs(cf.LookVector.Z) * part.Size.Z) / 2
			back = math.max(back, cf.Position.Z + halfZ)
		end
	end
	local twoHanded = back > 0.6

	-- everything below is in the (turned) torso's own space: the gun is welded there
	local twist = if twoHanded and torso.Name == "UpperTorso" then math.rad(Config.Combat.LongGunTwist) else 0
	setStance(character, twist)
	local gunTurn = CFrame.Angles(0, twist, 0) -- turns the gun back to the body's forward direction
	local gunLocal
	local isR6 = torso.Name == "Torso"
	if isR6 then
		-- classic blocky: long guns in front of the right half of the chest, stock end at the chest, barrel
		-- straight ahead; pistol held out in front, a bit right of center
		gunLocal = if twoHanded
			then CFrame.new(torsoSize.X * 0.18, torsoSize.Y * 0.18, -(torsoSize.Z * 0.5 + back + 0.05))
			else CFrame.new(torsoSize.X * 0.1, torsoSize.Y * 0.2, -(torsoSize.Z * 0.5 + 1.0))
	elseif twoHanded then
		-- stock end in the shoulder pocket (front of the chest, right of center), barrel forward
		local stockEnd = Vector3.new(torsoSize.X * 0.22, torsoSize.Y * 0.28, -torsoSize.Z * 0.5)
		gunLocal = CFrame.new(stockEnd + gunTurn.LookVector * back) * gunTurn
	else
		-- pistol: square two-handed stance in front of the chest, close enough that both hands surely reach
		gunLocal = CFrame.new(torsoSize.X * 0.1, torsoSize.Y * 0.25, -(torsoSize.Z * 0.5 + armLength * 0.5))
	end

	-- the left hand holds as far forward as the left arm can reach (slides back toward the grip if not)
	local leftGrip = handle:FindFirstChild("LeftGrip") :: Attachment?
	local leftUpper = character:FindFirstChild("LeftUpperArm")
	local leftLower = character:FindFirstChild("LeftLowerArm")
	local leftHand = character:FindFirstChild("LeftHand")
	local leftReach = if leftUpper and leftLower and leftHand
		then (leftUpper.Size.Y + leftLower.Size.Y + leftHand.Size.Y * 0.5) * 0.95
		elseif isR6 then R6_PIVOT_TO_HAND + R6_MAX_SLIDE
		else nil
	if leftGrip and leftReach then
		local reach = leftReach
		local shoulder = if isR6 then Vector3.new(-1.5, 0.9, 0) else Vector3.new(-torsoSize.X * 0.5, torsoSize.Y * 0.3, 0)
		local target = leftGrip.CFrame
		while target.Position.Z < -0.3 and ((gunLocal * target).Position - shoulder).Magnitude > reach do
			target = target + Vector3.new(0, 0, 0.05)
		end
		leftGrip.CFrame = target
	end

	for _, part in gun:GetDescendants() do
		if part:IsA("BasePart") then
			local weld = Instance.new("Weld")
			weld.Part0 = torso
			weld.Part1 = part
			weld.C0 = gunLocal * part.CFrame -- the model was built around the grip at the origin
			weld.Parent = part
			part.CFrame = torso.CFrame * weld.C0
		end
	end
	gun.Parent = character

	-- elbows: right one out to the side and down, left one down under the gun
	local rightPole = elbowPole(torso, "RightElbowPole", Vector3.new(torsoSize.X * 1.4, -torsoSize.Y * 0.6, 0.4))
	local leftPole = elbowPole(torso, "LeftElbowPole", Vector3.new(-torsoSize.X * 0.3, -torsoSize.Y * 1.4, -0.6))
	addHandIK(humanoid, "RightHandIK", upperArm, character:FindFirstChild("RightHand"), handle:FindFirstChild("RightGrip"), rightPole)
	addHandIK(humanoid, "LeftHandIK", leftUpper, leftHand, leftGrip, leftPole)

	if isR6 then
		local rightGrip = handle:FindFirstChild("RightGrip") :: Attachment?
		if rightGrip then
			aimArmR6(torso, "Right Shoulder", 1, (gunLocal * rightGrip.CFrame).Position)
		end
		if leftGrip then
			aimArmR6(torso, "Left Shoulder", -1, (gunLocal * leftGrip.CFrame).Position)
		end
	end
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

-- Shot budget: refills 1 per FireCooldown, capped at FireBurstAllowance. Spends 1 per shot.
-- Caps the average fire rate while accepting shots that arrive bunched together.
local function takeShotCredit(state: State, weaponId: string, cooldown: number, now: number): boolean
	local last = state.CreditTime[weaponId]
	local stored = state.FireCredit[weaponId] or Config.Combat.FireBurstAllowance
	local credit = if last then math.min(Config.Combat.FireBurstAllowance, stored + (now - last) / cooldown) else stored
	state.CreditTime[weaponId] = now
	if credit < 1 then
		state.FireCredit[weaponId] = credit
		return false
	end
	state.FireCredit[weaponId] = credit - 1
	return true
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

-- Casts every pellet of one shot along `aim`. Returns damage and hit point per enemy, and where pellet 1
-- stopped. With `onlyEnemyId` set, only pellets hitting that enemy count.
local function castPellets(weapon: WeaponData.WeaponDefinition, origin: Vector3, aim: Vector3, onlyEnemyId: number?)
	local params = getRayParams()
	local backOffset = Config.Combat.RayBackOffset
	local damageByEnemy: { [number]: number } = {}
	local hitPosition: { [number]: Vector3 } = {}
	local firstEnd: Vector3? = nil
	for pellet = 1, weapon.Pellets do
		local dir = WeaponData.PelletDirection(aim, weapon, pellet)
		-- start behind the muzzle so a grandma pressed against the gun is still hit
		local rayStart = origin - dir * backOffset
		local result = workspace:Raycast(rayStart, dir * (weapon.Range + backOffset), params)
		local endPosition = if result then result.Position else origin + dir * weapon.Range
		firstEnd = firstEnd or endPosition
		local enemyId = if result then EnemyService.GetEnemyIdFromInstance(result.Instance) else nil
		local position = endPosition
		if not enemyId then
			-- near miss: forgive small lag offsets (stops at walls/ground the ray already hit)
			local maxDistance = if result then result.Distance else weapon.Range + backOffset
			enemyId, position = EnemyService.FindEnemyNearRay(rayStart, dir, maxDistance, Config.Combat.HitTolerance)
		end
		if enemyId and (onlyEnemyId == nil or enemyId == onlyEnemyId) then
			damageByEnemy[enemyId] = (damageByEnemy[enemyId] or 0) + weapon.Damage
			hitPosition[enemyId] = position
		end
	end
	return damageByEnemy, hitPosition, firstEnd
end

local mapParams = RaycastParams.new()
mapParams.FilterType = Enum.RaycastFilterType.Include

-- "Favor the shooter": the client says which enemy was under its crosshair. Accept it only if that enemy
-- is alive, in range, in front, close to the shot line (ClaimTolerance) and not hidden behind the map.
local function validateClaim(enemyId: number, eye: Vector3, origin: Vector3, aim: Vector3, range: number): (boolean, Vector3?)
	local enemy = EnemyService.Get(enemyId)
	if not enemy or not enemy.Alive then
		return false, nil
	end
	local def = enemy.Def
	local center = enemy.Position + Vector3.new(0, def.RootHeight, 0)
	local toEnemy = center - origin
	if toEnemy.Magnitude > range + def.Radius + 5 then
		return false, nil
	end
	local t = toEnemy:Dot(aim)
	if t <= 0 then
		return false, nil
	end
	local offset = center - (origin + aim * t)
	local flat = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
	local tolerance = Config.Combat.ClaimTolerance
	if flat > def.Radius + tolerance or math.abs(offset.Y) > def.RootHeight * 1.25 + tolerance then
		return false, nil
	end
	local map = workspace:FindFirstChild("Map")
	if map then
		mapParams.FilterDescendantsInstances = { map }
		local toCenter = center - eye
		local blocked = workspace:Raycast(eye, toCenter, mapParams)
		if blocked and blocked.Distance < toCenter.Magnitude - (def.Radius + 1) then
			return false, nil
		end
	end
	return true, origin + aim * t
end

-- Why a shot was thrown away, in Output (at most once per 2 s per player), to find wrong rejections.
local lastRejectWarn: { [Player]: number } = {}
local function reject(player: Player, reason: string)
	local now = os.clock()
	if now - (lastRejectWarn[player] or 0) >= 2 then
		lastRejectWarn[player] = now
		warn("[CombatService] shot from " .. player.Name .. " rejected: " .. reason)
	end
end

local function onFire(player: Player, origin: any, direction: any, aimedEnemyId: any)
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
	if not head then
		return
	end
	local originDistance = (origin - head.Position).Magnitude
	if originDistance > Config.Combat.MaxShotOriginDistance then
		reject(player, string.format("gun muzzle %.1f studs from the head (max %d)", originDistance, Config.Combat.MaxShotOriginDistance))
		return
	end
	-- the muzzle may not be on the other side of a wall or under the floor (shooting from cover): then the
	-- shot starts at the head instead, which is always on the player's side
	local map = workspace:FindFirstChild("Map")
	if map then
		mapParams.FilterDescendantsInstances = { map }
		local blocked = workspace:Raycast(head.Position, origin - head.Position, mapParams)
		if blocked and blocked.Instance.CanCollide and blocked.Instance.Transparency < 1 then
			local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
			reject(player, string.format("muzzle behind %s, shooting from the head instead (head y %.1f, muzzle %s, hand %s)",
				blocked.Instance.Name, head.Position.Y, tostring(origin), if hand then tostring(hand.Position) else "?"))
			origin = head.Position
		end
	end

	local weapon = Weapons[state.Equipped]
	local now = os.clock()
	if state.Reloading or now < state.SwapReadyAt then
		return
	end
	if state.Ammo[weapon.Id] <= 0 then
		startReload(player, state)
		return
	end
	if not takeShotCredit(state, weapon.Id, weapon.FireCooldown, now) then
		reject(player, "faster than the fire rate of " .. weapon.Id)
		return
	end
	state.Ammo[weapon.Id] -= 1

	-- hit detection: one ray per pellet, damage summed per enemy
	local aim = direction.Unit
	local damageByEnemy, hitPosition, firstEnd = castPellets(weapon, origin, aim, nil)

	-- the enemy under the client's crosshair was missed on the server (it moved a bit on the server's side):
	-- if the claim checks out, re-fire the same pellet pattern at where the server has that enemy, so a
	-- shotgun blast that hit on screen deals its full pellet damage instead of a single pellet
	if typeof(aimedEnemyId) == "number" and not damageByEnemy[aimedEnemyId] then
		local valid, position = validateClaim(aimedEnemyId, head.Position, origin, aim, weapon.Range)
		local enemy = valid and EnemyService.Get(aimedEnemyId)
		if enemy and position then
			local corrected = (enemy.Position + Vector3.new(0, enemy.Def.RootHeight, 0) - origin).Unit
			-- only pellets that really reach her count (another grandma in front blocks them)
			local claimed, claimedPosition = castPellets(weapon, origin, corrected, aimedEnemyId)
			if claimed[aimedEnemyId] then
				damageByEnemy[aimedEnemyId] = claimed[aimedEnemyId]
				hitPosition[aimedEnemyId] = claimedPosition[aimedEnemyId] or position
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

local function equip(player: Player, state: State, weaponId: string)
	if not Weapons[weaponId] or not state.Owned[weaponId] or state.Equipped == weaponId then
		return
	end
	cancelReload(state)
	state.Equipped = weaponId
	state.SwapReadyAt = os.clock() + Config.Combat.SwapDelay
	publish(player, state)
	buildGun(player, state)
end

local function onEquip(player: Player, weaponId: any)
	local state = states[player]
	if not state or typeof(weaponId) ~= "string" or not allowRemote(state) then
		return
	end
	equip(player, state, weaponId)
end

-- Switches to an owned weapon (used by the shop right after a purchase).
function CombatService.EquipWeapon(player: Player, weaponId: string)
	equip(player, getState(player), weaponId)
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

-- Rebuilds the held gun (after a skin change).
function CombatService.RefreshGun(player: Player)
	local state = states[player]
	if state then
		buildGun(player, state)
	end
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
		lastRejectWarn[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		getState(player)
	end
end

return CombatService
