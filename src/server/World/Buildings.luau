--!nonstrict
-- The neighborhood's community and commercial buildings in the comic style, built from Architecture
-- components: the Retirement Home, the Weapon Shop, the Grocery, the Coffee Shop, the Town Hall and the Gas
-- Station. Each has a layered roof, recessed windows, detailed doors, its own wall material, trim and a
-- foundation, plus its lot dressing (signs, gardens, benches, carts, tables, pumps).
-- Walls, roofs and details go into the HouseWalls / HouseRoofs / HouseDetails outline groups like the houses
-- (ink lines where roofs and details meet walls); lot props go into Yards, StreetProps and vegetation layers.
-- All of them stand outside the arena fence (MapBuilder places them along the perimeter street), so they
-- never block combat routes. The Weapon Shop is scenery: buying weapons still happens in the shop panel.
-- Build(groups, kind, cframe, rng): `cframe` = the lot's front edge at the street sidewalk (LookVector toward
-- the street), except for the GasStation, whose `cframe` is the lot center facing the street corner.

local ComicKit = require(script.Parent.ComicKit)
local Architecture = require(script.Parent.Architecture)
local Fences = require(script.Parent.Fences)
local GrandmaProps = require(script.Parent.GrandmaProps)
local StreetProps = require(script.Parent.StreetProps)
local Vegetation = require(script.Parent.Vegetation)
local Vehicles = require(script.Parent.Vehicles)
local YardProps = require(script.Parent.YardProps)

local A = Architecture
local K = ComicKit
local C = ComicKit.Colors

local Buildings = {}

Buildings.Kinds = { "RetirementHome", "WeaponShop", "Grocery", "CoffeeShop", "TownHall", "GasStation" }

type Context = {
	L: Architecture.Layers,
	Yard: Instance,
	Street: Instance,
	Garden: Vegetation.Layers,
	Vehicles: Vehicles.Layers,
}

local TURN = CFrame.Angles(0, math.pi / 2, 0) -- roof ridge front to back
local FACE_OUT = CFrame.Angles(0, math.pi / 2, 0) -- turns a cylinder's axis to point out of a wall
local Face = Architecture.Face

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local GOLD = rgb(255, 205, 70)
local NAVY = rgb(40, 60, 120)

-- Placement helpers inside one building: `at(x, y, z)` = CFrame, `pt(x, y, z)` = world point.
local function frame(cframe: CFrame): ((number, number, number) -> CFrame, (number, number, number) -> Vector3)
	return function(x, y, z)
		return cframe * CFrame.new(x, y, z)
	end, function(x, y, z)
		return (cframe * CFrame.new(x, y, z)).Position
	end
end

local function sideFace(side: number): CFrame
	return if side == 1 then Face.Right else Face.Left
end

