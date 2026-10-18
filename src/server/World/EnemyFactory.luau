--!nonstrict
-- Builds lightweight enemy models: plain Parts welded to one anchored Root. No Humanoid, no scripts.
-- EnemyService moves only the Root; the welds carry every other part along.
-- Only the invisible "Hitbox" part is queryable, so bullet raycasts stay cheap and hits are forgiving.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local EnemyFactory = {}

local SKIN = Color3.fromRGB(247, 190, 132)
local HAIR = Color3.fromRGB(190, 190, 200)
local DARK = Color3.fromRGB(25, 25, 30)
local TIGHTS = Color3.fromRGB(230, 205, 175)

-- Adds a part welded to `root`. `offset` is relative to the root.
local function addPart(model: Model, root: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = root.CFrame * offset

	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part

	part.Parent = model
	return part
end

type GrandmaOptions = {
	Dress: Color3,
	Flowers: Color3,
	Hair: Color3?,
	Scale: number?,
	Legs: boolean?, -- false when sitting on a scooter
	GlowingEyes: boolean?,
	Held: string?, -- "Slipper" | "RollingPin"
}

-- Blocky Roblox-style grandma: bun, glasses, angry brows, flowery dress, arms stretched forward.
-- Front is -Z. Root origin = dress center; at Scale 1 the feet are 3 studs below it.
local function buildGrandma(model: Model, root: BasePart, options: GrandmaOptions)
	local s = options.Scale or 1
	local hair = options.Hair or HAIR
	-- every size and offset below is for Scale 1 and gets multiplied here
	local function add(name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): Part
		return addPart(model, root, name, size * s, CFrame.new(offset.Position * s) * offset.Rotation, color, shape)
	end

	root.Size = Vector3.new(2.2, 2.4, 1.3) * s
	root.Color = options.Dress

	if options.Legs ~= false then
		add("LegL", Vector3.new(0.7, 1.8, 0.7), CFrame.new(-0.5, -2.1, 0), TIGHTS)
		add("LegR", Vector3.new(0.7, 1.8, 0.7), CFrame.new(0.5, -2.1, 0), TIGHTS)
	end
	add("Collar", Vector3.new(1.7, 0.3, 1.5), CFrame.new(0, 1.2, 0), Color3.fromRGB(250, 250, 250))
	for i, x in { -0.6, 0.55, -0.1 } do
		add("Flower" .. i, Vector3.new(0.4, 0.4, 0.05), CFrame.new(x, 0.1 - i * 0.3, -0.68), options.Flowers)
	end

	add("Head", Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, 2.0, 0), SKIN)
	add("HairTop", Vector3.new(1.6, 0.45, 1.6), CFrame.new(0, 2.9, 0), hair)
	add("HairBack", Vector3.new(1.6, 1.3, 0.35), CFrame.new(0, 2.3, 0.65), hair)
	add("HairSideL", Vector3.new(0.3, 0.9, 1.5), CFrame.new(-0.8, 2.45, 0), hair)
	add("HairSideR", Vector3.new(0.3, 0.9, 1.5), CFrame.new(0.8, 2.45, 0), hair)
	add("Bun", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 3.35, 0.2), hair, Enum.PartType.Ball)

	for _, x in { -0.38, 0.38 } do
		add("GlassFrame", Vector3.new(0.58, 0.42, 0.06), CFrame.new(x, 2.05, -0.77), DARK)
		add("GlassLens", Vector3.new(0.44, 0.28, 0.07), CFrame.new(x, 2.05, -0.78), Color3.fromRGB(215, 235, 250))
		local eye = add("Eye", Vector3.new(0.13, 0.17, 0.08), CFrame.new(x, 2.03, -0.8), DARK)
		if options.GlowingEyes then
			eye.Size = Vector3.new(0.3, 0.22, 0.08) * s
			eye.Color = Color3.fromRGB(255, 40, 40)
			eye.Material = Enum.Material.Neon
		end
	end
	add("GlassBridge", Vector3.new(0.2, 0.07, 0.06), CFrame.new(0, 2.1, -0.77), DARK)
	-- angry brows: inner ends low (V shape)
	add("BrowL", Vector3.new(0.6, 0.1, 0.08), CFrame.new(-0.4, 2.42, -0.77) * CFrame.Angles(0, 0, math.rad(-22)), DARK)
	add("BrowR", Vector3.new(0.6, 0.1, 0.08), CFrame.new(0.4, 2.42, -0.77) * CFrame.Angles(0, 0, math.rad(22)), DARK)
	add("Mouth", Vector3.new(0.5, 0.12, 0.07), CFrame.new(0, 1.5, -0.77), Color3.fromRGB(120, 30, 40))

	-- arms stretched forward (-Z)
	add("ArmL", Vector3.new(0.5, 0.5, 1.7), CFrame.new(-1.35, 0.6, -0.9), SKIN)
	add("ArmR", Vector3.new(0.5, 0.5, 1.7), CFrame.new(1.35, 0.6, -0.9), SKIN)
	add("SleeveL", Vector3.new(0.6, 0.6, 0.6), CFrame.new(-1.35, 0.6, -0.1), options.Dress)
	add("SleeveR", Vector3.new(0.6, 0.6, 0.6), CFrame.new(1.35, 0.6, -0.1), options.Dress)

	if options.Held == "Slipper" then
		add("Slipper", Vector3.new(0.55, 0.25, 1.1), CFrame.new(1.35, 1.0, -1.7) * CFrame.Angles(math.rad(-35), 0, 0), Color3.fromRGB(255, 110, 190))
		add("SlipperFluff", Vector3.new(0.6, 0.3, 0.35), CFrame.new(1.35, 1.25, -1.5), Color3.fromRGB(255, 200, 230))
	elseif options.Held == "RollingPin" then
		add("RollingPin", Vector3.new(0.7, 3.2, 0.7), CFrame.new(1.35, 1.6, -1.8), Color3.fromRGB(205, 150, 90))
		add("PinHandleTop", Vector3.new(0.35, 0.8, 0.35), CFrame.new(1.35, 3.6, -1.8), Color3.fromRGB(150, 100, 55))
		add("PinHandleBottom", Vector3.new(0.35, 0.8, 0.35), CFrame.new(1.35, -0.4, -1.8), Color3.fromRGB(150, 100, 55))
	end
