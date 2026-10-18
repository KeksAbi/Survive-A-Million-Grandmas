--!nonstrict
-- Character setup (health, spawn protection), spawning and "who is alive" queries.
-- Roblox auto-respawn is OFF: WaveService decides when players (re)spawn. Dead players stay dead
-- until the wave ends; players joining mid-wave wait (and spectate) until the next wave.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local PlayerService = {}

PlayerService.CharacterSpawned = Signal.new() -- (player, character)
PlayerService.PlayerDied = Signal.new() -- (player)
PlayerService.PlayerJoined = Signal.new() -- (player, spawnedNow: boolean)

-- Set by WaveService: may a player who just joined spawn right away?
PlayerService.CanSpawnOnJoin = function(): boolean
	return true
end

export type LivingPlayer = { Player: Player, Character: Model, Root: BasePart, Humanoid: Humanoid }

local warnedR15 = false

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	if Config.Player.BasicBody then
		-- classic blocky body: R6 body packages are meshes on the blocks; without them everyone is blocky
		for _, child in character:GetChildren() do
			if child:IsA("CharacterMesh") then
				child:Destroy()
			end
		end
		character.ChildAdded:Connect(function(child)
			if child:IsA("CharacterMesh") then
				task.defer(child.Destroy, child) -- the appearance can arrive a moment later
			end
		end)
		if humanoid.RigType == Enum.HumanoidRigType.R15 and not warnedR15 then
			warnedR15 = true
			warn("[PlayerService] BasicBody: " .. player.Name .. " spawned as R15 (the blocky R6 build failed, see above)")
		end
	end

	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth
	humanoid.WalkSpeed = Config.Player.WalkSpeed

	-- Invisible ForceField = short spawn invulnerability (Humanoid:TakeDamage is ignored while it exists).
	local shield = Instance.new("ForceField")
	shield.Visible = false
	shield.Parent = character
	Debris:AddItem(shield, Config.Player.SpawnInvulnerability)

	player:SetAttribute("Alive", true)
	humanoid.Died:Once(function()
		player:SetAttribute("Alive", false)
		PlayerService.PlayerDied:Fire(player)
	end)

	PlayerService.CharacterSpawned:Fire(player, character)
end

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local spawning: { [Player]: boolean } = {}
local descriptions: { [Player]: HumanoidDescription } = {}

local function fetchDescription(player: Player): HumanoidDescription?
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(math.max(player.UserId, 1))
		end)
		if ok and result then
			return result
		end
		warn("[PlayerService] could not load the avatar of " .. player.Name .. " (try " .. attempt .. "): " .. tostring(result))
		task.wait(attempt)
	end
	return nil
end

-- The player's own look (clothes, accessories, colors, face) at standard proportions. If it cannot be
-- loaded, the default look is used.
local function basicDescription(player: Player): HumanoidDescription
	if descriptions[player] then
		return descriptions[player]
	end
	local own = fetchDescription(player)
	local final = own or Instance.new("HumanoidDescription")
	for _, field in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
		final[field] = 0
	end
	final.HeightScale = 1
	final.WidthScale = 1
	final.DepthScale = 1
	final.HeadScale = 1
	final.BodyTypeScale = 0
	final.ProportionScale = 0
	if own then
		descriptions[player] = final -- the plain fallback is not cached: the next spawn tries again
	end
	return final
end

-- Invisible damage shield for every living player (boss cutscene).
function PlayerService.ShieldAll(seconds: number)
	for _, entry in PlayerService.GetLivingPlayers() do
		local shield = Instance.new("ForceField")
		shield.Visible = false
		shield.Parent = entry.Character
		Debris:AddItem(shield, seconds)
	end
end

-- Spawns (or respawns) one player. Yields until the character exists. Ignored if already spawning.
-- Where characters appear: the map's PlayerSpawn pad (a little spread out), else near the park center.
local function spawnCFrame(): CFrame
	local map = workspace:FindFirstChild("Map")
	local pad = map and map:FindFirstChild("PlayerSpawn")
	local base = if pad and pad:IsA("BasePart") then pad.CFrame else CFrame.new(0, 0.5, 26)
	return base * CFrame.new(math.random(-40, 40) / 10, 3.5, math.random(-40, 40) / 10)
end

-- Classic blocky R6 character built from the player's look, whatever avatar type the game is set to.
-- Falls back to the normal spawn if Roblox cannot build it.
local function spawnBlocky(player: Player)
	local description = basicDescription(player):Clone()
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		warn("[PlayerService] could not build the blocky character for " .. player.Name .. ": " .. tostring(model))
		player:LoadCharacter()
		return
	end
	model.Name = player.Name
	for _, child in model:GetDescendants() do
		if child:IsA("CharacterMesh") then
			child:Destroy() -- body packages: without them every R6 body is plain blocks
		end
	end
	model:PivotTo(spawnCFrame())
	local old = player.Character
	player.Character = model
	model.Parent = workspace
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		pcall(root.SetNetworkOwner, root, player) -- the player's own client moves it, like a normal character
	end
	if old and old ~= model then
		old:Destroy()
	end
end

function PlayerService.Spawn(player: Player)
	if player.Parent ~= Players or spawning[player] then
		return
	end
	spawning[player] = true
	local ok, err = pcall(function()
		if Config.Player.BasicBody then
			spawnBlocky(player)
		else
			player:LoadCharacter()
		end
	end)
	spawning[player] = nil
	if not ok then
		warn("[PlayerService] LoadCharacter failed for", player.Name, err)
	end
end

-- Between waves: respawn everyone who is dead or never spawned, fully heal everyone alive.
-- Spawns run in parallel; returns when all are done (or after 5 s).
function PlayerService.RespawnAndHealAll()
	local pending = 0
	for _, player in Players:GetPlayers() do
		if spawning[player] then
			continue -- already on the way
		elseif isAlive(player) then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			humanoid.Health = humanoid.MaxHealth
		else
			pending += 1
			task.spawn(function()
				PlayerService.Spawn(player)
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + 5
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("Alive", false)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	local spawnNow = not player.Character and PlayerService.CanSpawnOnJoin()
	if spawnNow then
		task.spawn(PlayerService.Spawn, player)
	end
	PlayerService.PlayerJoined:Fire(player, spawnNow or player.Character ~= nil)
end

function PlayerService.Init()
	Players.CharacterAutoLoads = false
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		descriptions[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

-- Snapshot of every player with a live character. Called once per enemy AI tick.
function PlayerService.GetLivingPlayers(): { LivingPlayer }
	local result = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			table.insert(result, { Player = player, Character = character, Root = root, Humanoid = humanoid })
		end
	end
	return result
end

return PlayerService
