--!nonstrict
-- Comic-style streets: asphalt with black borders, white edge lines, yellow center lines, cracks, patches,
-- manholes and storm drains; raised sidewalks with curbs, slab joints (every other one inked), cracks, corner
-- ramps and sloped driveway aprons; triangular corner pieces that chamfer ("round") street corners;
-- crosswalks; garden stepping stones.
-- Layers = { Road, Walk } are two outline groups, so the client draws a black line wherever curb meets asphalt.
-- Positions are ground points; a road or sidewalk runs from `a` to `b` along its center line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local ComicKit = require(script.Parent.ComicKit)

local K = ComicKit
local C = ComicKit.Colors

local Streets = {}

export type Layers = { Road: Instance, Walk: Instance }

local ROAD_Y = 0.1 -- asphalt top
local WALK_Y = 0.4 -- sidewalk top
local LINE = 0.03 -- painted / inked line thickness
Streets.RoadHeight = ROAD_Y
Streets.WalkHeight = WALK_Y

local TACTILE = Color3.fromRGB(255, 200, 40)

-- CFrame helper along a straight piece: x across (local X of lookAt), y up, t = distance from `a`.
local function along(a: Vector3, b: Vector3): ((x: number, y: number, t: number) -> CFrame, number)
	local frame = CFrame.lookAt(a, b)
	return function(x, y, t)
		return frame * CFrame.new(x, y, -t)
	end, (b - a).Magnitude
end

------------------------------------------------------------------------------------------------- surface details

-- Hand-drawn crack: a zig-zag of three ink strokes with a short branch, lying on a surface (`cf` on it).
function Streets.Crack(parent: Instance, cf: CFrame, rng: Random, scale: number?)
	local s = scale or 1
	local heading = rng:NextNumber(0, math.pi * 2)
	local p = Vector3.zero
	local branchFrom = nil
	for i = 1, 3 do
		heading += if i % 2 == 0 then 0.7 else -0.6
		local q = p + Vector3.new(math.cos(heading), 0, math.sin(heading)) * rng:NextNumber(0.8, 1.4) * s
		local a, b = (cf * CFrame.new(p.X, LINE * 0.7, p.Z)).Position, (cf * CFrame.new(q.X, LINE * 0.7, q.Z)).Position
		K.Block(parent, Vector3.new(0.12 * s, LINE * 1.4, (b - a).Magnitude + 0.08), CFrame.lookAt((a + b) / 2, b), C.Ink, true)
		if i == 2 then
			branchFrom = q
		end
		p = q
	end
	local twig = branchFrom + Vector3.new(math.cos(heading + 1.6), 0, math.sin(heading + 1.6)) * 0.7 * s
	local a, b = (cf * CFrame.new(branchFrom.X, LINE * 0.7, branchFrom.Z)).Position, (cf * CFrame.new(twig.X, LINE * 0.7, twig.Z)).Position
	K.Block(parent, Vector3.new(0.09 * s, LINE * 1.4, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), C.Ink, true)
end

-- Asphalt patch: a lighter rectangle with an inked border (`cf` on the road surface).
function Streets.Patch(parent: Instance, cf: CFrame, rng: Random)
	local w, d = rng:NextNumber(2, 3), rng:NextNumber(1.5, 2.2)
	K.Block(parent, Vector3.new(w, LINE, d), cf * CFrame.new(0, LINE / 2, 0), C.Road:Lerp(Color3.new(1, 1, 1), 0.12), true)
	for _, s in { -1, 1 } do
		K.Block(parent, Vector3.new(w + 0.1, LINE * 1.3, 0.1), cf * CFrame.new(0, LINE * 0.65, s * d / 2), C.Ink, true)
		K.Block(parent, Vector3.new(0.1, LINE * 1.3, d), cf * CFrame.new(s * w / 2, LINE * 0.65, 0), C.Ink, true)
	end
end

-- Manhole cover: inked rim, metal lid, cross ribs.
function Streets.Manhole(parent: Instance, position: Vector3)
	K.Disc(parent, 2.9, LINE * 1.2, position, C.Ink, true)
	K.Disc(parent, 2.5, LINE * 1.6, position, C.MetalDark, true)
	for _, a in { 0, math.pi / 2 } do
		K.Block(parent, Vector3.new(2.0, LINE * 2, 0.14), CFrame.new(position + Vector3.new(0, LINE * 1.6, 0)) * CFrame.Angles(0, a + 0.4, 0), C.Ink, true)
	end
end

-- Storm drain grate at the curb (`cf` on the road surface, local Z along the road).
function Streets.Drain(parent: Instance, cf: CFrame)
	K.Block(parent, Vector3.new(0.9, LINE, 1.8), cf * CFrame.new(0, LINE / 2, 0), C.MetalDark, true)
	for i = -1, 1 do
		K.Block(parent, Vector3.new(0.9, LINE * 1.6, 0.12), cf * CFrame.new(0, LINE * 0.8, i * 0.45), C.Ink, true)
	end
	K.Block(parent, Vector3.new(0.12, LINE * 1.6, 1.9), cf * CFrame.new(0, LINE * 0.8, 0), C.Ink, true)
