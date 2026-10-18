--!nonstrict
-- Builds the whole HUD in code (no Studio GUI to keep in sync) and keeps it updated from attributes:
--   player: Cash, Weapon, Ammo, MagSize, Reloading, Owns<WeaponId>
--   workspace: MatchState, Wave, WaveKills, WaveTotal, Countdown (set by WaveService)
-- Layout: wave banner top center, crosshair center, health / cash / weapon slots bottom center,
-- ammo bottom right. Each corner group has its own UIScale (max 1.0), so nothing is pushed off screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local WeaponData = require(Shared.WeaponDefinitions)

local Effects = require(script.Parent.Parent.Effects)
local GunIcon = require(script.Parent.Parent.GunIcon)
local InputController = require(script.Parent.InputController)

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

-- true while a screen that needs the mouse (results) is open; GunController frees the mouse then
HUDController.ModalOpen = false
-- true while the boss cutscene plays: HUD hidden, no aiming or shooting
HUDController.CutsceneActive = false

local rescale: () -> () -- defined with HUDController.CreateContainer

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
		ZIndex = 10,
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
	ui.Crosshair = cross

	-- small reload bar under the crosshair (fills up while reloading)
	local reloadBar = make("Frame", {
		Name = "ReloadBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 8),
		Size = UDim2.fromOffset(48, 6),
		BackgroundColor3 = THEME.Dark,
		Visible = false,
		Parent = cross,
	}, { corner(3), stroke(1) })
	ui.CrossReloadFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.Gold, BorderSizePixel = 0, Parent = reloadBar }, { corner(3) })
	ui.CrossReloadBar = reloadBar
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
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(300, 58),
		BackgroundColor3 = THEME.Green,
		Parent = root,
	}, { corner(10), stroke(3) })
	ui.WaveBanner = banner
	ui.WaveLabel = label({ Text = "WAITING...", TextColor3 = THEME.Black, Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromOffset(10, 4), Parent = banner })
	ui.WaveLabel:FindFirstChildOfClass("UIStroke").Enabled = false

	local progress = make("Frame", {
		Name = "WaveProgress",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66),
		Size = UDim2.fromOffset(330, 34),
		BackgroundColor3 = THEME.Dark,
		Visible = false,
		Parent = root,
	}, { corner(8), stroke(2) })
	ui.WaveTask = label({ Text = "SURVIVE THE GRANDMAS", TextColor3 = THEME.Green, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.7, -10, 1, -10), Position = UDim2.fromOffset(10, 5), Parent = progress })
	ui.WaveCounter = label({ Text = "0 / 0", TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.3, -10, 1, -8), Position = UDim2.new(0.7, 0, 0, 4), Parent = progress })
	ui.WaveProgress = progress
end

local function buildBottom(root: Frame, ammoRoot: Frame)
	-- health bar
	local health = make("Frame", {
		Name = "Health",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 24),
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
		Position = UDim2.new(0.5, 0, 0, 88),
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
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(3 * 64 + 2 * 8, 64),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
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
		-- 3D icon of the real gun (refreshed when the skin changes)
		local icon = GunIcon.Create({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(58, 34),
			Parent = slot,
		}, weaponId, player:GetAttribute("Skin"))
		player:GetAttributeChangedSignal("Skin"):Connect(function()
			GunIcon.Set(icon, weaponId, player:GetAttribute("Skin"))
		end)
		-- the whole slot is a button too (tap on mobile, click on PC) = same as pressing its number key
		local tap = make("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = slot }) :: TextButton
		tap.Activated:Connect(function()
			InputController.SlotPressed:Fire(index)
		end)
		ui.Slots[weaponId] = { Frame = slot, Stroke = slotStroke }
	end

	-- ammo (bottom right)
	local ammo = make("Frame", {
		Name = "Ammo",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(170, 76),
		BackgroundColor3 = THEME.Dark,
		BackgroundTransparency = 0.15,
		Parent = ammoRoot,
	}, { corner(10), stroke(2) })
	ui.WeaponName = label({ Text = "PISTOL", Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 6), TextXAlignment = Enum.TextXAlignment.Right, Parent = ammo })
	ui.AmmoLabel = label({ Text = "12 / 12", Size = UDim2.new(1, -16, 0, 38), Position = UDim2.fromOffset(8, 30), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = THEME.Gold, Parent = ammo })
	local reloadBar = make("Frame", {
		Name = "ReloadBar",
		Position = UDim2.new(0, 8, 1, -10),
		Size = UDim2.new(1, -16, 0, 6),
		BackgroundColor3 = Color3.fromRGB(50, 52, 64),
		BorderSizePixel = 0,
		Visible = false,
		Parent = ammo,
	}, { corner(3) })
	ui.AmmoReloadFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.Red, BorderSizePixel = 0, Parent = reloadBar }, { corner(3) })
	ui.AmmoReloadBar = reloadBar
