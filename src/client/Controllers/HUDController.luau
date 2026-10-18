--!nonstrict
-- Builds the whole HUD in code (no Studio GUI to keep in sync) and keeps it updated from attributes:
--   player: Cash, Weapon, Ammo, MagSize, Reloading, Owns<WeaponId>
--   workspace: Wave, WaveKills, WaveTotal (set by WaveService; absent = test arena)
-- Layout: wave banner top center, crosshair center, health / cash / weapon slots bottom center,
-- ammo bottom right. All sizes are pixel offsets scaled by one UIScale, so it fits phone to PC.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local WeaponData = require(Shared.WeaponDefinitions)

local player = Players.LocalPlayer

local HUDController = {}

local THEME = {
	Green = Color3.fromRGB(70, 230, 130),
	Dark = Color3.fromRGB(22, 24, 34),
	Gold = Color3.fromRGB(255, 205, 50),
	White = Color3.fromRGB(255, 255, 255),
	Black = Color3.fromRGB(10, 10, 14),
	Red = Color3.fromRGB(235, 60, 60),
	Blue = Color3.fromRGB(60, 140, 255),
	Font = Enum.Font.GothamBlack,
}

local NOTIFY_COLORS = {
	info = THEME.Blue,
	good = THEME.Green,
	bad = THEME.Red,
	boss = Color3.fromRGB(200, 40, 40),
	gold = THEME.Gold,
}

local ui: { [string]: any } = {} -- named references to live elements

-- Instance.new + properties + children in one call.
local function make(className: string, props: { [string]: any }, children: { Instance }?): Instance
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function corner(radius: number): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius) }) :: UICorner
end

local function stroke(thickness: number, color: Color3?): UIStroke
	return make("UIStroke", { Thickness = thickness, Color = color or THEME.Black, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) :: UIStroke
end

local function label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = THEME.Font,
		TextColor3 = THEME.White,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	}
	for key, value in props do
		defaults[key] = value
	end
	local textLabel = make("TextLabel", defaults) :: TextLabel
	make("UIStroke", { Thickness = 2, Color = THEME.Black, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = textLabel })
	return textLabel
end

local function buildCrosshair(root: Frame)
	local cross = make("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(36, 36),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local bars = {
		{ UDim2.new(0.5, 0, 0, 0), UDim2.fromOffset(3, 11) },
		{ UDim2.new(0.5, 0, 1, -11), UDim2.fromOffset(3, 11) },
		{ UDim2.new(0, 0, 0.5, 0), UDim2.fromOffset(11, 3) },
		{ UDim2.new(1, -11, 0.5, 0), UDim2.fromOffset(11, 3) },
	}
	for _, bar in bars do
		make("Frame", {
			AnchorPoint = Vector2.new(if bar[2].X.Offset == 3 then 0.5 else 0, if bar[2].Y.Offset == 3 then 0.5 else 0),
			Position = bar[1],
			Size = bar[2],
			BackgroundColor3 = THEME.White,
			BorderSizePixel = 0,
			Parent = cross,
		}, { stroke(1) })
	end
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = THEME.White,
		BorderSizePixel = 0,
		Parent = cross,
	}, { corner(2), stroke(1) })

	-- hitmarker: an X of two rotated bars, hidden until a hit
	local hit = make("Frame", {
		Name = "Hitmarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Parent = cross,
	})
	ui.HitBars = {}
	for _, rotation in { 45, -45 } do
		local bar = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(30, 4),
			Rotation = rotation,
			BackgroundColor3 = THEME.White,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = hit,
		})
		table.insert(ui.HitBars, bar)
	end
end

local function buildWaveBanner(root: Frame)
	local banner = make("Frame", {
		Name = "WaveBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(300, 58),
		BackgroundColor3 = THEME.Green,
		Parent = root,
	}, { corner(10), stroke(3) })
	ui.WaveLabel = label({ Text = "TEST ARENA", TextColor3 = THEME.Black, Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromOffset(10, 4), Parent = banner })
	ui.WaveLabel:FindFirstChildOfClass("UIStroke").Enabled = false

	local progress = make("Frame", {
		Name = "WaveProgress",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 78),
		Size = UDim2.fromOffset(330, 34),
		BackgroundColor3 = THEME.Dark,
		Visible = false,
		Parent = root,
	}, { corner(8), stroke(2) })
	label({ Text = "SURVIVE THE GRANDMAS", TextColor3 = THEME.Green, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.7, -10, 1, -10), Position = UDim2.fromOffset(10, 5), Parent = progress })
	ui.WaveCounter = label({ Text = "0 / 0", TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.3, -10, 1, -8), Position = UDim2.new(0.7, 0, 0, 4), Parent = progress })
	ui.WaveProgress = progress
