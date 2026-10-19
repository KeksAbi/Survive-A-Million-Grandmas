--!nonstrict
-- Grandma-themed comic decorations: knitted yarn balls (giant ones with knitting needles), giant knitting
-- needles with a half-knitted scarf, a knitting basket, fluffy slippers, a rocking chair with a cushion and a
-- knitted blanket, Grandma's cookie stall, a BINGO TONIGHT marquee sign, retirement-home billboards, a heroic
-- grandma statue on a plinth and a shopping cart full of groceries. Mobility scooters are in Vehicles.
-- Same conventions as YardProps: ground CFrame in, LookVector = the prop's front, returns a Model, small
-- pieces are decoration and only big bodies stay solid.

local ComicKit = require(script.Parent.ComicKit)

local K = ComicKit
local C = ComicKit.Colors

local GrandmaProps = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local RED = rgb(226, 58, 50)
local CREAM = rgb(250, 240, 214)
local YELLOW = rgb(255, 204, 56)
local GOLD = rgb(255, 205, 70)
local SKIN = rgb(255, 205, 170)
local COOKIE = rgb(214, 156, 88)
local CHOCOLATE = rgb(86, 50, 30)
local YARN = { rgb(255, 110, 160), rgb(140, 110, 240), rgb(80, 200, 190), rgb(255, 176, 60) }
GrandmaProps.YarnColors = YARN

-- Placement helpers for one prop: `at(x, y, z)` = CFrame in prop space, `pt(x, y, z)` = world point.
local function frame(cframe: CFrame): ((number, number, number) -> CFrame, (number, number, number) -> Vector3)
	return function(x, y, z)
		return cframe * CFrame.new(x, y, z)
	end, function(x, y, z)
		return (cframe * CFrame.new(x, y, z)).Position
	end
end

