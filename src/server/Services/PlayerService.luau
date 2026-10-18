--!nonstrict
-- Character setup (health, spawn protection) and "who is alive" queries for the other services.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)

local PlayerService = {}

PlayerService.CharacterSpawned = Signal.new() -- (player, character)
PlayerService.PlayerDied = Signal.new() -- (player)

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

local function onPlayerAdded(player: Player)
	player:SetAttribute("Alive", false)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function PlayerService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
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