end

local function buildBottom(root: Frame)
	-- health bar
	local health = make("Frame", {
		Name = "Health",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -146),
		Size = UDim2.fromOffset(300, 24),
		BackgroundColor3 = THEME.Dark,
		Parent = root,
	}, { corner(8), stroke(2) })
	ui.HealthFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.Green,
		BorderSizePixel = 0,
		Parent = health,
	}, { corner(8) })
	ui.HealthText = label({ Text = "100 / 100", Size = UDim2.new(1, 0, 1, -4), Position = UDim2.fromOffset(0, 2), ZIndex = 2, Parent = health })

	-- cash
	local cash = make("Frame", {
		Name = "Cash",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -82),
		Size = UDim2.fromOffset(190, 54),
		BackgroundColor3 = THEME.Dark,
		Parent = root,
	}, { corner(10), stroke(3) })
	ui.CashLabel = label({ Text = "$ 0", TextColor3 = THEME.Gold, Size = UDim2.new(1, -16, 1, -10), Position = UDim2.fromOffset(8, 5), Parent = cash })
	ui.CashFrame = cash

	-- weapon slots
	local slots = make("Frame", {
		Name = "Slots",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(3 * 64 + 2 * 8, 64),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	ui.Slots = {}
	for index, weaponId in WeaponData.Order do
		local weapon = WeaponData.Weapons[weaponId]
		local slot = make("Frame", {
			Name = weaponId,
			LayoutOrder = index,
			Size = UDim2.fromOffset(64, 64),
			BackgroundColor3 = THEME.Dark,
			Parent = slots,
		}, { corner(8) })
		local slotStroke = stroke(3)
		slotStroke.Parent = slot
		label({ Text = tostring(index), Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(4, 2), TextColor3 = THEME.Gold, Parent = slot })
		label({ Text = string.upper(weapon.Name), Size = UDim2.new(1, -8, 0, 16), Position = UDim2.new(0, 4, 1, -20), Parent = slot })
		-- simple gun silhouette as the icon
		make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(math.clamp(weapon.Look.Size.Z * 16, 18, 44), 8),
			BackgroundColor3 = weapon.Look.AccentColor,
			BorderSizePixel = 0,
			Parent = slot,
		}, { corner(2) })
		ui.Slots[weaponId] = { Frame = slot, Stroke = slotStroke }
	end

	-- ammo (bottom right)
	local ammo = make("Frame", {
		Name = "Ammo",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(170, 76),
		BackgroundColor3 = THEME.Dark,
		BackgroundTransparency = 0.15,
		Parent = root,
	}, { corner(10), stroke(2) })
	ui.WeaponName = label({ Text = "PISTOL", Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 6), TextXAlignment = Enum.TextXAlignment.Right, Parent = ammo })
	ui.AmmoLabel = label({ Text = "12 / 12", Size = UDim2.new(1, -16, 0, 38), Position = UDim2.fromOffset(8, 30), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = THEME.Gold, Parent = ammo })
end

local function buildNotification(root: Frame)
	ui.Notify = label({
		Name = "Notification",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 160),
		Size = UDim2.fromOffset(600, 56),
		TextTransparency = 1,
		Parent = root,
	})
	ui.NotifyStroke = ui.Notify:FindFirstChildOfClass("UIStroke")
	ui.NotifyStroke.Thickness = 3
	ui.NotifyStroke.Transparency = 1
end

-- refreshers --------------------------------------------------------------

local function refreshCash()
	ui.CashLabel.Text = "$ " .. tostring(player:GetAttribute("Cash") or 0)
end

local function refreshWeapon()
	local weaponId = player:GetAttribute("Weapon") or "Pistol"
	local weapon = WeaponData.Weapons[weaponId]
	if weapon then
		ui.WeaponName.Text = string.upper(weapon.Name)
	end
	if player:GetAttribute("Reloading") then
		ui.AmmoLabel.Text = "RELOADING"
		ui.AmmoLabel.TextColor3 = THEME.Red
	else
		ui.AmmoLabel.Text = tostring(player:GetAttribute("Ammo") or 0) .. " / " .. tostring(player:GetAttribute("MagSize") or 0)
		ui.AmmoLabel.TextColor3 = THEME.Gold
	end
	for id, slot in ui.Slots do
		local owned = player:GetAttribute("Owns" .. id) == true
		slot.Frame.BackgroundTransparency = if owned then 0 else 0.55
		slot.Stroke.Color = if id == weaponId then THEME.Gold else THEME.Black
		slot.Stroke.Thickness = if id == weaponId then 4 else 3
	end
