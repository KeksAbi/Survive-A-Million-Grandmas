--!nonstrict
-- Client-only visual effects. Nothing here affects gameplay; the server never sees these parts.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Effects = {}

local folder = Instance.new("Folder")
folder.Name = "ClientEffects"
folder.Parent = workspace
Effects.Folder = folder

local function fxPart(size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	if shape then
		part.Shape = shape
	end
	part.Parent = folder
	return part
end

local function fadeOut(instance: Instance, seconds: number, goal: { [string]: any })
	TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(instance, seconds + 0.05)
end

function Effects.Trail(from: Vector3, to: Vector3, color: Color3?)
	local length = (to - from).Magnitude
	if length < 0.1 then
		return
	end
	local part = fxPart(Vector3.new(0.12, 0.12, length), CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2), color or Color3.fromRGB(255, 220, 120))
	part.Transparency = 0.2
	fadeOut(part, 0.12, { Transparency = 1, Size = Vector3.new(0.02, 0.02, length) })
end

function Effects.MuzzleFlash(position: Vector3)
	local part = fxPart(Vector3.new(0.9, 0.9, 0.9), CFrame.new(position), Color3.fromRGB(255, 210, 90), Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 100)
	light.Range = 8
	light.Brightness = 3
	light.Parent = part
	fadeOut(part, 0.06, { Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2) })
end

function Effects.HitSpark(position: Vector3)
	local part = fxPart(Vector3.new(0.4, 0.4, 0.4), CFrame.new(position), Color3.fromRGB(255, 140, 60), Enum.PartType.Ball)
	fadeOut(part, 0.18, { Transparency = 1, Size = Vector3.new(1.6, 1.6, 1.6) })
end

-- Cartoon "poof" where a grandma disappeared.
function Effects.DeathPuff(position: Vector3)
	for i = 1, 6 do
		local offset = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5) * 4
		local part = fxPart(Vector3.new(1.4, 1.4, 1.4), CFrame.new(position + Vector3.new(0, 1, 0)), if i % 2 == 0 then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(255, 170, 220), Enum.PartType.Ball)
		part.Material = Enum.Material.SmoothPlastic
		fadeOut(part, 0.45, { Transparency = 1, Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(position + offset + Vector3.new(0, 2, 0)) })
	end
end

-- Floating "-25" above the hit point. The killing blow shows a bigger "POOF!".
function Effects.DamageNumber(position: Vector3, amount: number, killed: boolean)
	local anchor = fxPart(Vector3.new(0.1, 0.1, 0.1), CFrame.new(position + Vector3.new(math.random() - 0.5, 1, math.random() - 0.5)), Color3.new(1, 1, 1))
	anchor.Transparency = 1

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 50)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	-- killing blow: "POOF!" in pink instead of a number, so it isn't mistaken for a critical hit
	label.Text = if killed then "POOF!" else "-" .. tostring(amount)
	label.TextScaled = true
	label.TextColor3 = if killed then Color3.fromRGB(255, 120, 200) else Color3.fromRGB(255, 235, 90)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	if killed then
		gui.Size = UDim2.fromOffset(160, 64)
	end

	fadeOut(anchor, 0.7, { CFrame = anchor.CFrame + Vector3.new(0, 3, 0) })
	TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
end

-- Moves `part` along an arc from `from` to `to` over `seconds` (apex `height` above the straight line),
-- spinning it. Calls onDone when it lands.
local function flyArc(part: BasePart, from: Vector3, to: Vector3, seconds: number, height: number, spin: number, onDone: (() -> ())?)
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / seconds, 1)
		local position = from:Lerp(to, t) + Vector3.new(0, 4 * height * t * (1 - t), 0)
		part.CFrame = CFrame.new(position) * CFrame.Angles(t * spin, t * spin * 0.6, 0)
		if t >= 1 then
			connection:Disconnect()
			if onDone then
				onDone()
			end
		end
	end)
end

-- Pink fluffy slipper thrown by a Slipper Grandma.
function Effects.Slipper(from: Vector3, to: Vector3, flightTime: number)
	local slipper = fxPart(Vector3.new(0.7, 0.35, 1.4), CFrame.new(from), Color3.fromRGB(255, 110, 190))
	slipper.Material = Enum.Material.SmoothPlastic
	local fluff = fxPart(Vector3.new(0.8, 0.4, 0.45), CFrame.new(from), Color3.fromRGB(255, 205, 235))
	fluff.Material = Enum.Material.SmoothPlastic
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = slipper
	weld.Part1 = fluff
	fluff.Anchored = false
	fluff.CFrame = slipper.CFrame * CFrame.new(0, 0.25, -0.35)
	weld.Parent = slipper
	flyArc(slipper, from, to, flightTime, math.max(2, (to - from).Magnitude * 0.12), math.pi * 6, function()
		Effects.HitSpark(to)
		slipper:Destroy()
	end)
	Debris:AddItem(slipper, flightTime + 1)
