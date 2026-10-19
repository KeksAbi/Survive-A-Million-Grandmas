--!nonstrict
-- Comic-style street furniture built from ComicKit parts: lamps, street lights, stop signs, benches, park
-- trash cans, fire hydrants, utility cabinets, planters, rocks, newspaper vending boxes, traffic cones,
-- construction barriers (A-frame and jersey), garbage bags, bicycle racks and bicycles. Manhole covers live
-- in Streets (they are part of the road surface).
-- Every builder takes a parent and a CFrame/position on the ground; a CFrame's LookVector is the prop's front.
-- Builders only make geometry: MapBuilder places them and registers enemy obstacles. Small pieces are
-- decoration (no collision, no raycasts); posts, boxes and bodies people would bump into stay solid.

local ComicKit = require(script.Parent.ComicKit)

local K = ComicKit
local C = ComicKit.Colors

local StreetProps = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local ORANGE = rgb(255, 120, 30)
local BLACK = rgb(38, 40, 48)

-- Placement helpers for one prop: `at(x, y, z)` = CFrame in prop space, `pt(x, y, z)` = world point.
local function frame(cframe: CFrame): ((number, number, number) -> CFrame, (number, number, number) -> Vector3)
	return function(x, y, z)
		return cframe * CFrame.new(x, y, z)
	end, function(x, y, z)
		return (cframe * CFrame.new(x, y, z)).Position
	end
end

------------------------------------------------------------------------------------------- street props

-- Classic street lamp: plinth, eight-sided pole with a ring, lantern with ink corner bars and a spire cap.
function StreetProps.Lamp(parent: Instance, position: Vector3): Model
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
function StreetProps.Bench(parent: Instance, cframe: CFrame): Model
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
function StreetProps.TrashCan(parent: Instance, position: Vector3): Model
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

-- Red fire hydrant: octagonal base flange with six bolts, round barrel with two raised bands, collar, yellow
-- bonnet with an operating nut, two side hose outlets and a big front pumper outlet (faces LookVector), each
-- with a cap; the side caps hang on little chains. The barrel is solid.
function StreetProps.Hydrant(parent: Instance, cframe: CFrame): Model
	local model = K.Model("Hydrant")
	local at, pt = frame(cframe)
	local red = rgb(220, 50, 45)
	K.Octagon(model, 1.35, 0.3, at(0, 0.15, 0), C.MetalDark, true)
	for i = 0, 5 do
		local angle = i * math.pi / 3 + 0.3
		K.Block(model, Vector3.new(0.16, 0.14, 0.16), at(math.cos(angle) * 0.55, 0.36, math.sin(angle) * 0.55), C.Metal, true)
	end
	K.Disc(model, 0.95, 1.9, pt(0, 0.3, 0), red)
	for _, y in { 0.5, 1.9 } do
		K.Disc(model, 1.08, 0.16, pt(0, y, 0), K.Dark(red), true)
	end
	K.Disc(model, 1.2, 0.22, pt(0, 2.2, 0), K.Dark(red), true)
	K.Spire(model, 1.0, 0.6, at(0, 2.4, 0), C.RoadLine, true)
	K.Block(model, Vector3.new(0.3, 0.3, 0.3), at(0, 3.0, 0) * CFrame.Angles(0, math.pi / 4, 0), C.Metal, true)
	for _, side in { -1, 1 } do
		K.Cylinder(model, Vector3.new(0.45, 0.45, 0.45), at(side * 0.62, 1.45, 0), red, true)
		K.Cylinder(model, Vector3.new(0.14, 0.52, 0.52), at(side * 0.88, 1.45, 0), C.Metal, true)
		K.Rod(model, pt(side * 0.88, 1.3, -0.15), pt(side * 0.5, 1.1, -0.42), 0.05, C.Ink, true)
	end
	K.Tube(model, pt(0, 1.3, -0.3), pt(0, 1.3, -0.72), 0.68, red, true)
	K.Tube(model, pt(0, 1.3, -0.7), pt(0, 1.3, -0.86), 0.76, C.Metal, true)
	K.Block(model, Vector3.new(0.26, 0.26, 0.1), at(0, 1.3, -0.9), C.MetalDark, true)
	model.Parent = parent
	return model
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
function StreetProps.StopSign(parent: Instance, cframe: CFrame, names: { string }): Model
	local model = K.Model("StopSign")
	K.Block(model, Vector3.new(0.25, 9.4, 0.25), cframe * CFrame.new(0, 4.7, 0), C.Metal)
	local face = cframe * CFrame.new(0, 6.6, -0.2)
	octagon(model, face, 2.6, 0.08, C.Ink)
	octagon(model, face * CFrame.new(0, 0, -0.06), 2.4, 0.06, C.Trim)
	local red = octagon(model, face * CFrame.new(0, 0, -0.11), 2.15, 0.06, Color3.fromRGB(220, 30, 30))
	K.Text(red, "STOP", C.Trim)
	local green = Color3.fromRGB(30, 130, 80)
	for i, name in names do
		local blade = cframe * CFrame.new(0, 8.6 + i * 0.75, 0) * CFrame.Angles(0, (i - 1) * math.pi / 2, 0)
		K.Block(model, Vector3.new(3.5, 0.72, 0.1), blade, C.Ink, true)
		local plate = K.Block(model, Vector3.new(3.3, 0.55, 0.14), blade, green, true)
		K.Text(plate, name, C.Trim, true)
	end
	K.Block(model, Vector3.new(0.35, 0.3, 0.35), cframe * CFrame.new(0, 10.3, 0), C.Metal, true)
	model.Parent = parent
	return model