-- Bold sign lettering with an ink stroke on a part's front face.
local function lettering(part: BasePart, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.TextStrokeColor3 = C.Ink
	label.TextStrokeTransparency = 0
	label.Parent = gui
end

-- Framed sign board on a wall (`wall` = wall CFrame at its center).
local function sign(P: Instance, wall: CFrame, w: number, h: number, text: string, bg: Color3, fg: Color3): BasePart
	local board = K.Panel(P, w, h, wall, bg, 0.25, 0.2)
	lettering(board, text, fg)
	return board
end

-- Clock face on a wall (`wall` = wall CFrame at its center): ink ring, white face, twelve ticks, two hands.
local function clock(P: Instance, wall: CFrame, d: number)
	K.Cylinder(P, Vector3.new(0.2, d + 0.6, d + 0.6), wall * CFrame.new(0, 0, -0.1) * FACE_OUT, C.Ink, true)
	K.Cylinder(P, Vector3.new(0.3, d, d), wall * CFrame.new(0, 0, -0.25) * FACE_OUT, C.Trim, true)
	for i = 0, 11 do
		local a = i * math.pi / 6
		local len = if i % 3 == 0 then d * 0.16 else d * 0.08
		K.Ink(P, Vector3.new(d * 0.05, len, 0.1), wall * CFrame.new(math.sin(a) * d * 0.38, math.cos(a) * d * 0.38, -0.42) * CFrame.Angles(0, 0, -a))
	end
	for _, hand in { { -1.0, 0.24 }, { 0.7, 0.36 } } do
		local a, len = hand[1], d * hand[2]
		K.Ink(P, Vector3.new(d * 0.06, len, 0.1), wall * CFrame.new(math.sin(a) * len / 2, math.cos(a) * len / 2, -0.47) * CFrame.Angles(0, 0, -a))
	end
end

-- Half-round fanlight over a doorway (`wall` = wall CFrame at the center of its flat bottom edge); the lower
-- half hides behind the door head.
local function fanlight(P: Instance, wall: CFrame, d: number)
	K.Cylinder(P, Vector3.new(0.12, d + 0.5, d + 0.5), wall * CFrame.new(0, 0, -0.06) * FACE_OUT, C.Ink, true)
	K.Cylinder(P, Vector3.new(0.14, d, d), wall * CFrame.new(0, 0, -0.1) * FACE_OUT, C.Glass, true)
	for _, a in { -0.9, 0, 0.9 } do
		K.Block(P, Vector3.new(0.12, d * 0.45, 0.06), wall * CFrame.new(math.sin(a) * d * 0.22, math.cos(a) * d * 0.22, -0.18) * CFrame.Angles(0, 0, -a), C.Trim, true)
	end
end

-- Arched opening (belfry, tower): an ink slot with a round top and louvers (`wall` = wall CFrame at its center).
local function louver(P: Instance, wall: CFrame, w: number, h: number, slat: Color3)
	K.Block(P, Vector3.new(w, h - w / 2, 0.12), wall * CFrame.new(0, -w / 4, -0.04), C.Ink, true)
	K.Cylinder(P, Vector3.new(0.12, w, w), wall * CFrame.new(0, h / 2 - w / 2, -0.04) * FACE_OUT, C.Ink, true)
	for y = -h / 2 + 0.5, h / 2 - w / 2 - 0.2, 0.6 do
		K.Block(P, Vector3.new(w - 0.2, 0.14, 0.1), wall * CFrame.new(0, y, -0.12) * CFrame.Angles(math.rad(-25), 0, 0), slat, true)
	end
end

-- Sandwich-board sign standing on the ground (two leaning boards with lettering on the front one).
local function sandwichBoard(P: Instance, cframe: CFrame, text: string, color: Color3)
	for _, s in { -1, 1 } do
		local board = K.Block(P, Vector3.new(1.6, 2.4, 0.1), cframe * CFrame.new(0, 1.15, s * 0.28) * CFrame.Angles(s * math.rad(12), 0, 0), color, true)
		if s == -1 then
			K.Text(board, text, C.Trim)
		end
	end
	K.Block(P, Vector3.new(1.7, 0.16, 0.2), cframe * CFrame.new(0, 2.38, 0), C.Wood, true)
end

----------------------------------------------------------------------------------------------- buildings

local BUILDERS: { [string]: (B: Context, cframe: CFrame, rng: Random) -> () } = {}

-- 1. Retirement Home: a long two-story main block (red brick ground floor, cream upper floor) with a gable roof,
-- four dormers and a clock tower (belfry and steeple), two end wings stepping forward under their own front
-- gables, a full-width veranda with a gabled entrance, double doors under a fanlight, the RETIREMENT HOME sign,
-- rocking chairs and knitting on the veranda, and the grounds: walk, lamps, benches, flower beds, hedges, the
-- SUNNY ACRES monument sign, the BINGO sign, a bike rack and an iron fence along the sidewalk.
function BUILDERS.RetirementHome(B: Context, curb: CFrame, rng: Random)
	local L = B.L
	local box = curb * CFrame.new(0, 0, 33)
	local at, pt = frame(box)
	local cream, brick, roof, trim = rgb(244, 226, 190), C.Brick, C.Roofs[4], C.Trim
	local shutter = rgb(46, 120, 80)
	local W, D, H = 48, 30, 22
	local front = -D / 2

	-- a cream box with a red brick skin on the ground floor (mortar courses on the front and sides), a belt
	-- course and a cornice band
	local function storeys(b: CFrame, w: number, h: number, d: number)
		A.Walls(L, b, w, h, d, cream, nil, trim, rng)
		K.Block(L.Walls, Vector3.new(w + 0.12, 10, d + 0.12), b * CFrame.new(0, 6.2, 0), brick)
		local mortar = brick:Lerp(Color3.new(1, 1, 1), 0.45)
		for _, face in { { b * CFrame.new(0, 0, -d / 2), w }, { b * CFrame.new(-w / 2, 0, 0) * Face.Left, d }, { b * CFrame.new(w / 2, 0, 0) * Face.Right, d } } do
			for y = 2.8, 10.4, 1.8 do
				K.Block(L.Walls, Vector3.new(face[2] - 0.8, 0.1, 0.06), face[1] * CFrame.new(0, y, -0.09), mortar, true)
			end
		end
		K.Block(L.Walls, Vector3.new(w + 0.7, 0.7, d + 0.7), b * CFrame.new(0, 11.2, 0), trim, true)
		K.Block(L.Walls, Vector3.new(w + 1.0, 0.8, d + 1.0), b * CFrame.new(0, h - 0.4, 0), trim, true)
	end

	storeys(box, W, H, D)
	local roofInfo = A.GableRoof(L, box, W, D, H, 9, roof, cream, { Vents = false, Back = false })
	for _, x in { -16, -9, 9, 16 } do
		A.Dormer(L, box, roofInfo, x, 2.4, 2.4, cream, roof, trim)
	end
	for _, y in { 5.6, 16.2 } do
		for _, x in { 9, 15, 21 } do
			for _, s in { -1, 1 } do
				A.Window(L, at(s * x, y, front), 3.0, 4.2, { Crown = true, Grid = y > 10 })
			end
		end
	end
	local name = K.Panel(L.Details, 11, 3.0, at(0, 16.4, front), NAVY, 0.35, 0.3)
	lettering(name, "RETIREMENT HOME", rgb(255, 225, 120))

	-- end wings stepping forward under front gables
	for _, s in { -1, 1 } do
		local wing = at(s * 32, 0, -2)
		storeys(wing, 16, 20, 34)
		A.GableRoof(L, wing * TURN, 34, 16, 20, 7, roof, cream, { Vents = false, Downspouts = true })
		A.RoundWindow(L, wing * CFrame.new(0, 22.6, -17), 2.4, trim)
		for _, y in { 5.6, 15.6 } do
			for _, x in { -4, 4 } do
				A.Window(L, wing * CFrame.new(x, y, -17), 3.0, 4.2, { Crown = true, Shutters = shutter, ShutterWidth = 1.0, Box = if y < 10 then roof else nil })
			end
			for _, z in { -6, 6 } do
				A.Window(L, wing * CFrame.new(s * 8, y, z) * sideFace(s), 3.0, 4.2, { Crown = true })
			end
		end
	end

	-- clock tower on the ridge: square base with brick quoins and a clock, octagonal belfry, steeple, vane
	K.Block(L.Walls, Vector3.new(10, 12, 10), at(0, 30, 0), cream)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			K.Block(L.Walls, Vector3.new(1.0, 12, 1.0), at(sx * 4.8, 30, sz * 4.8), brick, true)
		end
	end
	K.Block(L.Roofs, Vector3.new(11.2, 0.8, 11.2), at(0, 36.4, 0), trim, true)
	clock(L.Details, at(0, 31.2, -5), 6.0)
	K.Octagon(L.Walls, 8, 5, at(0, 39.3, 0), trim)
	for k = 0, 3 do
		louver(L.Details, at(0, 39.1, 0) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -4), 2.0, 3.6, K.Dark(cream))
	end
	K.Octagon(L.Roofs, 9.2, 0.6, at(0, 42.1, 0), trim, true)
	K.Cone(L.Roofs, 9, 7.5, at(0, 42.4, 0), C.Roofs[1], false, 12)
	K.Ball(L.Roofs, 2.6, pt(0, 49.9, 0), GOLD, true)
	YardProps.WeatherVane(L.Details, at(0, 50.8, 0))

	-- veranda with a gabled entrance, double doors under a fanlight
	A.Porch(L, at(0, 0, front), {
		Width = 46,
		Depth = 8,
		Floor = 1.8,
		Columns = { -22.4, -18, -12, -3.2, 3.2, 12, 18, 22.4 },
		ColumnHeight = 8.5,
		Style = "Square",
		Rail = true,
		StepX = 0,
		StepWidth = 6.4,
		Roof = "Shed",
		RoofColor = roof,
	})
	A.GableRoof(L, at(0, 0, front - 4.6) * TURN, 9.2, 9, 10.3, 3.0, roof, cream, { Over = 0.8, Vents = false, Gutters = false })
	local plaque = K.Panel(L.Details, 4.2, 0.9, at(0, 11.25, front - 9.2), trim, 0.12, 0.08)
	K.Text(plaque, "EST. 1952", brick)
	for _, x in { -1.8, 1.8 } do
		A.Door(L, at(x, 1.8, front), 3.4, 7.2, C.Doors[4], { Glass = true })
	end
	fanlight(L.Details, at(0, 10.0, front), 3.8)
	for _, x in { -11, 11 } do
		GrandmaProps.RockingChair(B.Yard, at(x, 1.8, front - 3.6) * CFrame.Angles(0, if x < 0 then 0.3 else -0.3, 0), if x < 0 then C.Doors[2] else C.Doors[3])
	end
	GrandmaProps.KnittingBasket(B.Yard, at(-8.4, 1.8, front - 2.6))
	GrandmaProps.Slippers(B.Yard, at(4.4, 1.8, front - 1.3) * CFrame.Angles(0, 0.3, 0))
	for _, s in { -1, 1 } do
		Vehicles.Build(B.Vehicles, "Scooter", at(s * 17.5, 1.8, front - 4.5) * CFrame.Angles(0, s * 0.4, 0))
	end

	-- grounds: walk to the sidewalk, lamps, shrubs at the steps, beds and hedges before the wings, benches,
	-- a round flower bed, the monument sign, the BINGO sign, a bike rack and the iron fence
	K.Block(B.Yard, Vector3.new(5.6, 0.2, 7.4), at(0, 0.1, -29.3), C.Path, true)
	for _, s in { -1, 1 } do
		K.Block(B.Yard, Vector3.new(0.35, 0.3, 7.4), at(s * 2.95, 0.15, -29.3), C.Stone, true)
		StreetProps.Lamp(B.Street, pt(s * 4.4, 0, -31))
		Vegetation.Bush(B.Garden, "Pointed", pt(s * 4.6, 0, -25.2), rng)
		Vegetation.Bed(B.Garden, pt(s * 25.5, 0, -21.3), pt(s * 38.5, 0, -21.3), { "Rose", "Tulip" }, rng)
		Vegetation.TrimmedHedge(B.Garden, at(s * 32, 0, -23.3), 13, rng)
		Fences.Iron(B.Yard, pt(s * 6.2, 0, -32.6), pt(s * 40, 0, -32.6), 2.2)
	end
	for _, x in { -10, -17 } do
		StreetProps.Bench(B.Street, at(x, 0, -27.8))
	end
	Vegetation.FlowerBed(B.Garden, pt(20.5, 0, -27.4), rng)
	local mon = at(11.5, 0, -30.2)
	K.Block(B.Yard, Vector3.new(9.6, 1.4, 1.6), mon * CFrame.new(0, 0.7, 0), brick)
	K.Block(B.Yard, Vector3.new(10.2, 0.3, 2.0), mon * CFrame.new(0, 1.55, 0), trim, true)
	K.Block(B.Yard, Vector3.new(8.8, 2.6, 0.6), mon * CFrame.new(0, 3.0, 0), cream, true)
	local board = K.Panel(B.Yard, 8.0, 2.0, mon * CFrame.new(0, 3.0, -0.3), NAVY, 0.15, 0.1)
	lettering(board, "SUNNY ACRES", GOLD)
	K.Block(B.Yard, Vector3.new(9.4, 0.4, 0.9), mon * CFrame.new(0, 4.5, 0), trim, true)
	for _, s in { -1, 1 } do
		K.Block(B.Yard, Vector3.new(1.2, 4.2, 1.2), mon * CFrame.new(s * 4.9, 2.1, 0), brick, true)
		K.Block(B.Yard, Vector3.new(1.5, 0.4, 1.5), mon * CFrame.new(s * 4.9, 4.4, 0), trim, true)
		K.Ball(B.Yard, 0.8, (mon * CFrame.new(s * 4.9, 4.95, 0)).Position, trim, true)
	end
	GrandmaProps.BingoSign(B.Yard, at(31, 0, -27.6))
	local rack = at(-29, 0, -27.4)
	StreetProps.BikeRack(B.Street, rack, 2)
	StreetProps.Bicycle(B.Street, rack, rgb(150, 110, 230))
