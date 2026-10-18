--!nonstrict
-- Builds lightweight enemy models: plain Parts welded to one anchored Root. No Humanoid, no scripts.
-- EnemyService moves only the Root; the welds carry every other part along.
-- Only the invisible "Hitbox" part is queryable, so bullet raycasts stay cheap and hits are forgiving.

local EnemyFactory = {}

local SKIN = Color3.fromRGB(247, 190, 132)
local HAIR = Color3.fromRGB(190, 190, 200)
local DARK = Color3.fromRGB(25, 25, 30)

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

-- Blocky Roblox-style grandma: bun, glasses, angry brows, flowery dress, arms stretched forward.
-- Front is -Z. Root origin = dress center; feet are at -RootHeight (RootHeight = 3).
local function buildGrandma(model: Model, root: BasePart, dressColor: Color3, hairColor: Color3)
	root.Size = Vector3.new(2.2, 2.4, 1.3)
	root.Color = dressColor

	-- legs
	addPart(model, root, "LegL", Vector3.new(0.7, 1.8, 0.7), CFrame.new(-0.5, -2.1, 0), Color3.fromRGB(230, 205, 175))
	addPart(model, root, "LegR", Vector3.new(0.7, 1.8, 0.7), CFrame.new(0.5, -2.1, 0), Color3.fromRGB(230, 205, 175))
	-- white collar + apron-like flowers
	addPart(model, root, "Collar", Vector3.new(1.7, 0.3, 1.5), CFrame.new(0, 1.2, 0), Color3.fromRGB(250, 250, 250))
	for i, x in { -0.6, 0.55, -0.1 } do
		addPart(model, root, "Flower" .. i, Vector3.new(0.4, 0.4, 0.05), CFrame.new(x, 0.1 - i * 0.3, -0.68), Color3.fromRGB(255, 150, 200))
	end

	-- head
	addPart(model, root, "Head", Vector3.new(1.5, 1.5, 1.5), CFrame.new(0, 2.0, 0), SKIN)
	-- hair: top cap, back, bun
	addPart(model, root, "HairTop", Vector3.new(1.6, 0.45, 1.6), CFrame.new(0, 2.9, 0), hairColor)
	addPart(model, root, "HairBack", Vector3.new(1.6, 1.3, 0.35), CFrame.new(0, 2.3, 0.65), hairColor)
	addPart(model, root, "HairSideL", Vector3.new(0.3, 0.9, 1.5), CFrame.new(-0.8, 2.45, 0), hairColor)
	addPart(model, root, "HairSideR", Vector3.new(0.3, 0.9, 1.5), CFrame.new(0.8, 2.45, 0), hairColor)
	addPart(model, root, "Bun", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 3.35, 0.2), hairColor, Enum.PartType.Ball)

	-- glasses (frames + dark eyes)
	for _, x in { -0.38, 0.38 } do
		addPart(model, root, "GlassFrame", Vector3.new(0.58, 0.42, 0.06), CFrame.new(x, 2.05, -0.77), DARK)
		addPart(model, root, "GlassLens", Vector3.new(0.44, 0.28, 0.07), CFrame.new(x, 2.05, -0.78), Color3.fromRGB(215, 235, 250))
		addPart(model, root, "Eye", Vector3.new(0.13, 0.17, 0.08), CFrame.new(x, 2.03, -0.8), DARK)
	end
	addPart(model, root, "GlassBridge", Vector3.new(0.2, 0.07, 0.06), CFrame.new(0, 2.1, -0.77), DARK)
	-- angry brows: inner ends low (V shape)
	addPart(model, root, "BrowL", Vector3.new(0.6, 0.1, 0.08), CFrame.new(-0.4, 2.42, -0.77) * CFrame.Angles(0, 0, math.rad(-22)), DARK)
	addPart(model, root, "BrowR", Vector3.new(0.6, 0.1, 0.08), CFrame.new(0.4, 2.42, -0.77) * CFrame.Angles(0, 0, math.rad(22)), DARK)
	-- frown
	addPart(model, root, "Mouth", Vector3.new(0.5, 0.12, 0.07), CFrame.new(0, 1.5, -0.77), Color3.fromRGB(120, 30, 40))

	-- arms stretched forward (-Z)
	addPart(model, root, "ArmL", Vector3.new(0.5, 0.5, 1.7), CFrame.new(-1.35, 0.6, -0.9), SKIN)
	addPart(model, root, "ArmR", Vector3.new(0.5, 0.5, 1.7), CFrame.new(1.35, 0.6, -0.9), SKIN)
	addPart(model, root, "SleeveL", Vector3.new(0.6, 0.6, 0.6), CFrame.new(-1.35, 0.6, -0.1), dressColor)
	addPart(model, root, "SleeveR", Vector3.new(0.6, 0.6, 0.6), CFrame.new(1.35, 0.6, -0.1), dressColor)
end

local BUILDERS = {
	NormalGrandma = function(model, root)
		buildGrandma(model, root, Color3.fromRGB(142, 79, 208), HAIR)
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
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = Vector3.new(2.8, 6.6, 2.4)
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	hitbox.Massless = true
	local hitboxOffset = CFrame.new(0, 0.3, 0)
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