end

-- Tall cobra-head street light: plinth, two-step tapered pole, curved arm, head with a glowing lens.
-- The arm reaches toward LookVector.
function StreetProps.StreetLight(parent: Instance, cframe: CFrame): Model
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

-- Green utility cabinet on a concrete pad: plinth, cabinet, two lighter door panels with an
-- ink seam, handles and a padlock, a DANGER sticker, louvered side vents, overhanging lid and a sloped rain
-- cap. Faces LookVector; the cabinet is solid.
function StreetProps.UtilityBox(parent: Instance, cframe: CFrame): Model
	local model = K.Model("UtilityBox")
	local at = frame(cframe)
	local green = rgb(70, 130, 90)
	K.Block(model, Vector3.new(3.2, 0.3, 2.0), at(0, 0.15, 0), C.Stone)
	K.Block(model, Vector3.new(2.6, 0.2, 1.45), at(0, 0.4, 0), K.Dark(green), true)
	K.Block(model, Vector3.new(2.4, 3.0, 1.3), at(0, 1.95, 0), green)
	K.Block(model, Vector3.new(2.65, 0.2, 1.55), at(0, 3.55, 0), K.Dark(green), true)
	K.Wedge(model, Vector3.new(2.65, 0.3, 1.55), at(0, 3.8, 0), green, true)
	local front = at(0, 0, -0.65)
	for _, x in { -0.6, 0.6 } do
		K.Block(model, Vector3.new(1.0, 2.6, 0.05), front * CFrame.new(x, 1.95, -0.02), K.Light(green), true)
		K.Block(model, Vector3.new(0.1, 0.5, 0.1), front * CFrame.new(x * 0.25, 1.9, -0.1), C.Metal, true)
	end
	K.Ink(model, Vector3.new(0.08, 2.7, 0.07), front * CFrame.new(0, 1.95, -0.03))
	K.Block(model, Vector3.new(0.24, 0.26, 0.1), front * CFrame.new(0, 1.5, -0.12), rgb(255, 196, 40), true)
	K.Ink(model, Vector3.new(0.16, 0.16, 0.05), front * CFrame.new(0, 1.7, -0.12))
	local sticker = K.Panel(model, 0.8, 0.5, front * CFrame.new(0.6, 2.8, -0.05), rgb(255, 205, 40), 0.05, 0.04)
	K.Text(sticker, "DANGER", C.Ink)
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			K.Ink(model, Vector3.new(0.06, 0.08, 0.8), at(side * 1.22, 2.85 - i * 0.25, 0))
		end
	end
	model.Parent = parent
	return model
end

-- Wooden planter box (`length` long along local X): plank walls with ink seams, darker corner posts, soil.
-- Returns the CFrame of the soil top center (for planting).
function StreetProps.Planter(parent: Instance, cframe: CFrame, length: number): CFrame
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
function StreetProps.Rocks(parent: Instance, position: Vector3, rng: Random, count: number)
	for i = 1, count do
		local angle = i * 2.4
		local size = rng:NextNumber(0.7, 1.5) * (if i == 1 then 1.3 else 1)
		local at = position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (if i == 1 then 0 else rng:NextNumber(0.8, 1.4)) + Vector3.new(0, size * 0.2, 0)
		K.Gem(parent, size, at, if i % 2 == 0 then C.Stone else K.Dark(C.Stone), rng, true)
	end
