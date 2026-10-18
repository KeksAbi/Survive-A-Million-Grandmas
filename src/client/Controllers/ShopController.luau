--!nonstrict
-- Shop panel (left): every weapon with price / OWNED / EQUIPPED; click to buy or equip.
-- Grenade panel (right): count, price and the G key; click to buy one.
-- Only sends Purchase / Equip requests; the server checks cash and ownership (ShopService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local WeaponData = require(Shared.WeaponDefinitions)

local HUDController = require(script.Parent.HUDController)
local GunIcon = require(script.Parent.Parent.GunIcon)

local player = Players.LocalPlayer

local ShopController = {}

local rows = {} -- weaponId -> { Button, Stroke, Price, Name }
local grenadeUi = {}

local function buildShop()
	local kit = HUDController.Kit
	local theme = kit.Theme
	local rowHeight, gap = 62, 8
	local height = 44 + #WeaponData.Order * (rowHeight + gap)
	local panel = HUDController.CreateContainer("Shop", Vector2.new(0, 0.5), UDim2.new(0, 16, 0.5, 0), Vector2.new(240, height))

	local title = kit.Make("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = theme.Green,
		Parent = panel,
	}, { kit.Corner(8), kit.Stroke(3) })
	local titleLabel = kit.Label({ Text = "SHOP", TextColor3 = theme.Black, Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Parent = title })
	titleLabel:FindFirstChildOfClass("UIStroke").Enabled = false

	for index, weaponId in WeaponData.Order do
		local weapon = WeaponData.Weapons[weaponId]
		local button = kit.Make("TextButton", {
			Name = weaponId,
			Text = "",
			AutoButtonColor = true,
			Position = UDim2.fromOffset(0, 44 + (index - 1) * (rowHeight + gap)),
			Size = UDim2.new(1, 0, 0, rowHeight),
			BackgroundColor3 = theme.Dark,
			Parent = panel,
		}, { kit.Corner(8) }) :: TextButton
		local rowStroke = kit.Stroke(3)
		rowStroke.Parent = button

		kit.Label({ Text = tostring(index), TextColor3 = theme.Gold, Size = UDim2.fromOffset(18, 20), Position = UDim2.fromOffset(6, 4), Parent = button })
		-- 3D icon of the real gun, in the player's current skin
		local icon = GunIcon.Create({
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 22, 0.5, 0),
			Size = UDim2.fromOffset(60, 44),
			Parent = button,
		}, weaponId, player:GetAttribute("Skin"))
		local name = kit.Label({ Text = string.upper(weapon.Name), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -90, 0, 24), Position = UDim2.fromOffset(84, 6), Parent = button })
		local price = kit.Label({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -90, 0, 24), Position = UDim2.fromOffset(84, 32), Parent = button })

		button.Activated:Connect(function()
			if player:GetAttribute("Owns" .. weaponId) then
				Remotes.Get("Equip"):FireServer(weaponId)
			else
				Remotes.Get("Purchase"):FireServer(weaponId)
			end
		end)
		rows[weaponId] = { Button = button, Stroke = rowStroke, Price = price, Name = name, Icon = icon }
	end
end

local function buildGrenadePanel()
	local kit = HUDController.Kit
	local theme = kit.Theme
	local panel = HUDController.CreateContainer("GrenadePanel", Vector2.new(1, 0.5), UDim2.new(1, -16, 0.5, 0), Vector2.new(130, 170))
	local button = kit.Make("TextButton", {
		Text = "",
		AutoButtonColor = true,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.Dark,
		Parent = panel,
	}, { kit.Corner(10) }) :: TextButton
	local panelStroke = kit.Stroke(3)
	panelStroke.Parent = button

	kit.Label({ Text = "GRENADE", Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 8), Parent = button })
	-- key badge
	local key = kit.Make("Frame", { Position = UDim2.new(1, -34, 0, 34), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = theme.Blue, Parent = button }, { kit.Corner(6), kit.Stroke(2) })
	kit.Label({ Text = "G", Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), Parent = key })
	-- grenade icon: green ball with a dark band
	local icon = kit.Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, -8, 0, 78),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = Color3.fromRGB(80, 125, 55),
		Parent = button,
	}, { kit.Corner(26), kit.Stroke(3) })
	kit.Make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Color3.fromRGB(45, 65, 35), BorderSizePixel = 0, Parent = icon })
	grenadeUi.Count = kit.Label({ Text = "x0", TextColor3 = theme.White, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, 14, 0, 92), Size = UDim2.fromOffset(44, 26), Parent = button })
	grenadeUi.Price = kit.Label({ Text = "$" .. Config.Grenade.Cost, TextColor3 = theme.Gold, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 1, -36), Parent = button })
	grenadeUi.Stroke = panelStroke

	button.Activated:Connect(function()
		Remotes.Get("Purchase"):FireServer("Grenade")
	end)
end

local function refresh()
	local theme = HUDController.Kit.Theme
	local cash = player:GetAttribute("Cash") or 0
	local equipped = player:GetAttribute("Weapon")
	for weaponId, row in rows do
		local weapon = WeaponData.Weapons[weaponId]
		local owned = player:GetAttribute("Owns" .. weaponId) == true
		if owned then
			row.Price.Text = if equipped == weaponId then "EQUIPPED" else "OWNED"
			row.Price.TextColor3 = theme.Green
			row.Stroke.Color = if equipped == weaponId then theme.Gold else theme.Black
			row.Button.BackgroundTransparency = 0
		else
			local affordable = cash >= weapon.Cost
			row.Price.Text = "$" .. weapon.Cost
			row.Price.TextColor3 = if affordable then theme.Gold else theme.Red
			row.Stroke.Color = if affordable then theme.Green else theme.Black
			row.Button.BackgroundTransparency = if affordable then 0 else 0.35
		end
	end

	local grenades = player:GetAttribute("Grenades") or 0
	grenadeUi.Count.Text = "x" .. grenades
	local canBuy = cash >= Config.Grenade.Cost and grenades < Config.Grenade.MaxCarried
	grenadeUi.Price.Text = if grenades >= Config.Grenade.MaxCarried then "FULL" else "$" .. Config.Grenade.Cost
	grenadeUi.Price.TextColor3 = if canBuy or grenades >= Config.Grenade.MaxCarried then theme.Gold else theme.Red
	grenadeUi.Stroke.Color = if grenades > 0 then theme.Green else theme.Black
end

function ShopController.Init()
	buildShop()
	buildGrenadePanel()
	player.AttributeChanged:Connect(function(name)
		if name == "Cash" or name == "Weapon" or name == "Grenades" or string.sub(name, 1, 4) == "Owns" then
			refresh()
		elseif name == "Skin" then
			for weaponId, row in rows do
				GunIcon.Set(row.Icon, weaponId, player:GetAttribute("Skin"))
			end
		end
	end)
	refresh()
end

return ShopController
