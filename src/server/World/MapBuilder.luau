--!nonstrict
-- Builds "Grandma's Retirement Neighborhood" in the comic-book style at server start, no external assets.
-- Layout: a perfectly square park with a fountain inside a square ring road ("Bingo Blvd"); from the middle of
-- each side a street runs out across the arena's lawn to a square perimeter street ("Slipper Ave") just outside
-- the arena fence, which the houses, the community buildings (north side: town hall, coffee shop, retirement
-- home, grocery, weapon shop, gas station) and their driveways face. A picket fence (closed by ROAD CLOSED
-- barricades where the streets cross it) and invisible walls close the arena at Config.Map.WallDistance.
-- Enemies spawn at 8 marked points just inside the fence. Everything inside the arena is low, small and
-- round-ish, because enemy AI walks in straight lines (obstacles are circles, see GetObstacles): one circle per
-- prop, never a chain of overlapping circles (the notch between two traps grandmas), gaps wider than a grandma.
-- Props go into outline-group Models (ComicKit.OutlineGroup): each group gets one ink outline on the client.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local ComicKit = require(script.Parent.ComicKit)
local Fences = require(script.Parent.Fences)
local GrandmaProps = require(script.Parent.GrandmaProps)
local Buildings = require(script.Parent.Buildings)
local Houses = require(script.Parent.Houses)
local ParkProps = require(script.Parent.ParkProps)
local PropLibrary = require(script.Parent.PropLibrary)
local StreetProps = require(script.Parent.StreetProps)
local Vegetation = require(script.Parent.Vegetation)
local Streets = require(script.Parent.Streets)
local Vehicles = require(script.Parent.Vehicles)
local YardProps = require(script.Parent.YardProps)

local K = ComicKit
local C = ComicKit.Colors

local MapBuilder = {}

local spawnPositions: { Vector3 } = {}

-- Solid things grandmas must walk around, as circles on the ground (EnemyService pushes them out).
export type Obstacle = { Position: Vector3, Radius: number }
local obstacles: { Obstacle } = {}

local function addObstacle(position: Vector3, radius: number)
	local limit = Config.Map.WallDistance
	if math.abs(position.X) > limit or math.abs(position.Z) > limit then
		return -- outside the arena: enemies never get there
	end
	table.insert(obstacles, { Position = Vector3.new(position.X, 0, position.Z), Radius = radius })
end
local rng = Random.new(1337) -- fixed seed: same map every server

local RING = 75 -- ring road center line, studs from the map center
local ROAD_WIDTH = 16
local WALK = 4 -- sidewalk width
local SPUR = 14 -- width of the streets from the ring road out to the perimeter street
local OUTER = Config.Map.WallDistance + 11 -- perimeter street center line (outside the arena fence)
local OUTER_WIDTH = 14
local HOUSE_ROW = Config.Map.WallDistance + 42 -- house centers
local BILLBOARD = OUTER + 19 -- the corner billboards stand at (+-BILLBOARD, +-BILLBOARD)
local GAS_STATION = OUTER + 34 -- the gas station lot center is (GAS_STATION, -GAS_STATION)
local NAMES = { Ring = "BINGO BLVD", Outer = "SLIPPER AVE", Spurs = { "DENTURE DR", "GRANNY LN", "KNITTING WAY", "PRUNE ST" } }
local SIDES = { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }
local CORNERS = { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Vegetation outline layers (set in Build).
local garden: Vegetation.Layers

-- Tree / bush whose trunk or footprint is an enemy obstacle (ignored outside the arena).
local function tree(kind: string, position: Vector3, scale: number?)
	addObstacle(position, Vegetation.Tree(garden, kind, position, rng, scale))
end

local function bush(kind: string, position: Vector3, scale: number?)
	addObstacle(position, Vegetation.Bush(garden, kind, position, rng, scale))
end

-- A ring of grass tufts (decoration only, skipped when Config.Comic.SmallDetails is off).
local function tufts(center: Vector3, radius: number, count: number)
	if not Config.Comic.SmallDetails then
		return
	end
	for i = 1, count do
		local angle = i * math.pi * 2 / count + 0.4
		Vegetation.Grass(garden, center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), rng)
	end
end

-- Vehicle outline layers (set in Build).
local vehicles: Vehicles.Layers

