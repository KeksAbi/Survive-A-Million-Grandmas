--!nonstrict
-- Comic-style vehicles: Sedan, Hatchback, Wagon, Minivan, SUV, Pickup (one shared car builder driven by a
-- spec each), the grandma mobility Scooter and the retirement-home Shuttle bus.
-- Each vehicle is one Model per outline layer: Layers = { Body, Details }. Body (painted panels, pillars,
-- roof) and Details (glass, wheels, lights, bumpers, grille, mirrors, plates) are separate outline groups, so
-- the client draws ink lines around windows, wheels, lights and bumpers; thin ink parts mark the panel seams.
-- Everything is anchored and decoration (no touch, no raycasts, no shadow) except the main body blocks, which
-- stay solid so players can stand on parked cars and bullets stop at them.
-- Placement: `cframe` = ground point under the vehicle's center, LookVector = its nose.

local ComicKit = require(script.Parent.ComicKit)
local Meshes = require(script.Parent.Meshes)

local K = ComicKit
local C = ComicKit.Colors

local Vehicles = {}

export type Layers = { Body: Instance, Details: Instance }

Vehicles.Kinds = { "Sedan", "Hatchback", "Wagon", "Minivan", "SUV", "Pickup", "Scooter", "Shuttle" }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local TIRE = rgb(34, 34, 40)
local WELL = rgb(28, 26, 34)
local HEADLIGHT = rgb(255, 240, 170)
local TAILLIGHT = rgb(230, 40, 40)
local AMBER = rgb(255, 160, 40)
local BRASS = rgb(255, 205, 70)

-- Car shapes. Lengths in studs, z runs from the nose (-) to the tail (+).
--   L/W: body size, Clear: ground clearance, BodyH: lower body height, Wheel: tire radius, Axles: wheel z,
--   Cabin: z of the roof's front and back edge, CabinH: glass height, RakeF/RakeR: windshield / rear glass run,
--   Doors: 2 or 4 (door seams per side), Pillars: extra pillars along a long roof.
local SPECS = {
	Sedan = { L = 11.6, W = 5.4, Clear = 0.9, BodyH = 1.9, Wheel = 1.15, Axles = { -3.7, 3.6 }, Cabin = { -1.3, 2.3 }, CabinH = 1.8, RakeF = 1.9, RakeR = 1.5, Doors = 4, Color = rgb(60, 120, 220), Bumper = C.MetalDark },
	Hatchback = { L = 9.6, W = 5.2, Clear = 0.8, BodyH = 1.8, Wheel = 1.05, Axles = { -3.0, 3.0 }, Cabin = { -0.9, 3.2 }, CabinH = 1.9, RakeF = 1.8, RakeR = 0.8, Doors = 2, Color = rgb(225, 50, 50), Bumper = C.MetalDark, Spoiler = true },
	Wagon = { L = 12.6, W = 5.5, Clear = 0.9, BodyH = 1.9, Wheel = 1.15, Axles = { -4.0, 4.0 }, Cabin = { -1.6, 5.2 }, CabinH = 1.8, RakeF = 1.8, RakeR = 0.5, Doors = 4, Pillars = { 3.6 }, Color = rgb(255, 200, 50), Bumper = C.Metal, Wood = true, Rack = true },
	Minivan = { L = 12.2, W = 5.8, Clear = 0.9, BodyH = 2.2, Wheel = 1.15, Axles = { -3.9, 3.9 }, Cabin = { -2.2, 5.3 }, CabinH = 2.6, RakeF = 2.6, RakeR = 0.4, Doors = 4, Pillars = { 3.4 }, Color = rgb(246, 246, 240), Bumper = C.MetalDark, Slider = true },
	SUV = { L = 12, W = 5.9, Clear = 1.3, BodyH = 2.3, Wheel = 1.4, Axles = { -3.9, 3.8 }, Cabin = { -1.5, 4.9 }, CabinH = 2.2, RakeF = 1.6, RakeR = 0.5, Doors = 4, Pillars = { 3.4 }, Color = rgb(40, 110, 70), Bumper = C.MetalDark, Rack = true, Spare = true, Flares = true },
	Pickup = { L = 12.6, W = 5.8, Clear = 1.2, BodyH = 2.2, Wheel = 1.35, Axles = { -4.0, 4.0 }, Cabin = { -1.7, 1.1 }, CabinH = 2.1, RakeF = 1.6, RakeR = 0, Doors = 2, Color = rgb(255, 130, 30), Bumper = C.Metal, Bed = true, Flares = true },
}
Vehicles.Specs = SPECS

-- One vehicle's two Models (named after it) inside the two layers.
local function models(L: Layers, name: string): (Model, Model)
	local body, details = K.Model(name), K.Model(name)
	body.Parent = L.Body
	details.Parent = L.Details
	return body, details
end

-- Black-rimmed plate with text on a surface (`cf` on the surface, LookVector out).
local function plate(parent: Instance, cf: CFrame, text: string, w: number?, h: number?)
	local part = K.Panel(parent, w or 1.2, h or 0.5, cf, C.Trim, 0.08, 0.06)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = C.Ink
	label.Parent = gui
	return part
end

-- Wheel at `center` on side s (+1 = +X): a dark wheel-well disc on the body, tire, rim, hub and six spokes.
local function wheel(D: Instance, cf: CFrame, s: number, x: number, z: number, r: number, width: number, bodyX: number)
	local center = cf * CFrame.new(x, r, z)
	K.Cylinder(D, Vector3.new(0.06, 2 * r + 0.7, 2 * r + 0.7), cf * CFrame.new(s * (bodyX + 0.02), r, z), WELL, true)
	K.Cylinder(D, Vector3.new(width, 2 * r, 2 * r), center, TIRE, true)
	K.Cylinder(D, Vector3.new(width + 0.04, 1.25 * r, 1.25 * r), center, C.Metal, true)
	K.Cylinder(D, Vector3.new(width + 0.1, 0.35 * r, 0.35 * r), center, C.MetalDark, true)
	local face = cf * CFrame.new(x + s * (width / 2 + 0.03), r, z)
	for i = 0, 2 do
		K.Block(D, Vector3.new(0.06, 1.2 * r, 0.16), face * CFrame.Angles(i * math.pi / 3, 0, 0), C.MetalDark, true)
	end