end

local function buildBossBar(root: Frame)
	local bar = make("Frame", {
		Name = "BossBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.fromOffset(420, 30),
		BackgroundColor3 = THEME.Dark,
		Visible = false,
		Parent = root,
	}, { corner(8), stroke(3) })
	ui.BossFill = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.Red,
		BorderSizePixel = 0,
		Parent = bar,
	}, { corner(8) })
	ui.BossLabel = label({ Text = "MEGA GRANDMA", Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), ZIndex = 2, Parent = bar })
	ui.BossBar = bar
end

local function refreshBoss()
	local health = workspace:GetAttribute("BossHealth")
	local maxHealth = workspace:GetAttribute("BossMaxHealth")
	if not health or not maxHealth then
		ui.BossBar.Visible = false
		return
	end
	ui.BossBar.Visible = true
	ui.BossLabel.Text = tostring(workspace:GetAttribute("BossName") or "BOSS") .. "  " .. tostring(health) .. " / " .. tostring(maxHealth)
	TweenService:Create(ui.BossFill, TweenInfo.new(0.15), { Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1) }):Play()
end

local function buildNotification(root: Frame)
	ui.Notify = label({
		Name = "Notification",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 170),
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

-- Reload timer: counts down from the weapon's ReloadTime while the "Reloading" attribute is true.
local reloadConnection: RBXScriptConnection? = nil
local function stopReloadTimer()
	if reloadConnection then
		reloadConnection:Disconnect()
		reloadConnection = nil
	end
	ui.AmmoReloadBar.Visible = false
	ui.CrossReloadBar.Visible = false
end

local function startReloadTimer(reloadTime: number)
	stopReloadTimer()
	local started = os.clock()
	ui.AmmoReloadBar.Visible = true
	ui.CrossReloadBar.Visible = true
	ui.AmmoLabel.TextColor3 = THEME.Red
	reloadConnection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		local progress = math.clamp(elapsed / reloadTime, 0, 1)
		ui.AmmoLabel.Text = string.format("RELOADING %.1fs", math.max(0, reloadTime - elapsed))
		ui.AmmoReloadFill.Size = UDim2.fromScale(progress, 1)
		ui.CrossReloadFill.Size = UDim2.fromScale(progress, 1)
	end)
end

local wasReloading = false
local function refreshWeapon()
	local weaponId = player:GetAttribute("Weapon") or "Pistol"
	local weapon = WeaponData.Weapons[weaponId]
	if weapon then
		ui.WeaponName.Text = string.upper(weapon.Name)
	end
	local reloading = player:GetAttribute("Reloading") == true
	if reloading and not wasReloading and weapon then
		startReloadTimer(weapon.ReloadTime)
		Effects.PlaySound("Reload")
	elseif not reloading and wasReloading then
		stopReloadTimer()
	end
	wasReloading = reloading
	if reloading then
		-- text is driven by the reload timer
	else
		ui.AmmoLabel.Text = tostring(player:GetAttribute("Ammo") or 0) .. " / " .. tostring(player:GetAttribute("MagSize") or 0)
		ui.AmmoLabel.TextColor3 = THEME.Gold
	end
	for id, slot in ui.Slots do
		local owned = player:GetAttribute("Owns" .. id) == true
		slot.Frame.Visible = owned -- a gun appears in the hotbar only once it is bought (the list re-centers)
		slot.Stroke.Color = if id == weaponId then THEME.Gold else THEME.Black
		slot.Stroke.Thickness = if id == weaponId then 4 else 3
	end
