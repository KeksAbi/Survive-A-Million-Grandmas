--!nonstrict
-- Gamepasses, the Revive developer product and gun skins. Only official MarketplaceService APIs.
-- Ids live in Config.Monetization (0 = not set up yet: the pass is simply never owned).
--   Passes: ownership checked on join (UserOwnsGamePassAsync) and on PromptGamePassPurchaseFinished.
--     DoubleCash -> player attribute CashMultiplier = 2 (EconomyService applies it to kill rewards).
--     VIP        -> VIP name tag, golden gun skin, golden sparkles.
--     SkinPack   -> the skins in SkinDefinitions that require it.
--   Revive product: ProcessReceipt stores one revive credit through DataService (granted exactly once),
--     then uses it at once if the buyer is dead during a wave. UseRevive spends a credit later.
-- Replicates player attributes Pass<Key> (true/false), Skin, RevivedWave.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local SkinData = require(Shared.SkinDefinitions)

local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)

local PurchaseService = {}

local Monetization = Config.Monetization
local revivedWave: { [Player]: number } = {} -- wave number of the last revive (RevivesPerWave)
local reviveUses: { [Player]: number } = {}
local lastRequest: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string)
	Remotes.Get("Notify"):FireClient(player, text, kind)
end

local function ownsPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass" .. key) == true
end

local function canUseSkin(player: Player, skinId: string): boolean
	local skin = SkinData.Skins[skinId]
	return skin ~= nil and (skin.Requires == nil or ownsPass(player, skin.Requires))
end

-- VIP look on the character: name tag over the head and a few golden sparkles.
local function applyVipLook(player: Player, character: Model)
	if not ownsPass(player, "VIP") or character:FindFirstChild("VipTag", true) then
		return
	end
	local head = character:FindFirstChild("Head")
	if head then
		local tag = Instance.new("BillboardGui")
		tag.Name = "VipTag"
		tag.Size = UDim2.fromOffset(70, 26)
		tag.StudsOffset = Vector3.new(0, 2.4, 0)
		tag.AlwaysOnTop = false
		tag.MaxDistance = 80
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(255, 196, 40)
		label.Font = Enum.Font.GothamBlack
		label.Text = "VIP"
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(30, 22, 0)
		label.Parent = tag
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
		tag.Parent = head
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 210, 60)
		sparkles.TimeScale = 0.6
		sparkles.Parent = root
	end
end

local function setSkin(player: Player, skinId: string)
	if player:GetAttribute("Skin") ~= skinId then
		player:SetAttribute("Skin", skinId)
		CombatService.RefreshGun(player)
	end
end

local function grantPass(player: Player, key: string, justBought: boolean)
	if ownsPass(player, key) then
		return
	end
	player:SetAttribute("Pass" .. key, true)
	if key == "DoubleCash" then
		player:SetAttribute("CashMultiplier", 2)
	elseif key == "VIP" then
		setSkin(player, "Gold")
		if player.Character then
			applyVipLook(player, player.Character)
		end
	elseif key == "SkinPack" and justBought then
		setSkin(player, "Candy")
	end
	if justBought then
		notify(player, "THANK YOU! " .. Monetization.Passes[key].Name .. " UNLOCKED", "gold")
	end
end

local function checkPasses(player: Player)
	for key, pass in Monetization.Passes do
		player:SetAttribute("Pass" .. key, false)
		if pass.Id > 0 then
			task.spawn(function()
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
				end)
				if not ok then
					task.wait(2)
					ok, owns = pcall(function()
						return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
					end)
				end
				if ok and owns and player.Parent == Players then
					grantPass(player, key, false)
				elseif not ok then
					warn("[PurchaseService] could not check pass " .. key .. " for " .. player.Name .. ": " .. tostring(owns))
				end
			end)
		end
	end
end

-- Revive --------------------------------------------------------------------

local function isDead(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return not humanoid or humanoid.Health <= 0
end

-- Why the player cannot revive right now (nil = they can).
local function reviveBlocker(player: Player): string?
	if workspace:GetAttribute("MatchState") ~= "Wave" then
		return "REVIVE WORKS DURING A WAVE"
	end
	if not isDead(player) then
		return "YOU ARE ALIVE"
	end
	local wave = workspace:GetAttribute("Wave")
	if revivedWave[player] == wave and (reviveUses[player] or 0) >= Monetization.RevivesPerWave then
		return "ALREADY REVIVED THIS WAVE"
	end
	return nil
end

local function revive(player: Player): boolean
	if reviveBlocker(player) or not DataService.TakeRevive(player) then
		return false
	end
	local wave = workspace:GetAttribute("Wave")
	if revivedWave[player] ~= wave then
		revivedWave[player] = wave
		reviveUses[player] = 0
	end
	reviveUses[player] += 1
	player:SetAttribute("RevivedWave", if reviveUses[player] >= Monetization.RevivesPerWave then wave else nil)
	task.spawn(PlayerService.Spawn, player)
	notify(player, "REVIVED!", "good")
	return true
end

local function onUseRevive(player: Player)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 1 then
		return
	end
	lastRequest[player] = now
	local blocker = reviveBlocker(player)
	if blocker then
		notify(player, blocker, "bad")
	elseif not revive(player) then
		notify(player, "NO REVIVES LEFT", "bad")
	end
end

local function findProduct(productId: number): string?
	for key, product in Monetization.Products do
		if product.Id > 0 and product.Id == productId then
			return key
		end
	end
	return nil
end

local function processReceipt(info)
	local key = findProduct(info.ProductId)
	if key == "Revive" then
		local stored = DataService.GrantReceipt(info.PlayerId, tostring(info.PurchaseId), "Revives", 1)
		if not stored then
			return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries later
		end
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if player and not reviveBlocker(player) then
			revive(player)
		elseif player then
			notify(player, "REVIVE SAVED FOR LATER", "good")
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	warn("[PurchaseService] receipt for unknown product " .. tostring(info.ProductId))
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- public --------------------------------------------------------------------

-- New match (or admin jump): everyone may revive again on every wave.
function PurchaseService.ResetRevives()
	table.clear(revivedWave)
	table.clear(reviveUses)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("RevivedWave", nil)
	end
end

function PurchaseService.Init()
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("Skin", "Default")
		checkPasses(player)
	end)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Skin", "Default")
		checkPasses(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		revivedWave[player] = nil
		reviveUses[player] = nil
		lastRequest[player] = nil
	end)

	PlayerService.CharacterSpawned:Connect(applyVipLook)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, pass in Monetization.Passes do
			if pass.Id > 0 and pass.Id == passId then
				grantPass(player, key, true)
			end
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt

	local lastSkinChange: { [Player]: number } = {}
	Players.PlayerRemoving:Connect(function(player)
		lastSkinChange[player] = nil
	end)
	Remotes.Get("SelectSkin").OnServerEvent:Connect(function(player, skinId)
		local now = os.clock()
		if now - (lastSkinChange[player] or 0) < 0.5 then
			return -- each change rebuilds the gun for everyone: no spamming
		end
		if typeof(skinId) == "string" and canUseSkin(player, skinId) then
			lastSkinChange[player] = now
			setSkin(player, skinId)
		end
	end)
	Remotes.Get("UseRevive").OnServerEvent:Connect(onUseRevive)
end

return PurchaseService