end

-- Bumper across the car at the nose (end = -1) or tail (end = 1): a deep bar, two wrap-around corner caps
-- and an ink line along its top.
local function bumper(D: Instance, cf: CFrame, W: number, y: number, z: number, e: number, color: Color3)
	K.Block(D, Vector3.new(W - 0.6, 0.55, 0.7), cf * CFrame.new(0, y, z), color)
	for _, s in { -1, 1 } do
		K.Block(D, Vector3.new(0.9, 0.55, 0.55), cf * CFrame.new(s * (W / 2 - 0.35), y, z - e * 0.12) * CFrame.Angles(0, s * e * math.rad(30), 0), color, true)
	end
	K.Ink(D, Vector3.new(W - 0.5, 0.08, 0.72), cf * CFrame.new(0, y + 0.3, z))
	K.Block(D, Vector3.new(W - 1.2, 0.18, 0.4), cf * CFrame.new(0, y - 0.32, z - e * 0.05), K.Dark(color), true)
end

----------------------------------------------------------------------------------------------------- mesh cars
-- Car bodies as real meshes (World/Meshes), built once per kind and cloned with the paint color:
--   * Paint: one solid mesh: the lower body (sloped hood, sloped trunk lid, bevelled nose, tail, shoulders
--     and rocker, chamfered corners) minus four wheel arches, merged with the cabin (raked windshield and rear
--     glass, sides leaning in, bevelled roof edges).
--   * Glass: a shell 0.07 outside the cabin, cut to the window band, with A, B and C pillars cut out of it, so
--     the paint shows through as pillars and the glass gets its own ink line (Details layer).
--   * Wheels: one mesh each (tire, rim, hub, spokes) set into the arches over a dark wheel well.
--   * Lights, grille, bumpers, plates, mirrors, handles and seams stay small plain parts.
-- Car kinds cut as CSG meshes. Empty: the CSG sedan came out with a broken glass cabin, so every car uses
-- the part builder.
local MESH_KINDS: { [string]: boolean } = {}

