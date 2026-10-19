--!nonstrict
-- Builds "Grandma's Retirement Neighborhood" in the comic-book style at server start, no external assets.
-- Layout: a perfectly square park with a fountain inside a square ring road ("Bingo Blvd"); from the middle of
-- each side a street runs out across the arena's lawn to a square perimeter street ("Slipper Ave") just outside
-- the arena fence, which the houses, the retirement home and their driveways face. A picket fence (closed by
-- ROAD CLOSED barricades where the streets cross it) and invisible walls close the arena at
-- Config.Map.WallDistance. Enemies spawn at 8 marked points just inside the fence. Everything inside the arena
-- is low, small and round-ish, because enemy AI walks in straight lines (obstacles are circles, see
-- GetObstacles).
-- Props go into outline-group Models (ComicKit.OutlineGroup): each group gets one ink outline on the client.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local ComicKit = require(script.Parent.ComicKit)
local Fences = require(script.Parent.Fences)
local Houses = require(script.Parent.Houses)
local Props = require(script.Parent.Props)
local Vegetation = require(script.Parent.Vegetation)
local Streets = require(script.Parent.Streets)
local Vehicles = require(script.Parent.Vehicles)

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

-- Parked car: two circles along its length keep grandmas off it.
local function car(kind: string, cframe: CFrame)
	Vehicles.Build(vehicles, kind, cframe)
	local spec = Vehicles.Specs[kind]
	for _, z in { -spec.L / 4, spec.L / 4 } do
		addObstacle((cframe * CFrame.new(0, 0, z)).Position, spec.W / 2 + 0.3)
	end
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

local function buildGround(map: Folder, roads: Model)
	local size = Config.Map.GroundSize
	K.Block(map, Vector3.new(size, 2, size), CFrame.new(0, -1, 0), C.Grass).Name = "Ground"

	-- mowed stripes on the square park lawn (no outline: flat ground)
	local park = RING - ROAD_WIDTH / 2 - WALK
	local stripe = park * 2 / 9
	for i = 0, 8, 2 do
		K.Block(map, Vector3.new(stripe, 0.04, park * 2), CFrame.new(-park + stripe * (i + 0.5), 0.02, 0), C.GrassLight, true)
	end

	-- park paths from the fountain to the ring road's sidewalk, with stone edging
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local path = CFrame.lookAt(dir * 36.5, dir * 37.5) -- local -Z runs along the path
		K.Block(roads, Vector3.new(6, 0.2, 53), path * CFrame.new(0, 0.1, 0), C.Path).Name = "ParkPath"
		for _, edge in { -1, 1 } do
			K.Block(roads, Vector3.new(0.4, 0.3, 53), path * CFrame.new(edge * 3.2, 0.15, 0), C.Stone, true)
		end
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

