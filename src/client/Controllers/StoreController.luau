--!nonstrict
-- Robux store (STORE button bottom left): gamepasses (2X CASH, VIP, SKIN PACK) and gun skins, plus the
-- REVIVE button while dead during a wave. Purchases use Roblox's own prompts (MarketplaceService); the
-- server (PurchaseService) checks ownership and grants everything. Ids 0 = "SOON", button disabled.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local SkinData = require(Shared.SkinDefinitions)

local HUDController = require(script.Parent.HUDController)
local GunIcon = require(script.Parent.Parent.GunIcon)

local player = Players.LocalPlayer
local Monetization = Config.Monetization

local StoreController = {}

local PASS_ORDER = { "DoubleCash", "VIP", "SkinPack" }
local PASS_COLORS = {
	DoubleCash = Color3.fromRGB(70, 200, 90),
	VIP = Color3.fromRGB(255, 190, 40),
	SkinPack = Color3.fromRGB(190, 90, 255),
}

local passRows = {} -- key -> { Button, Label }
local skinCells = {} -- skinId -> { Button, Stroke, Lock }
local prices = {} -- "Pass:<key>" / "Product:<key>" -> Robux price from Roblox
local reviveUi = {}

local function robux(amount: number): string
	return "R$ " .. tostring(amount)
end

-- Real prices from Roblox (falls back to the price in Config).
local function loadPrices(onDone: () -> ())
	for key, pass in Monetization.Passes do
		if pass.Id > 0 then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(pass.Id, Enum.InfoType.GamePass)
				end)
				if ok and info and info.PriceInRobux then
					prices["Pass:" .. key] = info.PriceInRobux
					onDone()
				end
			end)
		end
	end
	for key, product in Monetization.Products do
		if product.Id > 0 then
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(product.Id, Enum.InfoType.Product)
				end)
				if ok and info and info.PriceInRobux then
					prices["Product:" .. key] = info.PriceInRobux
					onDone()
				end
			end)
		end
	end
end

local function promptPass(key: string)
	local pass = Monetization.Passes[key]
	if pass and pass.Id > 0 and player:GetAttribute("Pass" .. key) ~= true then
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	end
end

local function refreshStore()
	local kit = HUDController.Kit
	for key, row in passRows do
		local pass = Monetization.Passes[key]
		if player:GetAttribute("Pass" .. key) == true then
			row.Label.Text = "OWNED"
			row.Button.BackgroundColor3 = kit.Theme.Dark
			row.Button.AutoButtonColor = false
		elseif pass.Id <= 0 then
			row.Label.Text = "SOON"
			row.Button.BackgroundColor3 = Color3.fromRGB(80, 84, 100)
			row.Button.AutoButtonColor = false
		else
			row.Label.Text = robux(prices["Pass:" .. key] or pass.Price)
			row.Button.BackgroundColor3 = kit.Theme.Green
			row.Button.AutoButtonColor = true
		end
	end
	local current = player:GetAttribute("Skin") or "Default"
	for skinId, cell in skinCells do
		local skin = SkinData.Skins[skinId]
		local unlocked = skin.Requires == nil or player:GetAttribute("Pass" .. skin.Requires) == true
		cell.Lock.Visible = not unlocked
		cell.Stroke.Color = if skinId == current then kit.Theme.Gold else kit.Theme.Black
		cell.Stroke.Thickness = if skinId == current then 4 else 2
	end
end