end

----------------------------------------------------------------------------------------------- new street props

-- Newspaper vending box on a pedestal: box with a sloped top, GRANNY GAZETTE header, coin box with an
-- ink slot, a window showing today's front page and a pull handle. Faces LookVector; the box is solid.
function StreetProps.NewspaperBox(parent: Instance, cframe: CFrame, color: Color3?, title: string?): Model
	local model = K.Model("NewspaperBox")
	local at = frame(cframe)
	local paint = color or rgb(40, 110, 200)
	K.Block(model, Vector3.new(1.5, 0.12, 1.3), at(0, 0.06, 0), C.MetalDark, true)
	K.Block(model, Vector3.new(0.5, 0.9, 0.5), at(0, 0.55, 0), C.MetalDark, true)
	K.Block(model, Vector3.new(1.6, 1.9, 1.4), at(0, 1.95, 0), paint)
	K.Block(model, Vector3.new(1.7, 0.12, 1.5), at(0, 2.92, 0), K.Dark(paint), true)
	K.Wedge(model, Vector3.new(1.6, 0.35, 1.4), at(0, 3.15, 0), paint, true)
	local front = at(0, 0, -0.7)
	local header = K.Panel(model, 1.05, 0.38, front * CFrame.new(-0.2, 2.62, 0), C.Trim, 0.05, 0.04)
	K.Text(header, title or "GRANNY GAZETTE", K.Dark(paint))
	K.Block(model, Vector3.new(0.3, 0.42, 0.1), front * CFrame.new(0.58, 2.62, -0.05), C.Metal, true)
	K.Ink(model, Vector3.new(0.05, 0.2, 0.04), front * CFrame.new(0.58, 2.66, -0.11))
	K.Panel(model, 1.3, 0.95, front * CFrame.new(0, 1.85, 0), C.Glass, 0.08, 0.04)
	local paper = K.Block(model, Vector3.new(0.95, 0.7, 0.04), front * CFrame.new(0, 1.85, -0.17), C.Trim, true)
	K.Text(paper, "GRANDMAS ATTACK!", C.Ink)
	K.Block(model, Vector3.new(0.7, 0.12, 0.12), front * CFrame.new(0, 1.2, -0.08), C.Metal, true)
	model.Parent = parent
	return model
end

-- Traffic cone: chamfered black rubber base, faceted orange cone and two white reflective collars. Decoration only.
function StreetProps.TrafficCone(parent: Instance, cframe: CFrame): Model
	local model = K.Model("TrafficCone")
	local at, pt = frame(cframe)
	K.Block(model, Vector3.new(1.3, 0.14, 1.3), at(0, 0.07, 0), BLACK, true)
	K.Block(model, Vector3.new(1.15, 0.15, 1.15), at(0, 0.075, 0) * CFrame.Angles(0, math.pi / 4, 0), BLACK, true)
	K.Cone(model, 0.95, 2.1, at(0, 0.14, 0), ORANGE, true)
	K.Disc(model, 0.82, 0.2, pt(0, 0.7, 0), C.Trim, true)
	K.Disc(model, 0.56, 0.17, pt(0, 1.27, 0), C.Trim, true)
	model.Parent = parent
	return model
end