local function buildPark(groups: { [string]: Model })
	Props.Fountain(groups.Park, Vector3.zero)
	addObstacle(Vector3.zero, 9.6)

	-- benches and trash cans around the fountain
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local pos = Vector3.new(math.cos(angle) * 16, 0, math.sin(angle) * 16)
		Props.Bench(groups.StreetProps, CFrame.lookAt(pos, Vector3.zero))
		addObstacle(pos, 2.8)
		local canAngle = angle + math.rad(14)
		local can = Vector3.new(math.cos(canAngle) * 17, 0, math.sin(canAngle) * 17)
		Props.TrashCan(groups.StreetProps, can)
		addObstacle(can, 1)
	end
	-- park quarters: an oak or a maple, two bushes, a round flower bed (low cover, not walls)
	for i, quarter in CORNERS do
		local trunk = Vector3.new(quarter[1] * 40, 0, quarter[2] * 40)
		tree(if i % 2 == 0 then "Oak" else "Maple", trunk)
		tufts(trunk, 2.6, 3)
		for k, spot in { Vector3.new(quarter[1] * 28, 0, quarter[2] * 48), Vector3.new(quarter[1] * 50, 0, quarter[2] * 26) } do
			bush(Vegetation.Bushes[({ 1, 3, 6, 8 })[(i + k) % 4 + 1]], spot)
			tufts(spot, 2.4, 2)
		end
		Vegetation.FlowerBed(garden, Vector3.new(quarter[1] * 22, 0, quarter[2] * 22), rng)
	end
	-- blossoming cherry trees in a pinwheel around the paths
	for _, spot in { Vector3.new(46, 0, 10), Vector3.new(-46, 0, -10), Vector3.new(10, 0, -46), Vector3.new(-10, 0, 46) } do
		tree("Cherry", spot)
		tufts(spot, 2.4, 3)
	end
	-- small rustic fences flanking each path where it meets the sidewalk (short pieces backed by obstacles)
	local edge = RING - ROAD_WIDTH / 2 - WALK - 1.4
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local across = Vector3.new(dir.Z, 0, -dir.X)
		for _, side in { -1, 1 } do
			local from, to = dir * edge + across * side * 5.5, dir * edge + across * side * 13.5
			Fences.Park(groups.Fence, from, to)
			for k = 0, 2 do
				addObstacle(from:Lerp(to, (k + 0.5) / 3), 1.1)
			end
		end
	end
	-- decorative rock clusters in the lawn corners
	for _, corner in CORNERS do
		local spot = Vector3.new(corner[1] * 55, 0, corner[2] * 55)
		Props.Rocks(groups.Park, spot, rng, 3)
		tufts(spot, 2.2, 2)
	end
	-- flower beds along both sides of every park path
	local mixes = { { "Tulip" }, { "Daisy", "Tulip" }, { "Rose", "Daisy" }, { "Tulip", "Wildflower" } }
	for k, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local across = Vector3.new(dir.Z, 0, -dir.X)
		for _, side in { -1, 1 } do
			Vegetation.Bed(garden, dir * 23 + across * side * 4.4, dir * 33 + across * side * 4.4, mixes[k], rng)
		end
	end
	-- lamps at the inner corners of the ring road and along its outer side, hydrants by the outer sidewalk
	for _, corner in CORNERS do
		for _, pos in { Vector3.new(corner[1] * 64, 0, corner[2] * 64), Vector3.new(corner[1] * 87, 0, corner[2] * 40), Vector3.new(corner[1] * 40, 0, corner[2] * 87) } do
			Props.Lamp(groups.StreetProps, pos)
			addObstacle(pos, 0.8)
		end
		local hydrant = Vector3.new(corner[1] * 87, 0, corner[2] * 58)
		Props.Hydrant(groups.StreetProps, CFrame.lookAt(hydrant, Vector3.new(0, 0, hydrant.Z)))
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
	-- houses along three sides, square to the perimeter street and facing the arena; the retirement home owns
	-- the north side
	local taken = { { Position = homeAt, Radius = 50 } }
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
		end
	end
	local home = CFrame.lookAt(homeAt, Vector3.zero)
	Props.RetirementHome(groups.Landmarks, home)
	-- retirement home garden: trimmed hedges and rose beds beside the porch, pointed shrubs at the steps
	for _, x in { -33, -23, 23, 33 } do
		Vegetation.TrimmedHedge(garden, home * CFrame.new(x, 0, -17.2), 8, rng)
	end
	for _, side in { -1, 1 } do
		Vegetation.Bed(garden, (home * CFrame.new(side * 19, 0, -19.6)).Position, (home * CFrame.new(side * 37, 0, -19.6)).Position, { "Rose" }, rng)
		Vegetation.Bush(garden, "Pointed", (home * CFrame.new(side * 8.6, 0, -28.4)).Position, rng)
	end
	-- retirement home: a short iron fence in front of the hedges, the shuttle at the curb of the perimeter street
	-- (door toward the home), two mobility scooters on the porch
	for _, side in { -1, 1 } do
		Fences.Iron(groups.Yards, (home * CFrame.new(side * 17.5, 0, -21.4)).Position, (home * CFrame.new(side * 38.5, 0, -21.4)).Position)
	end
	Vehicles.Build(vehicles, "Shuttle", CFrame.new(60, 0, -(OUTER + 3.2)) * CFrame.Angles(0, math.pi / 2, 0))
	for _, side in { -1, 1 } do
		Vehicles.Build(vehicles, "Scooter", home * CFrame.new(side * 13, 1.2, -22) * CFrame.Angles(0, side * 0.4, 0))
	end

	-- a ring of trees behind the houses: even spacing with a little jitter, kinds in a repeating pattern,
	-- never inside a building
	local ring = { "Oak", "Evergreen", "Maple", "Roadside", "Evergreen", "Cherry" }
	local planted = 0
	for i = 0, 43 do
		local angle = i * math.pi * 2 / 44 + rng:NextNumber(-0.03, 0.03)
		local radius = d + 66 + (i % 3) * 5 + rng:NextNumber(-1.5, 1.5)
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local free = true
		for _, spot in taken do
			if (spot.Position - position).Magnitude < spot.Radius then
				free = false
				break
			end
		end
		if free then
			planted += 1
			tree(ring[planted % #ring + 1], position, rng:NextNumber(0.9, 1.15))
		end
	end
	-- tall street lights along the perimeter street's arena side (no driveways there)
	for i, side in SIDES do
		local n, tan = sideFrame(side)
		for _, t in { -120, -75, -30, 30, 75, 120 } do
			local at = n * (OUTER - OUTER_WIDTH / 2 - WALK / 2) + tan * t
			Props.StreetLight(groups.StreetProps, CFrame.lookAt(at, at + n))
		end
		local corner = n * (OUTER - OUTER_WIDTH / 2 - WALK + 1.2) + tan * (SPUR / 2 + WALK - 0.7)
		Props.StopSign(groups.StreetProps, CFrame.lookAt(corner, corner - n), { NAMES.Outer, NAMES.Spurs[i] })
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
			local soil = Props.Planter(groups.StreetProps, CFrame.lookAt(spot, spot + out) * CFrame.Angles(0, math.pi / 2, 0), 3.2)
			for k = -1, 1 do
				Vegetation.Flower(garden, "Tulip", (soil * CFrame.new(k * 0.95, 0, 0)).Position, rng)
			end
			addObstacle(spot, 1.7)
		end
		-- at each spur: a stop sign with the street names at the ring road, a street light, a utility box
		local n, tan = sideFrame(side)
		local stop = n * (RING + ROAD_WIDTH / 2 + WALK + 1.4) - tan * (SPUR / 2 + WALK - 0.7)
		Props.StopSign(groups.StreetProps, CFrame.lookAt(stop, stop + n), { NAMES.Ring, NAMES.Spurs[s] })
		addObstacle(stop, 0.5)
		local lamp = n * 112 + tan * (SPUR / 2 + WALK - 0.7)
		Props.StreetLight(groups.StreetProps, CFrame.lookAt(lamp, lamp - tan))
		addObstacle(lamp, 0.7)
		local box = n * 100 + tan * (SPUR / 2 + WALK + 2.6)
		Props.UtilityBox(groups.StreetProps, CFrame.lookAt(box, box - tan))
		Props.Rocks(groups.Park, box + n * 2.4, rng, 2)
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

	buildGround(map, groups.Roads)
	buildPark(groups)
	buildBoundary(map, groups.Fence)
	buildSpawns(map)
	local aprons = buildScenery(groups)
	buildStreets({ Road = groups.Roads, Walk = groups.Sidewalks }, aprons)
	buildLawn(groups)

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
