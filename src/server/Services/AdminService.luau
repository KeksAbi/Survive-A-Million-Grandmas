--!nonstrict
-- Admin panel requests (testing tools: jump to a wave, skip, cash, all guns, kill all, heal).
-- Admins: Config.Admin.UserIds, the place owner, and everyone in a Studio playtest. Replicated as the
-- player attribute `Admin` (the client only shows the panel); every request is checked again here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local WeaponData = require(Shared.WeaponDefinitions)

local CombatService = require(script.Parent.CombatService)
local EconomyService = require(script.Parent.EconomyService)
local EnemyService = require(script.Parent.EnemyService)
local PlayerService = require(script.Parent.PlayerService)
local WaveService = require(script.Parent.WaveService)

local AdminService = {}

local ADMIN_COOLDOWN = 0.25
local lastRequest: { [Player]: number } = {}

local function isAdmin(player: Player): boolean
	local admin = Config.Admin
	if admin.AllowInStudio and RunService:IsStudio() then
		return true
	end
	if admin.AllowPlaceOwner and game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return table.find(admin.UserIds, player.UserId) ~= nil
end

local function notify(player: Player, text: string, kind: string)
	Remotes.Get("Notify"):FireClient(player, text, kind)
end

local ACTIONS = {
	JumpToWave = function(player: Player, value: any)
		if typeof(value) ~= "number" or value ~= value then
			return
		end
		if WaveService.JumpToWave(value) then
			notify(player, "ADMIN: JUMPING TO WAVE " .. math.floor(value), "info")
		end
	end,
	SkipWave = function(player: Player)
		if WaveService.SkipWave() then
			notify(player, "ADMIN: WAVE SKIPPED", "info")
		end
	end,
	SkipCountdown = function()
		WaveService.SkipCountdown()
	end,
	AddCash = function(player: Player)
		EconomyService.AddCash(player, Config.Admin.CashAmount)
	end,
	GiveWeapons = function(player: Player)
		for _, weaponId in WeaponData.Order do
			CombatService.GrantWeapon(player, weaponId)
		end
	end,
	KillAll = function(player: Player)
		for _, id in EnemyService.GetAliveIds() do
			EnemyService.Damage(id, math.huge, player)
		end
	end,
	Heal = function()
		PlayerService.RespawnAndHealAll()
	end,
}

local function onAdmin(player: Player, action: any, value: any)
	if typeof(action) ~= "string" or not ACTIONS[action] or not isAdmin(player) then
		return
	end
	local now = os.clock()
	if now - (lastRequest[player] or 0) < ADMIN_COOLDOWN then
		return
	end
	lastRequest[player] = now
	task.spawn(ACTIONS[action], player, value)
end

function AdminService.Init()
	local function setup(player: Player)
		player:SetAttribute("Admin", isAdmin(player))
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
	Remotes.Get("Admin").OnServerEvent:Connect(onAdmin)
end

return AdminService