end

local function refreshWave()
	local matchState = workspace:GetAttribute("MatchState") or "Waiting"
	local wave = tostring(workspace:GetAttribute("Wave") or 1)
	local countdown = tostring(workspace:GetAttribute("Countdown") or 0) .. "s"
	ui.WaveProgress.Visible = true
	ui.WaveBanner.BackgroundColor3 = THEME.Green
	if matchState == "Wave" then
		ui.WaveLabel.Text = "WAVE " .. wave
		ui.WaveTask.Text = "SURVIVE THE GRANDMAS"
		ui.WaveCounter.Text = tostring(workspace:GetAttribute("WaveKills") or 0) .. " / " .. tostring(workspace:GetAttribute("WaveTotal") or 0)
	elseif matchState == "Intermission" then
		ui.WaveLabel.Text = "WAVE " .. wave
		ui.WaveTask.Text = "GET READY!"
		ui.WaveCounter.Text = countdown
	elseif matchState == "Victory" or matchState == "Defeat" then
		ui.WaveLabel.Text = if matchState == "Victory" then "VICTORY!" else "GAME OVER"
		ui.WaveBanner.BackgroundColor3 = if matchState == "Victory" then THEME.Gold else THEME.Red
		ui.WaveTask.Text = "NEXT MATCH IN"
		ui.WaveCounter.Text = countdown
	else
		ui.WaveLabel.Text = "WAITING..."
		ui.WaveProgress.Visible = false
	end
end

-- full-screen countdown during the intermission ---------------------------------
-- A dimmed overlay under the rest of the HUD with a huge popping number, then "GO!" when the wave starts.
-- Sizes are screen-relative (scale), so it fills any screen.

local function buildCountdown(root: Frame)
	local overlay = make("Frame", {
		Name = "Countdown",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.Black,
		BackgroundTransparency = 1,
		ZIndex = 0, -- under every other HUD element, never blocks buttons
		Visible = false,
		Parent = root,
	})
	ui.CountdownFrame = overlay
	ui.CountdownTitle = label({
		Text = "WAVE 1",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.24),
		Size = UDim2.fromScale(0.7, 0.11),
		Parent = overlay,
	})
	ui.CountdownSub = label({
		Text = "STARTS IN",
		TextColor3 = THEME.Green,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.fromScale(0.5, 0.05),
		Parent = overlay,
	})
	ui.CountdownNumber = label({
		Text = "10",
		TextColor3 = THEME.Gold,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromScale(0.5, 0.36),
		Parent = overlay,
	})
	ui.CountdownTitle:FindFirstChildOfClass("UIStroke").Thickness = 5
	ui.CountdownSub:FindFirstChildOfClass("UIStroke").Thickness = 3
	ui.CountdownNumber:FindFirstChildOfClass("UIStroke").Thickness = 8
end

local NUMBER_SIZE = UDim2.fromScale(0.5, 0.36)
local lastCountdown: number? = nil
local goToken = 0

local function popNumber(text: string, color: Color3)
	local number = ui.CountdownNumber
	number.Text = text
	number.TextColor3 = color
	number.TextTransparency = 0
	number.Size = UDim2.fromScale(0.85, 0.6)
	number.Rotation = math.random(-8, 8)
	TweenService:Create(number, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = NUMBER_SIZE, Rotation = 0 }):Play()
end