end

-- A comic revolver, barrel along local X from `cf` (the frame center), with a POW! muzzle flash.
local function giantRevolver(P: Instance, cf: CFrame)
	local steel, dark, wood = rgb(110, 120, 140), rgb(52, 56, 70), rgb(150, 86, 44)
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local function pt(x: number, y: number, z: number): Vector3
		return (cf * CFrame.new(x, y, z)).Position
	end
	K.Tube(P, pt(0.8, 0.55, 0), pt(4.8, 0.55, 0), 0.8, steel, true)
	K.Tube(P, pt(0.9, 0.0, 0), pt(3.4, 0.0, 0), 0.36, dark, true)
	K.Block(P, Vector3.new(0.3, 0.45, 0.2), at(4.5, 1.05, 0), dark, true)
	K.Block(P, Vector3.new(2.6, 1.7, 0.75), at(-0.2, 0.25, 0), steel)
	K.Cylinder(P, Vector3.new(1.4, 1.8, 1.8), at(0.4, 0.25, 0), K.Light(steel), true)
	for _, y in { 0.55, -0.05 } do
		K.Ink(P, Vector3.new(1.3, 0.12, 0.1), at(0.4, y, -0.88))
	end
	K.Block(P, Vector3.new(0.5, 0.9, 0.35), at(-1.55, 1.2, 0) * CFrame.Angles(0, 0, 0.5), dark, true)
	K.Block(P, Vector3.new(1.1, 2.6, 0.7), at(-1.75, -1.55, 0) * CFrame.Angles(0, 0, -0.35), wood, true)
	for _, y in { -1.0, -1.7 } do
		K.Ink(P, Vector3.new(0.8, 0.1, 0.74), at(-1.75 + y * 0.35, y, 0) * CFrame.Angles(0, 0, -0.35))
	end
	K.Rod(P, pt(0.3, -0.6, 0), pt(0.1, -1.45, 0), 0.18, dark, true)
	K.Rod(P, pt(0.1, -1.45, 0), pt(-0.9, -1.3, 0), 0.18, dark, true)
	K.Block(P, Vector3.new(0.2, 0.6, 0.2), at(-0.25, -0.95, 0) * CFrame.Angles(0, 0, 0.3), dark, true)
	K.Block(P, Vector3.new(2.6, 2.6, 0.2), at(6.3, 0.55, 0) * CFrame.Angles(0, 0, math.pi / 4), rgb(255, 130, 30), true)
	local flash = K.Block(P, Vector3.new(2.0, 2.0, 0.3), at(6.3, 0.55, 0), rgb(255, 225, 60), true)
	K.Text(flash, "POW!", rgb(220, 40, 40))
end

-- Silhouettes behind a shop window (`g` = CFrame on the glass at the sill from Storefront).
local function rifle(P: Instance, g: CFrame, len: number, color: Color3)
	K.Block(P, Vector3.new(len * 0.3, 0.45, 0.06), g * CFrame.new(-len * 0.36, -0.08, 0) * CFrame.Angles(0, 0, 0.12), color, true)
	K.Block(P, Vector3.new(len * 0.3, 0.36, 0.06), g * CFrame.new(-len * 0.06, 0.02, 0), color, true)
	K.Block(P, Vector3.new(len * 0.42, 0.12, 0.06), g * CFrame.new(len * 0.29, 0.1, 0), color, true)
	K.Block(P, Vector3.new(len * 0.24, 0.16, 0.06), g * CFrame.new(-len * 0.02, 0.32, 0), color, true)
	K.Block(P, Vector3.new(0.18, 0.42, 0.06), g * CFrame.new(len * 0.05, -0.3, 0) * CFrame.Angles(0, 0, -0.2), color, true)
end

local function pistol(P: Instance, g: CFrame, s: number, color: Color3)
	K.Block(P, Vector3.new(1.0 * s, 0.3 * s, 0.06), g * CFrame.new(0.15 * s, 0.2 * s, 0), color, true)
	K.Block(P, Vector3.new(0.3 * s, 0.65 * s, 0.06), g * CFrame.new(-0.22 * s, -0.12 * s, 0) * CFrame.Angles(0, 0, -0.25), color, true)
	K.Block(P, Vector3.new(0.3 * s, 0.08 * s, 0.06), g * CFrame.new(0.05 * s, -0.08 * s, 0), color, true)
end