-- Construction barrier. "AFrame" (default): 4.6 wide, folding legs with spreaders, orange-striped top rail, an
-- orange DETOUR board, a flashing amber lamp and sandbags on the feet. "Jersey": a 6-long water-filled plastic
-- jersey barrier: wide foot, sloped sides, tall body with two white reflector bands, a fill cap and forklift
-- slots. Faces LookVector.
function StreetProps.ConstructionBarrier(parent: Instance, cframe: CFrame, kind: string?): Model
	local at, pt = frame(cframe)
	if kind == "Jersey" then
		local model = K.Model("JerseyBarrier")
		K.Block(model, Vector3.new(6, 0.35, 2.0), at(0, 0.175, 0), ORANGE)
		K.Wedge(model, Vector3.new(6, 0.7, 0.6), at(0, 0.7, -0.55), ORANGE, true)
		K.Wedge(model, Vector3.new(6, 0.7, 0.6), at(0, 0.7, 0.55) * CFrame.Angles(0, math.pi, 0), ORANGE, true)
		K.Block(model, Vector3.new(6, 2.25, 0.6), at(0, 1.475, 0), ORANGE)
		K.Block(model, Vector3.new(6.04, 0.15, 0.7), at(0, 2.65, 0), K.Dark(ORANGE), true)
		for _, y in { 1.45, 2.15 } do
			K.Block(model, Vector3.new(6.02, 0.24, 0.64), at(0, y, 0), C.Trim, true)
		end
		K.Disc(model, 0.4, 0.12, pt(-2.2, 2.72, 0), C.Trim, true)
		for _, x in { -1.6, 1.6 } do
			K.Block(model, Vector3.new(0.9, 0.2, 2.04), at(x, 0.15, 0), C.Ink, true)
		end
		model.Parent = parent
		return model
	end
	local model = K.Model("AFrameBarrier")
	for _, x in { -1.8, 1.8 } do
		for _, s in { -1, 1 } do
			K.Rod(model, pt(x, 2.75, 0), pt(x, 0.05, s * 0.6), 0.16, C.Trim, true)
		end
		K.Block(model, Vector3.new(0.12, 0.12, 0.9), at(x, 0.9, 0), C.MetalDark, true)
		K.Block(model, Vector3.new(0.6, 0.28, 0.5), at(x, 0.14, 0.62) * CFrame.Angles(0, 0.3, 0), rgb(176, 146, 96), true)
	end
	local rail = at(0, 2.3, -0.2)
	K.Block(model, Vector3.new(4.6, 0.55, 0.12), rail, C.Trim, true)
	for x = -2.0, 2.01, 0.8 do
		K.Block(model, Vector3.new(0.28, 0.45, 0.14), rail * CFrame.new(x, 0, 0) * CFrame.Angles(0, 0, math.rad(40)), ORANGE, true)
	end
	local sign = K.Block(model, Vector3.new(4.0, 0.55, 0.12), at(0, 1.55, -0.34), ORANGE, true)
	K.Text(sign, "DETOUR", C.Ink)
	K.Block(model, Vector3.new(0.36, 0.36, 0.3), at(-1.8, 2.95, 0), BLACK, true)
	local lens = K.Cylinder(model, Vector3.new(0.12, 0.5, 0.5), at(-1.8, 3.0, -0.2) * CFrame.Angles(0, math.pi / 2, 0), rgb(255, 190, 40), true)
	lens.Material = Enum.Material.Neon
	model.Parent = parent
	return model
end

