--!nonstrict
-- Comic-book art kit for the generated map (used by Props and MapBuilder): one palette, flat cel-shaded
-- parts and black "ink". Ink comes two ways:
--   * Silhouettes: props go into a few outline-group Models (`OutlineGroup`); the client's OutlineController
--     gives each group ONE outline-only Highlight. Roblox draws at most 31 Highlights at once, so it is one
--     per group, never one per prop.
--   * Inner lines: black plates behind windows, doors and signs, and thin black bars on important edges.
-- Shapes stay low poly but are shaped on purpose: wedges, tilted slabs, twisted segments and two-cube "gems".

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local ComicKit = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local INK = Config.Comic.InkColor
local WHITE = Color3.new(1, 1, 1)

ComicKit.Colors = {
	Ink = INK,
	Grass = rgb(104, 196, 72),
	GrassLight = rgb(126, 212, 86),
	Road = rgb(58, 60, 68),
	RoadLine = rgb(255, 210, 60),
	RoadEdge = rgb(245, 245, 238),
	Curb = rgb(168, 164, 156),
	Sidewalk = rgb(216, 208, 194),
	SidewalkJoint = rgb(178, 170, 156),
	Path = rgb(234, 208, 160),
	Stone = rgb(198, 190, 176),
	Trim = rgb(252, 250, 242),
	Walls = {
		rgb(132, 188, 236), -- pastel blue
		rgb(222, 92, 80), -- warm red
		rgb(246, 232, 196), -- cream
		rgb(252, 212, 92), -- yellow
		rgb(246, 152, 72), -- orange
		rgb(150, 196, 140), -- muted green
	},
	Roofs = {
		rgb(46, 62, 110), -- navy
		rgb(62, 64, 72), -- charcoal
		rgb(98, 64, 44), -- dark brown
		rgb(170, 62, 50), -- brick red
	},
	Doors = { rgb(196, 52, 46), rgb(40, 70, 130), rgb(46, 120, 80), rgb(150, 92, 50) },
	Leaves = { rgb(74, 176, 64), rgb(98, 200, 72), rgb(56, 150, 70), rgb(124, 208, 84) },
	Pine = { rgb(38, 128, 78), rgb(52, 150, 88) },
	Trunk = rgb(128, 82, 46),
	Wood = rgb(178, 108, 56),
	WoodLight = rgb(214, 144, 78),
	Metal = rgb(150, 158, 172),
	MetalDark = rgb(70, 76, 90),
	Glass = rgb(150, 214, 250),
	GlassShine = rgb(240, 252, 255),
	Brick = rgb(184, 78, 58),
	Water = rgb(72, 190, 255),
	Flowers = { rgb(255, 90, 130), rgb(255, 222, 60), rgb(176, 110, 255), rgb(255, 255, 255), rgb(255, 140, 60) },
	Cars = { rgb(230, 60, 60), rgb(60, 140, 230), rgb(255, 196, 40), rgb(90, 200, 120), rgb(250, 250, 245), rgb(150, 90, 210) },
	SpawnMark = rgb(255, 60, 60),
}

-- The 3 cel tones of a color: Light (lit tops), the color itself, Dark (undersides, lines, insets).
function ComicKit.Light(color: Color3): Color3
	return color:Lerp(WHITE, 0.22)
end

function ComicKit.Dark(color: Color3): Color3
	return color:Lerp(INK, 0.3)
end

-- Every map part: anchored, flat plastic (no texture noise), no touch events.
-- deco = pure decoration: no collision, invisible to raycasts, casts no shadow (cheaper; small details).
local function finish(part: BasePart, parent: Instance, size: Vector3, cframe: CFrame, color: Color3, deco: boolean?): BasePart
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanTouch = false
	if deco then
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
	end
	part.Parent = parent
	return part
end

function ComicKit.Block(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, deco: boolean?): BasePart
	return finish(Instance.new("Part"), parent, size, cframe, color, deco)
end

-- WedgePart: full height at its back (+Z), the slope faces front (-Z) and up.
function ComicKit.Wedge(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, deco: boolean?): BasePart
	return finish(Instance.new("WedgePart"), parent, size, cframe, color, deco)
end

-- Cylinder along the part's X axis (wheels, discs, clock faces).
function ComicKit.Cylinder(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, deco: boolean?): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	return finish(part, parent, size, cframe, color, deco)
end