local function refreshCountdown()
	local matchState = workspace:GetAttribute("MatchState")
	local countdown = workspace:GetAttribute("Countdown") or 0
	local overlay = ui.CountdownFrame

	if matchState == "Intermission" and countdown > 0 then
		goToken += 1
		if not overlay.Visible then
			overlay.Visible = true
			overlay.BackgroundTransparency = 1
			TweenService:Create(overlay, TweenInfo.new(0.4), { BackgroundTransparency = 0.55 }):Play()
		end
		ui.CountdownTitle.Text = "WAVE " .. tostring(workspace:GetAttribute("Wave") or 1)
		ui.CountdownSub.Text = "STARTS IN"
		if countdown ~= lastCountdown then
			lastCountdown = countdown
			popNumber(tostring(countdown), if countdown <= 3 then THEME.Red else THEME.Gold)
		end
	elseif matchState == "Wave" and lastCountdown ~= nil then
		-- countdown just finished: flash GO! and fade the overlay out
		lastCountdown = nil
		goToken += 1
		local token = goToken
		ui.CountdownSub.Text = "SURVIVE!"
		popNumber("GO!", THEME.Green)
		TweenService:Create(overlay, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
		task.delay(0.9, function()
			if token == goToken then
				overlay.Visible = false
			end
		end)
	elseif matchState ~= "Wave" then
		lastCountdown = nil
		overlay.Visible = false
	end
end

-- results screen ------------------------------------------------------------

local RESULT_ROWS = {
	{ Key = "WavesSurvived", Text = "WAVES SURVIVED" },
	{ Key = "Kills", Text = "GRANDMAS ELIMINATED" },
	{ Key = "CashEarned", Text = "CASH EARNED", Prefix = "$" },
	{ Key = "TeamKills", Text = "TEAM KILLS" },
	{ Key = "BestWave", Text = "BEST WAVE" },
}

local function buildResults(panel: Frame)
	panel.Visible = false
	panel.BackgroundColor3 = THEME.Dark
	panel.BackgroundTransparency = 0.05
	corner(14).Parent = panel
	ui.ResultsStroke = stroke(4, THEME.Gold)
	ui.ResultsStroke.Parent = panel

	ui.ResultsTitle = label({ Text = "VICTORY!", TextColor3 = THEME.Gold, Size = UDim2.new(1, -40, 0, 64), Position = UDim2.fromOffset(20, 14), Parent = panel })
	ui.ResultsValues = {}
	for index, row in RESULT_ROWS do
		local y = 88 + (index - 1) * 40
		label({ Text = row.Text, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.68, -24, 0, 28), Position = UDim2.fromOffset(24, y), Parent = panel })
		ui.ResultsValues[row.Key] = label({ Text = "0", TextColor3 = THEME.Gold, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.32, -24, 0, 28), Position = UDim2.new(0.68, 0, 0, y), Parent = panel })
	end
	ui.ResultsCountdown = label({ Text = "NEXT MATCH IN 12", TextColor3 = Color3.fromRGB(190, 195, 210), Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, 292), Parent = panel })

	local button = make("TextButton", {
		Name = "PlayAgain",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(240, 46),
		BackgroundColor3 = THEME.Green,
		Text = "",
		AutoButtonColor = true,
		Parent = panel,
	}, { corner(10), stroke(3) }) :: TextButton
	ui.PlayAgainLabel = label({ Text = "PLAY AGAIN", TextColor3 = THEME.White, Size = UDim2.new(1, -16, 1, -10), Position = UDim2.fromOffset(8, 5), Parent = button })
	button.Activated:Connect(function()
		HUDController.HideResults()
	end)
	ui.Results = panel
end

local resultsToken = 0
function HUDController.HideResults()
	resultsToken += 1
	if ui.Results then
		ui.Results.Visible = false
	end
	HUDController.ModalOpen = false
end

