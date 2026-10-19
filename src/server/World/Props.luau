--!nonstrict
-- Comic-style prop models for the map (trees, bushes, houses, cars, street furniture, landmarks), built from
-- ComicKit parts. Every builder takes a parent and a CFrame/position on the ground; a CFrame's LookVector is
-- the prop's front. Builders only make geometry: MapBuilder places them and registers enemy obstacles.

local Architecture = require(script.Parent.Architecture)
local ComicKit = require(script.Parent.ComicKit)

local K = ComicKit
local C = ComicKit.Colors

local Props = {}

local function pick(rng: Random, list: { any }): any
	return list[rng:NextInteger(1, #list)]
end

-- Turns a CFrame on a box's +X (side = 1) or -X (side = -1) wall so its LookVector points out of that wall.
local function sideFacing(side: number): CFrame
	return if side == 1 then Architecture.Face.Right else Architecture.Face.Left
end

--------------------------------------------------------------------------------------------------- nature

-- Leafy tree: twisted tapering trunk, root flares, three branches, faceted leaf clusters in three tones.
function Props.Tree(parent: Instance, position: Vector3, rng: Random): Model
	local model = K.Model("Tree")
	local height = rng:NextNumber(6, 8.5)
	local spin = rng:NextNumber(0, math.pi * 2)
	local base = CFrame.new(position) * CFrame.Angles(0, spin, 0)

	for i = 0, 2 do
		K.Wedge(model, Vector3.new(0.8, 1.1, 1.3), base * CFrame.Angles(0, i * math.pi * 2 / 3, 0) * CFrame.new(0, 0.55, -1.05), C.Trunk, true)
	end
	local segment = height / 3
	for i, width in { 1.7, 1.35, 1.0 } do
		K.Block(model, Vector3.new(width, segment + 0.3, width), base * CFrame.new(0, (i - 0.5) * segment, 0) * CFrame.Angles(0, i * 0.5, 0), C.Trunk)
	end

	local leaves = pick(rng, C.Leaves)
	local fork = position + Vector3.new(0, height - 1.2, 0)
	for i = 0, 2 do
		local angle = spin + i * math.pi * 2 / 3 + rng:NextNumber(-0.3, 0.3)
		local tip = fork + Vector3.new(math.cos(angle), 0.9, math.sin(angle)).Unit * rng:NextNumber(2.6, 3.4)
		K.Block(model, Vector3.new(0.55, 0.55, (tip - fork).Magnitude), CFrame.lookAt((fork + tip) / 2, tip), C.Trunk, true)
		K.Gem(model, rng:NextNumber(4, 4.8), tip + Vector3.new(0, 0.8, 0), if i == 0 then K.Dark(leaves) else leaves, rng, true)
	end
	K.Gem(model, rng:NextNumber(5.5, 6.5), position + Vector3.new(0, height + 2.6, 0), K.Light(leaves), rng, true)
	model.Parent = parent
	return model
end

-- Pine: short trunk and three twisted, shrinking spire tiers.
function Props.Pine(parent: Instance, position: Vector3, rng: Random): Model
	local model = K.Model("Pine")
	local base = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local scale = rng:NextNumber(0.9, 1.25)
	K.Block(model, Vector3.new(1.1, 3, 1.1) * scale, base * CFrame.new(0, 1.5 * scale, 0), C.Trunk)
	for i = 0, 2 do
		local color = C.Pine[i % 2 + 1]
		K.Spire(model, (7 - i * 1.9) * scale, (4.2 - i * 0.5) * scale, base * CFrame.new(0, (2.2 + i * 2.5) * scale, 0) * CFrame.Angles(0, i * 0.4, 0), color, true)
	end
	model.Parent = parent
	return model
end

-- Bush: irregular faceted leaf clusters (dark below, light on top), sometimes with blossoms.
function Props.Bush(parent: Instance, position: Vector3, rng: Random, scale: number?): Model
	local s = scale or 1
	local model = K.Model("Bush")
	local leaves = pick(rng, C.Leaves)
	local spin = rng:NextNumber(0, math.pi * 2)
	for i = 0, 2 do
		local angle = spin + i * math.pi * 2 / 3
		local offset = Vector3.new(math.cos(angle) * 0.9, 1, math.sin(angle) * 0.9) * s
		K.Gem(model, rng:NextNumber(2.2, 2.8) * s, position + offset, if i == 0 then K.Dark(leaves) else leaves, rng, true)
	end
	K.Gem(model, 2.4 * s, position + Vector3.new(0, 1.9 * s, 0), K.Light(leaves), rng, true)
	if rng:NextNumber() < 0.5 then
		local flower = pick(rng, C.Flowers)
		for i = 1, 4 do
			local angle = spin + i * 1.6
			local at = position + Vector3.new(math.cos(angle) * 1.4, rng:NextNumber(1.4, 2.4), math.sin(angle) * 1.4) * s
			K.Block(model, Vector3.one * 0.55 * s, CFrame.new(at) * CFrame.Angles(math.pi / 4, math.pi / 4, 0), flower, true)
		end
	end
	model.Parent = parent
	return model
end

-- Octagonal stone flower bed with stems, blossoms and leaf tufts (flat: nothing to walk around).
function Props.FlowerBed(parent: Instance, position: Vector3, rng: Random): Model
	local model = K.Model("FlowerBed")
	for i = 0, 7 do
		local cf = CFrame.new(position) * CFrame.Angles(0, i * math.pi / 4, 0) * CFrame.new(0, 0.3, -3.2)
		K.Block(model, Vector3.new(2.8, 0.6, 0.7), cf, C.Stone, true)
	end
	K.Disc(model, 6.2, 0.4, position, Color3.fromRGB(116, 76, 46), true)
	for i = 1, 9 do
		local angle = i * 2.4
		local radius = rng:NextNumber(0.5, 2.4)
		local height = rng:NextNumber(0.9, 1.6)
		local ground = position + Vector3.new(math.cos(angle) * radius, 0.4, math.sin(angle) * radius)
		K.Block(model, Vector3.new(0.18, height, 0.18), CFrame.new(ground + Vector3.new(0, height / 2, 0)), C.Pine[2], true)
		K.Block(model, Vector3.one * 0.8, CFrame.new(ground + Vector3.new(0, height, 0)) * CFrame.Angles(math.pi / 4, angle, math.pi / 4), C.Flowers[i % #C.Flowers + 1], true)
	end
	K.Gem(model, 1.4, position + Vector3.new(0.6, 0.8, -0.4), C.Leaves[3], rng, true)
	K.Gem(model, 1.2, position + Vector3.new(-0.8, 0.7, 0.7), C.Leaves[1], rng, true)
	model.Parent = parent
	return model
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

-- Picket fence from `from` to `to` on the ground: two rails and pointed pickets (pure decoration).
function Props.PicketFence(parent: Instance, from: Vector3, to: Vector3, spacing: number, height: number, color: Color3)
	local length = (to - from).Magnitude
	local frame = CFrame.lookAt(from, to)
	for _, y in { height * 0.3, height * 0.72 } do
		K.Block(parent, Vector3.new(0.25, 0.4, length), frame * CFrame.new(0, y, -length / 2), color, true)
	end
	local along = spacing / 2
	while along < length do
		local at = frame * CFrame.new(-0.25, 0, -along)
		K.Block(parent, Vector3.new(0.3, height, 0.75), at * CFrame.new(0, height / 2, 0), color, true)
		K.Block(parent, Vector3.new(0.3, 0.55, 0.55), at * CFrame.new(0, height, 0) * CFrame.Angles(math.pi / 4, 0, 0), color, true)
		along += spacing
	end
end

-- Square fence post with a cap and a little spire on top.
function Props.FencePost(parent: Instance, position: Vector3, height: number, color: Color3)
	local base = CFrame.new(position)
	K.Block(parent, Vector3.new(0.9, height, 0.9), base * CFrame.new(0, height / 2, 0), color, true)
	K.Block(parent, Vector3.new(1.25, 0.3, 1.25), base * CFrame.new(0, height + 0.15, 0), color, true)
	K.Spire(parent, 0.8, 0.6, base * CFrame.new(0, height + 0.3, 0), color, true)
end

--------------------------------------------------------------------------------------------------- vehicles

-- Car: shaped body (sloped hood, cabin with raked glass, roof), wheels with hubcaps under fender flares,
-- bumpers, inked lights, grille, mirrors, door seams. kind "Pickup" swaps the trunk for an open bed.
-- Length runs along Z, the nose points along LookVector.
function Props.Car(parent: Instance, cframe: CFrame, color: Color3, kind: string?): Model
	local model = K.Model("Car")
	local L, W = 11, 5.4
	local pickup = kind == "Pickup"
	local front = -L / 2
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end

	K.Block(model, Vector3.new(W, 1.6, L), at(0, 1.6, 0), color)
	K.Wedge(model, Vector3.new(W - 0.2, 0.5, 3.2), at(0, 2.65, front + 1.6), color, true)
	local cabinZ, cabinL = if pickup then -0.9 else 0.6, if pickup then 2.6 else 3.6
	K.Block(model, Vector3.new(W - 0.7, 1.9, cabinL), at(0, 3.35, cabinZ), color)
	K.Wedge(model, Vector3.new(W - 0.7, 1.9, 1.7), at(0, 3.35, cabinZ - cabinL / 2 - 0.85), C.Glass, true)
	K.Block(model, Vector3.new(W - 0.5, 0.25, cabinL + 0.3), at(0, 4.4, cabinZ), K.Light(color), true)
	if pickup then
		K.Panel(model, W - 1.6, 1.1, at(0, 3.45, cabinZ + cabinL / 2) * CFrame.Angles(0, math.pi, 0), C.Glass, 0.2, 0.08)
		local bedZ = L / 2 - 2.3
		for _, side in { -1, 1 } do
			K.Block(model, Vector3.new(0.3, 0.9, 4.4), at(side * (W / 2 - 0.15), 2.85, bedZ), color, true)
		end
		K.Block(model, Vector3.new(W, 0.9, 0.3), at(0, 2.85, L / 2 - 0.15), color, true)
		K.Block(model, Vector3.new(W - 0.6, 0.1, 4.2), at(0, 2.42, bedZ), C.MetalDark, true)
	else
		K.Wedge(model, Vector3.new(W - 0.7, 1.9, 1.3), at(0, 3.35, cabinZ + cabinL / 2 + 0.65) * CFrame.Angles(0, math.pi, 0), C.Glass, true)
		K.Block(model, Vector3.new(W - 0.2, 0.35, 2.2), at(0, 2.57, L / 2 - 1.1), color, true)
	end

	for _, side in { -1, 1 } do
		local x = side * (W - 0.7) / 2
		K.Panel(model, cabinL - 0.5, 1.2, at(x, 3.45, cabinZ) * sideFacing(side), C.Glass, 0.2, 0.08)
		K.Block(model, Vector3.new(0.12, 1.25, 0.3), at(x + side * 0.2, 3.45, cabinZ), color, true)
		K.Block(model, Vector3.new(0.5, 0.35, 0.3), at(side * (W / 2 - 0.05), 3.0, cabinZ - cabinL / 2 - 0.3), color, true)
		K.Ink(model, Vector3.new(0.06, 1.5, 0.06), at(side * (W / 2 + 0.03), 1.65, cabinZ))
		K.Block(model, Vector3.new(0.08, 0.15, 0.5), at(side * (W / 2 + 0.04), 2.05, cabinZ - 0.6), C.Metal, true)
		for _, z in { front + 2.4, L / 2 - 2.3 } do
			K.Cylinder(model, Vector3.new(0.9, 2.3, 2.3), at(side * (W / 2 + 0.05), 1.15, z), Color3.fromRGB(34, 34, 40))
			K.Cylinder(model, Vector3.new(0.95, 1.1, 1.1), at(side * (W / 2 + 0.05), 1.15, z), C.Metal, true)
			K.Block(model, Vector3.new(0.8, 0.45, 3.0), at(side * (W / 2 + 0.15), 2.45, z), K.Dark(color), true)
		end
		K.Panel(model, 1.1, 0.55, at(side * (W / 2 - 0.9), 2.0, front), Color3.fromRGB(255, 240, 170), 0.15, 0.08)
		K.Panel(model, 1.1, 0.5, at(side * (W / 2 - 0.9), 2.0, L / 2) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(230, 40, 40), 0.15, 0.08)
	end
	K.Panel(model, 2.2, 0.6, at(0, 1.85, front), C.MetalDark, 0.12, 0.06)
	for _, z in { front - 0.15, L / 2 + 0.15 } do
		K.Block(model, Vector3.new(W + 0.2, 0.55, 0.5), at(0, 1.15, z), C.Metal)
	end
	model.Parent = parent
	return model
end

-- Yellow school bus: nose with grille, black rub rails, inked window strip, flashing lights, stop arm,
-- mirrors and a SCHOOL BUS sign. Length along Z, nose along LookVector.
function Props.SchoolBus(parent: Instance, cframe: CFrame): Model
	local model = K.Model("SchoolBus")
	local yellow = Color3.fromRGB(255, 196, 30)
	local W = 7.6
	local function at(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end
	K.Block(model, Vector3.new(W, 7, 21), at(0, 5, 2.5), yellow)
	K.Block(model, Vector3.new(W - 0.6, 3.8, 4.4), at(0, 3.4, -10.2), yellow)
	K.Wedge(model, Vector3.new(W - 0.8, 0.8, 4.4), at(0, 5.7, -10.2), yellow, true)
	K.Block(model, Vector3.new(W + 0.3, 0.6, 21.3), at(0, 8.8, 2.5), C.Trim)
	for _, side in { -1, 1 } do
		local x = side * (W / 2)
		for _, y in { 2.6, 4.2 } do
			K.Ink(model, Vector3.new(0.1, 0.4, 21.1), at(x + side * 0.02, y, 2.5))
		end
		K.Ink(model, Vector3.new(0.1, 2.5, 19.2), at(x + side * 0.03, 6.5, 2.0))
		for i = 0, 6 do
			K.Block(model, Vector3.new(0.1, 2.0, 2.0), at(x + side * 0.09, 6.5, -6.2 + i * 2.6), C.Glass, true)
		end
		for _, z in { -8.8, 8.5 } do
			K.Cylinder(model, Vector3.new(1.2, 3.6, 3.6), at(side * (W / 2 + 0.05), 1.8, z), Color3.fromRGB(34, 34, 40))
			K.Cylinder(model, Vector3.new(1.25, 1.6, 1.6), at(side * (W / 2 + 0.05), 1.8, z), C.Metal, true)
			K.Block(model, Vector3.new(0.9, 0.6, 4.4), at(side * (W / 2 + 0.2), 3.9, z), C.Ink, true)
		end
		K.Block(model, Vector3.new(1.4, 0.2, 0.2), at(side * (W / 2 + 0.7), 6.8, -12.0), C.MetalDark, true)
		K.Block(model, Vector3.new(0.4, 1.2, 0.7), at(side * (W / 2 + 1.4), 6.5, -12.0), C.Ink, true)
		K.Panel(model, 0.9, 0.7, at(side * 2.6, 3.6, -12.4), Color3.fromRGB(255, 240, 170), 0.15, 0.08)
		K.Panel(model, 0.8, 0.8, at(side * 2.8, 4.5, 13) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(230, 40, 40), 0.15, 0.08)
		for _, x2 in { 2.8, 1.8 } do
			local lightColor = if x2 > 2 then Color3.fromRGB(240, 50, 50) else Color3.fromRGB(255, 160, 40)
			K.Block(model, Vector3.new(0.7, 0.6, 0.3), at(side * x2, 7.9, -8.15), lightColor, true)
		end
	end
	K.Panel(model, W - 1.4, 2.6, at(0, 6.4, -8), C.Glass, 0.3, 0.1)
	K.Ink(model, Vector3.new(0.25, 2.6, 0.1), at(0, 6.4, -8.3))
	K.Panel(model, 3.4, 2, at(0, 3.4, -12.4), C.MetalDark, 0.2, 0.1)
	for _, z in { -12.6, 13.2 } do
		K.Block(model, Vector3.new(W + 0.4, 0.8, 0.6), at(0, 1.5, z), C.Ink)
	end
	local stopArm = at(-W / 2 - 0.25, 5.4, -6.5)
	K.Block(model, Vector3.new(0.12, 1.6, 1.6), stopArm, Color3.fromRGB(220, 30, 30), true)
	K.Block(model, Vector3.new(0.12, 1.6, 1.6), stopArm * CFrame.Angles(math.pi / 4, 0, 0), Color3.fromRGB(220, 30, 30), true)

	local sign = K.Panel(model, 6, 1.1, at(0, 9.75, -7.9), yellow, 0.2, 0.15)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "SCHOOL BUS"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = C.Ink
	label.Parent = gui
	model.Parent = parent
	return model
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
function Props.RetirementHome(parent: Instance, cframe: CFrame, rng: Random): Model
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
	for _, x in { -36, -24, 24, 36 } do
		Props.Bush(model, at(x, 0, front - 2.2).Position, rng)
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