-- 2. Weapon Shop: a corrugated barrel-vault roof (faceted arc with ink seams) behind a stepped red brick false
-- front with pilasters, a giant comic revolver firing POW! on top, the WEAPON SHOP sign and a GUNS AMMO
-- GRENADES board, a hazard-striped awning over a glass door with a neon OPEN sign, two shop windows with
-- rifles, pistols, a target and grenades on display, barred side windows, ammo crates and a sandwich board.
function BUILDERS.WeaponShop(B: Context, curb: CFrame, rng: Random)
	local L = B.L
	local W, D, H = 18, 20, 7
	local box = curb * CFrame.new(0, 0, 9 + D / 2)
	local at = frame(box)
	local metal, dark, red = rgb(160, 170, 184), rgb(66, 74, 90), rgb(196, 56, 46)
	A.Walls(L, box, W, H, D, dark, "Siding", C.Trim, rng)

	-- barrel roof: an elliptic arc of facets in two tones, ink seams, stepped back end
	local Rx, Ry, n = W / 2 + 0.6, 6, 10
	local function arc(i: number): Vector3
		local a = math.pi * i / n
		return Vector3.new(Rx * math.cos(a), H + Ry * math.sin(a), 0)
	end
	for i = 0, n - 1 do
		local a, b = arc(i), arc(i + 1)
		local along = (b - a).Unit
		local out = Vector3.new(along.Y, -along.X, 0)
		K.Block(L.Roofs, Vector3.new((b - a).Magnitude + 0.15, 0.5, D + 1.4), box * CFrame.fromMatrix((a + b) / 2 + out * 0.25, along, out), if i % 2 == 0 then metal else K.Light(metal))
		if i > 0 then
			K.Ink(L.Roofs, Vector3.new(0.14, 0.14, D + 1.45), box * CFrame.new(a + out * 0.52))
		end
	end
	for k = 0, 4 do
		local f = (k + 0.75) / 5
		K.Block(L.Walls, Vector3.new(2 * Rx * math.sqrt(1 - f * f), Ry / 5, 0.6), at(0, H + Ry * (k + 0.5) / 5, D / 2 - 0.3), dark)
	end

	-- stepped false front with copings, a stone plinth, pilasters and brick courses
	local ff = at(0, 0, -D / 2 - 0.5)
	K.Block(L.Walls, Vector3.new(W + 3, 15, 1.0), ff * CFrame.new(0, 7.5, 0), red)
	K.Block(L.Walls, Vector3.new(W - 3, 1.6, 1.0), ff * CFrame.new(0, 15.8, 0), red)
	K.Block(L.Walls, Vector3.new(W - 9, 1.6, 1.0), ff * CFrame.new(0, 17.4, 0), red)
	for _, step in { { W + 3.6, 15.2 }, { W - 2.4, 16.8 }, { W - 8.4, 18.4 } } do
		K.Block(L.Roofs, Vector3.new(step[1], 0.45, 1.6), ff * CFrame.new(0, step[2], 0), C.Trim, true)
	end
	K.Block(L.Walls, Vector3.new(W + 3.6, 0.8, 1.6), ff * CFrame.new(0, 0.4, -0.05), C.Stone)
	K.Ink(L.Walls, Vector3.new(W + 3.65, 0.1, 1.65), ff * CFrame.new(0, 0.82, -0.05))
	local mortar = red:Lerp(Color3.new(1, 1, 1), 0.4)
	for y = 2.2, 14.3, 1.3 do
		K.Block(L.Walls, Vector3.new(W + 2.6, 0.1, 0.06), ff * CFrame.new(0, y, -0.52), mortar, true)
	end
	for _, s in { -1, 1 } do
		K.Block(L.Details, Vector3.new(1.0, 14.2, 0.4), ff * CFrame.new(s * (W / 2 + 1.0), 7.9, -0.6), K.Dark(red), true)
		K.Block(L.Details, Vector3.new(0.25, 3.0, 0.25), ff * CFrame.new(s * 1.4, 20.1, 0), C.MetalDark, true)
	end
	giantRevolver(L.Details, ff * CFrame.new(-1.6, 22.0, 0))

	local face = ff * CFrame.new(0, 0, -0.5)
	sign(L.Details, face * CFrame.new(0, 11.7, 0), 15, 2.6, "WEAPON SHOP", GOLD, red)
	sign(L.Details, face * CFrame.new(0, 16.0, 0), 12, 0.95, "GUNS - AMMO - GRENADES", C.Ink, GOLD)
	K.Block(L.Details, Vector3.new(4.6, 0.4, 1.2), face * CFrame.new(0, 0.2, -0.6), C.Stone, true)
	A.Door(L, face * CFrame.new(0, 0.8, 0), 3.2, 6.6, rgb(40, 50, 70), { Glass = true })
	local open = K.Block(L.Details, Vector3.new(1.0, 0.42, 0.05), face * CFrame.new(0.67, 5.5, -0.36), rgb(255, 70, 90), true)
	open.Material = Enum.Material.Neon
	K.Text(open, "OPEN", C.Trim)
	A.Awning(L, face * CFrame.new(0, 9.2, 0), 5.0, 1.8, rgb(40, 40, 48), GOLD)

	-- display windows: pegboard backing, guns, a target, grenades and a SALE tag
	local gunColor = rgb(50, 54, 66)
	for _, s in { -1, 1 } do
		local g = A.Storefront(L, face * CFrame.new(s * 5.6, 0.8, 0), 5.0, 6.6, { Kick = K.Dark(red), Panes = 2 })
		K.Block(L.Details, Vector3.new(4.4, 4.2, 0.03), g * CFrame.new(0, 2.3, -0.02), rgb(232, 212, 170), true)
		if s == -1 then
			rifle(L.Details, g * CFrame.new(0, 3.6, -0.06), 4.0, gunColor)
			pistol(L.Details, g * CFrame.new(-1.1, 1.3, -0.06), 1.2, gunColor)
			for i, color in { C.Trim, rgb(220, 40, 40), C.Trim } do
				K.Cylinder(L.Details, Vector3.new(0.05 + i * 0.02, 1.6 - i * 0.45, 1.6 - i * 0.45), g * CFrame.new(1.1, 1.5, -0.04 - i * 0.02) * FACE_OUT, color, true)
			end
		else
			rifle(L.Details, g * CFrame.new(0, 3.7, -0.06), 4.0, gunColor)
			rifle(L.Details, g * CFrame.new(0, 2.6, -0.06), 3.4, rgb(110, 70, 40))
			for i = -1, 1 do
				K.Ball(L.Details, 0.55, (g * CFrame.new(i * 0.7 - 0.4, 0.6, -0.2)).Position, rgb(70, 130, 60), true)
				K.Block(L.Details, Vector3.new(0.18, 0.2, 0.18), g * CFrame.new(i * 0.7 - 0.4, 0.95, -0.2), GOLD, true)
			end
			local tag = K.Block(L.Details, Vector3.new(1.0, 0.5, 0.05), g * CFrame.new(1.4, 1.3, -0.08) * CFrame.Angles(0, 0, 0.2), rgb(220, 40, 40), true)
			K.Text(tag, "SALE", C.Trim)
		end
	end
	for _, s in { -1, 1 } do
		local side = at(s * W / 2, 4.2, 1) * sideFace(s)
		A.Window(L, side, 2.4, 2.2)
		for x = -0.8, 0.81, 0.8 do
			K.Ink(L.Details, Vector3.new(0.12, 2.5, 0.12), side * CFrame.new(x, 0, -0.62))
		end
	end

	-- lot: paved forecourt, ammo crates, a sandwich board and a trash can
	K.Block(B.Yard, Vector3.new(W + 4, 0.12, 8), box * CFrame.new(0, 0.06, -D / 2 - 5), C.Sidewalk, true)
	YardProps.Crate(B.Yard, face * CFrame.new(-8.4, 0, -1.4) * CFrame.Angles(0, 0.2, 0), "AMMO", 1.6)
	YardProps.Crate(B.Yard, face * CFrame.new(-8.4, 1.6, -1.4) * CFrame.Angles(0, -0.15, 0), "AMMO", 1.3)
	sandwichBoard(B.Yard, face * CFrame.new(7.8, 0, -3.2) * CFrame.Angles(0, -0.3, 0), "GRENADES $60", rgb(40, 40, 48))
	StreetProps.TrashCan(B.Street, (face * CFrame.new(9.6, 0, -1.4)).Position)
end

-- A tilted produce crate full of fruit on a display stand (`cf` = crate bottom center, leaning to the front).
local function produceCrate(P: Instance, cf: CFrame, fruit: Color3, rng: Random)
	K.Block(P, Vector3.new(2.2, 0.55, 1.3), cf * CFrame.new(0, 0.27, 0), C.WoodLight, true)
	K.Ink(P, Vector3.new(2.24, 0.06, 1.34), cf * CFrame.new(0, 0.3, 0))
	K.Block(P, Vector3.new(2.0, 0.2, 1.1), cf * CFrame.new(0, 0.58, 0), K.Dark(fruit), true)
	for i = -1, 1 do
		K.Ball(P, 0.55, (cf * CFrame.new(i * 0.62 + rng:NextNumber(-0.08, 0.08), 0.78, rng:NextNumber(-0.2, 0.2))).Position, fruit, true)
	end
end

