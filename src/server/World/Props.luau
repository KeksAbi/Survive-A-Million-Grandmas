--!nonstrict
-- Comic-style prop models for the map (street furniture, yard decorations, landmarks), built from
-- ComicKit parts. Every builder takes a parent and a CFrame/position on the ground; a CFrame's LookVector is
-- the prop's front. Builders only make geometry: MapBuilder places them and registers enemy obstacles.

local Architecture = require(script.Parent.Architecture)
local ComicKit = require(script.Parent.ComicKit)

local K = ComicKit
local C = ComicKit.Colors

local Props = {}

-- Turns a CFrame on a box's +X (side = 1) or -X (side = -1) wall so its LookVector points out of that wall.
local function sideFacing(side: number): CFrame
	return if side == 1 then Architecture.Face.Right else Architecture.Face.Left
end

------------------------------------------------------------------------------------------- street props

-- Classic street lamp: plinth, eight-sided pole with a ring, lantern with ink corner bars and a spire cap.
function Props.Lamp(parent: Instance, position: Vector3): Model
	local model = K.Model("StreetLamp")
	local dark = C.MetalDark
	local function at(y: number): CFrame
		return CFrame.new(position + Vector3.new(0, y, 0))
	end
	K.Block(model, Vector3.new(1.5, 1.2, 1.5), at(0.6), dark)
	K.Block(model, Vector3.new(0.45, 10, 0.45), at(6.2), dark)
	K.Block(model, Vector3.new(0.45, 10, 0.45), at(6.2) * CFrame.Angles(0, math.pi / 4, 0), dark, true)
	K.Block(model, Vector3.new(0.8, 0.35, 0.8), at(3.4) * CFrame.Angles(0, math.pi / 4, 0), dark, true)
	K.Block(model, Vector3.new(1.6, 0.3, 1.6), at(11.3), dark, true)
	local glass = K.Block(model, Vector3.new(1.1, 1.5, 1.1), at(12.2), Color3.fromRGB(255, 232, 160), true)
	glass.Material = Enum.Material.Neon
	for _, x in { -0.55, 0.55 } do
		for _, z in { -0.55, 0.55 } do
			K.Ink(model, Vector3.new(0.18, 1.5, 0.18), at(12.2) * CFrame.new(x, 0, z))
		end
	end
	K.Spire(model, 1.9, 1.1, at(12.95), dark, true)
	K.Block(model, Vector3.one * 0.35, at(14.15) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), dark, true)
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 225, 170)
	light.Parent = glass
	model.Parent = parent
	return model
end

-- Park bench: three seat planks, tilted backrest, cast-iron sides with armrests. Sitter faces LookVector.
function Props.Bench(parent: Instance, cframe: CFrame): Model
	local model = K.Model("Bench")
	local iron = C.MetalDark
	for _, z in { -0.55, 0, 0.55 } do
		K.Block(model, Vector3.new(6, 0.25, 0.45), cframe * CFrame.new(0, 1.65, z), C.Wood)
	end
	for _, y in { 2.35, 2.95 } do
		K.Block(model, Vector3.new(6, 0.45, 0.18), cframe * CFrame.new(0, y, 0.95) * CFrame.Angles(math.rad(10), 0, 0), C.Wood, true)
	end
	for _, x in { -2.6, 2.6 } do
		K.Block(model, Vector3.new(0.3, 1.5, 0.3), cframe * CFrame.new(x, 0.75, -0.6), iron)
		K.Block(model, Vector3.new(0.3, 3.3, 0.3), cframe * CFrame.new(x, 1.65, 0.85) * CFrame.Angles(math.rad(10), 0, 0), iron)
		K.Block(model, Vector3.new(0.3, 0.25, 1.7), cframe * CFrame.new(x, 1.5, 0.1), iron, true)
		K.Block(model, Vector3.new(0.3, 0.25, 1.4), cframe * CFrame.new(x, 2.35, -0.1), iron, true)
		K.Block(model, Vector3.new(0.25, 0.85, 0.25), cframe * CFrame.new(x, 1.95, -0.7), iron, true)
	end
	model.Parent = parent
	return model
