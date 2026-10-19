--!nonstrict
-- Builds "Grandma's Retirement Neighborhood" in the comic-book style (World/ComicKit + World/Props) at server
-- start, no external assets. Layout: open grass arena with a square ring road around a perfectly square park
-- with a fountain. A picket fence and invisible walls close the arena at Config.Map.WallDistance; houses, the
-- retirement home and the school bus stand outside the fence as scenery. Enemies spawn at 8 marked points just
-- inside the fence. Everything inside the arena is low, small and round-ish, because enemy AI walks in
-- straight lines (obstacles are circles, see GetObstacles).
-- Props go into outline-group Models (ComicKit.OutlineGroup): each group gets one ink outline on the client.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local ComicKit = require(script.Parent.ComicKit)
local Houses = require(script.Parent.Houses)
local Props = require(script.Parent.Props)
local Vegetation = require(script.Parent.Vegetation)
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

-- A ring of grass tufts (decoration only, skipped when Config.Comic.GrassTufts is off).
local function tufts(center: Vector3, radius: number, count: number)
	if not Config.Comic.GrassTufts then
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

local function buildGroundAndRoads(map: Folder, roads: Model)
	local size = Config.Map.GroundSize
	K.Block(map, Vector3.new(size, 2, size), CFrame.new(0, -1, 0), C.Grass).Name = "Ground"

	-- mowed stripes on the square park lawn (no outline: flat ground)
	local park = RING - ROAD_WIDTH / 2 - 4
	local stripe = park * 2 / 9
	for i = 0, 8, 2 do
		K.Block(map, Vector3.new(stripe, 0.04, park * 2), CFrame.new(-park + stripe * (i + 0.5), 0.02, 0), C.GrassLight, true)
	end

	-- square ring road: asphalt, dashed center line, edge lines, curbs, sidewalks with joints
	for _, side in SIDES do
		local horizontal = side[1] == 0
		local length = 2 * RING + ROAD_WIDTH
		local cf = CFrame.new(side[1] * RING, 0.05, side[2] * RING)
		if not horizontal then
			cf *= CFrame.Angles(0, math.pi / 2, 0) -- local X runs along the road
		end
		K.Block(roads, Vector3.new(length, 0.1, ROAD_WIDTH), cf, C.Road).Name = "Road"
		local straight = 2 * RING - ROAD_WIDTH -- between the corner squares
		for t = -straight / 2 + 4, straight / 2 - 4, 8 do
			K.Block(roads, Vector3.new(4, 0.04, 0.45), cf * CFrame.new(t, 0.07, 0), C.RoadLine, true)
		end
		for _, edge in { -1, 1 } do
			K.Block(roads, Vector3.new(straight, 0.04, 0.3), cf * CFrame.new(0, 0.07, edge * (ROAD_WIDTH / 2 - 0.8)), C.RoadEdge, true)
			K.Block(roads, Vector3.new(length, 0.4, 0.45), cf * CFrame.new(0, 0.15, edge * (ROAD_WIDTH / 2 + 0.2)), C.Curb, true)
			local walk = cf * CFrame.new(0, 0.1, edge * (ROAD_WIDTH / 2 + 2))
			K.Block(roads, Vector3.new(length + 8, 0.3, 4), walk, C.Sidewalk).Name = "Sidewalk"
			for t = -length / 2, length / 2, 8 do
				K.Block(roads, Vector3.new(0.2, 0.04, 4), walk * CFrame.new(t, 0.16, 0), C.SidewalkJoint, true)
			end
		end
		-- manhole cover
		local manhole = (cf * CFrame.new(30, 0, 3)).Position
		K.Disc(roads, 2.9, 0.06, manhole + Vector3.new(0, 0.05, 0), C.Ink, true)
		K.Disc(roads, 2.4, 0.06, manhole + Vector3.new(0, 0.08, 0), C.MetalDark, true)
	end

	-- park paths from the fountain to the ring road, with stone edging
	for _, dir in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local path = CFrame.lookAt(dir * 35, dir * 36) -- local -Z runs along the path
		K.Block(roads, Vector3.new(6, 0.2, 50), path * CFrame.new(0, 0.1, 0), C.Path).Name = "ParkPath"
		for _, edge in { -1, 1 } do
			K.Block(roads, Vector3.new(0.4, 0.3, 50), path * CFrame.new(edge * 3.2, 0.15, 0), C.Stone, true)
		end
	end

	-- crosswalks where the park paths cross the ring road
	for _, side in SIDES do
		local alongX = side[1] ~= 0
		for i = -2, 2 do
			local offset = if alongX then Vector3.new(0, 0, i * 1.6) else Vector3.new(i * 1.6, 0, 0)
			local stripeSize = if alongX then Vector3.new(15, 0.12, 0.8) else Vector3.new(0.8, 0.12, 15)
			K.Block(roads, stripeSize, CFrame.new(Vector3.new(side[1] * RING, 0.12, side[2] * RING) + offset), C.Trim, true)
		end
	end
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

		-- white picket fence between capped posts (corner posts only once)
		local along = if horizontal then Vector3.xAxis else Vector3.zAxis
		local step = length / Config.Map.FenceSections
		for i = 0, Config.Map.FenceSections do
			local at = center + along * (-d + i * step)
			if i < Config.Map.FenceSections then
				Props.PicketFence(fence, at, at + along * step, 3.2, 3.4, C.Trim)
			end
			local key = string.format("%d,%d", math.round(at.X), math.round(at.Z))
			if not posts[key] then
				posts[key] = true
				Props.FencePost(fence, at, 4.4, C.Trim)
			end
		end
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