-- 3. Grocery: one tall story of painted teal brick under a flat roof with a parapet, dentil cornice and AC
-- units, a front gable parapet with rake trims carrying a giant red apple, the GRANNY'S GROCERY sign, a framed
-- entrance (pilasters and header) with sliding glass doors up a ramp, two shop windows with shelves of goods
-- under green striped awnings, produce stands of fruit crates, a cart corral with carts and a sandwich board.
function BUILDERS.Grocery(B: Context, curb: CFrame, rng: Random)
	local L = B.L
	local W, D, H = 28, 22, 12
	local box = curb * CFrame.new(0, 0, 8 + D / 2)
	local at, pt = frame(box)
	local wall, trim, green = rgb(90, 184, 160), C.Trim, rgb(40, 150, 80)
	local front = -D / 2
	A.Walls(L, box, W, H, D, wall, "Brick", trim, rng)
	local top = A.FlatRoof(L, box, W, D, H, wall, { Parapet = 1.8, Dentils = true, Units = 2 })
	K.Prism(L.Walls, 0.8, 13, 4.2, at(0, top - 0.2, front + 0.4) * TURN, wall)
	for _, s in { -1, 1 } do
		K.Rod(L.Roofs, pt(s * 6.9, top - 0.1, front + 0.3), pt(0, top + 4.25, front + 0.3), 0.6, trim, true)
	end
	local apple = pt(0, top + 1.6, front - 0.5)
	K.Ball(L.Details, 2.2, apple, rgb(220, 40, 40), true)
	K.Rod(L.Details, apple + Vector3.new(0, 1.0, 0), apple + Vector3.new(0, 1.6, 0), 0.18, C.Trunk, true)
	K.Wedge(L.Details, Vector3.new(0.12, 0.45, 0.8), CFrame.new(apple + Vector3.new(0.35, 1.45, 0)) * (box - box.Position) * TURN, C.Leaves[2], true)
	sign(L.Details, at(0, 10.4, front), 16, 1.9, "GRANNY'S GROCERY", rgb(250, 240, 214), K.Dark(green))

	-- framed entrance with sliding glass doors up a ramp
	for _, s in { -1, 1 } do
		K.Block(L.Details, Vector3.new(1.2, 9.0, 1.2), at(s * 3.6, 4.5, front - 0.4), trim, true)
	end
	K.Block(L.Details, Vector3.new(8.6, 1.2, 1.6), at(0, 8.8, front - 0.6), trim, true)
	K.Ink(L.Details, Vector3.new(8.65, 0.12, 1.65), at(0, 8.22, front - 0.6))
	A.Storefront(L, at(0, 1.2, front), 5.6, 7.0, { Frame = rgb(50, 60, 70), KickHeight = 0.4, Panes = 2 })
	local open = K.Block(L.Details, Vector3.new(1.2, 0.5, 0.05), at(1.4, 6.2, front - 0.25), rgb(255, 70, 90), true)
	open.Material = Enum.Material.Neon
	K.Text(open, "OPEN", C.Trim)
	K.Wedge(L.Details, Vector3.new(6, 1.2, 3.0), at(0, 0.6, front - 1.5), C.Sidewalk)

	-- shop windows with shelves of goods, awnings, produce stands
	local goods = { rgb(230, 70, 60), rgb(255, 200, 50), rgb(70, 140, 230), rgb(240, 140, 60), rgb(120, 200, 90) }
	for _, s in { -1, 1 } do
		local x = s * 9.1
		local g = A.Storefront(L, at(x, 1.2, front), 8.2, 6.8, { Kick = K.Dark(wall), Panes = 3 })
		for k, y in { 1.5, 3.1 } do
			K.Block(L.Details, Vector3.new(7.4, 0.14, 0.06), g * CFrame.new(0, y, -0.06), C.Wood, true)
			for i = 0, 4 do
				local color = goods[(i + k + (if s > 0 then 2 else 0)) % #goods + 1]
				K.Block(L.Details, Vector3.new(0.75, 0.95 - (i % 2) * 0.3, 0.05), g * CFrame.new(-2.9 + i * 1.45, y + 0.55 - (i % 2) * 0.15, -0.05), color, true)
			end
		end
		A.Awning(L, at(x, 9.1, front), 9.0, 3.0, green, C.Trim)
		K.Block(B.Yard, Vector3.new(7.6, 1.0, 1.4), at(x, 0.5, front - 2.6), C.Wood, true)
		K.Block(B.Yard, Vector3.new(7.6, 1.8, 1.0), at(x, 0.9, front - 1.3), K.Dark(C.Wood), true)
		local fruits = { rgb(230, 40, 40), rgb(255, 150, 30), rgb(255, 225, 60), rgb(120, 200, 70), rgb(150, 70, 180), rgb(230, 40, 40) }
		for i = -1, 1 do
			produceCrate(B.Yard, at(x + i * 2.4, 1.0, front - 2.6) * CFrame.Angles(math.rad(-12), 0, 0), fruits[i + 2 + (if s > 0 then 3 else 0)], rng)
			produceCrate(B.Yard, at(x + i * 2.4, 1.8, front - 1.3) * CFrame.Angles(math.rad(-12), 0, 0), fruits[(i + 3 + (if s > 0 then 0 else 3)) % 6 + 1], rng)
		end
	end
	for _, s in { -1, 1 } do
		for _, z in { -5, 5 } do
			A.Window(L, at(s * W / 2, 6, z) * sideFace(s), 3.0, 3.6)
		end
	end

	-- forecourt, cart corral with nested carts, a loose cart full of groceries, sandwich board
	K.Block(B.Yard, Vector3.new(W + 2, 0.12, 8), at(0, 0.06, front - 4), C.Sidewalk, true)
	local corral = 16.6 -- beside the building, along its side
	for _, dx in { -1.25, 1.25 } do
		for z = -17, -10, 3.5 do
			local h = if z == -17 then 3.0 else 1.7 -- the front pair carries the sign
			K.Block(B.Yard, Vector3.new(0.2, h, 0.2), at(corral + dx, h / 2, z), C.MetalDark, true)
		end
		K.Tube(B.Yard, pt(corral + dx, 1.7, -17), pt(corral + dx, 1.7, -10), 0.16, rgb(220, 40, 40), true)
	end
	sign(B.Yard, at(corral, 2.55, -17.1), 2.6, 0.7, "CARTS", rgb(220, 40, 40), C.Trim)
	for _, z in { -14.8, -12.4 } do
		GrandmaProps.ShoppingCart(B.Street, at(corral, 0, z) * CFrame.Angles(0, math.pi, 0), rng, true)
	end
	GrandmaProps.ShoppingCart(B.Street, at(-3.8, 0, -16.4) * CFrame.Angles(0, 0.6, 0), rng)
	sandwichBoard(B.Yard, at(-12, 0, -16.4) * CFrame.Angles(0, 0.3, 0), "PRUNES ON SALE!", rgb(40, 60, 50))
end

-- 4. Coffee Shop: two stories of red brick under a flat roof with a cream dentil cornice, corbels, a raised
-- date-stone parapet and a giant steaming coffee cup on legs; tall crowned upper windows with flower boxes, a
-- belt course, THE DAILY GRIND sign band, a shop window and a glass door under green striped awnings, and a
-- terrace with bistro tables, planters, flowerpots and a sandwich board.
function BUILDERS.CoffeeShop(B: Context, curb: CFrame, rng: Random)
	local L = B.L
	local W, D, H = 16, 16, 18
	local box = curb * CFrame.new(0, 0, 8 + D / 2)
	local at, pt = frame(box)
	local brick, cream, green = rgb(156, 72, 56), rgb(250, 236, 205), rgb(40, 110, 80)
	local coffee = rgb(110, 66, 40)
	local front = -D / 2
	A.Walls(L, box, W, H, D, brick, "Brick", C.Trim, rng)
	local top = A.FlatRoof(L, box, W, D, H, brick, { Parapet = 2.6, Cornice = cream, Dentils = true, Units = 1 })
	for x = -6, 6, 3 do
		K.Block(L.Details, Vector3.new(0.5, 0.9, 0.7), at(x, H - 1.25, front - 0.35), cream, true)
	end
	K.Block(L.Walls, Vector3.new(6, 1.5, 0.8), at(0, top + 0.3, front + 0.4), brick)
	K.Block(L.Roofs, Vector3.new(6.8, 0.4, 1.4), at(0, top + 1.2, front + 0.3), cream, true)
	local date = K.Panel(L.Details, 2.4, 0.8, at(0, top + 0.3, front), cream, 0.08, 0.06)
	K.Text(date, "1924", brick)
	K.Block(L.Walls, Vector3.new(W + 0.6, 0.6, D + 0.6), at(0, 10.0, 0), cream, true)
	for _, x in { -5, 0, 5 } do
		A.Window(L, at(x, 14.2, front), 2.6, 4.6, { Crown = true, Grid = true, Trim = cream, Box = green })
	end
	for _, s in { -1, 1 } do
		for _, z in { -3.5, 3.5 } do
			A.Window(L, at(s * W / 2, 14.2, z) * sideFace(s), 2.6, 4.6, { Crown = true, Trim = cream })
		end
		A.Window(L, at(s * W / 2, 5.2, 0) * sideFace(s), 3.0, 3.6, { Trim = cream })
	end
	sign(L.Details, at(0, 8.7, front), 12, 1.4, "THE DAILY GRIND", green, cream)

	-- ground floor: shop window with the cafe inside, glass door, awnings, steps
	local g = A.Storefront(L, at(-2.6, 1.2, front), 8.0, 6.4, { Frame = green, Kick = K.Dark(brick), Panes = 3 })
	K.Block(L.Details, Vector3.new(6.4, 1.0, 0.05), g * CFrame.new(0, 0.6, -0.05), C.Wood, true)
	K.Block(L.Details, Vector3.new(1.3, 1.1, 0.06), g * CFrame.new(-1.6, 1.65, -0.06), C.Metal, true)
	for i = 0, 2 do
		K.Block(L.Details, Vector3.new(0.35, 0.4, 0.06), g * CFrame.new(0.6 + i * 0.7, 1.3, -0.06), C.Trim, true)
	end
	A.Door(L, at(5.0, 1.2, front), 2.6, 6.2, green, { Glass = true, Trim = cream })
	for k = 1, 2 do
		K.Block(L.Details, Vector3.new(3.8, 1.2 - k * 0.4, 0.9), at(5.0, (1.2 - k * 0.4) / 2, front - 0.75 - (k - 1) * 0.9), C.Stone, true)
	end
	A.Awning(L, at(-2.6, 7.7, front), 8.6, 2.4, green, cream)
	A.Awning(L, at(5.0, 7.7, front), 3.6, 2.2, green, cream)

	-- giant coffee cup on four legs on the roof, with three curls of steam
	for _, x in { -1.6, 1.6 } do
		for _, z in { -0.2, 3.2 } do
			K.Rod(L.Details, pt(x, H + 0.6, z), pt(x * 0.8, H + 4.8, z * 0.9 + 0.2), 0.3, C.MetalDark, true)
		end
	end
	local base = pt(0, H + 4.8, 1.5)
	local up = Vector3.yAxis
	K.Disc(L.Details, 5.0, 0.35, base, C.Trim, true)
	K.Disc(L.Details, 5.2, 0.12, base - up * 0.06, C.Ink, true)
	K.Disc(L.Details, 3.2, 3.0, base + up * 0.35, C.Trim)
	K.Disc(L.Details, 3.26, 0.8, base + up * 1.3, green, true)
	K.Disc(L.Details, 3.4, 0.35, base + up * 3.1, cream, true)
	K.Disc(L.Details, 2.9, 0.1, base + up * 3.38, coffee, true)
	local handle = { pt(1.5, H + 6.1, 1.5), pt(2.5, H + 6.3, 1.5), pt(2.5, H + 7.4, 1.5), pt(1.5, H + 7.6, 1.5) }
	for i = 1, 3 do
		K.Rod(L.Details, handle[i], handle[i + 1], 0.4, C.Trim, true)
	end
	for k = -1, 1 do
		local x = k * 0.8
		local curl = { pt(x, H + 8.6, 1.5), pt(x + 0.4, H + 9.5, 1.5), pt(x - 0.2, H + 10.4, 1.5), pt(x + 0.3, H + 11.2, 1.5) }
		for i = 1, 3 do
			local steam = K.Rod(L.Details, curl[i], curl[i + 1], 0.3, C.Trim, true)
			steam.Transparency = 0.25
		end
	end

	-- terrace
	K.Block(B.Yard, Vector3.new(W + 2, 0.12, 8), at(0, 0.06, front - 4), C.Sidewalk, true)
	YardProps.CafeTable(B.Yard, at(-4.4, 0, front - 4.3), green, true)
	YardProps.CafeTable(B.Yard, at(2.6, 0, front - 5.4), green)
	for _, x in { -6.4, 6.8 } do
		local soil = StreetProps.Planter(B.Yard, at(x, 0, front - 7.2), 2.6)
		for k = -1, 1 do
			Vegetation.Flower(B.Garden, if k == 0 then "Rose" else "Tulip", (soil * CFrame.new(k * 0.8, 0, 0)).Position, rng)
		end
	end
	for _, x in { 2.1, 7.6 } do
		YardProps.FlowerPot(B.Yard, at(x, 0, front - 0.9), rng, rgb(70, 120, 210))
	end
	sandwichBoard(B.Yard, at(0.6, 0, front - 2.0) * CFrame.Angles(0, 0.2, 0), "LATTE $2", rgb(40, 60, 50))
end

-- 5. Town Hall: two stories of red brick with white quoins, belt course and cornice under a gable roof with two
-- dormers and a clock cupola (clocks on three sides, octagonal belfry, dome, gold ball, pennant); a columned
-- portico on a high base with wide steps and a TOWN HALL pediment, paneled double doors under a fanlight,
-- shuttered windows, and a lawn with the town flag (pink, golden slipper), benches, lamps, flower beds and a walk.
function BUILDERS.TownHall(B: Context, curb: CFrame, rng: Random)
	local L = B.L
	local W, D, H = 30, 22, 18
	local box = curb * CFrame.new(0, 0, 14 + D / 2)
	local at, pt = frame(box)
	local brick, trim, roof = C.Brick, C.Trim, C.Roofs[2]
	local front = -D / 2
	A.Walls(L, box, W, H, D, brick, "Brick", trim, rng)
	K.Block(L.Walls, Vector3.new(W + 0.6, 0.6, D + 0.6), at(0, 9.4, 0), trim, true)
	K.Block(L.Walls, Vector3.new(W + 1.2, 0.9, D + 1.2), at(0, H - 0.45, 0), trim, true)
	for x = -W / 2 + 0.9, W / 2 - 0.8, 1.2 do
		K.Block(L.Details, Vector3.new(0.45, 0.4, 0.4), at(x, H - 1.1, front - 0.2), trim, true)
	end
	for _, s in { -1, 1 } do
		for k = 0, 6 do
			local wide = k % 2 == 0
			K.Block(L.Details, Vector3.new(if wide then 1.7 else 1.1, 1.0, 0.25), at(s * (W / 2 - (if wide then 0.85 else 0.55)), 2.2 + k * 2.2, front - 0.12), trim, true)
		end
	end
	local roofInfo = A.GableRoof(L, box, W, D, H, 8, roof, trim, { Vents = false, Downspouts = true, Back = false })
	for _, x in { -9.5, 9.5 } do
		A.Dormer(L, box, roofInfo, x, 2.2, 2.2, trim, roof, trim)
	end

	-- clock cupola on the ridge
	K.Block(L.Walls, Vector3.new(7, 7, 7), at(0, 25.5, 0), trim)
	K.InkCorners(L.Walls, at(0, 25.5, 0), Vector3.new(7.2, 7, 7.2))
	K.Block(L.Roofs, Vector3.new(8, 0.6, 8), at(0, 29.3, 0), roof, true)
	for _, turn in { 0, math.pi / 2, -math.pi / 2 } do
		clock(L.Details, at(0, 26.2, 0) * CFrame.Angles(0, turn, 0) * CFrame.new(0, 0, -3.5), 4.4)
	end
	K.Octagon(L.Walls, 5.4, 3.6, at(0, 31.4, 0), trim)
	for k = 0, 3 do
		louver(L.Details, at(0, 31.3, 0) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -2.7), 1.4, 2.6, K.Dark(trim))
	end
	K.Octagon(L.Roofs, 6.2, 0.5, at(0, 33.45, 0), roof, true)
	K.Cone(L.Roofs, 5.8, 4.4, at(0, 33.7, 0), rgb(90, 160, 140), false, 12)
	K.Ball(L.Roofs, 1.6, pt(0, 38.2, 0), GOLD, true)
	K.Tube(L.Details, pt(0, 38.6, 0), pt(0, 42.6, 0), 0.14, C.MetalDark, true)
	K.Block(L.Details, Vector3.new(0.06, 1.0, 1.6), at(0, 42.0, -0.85), rgb(220, 50, 60), true)

	-- portico, doors, windows
	A.Porch(L, at(0, 0, front), {
		Width = 14,
		Depth = 6.5,
		Floor = 2.4,
		Columns = { -6, -2.2, 2.2, 6 },
		ColumnHeight = 11.5,
		Style = "Square",
		StepWidth = 8,
		Roof = "Gable",
		RoofColor = roof,
		GableRise = 3.6,
	})
	sign(L.Details, at(0, 14.6, front - 6.5), 7.2, 1.2, "TOWN HALL", NAVY, GOLD)
	for _, x in { -1.45, 1.45 } do
		A.Door(L, at(x, 2.4, front), 2.8, 7.6, NAVY, { Glass = true })
	end
	fanlight(L.Details, at(0, 10.95, front), 3.4)
	for _, x in { -10.5, 10.5 } do
		A.Window(L, at(x, 5.4, front), 3.0, 5.0, { Crown = true, Grid = true, Shutters = NAVY, ShutterWidth = 1.2 })
		A.Window(L, at(x, 13.8, front), 3.0, 4.4, { Crown = true, Grid = true, Shutters = NAVY, ShutterWidth = 1.2 })
	end
	for _, s in { -1, 1 } do
		for _, z in { -5, 5 } do
			for _, y in { 5.4, 13.8 } do
				A.Window(L, at(s * W / 2, y, z) * sideFace(s), 3.0, 4.4, { Crown = true, Grid = true })
			end
		end
	end

	-- lawn: walk, flagpole, benches, lamps, flower beds, shrubs
	K.Block(B.Yard, Vector3.new(8, 0.2, 4.6), at(0, 0.1, front - 11.7), C.Path, true)
	local pole = at(-9.5, 0, front - 6.0)
	K.Octagon(B.Yard, 1.8, 0.6, pole * CFrame.new(0, 0.3, 0), C.Stone)
	K.Tube(B.Yard, (pole * CFrame.new(0, 0.6, 0)).Position, (pole * CFrame.new(0, 18, 0)).Position, 0.25, C.Trim, true)
	K.Ball(B.Yard, 0.55, (pole * CFrame.new(0, 18.2, 0)).Position, GOLD, true)
	-- the town flag: pink with a golden slipper
	K.Block(B.Yard, Vector3.new(4.0, 2.4, 0.08), pole * CFrame.new(2.1, 16.5, 0), rgb(255, 120, 170), true)
	K.Block(B.Yard, Vector3.new(4.0, 0.3, 0.1), pole * CFrame.new(2.1, 15.45, 0), C.Trim, true)
	K.Block(B.Yard, Vector3.new(1.6, 0.45, 0.12), pole * CFrame.new(2.1, 16.4, 0), GOLD, true)
	K.Ball(B.Yard, 0.55, (pole * CFrame.new(2.6, 16.75, 0)).Position, C.Trim, true)
	for _, s in { -1, 1 } do
		StreetProps.Lamp(B.Street, pt(s * 5.4, 0, front - 12.6))
		StreetProps.Bench(B.Street, at(s * 12, 0, front - 10.4))
		Vegetation.Bed(B.Garden, pt(s * 8, 0, front - 1.3), pt(s * 14, 0, front - 1.3), { "Tulip", "Daisy" }, rng)
		Vegetation.Bush(B.Garden, "Round", pt(s * 15.6, 0, front - 2.4), rng, 0.8)
	end
