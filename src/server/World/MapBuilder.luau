--!nonstrict
-- Builds "Grandma's Retirement Neighborhood" from primitives at server start (no external assets).
-- Layout: open grass arena with a square ring road and a central park + fountain. A fence and
-- invisible walls close the arena at Config.Map.WallDistance; houses and the retirement home stand
-- outside the fence as scenery. Enemies spawn at 8 marked points just inside the fence.
-- Everything inside the arena is low and open, because enemy AI walks in straight lines.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local MapBuilder = {}

local spawnPositions: { Vector3 } = {}
local rng = Random.new(1337) -- fixed seed: same map every server

local COLORS = {
	Grass = Color3.fromRGB(96, 186, 72),
	Road = Color3.fromRGB(70, 72, 80),
	Sidewalk = Color3.fromRGB(205, 205, 200),
	Path = Color3.fromRGB(225, 210, 175),
	Trunk = Color3.fromRGB(120, 80, 45),
	Leaves = { Color3.fromRGB(70, 170, 60), Color3.fromRGB(95, 195, 70), Color3.fromRGB(55, 150, 65) },
	Houses = {
		Color3.fromRGB(250, 215, 90),
		Color3.fromRGB(110, 170, 240),
		Color3.fromRGB(240, 130, 120),
		Color3.fromRGB(150, 220, 150),
		Color3.fromRGB(245, 245, 235),
		Color3.fromRGB(200, 160, 230),
	},
	Roofs = { Color3.fromRGB(200, 70, 60), Color3.fromRGB(60, 90, 160), Color3.fromRGB(90, 90, 100) },
	White = Color3.fromRGB(250, 250, 245),
	Window = Color3.fromRGB(150, 210, 245),
	Door = Color3.fromRGB(120, 70, 40),
	Water = Color3.fromRGB(80, 190, 255),
	SpawnMark = Color3.fromRGB(255, 60, 60),
}