local function meshCar(kind: string): Meshes.Pieces
	local spec = SPECS[kind]
	local W, len, r = spec.W, spec.L, spec.Wheel
	local hw = W / 2
	local bot = spec.Clear
	local top = spec.Clear + spec.BodyH + 0.25
	local nose, tail = -len / 2, len / 2
	local z1, z2 = spec.Cabin[1], spec.Cabin[2]
	local front, back = z1 - spec.RakeF, z2 + spec.RakeR
	local roofY = top + spec.CabinH
	local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis
	local function v(x: number, y: number, z: number): Vector3
		return Vector3.new(x, y, z)
	end
	local edge = Meshes.Edge

	-- lower body
	local planes = {
		edge(v(0, top, front), v(0, top - 0.55, nose), X, v(0, 1, -0.2)), -- hood
		edge(v(0, top - 0.55, nose + 0.3), v(0, top - 0.85, nose), X, v(0, 1, -1)), -- nose top
		edge(v(0, bot + 0.45, nose), v(0, bot, nose + 0.55), X, v(0, -1, -1)), -- chin
		edge(v(0, top - 0.3, tail - 0.35), v(0, top - 0.7, tail), X, v(0, 1, 1)), -- tail top
		edge(v(0, bot + 0.4, tail), v(0, bot, tail - 0.45), X, v(0, -1, 1)), -- tail bottom
	}
	if tail - back > 1 then
		table.insert(planes, edge(v(0, top, back), v(0, top - 0.3, tail - 0.35), X, v(0, 1, 0.2))) -- trunk lid
	end
	for _, sx in { -1, 1 } do
		table.insert(planes, edge(v(sx * (hw - 0.35), top, 0), v(sx * hw, top - 0.3, 0), Z, v(sx, 1, 0))) -- shoulder
		table.insert(planes, edge(v(sx * hw, bot + 0.35, 0), v(sx * (hw - 0.3), bot, 0), Z, v(sx, -1, 0))) -- rocker
		table.insert(planes, edge(v(sx * hw, 0, nose + 1.0), v(sx * (hw - 0.7), 0, nose), Y, v(sx, 0, -1))) -- front corner
		table.insert(planes, edge(v(sx * hw, 0, tail - 0.8), v(sx * (hw - 0.55), 0, tail), Y, v(sx, 0, 1))) -- rear corner
	end
	local body = Meshes.Solid(v(W, top - bot, len), CFrame.new(0, (top + bot) / 2, 0), planes, spec.Color)
	local arches = {}
	for _, sx in { -1, 1 } do
		for _, z in spec.Axles do
			table.insert(arches, Meshes.Cylinder(v(1.4, 2 * r + 0.36, 2 * r + 0.36), CFrame.new(sx * (hw - 0.5), r, z), spec.Color))
		end
	end
	body = Meshes.Subtract(body, arches, spec.Color)

	-- cabin: sides lean in by `lean` from the belt line to the roof
	local belt = hw - 0.45
	local lean = 0.5
	local function sideX(y: number): number
		return belt - lean * (y - top) / spec.CabinH
	end
	local function cabinPlanes(grow: number): { CFrame }
		local list = {
			edge(v(0, top, front), v(0, roofY, z1), X, v(0, 1, -1)), -- windshield
		}
		if spec.RakeR > 0.15 then
			table.insert(list, edge(v(0, roofY, z2), v(0, top, back), X, v(0, 1, 1))) -- rear glass
		end
		for _, sx in { -1, 1 } do
			table.insert(list, edge(v(sx * sideX(top), top, 0), v(sx * sideX(roofY), roofY, 0), Z, v(sx, 0.1, 0)))
			table.insert(list, edge(v(sx * (sideX(roofY) - 0.3), roofY, 0), v(sx * sideX(roofY - 0.3), roofY - 0.3, 0), Z, v(sx, 1, 0)))
		end
		for i, plane in list do
			list[i] = plane * CFrame.new(0, 0, -grow)
		end
		return list
	end
	local cabinSize = v(2 * belt + 0.4, spec.CabinH + 0.1, back - front + 0.4)
	local cabinAt = CFrame.new(0, top + (spec.CabinH - 0.1) / 2, (front + back) / 2)
	local cabin = Meshes.Solid(cabinSize, cabinAt, cabinPlanes(0), spec.Color)
	local paint = Meshes.Finish(Meshes.Union({ body, cabin }, spec.Color), true, true, "Paint")

	-- glass shell with the pillars cut out
	local band = cabinPlanes(0.07)
	table.insert(band, Meshes.Plane(v(0, roofY - 0.28, 0), Y))
	table.insert(band, Meshes.Plane(v(0, top + 0.28, 0), -Y))
	local glass = Meshes.Solid(cabinSize + v(0.4, 0.4, 0.4), cabinAt, band, C.Glass)
	local pillars = {}
	local function pillar(a: Vector3, b: Vector3, width: number)
		table.insert(pillars, Meshes.Block(v(width, width, (b - a).Magnitude + 1.2), CFrame.lookAt((a + b) / 2, b), C.Glass))
	end
	local seams = table.clone(spec.Pillars or {})
	if spec.Doors == 4 then
		table.insert(seams, (z1 + z2) / 2 - 0.3)
	end
	for _, sx in { -1, 1 } do
		pillar(v(sx * sideX(top), top, front), v(sx * sideX(roofY), roofY, z1), 0.5)
		if spec.RakeR > 0.15 then
			pillar(v(sx * sideX(top), top, back), v(sx * sideX(roofY), roofY, z2), if spec.RakeR > 1 then 1.1 else 0.6)
		else
			pillar(v(sx * sideX(top), top, back - 0.2), v(sx * sideX(roofY), roofY, back - 0.2), 0.7)
		end
	end
	for _, z in seams do
		table.insert(pillars, Meshes.Block(v(W + 1, spec.CabinH + 1, 0.35), CFrame.new(0, top + spec.CabinH / 2, z), C.Glass))
	end
	glass = Meshes.Finish(Meshes.Subtract(glass, pillars, C.Glass), false, false, "Glass")

	-- one wheel mesh, copied to all four corners
	local width = 0.9
	local hub = Meshes.Union({
		Meshes.Cylinder(v(width, 2 * r, 2 * r), CFrame.new(), TIRE),
		Meshes.Cylinder(v(width + 0.06, 1.3 * r, 1.3 * r), CFrame.new(), C.Metal),
		Meshes.Cylinder(v(width + 0.14, 0.4 * r, 0.4 * r), CFrame.new(), C.MetalDark),
		Meshes.Block(v(width + 0.1, 1.2 * r, 0.18), CFrame.new(), C.MetalDark),
		Meshes.Block(v(width + 0.1, 1.2 * r, 0.18), CFrame.Angles(math.pi / 3, 0, 0), C.MetalDark),
		Meshes.Block(v(width + 0.1, 1.2 * r, 0.18), CFrame.Angles(-math.pi / 3, 0, 0), C.MetalDark),
	})
	local pieces = { { Layer = "Body", Part = paint }, { Layer = "Details", Part = glass } }
	for _, sx in { -1, 1 } do
		for _, z in spec.Axles do
			local tire = hub:Clone()
			tire.CFrame = CFrame.new(sx * (hw - 0.45), r, z)
			table.insert(pieces, { Layer = "Details", Part = Meshes.Finish(tire, false, false, "Wheel") })
		end
	end
	hub:Destroy()

	-- small plain-part details, built around the origin like the old car
	local B, D = K.Model(kind), K.Model(kind)
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x, y, z)
	end
	for _, sx in { -1, 1 } do
		for _, z in spec.Axles do
			K.Cylinder(D, v(0.06, 2 * r + 0.3, 2 * r + 0.3), at(sx * (hw - 1.18), r, z), WELL, true)
		end
		-- door seams (clear of the arches), handles, rocker line
		local doorFront = math.max(front + 0.3, spec.Axles[1] + r + 0.5)
		local doorBack = math.min(z1 + 4.4, spec.Axles[2] - r - 0.4)
		local doorSeams = if spec.Doors == 4 then { doorFront, (z1 + z2) / 2 - 0.3, doorBack } else { doorFront, doorBack }
		for i, sz in doorSeams do
			K.Ink(D, v(0.06, top - bot - 1.0, 0.07), at(sx * (hw + 0.02), bot + 0.5 + (top - bot - 1.0) / 2, sz))
			if i < #doorSeams then
				K.Block(D, v(0.1, 0.16, 0.5), at(sx * (hw + 0.05), top - 0.65, sz + 0.55), C.Metal, true)
			end
		end
		K.Ink(D, v(0.06, 0.08, spec.Axles[2] - spec.Axles[1] - 2 * r - 0.6), at(sx * (hw + 0.02), bot + 0.5, (spec.Axles[1] + spec.Axles[2]) / 2))
		-- mirror on an arm at the windshield base (the housing takes the paint color)
		K.Block(D, v(0.5, 0.12, 0.12), at(sx * (belt + 0.2), top + 0.25, front + 0.55), C.MetalDark, true)
		local mirror = K.Block(B, v(0.35, 0.45, 0.6), at(sx * (belt + 0.5), top + 0.4, front + 0.55), spec.Color, true)
		mirror.Name = "Paint"
		K.Block(D, v(0.3, 0.35, 0.05), at(sx * (belt + 0.5), top + 0.4, front + 0.86), C.Glass, true)
		-- shine streak on the side glass
		K.Block(D, v(0.06, spec.CabinH * 0.45, 0.2), at(sx * (sideX(top + spec.CabinH * 0.5) + 0.09), top + spec.CabinH * 0.5, (z1 + z2) / 2 + 0.8) * CFrame.Angles(math.rad(-30), 0, sx * math.atan(lean / spec.CabinH)), C.GlassShine, true)
	end
	-- nose: grille with chrome bars and badge, headlights, bumper, plate
	local faceY = (bot + 0.45 + top - 0.85) / 2
	local grilleW = W * 0.36
	K.Panel(D, grilleW, 0.45, at(0, faceY - 0.1, nose), C.MetalDark, 0.12, 0.08)
	for _, y in { -0.1, 0.1 } do
		K.Block(D, v(grilleW - 0.1, 0.07, 0.05), at(0, faceY - 0.1 + y, nose - 0.22), C.Metal, true)
	end
	K.Block(D, v(0.28, 0.28, 0.08), at(0, faceY - 0.1, nose - 0.27) * CFrame.Angles(0, 0, math.pi / 4), BRASS, true)
	for _, sx in { -1, 1 } do
		local lamp = at(sx * (hw - 1.05), faceY + 0.05, nose)
		K.Panel(D, 1.0, 0.5, lamp, HEADLIGHT, 0.12, 0.08)
		K.Block(D, v(0.32, 0.26, 0.05), lamp * CFrame.new(-sx * 0.2, 0, -0.2), C.Trim, true)
		local tailLamp = at(sx * (hw - 0.95), (bot + 0.4 + top - 0.7) / 2 + 0.05, tail) * CFrame.Angles(0, math.pi, 0)
		K.Panel(D, 0.9, 0.5, tailLamp, TAILLIGHT, 0.12, 0.08)
		K.Block(D, v(0.9, 0.14, 0.05), tailLamp * CFrame.new(0, -0.2, -0.2), AMBER, true)
	end
	local bumperY = bot + 0.3
	local cfOrigin = CFrame.new()
	bumper(D, cfOrigin, W - 0.4, bumperY, nose - 0.05, -1, spec.Bumper)
	bumper(D, cfOrigin, W - 0.4, bumperY, tail + 0.05, 1, spec.Bumper)
	plate(D, at(0, bumperY, nose - 0.4), "GRAN " .. string.upper(string.sub(kind, 1, 3)))
	plate(D, at(0, bumperY, tail + 0.4) * CFrame.Angles(0, math.pi, 0), "OLD 4EVR")
	-- wipers, cowl seam, trunk seam
	for _, x in { -0.9, 0.9 } do
		K.Ink(D, v(1.7, 0.08, 0.08), at(x, top + 0.12, front + 0.4) * CFrame.Angles(0, 0, if x < 0 then 0.18 else -0.18))
	end
	K.Ink(D, v(W - 1.4, 0.05, 0.08), at(0, top + 0.02, front - 0.15))
	if tail - back > 1 then
		K.Ink(D, v(W - 1.4, 0.05, 0.08), at(0, top - 0.02, back + 0.25))
	end
	table.insert(pieces, { Layer = "Body", Part = Meshes.Group("Trim", B:GetChildren()) })
	table.insert(pieces, { Layer = "Details", Part = Meshes.Group("Details", D:GetChildren()) })
	return pieces