end

-- A gas pump on an island (`cf` = island top, LookVector toward its lane): base, red body with a dark screen
-- and a price window, white header with the brand, holster with a hose and nozzle.
local function pump(P: Instance, cf: CFrame, red: Color3)
	K.Block(P, Vector3.new(1.6, 0.35, 1.0), cf * CFrame.new(0, 0.17, 0), C.MetalDark, true)
	K.Block(P, Vector3.new(1.4, 3.2, 0.8), cf * CFrame.new(0, 1.95, 0), red)
	K.Block(P, Vector3.new(1.6, 0.7, 0.95), cf * CFrame.new(0, 3.9, 0), C.Trim, true)
	K.Ink(P, Vector3.new(1.62, 0.1, 0.97), cf * CFrame.new(0, 3.55, 0))
	K.Panel(P, 0.9, 0.6, cf * CFrame.new(0, 2.7, -0.4), rgb(40, 50, 60), 0.06, 0.04)
	local price = K.Panel(P, 1.0, 0.35, cf * CFrame.new(0, 3.9, -0.47), rgb(255, 204, 56), 0.05, 0.03)
	K.Text(price, "1.99", C.Ink)
	K.Block(P, Vector3.new(0.3, 0.5, 0.25), cf * CFrame.new(0.5, 1.8, -0.5), C.MetalDark, true)
	K.Block(P, Vector3.new(0.2, 0.55, 0.18), cf * CFrame.new(0.5, 1.95, -0.66) * CFrame.Angles(math.rad(25), 0, 0), C.Ink, true)
	local hose = { (cf * CFrame.new(0.5, 1.65, -0.62)).Position, (cf * CFrame.new(0.62, 0.9, -0.75)).Position, (cf * CFrame.new(0.6, 0.6, -0.42)).Position }
	for i = 1, 2 do
		K.Rod(P, hose[i], hose[i + 1], 0.12, C.Ink, true)
	end