end

-- Grenade: flies in an arc, then sits on the ground blinking red until the server's explosion.
function Effects.Grenade(from: Vector3, landing: Vector3, flightTime: number, fuse: number)
	local grenade = fxPart(Vector3.new(1, 1, 1), CFrame.new(from), Color3.fromRGB(70, 110, 50), Enum.PartType.Ball)
	grenade.Material = Enum.Material.SmoothPlastic
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 40, 40)
	light.Range = 8
	light.Enabled = false
	light.Parent = grenade
	flyArc(grenade, from, landing, flightTime, 7, math.pi * 4, function()
		task.spawn(function()
			while grenade.Parent do
				light.Enabled = not light.Enabled
				grenade.Color = if light.Enabled then Color3.fromRGB(255, 70, 70) else Color3.fromRGB(70, 110, 50)
				task.wait(0.15)
			end
		end)
	end)
	Debris:AddItem(grenade, fuse)
end

local function shakeCamera(position: Vector3, strength: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local closeness = 1 - math.clamp((root.Position - position).Magnitude / 60, 0, 1)
	if closeness <= 0 then
		return
	end
	local camera = workspace.CurrentCamera
	for i = 1, 6 do
		local power = strength * closeness * (1 - i / 7)
		camera.CFrame *= CFrame.Angles(math.rad(math.random(-10, 10) / 10 * power), math.rad(math.random(-10, 10) / 10 * power), 0)
		task.wait()
	end
end

-- Cartoon explosion: orange fireball, white flash, grey smoke puffs, light camera shake nearby.
function Effects.Explosion(position: Vector3, radius: number)
	local ball = fxPart(Vector3.new(2, 2, 2), CFrame.new(position), Color3.fromRGB(255, 150, 40), Enum.PartType.Ball)
	fadeOut(ball, 0.45, { Size = Vector3.one * radius * 1.6, Transparency = 1 })
	local flash = fxPart(Vector3.new(1, 1, 1), CFrame.new(position), Color3.fromRGB(255, 255, 220), Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Range = radius * 2
	light.Brightness = 5
	light.Color = Color3.fromRGB(255, 180, 90)
	light.Parent = flash
	fadeOut(flash, 0.2, { Size = Vector3.one * radius, Transparency = 1 })
	for _ = 1, 8 do
		local offset = Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5) * radius
		local smoke = fxPart(Vector3.new(3, 3, 3), CFrame.new(position), Color3.fromRGB(110, 105, 100), Enum.PartType.Ball)
		smoke.Material = Enum.Material.SmoothPlastic
		smoke.Transparency = 0.2
		fadeOut(smoke, 0.9, { Size = Vector3.one * 6, Transparency = 1, CFrame = CFrame.new(position + offset + Vector3.new(0, 3, 0)) })
	end
	Effects.PlaySound("Explosion", position)
	task.spawn(shakeCamera, position, 1.2)
end

-- Flat ring on the ground (cylinder lying flat).
local function groundRing(position: Vector3, diameter: number, color: Color3): Part
	local ring = fxPart(Vector3.new(0.2, diameter, diameter), CFrame.new(position.X, 0.15, position.Z) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
	return ring
end

-- MEGA GRANDMA stomp warning: a pulsing red circle that shows where the stomp will hit.
function Effects.StompWarning(position: Vector3, radius: number, seconds: number)
	local ring = groundRing(position, radius * 2, Color3.fromRGB(255, 40, 40))
	ring.Transparency = 0.7
	TweenService:Create(ring, TweenInfo.new(seconds / 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.35 }):Play()
	Debris:AddItem(ring, seconds)
end

-- MEGA GRANDMA stomp: an expanding shockwave ring and a hard camera shake nearby.
function Effects.Stomp(position: Vector3, radius: number)
	local ring = groundRing(position, 4, Color3.fromRGB(255, 220, 160))
	ring.Transparency = 0.2
	fadeOut(ring, 0.45, { Size = Vector3.new(0.2, radius * 2.2, radius * 2.2), Transparency = 1 })
	Effects.PlaySound("Stomp", position)
	task.spawn(shakeCamera, position, 2.5)
end

-- Sound hook: plug SoundIds in later (Phase 5). Kept as a no-op so callers don't change.
function Effects.PlaySound(_name: string, _position: Vector3?) end

return Effects