end

----------------------------------------------------------------------------------------------------------- cars

local function car(L: Layers, kind: string, cf: CFrame, paint: Color3?): (Model, Model)
	local spec = SPECS[kind]
	local B, D = models(L, kind)
	local color = paint or spec.Color
	if MESH_KINDS[kind] and Meshes.Ensure("Car" .. kind, function()
		return meshCar(kind)
	end) then
		Meshes.Place("Car" .. kind, { Body = B, Details = D }, cf, 1, color)
		return B, D
	end
	local W, len = spec.W, spec.L
	local c = 0.45 -- bevel on the body's top edges
	local top = spec.Clear + spec.BodyH
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end

	-- lower body: core, a narrower top layer and wedge bevels on all four top edges
	K.Block(B, Vector3.new(W, spec.BodyH - c, len), at(0, spec.Clear + (spec.BodyH - c) / 2, 0), color)
	K.Block(B, Vector3.new(W - 2 * c, c, len - 2 * c), at(0, top - c / 2, 0), color)
	K.Wedge(B, Vector3.new(W - 2 * c, c, c), at(0, top - c / 2, -len / 2 + c / 2), color, true)
	K.Wedge(B, Vector3.new(W - 2 * c, c, c), at(0, top - c / 2, len / 2 - c / 2) * CFrame.Angles(0, math.pi, 0), color, true)
	for _, s in { -1, 1 } do
		K.Wedge(B, Vector3.new(len - 2 * c, c, c), at(s * (W / 2 - c / 2), top - c / 2, 0) * CFrame.Angles(0, -s * math.pi / 2, 0), color, true)
		-- shoulder crease, dark rocker panel with an ink line
		K.Ink(D, Vector3.new(0.06, 0.08, len - 0.6), at(s * (W / 2 + 0.01), top - c - 0.02, 0))
		K.Block(D, Vector3.new(0.08, 0.4, len - 2.4), at(s * (W / 2 + 0.02), spec.Clear + 0.2, 0), K.Dark(color), true)
		K.Ink(D, Vector3.new(0.1, 0.08, len - 2.4), at(s * (W / 2 + 0.03), spec.Clear + 0.42, 0))
	end

	-- cabin: a painted shell (roof, pillars, sloped windshield and rear) with glass windows set into it, so it
	-- reads as a car from every side (a glass box with a light roof looked like a broken fin from the side)
	local z1, z2 = spec.Cabin[1], spec.Cabin[2]
	local cw = W - 2 * c - 0.2
	local cy = top + spec.CabinH / 2
	local roofY = top + spec.CabinH
	K.Block(B, Vector3.new(cw, spec.CabinH, z2 - z1), at(0, cy, (z1 + z2) / 2), color)
	K.Wedge(B, Vector3.new(cw, spec.CabinH, spec.RakeF), at(0, cy, z1 - spec.RakeF / 2), color)
	if spec.RakeR > 0.15 then
		K.Wedge(B, Vector3.new(cw, spec.CabinH, spec.RakeR), at(0, cy, z2 + spec.RakeR / 2) * CFrame.Angles(0, math.pi, 0), color)
	end
	K.Block(B, Vector3.new(cw + 0.3, 0.3, z2 - z1 + 0.3), at(0, roofY + 0.15, (z1 + z2) / 2), color)
	K.Ink(D, Vector3.new(cw + 0.34, 0.06, z2 - z1 + 0.34), at(0, roofY + 0.01, (z1 + z2) / 2))

	-- glass lying on the windshield and rear slopes (a frame of paint stays around it)
	local function slopeGlass(fromZ: number, fromY: number, toZ: number, toY: number)
		local a = at(0, fromY, fromZ).Position
		local b = at(0, toY, toZ).Position
		local frame = CFrame.lookAt((a + b) / 2, b, cf.UpVector)
		K.Block(D, Vector3.new(cw - 0.6, 0.08, (b - a).Magnitude - 0.45), frame * CFrame.new(0, 0.05, 0), C.Glass, true)
		K.Block(D, Vector3.new(0.35, 0.09, (b - a).Magnitude - 0.8), frame * CFrame.new(-cw * 0.22, 0.06, 0), C.GlassShine, true)
	end
	slopeGlass(z1 - spec.RakeF, top + 0.05, z1, roofY - 0.05)
	if spec.RakeR > 0.15 then
		slopeGlass(z2, roofY - 0.05, z2 + spec.RakeR, top + 0.05)
	else
		K.Block(D, Vector3.new(cw - 0.6, spec.CabinH - 0.5, 0.08), at(0, cy + 0.05, z2 + 0.04), C.Glass, true) -- flat rear window
	end

	for _, s in { -1, 1 } do
		-- door seams stay clear of the wheel wells; a 4-door car has its B pillar on the middle seam
		local doorFront = math.max(z1 - spec.RakeF + 0.3, spec.Axles[1] + spec.Wheel + 0.5)
		local doorBack = math.min(z1 + 4.4, spec.Axles[2] - spec.Wheel - 0.4)
		local seams = { doorFront, z1 + 2.2 }
		local pillars = table.clone(spec.Pillars or {})
		if spec.Doors == 4 then
			seams = { doorFront, (doorFront + doorBack) / 2, doorBack }
			table.insert(pillars, seams[2])
		end
		-- side windows between the pillars (paint shows between them as the B / C pillars)
		table.sort(pillars)
		local edges = { z1 + 0.25 }
		for _, pz in pillars do
			if pz > z1 + 0.6 and pz < z2 - 0.6 then
				table.insert(edges, pz - 0.2)
				table.insert(edges, pz + 0.2)
			end
		end
		table.insert(edges, z2 - 0.25)
		for i = 1, #edges - 1, 2 do
			local za, zb = edges[i], edges[i + 1]
			if zb - za > 0.3 then
				K.Block(D, Vector3.new(0.08, spec.CabinH - 0.45, zb - za), at(s * (cw / 2 + 0.04), cy + 0.05, (za + zb) / 2), C.Glass, true)
			end
		end
		K.Block(D, Vector3.new(0.06, spec.CabinH * 0.45, 0.22), at(s * (cw / 2 + 0.09), cy + 0.15, z1 + 0.9) * CFrame.Angles(math.rad(-30), 0, 0), C.GlassShine, true)

		-- door seams and handles
		for i, sz in seams do
			K.Ink(D, Vector3.new(0.06, spec.BodyH - 0.8, 0.07), at(s * (W / 2 + 0.02), spec.Clear + 0.5 + (spec.BodyH - 0.8) / 2, sz))
			if i < #seams then
				K.Block(D, Vector3.new(0.1, 0.16, 0.5), at(s * (W / 2 + 0.05), top - c - 0.3, sz + 0.55), C.Metal, true)
			end
		end
		if spec.Slider then
			K.Ink(D, Vector3.new(0.06, 0.07, 3.0), at(s * (W / 2 + 0.02), top - c - 0.55, (z1 + z2) / 2 + 1.4))
		end

		-- mirror on an arm at the windshield base
		local mirror = at(s * (cw / 2 + 0.55), top + 0.45, z1 - spec.RakeF + 0.5)
		K.Block(D, Vector3.new(0.5, 0.12, 0.12), at(s * (cw / 2 + 0.25), top + 0.3, z1 - spec.RakeF + 0.5), C.MetalDark, true)
		K.Block(B, Vector3.new(0.35, 0.45, 0.6), mirror, color, true)
		K.Block(D, Vector3.new(0.3, 0.35, 0.05), mirror * CFrame.new(0, 0, 0.31), C.Glass, true)

		-- wheels
		for _, wz in spec.Axles do
			wheel(D, cf, s, s * (W / 2 - 0.3), wz, spec.Wheel, 0.9, W / 2)
			if spec.Flares then
				K.Block(D, Vector3.new(0.3, 0.35, 2 * spec.Wheel + 0.8), at(s * (W / 2 + 0.12), 2 * spec.Wheel + 0.25, wz), C.Ink, true)
			end
		end
	end

	-- wipers on the windshield base, hood seam at the cowl
	local wiperY = top + spec.CabinH * 0.35 / spec.RakeF + 0.06
	for _, x in { -0.9, 0.9 } do
		K.Ink(D, Vector3.new(1.7, 0.08, 0.08), at(x, wiperY, z1 - spec.RakeF + 0.35) * CFrame.Angles(0, 0, if x < 0 then 0.18 else -0.18))
	end
	K.Ink(D, Vector3.new(W - 2 * c, 0.05, 0.08), at(0, top + 0.02, z1 - spec.RakeF - 0.15))

	-- nose: inked grille with chrome bars and a badge, headlights with a bright core, bumper, plate
	local nose = -len / 2
	local grilleY = spec.Clear + spec.BodyH * 0.55
	local grilleW = W * (if kind == "SUV" or kind == "Pickup" then 0.5 else 0.38)
	K.Panel(D, grilleW, 0.6, at(0, grilleY, nose), C.MetalDark, 0.15, 0.08)
	for _, y in { -0.12, 0.12 } do
		K.Block(D, Vector3.new(grilleW - 0.1, 0.08, 0.05), at(0, grilleY + y, nose - 0.22), C.Metal, true)
	end
	K.Block(D, Vector3.new(0.3, 0.3, 0.08), at(0, grilleY, nose - 0.27) * CFrame.Angles(0, 0, math.pi / 4), BRASS, true)
	for _, s in { -1, 1 } do
		local lamp = at(s * (W / 2 - 0.85), grilleY + 0.1, nose)
		K.Panel(D, 1.1, 0.55, lamp, HEADLIGHT, 0.12, 0.08)
		K.Block(D, Vector3.new(0.35, 0.3, 0.05), lamp * CFrame.new(-s * 0.2, 0, -0.2), C.Trim, true)
		local tail = at(s * (W / 2 - 0.7), grilleY + 0.15, len / 2) * CFrame.Angles(0, math.pi, 0)
		K.Panel(D, 0.9, 0.6, tail, TAILLIGHT, 0.12, 0.08)
		K.Block(D, Vector3.new(0.9, 0.16, 0.05), tail * CFrame.new(0, -0.22, -0.2), AMBER, true)
	end
	local bumperY = spec.Clear + 0.3
	bumper(D, cf, W, bumperY, nose - 0.1, -1, spec.Bumper)
	bumper(D, cf, W, bumperY, len / 2 + 0.1, 1, spec.Bumper)
	plate(D, at(0, bumperY, nose - 0.45), "GRAN " .. string.upper(string.sub(kind, 1, 3)))
	plate(D, at(0, bumperY, len / 2 + 0.45) * CFrame.Angles(0, math.pi, 0), "OLD 4EVR")

	-- trunk seam (or a tailgate seam on hatches, wagons, vans)
	if spec.RakeR > 1 then
		K.Ink(D, Vector3.new(W - 2 * c, 0.05, 0.08), at(0, top + 0.02, z2 + spec.RakeR + 0.2))
	else
		K.Ink(D, Vector3.new(W - 1.2, 0.08, 0.06), at(0, top - c - 0.1, len / 2 + 0.02))
	end

	if spec.Spoiler then
		K.Wedge(B, Vector3.new(cw, 0.25, 0.7), at(0, roofY + 0.4, z2 + 0.1) * CFrame.Angles(0, math.pi, 0), color, true)
	end
	if spec.Rack then
		for _, s in { -1, 1 } do
			K.Block(D, Vector3.new(0.15, 0.15, z2 - z1 - 0.4), at(s * (cw / 2 - 0.3), roofY + 0.45, (z1 + z2) / 2), C.MetalDark, true)
		end
		for i = 0, 2 do
			K.Block(D, Vector3.new(cw - 0.4, 0.12, 0.15), at(0, roofY + 0.45, z1 + 0.6 + i * (z2 - z1 - 1.2) / 2), C.MetalDark, true)
		end
	end
	if spec.Wood then
		for _, s in { -1, 1 } do
			K.Block(D, Vector3.new(0.06, spec.BodyH * 0.45, len - 4), at(s * (W / 2 + 0.04), spec.Clear + spec.BodyH * 0.5, 0.3), C.Wood, true)
			for _, dy in { -1, 1 } do
				K.Block(D, Vector3.new(0.08, 0.1, len - 4), at(s * (W / 2 + 0.05), spec.Clear + spec.BodyH * (0.5 + dy * 0.225), 0.3), C.WoodLight, true)
			end
		end
	end
	if spec.Spare then
		local spare = at(0, spec.Clear + spec.BodyH * 0.55, len / 2 + 0.45) * CFrame.Angles(0, math.pi / 2, 0)
		K.Cylinder(D, Vector3.new(0.8, 2.2, 2.2), spare, TIRE, true)
		K.Cylinder(D, Vector3.new(0.84, 1.3, 1.3), spare, color, true)
	end
	if spec.Bed then
		-- open bed: dark liner, side rails and a tailgate rail on top of the body behind the cab
		local bedStart, bedEnd = z2 + 0.4, len / 2 - 0.2
		local bedLen = bedEnd - bedStart
		K.Block(D, Vector3.new(W - 2 * c - 0.4, 0.05, bedLen), at(0, top + 0.03, (bedStart + bedEnd) / 2), WELL, true)
		for _, s in { -1, 1 } do
			K.Block(B, Vector3.new(0.3, 0.6, bedLen), at(s * (W / 2 - 0.15), top + 0.3, (bedStart + bedEnd) / 2), color, true)
		end
		K.Block(B, Vector3.new(W, 0.6, 0.3), at(0, top + 0.3, bedEnd + 0.05), color, true)
		K.Block(B, Vector3.new(W, 0.6, 0.3), at(0, top + 0.3, bedStart - 0.15), color, true)
		K.Panel(D, cw - 1, spec.CabinH - 0.7, at(0, cy, z2 + 0.02) * CFrame.Angles(0, math.pi, 0), C.Glass, 0.15, 0.06)
	end
	return B, D
