--!nonstrict
-- Comic-style vegetation: 6 trees, 8 bushes/hedges, 5 flowers, grass tufts, flower beds.
-- Plants are split over five outline layers, so the client draws ink lines between them:
--   Layers = { FoliageA, FoliageB, Wood, Bloom, Grass }
-- Neighboring leaf masses alternate between FoliageA and FoliageB, which puts a black line between the masses
-- of one canopy; trunks and branches (Wood) get a line against the leaves; petals (Bloom) get a line around
-- them. Grass (blades, stems, small leaves, soil) is not outlined: at a distance its outline would be all you
-- see. Everything is decoration (no collision, no raycasts, no shadow) except tree trunks.
-- Shapes: faceted leaf masses (turned cubes with lumps and pointed leaf tips), tapered bent trunks with root
-- flares and bark grooves, wedge blades and petals. Never plain spheres.

local ComicKit = require(script.Parent.ComicKit)

local K = ComicKit
local C = ComicKit.Colors

local Vegetation = {}

export type Layers = { FoliageA: Instance, FoliageB: Instance, Wood: Instance, Bloom: Instance, Grass: Instance }

Vegetation.Trees = { "Oak", "Maple", "Ornamental", "Evergreen", "Cherry", "Roadside" }
Vegetation.Bushes = { "Round", "Hedge", "Flowering", "Pointed", "Trimmed", "Wild", "Leafy", "Corner" }
Vegetation.Flowers = { "Daisy", "Rose", "Tulip", "Sunflower", "Wildflower" }

-- The vegetation layers from the map's outline groups (MapBuilder names them).
function Vegetation.LayersFrom(groups: { [string]: Model }): Layers
	return { FoliageA = groups.FoliageA, FoliageB = groups.FoliageB, Wood = groups.Wood, Bloom = groups.Flowers, Grass = groups.Grass }
end

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local PALETTE = {
	Maple = rgb(118, 186, 58),
	Ornamental = rgb(196, 62, 84),
	Blossom = rgb(245, 140, 185),
	Evergreen = rgb(40, 132, 80),
	Bark = C.Trunk,
	Soil = rgb(116, 76, 46),
	Petal = rgb(252, 252, 245),
	DaisyCenter = rgb(255, 200, 40),
	Roses = { rgb(225, 40, 60), rgb(255, 120, 160), rgb(255, 220, 90) },
	Tulips = { rgb(255, 70, 90), rgb(255, 200, 50), rgb(255, 130, 40), rgb(200, 90, 220), rgb(252, 252, 245) },
	Sunflower = rgb(255, 205, 30),
	SunflowerCenter = rgb(120, 70, 30),
	Stem = rgb(70, 150, 60),
}
Vegetation.Palette = PALETTE

local function foliage(L: Layers, i: number): Instance
	return if i % 2 == 0 then L.FoliageA else L.FoliageB
end

local function turn(rng: Random): CFrame
	return CFrame.Angles(rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi))
end

------------------------------------------------------------------------------------------------- building blocks

-- Irregular faceted leaf mass: a two-cube gem, `lumps` smaller turned cubes pushed out of its sides and one
-- pointed leaf tip, so no mass (and no silhouette) reads as a ball.
local function leafMass(parent: Instance, center: Vector3, size: number, color: Color3, rng: Random, lumps: number?)
	K.Gem(parent, size, center, color, rng, true)
	for _ = 1, lumps or 1 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dir = Vector3.new(math.cos(angle), rng:NextNumber(-0.3, 0.6), math.sin(angle)).Unit
		local s = size * rng:NextNumber(0.45, 0.6)
		K.Block(parent, Vector3.new(s, s * 0.8, s), CFrame.new(center + dir * size * 0.45) * turn(rng), color, true)
	end
	local angle = rng:NextNumber(0, math.pi * 2)
	local out = Vector3.new(math.cos(angle), rng:NextNumber(-0.2, 0.4), math.sin(angle)).Unit
	local length = size * 0.5
	local root = center + out * size * 0.4
	K.Wedge(parent, Vector3.new(0.2, size * 0.4, length), CFrame.lookAt(root + out * length / 2, root + out * length), color, true)