function HUDController.ShowResults(result)
	resultsToken += 1
	local token = resultsToken
	local color = if result.Victory then THEME.Gold else THEME.Red
	ui.ResultsTitle.Text = if result.Victory then "VICTORY!" else "GAME OVER"
	ui.ResultsTitle.TextColor3 = color
	ui.ResultsStroke.Color = color
	ui.PlayAgainLabel.Parent.BackgroundColor3 = if result.Victory then THEME.Green else THEME.Red
	for _, row in RESULT_ROWS do
		ui.ResultsValues[row.Key].Text = (row.Prefix or "") .. tostring(result[row.Key] or 0)
	end
	ui.Results.Visible = true
	ui.Results.Position = UDim2.new(0.5, 0, 0.5, 60)
	TweenService:Create(ui.Results, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	HUDController.ModalOpen = true

	task.spawn(function()
		for t = result.NextMatchIn or 10, 1, -1 do
			if token ~= resultsToken then
				return
			end
			ui.ResultsCountdown.Text = "NEXT MATCH IN " .. t
			task.wait(1)
		end
		if token == resultsToken then
			HUDController.HideResults()
		end
	end)
end

function HUDController.SetCutscene(active: boolean)
	HUDController.CutsceneActive = active
	ui.Root.Visible = not active
end

-- crosshair = mouse cursor (GunController moves it every frame; nil hides it)
function HUDController.SetCrosshair(screenPosition: Vector2?)
	if screenPosition then
		ui.Crosshair.Visible = true
		ui.Crosshair.Position = UDim2.fromOffset(screenPosition.X, screenPosition.Y)
	else
		ui.Crosshair.Visible = false
	end
end

-- status line (eliminated / spectating) ---------------------------------------

function HUDController.SetStatus(text: string?)
	ui.Status.Visible = text ~= nil
	if text then
		ui.Status.Text = text
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
		ui.LowHealth.Visible = ratio > 0 and ratio < 0.3
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
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 8, 0.5, 0),
		Size = UDim2.fromOffset(110, 34),
		Parent = ui.CashFrame,
	})
	TweenService:Create(popup, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, 8, 0.5, -60),
		TextTransparency = 1,
	}):Play()
	TweenService:Create(popup:FindFirstChildOfClass("UIStroke"), TweenInfo.new(0.8), { Transparency = 1 }):Play()
	task.delay(0.85, function()
		popup:Destroy()
	end)
end

-- public ------------------------------------------------------------------

-- UI building blocks for other controllers (ShopController), so every panel looks the same.
HUDController.Kit = { Make = make, Label = label, Corner = corner, Stroke = stroke, Theme = THEME }

-- One container per screen edge/area, each with its own UIScale (scaled around its AnchorPoint,
-- capped at 1.0) so groups never push each other off screen.
local scales: { UIScale } = {}
rescale = function()
	local viewport = workspace.CurrentCamera.ViewportSize
	local s = math.clamp(math.min(viewport.Y / 1000, viewport.X / 1500), 0.55, 1)
	for _, uiScale in scales do
		uiScale.Scale = s
	end
end

function HUDController.CreateContainer(name: string, anchor: Vector2, position: UDim2, size: Vector2): Frame
	local frame = make("Frame", {
		Name = name,
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
		Parent = ui.Root,
	}) :: Frame
	local uiScale = make("UIScale", { Parent = frame }) :: UIScale
	table.insert(scales, uiScale)
	rescale()
	return frame
end

function HUDController.ShowHitmarker(killed: boolean)
	for _, bar in ui.HitBars do
		bar.BackgroundColor3 = if killed then THEME.Red else THEME.White
		bar.BackgroundTransparency = 0
		TweenService:Create(bar, TweenInfo.new(0.18), { BackgroundTransparency = 1 }):Play()
	end
end

local notifyToken = 0
local NOTIFY_SOUNDS = {
	info = "WaveStart",
	good = "WaveComplete",
	boss = "BossIncoming",
	gold = "Victory",
	bad = "Error",
}