end

------------------------------------------------------------------------------------------------ special vehicles

-- Pink grandma mobility scooter: deck with a nose shroud, rear cover, four little wheels, a padded seat with
-- armrests, a tilted tiller with curved handlebars, a wicker basket full of flowers, a headlight, a chrome
-- bumper, a safety flag and a GRANNY GO plate.
local function scooter(L: Layers, cf: CFrame)
	local B, D = models(L, "Scooter")
	local pink, seat = rgb(255, 140, 190), rgb(150, 40, 80)
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	K.Block(B, Vector3.new(1.6, 0.35, 3.4), at(0, 0.6, 0), pink, true)
	K.Block(B, Vector3.new(1.4, 1.1, 0.6), at(0, 1.1, -1.55) * CFrame.Angles(math.rad(-15), 0, 0), pink, true)
	K.Wedge(B, Vector3.new(1.4, 0.45, 0.6), at(0, 0.6, -2.0) * CFrame.Angles(0, math.pi, 0), pink, true)
	K.Block(B, Vector3.new(1.9, 0.55, 1.3), at(0, 0.95, 1.15), pink, true)
	K.Wedge(B, Vector3.new(1.9, 0.4, 0.5), at(0, 1.42, 1.55) * CFrame.Angles(0, math.pi, 0), K.Light(pink), true)
	K.Ink(D, Vector3.new(1.96, 0.07, 1.36), at(0, 0.7, 1.15))
	for _, wz in { -1.35, 1.15 } do
		local wx = if wz < 0 then 0.65 else 0.95
		for _, s in { -1, 1 } do
			local center = at(s * wx, 0.45, wz)
			K.Cylinder(D, Vector3.new(0.4, 0.9, 0.9), center, TIRE, true)
			K.Cylinder(D, Vector3.new(0.44, 0.5, 0.5), center, C.Metal, true)
			K.Cylinder(D, Vector3.new(0.48, 0.18, 0.18), center, C.MetalDark, true)
		end
	end
	-- seat
	K.Block(D, Vector3.new(0.3, 0.8, 0.3), at(0, 1.5, 0.8), C.MetalDark, true)
	K.Block(B, Vector3.new(1.5, 0.35, 1.3), at(0, 2.0, 0.8), seat, true)
	K.Block(B, Vector3.new(1.5, 1.3, 0.3), at(0, 2.75, 1.45) * CFrame.Angles(math.rad(10), 0, 0), seat, true)
	K.Ink(D, Vector3.new(1.54, 0.07, 1.34), at(0, 2.18, 0.8))
	for _, s in { -1, 1 } do
		K.Block(D, Vector3.new(0.2, 0.15, 1.0), at(s * 0.82, 2.45, 0.75), C.MetalDark, true)
		K.Block(D, Vector3.new(0.12, 0.45, 0.12), at(s * 0.82, 2.2, 0.35), C.MetalDark, true)
	end
	-- tiller and curved handlebars
	local base, head = at(0, 1.3, -1.45).Position, at(0, 2.8, -1.05).Position
	K.Block(D, Vector3.new(0.25, 0.25, (head - base).Magnitude), CFrame.lookAt((base + head) / 2, head), C.MetalDark, true)
	K.Block(D, Vector3.new(0.8, 0.15, 0.15), at(0, 2.8, -1.05), C.MetalDark, true)
	for _, s in { -1, 1 } do
		local bend = at(s * 0.55, 2.82, -0.95) * CFrame.Angles(0, s * math.rad(35), math.rad(-10) * s)
		K.Block(D, Vector3.new(0.5, 0.15, 0.15), bend, C.MetalDark, true)
		K.Block(D, Vector3.new(0.18, 0.18, 0.45), at(s * 0.78, 2.85, -0.75), C.Ink, true)
	end
	-- wicker basket with flowers
	local basket = at(0, 1.85, -2.05)
	K.Block(D, Vector3.new(1.2, 0.06, 0.8), basket * CFrame.new(0, -0.35, 0), C.WoodLight, true)
	for _, side in { { 0, -0.4, 1.2, 0.06 }, { 0, 0.4, 1.2, 0.06 }, { -0.6, 0, 0.06, 0.8 }, { 0.6, 0, 0.06, 0.8 } } do
		K.Block(D, Vector3.new(side[3], 0.7, side[4]), basket * CFrame.new(side[1], 0, side[2]), C.WoodLight, true)
	end
	for _, y in { -0.1, 0.25 } do
		K.Block(D, Vector3.new(1.24, 0.06, 0.84), basket * CFrame.new(0, y, 0), C.Wood, true)
	end
	for i, x in { -0.3, 0.1, 0.35 } do
		K.Block(D, Vector3.one * 0.35, basket * CFrame.new(x, 0.45, (i % 2 - 0.5) * 0.3) * CFrame.Angles(math.pi / 4, i, math.pi / 4), C.Flowers[i], true)
	end
	-- headlight, chrome bumper, safety flag, plate
	K.Panel(D, 0.5, 0.4, at(0, 1.2, -1.9) * CFrame.Angles(math.rad(-15), 0, 0), HEADLIGHT, 0.1, 0.06)
	K.Block(D, Vector3.new(1.7, 0.2, 0.25), at(0, 0.5, -2.35), C.Metal, true)
	K.Block(D, Vector3.new(0.06, 3.2, 0.06), at(-0.8, 2.6, 1.7), C.MetalDark, true)
	K.Prism(D, 0.06, 0.8, 1.0, at(-0.8, 3.75, 1.7) * CFrame.Angles(math.pi / 2, 0, 0), AMBER, true) -- pennant pointing back
	plate(D, at(0, 0.95, 1.8) * CFrame.Angles(0, math.pi, 0), "GRANNY GO", 1.1, 0.4)
	return B, D