end

-- Tapered trunk bending a little at every segment, with flared roots and inked bark grooves. `widths` lists
-- the segments bottom first. Returns the CFrame at the top. The bottom segment is solid (bullets hit trunks).
local function trunk(L: Layers, base: CFrame, widths: { number }, segment: number, bend: number, rng: Random, color: Color3?): CFrame
	local bark = color or PALETTE.Bark
	local w0 = widths[1]
	local roots = if w0 > 1.2 then 4 else 3
	for i = 0, roots - 1 do
		local around = base * CFrame.Angles(0, i * math.pi * 2 / roots + rng:NextNumber(-0.3, 0.3), 0)
		K.Wedge(L.Wood, Vector3.new(w0 * 0.45, w0 * 0.7, w0 * 0.8), around * CFrame.new(0, w0 * 0.35, -w0 * 0.9), bark, true)
	end
	local axis = rng:NextNumber(0, math.pi * 2)
	local tilt = CFrame.Angles(bend * math.cos(axis), 0, bend * math.sin(axis))
	local cf = base
	for i, w in widths do
		local part = cf * CFrame.new(0, segment / 2, 0) * CFrame.Angles(0, i * 0.45, 0)
		K.Block(L.Wood, Vector3.new(w, segment + w * 0.3, w), part, bark, i > 1)
		local groove = if i == 1 then C.Ink else K.Dark(bark)
		K.Block(L.Wood, Vector3.new(0.14, segment * 0.7, 0.06), part * CFrame.new((i % 2 - 0.5) * w * 0.4, 0, -w / 2 - 0.02), groove, true)
		cf = cf * CFrame.new(0, segment, 0) * tilt
	end
	return cf
end

-- Branch from `from` along `dir`: a thick base and a thinner tip. Returns the tip.
local function branch(L: Layers, from: Vector3, dir: Vector3, length: number, width: number, color: Color3?): Vector3
	local bark = color or PALETTE.Bark
	local mid = from + dir * length * 0.55
	local tip = from + dir * length
	K.Block(L.Wood, Vector3.new(width, width, length * 0.6), CFrame.lookAt((from + mid) / 2, mid), bark, true)
	K.Block(L.Wood, Vector3.new(width * 0.65, width * 0.65, length * 0.5), CFrame.lookAt((mid + tip) / 2, tip), bark, true)
	return tip
end

local function spread(rng: Random, i: number, count: number, rise: number): Vector3
	local angle = i * math.pi * 2 / count + rng:NextNumber(-0.35, 0.35)
	return Vector3.new(math.cos(angle), rise, math.sin(angle)).Unit
end

------------------------------------------------------------------------------------------------------- trees

local TREES = {}