end

-- Eight-sided park trash can with ribs and a lid.
function Props.TrashCan(parent: Instance, position: Vector3): Model
	local model = K.Model("TrashCan")
	local green = Color3.fromRGB(60, 150, 90)
	local function at(y: number): CFrame
		return CFrame.new(position + Vector3.new(0, y, 0))
	end
	K.Block(model, Vector3.new(1.6, 2.4, 1.6), at(1.2), green)
	K.Block(model, Vector3.new(1.6, 2.4, 1.6), at(1.2) * CFrame.Angles(0, math.pi / 4, 0), green, true)
	for _, y in { 0.5, 2.0 } do
		K.Block(model, Vector3.new(1.75, 0.25, 1.75), at(y) * CFrame.Angles(0, math.pi / 8, 0), K.Dark(green), true)
	end
	K.Block(model, Vector3.new(1.95, 0.35, 1.95), at(2.55) * CFrame.Angles(0, math.pi / 8, 0), K.Dark(green), true)
	K.Block(model, Vector3.new(0.6, 0.3, 0.6), at(2.85), C.MetalDark, true)
	model.Parent = parent
	return model
end

-- Red fire hydrant: flange, eight-sided body, collar, yellow cap and three nozzles.
function Props.Hydrant(parent: Instance, cframe: CFrame): Model
	local model = K.Model("Hydrant")
	local red = Color3.fromRGB(220, 50, 45)
	K.Block(model, Vector3.new(1.3, 0.3, 1.3), cframe * CFrame.new(0, 0.15, 0), C.MetalDark)
	K.Block(model, Vector3.new(0.95, 1.9, 0.95), cframe * CFrame.new(0, 1.25, 0), red)
	K.Block(model, Vector3.new(0.95, 1.9, 0.95), cframe * CFrame.new(0, 1.25, 0) * CFrame.Angles(0, math.pi / 4, 0), red, true)
	K.Block(model, Vector3.new(1.2, 0.25, 1.2), cframe * CFrame.new(0, 2.1, 0) * CFrame.Angles(0, math.pi / 8, 0), K.Dark(red), true)
	K.Spire(model, 1.0, 0.6, cframe * CFrame.new(0, 2.22, 0), C.RoadLine, true)
	K.Block(model, Vector3.new(0.3, 0.3, 0.3), cframe * CFrame.new(0, 2.9, 0), C.Metal, true)
	for _, side in { -1, 1 } do
		K.Cylinder(model, Vector3.new(0.6, 0.5, 0.5), cframe * CFrame.new(side * 0.65, 1.5, 0), C.Metal, true)
	end
	K.Cylinder(model, Vector3.new(0.5, 0.7, 0.7), cframe * CFrame.new(0, 1.4, -0.6) * CFrame.Angles(0, math.pi / 2, 0), C.Metal, true)
	model.Parent = parent
	return model
end

-- Mailbox on a wooden post: box with a rounded top, door seam and a red flag. Door faces LookVector.
function Props.Mailbox(parent: Instance, cframe: CFrame, color: Color3): Model
	local model = K.Model("Mailbox")
	K.Block(model, Vector3.new(0.45, 3.2, 0.45), cframe * CFrame.new(0, 1.6, 0), C.Wood)
	K.Block(model, Vector3.new(1.1, 0.8, 1.9), cframe * CFrame.new(0, 3.55, 0), color, true)
	K.Cylinder(model, Vector3.new(1.9, 1.1, 1.1), cframe * CFrame.new(0, 3.95, 0) * CFrame.Angles(0, math.pi / 2, 0), color, true)
	K.Ink(model, Vector3.new(1.0, 0.1, 0.06), cframe * CFrame.new(0, 3.3, -0.97))
	K.Block(model, Vector3.new(0.08, 0.3, 0.8), cframe * CFrame.new(0.6, 3.7, 0.3), C.MetalDark, true)
	K.Block(model, Vector3.new(0.08, 0.7, 0.4), cframe * CFrame.new(0.6, 4.1, 0.6), Color3.fromRGB(230, 40, 40), true)
	model.Parent = parent
	return model