end

-- Garden stepping stone: an irregular flat octagon (two turned slabs) in two stone tones.
function Streets.Stone(parent: Instance, position: Vector3, rng: Random, size: number?)
	local s = size or 1.3
	local spin = CFrame.new(position + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	K.Block(parent, Vector3.new(s * rng:NextNumber(0.9, 1.15), 0.16, s), spin, C.Stone, true)
	K.Block(parent, Vector3.new(s * 0.8, 0.17, s * rng:NextNumber(0.75, 0.95)), spin * CFrame.Angles(0, math.pi / 4, 0), K.Light(C.Stone), true)
end

------------------------------------------------------------------------------------------------------- roads

-- Straight road `width` wide from a to b. Options: Center ("Dashed" | "Double" | nil), Edges (white edge lines,
-- default on), Details (cracks, patches, manholes, drains; default on, skipped without Config.Comic.SmallDetails).
function Streets.Road(L: Layers, a: Vector3, b: Vector3, width: number, rng: Random, o: { [string]: any }?)
	local opt = o or {}
	local at, len = along(a, b)
	K.Block(L.Road, Vector3.new(width, ROAD_Y, len), at(0, ROAD_Y / 2, len / 2), C.Road)
	for _, s in { -1, 1 } do
		K.Block(L.Road, Vector3.new(0.3, LINE, len), at(s * (width / 2 - 0.15), ROAD_Y + LINE / 2, len / 2), C.Ink, true)
		if opt.Edges ~= false and len > 3 then
			K.Block(L.Road, Vector3.new(0.3, LINE, len - 2), at(s * (width / 2 - 1.0), ROAD_Y + LINE / 2, len / 2), C.RoadEdge, true)
		end
	end
	if opt.Center == "Double" then
		for _, s in { -1, 1 } do
			K.Block(L.Road, Vector3.new(0.22, LINE, len - 2), at(s * 0.25, ROAD_Y + LINE / 2, len / 2), C.RoadLine, true)
		end
	elseif opt.Center == "Dashed" then
		for t = 4, len - 3, 8 do
			K.Block(L.Road, Vector3.new(0.3, LINE, 4), at(0, ROAD_Y + LINE / 2, t), C.RoadLine, true)
		end
	end
	if opt.Details == false or not Config.Comic.SmallDetails then
		return
	end
	local count = math.floor(len / 28)
	for i = 1, count do
		local t = (i - 0.5) * len / count + rng:NextNumber(-3, 3)
		local side = if i % 2 == 0 then 1 else -1
		local kind = i % 4
		if kind == 1 then
			Streets.Crack(L.Road, at(side * width * rng:NextNumber(0.12, 0.3), ROAD_Y, t), rng)
		elseif kind == 2 then
			Streets.Patch(L.Road, at(side * width * rng:NextNumber(0.12, 0.25), ROAD_Y, t) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), rng)
		elseif kind == 3 then
			Streets.Manhole(L.Road, at(side * width * 0.2, ROAD_Y, t).Position)
		else
			Streets.Drain(L.Road, at(side * (width / 2 - 0.75), ROAD_Y, t))
		end
	end
end

-- Flat right triangle (thickness `h`, legs `r`) with its right angle at `corner` (ground point) and legs along
-- the horizontal unit vectors dirA and dirB, standing from y0 to y0 + h.
local function triangle(parent: Instance, corner: Vector3, dirA: Vector3, dirB: Vector3, r: number, y0: number, h: number, color: Color3, deco: boolean?)
	local center = corner + (dirA + dirB) * (r / 2) + Vector3.new(0, y0 + h / 2, 0)
	local frame = CFrame.fromMatrix(center, dirB:Cross(dirA), dirA, -dirB)
	K.Wedge(parent, Vector3.new(h, r, r), frame, color, deco)
end

-- Corner piece that chamfers ("rounds") a street corner: a sidewalk triangle with a curb and ink along its long
-- side, and the matching asphalt triangle on the road side. `corner` = the sidewalk's back corner (away from
-- the road), dirA/dirB = unit directions from there along the two curbs, `r` = sidewalk width.
function Streets.Corner(L: Layers, corner: Vector3, dirA: Vector3, dirB: Vector3, r: number)
	triangle(L.Walk, corner, dirA, dirB, r, 0, WALK_Y, C.Sidewalk)
	triangle(L.Road, corner + (dirA + dirB) * r, -dirA, -dirB, r, 0, ROAD_Y, C.Road)
	local p, q = corner + dirA * r, corner + dirB * r
	local inward = -(dirA + dirB).Unit * 0.25
	local mid = (p + q) / 2 + inward + Vector3.new(0, (WALK_Y + 0.06) / 2, 0)
	K.Block(L.Walk, Vector3.new(0.5, WALK_Y + 0.06, (q - p).Magnitude), CFrame.lookAt(mid, mid + (q - p)), C.Curb, true)
	local ink = (p + q) / 2 + inward * 2.1 + Vector3.new(0, WALK_Y + LINE / 2, 0)
	K.Block(L.Walk, Vector3.new(0.08, LINE, (q - p).Magnitude - 0.6), CFrame.lookAt(ink, ink + (q - p)), C.Ink, true)