end

local function refreshWave()
	local wave = workspace:GetAttribute("Wave")
	if wave then
		ui.WaveLabel.Text = "WAVE " .. tostring(wave)
		ui.WaveCounter.Text = tostring(workspace:GetAttribute("WaveKills") or 0) .. " / " .. tostring(workspace:GetAttribute("WaveTotal") or 0)
		ui.WaveProgress.Visible = true
	else
		ui.WaveLabel.Text = "TEST ARENA"
		ui.WaveProgress.Visible = false
	end
end

local healthConnection: RBXScriptConnection? = nil
local function watchHealth(character: Model)
	if healthConnection then
		healthConnection:Disconnect()
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	local function update()
		local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		TweenService:Create(ui.HealthFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(ratio, 1) }):Play()
		ui.HealthFill.BackgroundColor3 = if ratio > 0.5 then THEME.Green elseif ratio > 0.25 then THEME.Gold else THEME.Red
		ui.HealthText.Text = tostring(math.ceil(humanoid.Health)) .. " / " .. tostring(humanoid.MaxHealth)
	end
	healthConnection = humanoid.HealthChanged:Connect(update)
	update()
end

-- "+$12" floating up from the cash box
local lastCash = 0
local function cashPopup(delta: number)
	local popup = label({
		Text = "+$" .. tostring(delta),
		TextColor3 = THEME.Gold,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 70, 1, -110),
		Size = UDim2.fromOffset(110, 34),
		Parent = ui.Root,
	})
	TweenService:Create(popup, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 70, 1, -170),
		TextTransparency = 1,
	}):Play()
	TweenService:Create(popup:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.8), { Transparency = 1 }):Play()
	task.delay(0.85, function()
		popup:Destroy()
	end)
end

-- public ------------------------------------------------------------------

function HUDController.ShowHitmarker(killed: boolean)
	for _, bar in ui.HitBars do
		bar.BackgroundColor3 = if killed then THEME.Red else THEME.White
		bar.BackgroundTransparency = 0
		TweenService:Create(bar, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
	end
end

local notifyToken = 0
function HUDController.Notify(text: string, kind: string?)
	notifyToken += 1
	local token = notifyToken
	local color = NOTIFY_COLORS[kind or "info"] or THEME.Blue
	ui.Notify.Text = text
	ui.Notify.TextColor3 = THEME.White
	ui.NotifyStroke.Color = color
	ui.Notify.TextTransparency = 0
	ui.NotifyStroke.Transparency = 0
	ui.Notify.Size = UDim2.fromOffset(420, 40)
	TweenService:Create(ui.Notify, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(600, 56) }):Play()
	task.delay(2.2, function()
		if token ~= notifyToken then
			return
		end
		TweenService:Create(ui.Notify, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(ui.NotifyStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	end)
end

function HUDController.Init()
	local gui = make("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local root = make("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	ui.Root = root

	-- one scale for every element: 1.0 at 900 px screen height
	local scale = make("UIScale", { Parent = root }) :: UIScale
	local camera = workspace.CurrentCamera
	local function rescale()
		scale.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.6, 1.3)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	buildCrosshair(root)
	buildWaveBanner(root)
	buildBottom(root)
	buildNotification(root)

	lastCash = player:GetAttribute("Cash") or 0
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		local cash = player:GetAttribute("Cash") or 0
		if cash > lastCash then
			cashPopup(cash - lastCash)
		end
		lastCash = cash
		refreshCash()
	end)
	player.AttributeChanged:Connect(function(name)
		if name == "Weapon" or name == "Ammo" or name == "MagSize" or name == "Reloading" or string.sub(name, 1, 4) == "Owns" then
			refreshWeapon()
		end
	end)
	workspace.AttributeChanged:Connect(function(name)
		if name == "Wave" or name == "WaveKills" or name == "WaveTotal" then
			refreshWave()
		end
	end)
	Remotes.Get("Notify").OnClientEvent:Connect(HUDController.Notify)

	player.CharacterAdded:Connect(watchHealth)
	if player.Character then
		task.spawn(watchHealth, player.Character)
	end

	refreshCash()
	refreshWeapon()
	refreshWave()
end

return HUDController
