--!nonstrict
-- Residential props for front yards, porches and driveways, built from ComicKit parts: wooden mailbox, hose
-- reel, lawn mower, wheelbarrow, garden tools (shovel, rake, pitchfork, tool rack), flowerpots, watering can,
-- gnome, flamingo, outdoor (Adirondack) chair, wooden patio table, kettle grill, trash and recycling bins,
-- welcome sign, hanging flower basket, doghouse, birdhouse, wooden crate, bunting and a weather vane.
-- Every builder takes a parent and a ground CFrame (LookVector = the prop's front) and returns a Model.
-- Small props are pure decoration (no collision, no raycasts, no shadow); bigger ones keep one solid core
-- (bins, doghouse, crate, grill) to bump into. Houses and MapBuilder place them; anything inside the arena
-- also needs an enemy obstacle there.

local ComicKit = require(script.Parent.ComicKit)

local K = ComicKit
local C = ComicKit.Colors

local YardProps = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local RED = rgb(226, 58, 50)
local YELLOW = rgb(255, 204, 56)
local BLACK = rgb(42, 44, 52)
local TERRACOTTA = rgb(214, 112, 72)
local CREAM = rgb(250, 240, 214)
local PAINTS = { rgb(236, 84, 84), rgb(70, 190, 180), rgb(255, 204, 56), rgb(250, 248, 240), rgb(120, 170, 240) }

-- Placement helpers for one prop: `at(x, y, z)` = CFrame in prop space, `pt(x, y, z)` = world point.
local function frame(cframe: CFrame): ((number, number, number) -> CFrame, (number, number, number) -> Vector3)
	return function(x, y, z)
		return cframe * CFrame.new(x, y, z)
	end, function(x, y, z)
		return (cframe * CFrame.new(x, y, z)).Position
	end
end

-- Flat board from a to b (seat slats, roof boards): `width` across (stays horizontal), `thick` normal to it.
local function board(parent: Instance, a: Vector3, b: Vector3, width: number, thick: number, color: Color3, deco: boolean?): BasePart
	return K.Block(parent, Vector3.new(width, thick, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, deco)
end

-- Little flower painted or growing: four petals (a turned square) around a yellow center, facing `cframe`'s
-- up (lying) direction.
local function blossom(parent: Instance, cframe: CFrame, size: number, color: Color3)
	K.Block(parent, Vector3.new(size, size * 0.3, size), cframe * CFrame.Angles(0, math.pi / 4, 0), color, true)
	K.Block(parent, Vector3.new(size * 0.4, size * 0.36, size * 0.4), cframe, YELLOW, true)
end

-------------------------------------------------------------------------------------------- mailbox

-- Wooden post mailbox shaped like a tiny house: footing, post with a brace, gable roof, inked door with a
-- knob, red flag and a house-number plate. Door faces LookVector.
function YardProps.Mailbox(parent: Instance, cframe: CFrame, color: Color3?, number: string?): Model
	local model = K.Model("Mailbox")
	local at, pt = frame(cframe)
	local paint = color or RED
	local wood = C.Wood
	K.Block(model, Vector3.new(0.9, 0.25, 0.9), at(0, 0.12, 0), K.Dark(C.Stone), true)
	K.Block(model, Vector3.new(0.5, 3.6, 0.5), at(0, 1.8, 0), wood)
	K.Block(model, Vector3.new(0.5, 0.3, 2.3), at(0, 3.55, 0.15), K.Dark(wood), true)
	K.Rod(model, pt(0, 2.5, 0.25), pt(0, 3.4, 0.95), 0.24, K.Dark(wood), true)
	local box = at(0, 4.15, 0)
	K.Block(model, Vector3.new(1.2, 0.9, 2.0), box, paint, true)
	K.Prism(model, 2.3, 1.55, 0.7, box * CFrame.new(0, 0.45, 0) * CFrame.Angles(0, math.pi / 2, 0), C.Roofs[1], true)
	K.Block(model, Vector3.new(0.18, 0.14, 2.35), box * CFrame.new(0, 1.17, 0), C.Ink, true)
	K.Panel(model, 0.85, 0.66, box * CFrame.new(0, -0.02, -1.0), K.Light(C.WoodLight), 0.08, 0.06)
	K.Ball(model, 0.16, (box * CFrame.new(0.28, -0.02, -1.2)).Position, YELLOW, true)
	K.Block(model, Vector3.new(0.08, 0.8, 0.1), box * CFrame.new(0.66, 0.15, 0.55), C.MetalDark, true)
	K.Block(model, Vector3.new(0.08, 0.38, 0.55), box * CFrame.new(0.68, 0.4, 0.3), RED, true)
	local plate = K.Panel(model, 0.42, 0.6, at(0, 2.6, -0.25), C.Trim, 0.06, 0.05)
	K.Text(plate, number or "12", C.Ink)
	model.Parent = parent
	return model
end

-------------------------------------------------------------------------------------------- garden gear

-- Garden hose reel cart: A-frame stand with a carry handle, two drum ends, the wound hose with ink coil lines,
-- a crank, and the hose snaking over the grass to a pistol nozzle. The reel axle runs along X.
function YardProps.HoseReel(parent: Instance, cframe: CFrame, hoseColor: Color3?): Model
	local model = K.Model("HoseReel")
	local at, pt = frame(cframe)
	local hose = hoseColor or rgb(70, 176, 74)
	local steel = C.MetalDark
	for _, x in { -0.85, 0.85 } do
		K.Block(model, Vector3.new(0.25, 0.2, 1.6), at(x, 0.1, 0), steel, true)
		K.Rod(model, pt(x, 0.15, -0.7), pt(x, 1.6, 0), 0.16, steel, true)
		K.Rod(model, pt(x, 0.15, 0.7), pt(x, 1.6, 0), 0.16, steel, true)
		K.Rod(model, pt(x, 1.6, 0), pt(x, 2.6, 0.2), 0.16, steel, true)
	end
	K.Tube(model, pt(-0.6, 2.6, 0.2), pt(0.6, 2.6, 0.2), 0.28, YELLOW, true)
	K.Tube(model, pt(-0.95, 1.6, 0), pt(1.08, 1.6, 0), 0.18, C.Metal, true)
	for _, x in { -0.68, 0.68 } do
		K.Cylinder(model, Vector3.new(0.12, 1.9, 1.9), at(x, 1.6, 0), YELLOW, true)
	end
	K.Cylinder(model, Vector3.new(1.24, 1.4, 1.4), at(0, 1.6, 0), hose, true)
	for _, x in { -0.3, 0, 0.3 } do
		K.Cylinder(model, Vector3.new(0.05, 1.44, 1.44), at(x, 1.6, 0), C.Ink, true)
	end
	K.Rod(model, pt(1.02, 1.6, 0), pt(1.02, 2.15, -0.3), 0.12, C.Metal, true)
	K.Tube(model, pt(1.02, 2.15, -0.3), pt(1.34, 2.15, -0.3), 0.2, RED, true)

	local path = { pt(0.1, 0.95, -0.6), pt(0.3, 0.12, -1.3), pt(0.9, 0.12, -2.2), pt(1.9, 0.12, -2.6), pt(2.6, 0.12, -3.5), pt(2.3, 0.12, -4.6), pt(1.3, 0.12, -5.0) }
	for i = 1, #path - 1 do
		K.Tube(model, path[i], path[i + 1], 0.22, hose, true)
		if i > 1 then
			K.Ball(model, 0.22, path[i], hose, true)
		end
	end
	local tip, before = path[#path], path[#path - 1]
	local nozzle = CFrame.lookAt(tip, tip + (tip - before))
	K.Block(model, Vector3.new(0.28, 0.28, 0.75), nozzle * CFrame.new(0, 0.04, -0.35), C.Metal, true)
	K.Block(model, Vector3.new(0.6, 0.22, 0.24), nozzle * CFrame.new(0.32, 0.02, -0.15), BLACK, true)
	K.Block(model, Vector3.new(0.4, 0.1, 0.08), nozzle * CFrame.new(0.25, 0.02, -0.38), RED, true)
	K.Tube(model, (nozzle * CFrame.new(0, 0.04, -0.7)).Position, (nozzle * CFrame.new(0, 0.04, -1.0)).Position, 0.22, YELLOW, true)
	model.Parent = parent
	return model
end

-- Push lawn mower: bevelled deck with a dark skirt, engine with a cap, fuel cap and pull-start, four wheels
-- with yellow hubcaps, grass-catcher bag, handle with a black grip and a red bail bar. Drives toward
-- LookVector; the handle is at the back.
function YardProps.LawnMower(parent: Instance, cframe: CFrame, color: Color3?): Model
	local model = K.Model("LawnMower")
	local at, pt = frame(cframe)
	local body = color or RED
	K.Block(model, Vector3.new(1.95, 0.14, 2.1), at(0, 0.36, 0), BLACK, true)
	K.Block(model, Vector3.new(1.8, 0.42, 1.95), at(0, 0.62, 0), body, true)
	K.Block(model, Vector3.new(1.5, 0.24, 1.5), at(0, 0.95, 0.15), K.Light(body), true)
	K.Wedge(model, Vector3.new(1.5, 0.24, 0.35), at(0, 0.95, -0.77), K.Light(body), true)
	K.Disc(model, 1.0, 0.6, pt(0, 1.07, 0.2), BLACK, true)
	K.Disc(model, 0.85, 0.12, pt(0, 1.67, 0.2), body, true)
	K.Disc(model, 0.22, 0.1, pt(0.22, 1.79, 0.38), YELLOW, true)
	K.Block(model, Vector3.new(0.4, 0.12, 0.14), at(-0.15, 1.85, 0.0), BLACK, true)
	K.Block(model, Vector3.new(0.36, 0.34, 0.3), at(0.48, 1.3, -0.15), C.MetalDark, true)
	for _, x in { -0.98, 0.98 } do
		for _, z in { -0.72, 0.75 } do
			K.Cylinder(model, Vector3.new(0.28, 0.8, 0.8), at(x, 0.4, z), BLACK, true)
			K.Cylinder(model, Vector3.new(0.06, 0.42, 0.42), at(x * 1.14, 0.4, z), YELLOW, true)
		end
	end
	local bag = rgb(64, 146, 78)
	K.Block(model, Vector3.new(1.3, 0.8, 0.95), at(0, 0.95, 1.5), bag, true)
	K.Wedge(model, Vector3.new(1.3, 0.3, 0.95), at(0, 1.5, 1.5) * CFrame.Angles(0, math.pi, 0), bag, true)
	K.Tube(model, pt(-0.68, 1.36, 1.05), pt(0.68, 1.36, 1.05), 0.1, C.Ink, true)
	for _, x in { -0.7, 0.7 } do
		K.Rod(model, pt(x, 0.85, 0.9), pt(x, 2.75, 2.35), 0.12, C.Metal, true)
	end
	K.Tube(model, pt(-0.75, 1.8, 1.65), pt(0.75, 1.8, 1.65), 0.1, C.Metal, true)
	K.Tube(model, pt(-0.78, 2.75, 2.35), pt(0.78, 2.75, 2.35), 0.2, BLACK, true)
	K.Tube(model, pt(-0.6, 2.55, 2.12), pt(0.6, 2.55, 2.12), 0.09, RED, true)
	model.Parent = parent
	return model
end

-- Wheelbarrow: flared metal tray (sloped front, tilted sides), soil load, front wheel on a fork, two long
-- handles with black grips and two legs. The wheel is at the front (LookVector).
function YardProps.Wheelbarrow(parent: Instance, cframe: CFrame, color: Color3?): Model
	local model = K.Model("Wheelbarrow")
	local at, pt = frame(cframe)
	local tray = color or rgb(66, 150, 96)
	K.Block(model, Vector3.new(1.3, 0.12, 1.8), at(0, 1.05, 0.1), K.Dark(tray), true)
	for _, s in { -1, 1 } do
		K.Block(model, Vector3.new(0.1, 0.85, 2.0), at(s * 0.8, 1.45, 0.1) * CFrame.Angles(0, 0, -s * math.rad(18)), tray, true)
	end
	K.Block(model, Vector3.new(1.55, 1.0, 0.1), at(0, 1.45, -0.98) * CFrame.Angles(math.rad(-35), 0, 0), tray, true)
	K.Block(model, Vector3.new(1.55, 0.85, 0.1), at(0, 1.45, 1.1) * CFrame.Angles(math.rad(14), 0, 0), tray, true)
	K.Block(model, Vector3.new(1.4, 0.3, 1.75), at(0, 1.6, 0.05), rgb(110, 72, 44), true)
	K.Gem(model, 0.9, pt(0.1, 1.85, 0.1), rgb(96, 62, 38), Random.new(3), true)
	K.Cylinder(model, Vector3.new(0.3, 1.1, 1.1), at(0, 0.55, -1.45), BLACK, true)
	K.Cylinder(model, Vector3.new(0.34, 0.36, 0.36), at(0, 0.55, -1.45), C.Metal, true)
	for _, s in { -1, 1 } do
		K.Rod(model, pt(s * 0.24, 0.55, -1.45), pt(s * 0.42, 1.0, -0.75), 0.1, C.MetalDark, true)
		K.Rod(model, pt(s * 0.42, 0.85, -1.1), pt(s * 0.78, 1.12, 1.8), 0.14, C.Wood, true)
		K.Tube(model, pt(s * 0.78, 1.12, 1.75), pt(s * 0.82, 1.2, 2.45), 0.2, BLACK, true)
		K.Rod(model, pt(s * 0.6, 1.0, 0.85), pt(s * 0.66, 0.05, 1.05), 0.12, C.MetalDark, true)
	end
	model.Parent = parent
	return model
end

-- One long-handled garden tool, built standing on its head: cframe = ground point under the head, the handle
-- runs up local Y (tilt the cframe to lean it). Kinds: "Shovel", "Rake", "Pitchfork".
function YardProps.Tool(parent: Instance, cframe: CFrame, kind: string): Model
	local model = K.Model(kind)
	local at, pt = frame(cframe)
	local steel, handle = C.Metal, C.WoodLight
	if kind == "Shovel" then
		K.Block(model, Vector3.new(0.65, 0.72, 0.06), at(0, 0.62, 0), steel, true)
		K.Block(model, Vector3.new(0.46, 0.46, 0.06), at(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 4), steel, true)
		K.Block(model, Vector3.new(0.2, 0.36, 0.14), at(0, 1.1, 0), C.MetalDark, true)
		K.Tube(model, pt(0, 1.2, 0), pt(0, 3.3, 0), 0.14, handle, true)
		for _, s in { -1, 1 } do
			K.Rod(model, pt(0, 3.25, 0), pt(s * 0.22, 3.6, 0), 0.08, C.MetalDark, true)
		end
		K.Tube(model, pt(-0.24, 3.62, 0), pt(0.24, 3.62, 0), 0.14, BLACK, true)
	elseif kind == "Rake" then
		K.Tube(model, pt(-0.7, 0.35, 0), pt(0.7, 0.35, 0), 0.12, steel, true)
		for i = -3, 3 do
			K.Rod(model, pt(i * 0.21, 0.35, 0), pt(i * 0.21, 0.02, -0.12), 0.06, C.MetalDark, true)
		end
		for _, s in { -1, 1 } do
			K.Rod(model, pt(s * 0.5, 0.35, 0), pt(0, 0.85, 0), 0.06, C.MetalDark, true)
		end
		K.Tube(model, pt(0, 0.35, 0), pt(0, 4.0, 0), 0.13, handle, true)
	else -- Pitchfork
		K.Block(model, Vector3.new(0.68, 0.14, 0.1), at(0, 1.05, 0), steel, true)
		for i = -1.5, 1.5 do
			K.Rod(model, pt(i * 0.21, 1.05, 0), pt(i * 0.21, 0.02, -0.08), 0.07, steel, true)
		end
		K.Block(model, Vector3.new(0.18, 0.4, 0.14), at(0, 1.3, 0), C.MetalDark, true)
		K.Tube(model, pt(0, 1.4, 0), pt(0, 3.4, 0), 0.14, handle, true)
		K.Tube(model, pt(-0.24, 3.55, 0), pt(0.24, 3.55, 0), 0.14, BLACK, true)
		for _, s in { -1, 1 } do
			K.Rod(model, pt(0, 3.35, 0), pt(s * 0.22, 3.55, 0), 0.08, C.MetalDark, true)
		end
	end
	model.Parent = parent
	return model
end

-- Wooden tool rack against a wall or fence: base board, two posts and a rail with a shovel, a rake and a
-- pitchfork leaning on it, and a metal bucket with a trowel. The tools lean back (away from LookVector).
function YardProps.GardenTools(parent: Instance, cframe: CFrame): Model
	local model = K.Model("GardenTools")
	local at, pt = frame(cframe)
	K.Block(model, Vector3.new(3.4, 0.2, 0.9), at(0, 0.1, -0.15), K.Dark(C.Wood), true)
	for _, x in { -1.55, 1.55 } do
		K.Block(model, Vector3.new(0.25, 2.5, 0.25), at(x, 1.25, 0.25), C.Wood, true)
	end
	K.Block(model, Vector3.new(3.4, 0.25, 0.2), at(0, 2.3, 0.25), C.WoodLight, true)
	K.Block(model, Vector3.new(3.4, 0.2, 0.2), at(0, 1.0, 0.25), C.WoodLight, true)
	for i, kind in { "Shovel", "Rake", "Pitchfork" } do
		YardProps.Tool(model, at((i - 2) * 0.9, 0.2, -0.32) * CFrame.Angles(math.rad(10), 0, 0), kind)
	end
	local bucket = pt(2.3, 0, -0.3)
	K.Disc(model, 0.95, 0.9, bucket, C.Metal, true)
	K.Disc(model, 1.05, 0.12, bucket + Vector3.new(0, 0.82, 0), K.Light(C.Metal), true)
	K.Disc(model, 0.85, 0.05, bucket + Vector3.new(0, 0.82, 0), rgb(110, 72, 44), true)
	K.Rod(model, (cframe * CFrame.new(1.85, 0.9, -0.3)).Position, (cframe * CFrame.new(2.3, 1.45, -0.3)).Position, 0.06, C.Ink, true)
	K.Rod(model, (cframe * CFrame.new(2.3, 1.45, -0.3)).Position, (cframe * CFrame.new(2.75, 0.9, -0.3)).Position, 0.06, C.Ink, true)
	K.Tube(model, bucket + Vector3.new(0.1, 0.8, 0), bucket + Vector3.new(0.25, 1.35, -0.1), 0.12, RED, true)
	model.Parent = parent
	return model
end

-- Ceramic flowerpot: foot, tapered two-step body with a painted band and an ink line, wide glazed rim, soil,
-- leafy plant and three blossoms. `size` scales it (1 = knee-high-ish pot, 1.15 tall).
function YardProps.FlowerPot(parent: Instance, cframe: CFrame, rng: Random, color: Color3?, size: number?): Model
	local model = K.Model("FlowerPot")
	local s = size or 1
	local pot = color or TERRACOTTA
	local base = cframe.Position
	local function up(y: number): Vector3
		return base + Vector3.new(0, y * s, 0)
	end
	K.Disc(model, 0.7 * s, 0.1 * s, up(0), K.Dark(pot), true)
	K.Disc(model, 0.8 * s, 0.42 * s, up(0.1), pot, true)
	K.Disc(model, 0.95 * s, 0.4 * s, up(0.5), pot, true)
	K.Disc(model, 0.99 * s, 0.14 * s, up(0.62), C.Trim, true)
	K.Disc(model, 0.84 * s, 0.05 * s, up(0.5), C.Ink, true)
	K.Disc(model, 1.15 * s, 0.24 * s, up(0.88), K.Light(pot), true)
	K.Disc(model, 1.0 * s, 0.05 * s, up(1.1), rgb(96, 62, 38), true)
	for i = 1, 2 do
		K.Gem(model, 0.6 * s, up(1.35) + Vector3.new((i - 1.5) * 0.35 * s, 0, rng:NextNumber(-0.15, 0.15) * s), C.Leaves[i], rng, true)
	end
	local color1 = C.Flowers[rng:NextInteger(1, #C.Flowers)]
	for i = 1, 3 do
		local angle = i * 2.1 + rng:NextNumber(0, 0.5)
		local spot = up(1.62 + (i % 2) * 0.12) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 0.32 * s
		blossom(model, CFrame.new(spot) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), angle, 0), 0.34 * s, color1)
	end
	model.Parent = parent
	return model
end

-- Metal watering can: round body with an ink band, top plate with a filler hole, arched handle, long spout
-- and a yellow sprinkler rose. The spout points toward LookVector.
function YardProps.WateringCan(parent: Instance, cframe: CFrame, color: Color3?): Model
	local model = K.Model("WateringCan")
	local _, pt = frame(cframe)
	local paint = color or rgb(70, 160, 220)
	K.Disc(model, 1.0, 0.9, pt(0, 0, 0), paint, true)
	K.Disc(model, 1.04, 0.07, pt(0, 0.14, 0), C.Ink, true)
	K.Disc(model, 0.75, 0.12, pt(0, 0.9, 0), K.Light(paint), true)
	K.Disc(model, 0.36, 0.08, pt(0, 0.98, 0.18), C.Ink, true)
	K.Rod(model, pt(0, 0.9, 0.4), pt(0, 1.42, 0.25), 0.1, K.Dark(paint), true)
	K.Rod(model, pt(0, 1.42, 0.25), pt(0, 1.42, -0.2), 0.1, K.Dark(paint), true)
	K.Rod(model, pt(0, 1.42, -0.2), pt(0, 0.98, -0.32), 0.1, K.Dark(paint), true)
	K.Tube(model, pt(0, 0.25, -0.42), pt(0, 1.15, -1.3), 0.14, paint, true)
	K.Tube(model, pt(0, 1.13, -1.28), pt(0, 1.25, -1.45), 0.34, YELLOW, true)
	model.Parent = parent
	return model
end

----------------------------------------------------------------------------------------------- yard figures

-- Garden gnome: boots, blue coat with an ink belt and a gold buckle, arms with hands, white beard, round
-- nose, ink eyes and a tall red hat with a bent tip.
function YardProps.Gnome(parent: Instance, cframe: CFrame): Model
	local model = K.Model("Gnome")
	local at, pt = frame(cframe)
	local skin, coat, hat = rgb(255, 200, 160), rgb(60, 110, 220), rgb(230, 40, 40)
	for _, x in { -0.25, 0.25 } do
		K.Block(model, Vector3.new(0.38, 0.22, 0.55), at(x, 0.11, -0.08), BLACK, true)
	end
	K.Block(model, Vector3.new(1.0, 1.0, 0.9), at(0, 0.7, 0), coat, true)
	K.Ink(model, Vector3.new(1.04, 0.14, 0.94), at(0, 0.82, 0))
	K.Block(model, Vector3.new(0.24, 0.2, 0.06), at(0, 0.82, -0.48), YELLOW, true)
	for _, s in { -1, 1 } do
		K.Rod(model, pt(s * 0.5, 1.1, 0), pt(s * 0.62, 0.68, -0.22), 0.26, coat, true)
		K.Ball(model, 0.26, pt(s * 0.62, 0.6, -0.28), skin, true)
	end
	K.Block(model, Vector3.new(0.85, 0.55, 0.85), at(0, 1.45, 0.05), skin, true)
	K.Prism(model, 0.3, 0.86, 0.78, at(0, 1.34, -0.42) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.pi, 0, 0), C.Trim, true)
	K.Ball(model, 0.26, pt(0, 1.42, -0.42), rgb(240, 140, 120), true)
	for _, x in { -0.2, 0.2 } do
		K.Ink(model, Vector3.new(0.1, 0.12, 0.04), at(x, 1.58, -0.39))
	end
	K.Block(model, Vector3.new(1.0, 0.18, 1.0), at(0, 1.74, 0.05), hat, true)
	K.Cone(model, 0.95, 1.3, at(0, 1.82, 0.05), hat, true)
	K.Block(model, Vector3.new(0.2, 0.4, 0.2), at(0, 3.12, 0.2) * CFrame.Angles(math.rad(55), 0, 0), hat, true)
	model.Parent = parent
	return model
end

-- Pink plastic lawn flamingo on wire legs (faces LookVector).
function YardProps.Flamingo(parent: Instance, cframe: CFrame): Model
	local model = K.Model("Flamingo")
	local at, pt = frame(cframe)
	local pink = rgb(255, 120, 170)
	for _, x in { -0.15, 0.15 } do
		K.Block(model, Vector3.new(0.12, 2.2, 0.12), at(x, 1.1, 0), C.Ink, true)
	end
	local body = at(0, 2.6, 0.1) * CFrame.Angles(math.rad(-12), 0, 0)
	K.Block(model, Vector3.new(0.9, 0.8, 1.6), body, pink, true)
	K.Block(model, Vector3.new(0.7, 0.7, 1.3), body * CFrame.Angles(0, 0, math.pi / 4), pink, true)
	K.Wedge(model, Vector3.new(0.5, 0.5, 0.7), body * CFrame.new(0, 0.3, 1.0) * CFrame.Angles(0, math.pi, 0), K.Dark(pink), true)
	K.Rod(model, pt(0, 2.9, -0.6), pt(0, 3.9, -0.4), 0.25, pink, true)
	K.Rod(model, pt(0, 3.9, -0.4), pt(0, 4.6, -0.75), 0.25, pink, true)
	K.Block(model, Vector3.new(0.4, 0.4, 0.6), at(0, 4.7, -0.95), pink, true)
	K.Block(model, Vector3.new(0.18, 0.18, 0.5), at(0, 4.55, -1.35) * CFrame.Angles(math.rad(-25), 0, 0), C.Ink, true)
	K.Block(model, Vector3.new(0.42, 0.1, 0.1), at(0, 4.8, -1.05), C.Ink, true)
	model.Parent = parent
	return model
end

------------------------------------------------------------------------------------------ outdoor furniture

-- Adirondack chair: sloped seat slats on stringers, front and back legs, wide flat armrests and a fanned
-- back of five slats on two cross supports. The sitter faces LookVector.
function YardProps.OutdoorChair(parent: Instance, cframe: CFrame, color: Color3?): Model
	local model = K.Model("OutdoorChair")
	local at, pt = frame(cframe)
	local paint = color or PAINTS[1]
	local dark = K.Dark(paint)
	for _, s in { -1, 1 } do
		K.Block(model, Vector3.new(0.18, 2.25, 0.36), at(s * 0.9, 1.12, -0.85), paint, true)
		board(model, pt(s * 0.85, 1.35, -1.1), pt(s * 0.85, 1.0, 0.8), 0.15, 0.32, dark, true)
		K.Block(model, Vector3.new(0.15, 1.05, 0.32), at(s * 0.85, 0.52, 0.62), dark, true)
		K.Block(model, Vector3.new(0.55, 0.12, 2.2), at(s * 1.02, 2.3, -0.15), paint, true)
		K.Wedge(model, Vector3.new(0.14, 0.4, 0.4), at(s * 0.98, 2.04, -0.6) * CFrame.Angles(0, math.pi, 0), dark, true)
	end
	for i = 0, 4 do
		local z = -0.92 + i * 0.36
		K.Block(model, Vector3.new(1.65, 0.1, 0.28), at(0, 1.55 - (z + 1.1) * 0.184, z) * CFrame.Angles(math.rad(11), 0, 0), paint, true)
	end
	for i = -2, 2 do
		local top = 3.75 - math.abs(i) * 0.22
		board(model, pt(i * 0.31, 1.1, 0.6), pt(i * 0.38, top, 1.45), 0.27, 0.08, paint, true)
	end
	for _, y in { 1.7, 2.85 } do
		local z = 0.6 + (y - 1.1) * 0.32 + 0.1
		K.Block(model, Vector3.new(1.75, 0.18, 0.1), at(0, y, z), dark, true)
	end
	model.Parent = parent
	return model
end

-- Wooden patio table: five planks over an ink slab (dark gaps between the planks), apron, four legs with
-- stretchers, and optionally a striped sun umbrella through the middle.
function YardProps.PatioTable(parent: Instance, cframe: CFrame, umbrella: boolean?): Model
	local model = K.Model("PatioTable")
	local at, pt = frame(cframe)
	K.Ink(model, Vector3.new(3.3, 0.08, 2.3), at(0, 2.32, 0))
	for i = -2, 2 do
		K.Block(model, Vector3.new(3.4, 0.14, 0.42), at(0, 2.42, i * 0.47), C.WoodLight, true)
	end
	for _, z in { -0.95, 0.95 } do
		K.Block(model, Vector3.new(3.0, 0.3, 0.12), at(0, 2.15, z), C.Wood, true)
	end
	for _, x in { -1.45, 1.45 } do
		K.Block(model, Vector3.new(0.12, 0.3, 1.8), at(x, 2.15, 0), C.Wood, true)
		for _, z in { -0.95, 0.95 } do
			K.Block(model, Vector3.new(0.25, 2.3, 0.25), at(x, 1.15, z), C.Wood)
		end
	end
	K.Block(model, Vector3.new(2.7, 0.15, 0.15), at(0, 0.45, 0), K.Dark(C.Wood), true)
	if umbrella then
		K.Tube(model, pt(0, 0.1, 0), pt(0, 5.6, 0), 0.16, C.Trim, true)
		K.Spire(model, 4.6, 1.2, at(0, 4.4, 0), RED, true)
		K.Spire(model, 4.6, 1.2, at(0, 4.42, 0) * CFrame.Angles(0, math.pi / 4, 0), C.Trim, true)
		K.Ball(model, 0.35, pt(0, 5.65, 0), RED, true)
	end
	model.Parent = parent
	return model
end

-- Kettle barbecue: round black kettle with a lid seam ring, lid handle with a wooden grip, side handles,
-- three splayed legs (two with wheels) and an ash pan. The kettle is solid.
function YardProps.KettleGrill(parent: Instance, cframe: CFrame): Model
	local model = K.Model("KettleGrill")
	local at, pt = frame(cframe)
	K.Ball(model, 2.0, pt(0, 2.4, 0), BLACK)
	K.Cylinder(model, Vector3.new(0.12, 2.08, 2.08), at(0, 2.5, 0) * CFrame.Angles(0, 0, math.pi / 2), C.Metal, true)
	K.Disc(model, 0.5, 0.08, pt(0, 3.36, 0), C.Metal, true)
	for _, x in { -0.3, 0.3 } do
		K.Rod(model, pt(x, 3.3, 0.3), pt(x, 3.55, 0.3), 0.08, C.Metal, true)
	end
	K.Tube(model, pt(-0.4, 3.6, 0.3), pt(0.4, 3.6, 0.3), 0.18, C.Wood, true)
	for _, s in { -1, 1 } do
		K.Tube(model, pt(s * 0.98, 2.35, 0), pt(s * 1.25, 2.35, 0), 0.14, BLACK, true)
	end
	for i, angle in { math.pi / 2, math.pi * 7 / 6, math.pi * 11 / 6 } do
		local dir = Vector3.new(math.cos(angle), 0, -math.sin(angle))
		local top = pt(0, 1.7, 0) + dir * 0.55
		local foot = pt(0, 0.25, 0) + dir * 1.05
		K.Rod(model, top, foot, 0.14, C.MetalDark, true)
		if i > 1 then
			K.Cylinder(model, Vector3.new(0.16, 0.5, 0.5), CFrame.lookAt(foot, foot + dir) * CFrame.Angles(0, math.pi / 2, 0), BLACK, true)
		end
	end
	K.Disc(model, 0.8, 0.08, pt(0, 0.85, 0), C.Metal, true)
	model.Parent = parent
	return model
end

-- Wheelie bin, "Trash" (gray with a black lid) or "Recycling" (blue with a yellow lid): body with a recessed
-- front panel and side ribs, label, rim collar, lid with a grip lip, hinge bar at the back, rear
-- handle bar, two wheels and a front foot. The lid opens at the front (LookVector). The body is solid.
function YardProps.WheelieBin(parent: Instance, cframe: CFrame, kind: string?): Model
	local recycling = kind == "Recycling"
	local model = K.Model(if recycling then "RecyclingBin" else "TrashBin")
	local at, pt = frame(cframe)
	local body = if recycling then rgb(54, 116, 210) else rgb(84, 96, 108)
	local lid = if recycling then YELLOW else rgb(44, 48, 56)
	K.Block(model, Vector3.new(1.55, 2.9, 1.6), at(0, 1.85, 0), body)
	K.Block(model, Vector3.new(1.1, 1.6, 0.06), at(0, 1.7, -0.82), K.Dark(body), true)
	for _, s in { -1, 1 } do
		K.Block(model, Vector3.new(0.06, 2.4, 0.14), at(s * 0.79, 1.8, 0.05), K.Light(body), true)
	end
	local label = K.Panel(model, 1.1, 0.42, at(0, 2.85, -0.8), C.Trim, 0.06, 0.05)
	K.Text(label, if recycling then "RECYCLE" else "TRASH", if recycling then body else C.Ink)
	K.Block(model, Vector3.new(1.72, 0.22, 1.76), at(0, 3.38, 0), K.Dark(body), true)
	K.Block(model, Vector3.new(1.8, 0.14, 1.92), at(0, 3.56, -0.04), lid, true)
	K.Block(model, Vector3.new(1.3, 0.26, 0.14), at(0, 3.5, -1.04), lid, true)
	K.Tube(model, pt(-0.82, 3.5, 0.94), pt(0.82, 3.5, 0.94), 0.22, K.Dark(lid), true)
	for _, x in { -0.6, 0.6 } do
		K.Rod(model, pt(x, 3.15, 0.78), pt(x, 3.15, 1.08), 0.1, K.Dark(body), true)
	end
	K.Tube(model, pt(-0.72, 3.15, 1.08), pt(0.72, 3.15, 1.08), 0.16, K.Dark(body), true)
	K.Tube(model, pt(-0.85, 0.42, 0.62), pt(0.85, 0.42, 0.62), 0.12, C.MetalDark, true)
	for _, s in { -1, 1 } do
		K.Cylinder(model, Vector3.new(0.26, 0.84, 0.84), at(s * 0.72, 0.42, 0.62), BLACK, true)
		K.Cylinder(model, Vector3.new(0.06, 0.4, 0.4), at(s * 0.87, 0.42, 0.62), C.Metal, true)
	end
	K.Block(model, Vector3.new(1.2, 0.4, 0.25), at(0, 0.2, -0.62), K.Dark(body), true)
	model.Parent = parent
	return model
end

------------------------------------------------------------------------------------------------ decorations

-- Yard welcome sign: two stakes, a board with rounded ends and an inked painted panel, painted flowers, and a
-- little "HOME SWEET HOME" tag hanging under it on two cords. Reads toward LookVector.
function YardProps.WelcomeSign(parent: Instance, cframe: CFrame, text: string?, color: Color3?): Model
	local model = K.Model("WelcomeSign")
	local at, pt = frame(cframe)
	local paint = color or rgb(120, 190, 240)
	for _, x in { -1.1, 1.1 } do
		K.Block(model, Vector3.new(0.2, 2.7, 0.2), at(x, 1.35, 0.15), K.Dark(C.Wood), true)
	end
	K.Block(model, Vector3.new(3.0, 1.1, 0.18), at(0, 2.2, 0), paint, true)
	for _, x in { -1.5, 1.5 } do
		K.Cylinder(model, Vector3.new(0.18, 1.1, 1.1), at(x, 2.2, 0) * CFrame.Angles(0, math.pi / 2, 0), paint, true)
	end
	local panel = K.Panel(model, 2.5, 0.72, at(0, 2.2, -0.09), CREAM, 0.07, 0.05)
	K.Text(panel, text or "WELCOME", K.Dark(paint))
	for _, x in { -1.5, 1.5 } do
		blossom(model, at(x, 2.2, -0.18) * CFrame.Angles(math.pi / 2, 0, 0), 0.5, rgb(255, 110, 150))
	end
	for _, x in { -0.7, 0.7 } do
		K.Rod(model, pt(x, 1.65, -0.05), pt(x, 1.3, -0.05), 0.05, C.Ink, true)
	end
	local tag = K.Panel(model, 1.8, 0.42, at(0, 1.1, -0.0), C.WoodLight, 0.05, 0.08)
	K.Text(tag, "HOME SWEET HOME", K.Dark(C.Wood))
	model.Parent = parent
	return model
end

-- Hanging flower basket under a hook point (`cframe`): optional iron wall bracket reaching out of the wall
-- behind it (+Z = toward the wall), three chains, a woven basket with an ink band, leaves spilling over the
-- rim and blossoms.
function YardProps.HangingBasket(parent: Instance, cframe: CFrame, rng: Random, bracket: boolean?): Model
	local model = K.Model("HangingBasket")
	local at, pt = frame(cframe)
	if bracket then
		K.Rod(model, pt(0, 0.05, 0), pt(0, 0.05, 1.0), 0.12, BLACK, true)
		K.Rod(model, pt(0, -0.7, 1.0), pt(0, 0.05, 0.3), 0.1, BLACK, true)
		K.Block(model, Vector3.new(0.3, 0.9, 0.08), at(0, -0.3, 1.0), BLACK, true)
	end
	K.Rod(model, pt(0, 0.05, 0), pt(0, -0.25, 0), 0.08, C.Ink, true)
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3 + 0.3
		K.Rod(model, pt(0, -0.25, 0), pt(math.cos(angle) * 0.55, -1.6, math.sin(angle) * 0.55), 0.05, C.Ink, true)
	end
	local woven = rgb(166, 118, 70)
	K.Disc(model, 0.65, 0.3, pt(0, -2.15, 0), K.Dark(woven), true)
	K.Disc(model, 1.15, 0.36, pt(0, -1.9, 0), woven, true)
	K.Disc(model, 1.2, 0.07, pt(0, -1.72, 0), C.Ink, true)
	K.Gem(model, 0.85, pt(0, -1.4, 0), C.Leaves[2], rng, true)
	for i = 0, 1 do
		local angle = i * math.pi + 1.1
		K.Gem(model, 0.45, pt(math.cos(angle) * 0.62, -2.05, math.sin(angle) * 0.62), C.Leaves[1], rng, true)
	end
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3 + rng:NextNumber(0, 0.6)
		local spot = at(math.cos(angle) * 0.42, -1.1 + (i % 2) * 0.1, math.sin(angle) * 0.42)
		blossom(model, spot * CFrame.Angles(0, angle, 0), 0.32, C.Flowers[(i % 3) + 1])
	end
	model.Parent = parent
	return model
end

-- Doghouse: base, painted walls with white corner boards and ink siding lines, a gable filled in the wall
-- color under a two-board roof with shingle lines and a ridge cap, an arched door with white trim, a name
-- board, a food bowl and a bone. The door faces LookVector; the walls are solid.
function YardProps.Doghouse(parent: Instance, cframe: CFrame, name: string?, color: Color3?): Model
	local model = K.Model("Doghouse")
	local at, pt = frame(cframe)
	local paint = color or RED
	local roof = C.Roofs[1]
	K.Block(model, Vector3.new(3.6, 0.3, 4.0), at(0, 0.15, 0), K.Dark(C.Wood), true)
	K.Block(model, Vector3.new(3.2, 2.4, 3.6), at(0, 1.5, 0), paint)
	for _, x in { -1.6, 1.6 } do
		for _, z in { -1.8, 1.8 } do
			K.Block(model, Vector3.new(0.24, 2.4, 0.24), at(x, 1.5, z), C.Trim, true)
		end
	end
	for _, y in { 1.1, 1.9 } do
		K.Ink(model, Vector3.new(3.24, 0.06, 3.3), at(0, y, 0))
	end
	K.Prism(model, 3.6, 3.2, 1.4, at(0, 2.7, 0) * CFrame.Angles(0, math.pi / 2, 0), paint, true)
	for _, s in { -1, 1 } do
		local eave, ridge = pt(s * 1.95, 2.38, 0), pt(0, 4.15, 0)
		local slope = CFrame.lookAt((eave + ridge) / 2, ridge)
		local length = (ridge - eave).Magnitude
		K.Block(model, Vector3.new(4.3, 0.2, length), slope * CFrame.new(0, 0.1, 0), roof, true)
		for _, z in { -length / 6, length / 6 } do
			K.Ink(model, Vector3.new(4.32, 0.05, 0.07), slope * CFrame.new(0, 0.21, z))
		end
	end
	K.Block(model, Vector3.new(0.34, 0.22, 4.45), at(0, 4.2, 0), K.Dark(roof), true)
	local door = at(0, 0, -1.8)
	K.Block(model, Vector3.new(1.7, 1.3, 0.06), door * CFrame.new(0, 0.95, -0.03), C.Trim, true)
	K.Cylinder(model, Vector3.new(0.06, 1.7, 1.7), door * CFrame.new(0, 1.6, -0.03) * CFrame.Angles(0, math.pi / 2, 0), C.Trim, true)
	K.Block(model, Vector3.new(1.3, 1.1, 0.06), door * CFrame.new(0, 0.85, -0.08), C.Ink, true)
	K.Cylinder(model, Vector3.new(0.06, 1.3, 1.3), door * CFrame.new(0, 1.4, -0.08) * CFrame.Angles(0, math.pi / 2, 0), C.Ink, true)
	local plate = K.Panel(model, 1.4, 0.42, door * CFrame.new(0, 3.05, 0), C.Trim, 0.06, 0.06)
	K.Text(plate, name or "FIDO", K.Dark(paint))
	K.Disc(model, 0.9, 0.3, pt(1.05, 0, -2.6), RED, true)
	K.Disc(model, 0.72, 0.06, pt(1.05, 0.28, -2.6), rgb(140, 90, 50), true)
	local bone = at(-1.1, 0.14, -2.7) * CFrame.Angles(0, 0.5, 0)
	K.Block(model, Vector3.new(0.9, 0.16, 0.16), bone, C.Trim, true)
	for _, x in { -0.45, 0.45 } do
		for _, z in { -0.1, 0.1 } do
			K.Ball(model, 0.22, (bone * CFrame.new(x, 0, z)).Position, C.Trim, true)
		end
	end
	model.Parent = parent
	return model
end

-- Birdhouse on a post: platform, painted box, overhanging roof, ink entrance hole, perch peg and a little
-- bluebird sitting on the ridge. The hole faces LookVector.
function YardProps.Birdhouse(parent: Instance, cframe: CFrame, color: Color3?): Model
	local model = K.Model("Birdhouse")
	local at, pt = frame(cframe)
	local paint = color or YELLOW
	K.Block(model, Vector3.new(0.3, 4.3, 0.3), at(0, 2.15, 0), C.Wood, true)
	K.Rod(model, pt(0, 3.6, 0), pt(0, 4.25, -0.45), 0.12, K.Dark(C.Wood), true)
	K.Block(model, Vector3.new(1.2, 0.12, 1.25), at(0, 4.3, -0.05), K.Dark(C.Wood), true)
	K.Block(model, Vector3.new(0.9, 1.05, 0.9), at(0, 4.88, 0), paint, true)
	K.Prism(model, 1.3, 1.35, 0.6, at(0, 5.4, 0) * CFrame.Angles(0, math.pi / 2, 0), C.Roofs[4], true)
	K.Cylinder(model, Vector3.new(0.06, 0.34, 0.34), at(0, 5.0, -0.46) * CFrame.Angles(0, math.pi / 2, 0), C.Ink, true)
	K.Tube(model, pt(0, 4.68, -0.44), pt(0, 4.68, -0.75), 0.07, C.Wood, true)
	local blue = rgb(70, 130, 230)
	K.Ball(model, 0.4, pt(0.15, 6.08, 0.05), blue, true)
	K.Ball(model, 0.28, pt(0.15, 6.3, -0.15), blue, true)
	K.Wedge(model, Vector3.new(0.08, 0.1, 0.18), at(0.15, 6.29, -0.36) * CFrame.Angles(0, math.pi, 0), YELLOW, true)
	K.Block(model, Vector3.new(0.14, 0.06, 0.3), at(0.15, 6.12, 0.3) * CFrame.Angles(math.rad(-20), 0, 0), K.Dark(blue), true)
	model.Parent = parent
	return model
end

-- Wooden crate: box with corner posts, a bottom band, a top rim of four boards, ink plank lines, a diagonal
-- brace on the front and back and a stencilled label. `size` = edge length. The box is solid.
function YardProps.Crate(parent: Instance, cframe: CFrame, label: string?, size: number?): Model
	local model = K.Model("Crate")
	local s = size or 2
	local h = s / 2
	local at = frame(cframe)
	local box = K.Block(model, Vector3.new(s - 0.1, s - 0.1, s - 0.1), at(0, h, 0), C.WoodLight)
	K.Text(box, label or "FRAGILE", K.Dark(C.Wood))
	local dark = C.Wood
	for _, x in { -h, h } do
		for _, z in { -h, h } do
			K.Block(model, Vector3.new(0.22, s, 0.22), at(x * 0.95, h, z * 0.95), dark, true)
		end
	end
	K.Block(model, Vector3.new(s + 0.02, 0.22, s + 0.02), at(0, 0.11, 0), dark, true)
	for _, z in { -h, h } do
		K.Block(model, Vector3.new(s, 0.22, 0.24), at(0, s - 0.11, z * 0.95), dark, true)
		K.Block(model, Vector3.new(0.24, 0.22, s), at(z * 0.95, s - 0.11, 0), dark, true)
		K.Block(model, Vector3.new(0.08, s * 1.25, 0.18), at(z, h, 0) * CFrame.Angles(math.pi / 4, 0, 0), dark, true)
	end
	K.Ink(model, Vector3.new(s - 0.06, 0.05, s - 0.06), at(0, h * 0.75, 0))
	K.Ink(model, Vector3.new(s - 0.06, 0.05, s - 0.06), at(0, h * 1.3, 0))
	model.Parent = parent
	return model
end

-- String of triangle flags from `from` to `to` (both world points), hanging below the string.
function YardProps.Bunting(parent: Instance, from: Vector3, to: Vector3, spacing: number)
	local length = (to - from).Magnitude
	local line = CFrame.lookAt(from, to)
	K.Ink(parent, Vector3.new(0.08, 0.08, length), line * CFrame.new(0, 0, -length / 2))
	local i = 0
	for along = spacing / 2, length - 0.3, spacing do
		i += 1
		K.Prism(parent, 0.06, 0.9, 0.9, line * CFrame.new(0, 0, -along) * CFrame.Angles(math.pi, 0, 0), C.Flowers[i % #C.Flowers + 1], true)
	end
end

-- Weather vane: pole, arrow with a tail fin, and a little gold rooster on top.
function YardProps.WeatherVane(parent: Instance, base: CFrame)
	local gold = rgb(255, 205, 70)
	K.Block(parent, Vector3.new(0.15, 2.6, 0.15), base * CFrame.new(0, 1.3, 0), C.Ink, true)
	K.Block(parent, Vector3.new(0.12, 0.12, 2.2), base * CFrame.new(0, 1.9, 0), C.Ink, true)
	K.Block(parent, Vector3.new(0.06, 0.6, 0.6), base * CFrame.new(0, 1.9, 1.05) * CFrame.Angles(math.pi / 4, 0, 0), C.Ink, true)
	K.Block(parent, Vector3.new(0.12, 0.4, 0.4), base * CFrame.new(0, 1.9, -1.15) * CFrame.Angles(math.pi / 4, 0, 0), C.Ink, true)
	K.Block(parent, Vector3.new(0.12, 0.6, 1.0), base * CFrame.new(0, 2.8, 0), gold, true)
	K.Block(parent, Vector3.new(0.12, 0.45, 0.4), base * CFrame.new(0, 3.25, -0.4), gold, true)
	K.Wedge(parent, Vector3.new(0.1, 0.7, 0.5), base * CFrame.new(0, 3.15, 0.55), gold, true)
end

YardProps.Paints = PAINTS

return YardProps
