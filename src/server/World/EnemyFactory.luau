--!nonstrict
-- Builds lightweight enemy models: plain Parts welded to one anchored Root. No Humanoid, no scripts.
-- EnemyService moves only the Root; the welds carry every other part along.
-- Only the invisible "Hitbox" part is queryable, so bullet raycasts stay cheap and hits are forgiving.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local EnemyFactory = {}

-- Comic palette (bright flat colors + black ink, matching ComicKit's map look)
local SKIN = Color3.fromRGB(250, 196, 150)
local SKIN_SHADE = Color3.fromRGB(232, 160, 120)
local BLUSH = Color3.fromRGB(246, 120, 140)
local HAIR = Color3.fromRGB(214, 214, 226)
local HAIR_SHADE = Color3.fromRGB(176, 176, 196)
local INK = Color3.fromRGB(24, 22, 30)
local WHITE = Color3.fromRGB(252, 250, 244)
local LENS = Color3.fromRGB(200, 236, 255)
local TIGHTS = Color3.fromRGB(236, 206, 176)
local SHOES = Color3.fromRGB(110, 66, 44)
local PEARL = Color3.fromRGB(250, 246, 236)

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
	part.CastShadow = false
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
	Cardigan: Color3,
	Dots: Color3,
	Hair: Color3?,
	Scale: number?,
	Legs: boolean?, -- false when sitting on a scooter
	GlowingEyes: boolean?,
	Held: string?, -- "Slipper" | "RollingPin" | "Handbag"
}

local FACING_Z = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder (axis X) to face forward (-Z)