-- Large suburban oak: thick root-flared trunk, four wide branches, a broad irregular canopy.
function TREES.Oak(L: Layers, base: CFrame, rng: Random, s: number)
	local top = trunk(L, base, { 2.2 * s, 1.8 * s, 1.4 * s }, 2.2 * s, math.rad(5), rng)
	local leaves = C.Leaves[rng:NextInteger(1, #C.Leaves)]
	local fork = top.Position - Vector3.new(0, 0.6 * s, 0)
	for i = 0, 3 do
		local tip = branch(L, fork, spread(rng, i, 4, rng:NextNumber(0.45, 0.75)), rng:NextNumber(4, 5) * s, 0.7 * s)
		leafMass(foliage(L, i), tip + Vector3.new(0, s, 0), rng:NextNumber(4.2, 5) * s, if i == 0 then K.Dark(leaves) else leaves, rng)
	end
	for i, offset in { Vector3.new(1.5, 3.2, 1), Vector3.new(-1.4, 3.6, -1.2) } do
		leafMass(foliage(L, i), top.Position + offset * s, 5.4 * s, K.Light(leaves), rng)
	end
end

-- Tall maple: slim trunk, foliage in three layered tiers getting smaller toward the top.
function TREES.Maple(L: Layers, base: CFrame, rng: Random, s: number)
	local top = trunk(L, base, { 1.6 * s, 1.3 * s, 1.0 * s, 0.8 * s }, 2.4 * s, math.rad(3), rng)
	local leaves = PALETTE.Maple
	local stem = top.Position
	local tiers = { { -3.6, 3, 2.8, 3.8, K.Dark(leaves) }, { -1.2, 3, 2.0, 3.4, leaves }, { 1.2, 1, 0, 3.4, K.Light(leaves) } }
	local n = 0
	for t, tier in tiers do
		local y, count, radius, size, color = tier[1], tier[2], tier[3], tier[4], tier[5]
		for i = 0, count - 1 do
			n += 1
			local dir = spread(rng, i + t * 0.5, count, 0)
			local at = stem + Vector3.new(dir.X * radius, y, dir.Z * radius) * s
			if radius > 0 and t == 1 then
				branch(L, stem + Vector3.new(0, -4.2 * s, 0), (at - (stem + Vector3.new(0, -4.2 * s, 0))).Unit, (at - stem).Magnitude * 0.8, 0.5 * s)
			end
			leafMass(foliage(L, n), at, size * s, color, rng)
		end
	end
end

-- Small ornamental garden tree (red-leaf "Japanese maple"): bent thin trunk, two branches, three small masses.
function TREES.Ornamental(L: Layers, base: CFrame, rng: Random, s: number)
	local top = trunk(L, base, { 0.7 * s, 0.55 * s }, 1.4 * s, math.rad(12), rng)
	local leaves = PALETTE.Ornamental
	local fork = top.Position
	for i = 0, 1 do
		local tip = branch(L, fork, spread(rng, i, 2, 0.6), 1.6 * s, 0.35 * s)
		leafMass(foliage(L, i), tip + Vector3.new(0, 0.4 * s, 0), 2.2 * s, if i == 0 then K.Dark(leaves) else leaves, rng)
	end
	leafMass(L.FoliageA, fork + Vector3.new(0, 1.3 * s, 0), 2.4 * s, K.Light(leaves), rng)
end

-- Tall conical evergreen: five twisted spire tiers in alternating tones with drooping leaf tips.
function TREES.Evergreen(L: Layers, base: CFrame, rng: Random, s: number)
	trunk(L, base, { 1.0 * s, 0.8 * s }, 1.5 * s, 0, rng)
	for i = 0, 4 do
		local width = (7.5 - i * 1.2) * s
		local height = (3.6 - i * 0.25) * s
		local tier = base * CFrame.new(0, (2.2 + i * 2.3) * s, 0) * CFrame.Angles(0, i * 0.4, 0)
		local color = if i % 2 == 0 then PALETTE.Evergreen else K.Light(PALETTE.Evergreen)
		K.Spire(foliage(L, i), width, height, tier, color, true)
		for _, a in { 0.4, 0.4 + math.pi } do
			local tip = tier * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.3 * s, -width * 0.5)
			K.Wedge(foliage(L, i), Vector3.new(0.2, 0.5 * s, 1.0 * s), tip * CFrame.Angles(math.rad(-20), 0, 0), K.Dark(PALETTE.Evergreen), true)
		end
	end
end

-- Rounded flowering tree: four branches, pink blossom masses in three tones, scattered petals.
function TREES.Cherry(L: Layers, base: CFrame, rng: Random, s: number)
	local top = trunk(L, base, { 1.2 * s, 1.0 * s, 0.8 * s }, 1.8 * s, math.rad(8), rng, rgb(110, 70, 60))
	local pink = PALETTE.Blossom
	local fork = top.Position
	for i = 0, 3 do
		local tip = branch(L, fork - Vector3.new(0, 0.4 * s, 0), spread(rng, i, 4, 0.7), 2.6 * s, 0.45 * s, rgb(110, 70, 60))
		leafMass(foliage(L, i), tip + Vector3.new(0, 0.6 * s, 0), 3.4 * s, if i == 0 then K.Dark(pink) else pink, rng)
	end
	leafMass(L.FoliageB, fork + Vector3.new(0, 2.4 * s, 0), 3.8 * s, K.Light(pink), rng)
	for i = 1, 6 do
		local at = fork + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(0.5, 3.5), rng:NextNumber(-3, 3)) * s
		K.Block(L.Bloom, Vector3.new(0.5, 0.08, 0.5) * s, CFrame.new(at) * turn(rng), if i % 2 == 0 then C.Trim else K.Light(pink), true)
	end
	local ground = base.Position
	for i = 1, 4 do
		local angle = i * 1.7
		K.Block(L.Bloom, Vector3.new(0.45, 0.04, 0.45) * s, CFrame.new(ground + Vector3.new(math.cos(angle) * 2.4, 0.03, math.sin(angle) * 2.4) * s) * CFrame.Angles(0, angle, 0), K.Light(pink), true)
	end
