--!nonstrict
-- Real mesh geometry for the comic map, made at server start with Roblox's in-game CSG (GeometryService).
-- Custom MeshParts cannot be uploaded from code, but CSG can cut proper low-poly solids out of plain parts:
--   * Solid: a convex solid bounded by planes (a box cut by turned blocks): tapered trunks, car bodies with
--     sloped hoods and bevelled edges, raked windshields.
--   * Lump: a faceted, slightly irregular blob (four turned blocks intersected): leaf clusters, bush masses.
--   * Union / Subtract: merge pieces into one mesh, cut wheel arches.
-- Every shape is built ONCE as a template (`Ensure`) and cloned for each copy (`Place`, with a uniform
-- scale), so the CSG cost is paid per template, not per tree. One mesh replaces 10-30 primitive parts:
-- fewer parts, fewer Highlight re-renders, and silhouettes that are not boxes.
-- Faces stay flat (no smoothing), so every facet takes its own light tone: hard cel-shaded facets.
-- If CSG is unavailable (or Config.Comic.Meshes is false), `Ensure` returns false and callers build their
-- primitive version instead, so the map always builds.

local GeometryService = game:GetService("GeometryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Meshes = {}

-- A template's pieces: each goes into one outline layer (layer name -> Instance given to Place).
export type Pieces = { { Layer: string, Part: Instance } }

local OPTIONS = {
	CollisionFidelity = Enum.CollisionFidelity.Box,
	RenderFidelity = Enum.RenderFidelity.Automatic,
	SplitApart = false,
}

local templates: { [string]: Pieces | false } = {}
local worked = false -- at least one template built: CSG works on this server
local disabled = Config.Comic.Meshes == false

-- A loose part for CSG input (never parented: GeometryService works on unparented parts).
local function block(size: Vector3, cframe: CFrame, color: Color3, class: string?): BasePart
	local part = Instance.new(class or "Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	return part
end
Meshes.Block = block

local function cylinder(size: Vector3, cframe: CFrame, color: Color3): BasePart
	local part = block(size, cframe, color)
	part.Shape = Enum.PartType.Cylinder
	return part
end
Meshes.Cylinder = cylinder

-- Runs one CSG operation. Errors (caught by Ensure) when it fails, so a half-built template is never used.
local function run(method: string, main: BasePart, others: { BasePart }, color: Color3?): BasePart
	local result = GeometryService[method](GeometryService, main, others, OPTIONS)
	local part = result and result[1]
	assert(part, "CSG " .. method .. " returned nothing")
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	if color then
		part.UsePartColor = true
		part.Color = color
	end
	main:Destroy()
	for _, other in others do
		other:Destroy()
	end
	return part
end

-------------------------------------------------------------------------------------------------- operations

function Meshes.Intersect(parts: { BasePart }, color: Color3?): BasePart
	return run("IntersectAsync", parts[1], { table.unpack(parts, 2) }, color)
end

-- One mesh from several pieces. Without `color` every face keeps its piece's color (two-tone meshes).
function Meshes.Union(parts: { BasePart }, color: Color3?): BasePart
	if #parts == 1 and not color then
		return parts[1]
	end
	return run("UnionAsync", parts[1], { table.unpack(parts, 2) }, color)
end

function Meshes.Subtract(main: BasePart, cutters: { BasePart }, color: Color3?): BasePart
	return run("SubtractAsync", main, cutters, color)
end

---------------------------------------------------------------------------------------------------- planes

-- A cutting plane through `point` whose outside is along `normal`, as a CFrame (LookVector = normal).
function Meshes.Plane(point: Vector3, normal: Vector3): CFrame
	local up = if math.abs(normal.Unit.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	return CFrame.lookAt(point, point + normal, up)
end

-- The plane through the line a-b that also runs along `along`; `outward` picks which side is outside.
-- (Profile cuts: a and b in a side view, `along` = the axis the cut runs across.)
function Meshes.Edge(a: Vector3, b: Vector3, along: Vector3, outward: Vector3): CFrame
	local normal = (b - a):Cross(along).Unit
	if normal:Dot(outward) < 0 then
		normal = -normal
	end
	return Meshes.Plane(a, normal)
end

-------------------------------------------------------------------------------------------------- solids

-- Convex solid: the box `size` at `cframe` with everything outside `planes` cut away (one CSG call).
function Meshes.Solid(size: Vector3, cframe: CFrame, planes: { CFrame }, color: Color3): BasePart
	local main = block(size, cframe, color)
	local big = size.Magnitude * 2 + 4
	local cutters = {}
	for _, plane in planes do
		-- a big block whose front face lies on the plane, behind it (+Z of the plane CFrame = inside)
		table.insert(cutters, block(Vector3.one * big, plane * CFrame.new(0, 0, big / 2), color))
	end
	if #cutters == 0 then
		return main
	end
	return Meshes.Intersect({ main, table.unpack(cutters) }, color)
end

-- Tapered prism with `sides` faces (trunks, branches, posts): `base` = center of the bottom, its UpVector the
-- axis; rBottom/rTop = distance from the axis to each face at the bottom and the top.
function Meshes.Frustum(base: CFrame, rBottom: number, rTop: number, height: number, color: Color3, sides: number?): BasePart
	local n = sides or 8
	local planes = {}
	local slope = (rBottom - rTop) / height
	for i = 0, n - 1 do
		local a = (i + 0.5) * 2 * math.pi / n
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local normal = base:VectorToWorldSpace(Vector3.new(out.X, slope, out.Z))
		table.insert(planes, Meshes.Plane((base * CFrame.new(out * rBottom)).Position, normal))
	end
	local box = rBottom * 2.4 + 0.1
	return Meshes.Solid(Vector3.new(box, height, box), base * CFrame.new(0, height / 2, 0), planes, color)
end

-- CFrame at `from` whose UpVector points along `dir` (for frustums along a branch).
function Meshes.Along(from: Vector3, dir: Vector3): CFrame
	local up = dir.Unit
	local side = if math.abs(up.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	local right = side:Cross(up).Unit
	return CFrame.fromMatrix(from, right, up)
end

-- Faceted lump about `diameter` wide (`squash` = height / width): a box cut by three blocks turned 45 degrees
-- about Y, X and Z, each a little off and resized at random, then spun at random. 18 facets, never a ball.
function Meshes.Lump(diameter: number, center: Vector3, color: Color3, rng: Random, squash: number?): BasePart
	local d = diameter
	local h = d * (squash or 0.85)
	local function j(): number
		return rng:NextNumber(0.92, 1.08)
	end
	local function wobble(): number
		return math.rad(rng:NextNumber(-9, 9))
	end
	local spin = CFrame.new(center) * CFrame.Angles(wobble() * 2, rng:NextNumber(0, math.pi * 2), wobble() * 2)
	local k = rng:NextNumber(1.0, 1.08)
	return Meshes.Intersect({
		block(Vector3.new(d * j(), h * j(), d * j()), spin, color),
		block(Vector3.new(d * k * j(), h * 3, d * k * j()), spin * CFrame.Angles(wobble(), math.rad(45), wobble()), color),
		block(Vector3.new(d * 3, (h + d) / 2 * k * j(), (h + d) / 2 * k * j()), spin * CFrame.Angles(math.rad(45) + wobble(), 0, wobble()), color),
		block(Vector3.new((h + d) / 2 * k * j(), (h + d) / 2 * k * j(), d * 3), spin * CFrame.Angles(wobble(), 0, math.rad(45) + wobble()), color),
	}, color)
end

----------------------------------------------------------------------------------------------- templates

-- Builds template `name` once with `build` (returns its pieces, built around the origin: ground center at
-- (0, 0, 0), front = -Z). Returns false if CSG is off or failed (caller builds primitives).
function Meshes.Ensure(name: string, build: () -> Pieces): boolean
	local template = templates[name]
	if template == nil then
		if disabled then
			templates[name] = false
			return false
		end
		local ok, result = pcall(build)
		if ok then
			templates[name] = result
			worked = true
		else
			templates[name] = false
			warn("[Meshes] " .. name .. " fell back to plain parts: " .. tostring(result))
			if not worked then
				disabled = true -- the very first template failed: CSG is not available here, stop trying
			end
		end
		template = templates[name]
	end
	return template ~= false
end

local function fit(part: BasePart, cframe: CFrame, scale: number)
	local rel = part.CFrame
	part.Size *= scale
	part.CFrame = cframe * CFrame.new(rel.Position * scale) * rel.Rotation
end

-- Clones template `name` (Ensure first) to `cframe`, scaled by `scale`; each piece goes into
-- layers[piece.Layer] (pieces without a layer there are skipped). Returns the placed copies.
-- `paint` recolors pieces named "Paint" (car bodies).
function Meshes.Place(name: string, layers: { [string]: Instance }, cframe: CFrame, scale: number?, paint: Color3?): { Instance }
	local template = templates[name]
	assert(template, "Meshes: template " .. name .. " is not built")
	local s = scale or 1
	local placed = {}
	for _, piece in template do
		local parent = layers[piece.Layer]
		if not parent then
			continue
		end
		local copy = piece.Part:Clone()
		local parts = copy:GetDescendants()
		table.insert(parts, copy)
		for _, part in parts do
			if part:IsA("BasePart") then
				fit(part, cframe, s)
				if paint and part.Name == "Paint" then
					part.Color = paint
				end
			end
		end
		copy.Parent = parent
		table.insert(placed, copy)
	end
	return placed
end

-- Finishes a template piece: decoration (no collision, no raycasts) unless `solid`; `shadow` = casts one.
function Meshes.Finish(part: BasePart, solid: boolean?, shadow: boolean?, name: string?): BasePart
	part.Anchored = true
	part.CanTouch = false
	part.CanCollide = solid == true
	part.CanQuery = solid == true
	part.CastShadow = shadow == true
	part.Material = Enum.Material.SmoothPlastic
	if name then
		part.Name = name
	end
	return part
end

-- A plain Model holding loose pieces (details that stay primitives inside a template).
function Meshes.Group(name: string, parts: { BasePart }): Model
	local model = Instance.new("Model")
	model.Name = name
	for _, part in parts do
		Meshes.Finish(part)
		part.Parent = model
	end
	return model
end

return Meshes