-- Comic grandma: big head with round glasses, angry ink brows, rosy cheeks and gritted teeth, a curly perm
-- with a bun, polka-dot dress under an open cardigan, pearls, puffy sleeves, fists, stockings, chunky shoes.
-- Front is -Z. Root origin = dress center; at Scale 1 the feet are 3 studs below it.
local function buildGrandma(model: Model, root: BasePart, options: GrandmaOptions)
	local s = options.Scale or 1
	local hair = options.Hair or HAIR
	-- every size and offset below is for Scale 1 and gets multiplied here
	local function add(name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): Part
		return addPart(model, root, name, size * s, CFrame.new(offset.Position * s) * offset.Rotation, color, shape)
	end
	local function ball(name: string, diameter: number, x: number, y: number, z: number, color: Color3): Part
		return add(name, Vector3.new(diameter, diameter, diameter), CFrame.new(x, y, z), color, Enum.PartType.Ball)
	end

	-- dress (the root itself is the bodice), flared skirt with a lace hem and an ink line at the bottom
	root.Size = Vector3.new(2.2, 2.4, 1.3) * s
	root.Color = options.Dress
	add("Skirt", Vector3.new(2.6, 0.8, 1.7), CFrame.new(0, -0.85, 0), options.Dress)
	add("Lace", Vector3.new(2.66, 0.16, 1.76), CFrame.new(0, -1.15, 0), WHITE)
	add("HemInk", Vector3.new(2.7, 0.08, 1.8), CFrame.new(0, -1.26, 0), INK)
	add("BeltInk", Vector3.new(2.24, 0.08, 1.34), CFrame.new(0, -0.42, 0), INK)
	for i, dot in { { 0, 0.55 }, { -0.15, -0.05 }, { 0.2, -0.75 }, { -0.9, -0.95 }, { 0.95, -0.9 } } do
		ball("Dot" .. i, 0.3, dot[1], dot[2], -0.7 - (if dot[2] < -0.6 then 0.2 else 0), options.Dots)
	end

	-- open cardigan: front panels, shoulders, pearls and a white collar
	for _, x in { -1, 1 } do
		add("Cardigan", Vector3.new(0.72, 2.1, 0.12), CFrame.new(x * 0.76, 0.1, -0.68), options.Cardigan)
		add("CardiganInk", Vector3.new(0.06, 2.1, 0.13), CFrame.new(x * 0.39, 0.1, -0.69), INK)
		ball("Shoulder", 0.95, x * 1.05, 0.95, 0, options.Cardigan)
	end
	for i = -3, 3 do
		ball("Pearl", 0.2, i * 0.13, 1.02 - math.abs(i) * -0.025 - (3 - math.abs(i)) * 0.05, -0.7, PEARL)
	end
	add("Collar", Vector3.new(1.5, 0.3, 1.45), CFrame.new(0, 1.22, 0), WHITE)

	-- arms reaching forward: puffy sleeve, lace cuff, forearm, round fist
	for _, x in { -1.35, 1.35 } do
		add("Sleeve", Vector3.new(0.7, 0.7, 1.0), CFrame.new(x, 0.6, -0.35), options.Cardigan)
		add("Cuff", Vector3.new(0.6, 0.6, 0.16), CFrame.new(x, 0.6, -0.92), WHITE)
		add("Forearm", Vector3.new(0.5, 0.5, 0.85), CFrame.new(x, 0.6, -1.3), SKIN)
		ball("Fist", 0.68, x, 0.6, -1.85, SKIN)
	end

	-- legs: stockings and chunky shoes with an ink sole
	if options.Legs ~= false then
		for _, x in { -0.5, 0.5 } do
			add("Leg", Vector3.new(0.68, 1.55, 0.68), CFrame.new(x, -2.0, 0), TIGHTS)
			add("Shoe", Vector3.new(0.85, 0.45, 1.15), CFrame.new(x, -2.75, -0.15), SHOES)
			add("Sole", Vector3.new(0.88, 0.1, 1.18), CFrame.new(x, -2.95, -0.15), INK)
		end
	end

	-- big head
	add("Head", Vector3.new(1.75, 1.7, 1.6), CFrame.new(0, 2.2, 0), SKIN)
	add("Nose", Vector3.new(0.34, 0.42, 0.3), CFrame.new(0, 2.05, -0.92), SKIN_SHADE)
	for _, x in { -1, 1 } do
		add("Cheek", Vector3.new(0.36, 0.22, 0.05), CFrame.new(x * 0.58, 1.85, -0.81), BLUSH)
		-- round glasses: ink ring, lens, angry eye behind it
		add("GlassRing", Vector3.new(0.08, 0.66, 0.66), CFrame.new(x * 0.42, 2.32, -0.84) * FACING_Z, INK, Enum.PartType.Cylinder)
		add("GlassLens", Vector3.new(0.09, 0.52, 0.52), CFrame.new(x * 0.42, 2.32, -0.845) * FACING_Z, LENS, Enum.PartType.Cylinder)
		local eye = ball("Eye", 0.2, x * 0.36, 2.3, -0.86, INK)
		if options.GlowingEyes then
			eye.Size = Vector3.new(0.34, 0.34, 0.34) * s
			eye.Color = Color3.fromRGB(255, 40, 40)
			eye.Material = Enum.Material.Neon
		end
		-- thick angry brow, inner end low
		add("Brow", Vector3.new(0.62, 0.16, 0.1), CFrame.new(x * 0.42, 2.74, -0.83) * CFrame.Angles(0, 0, math.rad(x * 24)), INK)
	end
	add("GlassBridge", Vector3.new(0.22, 0.07, 0.07), CFrame.new(0, 2.36, -0.86), INK)
	-- grumpy mouth with gritted teeth
	add("Mouth", Vector3.new(0.72, 0.3, 0.06), CFrame.new(0, 1.6, -0.81), INK)
	add("Teeth", Vector3.new(0.56, 0.12, 0.07), CFrame.new(0, 1.64, -0.815), WHITE)

	-- curly perm: rings of curls (two grays for a comic shade), back hair and a bun with a hairpin
	for i, curl in {
		{ -0.55, 3.0, -0.45 }, { 0, 3.1, -0.5 }, { 0.55, 3.0, -0.45 },
		{ -0.6, 3.1, 0.2 }, { 0.6, 3.1, 0.2 }, { 0, 3.15, 0.25 },
		{ -0.9, 2.65, -0.15 }, { 0.9, 2.65, -0.15 }, { -0.9, 2.55, 0.5 }, { 0.9, 2.55, 0.5 },
	} do
		ball("Curl", if i <= 6 then 0.8 else 0.62, curl[1], curl[2], curl[3], if i % 2 == 0 then HAIR_SHADE else hair)
	end
	add("HairBack", Vector3.new(1.8, 1.2, 0.35), CFrame.new(0, 2.45, 0.75), hair)
	ball("Bun", 1.0, 0, 3.6, 0.3, hair)
	add("Hairpin", Vector3.new(0.08, 0.08, 1.1), CFrame.new(0.15, 3.7, 0.3) * CFrame.Angles(math.rad(20), math.rad(35), 0), INK)

	-- held items
	if options.Held == "Slipper" then
		add("Slipper", Vector3.new(0.6, 0.25, 1.2), CFrame.new(1.35, 1.1, -2.0) * CFrame.Angles(math.rad(-35), 0, 0), Color3.fromRGB(255, 110, 190))
		add("SlipperSole", Vector3.new(0.62, 0.08, 1.22), CFrame.new(1.35, 0.97, -2.0) * CFrame.Angles(math.rad(-35), 0, 0), INK)
		ball("SlipperFluff", 0.55, 1.35, 1.35, -1.75, Color3.fromRGB(255, 200, 230))
	elseif options.Held == "RollingPin" then
		add("RollingPin", Vector3.new(3.2, 0.75, 0.75), CFrame.new(1.35, 1.6, -1.85) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(214, 156, 92), Enum.PartType.Cylinder)
		for _, y in { 3.55, -0.35 } do
			add("PinHandle", Vector3.new(0.8, 0.36, 0.36), CFrame.new(1.35, y, -1.85) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 98, 52), Enum.PartType.Cylinder)
		end
	elseif options.Held == "Handbag" then
		add("Handbag", Vector3.new(0.4, 0.75, 0.95), CFrame.new(-1.75, 0.0, -1.3), Color3.fromRGB(205, 45, 60))
		add("BagFlap", Vector3.new(0.42, 0.25, 0.97), CFrame.new(-1.75, 0.27, -1.3), Color3.fromRGB(150, 30, 45))
		ball("BagClasp", 0.16, -1.97, 0.18, -1.3, Color3.fromRGB(240, 200, 70))
		add("BagStrap", Vector3.new(0.08, 0.6, 0.08), CFrame.new(-1.62, 0.45, -1.3) * CFrame.Angles(0, 0, math.rad(-25)), INK)
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
		buildGrandma(model, root, {
			Dress = Color3.fromRGB(150, 84, 214),
			Cardigan = Color3.fromRGB(246, 196, 64),
			Dots = Color3.fromRGB(255, 255, 255),
			Held = "Handbag",
		})
	end,
	SlipperGrandma = function(model, root)
		buildGrandma(model, root, {
			Dress = Color3.fromRGB(255, 120, 175),
			Cardigan = Color3.fromRGB(70, 190, 196),
			Dots = Color3.fromRGB(255, 240, 120),
			Held = "Slipper",
		})
	end,
	ScooterGrandma = function(model, root)
		buildGrandma(model, root, {
			Dress = Color3.fromRGB(80, 186, 110),
			Cardigan = Color3.fromRGB(246, 140, 60),
			Dots = Color3.fromRGB(255, 236, 100),
			Legs = false,
		})
		buildScooter(model, root)
	end,
	MegaGrandma = function(model, root)
		buildGrandma(model, root, {
			Dress = Color3.fromRGB(170, 60, 200),
			Cardigan = Color3.fromRGB(196, 40, 50),
			Dots = Color3.fromRGB(255, 160, 220),
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
	hitbox.Size = (def.HitboxSize or Vector3.new(3.6, 7.2, 3.8)) * scale
	hitbox.Transparency = if Config.Debug.ShowHitboxes then 0.75 else 1
	hitbox.Color = Color3.fromRGB(255, 0, 0)
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	hitbox.Massless = true
	local hitboxOffset = CFrame.new((def.HitboxOffset or Vector3.new(0, 0.5, -0.5)) * scale)
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
