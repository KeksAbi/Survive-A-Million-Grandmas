--!nonstrict
-- MEGA GRANDMA intro cutscene (~7 s, on every screen at once). The server freezes all enemies and shields
-- the players for Config.Boss.CutsceneSeconds, so nothing happens to you while the camera is away.
--   0.0  black: "SOMETHING IS COMING..."; cinema bars, the sky turns to a red dusk
--   0.5  low camera at her feet: the ground rumbles and she rises out of it, shockwave
--   3.0  camera circles her in the dark: lightning flashes, glowing red eyes
--   4.8  close-up on her face: "MEGA GRANDMA - THE ROLLING PIN OF DOOM" slams in
--   6.4  fade to black, back to the game
-- Everything here is local and visual (camera, lighting, the boss rising); the server state is untouched.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local EnemyDefinitions = require(ReplicatedStorage:WaitForChild("Shared").EnemyDefinitions)

local Effects = require(script.Parent.Parent.Effects)
local HUDController = require(script.Parent.HUDController)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local BossCutsceneController = {}

local playing = false

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function findBoss(enemyId: number): Model?
	local deadline = os.clock() + 2
	while os.clock() < deadline do
		local folder = workspace:FindFirstChild("Enemies")
		if folder then
			for _, model in folder:GetChildren() do
				if model:GetAttribute("EnemyId") == enemyId then
					return model
				end
			end
		end
		task.wait(0.05)
	end
	return nil
end

local function setControls(enabled: boolean)
	pcall(function()
		-- PlayerModule is Roblox's built-in control/camera module (inserted at runtime)
		local playerModule = (require :: any)(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		local controls = playerModule:GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

local function textLabel(parent: Instance, text: string, position: UDim2, size: UDim2, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	label.ZIndex = 5
	label.Parent = parent
	return label
end

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossCutscene"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")

	local function fullFrame(color: Color3, z: number): Frame
		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = color
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.ZIndex = z
		frame.Parent = gui
		return frame
	end

	local ui = {}
	ui.Gui = gui
	ui.Flash = fullFrame(Color3.new(1, 1, 1), 2)
	ui.Black = fullFrame(Color3.new(0, 0, 0), 4)
	for _, name in { "TopBar", "BottomBar" } do
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(1, 0.13)
		bar.Position = if name == "TopBar" then UDim2.fromScale(0, -0.13) else UDim2.fromScale(0, 1)
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.ZIndex = 3
		bar.Parent = gui
		ui[name] = bar
	end
	ui.Whisper = textLabel(gui, "SOMETHING IS COMING...", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.6, 0.07), Color3.fromRGB(200, 200, 210))
	ui.Title = textLabel(gui, "MEGA GRANDMA", UDim2.fromScale(0.5, 0.72), UDim2.fromScale(0.8, 0.16), Color3.fromRGB(235, 25, 25))
	ui.Subtitle = textLabel(gui, "THE ROLLING PIN OF DOOM", UDim2.fromScale(0.5, 0.84), UDim2.fromScale(0.55, 0.055), Color3.fromRGB(255, 225, 225))
	return ui
end

-- Dusk + red grade; returns a function that restores the original lighting.
local function darkenWorld(): () -> ()
	local original = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Ambient = Lighting.Ambient,
	}
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "BossCutsceneGrade"
	grade.Parent = Lighting
	tween(grade, 1.2, { TintColor = Color3.fromRGB(255, 150, 150), Contrast = 0.3, Saturation = -0.25, Brightness = -0.05 })
	tween(Lighting, 1.2, { ClockTime = 18.6, Brightness = 0.8, OutdoorAmbient = Color3.fromRGB(90, 35, 40), Ambient = Color3.fromRGB(60, 25, 30) })
	return function()
		tween(Lighting, 0.8, original)
		tween(grade, 0.8, { TintColor = Color3.new(1, 1, 1), Contrast = 0, Saturation = 0, Brightness = 0 })
		task.delay(0.9, function()
			grade:Destroy()
		end)
	end
end

-- Red point lights in the boss's eyes (she glows in the dark). Returns a cleanup function.
local function lightEyes(boss: Model): () -> ()
	local lights = {}
	for _, part in boss:GetChildren() do
		if part.Name == "Eye" and part:IsA("BasePart") then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 30, 30)
			light.Range = 14
			light.Brightness = 6
			light.Parent = part
			table.insert(lights, light)
		end
	end
	return function()
		for _, light in lights do
			light:Destroy()
		end
	end
end

local function lightning(ui)
	ui.Flash.BackgroundTransparency = 0.15
	tween(ui.Flash, 0.35, { BackgroundTransparency = 1 })
	Effects.PlaySound("Thunder")
end