end

-- Red mobility scooter under a seated grandma (feet level = 3 studs below the root).
local function buildScooter(model: Model, root: BasePart)
	local red = Color3.fromRGB(220, 40, 45)
	local black = Color3.fromRGB(30, 30, 35)
	addPart(model, root, "Base", Vector3.new(2.6, 0.7, 4.6), CFrame.new(0, -2.15, -0.3), red)
	addPart(model, root, "Seat", Vector3.new(2.3, 0.6, 1.6), CFrame.new(0, -1.4, 0.3), Color3.fromRGB(40, 40, 45))
	addPart(model, root, "Column", Vector3.new(0.4, 2.2, 0.4), CFrame.new(0, -0.9, -2.3) * CFrame.Angles(math.rad(-20), 0, 0), red)
	addPart(model, root, "Handlebar", Vector3.new(2.2, 0.25, 0.25), CFrame.new(0, 0.15, -2.65), black)
	addPart(model, root, "Basket", Vector3.new(1.6, 0.9, 1), CFrame.new(0, -0.6, -3), Color3.fromRGB(200, 160, 90))
	addPart(model, root, "Light", Vector3.new(0.5, 0.35, 0.2), CFrame.new(0, -1.7, -2.65), Color3.fromRGB(255, 240, 150)).Material = Enum.Material.Neon
	for _, wheel in { { -1.1, -1.8 }, { 1.1, -1.8 }, { -1.1, 1.3 }, { 1.1, 1.3 } } do
		addPart(model, root, "Wheel", Vector3.new(0.5, 1.1, 1.1), CFrame.new(wheel[1], -2.45, wheel[2]), black, Enum.PartType.Cylinder)
	end
end

local BUILDERS = {
	NormalGrandma = function(model, root)
		buildGrandma(model, root, { Dress = Color3.fromRGB(142, 79, 208), Flowers = Color3.fromRGB(255, 150, 200) })
	end,
	SlipperGrandma = function(model, root)
		buildGrandma(model, root, { Dress = Color3.fromRGB(255, 120, 175), Flowers = Color3.fromRGB(255, 240, 120), Held = "Slipper" })
	end,
	ScooterGrandma = function(model, root)
		buildGrandma(model, root, { Dress = Color3.fromRGB(90, 190, 120), Flowers = Color3.fromRGB(255, 230, 90), Legs = false })
		buildScooter(model, root)
	end,
	MegaGrandma = function(model, root)
		buildGrandma(model, root, {
			Dress = Color3.fromRGB(170, 60, 200),
			Flowers = Color3.fromRGB(255, 160, 220),
			Scale = 4,
			GlowingEyes = true,
			Held = "RollingPin",
		})
	end,
}

-- Returns (model, root). The model's PrimaryPart is the root, centered at the origin
-- at height def.RootHeight; the caller positions it with PivotTo.
function EnemyFactory.Build(typeName: string, def): (Model, BasePart)
	local builder = BUILDERS[typeName]
	assert(builder, "No EnemyFactory builder for " .. tostring(typeName))

	local model = Instance.new("Model")
	model.Name = def.Name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Material = Enum.Material.SmoothPlastic
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CFrame = CFrame.new(0, def.RootHeight, 0)
	root.Parent = model
	model.PrimaryPart = root

	builder(model, root)

	-- Invisible hitbox: the only part bullets can hit. Slightly larger than the visual model.
	local scale = def.Scale or 1
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = (def.HitboxSize or Vector3.new(2.8, 6.6, 2.4)) * scale
	hitbox.Transparency = if Config.Debug.ShowHitboxes then 0.75 else 1
	hitbox.Color = Color3.fromRGB(255, 0, 0)
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	hitbox.Massless = true
	local hitboxOffset = CFrame.new(0, 0.3 * scale, 0)
	hitbox.CFrame = root.CFrame * hitboxOffset
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = hitbox
	weld.C0 = hitboxOffset
	weld.Parent = hitbox
	hitbox.Parent = model

	return model, root
end

return EnemyFactory
