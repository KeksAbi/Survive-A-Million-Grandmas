--!nonstrict
-- Cash is owned by the server. Clients only read the "Cash" player attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local EconomyService = {}

local cash: { [Player]: number } = {}
local earned: { [Player]: number } = {}

local function publish(player: Player)
	player:SetAttribute("Cash", cash[player] or 0)
end

-- Starts a fresh match balance for the player.
function EconomyService.Reset(player: Player)
	cash[player] = Config.Player.StartingCash
	earned[player] = 0
	publish(player)
end

function EconomyService.GetCash(player: Player): number
	return cash[player] or 0
end

function EconomyService.GetEarned(player: Player): number
	return earned[player] or 0
end

-- Adds a reward. A "CashMultiplier" player attribute (set by PurchaseService for the 2x gamepass) scales it.
function EconomyService.AddCash(player: Player, amount: number)
	if cash[player] == nil or amount <= 0 then
		return
	end
	local multiplier = player:GetAttribute("CashMultiplier") or 1
	local final = math.floor(amount * multiplier + 0.5)
	cash[player] += final
	earned[player] += final
	publish(player)
end

-- Returns true and deducts if the player can afford it. All purchases go through this.
function EconomyService.TrySpend(player: Player, amount: number): boolean
	local balance = cash[player]
	if balance == nil or amount < 0 or balance < amount then
		return false
	end
	cash[player] = balance - amount
	publish(player)
	return true
end

function EconomyService.Init()
	Players.PlayerAdded:Connect(EconomyService.Reset)
	Players.PlayerRemoving:Connect(function(player)
		cash[player] = nil
		earned[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		EconomyService.Reset(player)
	end
end

return EconomyService