end

-- 6. Gas Station on a corner lot: asphalt lot with an ink edge, a canopy (white deck with red and yellow fascia
-- stripes, a dark top tier, GRANNY GAS brand panel, lights underneath) on four columns over two pump islands
-- (yellow bollards, two pumps each, trash cans), a car at the pumps, the MINI MART convenience store (siding,
-- flat roof, red cornice, shop windows with posters, glass door, newspaper box, ice chest, wheelie bins),
-- parking spaces with wheel stops and a parked car, and a tall price sign at the street corner.
function BUILDERS.GasStation(B: Context, st: CFrame, rng: Random)
	local L = B.L
	local at = frame(st)
	local red, yellow, white = rgb(220, 50, 45), rgb(255, 204, 56), C.Trim
	local center = st.Position
	K.Block(B.Yard, Vector3.new(43, 0.1, 43), CFrame.new(center + Vector3.new(0, 0.05, 0)), C.Ink, true)
	K.Block(B.Yard, Vector3.new(42, 0.14, 42), CFrame.new(center + Vector3.new(0, 0.07, 0)), C.Road)

	-- canopy over two pump islands
	local canopy = at(0, 0, -7)
	for _, x in { -5, 5 } do
		local island = canopy * CFrame.new(x, 0, 0)
		K.Block(L.Details, Vector3.new(2.4, 0.45, 9.4), island * CFrame.new(0, 0.22, 0), C.Sidewalk)
		K.Ink(L.Details, Vector3.new(2.44, 0.06, 9.44), island * CFrame.new(0, 0.42, 0))
		for _, z in { -4.7, 4.7 } do
			K.Block(L.Details, Vector3.new(0.5, 1.8, 0.5), island * CFrame.new(0, 1.1, z), yellow, true)
			K.Ink(L.Details, Vector3.new(0.54, 0.15, 0.54), island * CFrame.new(0, 1.4, z))
		end
		for _, z in { -3.9, 3.9 } do
			K.Block(L.Walls, Vector3.new(0.9, 8.6, 0.9), island * CFrame.new(0, 4.75, z), white)
			K.Block(L.Walls, Vector3.new(1.3, 0.8, 1.3), island * CFrame.new(0, 0.85, z), red, true)
		end
		for _, z in { -1.7, 1.7 } do
			pump(L.Details, island * CFrame.new(0, 0.45, z) * CFrame.Angles(0, if x < 0 then -math.pi / 2 else math.pi / 2, 0), red)
		end
		StreetProps.TrashCan(B.Street, (island * CFrame.new(0, 0, if x < 0 then -5.9 else 5.9)).Position)
	end
	K.Block(L.Roofs, Vector3.new(24, 1.6, 13), canopy * CFrame.new(0, 9.85, 0), white)
	K.Block(L.Roofs, Vector3.new(24.15, 0.45, 13.15), canopy * CFrame.new(0, 9.45, 0), red, true)
	K.Block(L.Roofs, Vector3.new(24.15, 0.25, 13.15), canopy * CFrame.new(0, 10.05, 0), yellow, true)
	K.Block(L.Roofs, Vector3.new(23, 0.5, 12), canopy * CFrame.new(0, 10.9, 0), C.MetalDark, true)
	K.Ink(L.Roofs, Vector3.new(24.2, 0.12, 13.2), canopy * CFrame.new(0, 9.0, 0))
	sign(L.Details, canopy * CFrame.new(0, 9.9, -6.5), 9, 1.2, "GRANNY GAS", white, red)
	for _, x in { -5, 5 } do
		local light = K.Block(L.Details, Vector3.new(1.4, 0.1, 6), canopy * CFrame.new(x, 8.98, 0), rgb(255, 250, 220), true)
		light.Material = Enum.Material.Neon
	end
	Vehicles.Build(B.Vehicles, "Sedan", canopy * CFrame.new(0, 0.14, 0.4))

	-- convenience store
	local store = at(0, 0, 8.5)
	local sf = store * CFrame.new(0, 0, -5)
	A.Walls(L, store, 18, 9, 10, white, "Siding", red, rng)
	A.FlatRoof(L, store, 18, 10, 9, white, { Parapet = 1.6, Cornice = red, Units = 1 })
	sign(L.Details, store * CFrame.new(0, 9.85, -5), 10, 1.2, "MINI MART", red, white)
	for _, s in { -1, 1 } do
		local g = A.Storefront(L, sf * CFrame.new(s * 5.6, 1.2, 0), 5.2, 5.8, { Frame = red, Kick = K.Dark(red), Panes = 2 })
		local poster = K.Block(L.Details, Vector3.new(1.8, 1.2, 0.05), g * CFrame.new(s * 1.2, 2.2, -0.06), if s < 0 then yellow else rgb(70, 140, 230), true)
		K.Text(poster, if s < 0 then "SNACKS" else "COLD DRINKS", C.Ink)
	end
	A.Storefront(L, sf * CFrame.new(0, 1.2, 0), 3.0, 6.6, { Frame = red, KickHeight = 0.3, Panes = 1 })
	K.Block(L.Details, Vector3.new(0.12, 1.4, 0.12), sf * CFrame.new(0.9, 4.2, -0.4), C.Metal, true)
	K.Wedge(L.Details, Vector3.new(4.2, 1.2, 2.0), sf * CFrame.new(0, 0.6, -1.0), C.Sidewalk)
	StreetProps.NewspaperBox(B.Street, sf * CFrame.new(3.0, 0, -2.4))
	local ice = store * CFrame.new(-10.3, 0, 1)
	K.Block(B.Yard, Vector3.new(1.4, 2.2, 3.0), ice * CFrame.new(0, 1.1, 0), C.Trim)
	K.Block(B.Yard, Vector3.new(1.5, 0.3, 3.1), ice * CFrame.new(0, 2.25, 0), rgb(70, 140, 230), true)
	local iceSign = K.Block(B.Yard, Vector3.new(0.05, 0.8, 2.0), ice * CFrame.new(-0.73, 1.3, 0), rgb(70, 140, 230), true)
	K.Text(iceSign, "ICE", C.Trim, false, Enum.NormalId.Left)
	for i, kind in { "Trash", "Recycling" } do
		YardProps.WheelieBin(B.Yard, store * CFrame.new(10.3, 0, -2 + i * 2.0) * CFrame.Angles(0, -math.pi / 2, 0), kind)
	end

	-- parking spaces beside the store, a parked hatchback
	for _, s in { -1, 1 } do
		for _, dx in { -3.3, 3.3 } do
			K.Block(B.Yard, Vector3.new(0.25, 0.03, 11), at(s * 15 + dx, 0.155, 2.5), C.Trim, true)
		end
		K.Block(B.Yard, Vector3.new(4, 0.4, 0.6), at(s * 15, 0.34, 7.6), C.Stone, true)
	end
	Vehicles.Build(B.Vehicles, "Hatchback", at(15, 0.14, 2.3) * CFrame.Angles(0, math.pi, 0))

	-- price sign at the corner
	local pylon = at(0, 0, -21.5)
	K.Block(L.Walls, Vector3.new(4.6, 1.0, 1.6), pylon * CFrame.new(0, 0.5, 0), C.Brick)
	for _, x in { -1.6, 1.6 } do
		K.Block(L.Walls, Vector3.new(0.5, 9, 0.5), pylon * CFrame.new(x, 5, 0), C.MetalDark)
	end
	K.Block(L.Details, Vector3.new(4.2, 6.0, 0.6), pylon * CFrame.new(0, 7.4, 0), white)
	sign(L.Details, pylon * CFrame.new(0, 9.6, -0.3), 3.8, 1.4, "GRANNY GAS", red, yellow)
	for i, row in { "REGULAR 1.99", "PREMIUM 2.29", "PRUNE JUICE 0.99" } do
		local panel = K.Panel(L.Details, 3.6, 0.85, pylon * CFrame.new(0, 8.1 - (i - 1) * 1.2, -0.3), C.Ink, 0.05, 0.05)
		K.Text(panel, row, yellow)
	end
	K.Block(L.Roofs, Vector3.new(4.6, 0.4, 0.9), pylon * CFrame.new(0, 10.6, 0), red, true)
end

-- Builds one community building of `kind` (see Buildings.Kinds) on its lot. Walls, roofs and details go into
-- one sub-Model per building in each house outline group.
function Buildings.Build(groups: { [string]: Model }, kind: string, cframe: CFrame, rng: Random)
	local function sub(group: Instance): Model
		local model = K.Model(kind)
		model.Parent = group
		return model
	end
	local context: Context = {
		L = { Walls = sub(groups.HouseWalls), Roofs = sub(groups.HouseRoofs), Details = sub(groups.HouseDetails) },
		Yard = sub(groups.Yards),
		Street = groups.StreetProps,
		Garden = Vegetation.LayersFrom(groups),
		Vehicles = { Body = groups.Cars, Details = groups.CarDetails },
	}
	BUILDERS[kind](context, cframe, rng)
end

return Buildings