end

-- Retirement-home shuttle bus: cream body with bevelled roof edges, raked windshield over a nose, inked
-- window band with six windows a side, folding glass door, teal stripes, side sign and logo, destination
-- sign, mirrors on arms, wipers, grille, lights, bumpers, roof AC unit and plates.
local function shuttle(L: Layers, cf: CFrame)
	local B, D = models(L, "Shuttle")
	local cream, teal = rgb(250, 246, 236), rgb(40, 160, 160)
	local len, W, clear, H = 24, 7.4, 1.0, 8.4
	local c = 0.8
	local top = clear + H
	local nose = -len / 2
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	-- body: core, top layer and bevels; the front upper part is the raked windshield
	K.Block(B, Vector3.new(W, H - c, len - 1.4), at(0, clear + (H - c) / 2, 0.7), cream)
	local roofLen, roofZ = len - 1.4 - c, 0.7 - c / 2 -- from the windshield top back to the rear bevel
	K.Block(B, Vector3.new(W - 2 * c, c, roofLen), at(0, top - c / 2, roofZ), cream)
	for _, s in { -1, 1 } do
		K.Wedge(B, Vector3.new(roofLen, c, c), at(s * (W / 2 - c / 2), top - c / 2, roofZ) * CFrame.Angles(0, -s * math.pi / 2, 0), cream, true)
	end
	K.Wedge(B, Vector3.new(W - 2 * c, c, c), at(0, top - c / 2, len / 2 - c / 2) * CFrame.Angles(0, math.pi, 0), cream, true)
	K.Block(B, Vector3.new(W, 3.4, 1.4), at(0, clear + 1.7, nose + 0.7), cream)
	K.Wedge(D, Vector3.new(W - 0.4, H - 3.4 - 0.3, 1.4), at(0, clear + 3.4 + (H - 3.7) / 2, nose + 0.7), C.Glass, true)
	K.Ink(D, Vector3.new(0.2, H - 3.7, 0.1), at(0, clear + 3.4 + (H - 3.7) / 2, nose + 0.72) * CFrame.Angles(math.atan2(1.4, H - 3.7), 0, 0))
	K.Block(D, Vector3.new(2.4, 0.9, 1.6), at(0, top + 0.45, 3), C.Metal, true)
	K.Ink(D, Vector3.new(2.45, 0.08, 1.65), at(0, top + 0.12, 3))

	for _, s in { -1, 1 } do
		local x = s * (W / 2)
		local side = at(x, 0, 0) * CFrame.Angles(0, -s * math.pi / 2, 0) -- wall CFrame on this side, LookVector out
		-- teal stripes and the window band
		for _, y in { 2.0, 3.0 } do
			K.Block(D, Vector3.new(0.06, 0.4, len - 1.6), at(x + s * 0.03, clear + y, 0.7), teal, true)
		end
		K.Ink(D, Vector3.new(0.08, 2.7, len - 4.4), at(x + s * 0.03, clear + 5.4, 1.5))
		for i = 0, 5 do
			local wz = -6.6 + i * 3.4
			if not (s == 1 and i == 0) then
				K.Block(D, Vector3.new(0.1, 2.2, 2.8), at(x + s * 0.08, clear + 5.4, wz), C.Glass, true)
				K.Block(D, Vector3.new(0.04, 1.1, 0.25), at(x + s * 0.13, clear + 5.6, wz - 0.6) * CFrame.Angles(math.rad(-30), 0, 0), C.GlassShine, true)
			end
		end
		-- side sign + logo diamond
		local sign = K.Panel(D, 9, 1.1, side * CFrame.new(-s * 2.5, clear + 3.95, 0), teal, 0.12, 0.08)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "RETIREMENT HOME SHUTTLE"
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = C.Trim
		label.Parent = gui
		K.Panel(D, 1.4, 1.4, side * CFrame.new(s * 8, clear + 3.95, 0) * CFrame.Angles(0, 0, math.pi / 4), BRASS, 0.12, 0.08)
		K.Block(D, Vector3.new(0.6, 0.6, 0.06), side * CFrame.new(s * 8, clear + 3.95, -0.22) * CFrame.Angles(0, 0, math.pi / 4), teal, true)
		-- mirrors on arms ahead of the windshield
		K.Block(D, Vector3.new(0.15, 0.15, 1.8), at(s * (W / 2 + 0.2), top - 1.5, nose + 0.6) * CFrame.Angles(0, s * math.rad(-25), 0), C.MetalDark, true)
		K.Block(D, Vector3.new(0.3, 1.2, 0.6), at(s * (W / 2 + 0.6), top - 2.1, nose - 0.2), C.Ink, true)
		-- wheels
		for _, wz in { -5.0, 7.2 } do
			wheel(D, cf, s, s * (W / 2 - 0.35), wz, 1.7, 1.0, W / 2)
		end
	end
	-- folding door (passenger side, front)
	local door = at(W / 2, 0, -8.6) * CFrame.Angles(0, -math.pi / 2, 0)
	K.Panel(D, 2.8, H - 1.6, door * CFrame.new(0, clear + 0.4 + (H - 1.6) / 2, 0), C.MetalDark, 0.15, 0.08)
	for _, x in { -0.7, 0.7 } do
		K.Block(D, Vector3.new(1.2, H - 2.2, 0.05), door * CFrame.new(x, clear + 0.6 + (H - 2.2) / 2, -0.25), C.Glass, true)
	end
	K.Block(D, Vector3.new(2.6, 0.25, 0.1), door * CFrame.new(0, clear + 3.0, -0.3), C.MetalDark, true)
	-- nose details: destination sign, grille, lights, wipers, bumpers, plates
	local destination = K.Panel(D, 5, 0.8, at(0, top - 0.75, nose + 1.32) * CFrame.Angles(math.atan2(1.4, H - 3.7), 0, 0), C.Ink, 0.08, 0.06)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = destination
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "SUNNY ACRES"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = AMBER
	label.Parent = gui
	K.Panel(D, 3.4, 1.1, at(0, clear + 1.9, nose), C.MetalDark, 0.15, 0.08)
	for _, y in { -0.25, 0.25 } do
		K.Block(D, Vector3.new(3.3, 0.1, 0.05), at(0, clear + 1.9 + y, nose - 0.22), C.Metal, true)
	end
	for _, s in { -1, 1 } do
		K.Panel(D, 1.0, 0.7, at(s * 2.7, clear + 2.1, nose), HEADLIGHT, 0.12, 0.08)
		K.Panel(D, 0.8, 1.0, at(s * 2.9, clear + 2.4, len / 2) * CFrame.Angles(0, math.pi, 0), TAILLIGHT, 0.12, 0.08)
		K.Ink(D, Vector3.new(2.2, 0.1, 0.1), at(s * 1.4, clear + 3.9, nose + 0.35) * CFrame.Angles(0, 0, s * 0.3))
	end
	bumper(D, cf, W, clear + 0.4, nose - 0.1, -1, C.MetalDark)
	bumper(D, cf, W, clear + 0.4, len / 2 + 0.1, 1, C.MetalDark)
	plate(D, at(0, clear + 0.4, nose - 0.45), "SUNNY 1")
	plate(D, at(0, clear + 1.6, len / 2) * CFrame.Angles(0, math.pi, 0), "SUNNY 1")
	K.Panel(D, W - 2, 2.6, at(0, clear + 5.6, len / 2) * CFrame.Angles(0, math.pi, 0), C.Glass, 0.15, 0.06)
	return B, D
end

-- Builds a vehicle of `kind` (Vehicles.Kinds) at `cframe`; `paint` overrides a car's color.
function Vehicles.Build(L: Layers, kind: string, cframe: CFrame, paint: Color3?): (Model, Model)
	if kind == "Scooter" then
		return scooter(L, cframe)
	elseif kind == "Shuttle" then
		return shuttle(L, cframe)
	end
	return car(L, kind, cframe, paint)
end

-- Half length of a vehicle (for parking it nose-in or along a curb).
function Vehicles.HalfLength(kind: string): number
	if kind == "Scooter" then
		return 2.4
	elseif kind == "Shuttle" then
		return 12.5
	end
	return SPECS[kind].L / 2 + 0.5
end

return Vehicles
