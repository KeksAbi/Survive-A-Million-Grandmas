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

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
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

-- The player's own look on the basic body: body parts and body scales reset to the standard blocky R15,
-- clothes, accessories, colors and face kept. nil if Roblox could not load it (then the normal avatar is used).
local function basicDescription(player: Player): HumanoidDescription?
	if descriptions[player] then
		return descriptions[player]
	end
	local ok, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(math.max(player.UserId, 1))
	end)
	if not ok or not description then
		warn("[PlayerService] could not load the avatar of " .. player.Name .. ": " .. tostring(description))
		return nil
	end
	for _, field in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
		description[field] = 0
	end
	description.HeightScale = 1
	description.WidthScale = 1
	description.DepthScale = 1
	description.HeadScale = 1
	description.BodyTypeScale = 0
	description.ProportionScale = 0
	descriptions[player] = description
	return description
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
function PlayerService.Spawn(player: Player)
	if player.Parent ~= Players or spawning[player] then
		return
	end
	spawning[player] = true
	local description = if Config.Player.BasicBody then basicDescription(player) else nil
	local ok, err = pcall(function()
		if description then
			player:LoadCharacterWithHumanoidDescription(description:Clone())
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