end

-- Medium roadside tree: narrow straight trunk, two short branches, a compact upright crown.
function TREES.Roadside(L: Layers, base: CFrame, rng: Random, s: number)
	local top = trunk(L, base, { 0.9 * s, 0.75 * s, 0.6 * s }, 2.0 * s, math.rad(2), rng)
	local leaves = C.Leaves[rng:NextInteger(1, #C.Leaves)]
	local stem = top.Position
	for i = 0, 1 do
		branch(L, stem - Vector3.new(0, 1.2 * s, 0), spread(rng, i, 2, 1.2), 1.6 * s, 0.35 * s)
	end
	leafMass(L.FoliageA, stem + Vector3.new(0, 0.6 * s, 0), 3.6 * s, K.Dark(leaves), rng)
	leafMass(L.FoliageB, stem + Vector3.new(0.3, 2.6 * s, -0.2), 3.3 * s, leaves, rng)
	leafMass(L.FoliageA, stem + Vector3.new(-0.2, 4.3 * s, 0.2), 2.6 * s, K.Light(leaves), rng)
end

-- Tree of `kind` at `position` (spun at random). Returns its trunk radius for enemy obstacles.
function Vegetation.Tree(L: Layers, kind: string, position: Vector3, rng: Random, scale: number?): number
	local s = scale or 1
	TREES[kind](L, CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng, s)
	return if kind == "Oak" then 1.3 * s elseif kind == "Ornamental" then 0.5 * s else 0.9 * s
end

------------------------------------------------------------------------------------------------------ bushes

local BUSHES = {}

-- Dense round decorative bush: a clipped core with four lumps and a lighter top.
function BUSHES.Round(L: Layers, base: CFrame, rng: Random, s: number)
	local leaves = C.Leaves[3]
	K.Gem(L.FoliageA, 2.2 * s, (base * CFrame.new(0, 1.1 * s, 0)).Position, leaves, rng, true)
	for i = 0, 3 do
		local at = base * CFrame.Angles(0, i * math.pi / 2, 0) * CFrame.new(0, 0.9 * s, -0.8 * s)
		K.Block(foliage(L, i + 1), Vector3.new(1.3, 1.1, 1.3) * s, at * turn(rng), if i == 0 then K.Dark(leaves) else leaves, true)
	end
	K.Block(L.FoliageB, Vector3.new(1.4, 1.0, 1.4) * s, base * CFrame.new(0, 1.9 * s, 0) * turn(rng), K.Light(leaves), true)
end

-- Wide irregular hedge bush: four masses of different sizes in a loose row.
function BUSHES.Hedge(L: Layers, base: CFrame, rng: Random, s: number)
	local leaves = C.Leaves[1]
	for i, x in { -2.4, -0.8, 0.9, 2.5 } do
		local size = rng:NextNumber(1.9, 2.6) * s
		leafMass(foliage(L, i), (base * CFrame.new(x * s, size * 0.45, rng:NextNumber(-0.3, 0.3))).Position, size, if i == 2 then K.Light(leaves) else leaves, rng)
	end
end

-- Small flowering shrub (hydrangea): three leaf masses with clusters of four-petal florets.
function BUSHES.Flowering(L: Layers, base: CFrame, rng: Random, s: number)
	local leaves = C.Leaves[1]
	local bloom = PALETTE.Tulips[rng:NextInteger(1, 4)]
	for i = 0, 2 do
		local at = base * CFrame.Angles(0, i * 2.1, 0) * CFrame.new(0, 0.9 * s, -0.6 * s)
		leafMass(foliage(L, i), at.Position, 1.8 * s, if i == 0 then K.Dark(leaves) else leaves, rng, 0)
	end
	for i = 1, 5 do
		local at = base * CFrame.Angles(0, i * 1.26, 0) * CFrame.new(0, (1.7 + (i % 2) * 0.4) * s, -0.9 * s) * CFrame.Angles(0.3, 0, 0)
		for _, a in { 0, math.pi / 2 } do
			K.Block(L.Bloom, Vector3.new(1.0, 0.16, 0.36) * s, at * CFrame.Angles(0, a + i, 0), if i % 2 == 0 then bloom else K.Light(bloom), true)
		end
	end
end

-- Tall pointed ornamental shrub (arborvitae): three stacked, twisted spires.
function BUSHES.Pointed(L: Layers, base: CFrame, _rng: Random, s: number)
	local green = PALETTE.Evergreen
	for i, tier in { { 1.9, 1.7, 0 }, { 1.5, 1.6, 1.1 }, { 1.0, 1.5, 2.1 } } do
		K.Spire(foliage(L, i), tier[1] * s, tier[2] * s, base * CFrame.new(0, tier[3] * s, 0) * CFrame.Angles(0, i * 0.5, 0), if i == 2 then K.Light(green) else green, true)
	end
	K.Block(L.Wood, Vector3.new(0.4, 0.5, 0.4) * s, base * CFrame.new(0, 0.1 * s, 0), PALETTE.Bark, true)
end

-- Flat-topped trimmed hedge `length` long (along X): chamfered top, inked top edges, leafy bumps on both faces
-- and the top.
function Vegetation.TrimmedHedge(L: Layers, cframe: CFrame, length: number, rng: Random, s: number?)
	local scale = s or 1
	local h, d = 2.2 * scale, 1.7 * scale
	local green = C.Leaves[3]
	K.Block(L.FoliageA, Vector3.new(length, h - 0.5, d), cframe * CFrame.new(0, (h - 0.5) / 2, 0), green, true)
	K.Block(L.FoliageA, Vector3.new(length, 0.5, d - 1.0), cframe * CFrame.new(0, h - 0.25, 0), K.Light(green), true)
	for _, side in { -1, 1 } do
		local chamfer = cframe * CFrame.new(0, h - 0.25, side * (d / 2 - 0.25)) * (if side == 1 then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
		K.Wedge(L.FoliageA, Vector3.new(length, 0.5, 0.5), chamfer, K.Light(green), true)
		K.Ink(L.FoliageA, Vector3.new(length, 0.08, 0.08), cframe * CFrame.new(0, h - 0.5, side * d / 2))
	end
	local count = math.max(2, math.floor(length / 1.6))
	for i = 1, count do
		local x = -length / 2 + (i - 0.5) * length / count
		for _, side in { -1, 1 } do
			local bump = cframe * CFrame.new(x + rng:NextNumber(-0.3, 0.3), rng:NextNumber(0.6, h - 0.9), side * (d / 2 + 0.02))
			K.Block(L.FoliageA, Vector3.new(0.7, 0.55, 0.45) * scale, bump * turn(rng), if i % 2 == 0 then K.Dark(green) else K.Light(green), true)
		end
		if i % 2 == 1 then
			K.Block(L.FoliageA, Vector3.new(0.8, 0.45, 0.8) * scale, cframe * CFrame.new(x, h - 0.05, rng:NextNumber(-0.2, 0.2)) * turn(rng), K.Light(green), true)
		end
	end
end

function BUSHES.Trimmed(L: Layers, base: CFrame, rng: Random, s: number)
	Vegetation.TrimmedHedge(L, base, 3.2 * s, rng, s)
end

-- Wild overgrown bush: four lumpy masses, twigs and stray leaf tips sticking out.
function BUSHES.Wild(L: Layers, base: CFrame, rng: Random, s: number)
	local leaves = C.Leaves[2]
	for i = 0, 3 do
		local at = base * CFrame.Angles(0, i * 1.6 + rng:NextNumber(-0.3, 0.3), 0) * CFrame.new(0, rng:NextNumber(0.9, 1.6) * s, -rng:NextNumber(0.6, 1.2) * s)
		leafMass(foliage(L, i), at.Position, rng:NextNumber(1.7, 2.4) * s, if i == 0 then K.Dark(leaves) elseif i == 3 then K.Light(leaves) else leaves, rng, 2)
	end
	for i = 0, 2 do
		branch(L, (base * CFrame.new(0, 0.8 * s, 0)).Position, spread(rng, i, 3, 1.0), 2.4 * s, 0.18 * s)
	end
end

-- Small leafy garden plant (hosta): seven diamond leaves fanning out and cupping upward.
function BUSHES.Leafy(L: Layers, base: CFrame, _rng: Random, s: number)
	local green = C.Leaves[4]
	for i = 0, 6 do
		local leaf = base * CFrame.new(0, 0.4 * s, 0) * CFrame.Angles(0, i * math.pi * 2 / 7, 0) * CFrame.new(0, 0, -0.65 * s)
			* CFrame.Angles(0.5, 0, 0) * CFrame.Angles(0, math.pi / 4, 0)
		K.Block(L.FoliageA, Vector3.new(1.05, 0.08, 1.05) * s, leaf, if i % 3 == 0 then K.Dark(green) else green, true)
	end
	K.Block(L.Grass, Vector3.new(0.3, 0.5, 0.3) * s, base * CFrame.new(0, 0.25 * s, 0), PALETTE.Stem, true)
end

-- Large corner landscaping bush: five big masses and two leafy fronds.
function BUSHES.Corner(L: Layers, base: CFrame, rng: Random, s: number)
	local leaves = C.Leaves[1]
	for i = 0, 4 do
		local at = base * CFrame.Angles(0, i * 1.25, 0) * CFrame.new(0, (if i == 4 then 2.6 else 1.3) * s, -(if i == 4 then 0 else 1.4) * s)
		leafMass(foliage(L, i), at.Position, (if i == 4 then 2.6 else 2.8) * s, if i == 4 then K.Light(leaves) elseif i == 0 then K.Dark(leaves) else leaves, rng)
	end
	BUSHES.Leafy(L, base * CFrame.new(1.9 * s, 0, -1.4 * s), rng, s * 0.8)
end

-- Bush of `kind` at `position` (spun at random). Returns its footprint radius for enemy obstacles.
function Vegetation.Bush(L: Layers, kind: string, position: Vector3, rng: Random, scale: number?): number
	local s = scale or 1
	BUSHES[kind](L, CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng, s)
	local radius = { Round = 1.5, Hedge = 3.4, Flowering = 1.6, Pointed = 1.0, Trimmed = 1.8, Wild = 2.2, Leafy = 0.9, Corner = 2.6 }
	return radius[kind] * s
end

----------------------------------------------------------------------------------------------------- flowers

local function stem(L: Layers, ground: Vector3, height: number, width: number)
	K.Block(L.Grass, Vector3.new(width, height, width), CFrame.new(ground + Vector3.new(0, height / 2, 0)), PALETTE.Stem, true)
end

-- Flat diamond leaf at `height` up a stem, pointing toward `angle` and tilted up.
local function leaf(L: Layers, ground: Vector3, height: number, angle: number, size: number)
	local cf = CFrame.new(ground + Vector3.new(0, height, 0)) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -size * 0.45) * CFrame.Angles(0.45, 0, 0) * CFrame.Angles(0, math.pi / 4, 0)
	K.Block(L.Grass, Vector3.new(size * 0.7, 0.05, size * 0.7), cf, C.Leaves[1], true)
end

local FLOWERS = {}

-- Daisy: six white petals (three crossing petal strips) around a yellow center.
function FLOWERS.Daisy(L: Layers, ground: Vector3, rng: Random)
	local h = rng:NextNumber(0.9, 1.3)
	stem(L, ground, h, 0.1)
	leaf(L, ground, h * 0.35, rng:NextNumber(0, math.pi * 2), 0.6)
	local head = CFrame.new(ground + Vector3.new(0, h, 0)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), 0)
	for i = 0, 2 do
		K.Block(L.Bloom, Vector3.new(1.0, 0.07, 0.24), head * CFrame.Angles(0, i * math.pi / 3, 0), PALETTE.Petal, true)
	end
	K.Block(L.Bloom, Vector3.new(0.34, 0.2, 0.34), head * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, math.pi / 4, 0), PALETTE.DaisyCenter, true)