function BossCutsceneController.Play(enemyId: number, seconds: number)
	if playing then
		return
	end
	local boss = findBoss(enemyId)
	if not boss then
		return -- model never arrived: skip the show, gameplay is unaffected
	end
	playing = true

	local def = EnemyDefinitions[tostring(boss:GetAttribute("EnemyType"))] or { RootHeight = 12 }
	local home = boss:GetPivot() -- where the server placed her
	local look = Vector3.new(home.LookVector.X, 0, home.LookVector.Z).Unit
	local ground = home.Position - Vector3.new(0, def.RootHeight, 0)
	local headHeight = def.RootHeight + 8 -- head center above the ground at scale 4

	local ui = buildGui()
	local savedCamera = camera.CFrame
	HUDController.SetCutscene(true)
	setControls(false)
	camera.CameraType = Enum.CameraType.Scriptable
	local restoreWorld = darkenWorld()
	local restoreEyes = lightEyes(boss)
	local root = boss:FindFirstChild("Root")
	local overheadBar = root and root:FindFirstChild("BossBar")
	if overheadBar then
		overheadBar.Enabled = false -- no health bar in the movie
	end

	-- opening: bars in, black with the whisper
	tween(ui.TopBar, 0.6, { Position = UDim2.fromScale(0, 0) })
	tween(ui.BottomBar, 0.6, { Position = UDim2.fromScale(0, 0.87) })
	ui.Black.BackgroundTransparency = 0
	tween(ui.Whisper, 0.3, { TextTransparency = 0, TextStrokeTransparency = 0.4 })

	local rise = 1 -- 1 = fully underground, 0 = standing
	local shake = 0
	local start = os.clock()
	local events = {
		{ 0.35, function()
			tween(ui.Whisper, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
			tween(ui.Black, 0.5, { BackgroundTransparency = 1 })
		end },
		{ 0.9, function()
			Effects.PlaySound("Rumble")
		end },
		{ 2.7, function() -- she's out: shockwave
			Effects.Stomp(ground, 24)
			Effects.Explosion(ground + Vector3.new(0, 1, 0), 10)
			shake = 3
		end },
		{ 3.3, function()
			lightning(ui)
			shake = math.max(shake, 1.5)
		end },
		{ 4.2, function()
			lightning(ui)
			shake = math.max(shake, 1.5)
		end },
		{ 5.0, function() -- title slam
			ui.Title.Size = UDim2.fromScale(1.4, 0.3)
			ui.Title.TextTransparency = 0
			ui.Title.TextStrokeTransparency = 0
			tween(ui.Title, 0.35, { Size = UDim2.fromScale(0.8, 0.16) }, Enum.EasingStyle.Back)
			Effects.PlaySound("BossRoar")
			shake = 3.5
		end },
		{ 5.35, function()
			tween(ui.Subtitle, 0.4, { TextTransparency = 0, TextStrokeTransparency = 0.3 })
		end },
		{ seconds - 0.6, function()
			tween(ui.Black, 0.4, { BackgroundTransparency = 0 })
		end },
	}
	local nextEvent = 1

	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - start
		while events[nextEvent] and t >= events[nextEvent][1] do
			events[nextEvent][2]()
			nextEvent += 1
		end

		-- boss rising out of the ground (local only; the server froze her in place)
		if t >= 0.9 and t <= 2.7 then
			local p = (t - 0.9) / 1.8
			rise = 1 - (1 - (1 - p) ^ 3) -- ease out
			shake = math.max(shake, 0.6)
		elseif t > 2.7 then
			rise = 0
		end
		local jitter = if rise > 0 and rise < 1 then Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.6 else Vector3.zero
		boss:PivotTo(home + Vector3.new(0, -rise * (def.RootHeight * 2 + 4), 0) + jitter)

		-- camera shots
		local cameraCFrame
		if t < 3.0 then
			-- shot 1: low at her feet, looking up as she rises
			local p = math.clamp((t - 0.5) / 2.5, 0, 1)
			local position = ground + look * (18 - 5 * p) + Vector3.new(0, 1.5 + p, 0)
			local target = ground + Vector3.new(0, 4 + (1 - rise) * (headHeight - 4), 0)
			cameraCFrame = CFrame.lookAt(position, target)
		elseif t < 4.8 then
			-- shot 2: slow circle around her in the dark
			local p = (t - 3.0) / 1.8
			local angle = math.rad(-70 + 110 * p)
			local side = Vector3.new(-look.Z, 0, look.X)
			local offset = (look * math.cos(angle) + side * math.sin(angle)) * 34
			cameraCFrame = CFrame.lookAt(ground + offset + Vector3.new(0, 6 + 10 * p, 0), ground + Vector3.new(0, headHeight - 4, 0))
		else
			-- shot 3: close-up on the face, pushing in slowly
			local p = math.clamp((t - 4.8) / 1.6, 0, 1)
			local head = ground + Vector3.new(0, headHeight, 0)
			cameraCFrame = CFrame.lookAt(head + look * (17 - 6 * p) + Vector3.new(0, 0.5, 0), head - Vector3.new(0, 1, 0))
		end
		if shake > 0 then
			local s = math.rad(shake)
			cameraCFrame *= CFrame.Angles((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
			shake = math.max(0, shake - dt * 4)
		end
		camera.CFrame = cameraCFrame

		if t >= seconds then
			connection:Disconnect()
			-- back to the game
			boss:PivotTo(home)
			restoreEyes()
			if overheadBar then
				overheadBar.Enabled = true
			end
			restoreWorld()
			camera.CFrame = savedCamera
			camera.CameraType = Enum.CameraType.Custom
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				camera.CameraSubject = humanoid
			end
			setControls(true)
			HUDController.SetCutscene(false)
			tween(ui.TopBar, 0.4, { Position = UDim2.fromScale(0, -0.13) })
			tween(ui.BottomBar, 0.4, { Position = UDim2.fromScale(0, 1) })
			tween(ui.Title, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
			tween(ui.Subtitle, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
			tween(ui.Black, 0.5, { BackgroundTransparency = 1 })
			task.delay(0.6, function()
				ui.Gui:Destroy()
			end)
			playing = false
		end
	end)
end

return BossCutsceneController