local function build()
	local kit = HUDController.Kit
	local theme = kit.Theme
	local width = 300
	local panelHeight = 44 + #PASS_ORDER * 68 + 30 + 84 + 12
	-- STORE button bottom left on PC, top left on touch screens (the thumbstick sits bottom left there);
	-- the panel opens in the middle of the screen so it never covers the weapon shop
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local container = if touch
		then HUDController.CreateContainer("StoreButton", Vector2.new(0, 0), UDim2.new(0, 16, 0, 70), Vector2.new(130, 44))
		else HUDController.CreateContainer("StoreButton", Vector2.new(0, 1), UDim2.new(0, 16, 1, -16), Vector2.new(130, 44))
	local panelContainer = HUDController.CreateContainer("Store", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), Vector2.new(width, panelHeight))

	local toggle = kit.Make("TextButton", {
		Text = "",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.Gold,
		Parent = container,
	}, { kit.Corner(10), kit.Stroke(3) }) :: TextButton
	local toggleLabel = kit.Label({ Text = "STORE", TextColor3 = theme.Black, Size = UDim2.new(1, -16, 1, -12), Position = UDim2.fromOffset(8, 6), Parent = toggle })
	toggleLabel:FindFirstChildOfClass("UIStroke").Enabled = false

	local panel = kit.Make("Frame", {
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.Dark,
		BackgroundTransparency = 0.05,
		Parent = panelContainer,
	}, { kit.Corner(12), kit.Stroke(3) }) :: Frame
	local title = kit.Make("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = theme.Gold, Parent = panel }, { kit.Corner(12) })
	local titleLabel = kit.Label({ Text = "STORE", TextColor3 = theme.Black, Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Parent = title })
	titleLabel:FindFirstChildOfClass("UIStroke").Enabled = false
	local close = kit.Make("TextButton", {
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = theme.Red,
		Parent = title,
	}, { kit.Corner(8), kit.Stroke(2) }) :: TextButton
	kit.Label({ Text = "X", Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), Parent = close })

	-- gamepasses
	for index, key in PASS_ORDER do
		local pass = Monetization.Passes[key]
		local y = 44 + (index - 1) * 68
		local row = kit.Make("Frame", {
			Position = UDim2.fromOffset(10, y),
			Size = UDim2.new(1, -20, 0, 60),
			BackgroundColor3 = Color3.fromRGB(38, 40, 56),
			Parent = panel,
		}, { kit.Corner(8) })
		kit.Make("Frame", { Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = PASS_COLORS[key], BorderSizePixel = 0, Parent = row }, { kit.Corner(4) })
		kit.Label({ Text = pass.Name, TextColor3 = PASS_COLORS[key], TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -120, 0, 26), Position = UDim2.fromOffset(16, 5), Parent = row })
		local description = kit.Label({ Text = pass.Description, TextColor3 = Color3.fromRGB(200, 205, 220), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -120, 0, 18), Position = UDim2.fromOffset(16, 34), Parent = row })
		kit.Make("UITextSizeConstraint", { MaxTextSize = 13, Parent = description }) -- same size on every row
		local button = kit.Make("TextButton", {
			Text = "",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(92, 40),
			BackgroundColor3 = theme.Green,
			Parent = row,
		}, { kit.Corner(8), kit.Stroke(3) }) :: TextButton
		local label = kit.Label({ Text = "", Size = UDim2.new(1, -10, 1, -12), Position = UDim2.fromOffset(5, 6), Parent = button })
		button.Activated:Connect(function()
			promptPass(key)
		end)
		passRows[key] = { Button = button, Label = label }
	end

	-- gun skins
	local skinsY = 44 + #PASS_ORDER * 68 + 2
	kit.Label({ Text = "GUN SKINS", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(12, skinsY), Parent = panel })
	local cellSize = (width - 20 - 4 * 6) / 5
	for index, skinId in SkinData.Order do
		local skin = SkinData.Skins[skinId]
		local cell = kit.Make("TextButton", {
			Text = "",
			Position = UDim2.fromOffset(10 + (index - 1) * (cellSize + 6), skinsY + 28),
			Size = UDim2.fromOffset(cellSize, 76),
			BackgroundColor3 = Color3.fromRGB(38, 40, 56),
			Parent = panel,
		}, { kit.Corner(8) }) :: TextButton
		local cellStroke = kit.Stroke(2)
		cellStroke.Parent = cell
		-- the assault rifle in this skin, as a 3D icon
		GunIcon.Create({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.new(1, -4, 0, 36),
			Parent = cell,
		}, "AssaultRifle", skinId)
		kit.Label({ Text = skin.Name, Size = UDim2.new(1, -6, 0, 16), Position = UDim2.fromOffset(3, 40), Parent = cell })
		local lock = kit.Label({
			Text = if skin.Requires == "VIP" then "VIP" else "PACK",
			TextColor3 = theme.Gold,
			Size = UDim2.new(1, -6, 0, 14),
			Position = UDim2.fromOffset(3, 58),
			Parent = cell,
		})
		cell.Activated:Connect(function()
			local unlocked = skin.Requires == nil or player:GetAttribute("Pass" .. skin.Requires) == true
			if unlocked then
				Remotes.Get("SelectSkin"):FireServer(skinId)
			elseif skin.Requires then
				promptPass(skin.Requires)
			end
		end)
		skinCells[skinId] = { Button = cell, Stroke = cellStroke, Lock = lock }
	end

	local function setOpen(open: boolean)
		panel.Visible = open
		HUDController.ModalOpen = open -- free mouse, no shooting while shopping
	end
	toggle.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