-- Flat board from a to b: `width` across (stays horizontal), `thick` normal to it.
local function board(parent: Instance, a: Vector3, b: Vector3, width: number, thick: number, color: Color3, deco: boolean?): BasePart
	return K.Block(parent, Vector3.new(width, thick, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, deco)
end

-- A knitting needle from its knob end `butt` to its `tip`: shaft, pointed tip (unless it is buried) and a
-- round knob.
local function needle(parent: Instance, butt: Vector3, tip: Vector3, diameter: number, color: Color3, knob: Color3, pointed: boolean?)
	local dir = (tip - butt).Unit
	local shaftEnd = if pointed then tip - dir * diameter * 2 else tip
	K.Tube(parent, butt, shaftEnd, diameter, color, true)
	if pointed then
		local base = CFrame.lookAt(shaftEnd, shaftEnd + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
		K.Spire(parent, diameter * 0.75, diameter * 2, base, color, true)
	end
	K.Ball(parent, diameter * 2.2, butt, knob, true)
end

-- Ball of yarn with wound strands crossing around it (bands tilted at alternating angles) and a loose end
-- trailing over the ground toward LookVector. Optionally two knitting needles stuck in it. The ball is solid.
function GrandmaProps.YarnBall(parent: Instance, cframe: CFrame, diameter: number, color: Color3?, needles: boolean?): Model
	local model = K.Model("YarnBall")
	local d = diameter
	local yarn = color or YARN[1]
	local center = (cframe * CFrame.new(0, d * 0.46, 0)).Position
	K.Ball(model, d, center, yarn)
	for i = 0, 7 do
		local tilt = if i % 2 == 0 then math.rad(28) else math.rad(42)
		local turn = CFrame.new(center) * (cframe - cframe.Position) * CFrame.Angles(0, i * math.pi / 4 + 0.2, 0) * CFrame.Angles(0, 0, tilt)
		K.Cylinder(model, Vector3.new(d * 0.035, d * 1.025, d * 1.025), turn, K.Dark(yarn), true)
	end
	local lift = math.max(d * 0.02, 0.06)
	local strand = { (cframe * CFrame.new(d * 0.1, d * 0.06, -d * 0.42)).Position }
	for _, p in { { 0.2, -0.7 }, { -0.05, -0.95 }, { 0.15, -1.2 }, { 0.45, -1.3 } } do
		table.insert(strand, (cframe * CFrame.new(p[1] * d, lift, p[2] * d)).Position)
	end
	for i = 1, #strand - 1 do
		K.Tube(model, strand[i], strand[i + 1], d * 0.04, yarn, true)
	end
	if needles then
		for _, dir in { Vector3.new(0.45, 0.8, 0.35), Vector3.new(-0.5, 0.75, 0.3) } do
			local world = cframe:VectorToWorldSpace(dir.Unit)
			needle(model, center + world * d * 1.05, center - world * d * 0.2, d * 0.06, C.Metal, YARN[3])
		end
	end
	model.Parent = parent
	return model
end

-- Giant knitting needles stuck in the lawn, crossed in an X, with a striped half-knitted scarf hanging over
-- the crossing down both sides (knit rib lines, fringe on the ends). The scarf faces LookVector.
function GrandmaProps.KnittingNeedles(parent: Instance, cframe: CFrame, color: Color3?): Model
	local model = K.Model("KnittingNeedles")
	local at, pt = frame(cframe)
	local yarn = color or YARN[2]
	for _, s in { -1, 1 } do
		needle(model, pt(s * 1.8, 9.0, 0), pt(-s * 3.2, -0.3, 0), 0.4, C.WoodLight, YARN[1])
	end
	local top = 5.75
	local stripes = { yarn, C.Trim, K.Light(yarn) }
	for _, side in { -1, 1 } do
		local from = pt(0, top, side * 0.15)
		local to = pt(0, 0.15, side * 1.6)
		for k = 0, 2 do
			local a, b = from:Lerp(to, k / 3), from:Lerp(to, (k + 1) / 3)
			board(model, a, b, 1.7, 0.18, stripes[k + 1], true)
		end
		local slope = CFrame.lookAt((from + to) / 2, to)
		for _, x in { -0.45, 0.45 } do
			K.Ink(model, Vector3.new(0.06, 0.2, (to - from).Magnitude), slope * CFrame.new(x, 0.02, 0))
		end
		for _, x in { -0.6, 0, 0.6 } do
			K.Rod(model, to + cframe:VectorToWorldSpace(Vector3.new(x, 0, 0)), to + cframe:VectorToWorldSpace(Vector3.new(x, -0.1, side * 0.55)), 0.1, stripes[3], true)
		end
	end
	K.Block(model, Vector3.new(1.7, 0.3, 0.5), at(0, top + 0.05, 0), yarn, true)
	model.Parent = parent
	return model
end

-- Wicker knitting basket for a porch: woven basket with an ink band, three small yarn balls heaped in it and
-- two needles sticking out.
function GrandmaProps.KnittingBasket(parent: Instance, cframe: CFrame): Model
	local model = K.Model("KnittingBasket")
	local _, pt = frame(cframe)
	local woven = rgb(186, 136, 80)
	K.Disc(model, 1.1, 0.15, pt(0, 0, 0), K.Dark(woven), true)
	K.Disc(model, 1.35, 0.55, pt(0, 0.1, 0), woven, true)
	K.Disc(model, 1.39, 0.08, pt(0, 0.3, 0), C.Ink, true)
	K.Disc(model, 1.45, 0.14, pt(0, 0.62, 0), K.Light(woven), true)
	for i, spot in { { -0.25, 0.85, 0.1 }, { 0.25, 0.85, -0.12 }, { 0.02, 1.15, 0.12 } } do
		local center = pt(spot[1], spot[2], spot[3])
		local yarn = YARN[i]
		K.Ball(model, 0.62, center, yarn, true)
		for k = 0, 1 do
			K.Cylinder(model, Vector3.new(0.03, 0.64, 0.64), CFrame.new(center) * CFrame.Angles(0, k * 1.6 + i, math.rad(35)), K.Dark(yarn), true)
		end
	end
	needle(model, pt(0.55, 1.75, 0.35), pt(0.0, 0.7, 0.0), 0.07, C.Metal, YARN[4])
	needle(model, pt(0.75, 1.6, -0.1), pt(0.1, 0.75, 0.05), 0.07, C.Metal, YARN[4])
	model.Parent = parent
	return model
end

-- A pair of fluffy grandma slippers: cream soles with rounded toes and heels, fuzzy toe caps, an ink opening
-- and a pom-pom on each. The toes point toward LookVector.
function GrandmaProps.Slippers(parent: Instance, cframe: CFrame, color: Color3?): Model
	local model = K.Model("Slippers")
	local fluff = color or rgb(255, 140, 190)
	for _, s in { -1, 1 } do
		local foot = cframe * CFrame.new(s * 0.36, 0, s * 0.12) * CFrame.Angles(0, -s * 0.18, 0)
		local at, pt = frame(foot)
		K.Block(model, Vector3.new(0.5, 0.12, 0.6), at(0, 0.06, 0), CREAM, true)
		K.Disc(model, 0.5, 0.12, pt(0, 0, -0.3), CREAM, true)
		K.Disc(model, 0.5, 0.12, pt(0, 0, 0.3), CREAM, true)
		K.Block(model, Vector3.new(0.52, 0.26, 0.42), at(0, 0.25, -0.22), fluff, true)
		K.Disc(model, 0.52, 0.26, pt(0, 0.12, -0.42), fluff, true)
		K.Ink(model, Vector3.new(0.4, 0.04, 0.34), at(0, 0.13, 0.18))
		K.Ball(model, 0.3, pt(0, 0.44, -0.32), K.Light(fluff), true)
	end
	model.Parent = parent
	return model
end

-- Rocking chair: curved rockers (three-segment arcs), legs, seat with a tufted cushion, armrests on spindles,
-- a slanted spindle back with a crest rail and a striped knitted blanket over it. The sitter faces
-- LookVector; the seat is solid.
function GrandmaProps.RockingChair(parent: Instance, cframe: CFrame, cushion: Color3?): Model
	local model = K.Model("RockingChair")
	local at, pt = frame(cframe)
	local wood, dark = C.Wood, K.Dark(C.Wood)
	local pad = cushion or rgb(200, 70, 90)
	local lean = math.rad(10)
	local function back(x: number, y: number): Vector3
		return pt(x, y, 0.7 + (y - 1.5) * math.tan(lean))
	end
	for _, x in { -0.9, 0.9 } do
		local arc = { pt(x, 0.42, -1.15), pt(x, 0.12, -0.45), pt(x, 0.12, 0.45), pt(x, 0.45, 1.2) }
		for i = 1, 3 do
			board(model, arc[i], arc[i + 1], 0.18, 0.18, dark, true)
		end
		K.Block(model, Vector3.new(0.2, 2.15, 0.2), at(x, 1.25, -0.6), wood, true)
		K.Block(model, Vector3.new(0.2, 1.4, 0.2), at(x, 0.85, 0.6), wood, true)
		K.Rod(model, back(x, 1.45), back(x * 1.04, 4.15), 0.22, wood, true)
		K.Block(model, Vector3.new(0.3, 0.12, 1.75), at(x * 1.03, 2.38, -0.05), wood, true)
		K.Rod(model, pt(x, 1.6, 0.3), pt(x, 2.32, 0.3), 0.1, wood, true)
	end
	K.Block(model, Vector3.new(1.95, 0.2, 1.6), at(0, 1.55, 0), wood)
	K.Block(model, Vector3.new(1.6, 0.25, 1.35), at(0, 1.77, -0.05), pad, true)
	for _, x in { -0.4, 0.4 } do
		K.Ink(model, Vector3.new(0.1, 0.04, 0.1), at(x, 1.9, -0.1))
	end
	local crest = back(0, 3.95)
	K.Block(model, Vector3.new(2.15, 0.45, 0.18), CFrame.new(crest) * (cframe - cframe.Position) * CFrame.Angles(lean, 0, 0), wood, true)
	K.Block(model, Vector3.new(1.9, 0.18, 0.12), CFrame.new(back(0, 2.5)) * (cframe - cframe.Position) * CFrame.Angles(lean, 0, 0), wood, true)
	for i = -2, 2 do
		K.Rod(model, back(i * 0.32, 1.65), back(i * 0.32, 3.75), 0.1, wood, true)
	end
	local stripes = { YELLOW, rgb(80, 200, 190), rgb(255, 120, 170) }
	for i, color in stripes do
		local y = 3.55 - (i - 1) * 0.42
		local spot = back(0.3, y) + cframe.LookVector * 0.14
		K.Block(model, Vector3.new(1.4, 0.42, 0.08), CFrame.new(spot) * (cframe - cframe.Position) * CFrame.Angles(lean, 0, 0), color, true)
	end
	model.Parent = parent
	return model
end

-- Grandma's cookie stall: counter with a painted GRANDMA'S COOKIES sign, countertop, four posts, a red and
-- white striped awning with a scalloped valance, a giant chocolate-chip cookie on top, two cookie jars, two
-- trays of cookies, a rolling pin and a chalkboard price easel. Customers stand in front (LookVector); the
-- counter is solid.
function GrandmaProps.CookieStall(parent: Instance, cframe: CFrame): Model
	local model = K.Model("CookieStall")
	local at, pt = frame(cframe)
	local wood, light = C.Wood, C.WoodLight
	K.Block(model, Vector3.new(7.7, 0.35, 2.5), at(0, 0.175, -0.4), K.Dark(wood), true)
	K.Block(model, Vector3.new(7.6, 3.2, 2.4), at(0, 1.6, -0.4), wood)
	local sign = K.Panel(model, 6.2, 1.5, at(0, 1.75, -1.6), CREAM, 0.12, 0.06)
	K.Text(sign, "GRANDMA'S COOKIES", rgb(150, 70, 40))
	K.Block(model, Vector3.new(8.0, 0.25, 2.9), at(0, 3.32, -0.45), light, true)
	for _, x in { -3.75, 3.75 } do
		K.Block(model, Vector3.new(0.35, 6.3, 0.35), at(x, 3.15, -1.75), light, true)
		K.Block(model, Vector3.new(0.35, 7.4, 0.35), at(x, 3.7, 1.0), light, true)
	end
	for i = 1, 6 do
		local x = -3.45 + (i - 1) * 1.38
		board(model, pt(x, 7.45, 1.15), pt(x, 6.2, -2.35), 1.38, 0.15, if i % 2 == 0 then C.Trim else RED, true)
	end
	K.Block(model, Vector3.new(8.3, 0.4, 0.1), at(0, 6.0, -2.4), RED, true)
	for i = 1, 6 do
		local x = -3.45 + (i - 1) * 1.38
		K.Cylinder(model, Vector3.new(0.08, 0.9, 0.9), at(x, 5.8, -2.3) * CFrame.Angles(0, math.pi / 2, 0), if i % 2 == 0 then RED else C.Trim, true)
	end
	local big = at(0, 8.7, 0.95)
	K.Cylinder(model, Vector3.new(0.3, 2.8, 2.8), big * CFrame.new(0, 0, 0.05) * CFrame.Angles(0, math.pi / 2, 0), C.Ink, true)
	K.Cylinder(model, Vector3.new(0.35, 2.6, 2.6), big * CFrame.Angles(0, math.pi / 2, 0), COOKIE, true)
	for _, chip in { { -0.6, 0.5 }, { 0.5, 0.7 }, { 0.1, -0.1 }, { -0.5, -0.6 }, { 0.65, -0.5 } } do
		K.Block(model, Vector3.new(0.32, 0.3, 0.1), big * CFrame.new(chip[1], chip[2], -0.2) * CFrame.Angles(0, 0, chip[1]), CHOCOLATE, true)
	end
	for _, x in { -2.9, -1.8 } do
		local jar = pt(x, 3.45, -0.55)
		local glass = K.Disc(model, 0.85, 1.0, jar, C.Glass, true)
		glass.Transparency = 0.35
		for _, y in { 0.1, 0.28 } do
			K.Disc(model, 0.62, 0.14, jar + Vector3.new(0, y, 0), COOKIE, true)
		end
		K.Disc(model, 0.92, 0.15, jar + Vector3.new(0, 1.0, 0), RED, true)
		K.Ball(model, 0.22, jar + Vector3.new(0, 1.2, 0), C.Trim, true)
	end
	for _, x in { 0.5, 2.4 } do
		K.Block(model, Vector3.new(1.6, 0.08, 1.0), at(x, 3.49, -0.75), C.Metal, true)
		for k = -1, 1 do
			local spot = pt(x + k * 0.5, 3.53, -0.75 + (k % 2) * 0.15)
			K.Disc(model, 0.45, 0.1, spot, COOKIE, true)
			K.Block(model, Vector3.new(0.1, 0.04, 0.1), CFrame.new(spot + Vector3.new(0.06, 0.11, 0)), CHOCOLATE, true)
		end
	end
	K.Tube(model, pt(-0.6, 3.62, 0.3), pt(0.4, 3.62, 0.15), 0.3, light, true)
	K.Tube(model, pt(-0.95, 3.62, 0.35), pt(-0.6, 3.62, 0.3), 0.14, K.Dark(wood), true)
	K.Tube(model, pt(0.4, 3.62, 0.15), pt(0.75, 3.62, 0.1), 0.14, K.Dark(wood), true)
	local easel = at(5.0, 0, -2.6) * CFrame.Angles(0, -0.35, 0)
	local lean = easel * CFrame.new(0, 1.9, 0) * CFrame.Angles(math.rad(12), 0, 0)
	K.Block(model, Vector3.new(1.6, 2.0, 0.08), lean * CFrame.new(0, 0, 0.05), light, true)
	local chalk = K.Block(model, Vector3.new(1.35, 1.75, 0.06), lean, rgb(40, 60, 50), true)
	K.Text(chalk, "FRESH COOKIES 5¢", C.Trim)
	for _, x in { -0.65, 0.65 } do
		K.Rod(model, (easel * CFrame.new(x, 3.0, 0.2)).Position, (easel * CFrame.new(x, 0, -0.25)).Position, 0.12, light, true)
	end
	K.Rod(model, (easel * CFrame.new(0, 2.8, 0.25)).Position, (easel * CFrame.new(0, 0, 0.9)).Position, 0.12, light, true)
	model.Parent = parent
	return model
end

-- BINGO TONIGHT marquee sign: two posts on footings, a red board with two lettered panels, a row of glowing
-- bulbs along the top and bottom edges and five bingo balls (B I N G O) on top. Reads toward LookVector.
function GrandmaProps.BingoSign(parent: Instance, cframe: CFrame): Model
	local model = K.Model("BingoSign")
	local at, pt = frame(cframe)
	for _, x in { -3.7, 3.7 } do
		K.Block(model, Vector3.new(1.0, 0.3, 1.0), at(x, 0.15, 0.3), C.Stone, true)
		K.Block(model, Vector3.new(0.5, 6.8, 0.5), at(x, 3.4, 0.3), C.MetalDark)
	end
	K.Block(model, Vector3.new(7.9, 3.4, 0.5), at(0, 5.2, 0.15), RED, true)
	local top = K.Panel(model, 7.0, 1.5, at(0, 5.75, -0.1), CREAM, 0.1, 0.05)
	K.Text(top, "BINGO TONIGHT!", RED)
	local bottom = K.Panel(model, 7.0, 0.8, at(0, 4.35, -0.1), rgb(40, 70, 140), 0.1, 0.05)
	K.Text(bottom, "7 PM - RETIREMENT HOME", YELLOW)
	for _, y in { 3.68, 6.72 } do
		for x = -3.6, 3.61, 1.2 do
			local bulb = K.Ball(model, 0.24, pt(x, y, -0.15), rgb(255, 236, 140), true)
			bulb.Material = Enum.Material.Neon
		end
	end
	local colors = { rgb(60, 120, 230), RED, rgb(60, 180, 90), YELLOW, rgb(150, 90, 220) }
	for i, letter in { "B", "I", "N", "G", "O" } do
		local center = pt((i - 3) * 1.3, 7.48, 0.1)
		K.Ball(model, 1.15, center, colors[i], true)
		local face = K.Cylinder(model, Vector3.new(0.06, 0.66, 0.66), CFrame.new(center) * (cframe - cframe.Position) * CFrame.new(0, 0, -0.53) * CFrame.Angles(0, math.pi / 2, 0), C.Trim, true)
		K.Text(face, letter, C.Ink, false, Enum.NormalId.Right)
	end
	model.Parent = parent
	return model
end

-- Retirement-home billboard: two I-beam legs on footings, a catwalk with a thin railing, a framed board with a
-- painted smiling grandma (gray hair and bun, glasses, rosy cheeks, cardigan), SUNNY ACRES RETIREMENT HOME
-- lettering, a slogan banner, an OPEN HOUSE burst, and three gooseneck lamps on top. Faces LookVector.
function GrandmaProps.RetirementBillboard(parent: Instance, cframe: CFrame, slogan: string?): Model
	local model = K.Model("RetirementBillboard")
	local at, pt = frame(cframe)
	local steel = C.MetalDark
	for _, x in { -6, 6 } do
		K.Block(model, Vector3.new(1.8, 0.4, 1.8), at(x, 0.2, 0.9), C.Stone, true)
		K.Block(model, Vector3.new(0.35, 8.4, 0.7), at(x, 4.2, 0.9), steel)
		for _, z in { 0.55, 1.25 } do
			K.Block(model, Vector3.new(1.1, 8.4, 0.14), at(x, 4.2, z), steel, true)
		end
	end
	K.Block(model, Vector3.new(20, 0.2, 1.3), at(0, 7.8, -0.55), steel, true)
	for x = -9, 9.01, 4.5 do
		K.Rod(model, pt(x, 7.9, -1.15), pt(x, 8.8, -1.15), 0.1, steel, true)
	end
	K.Tube(model, pt(-9.5, 8.8, -1.15), pt(9.5, 8.8, -1.15), 0.12, steel, true)
	K.Block(model, Vector3.new(22.6, 9.6, 0.6), at(0, 13.0, 0.3), C.Metal)
	K.Panel(model, 22, 9, at(0, 13.0, 0), rgb(150, 214, 255), 0.3, 0.1)
	local face = -0.2 -- front of the painted board
	local function paint(x: number, y: number, layer: number): CFrame
		return at(x, y, face - 0.04 * layer) * CFrame.Angles(0, math.pi / 2, 0)
	end
	local function round(diameter: number, x: number, y: number, layer: number, color: Color3)
		K.Cylinder(model, Vector3.new(0.04, diameter, diameter), paint(x, y, layer), color, true)
	end
	local hair = rgb(200, 200, 214)
	K.Block(model, Vector3.new(6.4, 1.8, 0.04), at(-6.8, 9.4, face - 0.02), rgb(150, 90, 200), true)
	round(5.4, -6.8, 12.6, 1, hair)
	round(2.2, -6.8, 15.5, 1, hair)
	round(4.4, -6.8, 12.2, 2, SKIN)
	for _, s in { -1, 1 } do
		round(1.55, -6.8 + s * 1.0, 12.7, 3, C.Ink)
		round(1.15, -6.8 + s * 1.0, 12.7, 4, C.GlassShine)
		round(0.35, -6.8 + s * 1.0, 12.6, 5, C.Ink)
		round(0.8, -6.8 + s * 1.55, 11.55, 3, rgb(255, 140, 150))
	end
	K.Block(model, Vector3.new(0.5, 0.12, 0.04), at(-6.8, 12.7, face - 0.14), C.Ink, true)
	round(0.55, -6.8, 11.85, 3, K.Dark(SKIN))
	K.Block(model, Vector3.new(1.4, 0.22, 0.04), at(-6.8, 10.95, face - 0.12), C.Ink, true)
	for _, s in { -1, 1 } do
		K.Block(model, Vector3.new(0.6, 0.22, 0.04), at(-6.8 + s * 0.9, 11.1, face - 0.12) * CFrame.Angles(0, 0, s * 0.5), C.Ink, true)
	end
	local title = K.Panel(model, 12.4, 2.4, at(3.2, 15.4, face), C.Trim, 0.12, 0.04)
	K.Text(title, "SUNNY ACRES", RED)
	local subtitle = K.Panel(model, 12.4, 1.4, at(3.2, 13.2, face), rgb(40, 70, 140), 0.12, 0.04)
	K.Text(subtitle, "RETIREMENT HOME", YELLOW)
	local banner = K.Panel(model, 10.4, 1.3, at(1.8, 10.6, face), YELLOW, 0.12, 0.04)
	K.Text(banner, slogan or "BINGO EVERY NIGHT!", C.Ink)
	local burst = at(9.0, 10.5, face - 0.1)
	K.Block(model, Vector3.new(2.6, 2.6, 0.05), burst * CFrame.Angles(0, 0, math.pi / 4), RED, true)
	local burstFront = K.Block(model, Vector3.new(2.6, 2.6, 0.06), burst * CFrame.new(0, 0, -0.02), RED, true)
	K.Text(burstFront, "OPEN HOUSE!", C.Trim)
	for x = -7, 7.01, 7 do
		local base, bend, head = pt(x, 17.8, 0.4), pt(x, 19.0, 0.0), pt(x, 18.9, -1.6)
		K.Rod(model, base, bend, 0.18, steel, true)
		K.Rod(model, bend, head, 0.18, steel, true)
		K.Block(model, Vector3.new(1.3, 0.4, 0.7), CFrame.new(head) * (cframe - cframe.Position), steel, true)
		local lens = K.Block(model, Vector3.new(1.1, 0.08, 0.5), CFrame.new(head) * (cframe - cframe.Position) * CFrame.new(0, -0.22, 0), rgb(255, 236, 170), true)
		lens.Material = Enum.Material.Neon
	end
	model.Parent = parent
	return model
end

-- Heroic grandma statue in green-bronze on a stepped stone plinth with a gold plaque: sensible shoes,
-- two-tier skirt, shawl, round head with hair, bun, glasses and nose, one arm raising a rolling pin, the
-- other holding a handbag. Faces LookVector; the plinth is solid.
function GrandmaProps.GrandmaStatue(parent: Instance, cframe: CFrame, color: Color3?): Model
	local model = K.Model("GrandmaStatue")
	local at, pt = frame(cframe)
	local bronze = color or rgb(88, 168, 146)
	local dark, light = K.Dark(bronze), K.Light(bronze)
	K.Block(model, Vector3.new(3.6, 0.6, 3.6), at(0, 0.3, 0), K.Dark(C.Stone), true)
	K.Block(model, Vector3.new(2.8, 2.6, 2.8), at(0, 1.9, 0), C.Stone)
	K.Block(model, Vector3.new(3.2, 0.4, 3.2), at(0, 3.4, 0), K.Light(C.Stone), true)
	local plaque = K.Panel(model, 2.3, 0.9, at(0, 1.95, -1.4), GOLD, 0.08, 0.06)
	K.Text(plaque, "OUR HERO GRANNY", K.Dark(GOLD))
	for _, x in { -0.4, 0.4 } do
		K.Block(model, Vector3.new(0.55, 0.3, 0.85), at(x, 3.75, -0.15), dark, true)
	end
	K.Octagon(model, 2.3, 1.1, at(0, 4.3, 0), bronze, true)
	K.Octagon(model, 1.95, 1.0, at(0, 5.35, 0), light, true)
	K.Block(model, Vector3.new(1.75, 1.6, 1.15), at(0, 6.6, 0), bronze, true)
	K.Block(model, Vector3.new(2.05, 0.55, 1.35), at(0, 7.25, 0), dark, true)
	K.Ball(model, 1.45, pt(0, 8.25, 0), light, true)
	K.Ball(model, 1.5, pt(0, 8.45, 0.14), dark, true)
	K.Ball(model, 0.85, pt(0, 9.25, 0.3), dark, true)
	K.Ball(model, 0.28, pt(0, 8.12, -0.72), bronze, true)
	for _, x in { -0.3, 0.3 } do
		K.Cylinder(model, Vector3.new(0.06, 0.46, 0.46), at(x, 8.32, -0.68) * CFrame.Angles(0, math.pi / 2, 0), C.Ink, true)
		K.Cylinder(model, Vector3.new(0.06, 0.32, 0.32), at(x, 8.32, -0.7) * CFrame.Angles(0, math.pi / 2, 0), light, true)
	end
	K.Rod(model, pt(0.95, 7.2, 0), pt(1.35, 8.2, -0.15), 0.5, bronze, true)
	K.Rod(model, pt(1.35, 8.2, -0.15), pt(1.45, 9.45, -0.25), 0.45, bronze, true)
	K.Ball(model, 0.55, pt(1.45, 9.6, -0.25), light, true)
	K.Tube(model, pt(0.55, 9.75, -0.25), pt(2.35, 9.75, -0.25), 0.45, light, true)
	for _, ends in { { 0.2, 0.55 }, { 2.35, 2.7 } } do
		K.Tube(model, pt(ends[1], 9.75, -0.25), pt(ends[2], 9.75, -0.25), 0.2, dark, true)
	end
	K.Rod(model, pt(-0.95, 7.2, 0), pt(-1.3, 6.0, -0.2), 0.48, bronze, true)
	K.Ball(model, 0.5, pt(-1.32, 5.85, -0.22), light, true)
	K.Block(model, Vector3.new(0.85, 0.7, 0.4), at(-1.45, 5.25, -0.2), dark, true)
	K.Rod(model, pt(-1.75, 5.55, -0.2), pt(-1.32, 5.95, -0.22), 0.08, dark, true)
	K.Rod(model, pt(-1.15, 5.55, -0.2), pt(-1.32, 5.95, -0.22), 0.08, dark, true)
	model.Parent = parent
	return model
end

-- Shopping cart: wire basket (top and bottom rims, corner posts, side and front wires, floor), folded child
-- seat, red handle, chassis with a lower rack and four caster wheels, and (unless `empty`) groceries: paper
-- bag with a baguette and greens, milk carton, apples, a box of PRUNES and a ball of yarn. The handle is at the
-- back; it rolls toward LookVector. Decoration only.
function GrandmaProps.ShoppingCart(parent: Instance, cframe: CFrame, rng: Random, empty: boolean?): Model
	local model = K.Model("ShoppingCart")
	local at, pt = frame(cframe)
	local wire = C.Metal
	local top = { pt(-0.95, 3.0, -1.5), pt(0.95, 3.0, -1.5), pt(0.95, 3.0, 1.5), pt(-0.95, 3.0, 1.5) }
	local bottom = { pt(-0.75, 1.3, -1.1), pt(0.75, 1.3, -1.1), pt(0.75, 1.3, 1.35), pt(-0.75, 1.3, 1.35) }
	for i = 1, 4 do
		local j = i % 4 + 1
		K.Tube(model, top[i], top[j], 0.1, wire, true)
		K.Tube(model, bottom[i], bottom[j], 0.08, wire, true)
		K.Rod(model, top[i], bottom[i], 0.07, wire, true)
	end
	for _, t in { 0.33, 0.66 } do
		K.Rod(model, top[2]:Lerp(top[3], t), bottom[2]:Lerp(bottom[3], t), 0.05, wire, true)
		K.Rod(model, top[1]:Lerp(top[4], t), bottom[1]:Lerp(bottom[4], t), 0.05, wire, true)
		K.Rod(model, top[1]:Lerp(top[2], t), bottom[1]:Lerp(bottom[2], t), 0.05, wire, true)
	end
	for _, side in { { 1, 4 }, { 2, 3 } } do
		K.Rod(model, top[side[1]]:Lerp(bottom[side[1]], 0.5), top[side[2]]:Lerp(bottom[side[2]], 0.5), 0.05, wire, true)
	end
	K.Block(model, Vector3.new(1.5, 0.05, 2.45), at(0, 1.3, 0.12), C.MetalDark, true)
	local red = RED
	K.Block(model, Vector3.new(1.7, 0.08, 0.9), at(0, 3.05, 1.05), red, true)
	for _, x in { -0.95, 0.95 } do
		K.Rod(model, pt(x, 3.0, 1.5), pt(x * 0.92, 3.35, 1.85), 0.08, wire, true)
	end
	K.Tube(model, pt(-0.92, 3.35, 1.85), pt(0.92, 3.35, 1.85), 0.22, red, true)
	for _, x in { -0.6, 0.6 } do
		K.Tube(model, pt(x, 0.5, -1.3), pt(x, 0.5, 1.4), 0.1, wire, true)
		K.Rod(model, pt(x, 1.3, 1.3), pt(x, 0.5, 1.35), 0.08, wire, true)
		K.Rod(model, pt(x, 1.3, -1.05), pt(x, 0.5, -1.15), 0.08, wire, true)
		for _, z in { -1.2, 1.25 } do
			K.Cylinder(model, Vector3.new(0.12, 0.4, 0.4), at(x, 0.2, z), C.Ink, true)
		end
	end
	K.Block(model, Vector3.new(1.2, 0.05, 1.8), at(0, 0.55, 0.05), C.MetalDark, true)
	if not empty then
		local kraft = rgb(196, 150, 100)
		K.Block(model, Vector3.new(0.85, 1.05, 0.65), at(0.35, 1.85, 0.6), kraft, true)
		K.Block(model, Vector3.new(0.89, 0.18, 0.69), at(0.35, 2.3, 0.6), K.Light(kraft), true)
		local loafA, loafB = pt(0.25, 2.1, 0.5), pt(0.55, 3.45, 0.25)
		K.Tube(model, loafA, loafB, 0.3, rgb(230, 170, 90), true)
		for _, t in { 0.55, 0.75 } do
			K.Block(model, Vector3.new(0.2, 0.05, 0.32), CFrame.lookAt(loafA:Lerp(loafB, t), loafB) * CFrame.new(0, 0.14, 0), K.Dark(rgb(230, 170, 90)), true)
		end
		K.Gem(model, 0.45, pt(0.55, 2.55, 0.75), C.Leaves[2], rng, true)
		K.Block(model, Vector3.new(0.42, 0.65, 0.42), at(-0.4, 1.66, 0.75), C.Trim, true)
		K.Prism(model, 0.42, 0.42, 0.22, at(-0.4, 1.98, 0.75), C.Trim, true)
		K.Block(model, Vector3.new(0.44, 0.18, 0.44), at(-0.4, 1.6, 0.75), rgb(60, 120, 230), true)
		for i, spot in { { -0.35, -0.55 }, { -0.05, -0.75 }, { -0.4, -0.85 } } do
			K.Ball(model, 0.4, pt(spot[1], 1.53 + (i - 1) * 0.02, spot[2]), RED, true)
		end
		local box = K.Block(model, Vector3.new(0.7, 0.5, 0.45), at(-0.25, 1.58, 0.05), rgb(130, 70, 160), true)
		K.Text(box, "PRUNES", C.Trim)
		K.Ball(model, 0.55, pt(0.4, 1.6, -0.6), YARN[1], true)
		K.Cylinder(model, Vector3.new(0.03, 0.57, 0.57), at(0.4, 1.6, -0.6) * CFrame.Angles(0, 0.6, math.rad(30)), K.Dark(YARN[1]), true)
	end
	model.Parent = parent
	return model
end

return GrandmaProps