local function buildScenery(groups: { [string]: Model })
	local d = Config.Map.WallDistance
	-- houses along three sides, square to the streets and facing the arena; the retirement home owns the north
	local taken = { { Position = Vector3.new(0, 0, -d - 35), Radius = 50 }, { Position = Vector3.new(70, 0, -d - 18), Radius = 16 } }
	local row = d + 26
	local index = 0
	for k, t in { -110, -66, -22, 22, 66, 110 } do
		for s, spot in { { Vector3.new(t, 0, row), -Vector3.zAxis }, { Vector3.new(-row, 0, t), Vector3.xAxis }, { Vector3.new(row, 0, t), -Vector3.xAxis } } do
			index += 1
			local position, facing = spot[1], spot[2]
			local design = Houses.Designs[(k + s * 2) % #Houses.Designs + 1] -- every street shows all six designs
			Houses.Build(groups, CFrame.lookAt(position, position + facing), design, rng, design .. index)
			table.insert(taken, { Position = position, Radius = 30 })
		end
	end
	local home = CFrame.lookAt(Vector3.new(0, 0, -d - 35), Vector3.zero)
	Props.RetirementHome(groups.Landmarks, home)
	-- retirement home garden: trimmed hedges and rose beds beside the porch, pointed shrubs at the steps
	for _, x in { -33, -23, 23, 33 } do
		Vegetation.TrimmedHedge(garden, home * CFrame.new(x, 0, -17.2), 8, rng)
	end
	for _, side in { -1, 1 } do
		Vegetation.Bed(garden, (home * CFrame.new(side * 19, 0, -19.6)).Position, (home * CFrame.new(side * 37, 0, -19.6)).Position, { "Rose" }, rng)
		Vegetation.Bush(garden, "Pointed", (home * CFrame.new(side * 8.6, 0, -28.4)).Position, rng)
	end
	-- the shuttle waits by the home (door toward it), two mobility scooters on the porch
	Vehicles.Build(vehicles, "Shuttle", CFrame.new(70, 0, -d - 18) * CFrame.Angles(0, math.pi / 2, 0))
	for _, side in { -1, 1 } do
		Vehicles.Build(vehicles, "Scooter", home * CFrame.new(side * 13, 1.2, -22) * CFrame.Angles(0, side * 0.4, 0))
	end

	-- a ring of trees behind the houses: even spacing with a little jitter, kinds in a repeating pattern,
	-- never inside a building
	local ring = { "Oak", "Evergreen", "Maple", "Roadside", "Evergreen", "Cherry" }
	local planted = 0
	for i = 0, 43 do
		local angle = i * math.pi * 2 / 44 + rng:NextNumber(-0.03, 0.03)
		local radius = d + 52 + (i % 3) * 6 + rng:NextNumber(-1.5, 1.5)
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
end

-- The arena's outer lawn: planting spots along the outer sidewalks, bushes and roadside trees in a regular
-- pattern between the road and the spawn circles (lanes stay open).
local function buildLawn()
	local d = Config.Map.WallDistance
	local bushKinds = { "Wild", "Round", "Corner", "Flowering" }
	for s, side in SIDES do
		local out = Vector3.new(side[1], 0, side[2])
		local along = if side[1] == 0 then Vector3.xAxis else Vector3.zAxis
		for _, t in { -66, -20, 20, 66 } do
			local spot = out * (RING + 15) + along * t
			Vegetation.Bush(garden, "Leafy", spot, rng, 0.9)
			Vegetation.Flower(garden, "Wildflower", spot + along * 1.6, rng)
			tufts(spot - along * 1.6, 0.3, 1)
		end
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
	for _, name in { "Roads", "Park", "StreetProps", "Cars", "CarDetails", "FoliageA", "FoliageB", "Wood", "Flowers", "HouseWalls", "HouseRoofs", "HouseDetails", "Yards", "Landmarks", "Fence" } do
		groups[name] = K.OutlineGroup(map, name)
	end
	-- grass blades, stems and soil stay without outlines: at a distance an outline would be all you see of them
	groups.Grass = K.Model("Grass")
	groups.Grass.Parent = map
	garden = Vegetation.LayersFrom(groups)
	vehicles = { Body = groups.Cars, Details = groups.CarDetails }

	buildGroundAndRoads(map, groups.Roads)
	buildPark(groups)
	buildBoundary(map, groups.Fence)
	buildSpawns(map)
	buildScenery(groups)
	buildLawn()

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