end

-- Text on a part's front (and optionally back) face.
local function label(part: BasePart, text: string, color: Color3, bothSides: boolean?)
	local faces = { Enum.NormalId.Front }
	if bothSides then
		table.insert(faces, Enum.NormalId.Back)
	end
	for _, face in faces do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = part
		local text3 = Instance.new("TextLabel")
		text3.Size = UDim2.fromScale(1, 1)
		text3.BackgroundTransparency = 1
		text3.Text = text
		text3.TextScaled = true
		text3.Font = Enum.Font.GothamBlack
		text3.TextColor3 = color
		text3.Parent = gui
	end
end

-- Regular octagon standing on a surface (`cf` LookVector = its front): a wide and a tall bar plus four corner
-- wedges. Returns the wide bar (for text).
local function octagon(parent: Instance, cf: CFrame, size: number, thick: number, color: Color3): BasePart
	local a = size / (1 + math.sqrt(2)) -- side length
	local first = K.Block(parent, Vector3.new(size, a, thick), cf, color, true)
	K.Block(parent, Vector3.new(a, size, thick), cf, color, true)
	local leg = (size - a) / 2
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			local dirA, dirB = Vector3.new(sx, 0, 0), Vector3.new(0, sy, 0)
			local center = Vector3.new(sx * a / 2, sy * a / 2, 0) + (dirA + dirB) * (leg / 2)
			K.Wedge(parent, Vector3.new(thick, leg, leg), cf * CFrame.fromMatrix(center, dirB:Cross(dirA), dirA, -dirB), color, true)
		end
	end
	return first
end