end

-- Rose: faceted bud (a petal gem with a lighter twisted heart on top), a leaf on the stem.
function FLOWERS.Rose(L: Layers, ground: Vector3, rng: Random, color: Color3?)
	local h = rng:NextNumber(1.0, 1.4)
	local red = color or PALETTE.Roses[1]
	stem(L, ground, h, 0.1)
	leaf(L, ground, h * 0.45, rng:NextNumber(0, math.pi * 2), 0.6)
	local head = CFrame.new(ground + Vector3.new(0, h, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	K.Gem(L.Bloom, 0.55, (head * CFrame.new(0, 0.25, 0)).Position, red, rng, true)
	K.Block(L.Bloom, Vector3.new(0.3, 0.3, 0.3), head * CFrame.new(0, 0.5, 0) * CFrame.Angles(0.6, 0.8, 0), K.Light(red), true)
end

-- Tulip: four pointed petals (two crossing petal prisms) around a dark cup, a long blade leaf.
function FLOWERS.Tulip(L: Layers, ground: Vector3, rng: Random, color: Color3?)
	local h = rng:NextNumber(1.0, 1.4)
	local petal = color or PALETTE.Tulips[rng:NextInteger(1, #PALETTE.Tulips)]
	stem(L, ground, h, 0.1)
	local spin = rng:NextNumber(0, math.pi)
	K.Wedge(L.Grass, Vector3.new(0.06, h * 0.65, 0.3), CFrame.new(ground) * CFrame.Angles(0, spin, 0) * CFrame.new(0, h * 0.32, 0.12) * CFrame.Angles(0.2, 0, 0), C.Leaves[2], true)
	local head = CFrame.new(ground + Vector3.new(0, h, 0)) * CFrame.Angles(0, spin, 0)
	K.Block(L.Bloom, Vector3.new(0.3, 0.3, 0.3), head * CFrame.new(0, 0.12, 0), K.Dark(petal), true)
	for _, a in { 0, math.pi / 2 } do
		K.Prism(L.Bloom, 0.14, 0.5, 0.6, head * CFrame.Angles(0, a, 0), petal, true)
	end
end

-- Sunflower: tall stem, two big blade leaves, a brown disc facing `facing` (or a random way) with eight
-- petal tips around it.
function FLOWERS.Sunflower(L: Layers, ground: Vector3, rng: Random, _color: Color3?, facing: Vector3?)
	local h = rng:NextNumber(3.0, 3.6)
	stem(L, ground, h - 0.45, 0.2)
	local spin = rng:NextNumber(0, math.pi * 2)
	for i, y in { 0.35, 0.6 } do
		local a = spin + i * math.pi
		K.Wedge(L.Grass, Vector3.new(0.06, 0.9, 0.8), CFrame.new(ground) * CFrame.Angles(0, a, 0) * CFrame.new(0, h * y, 0.45) * CFrame.Angles(0.5, 0, 0), C.Leaves[1], true)
	end
	local top = ground + Vector3.new(0, h, 0)
	local look = if facing then CFrame.lookAt(top, top + Vector3.new(facing.X, 0, facing.Z)) else CFrame.new(top) * CFrame.Angles(0, spin, 0)
	local head = look * CFrame.Angles(0.25, rng:NextNumber(-0.3, 0.3), 0)
	for i = 0, 3 do
		K.Block(L.Bloom, Vector3.new(2.0, 0.32, 0.06), head * CFrame.new(0, 0, 0.05) * CFrame.Angles(0, 0, i * math.pi / 4), PALETTE.Sunflower, true)
	end
	K.Cylinder(L.Bloom, Vector3.new(0.25, 1.0, 1.0), head * CFrame.Angles(0, math.pi / 2, 0), PALETTE.SunflowerCenter, true)
	K.Cylinder(L.Grass, Vector3.new(0.2, 0.8, 0.8), head * CFrame.new(0, 0, 0.2) * CFrame.Angles(0, math.pi / 2, 0), C.Leaves[3], true)
end

-- Wildflowers: a patch of three tiny star blooms on thin stems.
function FLOWERS.Wildflower(L: Layers, ground: Vector3, rng: Random)
	for i = 1, 3 do
		local angle = i * 2.1
		local at = ground + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(0.2, 0.7)
		local h = rng:NextNumber(0.4, 0.8)
		K.Block(L.Grass, Vector3.new(0.06, h, 0.06), CFrame.new(at + Vector3.new(0, h / 2, 0)), PALETTE.Stem, true)
		K.Block(L.Bloom, Vector3.new(0.32, 0.05, 0.32), CFrame.new(at + Vector3.new(0, h, 0)) * CFrame.Angles(0, angle, 0) * CFrame.Angles(0, math.pi / 4, 0), PALETTE.Tulips[i % #PALETTE.Tulips + 1], true)
	end
end

-- Flower of `kind`; `facing` turns a sunflower's head (others ignore it).
function Vegetation.Flower(L: Layers, kind: string, ground: Vector3, rng: Random, color: Color3?, facing: Vector3?)
	FLOWERS[kind](L, ground, rng, color, facing)
end

------------------------------------------------------------------------------------------------ grass, beds

-- Grass tuft: four pointed blades leaning out of a clump, in two greens.
function Vegetation.Grass(L: Layers, ground: Vector3, rng: Random, scale: number?)
	local s = scale or 1
	local spin = rng:NextNumber(0, math.pi * 2)
	for i = 0, 3 do
		local h = rng:NextNumber(0.7, 1.2) * s
		local blade = CFrame.new(ground) * CFrame.Angles(0, spin + i * math.pi / 2, 0) * CFrame.new(0, h / 2, 0.12 * s) * CFrame.Angles(rng:NextNumber(0.15, 0.45), 0, 0)
		K.Wedge(L.Grass, Vector3.new(0.07, h, 0.38 * s), blade, if i % 2 == 0 then C.Leaves[2] else K.Light(C.Leaves[2]), true)
	end
end

-- Straight garden bed from `from` to `to` (ground points): a soil strip with flowers planted every 1.4 studs,
-- cycling through `mix` (flower kinds), zig-zagging a little across the strip.
function Vegetation.Bed(L: Layers, from: Vector3, to: Vector3, mix: { string }, rng: Random)
	local length = (to - from).Magnitude
	local frame = CFrame.lookAt(from, to)
	K.Block(L.Grass, Vector3.new(1.3, 0.12, length + 0.6), frame * CFrame.new(0, 0.06, -length / 2), PALETTE.Soil, true)
	local count = math.max(1, math.floor(length / 1.4))
	for i = 0, count do
		local at = frame * CFrame.new((i % 2 - 0.5) * 0.4, 0.12, -i * length / count)
		local kind = mix[i % #mix + 1]
		Vegetation.Flower(L, kind, at.Position, rng)
	end
end

-- Round park flower bed: octagon of stones around soil, a pointed shrub in the middle (left out when
-- `centerpiece` is set: a statue stands there instead), a ring of mixed flowers.
function Vegetation.FlowerBed(L: Layers, position: Vector3, rng: Random, centerpiece: boolean?)
	for i = 0, 7 do
		local stone = CFrame.new(position) * CFrame.Angles(0, i * math.pi / 4, 0) * CFrame.new(0, 0.3, -3.2)
		K.Block(L.Wood, Vector3.new(2.8, 0.6, 0.7), stone, C.Stone, true)
	end
	K.Disc(L.Grass, 6.2, 0.4, position, PALETTE.Soil, true)
	if not centerpiece then
		BUSHES.Pointed(L, CFrame.new(position + Vector3.new(0, 0.4, 0)), rng, 0.8)
	end
	local mix = { "Tulip", "Daisy", "Rose", "Tulip", "Daisy", "Rose", "Tulip" }
	for i, kind in mix do
		local angle = i * math.pi * 2 / #mix
		Vegetation.Flower(L, kind, position + Vector3.new(math.cos(angle) * 2.1, 0.4, math.sin(angle) * 2.1), rng)
	end
end

return Vegetation