local function block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Upright cylinder standing on `base` (Roblox cylinders lie along X, so rotate them).
local function cylinder(parent: Instance, name: string, height: number, diameter: number, base: Vector3, color: Color3, material: Enum.Material?): Part
	local part = block(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function ball(parent: Instance, name: string, diameter: number, center: Vector3, color: Color3): Part
	local part = block(parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(center), color)
	part.Shape = Enum.PartType.Ball
	return part
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function tree(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local height = rng:NextNumber(5, 8)
	cylinder(model, "Trunk", height, 1.4, position, COLORS.Trunk)
	local leaves = COLORS.Leaves[rng:NextInteger(1, #COLORS.Leaves)]
	ball(model, "Leaves", rng:NextNumber(7, 9), position + Vector3.new(0, height + 2.5, 0), leaves)
	ball(model, "Leaves2", rng:NextNumber(5, 6), position + Vector3.new(rng:NextNumber(-1.5, 1.5), height + 5.5, rng:NextNumber(-1.5, 1.5)), leaves)
	model.Parent = parent
end

local function bush(parent: Instance, position: Vector3)
	ball(parent, "Bush", rng:NextNumber(3, 4.5), position + Vector3.new(0, 1.2, 0), COLORS.Leaves[rng:NextInteger(1, #COLORS.Leaves)])
end

local function lamp(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "StreetLamp"
	cylinder(model, "Pole", 11, 0.5, position, Color3.fromRGB(35, 35, 40), Enum.Material.Metal)
	block(model, "Head", Vector3.new(1.6, 0.6, 1.6), CFrame.new(position + Vector3.new(0, 11.3, 0)), Color3.fromRGB(35, 35, 40), Enum.Material.Metal)
	local bulb = ball(model, "Bulb", 1.3, position + Vector3.new(0, 10.6, 0), Color3.fromRGB(255, 235, 170))
	bulb.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 225, 170)
	light.Parent = bulb
	model.Parent = parent
end

local function bench(parent: Instance, cframe: CFrame)
	local model = Instance.new("Model")
	model.Name = "Bench"
	local wood = Color3.fromRGB(150, 95, 50)
	local iron = Color3.fromRGB(40, 40, 45)
	block(model, "Seat", Vector3.new(6, 0.4, 1.8), cframe * CFrame.new(0, 1.6, 0), wood)
	block(model, "Back", Vector3.new(6, 1.4, 0.3), cframe * CFrame.new(0, 2.6, 0.8), wood)
	block(model, "LegL", Vector3.new(0.4, 1.4, 1.6), cframe * CFrame.new(-2.5, 0.7, 0), iron)
	block(model, "LegR", Vector3.new(0.4, 1.4, 1.6), cframe * CFrame.new(2.5, 0.7, 0), iron)
	model.Parent = parent
end

local function mailbox(parent: Instance, cframe: CFrame)
	block(parent, "MailboxPost", Vector3.new(0.4, 3, 0.4), cframe * CFrame.new(0, 1.5, 0), Color3.fromRGB(120, 80, 45))
	block(parent, "Mailbox", Vector3.new(1, 1.1, 1.8), cframe * CFrame.new(0, 3.4, 0), Color3.fromRGB(220, 40, 40))
end

-- Boxy suburban house. Built facing -Z, then turned so the front faces the arena center.
local function house(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "House"
	local w, h, d = rng:NextNumber(20, 26), rng:NextNumber(12, 15), rng:NextNumber(16, 20)
	local wallColor = COLORS.Houses[rng:NextInteger(1, #COLORS.Houses)]
	local roofColor = COLORS.Roofs[rng:NextInteger(1, #COLORS.Roofs)]
	local base = CFrame.new(position)

	block(model, "Body", Vector3.new(w, h, d), base * CFrame.new(0, h / 2, 0), wallColor)
	-- stepped roof (three shrinking slabs) for a chunky low-poly look
	for i = 0, 2 do
		block(model, "Roof" .. i, Vector3.new(w + 2 - i * 6, 1.6, d + 2 - i * 5), base * CFrame.new(0, h + 0.8 + i * 1.6, 0), roofColor)
	end
	block(model, "Chimney", Vector3.new(2, 4, 2), base * CFrame.new(w / 4, h + 3, d / 6), Color3.fromRGB(170, 80, 60))
	block(model, "Door", Vector3.new(3.2, 6, 0.4), base * CFrame.new(0, 3, -d / 2 - 0.1), COLORS.Door)
	block(model, "Step", Vector3.new(5, 0.6, 2.5), base * CFrame.new(0, 0.3, -d / 2 - 1.2), COLORS.Sidewalk)
	for _, x in { -w / 3.2, w / 3.2 } do
		block(model, "Window", Vector3.new(4, 3.5, 0.3), base * CFrame.new(x, h * 0.55, -d / 2 - 0.1), COLORS.Window, Enum.Material.Glass)
		block(model, "WindowFrame", Vector3.new(4.6, 0.4, 0.4), base * CFrame.new(x, h * 0.55 - 1.9, -d / 2 - 0.15), COLORS.White)
	end
	-- little picket fence and mailbox in the front yard
	block(model, "YardFence", Vector3.new(w + 4, 1.6, 0.3), base * CFrame.new(0, 0.8, -d / 2 - 6), COLORS.White)
	mailbox(model, base * CFrame.new(w / 2 - 1, 0, -d / 2 - 7.5))

	model.WorldPivot = base
	model:PivotTo(CFrame.lookAt(position, Vector3.new(0, position.Y, 0)))
	model.Parent = parent
end

local function retirementHome(parent: Instance, position: Vector3)
	local model = Instance.new("Model")
	model.Name = "RetirementHome"
	local base = CFrame.new(position)
	local cream = Color3.fromRGB(240, 220, 185)
	block(model, "Body", Vector3.new(80, 22, 30), base * CFrame.new(0, 11, 0), cream)
	block(model, "Roof", Vector3.new(84, 2, 34), base * CFrame.new(0, 23, 0), Color3.fromRGB(190, 75, 60))
	block(model, "Tower", Vector3.new(20, 10, 20), base * CFrame.new(0, 29, 0), cream)
	block(model, "TowerRoof", Vector3.new(23, 2, 23), base * CFrame.new(0, 35, 0), Color3.fromRGB(190, 75, 60))
	block(model, "Porch", Vector3.new(30, 1, 10), base * CFrame.new(0, 0.5, -20), COLORS.Sidewalk)
	for _, x in { -12, -4, 4, 12 } do
		cylinder(model, "Column", 12, 1.6, (base * CFrame.new(x, 1, -24)).Position, COLORS.White)
	end
	block(model, "PorchRoof", Vector3.new(32, 1.2, 10), base * CFrame.new(0, 13.5, -20), COLORS.White)
	block(model, "Doors", Vector3.new(8, 9, 0.5), base * CFrame.new(0, 5.5, -15.2), COLORS.Door)
	for row = 0, 1 do
		for col = -3, 3 do
			if col ~= 0 then
				block(model, "Window", Vector3.new(5, 4, 0.4), base * CFrame.new(col * 10, 6 + row * 9, -15.2), COLORS.Window, Enum.Material.Glass)
			end
		end
	end

	local sign = block(model, "Sign", Vector3.new(30, 4, 0.6), base * CFrame.new(0, 16.5, -15.4), Color3.fromRGB(40, 70, 140))
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
	label.Parent = gui

	model.WorldPivot = base
	model:PivotTo(CFrame.lookAt(position, Vector3.new(0, position.Y, 0)))
	model.Parent = parent
end

local function buildGroundAndRoads(map: Folder)
	local size = Config.Map.GroundSize
	block(map, "Ground", Vector3.new(size, 2, size), CFrame.new(0, -1, 0), COLORS.Grass, Enum.Material.Grass)

	-- square ring road (center line radius 75) with sidewalks
	local roads = folder(map, "Roads")
	local r, width = 75, 16
	for _, side in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		local horizontal = side[1] == 0
		local length = 2 * r + width
		local cf = CFrame.new(side[1] * r, 0.05, side[2] * r)
		local roadSize = if horizontal then Vector3.new(length, 0.1, width) else Vector3.new(width, 0.1, length)
		block(roads, "Road", roadSize, cf, COLORS.Road, Enum.Material.Asphalt)
		for _, edge in { -1, 1 } do
			local offset = (width / 2 + 2) * edge
			local walkCf = if horizontal then cf * CFrame.new(0, 0.1, offset) else cf * CFrame.new(offset, 0.1, 0)
			local walkSize = if horizontal then Vector3.new(length + 8, 0.3, 4) else Vector3.new(4, 0.3, length + 8)
			block(roads, "Sidewalk", walkSize, walkCf, COLORS.Sidewalk, Enum.Material.Concrete)
		end
	end
	-- park paths from the fountain to the ring road
	for _, dir in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local center = dir * 35
		local size3 = if dir.X ~= 0 then Vector3.new(50, 0.2, 6) else Vector3.new(6, 0.2, 50)
		block(roads, "ParkPath", size3, CFrame.new(center + Vector3.new(0, 0.1, 0)), COLORS.Path, Enum.Material.Concrete)
	end
end

local function buildPark(map: Folder)
	local park = folder(map, "Park")
	-- fountain
	cylinder(park, "FountainBase", 1.6, 18, Vector3.new(0, 0, 0), COLORS.Sidewalk, Enum.Material.Concrete)
	local water = cylinder(park, "FountainWater", 0.3, 15.5, Vector3.new(0, 1.4, 0), COLORS.Water)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.2
	cylinder(park, "FountainPillar", 5, 2.2, Vector3.new(0, 1.6, 0), COLORS.Sidewalk, Enum.Material.Concrete)
	cylinder(park, "FountainBowl", 0.8, 6, Vector3.new(0, 6.6, 0), COLORS.Sidewalk, Enum.Material.Concrete)
	ball(park, "FountainTop", 1.8, Vector3.new(0, 8.3, 0), COLORS.Water).Material = Enum.Material.Neon

	-- benches around the fountain
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local pos = Vector3.new(math.cos(angle) * 16, 0, math.sin(angle) * 16)
		bench(park, CFrame.lookAt(pos, Vector3.new(0, 0, 0)))
	end
	-- trees and bushes in the park quarters (low cover, not walls)
	for _, quarter in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		tree(park, Vector3.new(quarter[1] * 40, 0, quarter[2] * 40))
		bush(park, Vector3.new(quarter[1] * 28, 0, quarter[2] * 48))
		bush(park, Vector3.new(quarter[1] * 50, 0, quarter[2] * 26))
	end
	-- lamps at the inner corners of the ring road
	for _, corner in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		lamp(park, Vector3.new(corner[1] * 64, 0, corner[2] * 64))
	end
end

local function buildBoundary(map: Folder)
	local boundary = folder(map, "Boundary")
	local d = Config.Map.WallDistance
	local length = d * 2

	for _, side in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		local horizontal = side[1] == 0
		local center = Vector3.new(side[1] * d, 0, side[2] * d)

		-- invisible wall: keeps players in, lets bullets through
		local wallSize = if horizontal then Vector3.new(length, 40, 2) else Vector3.new(2, 40, length)
		local wall = block(boundary, "InvisibleWall", wallSize, CFrame.new(center + Vector3.new(0, 20, 0)), COLORS.White)
		wall.Transparency = 1
		wall.CanQuery = false

		-- white rail fence (posts every 14 studs)
		for _, y in { 1.4, 3 } do
			local railSize = if horizontal then Vector3.new(length, 0.5, 0.4) else Vector3.new(0.4, 0.5, length)
			block(boundary, "Rail", railSize, CFrame.new(center + Vector3.new(0, y, 0)), COLORS.White)
		end
		for t = -d, d, 14 do
			local pos = if horizontal then Vector3.new(t, 0, center.Z) else Vector3.new(center.X, 0, t)
			block(boundary, "Post", Vector3.new(0.8, 4, 0.8), CFrame.new(pos + Vector3.new(0, 2, 0)), COLORS.White)
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
		local mark = cylinder(spawns, "SpawnMark", 0.15, 14, pos, COLORS.SpawnMark, Enum.Material.Neon)
		mark.Transparency = 0.45
		mark.CanCollide = false
		mark.CanQuery = false
	end
end

local function buildScenery(map: Folder)
	local scenery = folder(map, "Scenery")
	local d = Config.Map.WallDistance
	-- houses along three sides; the retirement home owns the north side
	for t = -110, 110, 44 do
		house(scenery, Vector3.new(t, 0, d + 22)) -- south
		house(scenery, Vector3.new(-d - 22, 0, t)) -- west
		house(scenery, Vector3.new(d + 22, 0, t)) -- east
	end
	retirementHome(scenery, Vector3.new(0, 0, -d - 35))
	-- trees scattered behind the houses and in the arena's outer lawn
	for _ = 1, 40 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(d + 50, d + 70)
		tree(scenery, Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
	end
	for _ = 1, 14 do
		local x = rng:NextNumber(-d + 10, d - 10)
		local z = if rng:NextNumber() > 0.5 then rng:NextNumber(95, d - 20) else -rng:NextNumber(95, d - 20)
		if rng:NextNumber() > 0.5 then
			x, z = z, x
		end
		bush(scenery, Vector3.new(x, 0, z))
	end
end

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	Lighting.Ambient = Color3.fromRGB(90, 90, 100)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.25
		atmosphere.Haze = 0.5
		atmosphere.Color = Color3.fromRGB(200, 220, 255)
		atmosphere.Parent = Lighting
	end
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

	buildGroundAndRoads(map)
	buildPark(map)
	buildBoundary(map)
	buildSpawns(map)
	buildScenery(map)

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

function MapBuilder.GetSpawnPositions(): { Vector3 }
	return spawnPositions
end

-- A random point near one of the enemy spawn markers.
function MapBuilder.GetRandomSpawnPosition(): Vector3
	local base = spawnPositions[math.random(1, #spawnPositions)]
	return base + Vector3.new(math.random() * 10 - 5, 0, math.random() * 10 - 5)
end

return MapBuilder