-- Flat disc lying on the ground, centered on `position` (its bottom at position.Y).
function ComicKit.Disc(parent: Instance, diameter: number, thickness: number, position: Vector3, color: Color3, deco: boolean?): BasePart
	local cframe = CFrame.new(position + Vector3.new(0, thickness / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return ComicKit.Cylinder(parent, Vector3.new(thickness, diameter, diameter), cframe, color, deco)
end

function ComicKit.Ink(parent: Instance, size: Vector3, cframe: CFrame): BasePart
	return ComicKit.Block(parent, size, cframe, INK, true)
end

-- Low-poly blob (foliage, rocks): two cubes turned against each other read as one faceted shape.
function ComicKit.Gem(parent: Instance, size: number, center: Vector3, color: Color3, rng: Random, deco: boolean?)
	local turn = CFrame.new(center) * CFrame.Angles(rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi))
	ComicKit.Block(parent, Vector3.new(size, size * 0.8, size), turn, color, deco)
	ComicKit.Block(parent, Vector3.one * size * 0.82, turn * CFrame.Angles(math.rad(45), math.rad(35), 0), color, deco)
end

-- Triangular prism (roof, pediment, pine tier): ridge along local X, `height` above `cframe`, `depth` wide in Z.
function ComicKit.Prism(parent: Instance, width: number, depth: number, height: number, cframe: CFrame, color: Color3, deco: boolean?)
	local size = Vector3.new(width, height, depth / 2)
	ComicKit.Wedge(parent, size, cframe * CFrame.new(0, height / 2, -depth / 4), color, deco)
	ComicKit.Wedge(parent, size, cframe * CFrame.new(0, height / 2, depth / 4) * CFrame.Angles(0, math.pi, 0), color, deco)
end

-- Four-sided spire (tower roofs, lamp caps, pine tiers): two crossed prisms.
function ComicKit.Spire(parent: Instance, width: number, height: number, cframe: CFrame, color: Color3, deco: boolean?)
	ComicKit.Prism(parent, width, width, height, cframe, color, deco)
	ComicKit.Prism(parent, width, width, height, cframe * CFrame.Angles(0, math.pi / 2, 0), color, deco)
end

-- Flat detail on a surface (glass, door, sign): a black plate `ink` studs bigger on every side behind a
-- colored plate. `cframe` sits on the surface with LookVector = outward. Returns the colored plate,
-- whose front is 0.1 + depth in front of the surface.
function ComicKit.Panel(parent: Instance, width: number, height: number, cframe: CFrame, color: Color3, ink: number?, depth: number?): BasePart
	local line = ink or Config.Comic.InkWidth
	local thick = depth or 0.15
	ComicKit.Ink(parent, Vector3.new(width + line * 2, height + line * 2, 0.1), cframe * CFrame.new(0, 0, -0.05))
	return ComicKit.Block(parent, Vector3.new(width, height, thick), cframe * CFrame.new(0, 0, -0.1 - thick / 2), color, true)
end

-- Window: inked white frame, glass with a comic glint, cross bars, sill, optional shutters.
-- `cframe` = center on the wall, LookVector = outward.
function ComicKit.Window(parent: Instance, cframe: CFrame, width: number, height: number, shutterColor: Color3?)
	local C = ComicKit.Colors
	ComicKit.Panel(parent, width + 0.5, height + 0.5, cframe, C.Trim, nil, 0.15)
	local glass = cframe * CFrame.new(0, 0, -0.25)
	ComicKit.Block(parent, Vector3.new(width, height, 0.1), glass * CFrame.new(0, 0, -0.05), C.Glass, true)
	ComicKit.Block(parent, Vector3.new(0.3, height * 0.55, 0.06), glass * CFrame.new(-width * 0.22, height * 0.1, -0.13) * CFrame.Angles(0, 0, math.rad(-30)), C.GlassShine, true)
	ComicKit.Block(parent, Vector3.new(0.22, height, 0.16), glass * CFrame.new(0, 0, -0.12), C.Trim, true)
	ComicKit.Block(parent, Vector3.new(width, 0.22, 0.16), glass * CFrame.new(0, 0, -0.12), C.Trim, true)
	ComicKit.Block(parent, Vector3.new(width + 1.2, 0.35, 0.7), cframe * CFrame.new(0, -height / 2 - 0.6, -0.35), C.Trim, true)
	if shutterColor then
		for _, side in { -1, 1 } do
			local x = side * (width / 2 + 0.75 + width * 0.19)
			ComicKit.Panel(parent, width * 0.38, height + 0.3, cframe * CFrame.new(x, 0, 0), shutterColor, 0.15, 0.15)
		end
	end
end

-- Door with frame, two inset panels and a brass knob. `cframe` = bottom center on the wall, LookVector = outward.
function ComicKit.Door(parent: Instance, cframe: CFrame, width: number, height: number, color: Color3)
	ComicKit.Panel(parent, width + 0.6, height + 0.3, cframe * CFrame.new(0, (height + 0.3) / 2, 0), ComicKit.Colors.Trim, nil, 0.15)
	local door = cframe * CFrame.new(0, height / 2, -0.25)
	ComicKit.Block(parent, Vector3.new(width, height, 0.15), door * CFrame.new(0, 0, -0.075), color, true)
	for _, y in { 0.2, -0.2 } do
		ComicKit.Block(parent, Vector3.new(width * 0.6, height * 0.28, 0.08), door * CFrame.new(0, y * height, -0.19), ComicKit.Dark(color), true)
	end
	ComicKit.Block(parent, Vector3.new(0.35, 0.35, 0.3), door * CFrame.new(width * 0.33, -0.02 * height, -0.3), Color3.fromRGB(255, 205, 70), true)
end

-- Thin ink bars on the 4 vertical edges of a box (inner corners a silhouette outline cannot show).
function ComicKit.InkCorners(parent: Instance, cframe: CFrame, size: Vector3)
	local w = Config.Comic.InkWidth
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			ComicKit.Ink(parent, Vector3.new(w, size.Y, w), cframe * CFrame.new(sx * size.X / 2, 0, sz * size.Z / 2))
		end
	end
end

-- A Model whose silhouettes the client outlines with one Highlight (see OutlineController).
function ComicKit.OutlineGroup(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	CollectionService:AddTag(model, Config.Comic.OutlineTag)
	model.Parent = parent
	return model
end

-- Empty model for one prop (parts are built straight at their world positions).
function ComicKit.Model(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	return model
end

return ComicKit
