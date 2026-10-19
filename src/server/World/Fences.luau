--!nonstrict
-- Comic-style fences: white Picket, brown Board (backyard privacy), short decorative Iron, rustic Park
-- post-and-rail, low garden Border, and a striped road-closed Barricade. Each runs from `from` to `to`
-- (ground points). All parts are decoration (no collision, no raycasts): fences inside the arena are short
-- pieces that MapBuilder backs with round enemy obstacles, never long walls that could trap grandmas.
-- The outline group draws the thick silhouette; ink parts mark the thinner lines between boards and rails.

local ComicKit = require(script.Parent.ComicKit)

local K = ComicKit
local C = ComicKit.Colors

local Fences = {}

local IRON = Color3.fromRGB(40, 40, 48)
local BOARD = Color3.fromRGB(150, 95, 55)
local ORANGE = Color3.fromRGB(255, 120, 30)

-- Square post with a cap and a little spire on top.
function Fences.Post(parent: Instance, position: Vector3, height: number, color: Color3)
	local base = CFrame.new(position)
	K.Block(parent, Vector3.new(0.9, height, 0.9), base * CFrame.new(0, height / 2, 0), color, true)
	K.Block(parent, Vector3.new(1.25, 0.3, 1.25), base * CFrame.new(0, height + 0.15, 0), color, true)
	K.Spire(parent, 0.8, 0.6, base * CFrame.new(0, height + 0.3, 0), color, true)
end

-- White picket fence: two rails and pointed pickets every `spacing` studs.
function Fences.Picket(parent: Instance, from: Vector3, to: Vector3, spacing: number, height: number, color: Color3?)
	local white = color or C.Trim
	local length = (to - from).Magnitude
	local frame = CFrame.lookAt(from, to)
	for _, y in { height * 0.3, height * 0.72 } do
		K.Block(parent, Vector3.new(0.25, 0.4, length), frame * CFrame.new(0, y, -length / 2), white, true)
	end
	local along = spacing / 2
	while along < length do
		local at = frame * CFrame.new(-0.25, 0, -along)
		K.Block(parent, Vector3.new(0.3, height, 0.75), at * CFrame.new(0, height / 2, 0), white, true)
		K.Block(parent, Vector3.new(0.3, 0.55, 0.55), at * CFrame.new(0, height, 0) * CFrame.Angles(math.pi / 4, 0, 0), white, true)
		along += spacing
	end
end

-- Brown backyard privacy fence: posts every ~8 studs, solid board panels with inked plank lines, a top rail.
function Fences.Board(parent: Instance, from: Vector3, to: Vector3, height: number)
	local length = (to - from).Magnitude
	local frame = CFrame.lookAt(from, to)
	local sections = math.max(1, math.round(length / 8))
	local step = length / sections
	for i = 0, sections do
		local post = frame * CFrame.new(0, 0, -i * step)
		K.Block(parent, Vector3.new(0.7, height + 0.4, 0.7), post * CFrame.new(0, (height + 0.4) / 2, 0), K.Dark(BOARD), true)
		K.Block(parent, Vector3.new(0.9, 0.2, 0.9), post * CFrame.new(0, height + 0.5, 0), K.Dark(BOARD), true)
		if i < sections then
			local mid = frame * CFrame.new(0, 0, -(i + 0.5) * step)
			K.Block(parent, Vector3.new(0.3, height - 0.3, step - 0.7), mid * CFrame.new(0, 0.15 + (height - 0.3) / 2, 0), BOARD, true)
			K.Block(parent, Vector3.new(0.5, 0.25, step - 0.7), mid * CFrame.new(0, height - 0.05, 0), K.Light(BOARD), true)
			for z = -step / 2 + 1.5, step / 2 - 1.2, 1.6 do
				K.Block(parent, Vector3.new(0.36, height - 0.6, 0.07), mid * CFrame.new(0, 0.15 + (height - 0.3) / 2 - 0.1, z), C.Ink, true)
			end
		end
	end
end

