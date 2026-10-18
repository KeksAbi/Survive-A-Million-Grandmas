--!nonstrict
-- Match shop: weapons (WeaponDefinitions.Cost) and grenades (Config.Grenade.Cost).
-- The client sends only the item id; price, ownership, cash and limits are all checked here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local WeaponData = require(Shared.WeaponDefinitions)

local CombatService = require(script.Parent.CombatService)
local EconomyService = require(script.Parent.EconomyService)
local GrenadeService = require(script.Parent.GrenadeService)

local ShopService = {}

local MIN_INTERVAL = 0.15 -- seconds between purchase requests per player
local lastRequest: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string)
	Remotes.Get("Notify"):FireClient(player, text, kind)
end

local function onPurchase(player: Player, itemId: any)
	if typeof(itemId) ~= "string" then
		return
	end
	local now = os.clock()
	if now - (lastRequest[player] or 0) < MIN_INTERVAL then
		return
	end
	lastRequest[player] = now

	if itemId == "Grenade" then
		if GrenadeService.GetCount(player) >= Config.Grenade.MaxCarried then
			notify(player, "GRENADE BAG FULL!", "bad")
		elseif not EconomyService.TrySpend(player, Config.Grenade.Cost) then
			notify(player, "NOT ENOUGH CASH!", "bad")
		else
			GrenadeService.Add(player)
		end
		return
	end

	local weapon = WeaponData.Weapons[itemId]
	if not weapon then
		return
	end
	if CombatService.OwnsWeapon(player, itemId) then
		CombatService.EquipWeapon(player, itemId)
		return
	end
	if not EconomyService.TrySpend(player, weapon.Cost) then
		notify(player, "NOT ENOUGH CASH! " .. string.upper(weapon.Name) .. " COSTS $" .. weapon.Cost, "bad")
		return
	end
	CombatService.GrantWeapon(player, itemId)
	CombatService.EquipWeapon(player, itemId)
	notify(player, string.upper(weapon.Name) .. " UNLOCKED!", "good")
end

function ShopService.Init()
	Remotes.Get("Purchase").OnServerEvent:Connect(onPurchase)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ShopService