end

-- Outer corner fillet: a sidewalk triangle filling the road corner square's outer corner (`corner` = the road
-- corner point, dirA/dirB = unit directions along the two curbs, back toward the road, `r` = leg length).
function Streets.Fillet(L: Layers, corner: Vector3, dirA: Vector3, dirB: Vector3, r: number)
	triangle(L.Walk, corner, dirA, dirB, r, 0, WALK_Y, C.Sidewalk)
	local p, q = corner + dirA * r, corner + dirB * r
	local mid = (p + q) / 2 - (dirA + dirB).Unit * 0.25 + Vector3.new(0, (WALK_Y + 0.06) / 2, 0)
	K.Block(L.Walk, Vector3.new(0.5, WALK_Y + 0.06, (q - p).Magnitude), CFrame.lookAt(mid, mid + (q - p)), C.Curb, true)
end

-- Zebra crosswalk across a road: `center` on the road's center line, `roadDir` = unit direction of the road.
function Streets.Crosswalk(L: Layers, center: Vector3, roadDir: Vector3, roadWidth: number)
	local across = Vector3.new(roadDir.Z, 0, -roadDir.X)
	for x = -roadWidth / 2 + 1.6, roadWidth / 2 - 1.5, 1.8 do
		local p = center + across * x + Vector3.new(0, ROAD_Y + LINE / 2, 0)
		K.Block(L.Road, Vector3.new(0.9, LINE, 5), CFrame.lookAt(p, p + roadDir), C.Trim, true)
	end
end

----------------------------------------------------------------------------------------------------- sidewalks

-- Sloped wedge in front of a curb (ramp or driveway apron). `at` is the sidewalk's placer.
local function ramp(L: Layers, at, curbSide: number, width: number, t: number, w: number, tactile: boolean)
	K.Wedge(L.Walk, Vector3.new(w, WALK_Y, 1.2), at(curbSide * (width / 2 + 0.6), WALK_Y / 2, t) * CFrame.Angles(0, -curbSide * math.pi / 2, 0), C.Sidewalk)
	if tactile then
		K.Block(L.Walk, Vector3.new(0.6, LINE, w - 0.6), at(curbSide * (width / 2 - 0.9), WALK_Y + LINE / 2, t), TACTILE, true)
	end
end

-- Raised sidewalk from a to b, `width` wide, with its curb on side `curbSide` (+1 = the right side looking from
-- a to b). Slab, curb with an ink seam, slab joints every 6 studs (every other one inked), a few cracks.
-- Options: Ramps (distances along it: crosswalk ramps with a tactile strip), Aprons ({ distance, width }:
-- sloped driveway entrances).
function Streets.Walk(L: Layers, a: Vector3, b: Vector3, width: number, curbSide: number, rng: Random, o: { [string]: any }?)
	local opt = o or {}
	local at, len = along(a, b)
	if len < 0.2 then
		return
	end
	K.Block(L.Walk, Vector3.new(width - 0.5, WALK_Y, len), at(-curbSide * 0.25, WALK_Y / 2, len / 2), C.Sidewalk)
	K.Block(L.Walk, Vector3.new(0.5, WALK_Y + 0.06, len), at(curbSide * (width / 2 - 0.25), (WALK_Y + 0.06) / 2, len / 2), C.Curb)
	K.Block(L.Walk, Vector3.new(0.08, LINE, len), at(curbSide * (width / 2 - 0.52), WALK_Y + LINE / 2, len / 2), C.Ink, true)
	local n = 0
	for t = 6, len - 1, 6 do
		n += 1
		K.Block(L.Walk, Vector3.new(width - 0.6, LINE, 0.1), at(-curbSide * 0.25, WALK_Y + LINE / 2, t), if n % 2 == 0 then C.Ink else C.SidewalkJoint, true)
	end
	if Config.Comic.SmallDetails then
		for i = 1, math.floor(len / 40) do
			local t = (i - 0.5) * len / math.floor(len / 40) + rng:NextNumber(-2, 2)
			Streets.Crack(L.Walk, at(-curbSide * 0.4, WALK_Y, t), rng, 0.55)
		end
	end
	for _, t in opt.Ramps or {} do
		ramp(L, at, curbSide, width, t, 2.6, true)
	end
	for _, apron in opt.Aprons or {} do
		ramp(L, at, curbSide, width, apron[1], apron[2], false)
	end
end

return Streets
