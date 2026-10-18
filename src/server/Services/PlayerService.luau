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

local BODY_PARTS = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }
local BODY_SCALES = { "HeightScale", "WidthScale", "DepthScale", "HeadScale", "BodyTypeScale", "ProportionScale" }

local function fetchDescription(userId: number, label: string): HumanoidDescription?
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(math.max(userId, 1))
		end)
		if ok and result then
			return result
		end
		warn("[PlayerService] could not load the avatar of " .. label .. " (try " .. attempt .. "): " .. tostring(result))
		task.wait(attempt)
	end
	return nil
end

-- The shared body: body parts and proportions of Config.Player.BodyFromUserId (0 = the place owner).
local bodyTemplate: HumanoidDescription? = nil
local function getBodyTemplate(): HumanoidDescription?
	if bodyTemplate then
		return bodyTemplate
	end
	local userId = Config.Player.BodyFromUserId
	if userId == 0 and game.CreatorType == Enum.CreatorType.User then
		userId = game.CreatorId
	end
	if userId <= 0 then
		return nil
	end
	bodyTemplate = fetchDescription(userId, "the body template (user " .. userId .. ")")
	return bodyTemplate
end

-- The player's own look (clothes, accessories, colors, face) on the shared body. If a look cannot be
-- loaded the default look is used, so nobody ever spawns with a custom body.
local function basicDescription(player: Player): HumanoidDescription
	if descriptions[player] then
		return descriptions[player]
	end
	local own = fetchDescription(player.UserId, player.Name)
	local final = own or Instance.new("HumanoidDescription")
	local template = getBodyTemplate()
	for _, field in BODY_PARTS do
		final[field] = if template then template[field] else 0
	end
	for _, field in BODY_SCALES do
		final[field] = if template then template[field] elseif field == "BodyTypeScale" or field == "ProportionScale" then 0 else 1
	end
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
