--!nonstrict
-- The six comic-style house designs of the neighborhood, assembled from Architecture components, plus each
-- house's front yard (picket fence, path, driveway + car, mailbox, garden, decorations).
-- Every design is built around the ground center of its main box (`cframe`, front = LookVector, which faces
-- the arena) and returns a yard description. Numbers below were laid out so that windows, shutters, porches
-- and roofs do not overlap; keep them consistent when changing a design.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Architecture = require(script.Parent.Architecture)
local ComicKit = require(script.Parent.ComicKit)
local Props = require(script.Parent.Props)
local Vegetation = require(script.Parent.Vegetation)

local A = Architecture
local K = ComicKit
local C = ComicKit.Colors
local Face = Architecture.Face

local Houses = {}

local TURN = CFrame.Angles(0, math.pi / 2, 0) -- turns a roof so its ridge runs front to back
local GOLD = Color3.fromRGB(255, 205, 70)

type YardInfo = {
	DoorX: number, -- path line
	StepsZ: number, -- local z of the front of the porch steps
	FenceZ: number, -- local z of the yard fence
	LotLeft: number,
	LotRight: number,
	Garage: { X: number, Width: number, FrontZ: number }?,
	-- Planting, in local x/z: { "Bush", kind, x, z, scale? } | { "Tree", kind, x, z, scale? } |
	-- { "Flower", kind, x, z } | { "Bed", x1, x2, z, { flower kinds } } | { "Row", bush kind, x1, x2, z, spacing, scale }
	Garden: { { any } }?,
	Decor: ((parent: Instance, at: (x: number, z: number) -> CFrame) -> ())?,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function placer(cframe: CFrame): (x: number, y: number, z: number) -> CFrame
	return function(x, y, z)
		return cframe * CFrame.new(x, y, z)
	end
end

local function sideFace(side: number): CFrame
	return if side == 1 then Face.Right else Face.Left
end

-- Trim band around a box between the floors.
local function belt(L, box: CFrame, W: number, D: number, y: number, color: Color3)
	K.Block(L.Walls, Vector3.new(W + 0.5, 0.5, D + 0.5), box * CFrame.new(0, y, 0), color, true)
end

----------------------------------------------------------------------------------------------------- designs

local DESIGNS: { [string]: (L: any, cframe: CFrame, rng: Random) -> YardInfo } = {}

-- 1. Blue two-story family house: siding, a two-story entry bay with its own gable, wide porch with a
-- railing and a shed roof, attached garage.
function DESIGNS.Family(L, cframe, rng)
	local at = placer(cframe)
	local blue, roof, trim = rgb(132, 188, 236), C.Roofs[1], C.Trim
	local W, D, H = 24, 18, 19
	local front = -D / 2
	A.Walls(L, at(0, 0, 0), W, H, D, blue, "Siding", trim, rng)
	belt(L, at(0, 0, 0), W, D, 10, trim)
	A.GableRoof(L, cframe, W, D, H, 7, roof, blue, { Downspouts = true })
	A.Chimney(L, at(8, 0, 3), H, H + 9.2, C.Brick)

	A.Walls(L, at(-3, 0, -9.75), 7, H, 3.5, blue, "Siding", trim, rng)
	belt(L, at(-3, 0, -9.75), 7, 3.5, 10, trim)
	A.GableRoof(L, at(-3, 0, -7.25) * TURN, 8.5, 7, H, 4.5, roof, blue)

	A.Porch(L, at(-3, 0, front), { Width = 16, Depth = 6, Columns = { -7.4, -3, 3, 7.4 }, ColumnHeight = 6.6, Style = "Square", Rail = true, Roof = "Shed", RoofColor = roof })
	A.Door(L, at(-3, 1.2, -11.5), 3.2, 6.2, rgb(196, 52, 46), { Glass = true })

	local win = { Crown = true }
	for _, x in { -9.2, 9.4 } do
		A.Window(L, at(x, 5.6, front), 2.8, 4.2, win)
		A.Window(L, at(x, 14.3, front), 2.8, 4.2, win)
	end
	A.Window(L, at(4.5, 5.6, front), 3.2, 4.2, win)
	A.Window(L, at(4.5, 14.3, front), 3.2, 4.2, win)
	A.Window(L, at(-3, 14.3, -11.5), 3.4, 4.2, { Crown = true, Box = C.Wood })
	A.Window(L, at(-W / 2, 5.6, 2) * Face.Left, 3, 4.2, win)
	A.Window(L, at(-W / 2, 14.3, 2) * Face.Left, 3, 4.2, win)
	A.Window(L, at(W / 2, 14.3, 0) * Face.Right, 3, 4.2, win)

	A.Garage(L, at(18, 0, 2), 12, 16, 10, blue, roof, "Siding", rng, trim)
	return {
		DoorX = -3,
		StepsZ = front - 6.9,
		FenceZ = -18.6,
		LotLeft = -14.5,
		LotRight = 25,
		Garage = { X = 18, Width = 10, FrontZ = -6 },
		Garden = {
			{ "Bed", 5.8, 11.2, -9.9, { "Tulip", "Daisy" } },
			{ "Bush", "Corner", -13.8, -11.2, 0.7 },
			{ "Bush", "Pointed", 11.4, -11.8 },
		},
	}
end

-- 2. Yellow grandmother's cottage: steep front gable with a round attic window, shutters with flower boxes,
-- stone chimney up the side wall, small stoop with a bracketed door hood.
function DESIGNS.Cottage(L, cframe, rng)
	local at = placer(cframe)
	local yellow, roof, green = rgb(252, 212, 92), C.Roofs[4], rgb(46, 120, 80)
	local W, D, H = 20, 16, 10
	local front = -D / 2
	A.Walls(L, at(0, 0, 0), W, H, D, yellow, "Siding", C.Trim, rng)
	A.GableRoof(L, cframe * TURN, D, W, H, 8, roof, yellow, { Downspouts = true, Vents = false })
	A.RoundWindow(L, at(0, H + 2.8, front), 2.2)
	A.SideChimney(L, at(W / 2, 0, 2) * Face.Right, 7.5, 16, rgb(160, 148, 136))

	A.Porch(L, at(0, 0, front), { Width = 6, Depth = 2.6 })
	A.Door(L, at(0, 1.2, front), 3, 6.2, rgb(40, 70, 130))
	A.GableRoof(L, at(0, 0, front - 1) * TURN, 2, 5, 8.6, 1.6, roof, C.Trim, { Over = 0.5, Vents = false, Gutters = false })
	for _, s in { -1, 1 } do
		A.Bar(L.Details, cframe, Vector3.new(s * 2.35, 7.0, front - 0.15), Vector3.new(s * 2.35, 8.6, front - 1.9), 0.3, C.Trim)
	end

	local win = { Shutters = green, ShutterWidth = 1.0, Box = rgb(176, 96, 56) }
	for _, x in { -6, 6 } do
		A.Window(L, at(x, 5.4, front), 2.8, 4, win)
	end
	A.Window(L, at(-W / 2, 5.4, 0) * Face.Left, 2.8, 4, win)
	A.Window(L, at(W / 2, 5.4, -4.2) * Face.Right, 2.8, 4, win)
	return {
		DoorX = 0,
		StepsZ = front - 3.5,
		FenceZ = -15.5,
		LotLeft = -12,
		LotRight = 13,
		Garden = {
			{ "Bed", -9.4, -3.6, -9.0, { "Rose", "Daisy" } },
			{ "Bed", 3.6, 9.4, -9.0, { "Tulip", "Wildflower" } },
			{ "Bush", "Pointed", -10.8, -10.6 },
			{ "Bush", "Pointed", 10.8, -10.6 },
			{ "Tree", "Ornamental", -8.4, -13.2 },
		},
		Decor = function(parent, spot)
			Props.Gnome(parent, spot(3.6, -13))
			Props.Gnome(parent, spot(-3.4, -13.4) * CFrame.Angles(0, 0.5, 0))
		end,
	}
end

-- 3. Red brick Colonial: symmetrical two-story facade with 6-pane windows, cornice, steep roof with two
-- dormers and two end chimneys, columned portico with a pediment, door with sidelights.
function DESIGNS.Colonial(L, cframe, rng)
	local at = placer(cframe)
	local brick, roof = C.Brick, C.Roofs[2]
	local W, D, H = 30, 20, 19
	local front = -D / 2
	A.Walls(L, at(0, 0, 0), W, H, D, brick, "Brick", C.Trim, rng)
	belt(L, at(0, 0, 0), W, D, 10, C.Trim)
	K.Block(L.Walls, Vector3.new(W + 0.8, 0.6, D + 0.8), at(0, H - 0.3, 0), C.Trim, true)
	local roofInfo = A.GableRoof(L, cframe, W, D, H, 10, roof, brick, { Downspouts = true, Vents = false })
	for _, x in { -12.5, 12.5 } do
		A.Chimney(L, at(x, 0, 0), H, H + 12.5, brick)
	end
	for _, x in { -7.4, 7.4 } do
		A.Dormer(L, cframe, roofInfo, x, 2.4, 2.2, C.Trim, roof, C.Trim)
	end

	A.Porch(L, at(0, 0, front), { Width = 8, Depth = 4.5, Columns = { -3.4, 3.4 }, ColumnHeight = 7.2, Roof = "Gable", RoofColor = roof, GableRise = 2.0, StepWidth = 4 })
	A.Door(L, at(0, 1.2, front), 3, 6.2, rgb(30, 44, 80), { Sidelights = true })

	local win = { Grid = true, Crown = true }
	for _, x in { -12.2, -7.4, 7.4, 12.2 } do
		A.Window(L, at(x, 5.6, front), 3, 4.4, win)
	end
	for _, x in { -12.2, -7.4, 0, 7.4, 12.2 } do
		A.Window(L, at(x, 14.6, front), 3, 4.4, win)
	end
	for _, s in { -1, 1 } do
		for _, y in { 5.6, 14.6 } do
			A.Window(L, at(s * W / 2, y, -4) * sideFace(s), 3, 4.4, win)
		end
	end
	return {
		DoorX = 0,
		StepsZ = front - 5.4,
		FenceZ = -18,
		LotLeft = -16.5,
		LotRight = 16.5,
		Garden = {
			{ "Row", "Round", -13.6, -5.4, -11.6, 2.7, 0.6 },
			{ "Row", "Round", 5.4, 13.6, -11.6, 2.7, 0.6 },
			{ "Bed", -13.6, -5.4, -13.4, { "Tulip" } },
			{ "Bed", 5.4, 13.6, -13.4, { "Tulip" } },
			{ "Bush", "Pointed", -3.2, -15.6, 0.8 },
			{ "Bush", "Pointed", 3.2, -15.6, 0.8 },
		},
	}
end

-- 4. Pink eccentric grandma house: oversized porch with turned columns, mint railings and party bunting,
-- shutters with flower boxes, round gable windows, a cupola with a weather vane, flamingos and a gnome.
function DESIGNS.GrandmaPink(L, cframe, rng)
	local at = placer(cframe)
	local pink, roof, mint = rgb(255, 150, 190), rgb(130, 80, 170), rgb(110, 215, 185)
	local W, D, H = 22, 18, 11
	local front = -D / 2
	A.Walls(L, at(0, 0, 0), W, H, D, pink, "Shingle", C.Trim, rng)
	A.GableRoof(L, cframe, W, D, H, 7, roof, pink, { Downspouts = true, Vents = false })
	for _, s in { -1, 1 } do
		A.RoundWindow(L, at(s * W / 2, H + 2.6, 0) * sideFace(s), 2.2, mint)
	end
	A.Chimney(L, at(-6, 0, 3), H, H + 9.2, C.Brick)

	local ridge = H + 7
	K.Block(L.Walls, Vector3.new(3.2, 3.6, 3.2), at(5, ridge + 0.6, 0), pink)
	K.InkCorners(L.Walls, at(5, ridge + 0.6, 0), Vector3.new(3.2, 3.6, 3.2))
	for i = 0, 2 do
		K.Block(L.Details, Vector3.new(2.2, 0.15, 0.1), at(5, ridge + 0.9 + i * 0.6, -1.65), K.Dark(roof), true)
	end
	K.Block(L.Roofs, Vector3.new(3.8, 0.4, 3.8), at(5, ridge + 2.6, 0), C.Trim, true)
	K.Spire(L.Roofs, 4.2, 2.6, at(5, ridge + 2.8, 0), roof)
	Props.WeatherVane(L.Details, at(5, ridge + 5.4, 0))

	local edge = A.Porch(L, at(0, 0, front), { Width = 26, Depth = 7, Columns = { -12.4, -7, -2.6, 2.6, 7, 12.4 }, ColumnHeight = 6.2, Style = "Turned", Rail = true, RailColor = mint, Roof = "Shed", RoofColor = roof })
	Props.Bunting(L.Details, (edge * CFrame.new(-12.6, 0, 0)).Position, (edge * CFrame.new(12.6, 0, 0)).Position, 1.5)
	A.Door(L, at(0, 1.2, front), 3.2, 6.2, rgb(255, 205, 60), { Glass = true })

	local win = { Shutters = mint, ShutterWidth = 1.2, Box = roof }
	for _, x in { -6.5, 6.5 } do
		A.Window(L, at(x, 5.4, front), 3.4, 4, win)
	end
	for _, s in { -1, 1 } do
		A.Window(L, at(s * W / 2, 5.4, 0) * sideFace(s), 3.4, 4, win)
	end
	return {
		DoorX = 0,
		StepsZ = front - 7.9,
		FenceZ = -18.5,
		LotLeft = -14.5,
		LotRight = 14.5,
		Garden = {
			{ "Bed", -8, -2.4, -17.3, { "Tulip", "Daisy", "Rose" } },
			{ "Bed", 2.4, 8, -17.3, { "Daisy", "Tulip", "Rose" } },
			{ "Flower", "Sunflower", -12.6, -17.4 },
			{ "Flower", "Sunflower", -11.4, -17.8 },
			{ "Bush", "Flowering", -13.9, -7.6, 0.6 },
			{ "Bush", "Flowering", 13.9, -7.6, 0.6 },
		},
		Decor = function(parent, spot)
			Props.Flamingo(parent, spot(9.4, -17.3) * CFrame.Angles(0, 0.6, 0))
			Props.Flamingo(parent, spot(11.6, -17.1) * CFrame.Angles(0, -0.5, 0))
			Props.Gnome(parent, spot(-9, -17.4))
		end,
	}
end

-- 5. Cream Victorian: steep main gable, a front wing with its own gable and a canted bay window, a corner
-- tower with a spire, wrap-around porch with turned columns, teal trim and shingle siding.
function DESIGNS.Victorian(L, cframe, rng)
	local at = placer(cframe)
	local cream, teal, roof = rgb(246, 232, 196), rgb(60, 150, 160), C.Roofs[1]
	local W, D, H = 20, 18, 18
	local front = -D / 2
	A.Walls(L, at(0, 0, 0), W, H, D, cream, "Shingle", teal, rng)
	belt(L, at(0, 0, 0), W, D, 9.6, teal)
	A.GableRoof(L, cframe, W, D, H, 8, roof, cream, { Downspouts = true })
	A.Chimney(L, at(-3.5, 0, 4), H, H + 10.2, C.Brick)

	-- front wing: x 1.5..10, front at z = -13
	A.Walls(L, at(5.75, 0, -9), 8.5, H, 8, cream, "Shingle", teal, rng)
	belt(L, at(5.75, 0, -9), 8.5, 8, 9.6, teal)
	A.GableRoof(L, at(5.75, 0, -7) * TURN, 12, 8.5, H, 7, roof, cream, { Gutters = false })
	K.Block(L.Details, Vector3.new(8.5, 0.4, 0.5), at(5.75, H + 0.4, -13.3), teal, true)
	A.Bay(L, at(5.75, 0, -13), 3.4, 1.8, 3.2, 8.4, cream, roof, teal)
	A.Window(L, at(5.75, 13.6, -13), 3.2, 4.4, { Crown = true, Trim = teal })

	-- corner tower: x -10.75..-4.25, z -13.5..-7
	local tower = at(-7.5, 0, -10.25)
	A.Walls(L, tower, 6.5, 23, 6.5, cream, "Shingle", teal, rng)
	belt(L, tower, 6.5, 6.5, 9.6, teal)
	K.Block(L.Roofs, Vector3.new(7.4, 0.6, 7.4), tower * CFrame.new(0, 22.9, 0), teal, true)
	K.Spire(L.Roofs, 8.4, 9, tower * CFrame.new(0, 23.2, 0), roof)
	K.Block(L.Details, Vector3.new(0.2, 2.2, 0.2), tower * CFrame.new(0, 33.3, 0), C.Ink, true)
	K.Block(L.Details, Vector3.one * 0.6, tower * CFrame.new(0, 34.6, 0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), GOLD, true)
	A.Window(L, at(-7.5, 5.3, -13.5), 2.4, 4, { Trim = teal })
	A.Window(L, at(-7.5, 13.8, -13.5), 2.4, 4.2, { Crown = true, Trim = teal })
	A.Window(L, at(-7.5, 19.8, -13.5), 2.2, 2.2, { Trim = teal })
	A.Window(L, at(-10.75, 13.8, -10.25) * Face.Left, 2.4, 4.2, { Crown = true, Trim = teal })

	A.Porch(L, at(-4.75, 0, front), { Width = 12.5, Depth = 6, Columns = { -5.65, -2.75, 1.15, 5.65 }, ColumnHeight = 7, Style = "Turned", Rail = true, SideRails = false, Roof = "Shed", RoofColor = roof, StepX = 3.4, StepWidth = 3.4 })
	A.Door(L, at(-1.5, 1.2, front), 3, 6.4, rgb(150, 50, 70), { Glass = true, Trim = teal })
	A.Window(L, at(-1.5, 13.8, front), 3, 4.2, { Crown = true, Trim = teal })
	for _, s in { -1, 1 } do
		for _, y in { 5.4, 13.8 } do
			A.Window(L, at(s * W / 2, y, 2) * sideFace(s), 3, 4.2, { Crown = true, Trim = teal })
		end
	end
	return {
		DoorX = -1.35,
		StepsZ = front - 6.9,
		FenceZ = -17.8,
		LotLeft = -12.5,
		LotRight = 12.5,
		Garden = {
			{ "Bed", 2.2, 9.4, -15.6, { "Rose" } },
			{ "Bush", "Corner", 11.8, -15.4, 0.7 },
			{ "Bush", "Wild", -12.4, -5.6, 0.7 },
		},
	}
end

-- 6. Green craftsman bungalow: one big roof sweeping down over the full-width porch (tapered columns on
-- stone piers), a dormer, a stone chimney up the gable end and an attached garage.
function DESIGNS.Bungalow(L, cframe, rng)
	local at = placer(cframe)
	local green, cream, roof = rgb(150, 196, 140), rgb(246, 232, 196), C.Roofs[3]
	local W, D, H, rise = 26, 20, 12, 8
	local front = -D / 2
	local porchDepth = 6
	A.Walls(L, at(0, 0, 0), W, H, D, green, "Siding", cream, rng)
	local angle = math.atan2(rise, D / 2)
	local extend = (porchDepth + 0.8) / math.cos(angle) - 1.4 -- roof eave lands 0.8 past the porch
	local roofInfo = A.GableRoof(L, cframe, W, D, H, rise, roof, green, { Extend = extend, Downspouts = true })
	A.Dormer(L, cframe, roofInfo, -4, 3, 1.4, green, roof, cream)
	A.SideChimney(L, at(-W / 2, 0, 3) * Face.Left, 9, 22, rgb(150, 140, 130))

	-- the roof underside above the column line sets the column height
	local columnHeight = H - (porchDepth - 0.6) * math.tan(angle) - 1.2
	A.Porch(L, at(0, 0, front), { Width = 26, Depth = porchDepth, Columns = { -12.4, -6.6, -1.4, 4.6, 12.4 }, ColumnHeight = columnHeight, Style = "Tapered", Color = cream, StepX = -4 })
	A.Door(L, at(-4, 1.2, front), 3.2, 6.4, rgb(150, 92, 50), { Glass = true, Trim = cream })
	local win = { Grid = true, Crown = true, Trim = cream }
	for _, x in { -10, 2.4, 9 } do
		A.Window(L, at(x, 5.6, front), 3.4, 4.2, win)
	end
	A.Window(L, at(-W / 2, 5.6, -5) * Face.Left, 3, 4.2, win)

	A.Garage(L, at(19, 0, 3), 12, 16, 9, green, roof, "Siding", rng, cream)
	return {
		DoorX = -4,
		StepsZ = front - porchDepth - 0.9,
		FenceZ = -18.8,
		LotLeft = -15.5,
		LotRight = 25.5,
		Garage = { X = 19, Width = 10, FrontZ = -5 },
		Garden = {
			{ "Bed", -12, -6.4, -17.2, { "Daisy", "Wildflower" } },
			{ "Bed", -1.6, 8, -17.2, { "Tulip", "Daisy" } },
			{ "Flower", "Sunflower", 13.5, -6.6 },
			{ "Flower", "Sunflower", 13.5, -7.8 },
			{ "Flower", "Sunflower", 13.5, -9.0 },
			{ "Bush", "Leafy", 9.8, -17.4, 0.8 },
			{ "Bush", "Leafy", -13.6, -17.4, 0.8 },
		},
	}
end

Houses.Designs = { "Family", "Cottage", "Colonial", "GrandmaPink", "Victorian", "Bungalow" }

------------------------------------------------------------------------------------------------------- yard

-- Front yard: picket fence across the lot (open at the path and the driveway), stepping stones, driveway with
-- joints and a parked car, mailbox at the fence, the design's garden and decorations, grass at the gate.
local function buildYard(parent: Instance, cars: Instance, garden: Vegetation.Layers, cframe: CFrame, info: YardInfo, rng: Random)
	local function spot(x: number, z: number): CFrame
		return cframe * CFrame.new(x, 0, z)
	end
	local fz = info.FenceZ

	local gaps = { { info.DoorX - 1.6, info.DoorX + 1.6 } }
	local garage = info.Garage
	if garage then
		table.insert(gaps, { garage.X - garage.Width / 2 - 0.5, garage.X + garage.Width / 2 + 0.5 })
	end
	table.sort(gaps, function(a, b)
		return a[1] < b[1]
	end)
	local function run(x1: number, x2: number)
		if x2 - x1 < 1 then
			return
		end
		Props.PicketFence(parent, spot(x1, fz).Position, spot(x2, fz).Position, 2.4, 2.6, C.Trim)
		Props.FencePost(parent, spot(x1, fz).Position, 3.2, C.Trim)
		Props.FencePost(parent, spot(x2, fz).Position, 3.2, C.Trim)
	end
	local x = info.LotLeft
	for _, gap in gaps do
		run(x, gap[1])
		x = math.max(x, gap[2])
	end
	run(x, info.LotRight)

	local z = info.StepsZ - 0.9
	while z > fz + 0.5 do
		local stone = spot(info.DoorX + rng:NextNumber(-0.25, 0.25), z) * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0)
		K.Block(parent, Vector3.new(2.2, 0.15, 1.1), stone, C.Stone, true)
		z -= 1.7
	end

	if garage then
		local far = fz - 1.5
		local length = garage.FrontZ - far
		K.Block(parent, Vector3.new(garage.Width, 0.2, length), spot(garage.X, (garage.FrontZ + far) / 2) * CFrame.new(0, 0.1, 0), C.Sidewalk, true)
		for jz = garage.FrontZ - 4, far + 1, -4 do
			K.Block(parent, Vector3.new(garage.Width, 0.04, 0.15), spot(garage.X, jz) * CFrame.new(0, 0.22, 0), C.SidewalkJoint, true)
		end
		local kind = if rng:NextNumber() < 0.4 then "Pickup" else nil
		Props.Car(cars, spot(garage.X, garage.FrontZ - 6.5) * CFrame.Angles(0, math.pi, 0), C.Cars[rng:NextInteger(1, #C.Cars)], kind)
	end

	local mailColors = { Color3.fromRGB(220, 50, 45), C.Roofs[1], C.MetalDark }
	Props.Mailbox(parent, spot(info.DoorX + 2.6, fz - 1), mailColors[rng:NextInteger(1, #mailColors)])
	for _, plant in (info.Garden or {}) :: { { any } } do
		local what = plant[1]
		if what == "Bush" then
			Vegetation.Bush(garden, plant[2], spot(plant[3], plant[4]).Position, rng, plant[5])
		elseif what == "Tree" then
			Vegetation.Tree(garden, plant[2], spot(plant[3], plant[4]).Position, rng, plant[5])
		elseif what == "Flower" then
			Vegetation.Flower(garden, plant[2], spot(plant[3], plant[4]).Position, rng, nil, cframe.LookVector)
		elseif what == "Bed" then
			Vegetation.Bed(garden, spot(plant[2], plant[4]).Position, spot(plant[3], plant[4]).Position, plant[5], rng)
		elseif what == "Row" then
			for rowX = plant[3], plant[4] + 0.01, plant[6] do
				Vegetation.Bush(garden, plant[2], spot(rowX, plant[5]).Position, rng, plant[7])
			end
		end
	end
	if Config.Comic.GrassTufts then
		for _, gateX in { info.DoorX - 2.3, info.DoorX + 2.3 } do
			Vegetation.Grass(garden, spot(gateX, fz + 0.7).Position, rng, 0.8)
		end
	end
	if info.Decor then
		info.Decor(parent, spot)
	end
end

-- Builds one house of `design` at `cframe` (ground center of the main box, LookVector = its front). Walls,
-- roofs and details go to their own outline groups (one sub-Model per house in each).
function Houses.Build(groups: { [string]: Model }, cframe: CFrame, design: string, rng: Random, name: string)
	local function sub(group: Instance): Model
		local model = K.Model(name)
		model.Parent = group
		return model
	end
	local layers = { Walls = sub(groups.HouseWalls), Roofs = sub(groups.HouseRoofs), Details = sub(groups.HouseDetails) }
	local info = DESIGNS[design](layers, cframe, rng)
	buildYard(sub(groups.Yards), groups.Cars, Vegetation.LayersFrom(groups), cframe, info, rng)
end

return Houses