-- Red full-screen flash + camera shake (boss entrance).
local function bossFlash()
	ui.Flash.Visible = true
	for _ = 1, 2 do
		ui.Flash.BackgroundTransparency = 0.45
		TweenService:Create(ui.Flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		task.spawn(Effects.Shake, 2)
		task.wait(0.45)
	end
	ui.Flash.Visible = false
end

function HUDController.Notify(text: string, kind: string?)
	Effects.PlaySound(NOTIFY_SOUNDS[kind or "info"] or "WaveStart")
	if kind == "boss" then
		task.spawn(bossFlash)
	end
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

	local container = HUDController.CreateContainer
	local top = container("Top", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 12), Vector2.new(600, 210))
	local bottom = container("Bottom", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -12), Vector2.new(320, 160))
	local ammoRoot = container("AmmoCorner", Vector2.new(1, 1), UDim2.new(1, -16, 1, -16), Vector2.new(170, 76))

	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	buildCountdown(root) -- first, so it sits under everything else

	-- full-screen red flash (boss entrance)
	ui.Flash = make("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.Red, BackgroundTransparency = 1, ZIndex = 0, Visible = false, Parent = root })

	-- low health: red glow fading in from all four screen edges, pulsing
	local lowHealth = make("Frame", { Name = "LowHealth", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0, Visible = false, Parent = root })
	for _, edge in {
		{ UDim2.fromScale(1, 0.18), UDim2.fromScale(0, 0), 90 },
		{ UDim2.fromScale(1, 0.18), UDim2.fromScale(0, 0.82), -90 },
		{ UDim2.fromScale(0.12, 1), UDim2.fromScale(0, 0), 0 },
		{ UDim2.fromScale(0.12, 1), UDim2.fromScale(0.88, 0), 180 },
	} do
		local frame = make("Frame", { Size = edge[1], Position = edge[2], BackgroundColor3 = Color3.fromRGB(220, 0, 0), BorderSizePixel = 0, ZIndex = 0, Parent = lowHealth })
		make("UIGradient", { Rotation = edge[3], Transparency = NumberSequence.new(0.35, 1), Parent = frame })
	end
	ui.LowHealth = lowHealth
	task.spawn(function()
		while true do
			if lowHealth.Visible then
				for _, frame in lowHealth:GetChildren() do
					local gradient = frame:FindFirstChildOfClass("UIGradient")
					local strong = math.floor(os.clock() * 2) % 2 == 0
					gradient.Transparency = NumberSequence.new(if strong then 0.25 else 0.5, 1)
				end
			end
			task.wait(0.5)
		end
	end)
	buildCrosshair(root)
	buildWaveBanner(top)
	buildBottom(bottom, ammoRoot)
	buildBossBar(top)
	buildNotification(top)
	buildResults(container("Results", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), Vector2.new(440, 400)))
	rescale()
	ui.Status = label({
		Name = "Status",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.66),
		Size = UDim2.fromOffset(620, 34),
		TextColor3 = Color3.fromRGB(255, 120, 120),
		Visible = false,
		Parent = root,
	})

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
		if name == "MatchState" or name == "Wave" or name == "WaveKills" or name == "WaveTotal" or name == "Countdown" then
			refreshWave()
			refreshCountdown()
		end
		if name == "BossHealth" or name == "BossMaxHealth" or name == "BossName" then
			refreshBoss()
		end
		if name == "MatchState" and workspace:GetAttribute("MatchState") == "Intermission" then
			HUDController.HideResults() -- new match started
		end
	end)
	Remotes.Get("Notify").OnClientEvent:Connect(HUDController.Notify)
	Remotes.Get("MatchResult").OnClientEvent:Connect(HUDController.ShowResults)

	player.CharacterAdded:Connect(watchHealth)
	if player.Character then
		task.spawn(watchHealth, player.Character)
	end

	refreshCash()
	refreshWeapon()
	refreshWave()
	refreshCountdown()
	refreshBoss()
end

return HUDController
