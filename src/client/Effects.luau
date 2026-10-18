--!nonstrict
-- Client-only visual effects. Nothing here affects gameplay; the server never sees these parts.

local Debris = game:GetService("Debris")
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

-- Sound hook: plug SoundIds in later (Phase 5). Kept as a no-op so callers don't change.
function Effects.PlaySound(_name: string, _position: Vector3?) end

return Effects