-- Parked car: one circle over most of its length keeps grandmas off it. (Two circles side by side leave a
-- notch between them where a grandma walking straight at the car's flank gets stuck.)
local function car(kind: string, cframe: CFrame)
	Vehicles.Build(vehicles, kind, cframe)
	local spec = Vehicles.Specs[kind]
	addObstacle(cframe.Position, math.max(spec.W / 2 + 0.3, spec.L * 0.45))
end

-- Outward normal and along-direction of one side of a square street. Side i's +tan end meets the next side.
local function sideFrame(side: { number }): (Vector3, Vector3)
	local n = Vector3.new(side[1], 0, side[2])
	return n, Vector3.new(-n.Z, 0, n.X)
end

-- Square street around the center at distance r, `w` wide, with sidewalks on both sides: straight road between
-- corner squares (inked outer edges, a sidewalk fillet rounding the outer corner), chamfered inner corners,
-- optional gaps at the side middles where the spur streets meet it (o.OuterGap / o.InnerGap), crosswalk ramps
-- (o.InnerRamps, tan positions) and driveway aprons (o.Aprons[side index] = { { tan, width } }).
local function squareStreet(L: Streets.Layers, r: number, w: number, center: string, o: { [string]: any })
	local h = w / 2
	local gap = SPUR / 2
	for i, side in SIDES do
		local n, tan = sideFrame(side)
		Streets.Road(L, n * r - tan * (r - h), n * r + tan * (r - h), w, rng, { Center = center })
		local corner = n * r + tan * r
		K.Block(L.Road, Vector3.new(w, Streets.RoadHeight, w), CFrame.new(corner + Vector3.new(0, Streets.RoadHeight / 2, 0)), C.Road)
		for _, edge in { { n, tan }, { tan, n } } do
			local p = corner + edge[1] * (h - 0.15) + Vector3.new(0, Streets.RoadHeight + 0.015, 0)
			K.Block(L.Road, Vector3.new(0.3, 0.03, w), CFrame.lookAt(p, p + edge[2]), C.Ink, true)
		end
		Streets.Fillet(L, corner + n * h + tan * h, -n, -tan, 4)

		-- outer sidewalk: covers its +tan corner square; split around a spur
		local outerN = r + h + WALK / 2
		local function outerWalk(t1: number, t2: number)
			local aprons = {}
			for _, apron in (o.Aprons and o.Aprons[i]) or {} do
				if apron[1] > t1 + apron[2] / 2 and apron[1] < t2 - apron[2] / 2 then
					table.insert(aprons, { apron[1] - t1, apron[2] })
				end
			end
			Streets.Walk(L, n * outerN + tan * t1, n * outerN + tan * t2, WALK, 1, rng, { Aprons = aprons })
		end
		if o.OuterGap then
			outerWalk(-(r + h), -(gap + WALK))
			outerWalk(gap + WALK, r + h + WALK)
			for _, s in { -1, 1 } do
				Streets.Corner(L, n * (r + h + WALK) + tan * s * (gap + WALK), -n, -tan * s, WALK)
			end
		else
			outerWalk(-(r + h), r + h + WALK)
		end

		-- inner sidewalk: ends before the corners (chamfered corner pieces); split around a spur
		local innerN = r - h - WALK / 2
		local reach = r - h - WALK
		local function innerWalk(t1: number, t2: number)
			local ramps = {}
			for _, t in o.InnerRamps or {} do
				if t > t1 + 1.5 and t < t2 - 1.5 then
					table.insert(ramps, t - t1)
				end
			end
			Streets.Walk(L, n * innerN + tan * t1, n * innerN + tan * t2, WALK, -1, rng, { Ramps = ramps })
		end
		if o.InnerGap then
			innerWalk(-reach, -(gap + WALK))
			innerWalk(gap + WALK, reach)
			for _, s in { -1, 1 } do
				Streets.Corner(L, n * (r - h - WALK) + tan * s * (gap + WALK), n, -tan * s, WALK)
			end
		else
			innerWalk(-reach, reach)
		end
		Streets.Corner(L, n * reach + tan * reach, n, tan, WALK)
	end
end

-- A spur street from the ring road's outer edge out to the perimeter street, with sidewalks, a crosswalk near
-- the ring road and curb ramps.
local function spurStreet(L: Streets.Layers, side: { number })
	local n, tan = sideFrame(side)
	local start, finish = RING + ROAD_WIDTH / 2, OUTER - OUTER_WIDTH / 2
	Streets.Road(L, n * start, n * finish, SPUR, rng, { Center = "Double" })
	local crossing = WALK + 3
	for _, s in { -1, 1 } do
		local walkStart, walkEnd = start + WALK, finish - WALK
		local x = tan * s * (SPUR / 2 + WALK / 2)
		Streets.Walk(L, n * walkStart + x, n * walkEnd + x, WALK, -s, rng, { Ramps = { crossing - WALK } })
	end
	Streets.Crosswalk(L, n * (start + crossing), n, SPUR)
end

local function buildGround(map: Folder)
	local size = Config.Map.GroundSize
	K.Block(map, Vector3.new(size, 2, size), CFrame.new(0, -1, 0), C.Grass).Name = "Ground"

	-- mowed stripes on the square park lawn (no outline: flat ground)
	local park = RING - ROAD_WIDTH / 2 - WALK
	local stripe = park * 2 / 9
	for i = 0, 8, 2 do
		K.Block(map, Vector3.new(stripe, 0.04, park * 2), CFrame.new(-park + stripe * (i + 0.5), 0.02, 0), C.GrassLight, true)
	end
end

-- All streets: the ring road around the park, the four spurs and the perimeter street with the driveways.
local function buildStreets(L: Streets.Layers, aprons: { { { number } } })
	local ramps = { -(SPUR / 2 + WALK / 2), SPUR / 2 + WALK / 2 }
	squareStreet(L, RING, ROAD_WIDTH, "Dashed", { OuterGap = true, InnerRamps = ramps })
	for _, side in SIDES do
		local n, tan = sideFrame(side)
		for _, t in ramps do
			Streets.Crosswalk(L, n * RING + tan * t, tan, ROAD_WIDTH)
		end
		spurStreet(L, side)
	end
	squareStreet(L, OUTER, OUTER_WIDTH, "Dashed", { InnerGap = true, Aprons = aprons })
end

-- The central park (a perfect square inside the ring road's inner sidewalks): a round fountain plaza, four wide
-- paths to the sidewalks and four landscaped sections between them: playground (+X +Z), picnic area (-X +Z),
-- garden with seating (-X -Z) and an open recreation lawn (+X -Z). Every piece of furniture is a small round
-- obstacle with wide gaps between; hedges are short separate pieces, never closed rings.
local function buildPark(groups: { [string]: Model })
	local park, play = groups.Park, groups.Roads

	-- plaza: paved disc with an ink edge and a decorative stone ring, the fountain, benches, bins and lamps
	K.Disc(play, 45.2, 0.16, Vector3.zero, K.Dark(C.Stone), true)
	K.Disc(play, 44, 0.2, Vector3.zero, C.Path)
	K.Disc(play, 29.2, 0.22, Vector3.zero, K.Dark(C.Path), true)
	K.Disc(play, 28, 0.24, Vector3.zero, C.Path, true)
	for i = 0, 7 do
		local joint = CFrame.Angles(0, i * math.pi / 4 + math.pi / 8, 0) * CFrame.new(0, 0.21, -18)
		K.Ink(play, Vector3.new(0.1, 0.03, 7.6), joint)
	end
	ParkProps.Fountain(park, Vector3.new(0, 0.2, 0))
	addObstacle(Vector3.zero, 10.6)
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		-- lamp, bench and bin in one row along the plaza ring, covered by ONE obstacle circle (a chain of
		-- circles leaves notches); its center sits a little outward so the ring path round the fountain stays
		-- wider than a grandma
		local seat = dir * 17 + Vector3.new(0, 0.2, 0)
		local facing = CFrame.lookAt(seat, Vector3.new(0, 0.2, 0))
		StreetProps.Bench(groups.StreetProps, facing)
		StreetProps.TrashCan(groups.StreetProps, (facing * CFrame.new(3.6, 0, 0)).Position)
		StreetProps.Lamp(groups.StreetProps, (facing * CFrame.new(-3.4, 0, 0)).Position)
		addObstacle(dir * 18, 4.3)
	end

	-- the four wide paths from the plaza to the sidewalks, with stone edging and a rustic fence piece on each
	-- side where they meet the sidewalk (short, backed by obstacles)
	local edge = RING - ROAD_WIDTH / 2 - WALK
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local across = Vector3.new(dir.Z, 0, -dir.X)
		local from = 21
		local mid = dir * ((from + edge) / 2)
		local path = CFrame.lookAt(mid, mid + dir)
		K.Block(play, Vector3.new(10, 0.2, edge - from), path * CFrame.new(0, 0.1, 0), C.Path).Name = "ParkPath"
		for _, s in { -1, 1 } do
			K.Block(play, Vector3.new(0.4, 0.3, edge - from), path * CFrame.new(s * 5.2, 0.15, 0), C.Stone, true)
			local a, b = dir * (edge - 1.4) + across * s * 7.5, dir * (edge - 1.4) + across * s * 14.5
			Fences.Park(groups.Fence, a, b)
			addObstacle((a + b) / 2, 3.6) -- one circle: no notch for grandmas to get stuck in
		end
	end

	-- 1. playground (+X +Z): rubber mat, two slides, swings, climbing frame, sandbox, seesaw, spring riders
	local pg = Vector3.new(34, 0, 34)
	K.Block(play, Vector3.new(36.6, 0.06, 36.6), CFrame.new(pg + Vector3.new(0, 0.03, 0)), C.Ink, true)
	K.Block(play, Vector3.new(36, 0.08, 36), CFrame.new(pg + Vector3.new(0, 0.04, 0)), Color3.fromRGB(225, 110, 80), true)
	local function item(offset: Vector3, radius: number)
		addObstacle(pg + offset, radius)
	end
	-- one round obstacle per piece (never a chain of circles: the notch between two circles traps grandmas),
	-- at least a grandma's width apart; the sandbox and the spring riders are walk-through
	ParkProps.Slide(park, CFrame.new(pg + Vector3.new(-10, 0.08, 12)))
	item(Vector3.new(-10, 0, 8.75), 5.4)
	ParkProps.CurvySlide(park, CFrame.new(pg + Vector3.new(10, 0.08, 12)))
	item(Vector3.new(8.8, 0, 10), 4.0)
	ParkProps.SwingSet(park, CFrame.new(pg + Vector3.new(0, 0.08, -12)))
	item(Vector3.new(0, 0, -12), 7.0)
	ParkProps.ClimbingFrame(park, CFrame.new(pg + Vector3.new(11, 0.08, -1)))
	item(Vector3.new(11, 0, -1), 4.2)
	ParkProps.Sandbox(park, CFrame.new(pg + Vector3.new(-11, 0.08, -3)))
	ParkProps.Seesaw(park, CFrame.new(pg + Vector3.new(0, 0.08, 2)))
	item(Vector3.new(0, 0, 2), 3.6)
	ParkProps.SpringRider(park, CFrame.lookAt(pg + Vector3.new(-4, 0.08, -5), pg + Vector3.new(-4, 0.08, -10)), "Duck")
	ParkProps.SpringRider(park, CFrame.lookAt(pg + Vector3.new(4, 0.08, -5), pg + Vector3.new(4, 0.08, -10)), "Horse")
	for _, spot in { { Vector3.new(0, 0, 20), Vector3.new(0, 0, 10) }, { Vector3.new(21.5, 0, 0), Vector3.new(10, 0, 0) } } do
		StreetProps.Bench(groups.StreetProps, CFrame.lookAt(pg + spot[1], pg + spot[2]))
		item(spot[1], 2.8)
	end
	StreetProps.TrashCan(groups.StreetProps, pg + Vector3.new(6.5, 0, 20))
	item(Vector3.new(6.5, 0, 20), 1)
	-- bike rack with two bikes on the lawn beside the south path (bikes point at the path)
	local rack = CFrame.new(8.8, 0, 30) * CFrame.Angles(0, math.pi / 2, 0)
	StreetProps.BikeRack(park, rack)
	StreetProps.Bicycle(park, rack * CFrame.new(-0.75, 0, 0), Color3.fromRGB(70, 190, 180))
	StreetProps.Bicycle(park, rack * CFrame.new(0.75, 0, 0), Color3.fromRGB(255, 120, 170))
	addObstacle(rack.Position, 2.4)
	tree("Oak", Vector3.new(56, 0, 56))
	tufts(Vector3.new(56, 0, 56), 2.6, 3)

	-- 2. picnic area (-X +Z): pergola over two tables, more tables, a grill, planters, stepping-stone path, beds
	local pc = Vector3.new(-36, 0, 34)
	ParkProps.Pergola(park, CFrame.new(pc), 12, 9, rng)
	for _, x in { -3.5, 3.5 } do
		ParkProps.PicnicTable(park, CFrame.new(pc + Vector3.new(x, 0, 0)))
	end
	addObstacle(pc, 7.2) -- the pergola with its tables is one round obstacle (no pockets between posts)
	for _, spot in { { Vector3.new(-24, 0, 51), 0.3 }, { Vector3.new(-51, 0, 51), -0.4 }, { Vector3.new(-52, 0, 18), 0.2 } } do
		ParkProps.PicnicTable(park, CFrame.new(spot[1]) * CFrame.Angles(0, spot[2], 0))
		addObstacle(spot[1], 2.8)
	end
	ParkProps.Grill(park, CFrame.new(-21.5, 0, 45.5))
	addObstacle(Vector3.new(-21.5, 0, 45.5), 0.9)
	for _, offset in { Vector3.new(-10, 0, -7.5), Vector3.new(10, 0, -7.5), Vector3.new(-10, 0, 7.5), Vector3.new(10, 0, 7.5) } do
		local at = pc + offset
		local soil = StreetProps.Planter(groups.StreetProps, CFrame.new(at), 3.2)
		for k = -1, 1 do
			Vegetation.Flower(garden, if k == 0 then "Rose" else "Daisy", (soil * CFrame.new(k * 0.95, 0, 0)).Position, rng)
		end
		addObstacle(at, 1.7)
	end
	for x = -7, -27, -2 do
		Streets.Stone(play, Vector3.new(x, 0.02, 34 + (x % 4 - 1) * 0.3), rng, 1.4)
	end
	Vegetation.Bed(garden, Vector3.new(-60, 0, 22), Vector3.new(-60, 0, 46), { "Tulip", "Daisy" }, rng)
	StreetProps.TrashCan(groups.StreetProps, Vector3.new(-17, 0, 47.5))
	addObstacle(Vector3.new(-17, 0, 47.5), 1)
	tree("Maple", Vector3.new(-56, 0, 56))
	tufts(Vector3.new(-56, 0, 56), 2.6, 3)

	-- 3. garden and seating (-X -Z): grandma statue in a round flower bed with four benches, four short hedges on the diagonals
	-- (open between them), rose arches over the stepping-stone paths, cherry trees, flower beds
	local gd = Vector3.new(-36, 0, -36)
	Vegetation.FlowerBed(garden, gd, rng, true)
	GrandmaProps.GrandmaStatue(park, CFrame.lookAt(gd, Vector3.zero))
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		StreetProps.Bench(groups.StreetProps, CFrame.lookAt(gd + dir * 6.5, gd))
	end
	addObstacle(gd, 7.6) -- bed and benches as one round obstacle: no notches between the benches
	for i = 0, 3 do
		local diag = Vector3.new(math.cos(i * math.pi / 2 + math.pi / 4), 0, math.sin(i * math.pi / 2 + math.pi / 4))
		local at = gd + diag * 14.5 -- far enough from the bench ring for a scooter grandma to pass between
		Vegetation.TrimmedHedge(garden, CFrame.lookAt(at, gd), 6, rng, 0.8)
		addObstacle(at, 2.7) -- one circle per hedge: two side by side would leave a notch
	end
	for x = -7, -27, -2 do
		Streets.Stone(play, Vector3.new(x, 0.02, -36), rng, 1.3)
	end
	for z = -7, -27, -2 do
		Streets.Stone(play, Vector3.new(-36, 0.02, z), rng, 1.3)
	end
	ParkProps.RoseArch(park, CFrame.new(-12, 0, -36) * CFrame.Angles(0, math.pi / 2, 0), rng)
	ParkProps.RoseArch(park, CFrame.new(-36, 0, -12), rng)
	for _, post in { Vector3.new(-12, 0, -38.2), Vector3.new(-12, 0, -33.8), Vector3.new(-38.2, 0, -12), Vector3.new(-33.8, 0, -12) } do
		addObstacle(post, 0.5)
	end
	for _, spot in { Vector3.new(-54, 0, -20), Vector3.new(-20, 0, -54) } do
		tree("Cherry", spot)
		tufts(spot, 2.4, 3)
	end
	Vegetation.Bed(garden, Vector3.new(-24, 0, -49), Vector3.new(-24, 0, -60), { "Rose", "Tulip" }, rng)
	Vegetation.Bed(garden, Vector3.new(-49, 0, -24), Vector3.new(-60, 0, -24), { "Tulip", "Daisy" }, rng)
	tree("Oak", Vector3.new(-56, 0, -56))
	tufts(Vector3.new(-56, 0, -56), 2.6, 3)

	-- 4. open recreation lawn (+X -Z): two small soccer goals, a picnic blanket, a bird bath, a sundial, rocks,
	-- bushes and a tree at the edges
	ParkProps.SoccerGoal(park, CFrame.lookAt(Vector3.new(14, 0, -40), Vector3.new(30, 0, -40)))
	ParkProps.SoccerGoal(park, CFrame.lookAt(Vector3.new(58, 0, -40), Vector3.new(30, 0, -40)))
	for _, x in { 14, 58 } do
		addObstacle(Vector3.new(x, 0, -43), 0.5)
		addObstacle(Vector3.new(x, 0, -37), 0.5)
	end
	ParkProps.PicnicBlanket(park, CFrame.new(40, 0, -54) * CFrame.Angles(0, 0.3, 0))
	ParkProps.BirdBath(park, CFrame.new(24, 0, -56))
	addObstacle(Vector3.new(24, 0, -56), 1.3)
	ParkProps.Sundial(park, CFrame.new(50, 0, -20))
	addObstacle(Vector3.new(50, 0, -20), 1.0)
	StreetProps.Rocks(park, Vector3.new(30, 0, -24), rng, 3)
	bush("Round", Vector3.new(60, 0, -28))
	bush("Flowering", Vector3.new(28, 0, -60))
	tufts(Vector3.new(60, 0, -28), 2.2, 2)
	tree("Roadside", Vector3.new(56, 0, -56))
	tufts(Vector3.new(56, 0, -56), 2, 3)
end

-- Ring road furniture: lamps at the inner corners and along the outer side, hydrants, and the curb-parked cars.
local function buildRingProps(groups: { [string]: Model })
	-- lamps at the inner corners of the ring road and along its outer side, hydrants by the outer sidewalk
	for _, corner in CORNERS do
		for _, pos in { Vector3.new(corner[1] * 64, 0, corner[2] * 64), Vector3.new(corner[1] * 87, 0, corner[2] * 40), Vector3.new(corner[1] * 40, 0, corner[2] * 87) } do
			StreetProps.Lamp(groups.StreetProps, pos)
			addObstacle(pos, 0.8)
		end
		local hydrant = Vector3.new(corner[1] * 87, 0, corner[2] * 58)
		StreetProps.Hydrant(groups.StreetProps, CFrame.lookAt(hydrant, Vector3.new(0, 0, hydrant.Z)))
		addObstacle(hydrant, 0.9)
	end
	-- one car parked at the outer curb of each side of the ring road (the minivan by the park), clear of the
	-- crosswalks and lamps
	for i, side in SIDES do
		local t = if i % 2 == 0 then 35 else -35
		local along = if side[1] == 0 then Vector3.xAxis else Vector3.zAxis
		local pos = Vector3.new(side[1], 0, side[2]) * (RING + 4.5) + along * t
		car(({ "Sedan", "Minivan", "Hatchback", "Wagon" })[i], CFrame.lookAt(pos, pos + along))
	end
end

local function buildBoundary(map: Folder, fence: Model)
	local boundary = folder(map, "Boundary")
	local d = Config.Map.WallDistance
	local length = d * 2
	local posts = {}

	for _, side in SIDES do
		local horizontal = side[1] == 0
		local center = Vector3.new(side[1] * d, 0, side[2] * d)

		-- invisible wall: keeps players in, lets bullets through
		local wallSize = if horizontal then Vector3.new(length, 40, 2) else Vector3.new(2, 40, length)
		local wall = K.Block(boundary, wallSize, CFrame.new(center + Vector3.new(0, 20, 0)), C.Trim)
		wall.Name = "InvisibleWall"
		wall.Transparency = 1
		wall.CanQuery = false
		wall.CastShadow = false

		-- white picket fence between capped posts (corner posts only once), open where the spur street and its
		-- sidewalks cross; a ROAD CLOSED barricade fills that gap
		local along = if horizontal then Vector3.xAxis else Vector3.zAxis
		local gap = SPUR / 2 + WALK
		local sections = math.round(Config.Map.FenceSections / 2)
		for _, run in { { -d, -gap }, { gap, d } } do
			local step = (run[2] - run[1]) / sections
			for i = 0, sections do
				local at = center + along * (run[1] + i * step)
				if i < sections then
					Fences.Picket(fence, at, at + along * step, 4, 3.4)
				end
				local key = string.format("%d,%d", math.round(at.X), math.round(at.Z))
				if not posts[key] then
					posts[key] = true
					Fences.Post(fence, at, 4.4, C.Trim)
				end
			end
		end
		Fences.Barricade(fence, center - along * gap, center + along * gap, -Vector3.new(side[1], 0, side[2]))
	end
end

local function buildSpawns(map: Folder)
	local spawns = folder(map, "EnemySpawns")
	local s = Config.Map.SpawnDistance
	table.clear(spawnPositions)
	for _, p in { { -1, -1 }, { 0, -1 }, { 1, -1 }, { -1, 0 }, { 1, 0 }, { -1, 1 }, { 0, 1 }, { 1, 1 } } do
		local pos = Vector3.new(p[1] * s, 0, p[2] * s)
		table.insert(spawnPositions, pos)
		-- red circle on the ground marks the spawn area
		local mark = K.Disc(spawns, 14, 0.15, pos, C.SpawnMark, true)
		mark.Name = "SpawnMark"
		mark.Material = Enum.Material.Neon
		mark.Transparency = 0.45
	end
end

-- Houses, the retirement home with its shuttle, and the ring of trees behind them. Returns the driveway aprons
-- for the perimeter street's outer sidewalk, per side ({ tan position, width }).
local function buildScenery(groups: { [string]: Model }): { { { number } } }
	local d = Config.Map.WallDistance
	local homeAt = Vector3.new(0, 0, -d - 55)
	-- houses along three sides, square to the perimeter street and facing the arena; the community buildings own
	-- the north side
	local taken = { { Position = homeAt, Radius = 50 } }
	-- buildings that hide whatever stands right behind them from the arena: { center, outward normal, half width }
	local blockers = { { homeAt, Vector3.new(0, 0, -1), 40 } }
	local aprons = { {}, {}, {}, {} }
	local curbZ = -(HOUSE_ROW - (OUTER + OUTER_WIDTH / 2 + WALK)) -- the sidewalk's yard-side edge, in house space
	local index = 0
	for k, t in { -110, -66, -22, 22, 66, 110 } do
		for s, sideIndex in { 2, 3, 4 } do -- south, west, east (SIDES order)
			index += 1
			local n, tan = sideFrame(SIDES[sideIndex])
			local position = n * HOUSE_ROW + tan * t
			local design = Houses.Designs[(k + s * 2) % #Houses.Designs + 1] -- every street shows all six designs
			local house = CFrame.lookAt(position, position - n)
			local info = Houses.Build(groups, house, design, rng, design .. index, curbZ)
			if info.Garage then
				table.insert(aprons[sideIndex], { (house * Vector3.new(info.Garage.X, 0, 0)):Dot(tan), info.Garage.Width })
			end
			table.insert(taken, { Position = position, Radius = 30 })
			table.insert(blockers, { position, n, 13 })
		end
	end
	-- street trees on the lot lines between the houses, just inside the front fences (a tree-lined street),
	-- moved off any driveway
	for _, sideIndex in { 2, 3, 4 } do
		local n, tan = sideFrame(SIDES[sideIndex])
		for _, t in { -132, -88, -44, 0, 44, 88, 132 } do
			for _, shift in { 0, 5, -5 } do
				local clear = true
				for _, apron in aprons[sideIndex] do
					if math.abs(t + shift - apron[1]) < apron[2] / 2 + 3 then
						clear = false
					end
				end
				if clear then
					Vegetation.Tree(garden, "Roadside", n * (HOUSE_ROW - 16.4) + tan * (t + shift), rng, rng:NextNumber(0.95, 1.1))
					break
				end
			end
		end
	end
	-- the north side is the town's main street: the retirement home in the middle, the town hall and the coffee
	-- shop to the west, the grocery and the weapon shop to the east, the gas station on the north-east corner
	-- lot; the shuttle waits at the curb by the grocery
	local walkEdge = OUTER + OUTER_WIDTH / 2 + WALK
	for _, lot in { { "RetirementHome", 0 }, { "TownHall", -82 }, { "CoffeeShop", -124 }, { "Grocery", 84 }, { "WeaponShop", 124 } } do
		local curb = Vector3.new(lot[2], 0, -walkEdge)
		Buildings.Build(groups, lot[1], CFrame.lookAt(curb, Vector3.new(lot[2], 0, 0)), rng)
	end
	local station = Vector3.new(GAS_STATION, 0, -GAS_STATION)
	Buildings.Build(groups, "GasStation", CFrame.lookAt(station, Vector3.new(OUTER, 0, -OUTER)), rng)
	for _, spot in { { -82, -187, 24 }, { -124, -178, 14 }, { 84, -181, 20 }, { 124, -181, 14 }, { GAS_STATION, -GAS_STATION, 32 } } do
		table.insert(taken, { Position = Vector3.new(spot[1], 0, spot[2]), Radius = spot[3] })
		if spot[1] < 150 then
			table.insert(blockers, { Vector3.new(spot[1], 0, spot[2]), Vector3.new(0, 0, -1), spot[3] * 0.6 })
		end
	end
	Vehicles.Build(vehicles, "Shuttle", CFrame.new(60, 0, -(OUTER + 3.2)) * CFrame.Angles(0, math.pi / 2, 0))

	-- two rings of trees behind the houses (the town's tree cover and a wall of green at the map edge): even
	-- spacing with a little jitter, kinds in a repeating pattern, never inside a building or on the perimeter
	-- street (near the diagonals the circles cut inside its corners). Mesh trees (Oak, Roadside: 4 parts each)
	-- are planted everywhere; the part-built kinds only where the arena can see them (not straight behind a house)
	local ring = { "Oak", "Roadside", "Evergreen", "Oak", "Roadside", "Maple", "Oak", "Roadside", "Cherry" }
	local meshKinds = { Oak = true, Roadside = true }
	local planted = 0
	for i = 0, 107 do
		local outer = i >= 52
		local count = if outer then 56 else 52
		local angle = (if outer then (i - 52) + 0.5 else i) * math.pi * 2 / count + rng:NextNumber(-0.03, 0.03)
		local radius = (if outer then d + 84 else d + 64) + (i % 3) * 3 + rng:NextNumber(-1.5, 1.5)
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local kind = ring[planted % #ring + 1]
		local free = math.max(math.abs(position.X), math.abs(position.Z)) > OUTER + OUTER_WIDTH / 2 + WALK + 3
		for _, blocker in blockers do
			-- straight behind a house its roof hides a tree from the whole arena: no part-built tree there
			local offset = position - blocker[1]
			local n = blocker[2]
			if offset:Dot(n) > 0 and math.abs(offset:Dot(Vector3.new(-n.Z, 0, n.X))) < blocker[3] then
				if not meshKinds[kind] then
					kind = if i % 2 == 0 then "Oak" else "Roadside"
				end
				if offset:Dot(n) < 12 then
					free = false -- right against the back wall
				end
			end
		end
		for _, spot in taken do
			if (spot.Position - position).Magnitude < spot.Radius then
				free = false
				break
			end
		end
		if free then
			planted += 1
			Vegetation.Tree(garden, kind, position, rng, rng:NextNumber(0.9, 1.15) * (if outer then 1.15 else 1)) -- outside the arena: no obstacle
		end
	end
	-- tall street lights along the perimeter street's arena side (no driveways there)
	for i, side in SIDES do
		local n, tan = sideFrame(side)
		for _, t in { -120, -75, -30, 30, 75, 120 } do
			local at = n * (OUTER - OUTER_WIDTH / 2 - WALK / 2) + tan * t
			StreetProps.StreetLight(groups.StreetProps, CFrame.lookAt(at, at + n))
		end
		local corner = n * (OUTER - OUTER_WIDTH / 2 - WALK + 1.2) + tan * (SPUR / 2 + WALK - 0.7)
		StreetProps.StopSign(groups.StreetProps, CFrame.lookAt(corner, corner - n), { NAMES.Outer, NAMES.Spurs[i] })
	end
	return aprons
end

-- The arena's outer lawn: planting spots along the outer sidewalks, bushes and roadside trees in a regular
-- pattern between the road and the spawn circles (lanes stay open).
local function buildLawn(groups: { [string]: Model })
	local d = Config.Map.WallDistance
	local bushKinds = { "Wild", "Round", "Corner", "Flowering" }
	for s, side in SIDES do
		local out = Vector3.new(side[1], 0, side[2])
		local along = if side[1] == 0 then Vector3.xAxis else Vector3.zAxis
		for _, t in { -66, 66 } do
			local spot = out * (RING + 15) + along * t
			Vegetation.Bush(garden, "Leafy", spot, rng, 0.9)
			Vegetation.Flower(garden, "Wildflower", spot + along * 1.6, rng)
			tufts(spot - along * 1.6, 0.3, 1)
		end
		-- wooden planters with tulips along the ring road, either side of the spur
		for _, t in { -20, 20 } do
			local spot = out * (RING + 15) + along * t
			local soil = StreetProps.Planter(groups.StreetProps, CFrame.lookAt(spot, spot + out) * CFrame.Angles(0, math.pi / 2, 0), 3.2)
			for k = -1, 1 do
				Vegetation.Flower(garden, "Tulip", (soil * CFrame.new(k * 0.95, 0, 0)).Position, rng)
			end
			addObstacle(spot, 1.7)
		end
		-- at each spur: a stop sign with the street names at the ring road, a street light, a utility box
		local n, tan = sideFrame(side)
		local stop = n * (RING + ROAD_WIDTH / 2 + WALK + 1.4) - tan * (SPUR / 2 + WALK - 0.7)
		StreetProps.StopSign(groups.StreetProps, CFrame.lookAt(stop, stop + n), { NAMES.Ring, NAMES.Spurs[s] })
		addObstacle(stop, 0.5)
		local lamp = n * 112 + tan * (SPUR / 2 + WALK - 0.7)
		StreetProps.StreetLight(groups.StreetProps, CFrame.lookAt(lamp, lamp - tan))
		addObstacle(lamp, 0.7)
		local box = n * 100 + tan * (SPUR / 2 + WALK + 2.6)
		StreetProps.UtilityBox(groups.StreetProps, CFrame.lookAt(box, box - tan))
		StreetProps.Rocks(groups.Park, box + n * 2.4, rng, 2)
		addObstacle(box, 1.5)
		for k, t in { -96, -52, 52, 96 } do
			local spot = out * (d - 32) + along * t
			bush(bushKinds[(s + k) % #bushKinds + 1], spot)
			tufts(spot, 2.6, 2)
		end
		for _, t in { -74, 74 } do
			local spot = out * (d - 26) + along * t
			tree("Roadside", spot)
			tufts(spot, 1.8, 2)
		end
	end
end

-- Prop scenes from the prop library, each where it makes sense: road works on Knitting Way, newspaper boxes at
-- two ring-road corners, Grandma's cookie stall (with a customer's scooter) on the east lawn, giant knitting
-- landmarks in the four lawn corners, jersey barriers behind the ROAD CLOSED barricades, and outside the
-- arena retirement-home billboards in three map corners (the gas station has the fourth). Solid pieces inside the arena are round obstacles; cones, barriers
-- and the open manhole are decoration that grandmas walk through.
local function buildPropScenes(groups: { [string]: Model })
	local d = Config.Map.WallDistance
	local street, landmarks = groups.StreetProps, groups.Landmarks
	local road = Streets.RoadHeight

	-- road works on the south lane of Knitting Way (west spur): open manhole between two A-frame barriers,
	-- cones tapering in on both sides
	local works = Vector3.new(-106, road, 3.5)
	Streets.OpenManhole(street, works, Vector3.xAxis)
	for _, side in { -1, 1 } do
		local at = works + Vector3.new(side * 5.4, 0, 0)
		StreetProps.ConstructionBarrier(street, CFrame.lookAt(at, at + Vector3.new(side, 0, 0)), "AFrame")
	end
	for _, x in { -7.8, -2.6, 2.6, 7.8 } do
		for _, z in { -2.6, 2.6 } do
			PropLibrary.Build("TrafficCone", street, CFrame.new(works + Vector3.new(x, 0, z)), rng)
		end
	end

	-- newspaper boxes on the ring road's outer sidewalk at two corners, facing the road
	for _, corner in { { 1, 1 }, { -1, -1 } } do
		for k, z in { 50, 51.7 } do
			local at = Vector3.new(corner[1] * 86.2, Streets.WalkHeight, corner[2] * z)
			local facing = CFrame.lookAt(at, at - Vector3.new(corner[1], 0, 0))
			if k == 1 then
				StreetProps.NewspaperBox(street, facing)
			else
				StreetProps.NewspaperBox(street, facing, Color3.fromRGB(220, 60, 50), "DAILY DENTURE")
			end
		end
		addObstacle(Vector3.new(corner[1] * 86.2, 0, corner[2] * 50.85), 1.9) -- one circle for the pair
	end

	-- Grandma's cookie stall on the east lawn, facing the ring road, supply crates behind the counter, and a
	-- customer's mobility scooter parked a lane's width away (no notch between the two)
	local stallAt = Vector3.new(99.2, 0, -32)
	local stall = CFrame.lookAt(stallAt, stallAt - Vector3.xAxis)
	GrandmaProps.CookieStall(landmarks, stall)
	YardProps.Crate(landmarks, stall * CFrame.new(2.2, 0, 1.9) * CFrame.Angles(0, 0.2, 0), "FLOUR", 1.6)
	YardProps.Crate(landmarks, stall * CFrame.new(3.8, 0, 1.6), "COOKIES", 1.4)
	addObstacle(stallAt, 4.7)
	local scooter = Vector3.new(96.6, 0, -22.5)
	Vehicles.Build(vehicles, "Scooter", CFrame.lookAt(scooter, scooter + Vector3.xAxis))
	addObstacle(scooter, 1.4)

	-- giant knitting landmarks on the lawn diagonals (between the ring road and the corner spawn circles)
	local knitting = {
		{ Vector3.new(96, 0, 96), GrandmaProps.YarnColors[3] },
		{ Vector3.new(-96, 0, 96), GrandmaProps.YarnColors[1] },
		{ Vector3.new(96, 0, -96), GrandmaProps.YarnColors[4] },
	}
	for _, spot in knitting do
		GrandmaProps.YarnBall(landmarks, CFrame.lookAt(spot[1], Vector3.zero), 6, spot[2], true)
		addObstacle(spot[1], 3.2)
	end
	local needles = Vector3.new(-96, 0, -96)
	GrandmaProps.KnittingNeedles(landmarks, CFrame.lookAt(needles, Vector3.zero), GrandmaProps.YarnColors[2])
	addObstacle(needles, 3.4)

	-- jersey barriers behind the ROAD CLOSED barricades, where the spurs meet the perimeter street
	for _, side in SIDES do
		local n, tan = sideFrame(side)
		for _, s in { -1, 1 } do
			local at = n * (d + 2.4) + tan * s * 3.1 + Vector3.new(0, road, 0)
			StreetProps.ConstructionBarrier(street, CFrame.lookAt(at, at - n), "Jersey")
		end
	end

	-- retirement-home billboards in the four map corners, facing the arena over the perimeter street corners
	local slogans = { "BINGO EVERY NIGHT!", "NOW WITH EXTRA PUDDING!", "FREE SLIPPERS FOR NEW RESIDENTS!", "GRANDMA WRANGLERS WANTED!" }
	for i, corner in CORNERS do
		if corner[1] == 1 and corner[2] == -1 then
			continue -- the gas station's corner
		end
		local at = Vector3.new(corner[1], 0, corner[2]) * BILLBOARD
		GrandmaProps.RetirementBillboard(landmarks, CFrame.lookAt(at, Vector3.zero), slogans[i])
	end
end

-- Nothing outside the arena is ever touched: players stay inside the invisible walls and grandmas inside the
-- fence. Everything out there (houses, shops, yards, perimeter street) stops colliding and answering raycasts,
-- which keeps physics and hit tests lean. The ground stays solid.
local function settleOutside(map: Folder)
	local limit = Config.Map.WallDistance + 4
	for _, part in map:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "Ground" then
			local p = part.Position
			if math.abs(p.X) > limit or math.abs(p.Z) > limit then
				part.CanCollide = false
				part.CanQuery = false
			end
		end
	end
end

-- Bright, hard-shadowed daylight with punchy colors (Config.Comic.Lighting).
local function setupLighting()
	local look = Config.Comic.Lighting
	Lighting.ClockTime = look.ClockTime
	Lighting.Brightness = look.Brightness
	Lighting.OutdoorAmbient = look.OutdoorAmbient
	Lighting.Ambient = look.Ambient
	Lighting.ShadowSoftness = look.ShadowSoftness
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = look.AtmosphereDensity
	atmosphere.Haze = look.AtmosphereHaze
	atmosphere.Glare = 0
	atmosphere.Color = Color3.fromRGB(200, 225, 255)
	atmosphere.Parent = Lighting
	local grade = Lighting:FindFirstChild("ComicGrade") or Instance.new("ColorCorrectionEffect")
	grade.Name = "ComicGrade"
	grade.Saturation = look.Saturation
	grade.Contrast = look.Contrast
	grade.Parent = Lighting
end

function MapBuilder.Build(): Folder
	-- remove the default template pieces if the place still has them
	for _, name in { "Baseplate", "SpawnLocation" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local map = Instance.new("Folder")
	map.Name = "Map"

	-- outline groups: neighbors in different groups get an ink line between them
	local groups = {}
	for _, name in { "Roads", "Sidewalks", "Park", "StreetProps", "Cars", "CarDetails", "FoliageA", "FoliageB", "Wood", "Flowers", "HouseWalls", "HouseRoofs", "HouseDetails", "Yards", "Landmarks", "Fence" } do
		groups[name] = K.OutlineGroup(map, name)
	end
	-- grass blades, stems and soil stay without outlines: at a distance an outline would be all you see of them
	groups.Grass = K.Model("Grass")
	groups.Grass.Parent = map
	garden = Vegetation.LayersFrom(groups)
	vehicles = { Body = groups.Cars, Details = groups.CarDetails }

	buildGround(map)
	buildPark(groups)
	buildRingProps(groups)
	buildBoundary(map, groups.Fence)
	buildSpawns(map)
	local aprons = buildScenery(groups)
	buildStreets({ Road = groups.Roads, Walk = groups.Sidewalks }, aprons)
	buildLawn(groups)
	buildPropScenes(groups)
	settleOutside(map)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.5, 26)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Neutral = true
	spawn.Duration = 0 -- PlayerService adds its own invisible spawn shield
	spawn.Parent = map

	setupLighting()
	-- performance pass: nothing on the map uses Touched, and small pieces do not need to cast shadows
	for _, part in map:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanTouch = false
			local size = part.Size
			if math.max(size.X, size.Y, size.Z) < 3 then
				part.CastShadow = false
			end
		end
	end
	map.Parent = workspace
	return map
end

function MapBuilder.GetObstacles(): { Obstacle }
	return obstacles
end

function MapBuilder.GetSpawnPositions(): { Vector3 }
	return spawnPositions
end

-- A random point near one of the enemy spawn markers.
function MapBuilder.GetRandomSpawnPosition(): Vector3
	local base = spawnPositions[math.random(1, #spawnPositions)]
	return base + Vector3.new(math.random() * 10 - 5, 0, math.random() * 10 - 5)
end

return MapBuilder