end

-- REVIVE button (center) while dead during a wave.
local function buildRevive()
	local kit = HUDController.Kit
	local container = HUDController.CreateContainer("Revive", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.74), Vector2.new(320, 116))
	-- "LAST CHANCE 7" while the whole team is down (workspace ReviveCountdown)
	reviveUi.Countdown = kit.Label({
		Text = "",
		Visible = false,
		TextColor3 = kit.Theme.Red,
		Size = UDim2.new(1, 0, 0, 46),
		Parent = container,
	})
	local button = kit.Make("TextButton", {
		Text = "",
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(280, 60),
		BackgroundColor3 = kit.Theme.Green,
		Parent = container,
	}, { kit.Corner(12), kit.Stroke(3) }) :: TextButton
	reviveUi.Label = kit.Label({ Text = "REVIVE", TextColor3 = kit.Theme.Black, Size = UDim2.new(1, -20, 1, -14), Position = UDim2.fromOffset(10, 7), Parent = button })
	reviveUi.Label:FindFirstChildOfClass("UIStroke").Enabled = false
	reviveUi.Button = button
	button.Activated:Connect(function()
		local credits = player:GetAttribute("Revives") or 0
		local product = Monetization.Products.Revive
		if credits > 0 then
			Remotes.Get("UseRevive"):FireServer()
		elseif product.Id > 0 then
			MarketplaceService:PromptProductPurchase(player, product.Id)
		end
	end)
end

local function refreshRevive()
	local credits = player:GetAttribute("Revives") or 0
	local product = Monetization.Products.Revive
	local wave = workspace:GetAttribute("Wave")
	local show = workspace:GetAttribute("MatchState") == "Wave"
		and player:GetAttribute("Alive") ~= true
		and player:GetAttribute("RevivedWave") ~= wave
		and (credits > 0 or product.Id > 0)
	reviveUi.Button.Visible = show
	local countdown = workspace:GetAttribute("ReviveCountdown")
	reviveUi.Countdown.Visible = show and countdown ~= nil
	reviveUi.Countdown.Text = "LAST CHANCE  " .. tostring(countdown or "")
	if credits > 0 then
		reviveUi.Label.Text = "REVIVE (" .. credits .. " LEFT)"
	else
		reviveUi.Label.Text = "REVIVE  " .. robux(prices["Product:Revive"] or product.Price)
	end
end

function StoreController.Init()
	build()
	buildRevive()
	loadPrices(function()
		refreshStore()
		refreshRevive()
	end)
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 4) == "Pass" or name == "Skin" then
			refreshStore()
		elseif name == "Revives" or name == "Alive" or name == "RevivedWave" then
			refreshRevive()
		end
	end)
	workspace:GetAttributeChangedSignal("MatchState"):Connect(refreshRevive)
	workspace:GetAttributeChangedSignal("Wave"):Connect(refreshRevive)
	workspace:GetAttributeChangedSignal("ReviveCountdown"):Connect(refreshRevive)
	refreshStore()
	refreshRevive()
end

return StoreController