-- Stop sign with two crossed green street-name blades on top (names[1] along the sign's X, names[2] across).
-- Faces LookVector.
function Props.StopSign(parent: Instance, cframe: CFrame, names: { string }): Model
	local model = K.Model("StopSign")
	K.Block(model, Vector3.new(0.25, 9.4, 0.25), cframe * CFrame.new(0, 4.7, 0), C.Metal)
	local face = cframe * CFrame.new(0, 6.6, -0.2)
	octagon(model, face, 2.6, 0.08, C.Ink)
	octagon(model, face * CFrame.new(0, 0, -0.06), 2.4, 0.06, C.Trim)
	local red = octagon(model, face * CFrame.new(0, 0, -0.11), 2.15, 0.06, Color3.fromRGB(220, 30, 30))
	label(red, "STOP", C.Trim)
	local green = Color3.fromRGB(30, 130, 80)
	for i, name in names do
		local blade = cframe * CFrame.new(0, 8.6 + i * 0.75, 0) * CFrame.Angles(0, (i - 1) * math.pi / 2, 0)
		K.Block(model, Vector3.new(3.5, 0.72, 0.1), blade, C.Ink, true)
		local plate = K.Block(model, Vector3.new(3.3, 0.55, 0.14), blade, green, true)
		label(plate, name, C.Trim, true)
	end
	K.Block(model, Vector3.new(0.35, 0.3, 0.35), cframe * CFrame.new(0, 10.3, 0), C.Metal, true)
	model.Parent = parent
	return model
end

-- Tall cobra-head street light: plinth, two-step tapered pole, curved arm, head with a glowing lens.
-- The arm reaches toward LookVector.
function Props.StreetLight(parent: Instance, cframe: CFrame): Model
	local model = K.Model("StreetLight")
	local gray = C.Metal
	K.Block(model, Vector3.new(1.1, 0.8, 1.1), cframe * CFrame.new(0, 0.4, 0), C.Stone)
	K.Block(model, Vector3.new(0.55, 8, 0.55), cframe * CFrame.new(0, 4.6, 0), gray)
	K.Block(model, Vector3.new(0.42, 6.4, 0.42), cframe * CFrame.new(0, 11.8, 0), gray, true)
	local bend = (cframe * CFrame.new(0, 14.6, 0)).Position
	local tip = (cframe * CFrame.new(0, 15.4, -4.2)).Position
	local knee = (cframe * CFrame.new(0, 15.3, -1.2)).Position
	K.Block(model, Vector3.new(0.3, 0.3, (knee - bend).Magnitude + 0.2), CFrame.lookAt((bend + knee) / 2, knee), gray, true)
	K.Block(model, Vector3.new(0.3, 0.3, (tip - knee).Magnitude + 0.2), CFrame.lookAt((knee + tip) / 2, tip), gray, true)
	local head = CFrame.lookAt(tip, tip + (tip - knee)) * CFrame.new(0, 0, -0.9)
	K.Block(model, Vector3.new(1.0, 0.5, 2.2), head, gray, true)
	K.Wedge(model, Vector3.new(1.0, 0.3, 0.6), head * CFrame.new(0, 0.4, -0.8), gray, true)
	local lens = K.Block(model, Vector3.new(0.8, 0.12, 1.7), head * CFrame.new(0, -0.3, 0), Color3.fromRGB(255, 236, 170), true)
	lens.Material = Enum.Material.Neon
	K.Ink(model, Vector3.new(1.04, 0.08, 2.24), head * CFrame.new(0, -0.22, 0))
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Range = 24
	light.Angle = 100
	light.Brightness = 1.4
	light.Color = Color3.fromRGB(255, 225, 170)
	light.Parent = lens
	model.Parent = parent
	return model
end

-- Green utility box on a concrete pad: lid, door seam, vent slats, handle, warning sticker. Faces LookVector.
function Props.UtilityBox(parent: Instance, cframe: CFrame): Model
	local model = K.Model("UtilityBox")
	local green = Color3.fromRGB(70, 130, 90)
	K.Block(model, Vector3.new(3.2, 0.3, 2.0), cframe * CFrame.new(0, 0.15, 0), C.Stone)
	K.Block(model, Vector3.new(2.4, 3.0, 1.3), cframe * CFrame.new(0, 1.8, 0), green)
	K.Block(model, Vector3.new(2.6, 0.25, 1.5), cframe * CFrame.new(0, 3.4, 0), K.Dark(green), true)
	local front = cframe * CFrame.new(0, 0, -0.65)
	K.Ink(model, Vector3.new(0.06, 2.6, 0.06), front * CFrame.new(0, 1.8, -0.02))
	for i = 0, 2 do
		K.Ink(model, Vector3.new(0.8, 0.08, 0.06), front * CFrame.new(-0.65, 2.6 - i * 0.25, -0.02))
	end
	K.Block(model, Vector3.new(0.12, 0.5, 0.12), front * CFrame.new(0.25, 1.7, -0.08), C.Metal, true)
	K.Panel(model, 0.5, 0.4, front * CFrame.new(0.7, 2.6, 0), Color3.fromRGB(255, 205, 40), 0.06, 0.04)
	model.Parent = parent
	return model
end

-- Wooden planter box (`length` long along local X): plank walls with ink seams, darker corner posts, soil.
-- Returns the CFrame of the soil top center (for planting).
function Props.Planter(parent: Instance, cframe: CFrame, length: number): CFrame
	local w, h = 1.4, 1.1
	K.Block(parent, Vector3.new(length, h, w), cframe * CFrame.new(0, h / 2, 0), C.Wood, true)
	K.Block(parent, Vector3.new(length - 0.3, 0.08, w - 0.3), cframe * CFrame.new(0, h + 0.01, 0), Color3.fromRGB(116, 76, 46), true)
	for _, s in { -1, 1 } do
		K.Block(parent, Vector3.new(0.25, h + 0.1, w + 0.1), cframe * CFrame.new(s * (length / 2 - 0.1), (h + 0.1) / 2, 0), K.Dark(C.Wood), true)
		K.Ink(parent, Vector3.new(length - 0.4, 0.07, w + 0.04), cframe * CFrame.new(0, h * (0.5 + s * 0.17), 0))
	end
	return cframe * CFrame.new(0, h + 0.05, 0)
end

-- A cluster of decorative faceted rocks, half sunk into the ground.
function Props.Rocks(parent: Instance, position: Vector3, rng: Random, count: number)
	for i = 1, count do
		local angle = i * 2.4
		local size = rng:NextNumber(0.7, 1.5) * (if i == 1 then 1.3 else 1)
		local at = position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (if i == 1 then 0 else rng:NextNumber(0.8, 1.4)) + Vector3.new(0, size * 0.2, 0)
		K.Gem(parent, size, at, if i % 2 == 0 then C.Stone else K.Dark(C.Stone), rng, true)
	end
end

--------------------------------------------------------------------------------------------- yard decorations

-- Pink plastic lawn flamingo on wire legs (faces LookVector).
function Props.Flamingo(parent: Instance, cframe: CFrame): Model
	local model = K.Model("Flamingo")
	local pink = Color3.fromRGB(255, 120, 170)
	for _, x in { -0.15, 0.15 } do
		K.Block(model, Vector3.new(0.12, 2.2, 0.12), cframe * CFrame.new(x, 1.1, 0), C.Ink, true)
	end
	local body = cframe * CFrame.new(0, 2.6, 0.1) * CFrame.Angles(math.rad(-12), 0, 0)
	K.Block(model, Vector3.new(0.9, 0.8, 1.6), body, pink, true)
	K.Block(model, Vector3.new(0.7, 0.7, 1.3), body * CFrame.Angles(0, 0, math.pi / 4), pink, true)
	K.Wedge(model, Vector3.new(0.5, 0.5, 0.7), body * CFrame.new(0, 0.3, 1.0) * CFrame.Angles(0, math.pi, 0), K.Dark(pink), true)
	local neck, head = (cframe * CFrame.new(0, 3.9, -0.4)).Position, (cframe * CFrame.new(0, 4.6, -0.75)).Position
	local shoulder = (cframe * CFrame.new(0, 2.9, -0.6)).Position
	K.Block(model, Vector3.new(0.25, 0.25, (neck - shoulder).Magnitude + 0.2), CFrame.lookAt((shoulder + neck) / 2, neck), pink, true)
	K.Block(model, Vector3.new(0.25, 0.25, (head - neck).Magnitude + 0.2), CFrame.lookAt((neck + head) / 2, head), pink, true)
	K.Block(model, Vector3.new(0.4, 0.4, 0.6), cframe * CFrame.new(0, 4.7, -0.95), pink, true)
	K.Block(model, Vector3.new(0.18, 0.18, 0.5), cframe * CFrame.new(0, 4.55, -1.35) * CFrame.Angles(math.rad(-25), 0, 0), C.Ink, true)
	K.Block(model, Vector3.new(0.42, 0.1, 0.1), cframe * CFrame.new(0, 4.8, -1.05), C.Ink, true)
	model.Parent = parent
	return model
end

-- Garden gnome: blue coat, ink belt, white beard, pointy red hat.
function Props.Gnome(parent: Instance, cframe: CFrame): Model
	local model = K.Model("Gnome")
	local skin = Color3.fromRGB(255, 200, 160)
	K.Block(model, Vector3.new(1.0, 1.1, 0.9), cframe * CFrame.new(0, 0.55, 0), Color3.fromRGB(60, 110, 220), true)
	K.Ink(model, Vector3.new(1.04, 0.15, 0.94), cframe * CFrame.new(0, 0.7, 0))
	K.Block(model, Vector3.new(0.7, 0.5, 0.15), cframe * CFrame.new(0, 1.35, -0.4), skin, true)
	K.Block(model, Vector3.new(0.8, 0.6, 0.3), cframe * CFrame.new(0, 1.0, -0.42), C.Trim, true)
	K.Block(model, Vector3.new(0.25, 0.25, 0.25), cframe * CFrame.new(0, 1.3, -0.55), Color3.fromRGB(240, 140, 120), true)
	K.Block(model, Vector3.new(0.85, 0.5, 0.85), cframe * CFrame.new(0, 1.35, 0.05), skin, true)
	K.Spire(model, 1.0, 1.4, cframe * CFrame.new(0, 1.6, 0), Color3.fromRGB(230, 40, 40), true)
	model.Parent = parent
	return model
end

-- String of triangle flags from `from` to `to` (both world points), hanging below the string.
function Props.Bunting(parent: Instance, from: Vector3, to: Vector3, spacing: number)
	local length = (to - from).Magnitude
	local frame = CFrame.lookAt(from, to)
	K.Ink(parent, Vector3.new(0.08, 0.08, length), frame * CFrame.new(0, 0, -length / 2))
	local i = 0
	for along = spacing / 2, length - 0.3, spacing do
		i += 1
		K.Prism(parent, 0.06, 0.9, 0.9, frame * CFrame.new(0, 0, -along) * CFrame.Angles(math.pi, 0, 0), C.Flowers[i % #C.Flowers + 1], true)
	end
end

-- Weather vane: pole, arrow with a tail fin, and a little gold rooster on top.
function Props.WeatherVane(parent: Instance, base: CFrame)
	local gold = Color3.fromRGB(255, 205, 70)
	K.Block(parent, Vector3.new(0.15, 2.6, 0.15), base * CFrame.new(0, 1.3, 0), C.Ink, true)
	K.Block(parent, Vector3.new(0.12, 0.12, 2.2), base * CFrame.new(0, 1.9, 0), C.Ink, true)
	K.Block(parent, Vector3.new(0.06, 0.6, 0.6), base * CFrame.new(0, 1.9, 1.05) * CFrame.Angles(math.pi / 4, 0, 0), C.Ink, true)
	K.Block(parent, Vector3.new(0.12, 0.4, 0.4), base * CFrame.new(0, 1.9, -1.15) * CFrame.Angles(math.pi / 4, 0, 0), C.Ink, true)
	K.Block(parent, Vector3.new(0.12, 0.6, 1.0), base * CFrame.new(0, 2.8, 0), gold, true)
	K.Block(parent, Vector3.new(0.12, 0.45, 0.4), base * CFrame.new(0, 3.25, -0.4), gold, true)
	K.Wedge(parent, Vector3.new(0.1, 0.7, 0.5), base * CFrame.new(0, 3.15, 0.55), gold, true)
end

--------------------------------------------------------------------------------------------------- buildings

-- Rocking chair for the retirement home porch (sitter faces LookVector).
local function rockingChair(parent: Instance, cframe: CFrame)
	local wood = C.Wood
	for _, x in { -0.9, 0.9 } do
		K.Block(parent, Vector3.new(0.2, 0.2, 1.4), cframe * CFrame.new(x, 0.3, -0.6) * CFrame.Angles(math.rad(14), 0, 0), K.Dark(wood), true)
		K.Block(parent, Vector3.new(0.2, 0.2, 1.4), cframe * CFrame.new(x, 0.3, 0.6) * CFrame.Angles(math.rad(-14), 0, 0), K.Dark(wood), true)
		for _, z in { -0.8, 0.8 } do
			K.Block(parent, Vector3.new(0.2, 1.2, 0.2), cframe * CFrame.new(x, 0.9, z), wood, true)
		end
		K.Block(parent, Vector3.new(0.2, 0.2, 1.8), cframe * CFrame.new(x * 1.1, 2.2, 0), wood, true)
	end
	K.Block(parent, Vector3.new(2.1, 0.25, 1.9), cframe * CFrame.new(0, 1.5, 0), wood)
	K.Block(parent, Vector3.new(2.1, 2.2, 0.25), cframe * CFrame.new(0, 2.6, 0.95) * CFrame.Angles(math.rad(8), 0, 0), wood, true)
end

-- The retirement home: two floors of shuttered windows, pilasters, cornice, gable roof with a clock tower,
-- columned porch with rocking chairs, double doors and the big inked sign. Faces LookVector.
function Props.RetirementHome(parent: Instance, cframe: CFrame): Model
	local model = K.Model("RetirementHome")
	local W, D, H = 80, 30, 22
	local cream = Color3.fromRGB(244, 226, 190)
	local roof = C.Roofs[4]
	local shutter = Color3.fromRGB(46, 120, 80)
	local front = -D / 2
	local L = { Walls = model, Roofs = model, Details = model }
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end

	K.Block(model, Vector3.new(W + 1, 1.4, D + 1), at(0, 0.7, 0), C.Stone)
	K.Block(model, Vector3.new(W, H, D), at(0, H / 2, 0), cream)
	for _, x in { -W / 2, -25, -15, 15, 25, W / 2 } do
		K.Block(model, Vector3.new(1.4, H, 0.6), at(x, H / 2, front - 0.1), C.Trim, true)
	end
	K.InkCorners(model, at(0, H / 2, 0), Vector3.new(W + 0.4, H, D + 0.4))
	K.Block(model, Vector3.new(W + 0.6, 0.8, D + 0.6), at(0, 11, 0), C.Trim, true)
	K.Block(model, Vector3.new(W + 1.2, 1, D + 1.2), at(0, H - 0.5, 0), C.Trim, true)
	Architecture.GableRoof(L, cframe, W, D, H, 9, roof, cream, { Downspouts = true })

	-- clock tower on the ridge
	local tower = at(0, H + 8.5, 0)
	K.Block(model, Vector3.new(16, 17, 16), tower, cream)
	K.InkCorners(model, tower, Vector3.new(16, 17, 16))
	K.Block(model, Vector3.new(17, 0.8, 17), at(0, H + 17, 0), C.Trim, true)
	K.Spire(model, 18, 9, at(0, H + 17.2, 0), C.Roofs[1])
	K.Block(model, Vector3.one * 0.8, at(0, H + 26.6, 0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), Color3.fromRGB(255, 205, 70), true)
	local clock = at(0, H + 12, -8)
	K.Cylinder(model, Vector3.new(0.2, 7, 7), clock * CFrame.new(0, 0, -0.1) * CFrame.Angles(0, math.pi / 2, 0), C.Ink, true)
	K.Cylinder(model, Vector3.new(0.3, 6.2, 6.2), clock * CFrame.new(0, 0, -0.25) * CFrame.Angles(0, math.pi / 2, 0), C.Trim, true)
	K.Ink(model, Vector3.new(0.35, 2.4, 0.1), clock * CFrame.new(0, 1.1, -0.45))
	K.Ink(model, Vector3.new(2.0, 0.3, 0.1), clock * CFrame.new(0.9, 0, -0.45))
	for _, tick in { Vector3.new(0, 2.6, 0), Vector3.new(0, -2.6, 0), Vector3.new(2.6, 0, 0), Vector3.new(-2.6, 0, 0) } do
		K.Ink(model, Vector3.new(0.4, 0.4, 0.1), clock * CFrame.new(tick.X, tick.Y, -0.45))
	end

	-- windows: two shuttered rows on the front, two per side wall
	for _, y in { 6.5, 16 } do
		for _, x in { -30, -20, -10, 10, 20, 30 } do
			Architecture.Window(L, at(x, y, front), 3.6, 4.2, { Shutters = shutter, ShutterWidth = 1.3, Crown = true })
		end
	end
	for _, side in { -1, 1 } do
		for _, z in { -6, 6 } do
			Architecture.Window(L, at(side * W / 2, 6.5, z) * sideFacing(side), 3.6, 4.2, { Crown = true })
		end
	end

	-- porch: deck, steps, four columns, flat roof, rocking chairs, double doors with a transom window
	K.Block(model, Vector3.new(34, 1.2, 11), at(0, 0.6, front - 5.5), C.Stone)
	K.Block(model, Vector3.new(12, 0.8, 1.6), at(0, 0.4, front - 11.8), C.Stone)
	K.Block(model, Vector3.new(14, 0.4, 1.6), at(0, 0.2, front - 13.2), C.Stone)
	for _, x in { -14, -5, 5, 14 } do
		local column = at(x, 0, front - 10)
		K.Block(model, Vector3.new(2.2, 0.8, 2.2), column * CFrame.new(0, 1.6, 0), C.Trim)
		K.Block(model, Vector3.new(1.5, 10.6, 1.5), column * CFrame.new(0, 7.3, 0), C.Trim)
		K.Block(model, Vector3.new(1.5, 10.6, 1.5), column * CFrame.new(0, 7.3, 0) * CFrame.Angles(0, math.pi / 4, 0), C.Trim, true)
		K.Block(model, Vector3.new(2.4, 0.8, 2.4), column * CFrame.new(0, 13, 0), C.Trim, true)
	end
	K.Block(model, Vector3.new(36, 1, 12.5), at(0, 13.9, front - 5.8), C.Trim)
	K.Ink(model, Vector3.new(36.1, 0.2, 0.2), at(0, 13.4, front - 12.05))
	for _, x in { -9, 9 } do
		rockingChair(model, at(x, 1.2, front - 4) * CFrame.Angles(0, if x < 0 then 0.3 else -0.3, 0))
	end
	for _, x in { -1.8, 1.8 } do
		Architecture.Door(L, at(x, 1.4, front), 3.4, 8, C.Doors[4], { Glass = true })
	end

	-- the sign stands on the porch roof
	local sign = K.Panel(model, 30, 3.6, at(0, 16.6, front - 11.6), Color3.fromRGB(40, 70, 140), 0.4, 0.4)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "RETIREMENT HOME"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 225, 120)
	label.TextStrokeColor3 = C.Ink
	label.TextStrokeTransparency = 0
	label.Parent = gui

	model.Parent = parent
	return model
end

-- Park fountain: octagonal stone basin with a rim, water with comic glints, tiered pedestal, bowl, spout and
-- falling water arcs. Water parts are see-through decoration.
function Props.Fountain(parent: Instance, position: Vector3): Model
	local model = K.Model("Fountain")
	local stone = C.Stone
	local base = CFrame.new(position)
	local function water(part: BasePart, transparency: number)
		part.Transparency = transparency
	end

	for i = 0, 7 do
		local side = base * CFrame.Angles(0, i * math.pi / 4, 0) * CFrame.new(0, 0.9, -8.4)
		K.Block(model, Vector3.new(7.3, 1.8, 1.2), side, stone)
		K.Block(model, Vector3.new(7.6, 0.35, 1.6), side * CFrame.new(0, 1.05, 0), K.Light(stone), true)
	end
	K.Disc(model, 17.5, 0.3, position, K.Dark(stone), true)
	water(K.Disc(model, 16.4, 0.25, position + Vector3.new(0, 1.2, 0), C.Water, true), 0.15)
	for i = 0, 3 do
		local angle = 0.4 + i * math.pi / 2
		K.Block(model, Vector3.new(2.2, 0.06, 0.3), base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 1.48, -5), C.GlassShine, true)
	end

	K.Block(model, Vector3.new(4, 1.4, 4), base * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, math.pi / 8, 0), stone)
	K.Block(model, Vector3.new(2.6, 5, 2.6), base * CFrame.new(0, 3.5, 0), stone)
	K.Block(model, Vector3.new(2.6, 5, 2.6), base * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, math.pi / 4, 0), stone, true)
	for _, tier in { { 4.6, 0.6, 5.8 }, { 6.6, 0.5, 6.35 } } do
		for _, turn in { 0, math.pi / 4 } do
			K.Block(model, Vector3.new(tier[1], tier[2], tier[1]), base * CFrame.new(0, tier[3], 0) * CFrame.Angles(0, turn, 0), K.Light(stone), true)
		end
	end
	water(K.Disc(model, 5.6, 0.12, position + Vector3.new(0, 6.6, 0), C.Water, true), 0.15)
	K.Spire(model, 1.4, 1.4, base * CFrame.new(0, 6.6, 0), stone, true)
	water(K.Block(model, Vector3.new(0.6, 2.4, 0.6), base * CFrame.new(0, 8.6, 0), C.Water, true), 0.3)
	water(K.Block(model, Vector3.one * 0.8, base * CFrame.new(0, 10, 0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), C.Water, true), 0.2)
	local spout = position + Vector3.new(0, 9.6, 0)
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		local landing = position + Vector3.new(math.cos(angle) * 2.6, 6.9, math.sin(angle) * 2.6)
		local arc = K.Block(model, Vector3.new(0.35, 0.35, (landing - spout).Magnitude), CFrame.lookAt((spout + landing) / 2, landing), C.Water, true)
		water(arc, 0.3)
	end
	model.Parent = parent
	return model
end

return Props