-- Short decorative wrought-iron fence: posts with diamond finials, two rails, spear-tipped bars.
function Fences.Iron(parent: Instance, from: Vector3, to: Vector3, height: number?)
	local h = height or 2.6
	local length = (to - from).Magnitude
	local frame = CFrame.lookAt(from, to)
	for _, y in { 0.35, h - 0.25 } do
		K.Block(parent, Vector3.new(0.15, 0.15, length), frame * CFrame.new(0, y, -length / 2), IRON, true)
	end
	local sections = math.max(1, math.round(length / 6))
	for i = 0, sections do
		local post = frame * CFrame.new(0, 0, -i * length / sections)
		K.Block(parent, Vector3.new(0.35, h + 0.3, 0.35), post * CFrame.new(0, (h + 0.3) / 2, 0), IRON, true)
		K.Block(parent, Vector3.one * 0.4, post * CFrame.new(0, h + 0.45, 0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), IRON, true)
	end
	for along = 0.9, length - 0.4, 0.9 do
		local bar = frame * CFrame.new(0, 0, -along)
		K.Block(parent, Vector3.new(0.1, h - 0.1, 0.1), bar * CFrame.new(0, (h - 0.1) / 2, 0), IRON, true)
		K.Block(parent, Vector3.new(0.08, 0.22, 0.22), bar * CFrame.new(0, h, 0) * CFrame.Angles(math.pi / 4, 0, 0), IRON, true)
	end
end

-- Small rustic park fence: low pointed wooden posts and two log rails.
function Fences.Park(parent: Instance, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local frame = CFrame.lookAt(from, to)
	for _, y in { 0.55, 1.15 } do
		K.Block(parent, Vector3.new(0.28, 0.28, length), frame * CFrame.new(0, y, -length / 2), C.WoodLight, true)
	end
	local sections = math.max(1, math.round(length / 2.6))
	for i = 0, sections do
		local post = frame * CFrame.new(0, 0, -i * length / sections)
		K.Block(parent, Vector3.new(0.45, 1.4, 0.45), post * CFrame.new(0, 0.7, 0), C.Wood, true)
		K.Spire(parent, 0.45, 0.3, post * CFrame.new(0, 1.4, 0), C.Wood, true)
	end
end

-- Low garden border fence along a flower bed: little posts every stud, two thin rails.
function Fences.Border(parent: Instance, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local frame = CFrame.lookAt(from, to)
	for _, y in { 0.35, 0.7 } do
		K.Block(parent, Vector3.new(0.1, 0.1, length), frame * CFrame.new(0, y, -length / 2), C.Trim, true)
	end
	local count = math.max(1, math.round(length))
	for i = 0, count do
		K.Block(parent, Vector3.new(0.14, 0.9, 0.14), frame * CFrame.new(0, 0.45, -i * length / count), C.Trim, true)
	end
end

-- Striped road-closed barricade across a street: sawhorse legs, two boards with orange diagonal stripes and a
-- ROAD CLOSED sign in the middle facing `facing`.
function Fences.Barricade(parent: Instance, from: Vector3, to: Vector3, facing: Vector3)
	local length = (to - from).Magnitude
	local frame = CFrame.lookAt(from, to)
	local legs = math.max(2, math.round(length / 5.5) + 1)
	for i = 0, legs - 1 do
		local at = frame * CFrame.new(0, 0, -(0.4 + i * (length - 0.8) / (legs - 1)))
		for _, s in { -1, 1 } do
			K.Block(parent, Vector3.new(0.25, 2.8, 0.25), at * CFrame.new(s * 0.45, 1.3, 0) * CFrame.Angles(0, 0, s * 0.3), C.Wood, true)
		end
	end
	for _, y in { 1.6, 2.4 } do
		K.Block(parent, Vector3.new(0.15, 0.6, length), frame * CFrame.new(0, y, -length / 2), C.Trim, true)
		for along = 0.6, length - 0.5, 1.4 do
			K.Block(parent, Vector3.new(0.17, 0.25, 0.9), frame * CFrame.new(0, y, -along) * CFrame.Angles(math.rad(-40), 0, 0), ORANGE, true)
		end
	end
	local middle = (from + to) / 2 + Vector3.new(0, 3.4, 0)
	local sign = K.Panel(parent, 4.4, 1.2, CFrame.lookAt(middle, middle + facing), ORANGE, 0.12, 0.1)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "ROAD CLOSED"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = C.Ink
	label.Parent = gui
end

return Fences