-- Tied garbage bags: each a chamfered body, a gathered neck, an ink tie and two knot ears, with a glossy
-- highlight. Decoration only.
function StreetProps.GarbageBags(parent: Instance, cframe: CFrame, rng: Random, count: number?): Model
	local model = K.Model("GarbageBags")
	local colors = { rgb(44, 46, 56), rgb(56, 58, 70), rgb(60, 124, 72) }
	for i = 1, count or 2 do
		local s = rng:NextNumber(0.85, 1.1)
		local spot = cframe * CFrame.new((i - 1) * 1.05 - 0.5, 0, (i % 2) * 0.5) * CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), 0)
		local color = colors[(i - 1) % #colors + 1]
		K.Block(model, Vector3.new(1.15 * s, 0.95 * s, 1.05 * s), spot * CFrame.new(0, 0.48 * s, 0), color, true)
		K.Block(model, Vector3.new(0.95 * s, 0.9 * s, 0.95 * s), spot * CFrame.new(0, 0.5 * s, 0) * CFrame.Angles(0, math.pi / 4, 0), color, true)
		K.Spire(model, 0.85 * s, 0.42 * s, spot * CFrame.new(0, 0.95 * s, 0), color, true)
		K.Ink(model, Vector3.new(0.26 * s, 0.08 * s, 0.26 * s), spot * CFrame.new(0, 1.3 * s, 0))
		for _, side in { -1, 1 } do
			K.Block(model, Vector3.new(0.3 * s, 0.32 * s, 0.1 * s), spot * CFrame.new(side * 0.12 * s, 1.45 * s, 0) * CFrame.Angles(0, 0, -side * 0.6), color, true)
		end
		K.Block(model, Vector3.new(0.08 * s, 0.45 * s, 0.1 * s), spot * CFrame.new(-0.3 * s, 0.55 * s, -0.53 * s), color:Lerp(Color3.new(1, 1, 1), 0.45), true)
	end
	model.Parent = parent
	return model
end

-- Bicycle rack: `hoops` inverted-U hoops (1.5 apart along X) with rounded shoulders on two ground rails.
-- Bikes park between the hoops, parallel to LookVector. The hoop legs are solid.
function StreetProps.BikeRack(parent: Instance, cframe: CFrame, hoops: number?): Model
	local model = K.Model("BikeRack")
	local _, pt = frame(cframe)
	local n = hoops or 3
	local width = (n - 1) * 1.5
	local metal = rgb(70, 150, 110)
	for _, z in { -0.6, 0.6 } do
		K.Tube(model, pt(-width / 2 - 0.3, 0.08, z), pt(width / 2 + 0.3, 0.08, z), 0.16, C.MetalDark, true)
	end
	for i = 0, n - 1 do
		local x = -width / 2 + i * 1.5
		for _, z in { -0.6, 0.6 } do
			K.Tube(model, pt(x, 0.05, z), pt(x, 2.1, z), 0.18, metal)
			K.Tube(model, pt(x, 2.1, z), pt(x, 2.5, z / 2), 0.18, metal, true)
			K.Ball(model, 0.18, pt(x, 2.1, z), metal, true)
		end
		K.Tube(model, pt(x, 2.5, -0.32), pt(x, 2.5, 0.32), 0.18, metal, true)
	end
	model.Parent = parent
	return model
end

-- Grandma's bicycle: two wheels (tire, rim, spoke disc with ink spokes, hub), diamond frame, fork, stem and
-- handlebar with a bell, seat post and saddle, chainring with crank arms and pedals, and a wicker front basket.
-- The front wheel points toward LookVector. Decoration only.
function StreetProps.Bicycle(parent: Instance, cframe: CFrame, color: Color3?): Model
	local model = K.Model("Bicycle")
	local at, pt = frame(cframe)
	local paint = color or rgb(70, 190, 180)
	local R = 0.85
	for _, z in { -1.15, 1.15 } do
		K.Cylinder(model, Vector3.new(0.14, 1.7, 1.7), at(0, R, z), BLACK, true)
		K.Cylinder(model, Vector3.new(0.16, 1.4, 1.4), at(0, R, z), C.Metal, true)
		K.Cylinder(model, Vector3.new(0.17, 1.22, 1.22), at(0, R, z), C.Trim, true)
		for k = 0, 2 do
			K.Ink(model, Vector3.new(0.19, 0.05, 1.2), at(0, R, z) * CFrame.Angles(k * math.pi / 3, 0, 0))
		end
		K.Cylinder(model, Vector3.new(0.26, 0.28, 0.28), at(0, R, z), C.MetalDark, true)
	end
	local bracket, seat, head, headLow = pt(0, 0.8, 0.1), pt(0, 2.1, 0.45), pt(0, 2.05, -0.75), pt(0, 1.75, -0.82)
	local rear, front = pt(0, R, 1.15), pt(0, R, -1.15)
	for _, tube in { { bracket, seat }, { seat, head }, { bracket, headLow }, { bracket, rear }, { seat, rear } } do
		K.Tube(model, tube[1], tube[2], 0.14, paint, true)
	end
	K.Tube(model, head, front, 0.12, C.Metal, true)
	K.Tube(model, head, pt(0, 2.5, -0.8), 0.12, C.Metal, true)
	K.Tube(model, pt(-0.55, 2.5, -0.8), pt(0.55, 2.5, -0.8), 0.12, BLACK, true)
	K.Ball(model, 0.2, pt(0.32, 2.62, -0.8), rgb(255, 204, 56), true)
	K.Tube(model, seat, pt(0, 2.42, 0.5), 0.1, C.Metal, true)
	K.Block(model, Vector3.new(0.42, 0.16, 0.8), at(0, 2.5, 0.55), BLACK, true)
	K.Cylinder(model, Vector3.new(0.06, 0.62, 0.62), at(0.12, 0.8, 0.1), C.Metal, true)
	for _, s in { -1, 1 } do
		local foot = pt(s * 0.22, 0.8 - s * 0.38, 0.1 + s * 0.12)
		K.Rod(model, pt(s * 0.18, 0.8, 0.1), foot, 0.08, C.MetalDark, true)
		K.Block(model, Vector3.new(0.34, 0.08, 0.22), CFrame.new(foot) * (cframe - cframe.Position) * CFrame.new(s * 0.18, 0, 0), BLACK, true)
	end
	K.Block(model, Vector3.new(0.85, 0.55, 0.6), at(0, 2.3, -1.32), rgb(196, 150, 90), true)
	K.Ink(model, Vector3.new(0.88, 0.06, 0.63), at(0, 2.42, -1.32))
	model.Parent = parent
	return model
end

return StreetProps
