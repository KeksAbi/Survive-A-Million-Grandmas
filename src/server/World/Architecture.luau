--!nonstrict
-- Reusable comic-style building components (houses, garages, the retirement home): walls with siding, shingle
-- or brick finish, gable roofs, recessed windows, paneled doors, porches with columns and railings, garages with
-- sectional doors, dormers, bay windows, chimneys, gutters and downspouts.
--
-- Every builder takes Layers = { Walls, Roofs, Details } (all three may be the same Model). The map puts each
-- layer in its own outline group, so the client draws a thick ink line wherever a roof meets a wall or a
-- detail (window, door, porch, chimney) sits in front of a wall.
--
-- Placement conventions:
--   box CFrame  = ground center of a box; its front (-Z, LookVector) is the facade.
--   wall CFrame = a point on a wall's outer surface; LookVector points out of the wall, X runs along it.

local ComicKit = require(script.Parent.ComicKit)

local K = ComicKit
local C = ComicKit.Colors

local Architecture = {}

export type Layers = { Walls: Instance, Roofs: Instance, Details: Instance }

-- Turns a point on a box face into that face's wall CFrame.
Architecture.Face = {
	Front = CFrame.identity,
	Back = CFrame.Angles(0, math.pi, 0),
	Right = CFrame.Angles(0, -math.pi / 2, 0), -- looks along +X
	Left = CFrame.Angles(0, math.pi / 2, 0), -- looks along -X
}
local Face = Architecture.Face

local BRASS = Color3.fromRGB(255, 205, 70)
local WHITE = Color3.new(1, 1, 1)

-- Round bar between two points in `box` space (downspouts, brackets). Vertical bars are built upright
-- (CFrame.lookAt has no defined roll straight up).
local function bar(parent: Instance, box: CFrame, a: Vector3, b: Vector3, thickness: number, color: Color3)
	local d = b - a
	if math.abs(d.X) + math.abs(d.Z) < 0.01 then
		K.Block(parent, Vector3.new(thickness, math.abs(d.Y), thickness), box * CFrame.new((a + b) / 2), color, true)
	else
		K.Block(parent, Vector3.new(thickness, thickness, d.Magnitude + thickness * 0.6), box * CFrame.lookAt((a + b) / 2, b), color, true)
	end
end
Architecture.Bar = bar

------------------------------------------------------------------------------------------------------ walls

-- Box of walls on a stone foundation (ink line on top), with trim corner boards over ink corners and a
-- finish on the front and both sides: "Siding" (boards), "Shingle" (tighter rows), "Brick" (mortar lines and
-- a few loose bricks) or nil (plain). The back is never seen and stays plain.
function Architecture.Walls(L: Layers, box: CFrame, W: number, H: number, D: number, color: Color3, finish: string?, trim: Color3?, rng: Random)
	local P = L.Walls
	local trimColor = trim or C.Trim
	K.Block(P, Vector3.new(W + 0.6, 1.2, D + 0.6), box * CFrame.new(0, 0.6, 0), C.Stone)
	K.Ink(P, Vector3.new(W + 0.66, 0.12, D + 0.66), box * CFrame.new(0, 1.2, 0))
	K.Block(P, Vector3.new(W, H, D), box * CFrame.new(0, H / 2, 0), color)
	local upper = H - 1.2
	K.InkCorners(P, box * CFrame.new(0, 1.2 + upper / 2, 0), Vector3.new(W + 0.8, upper, D + 0.8))
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			K.Block(P, Vector3.new(0.8, upper, 0.8), box * CFrame.new(sx * W / 2, 1.2 + upper / 2, sz * D / 2), trimColor, true)
		end
	end
	if not finish then
		return
	end
	local faces = {
		{ box * CFrame.new(0, 0, -D / 2), W },
		{ box * CFrame.new(-W / 2, 0, 0) * Face.Left, D },
		{ box * CFrame.new(W / 2, 0, 0) * Face.Right, D },
	}
	for _, f in faces do
		local face, width = f[1], f[2]
		if finish == "Brick" then
			local mortar = color:Lerp(WHITE, 0.45)
			for y = 2.0, H - 0.6, 1.3 do
				K.Block(P, Vector3.new(width - 0.8, 0.1, 0.06), face * CFrame.new(0, y, -0.03), mortar, true)
			end
			for _ = 1, math.floor(width / 1.6) do
				local row = rng:NextInteger(0, math.max(0, math.floor((H - 3) / 1.3) - 1))
				local x = rng:NextNumber(-width / 2 + 1.5, width / 2 - 1.5)
				K.Block(P, Vector3.new(1.5, 0.6, 0.09), face * CFrame.new(x, 2.65 + row * 1.3, -0.045), K.Dark(color), true)
			end
		else
			local line = color:Lerp(C.Ink, 0.22)
			local spacing = if finish == "Shingle" then 1.25 else 1.6
			for y = 1.2 + spacing, H - 0.4, spacing do
				K.Block(P, Vector3.new(width - 0.8, 0.12, 0.08), face * CFrame.new(0, y, -0.04), line, true)
			end
		end
	end
end

-------------------------------------------------------------------------------------------------------- roofs

export type RoofInfo = { WallH: number, Rise: number, Half: number, Angle: number, Thick: number }

-- Gable roof on walls ending at wallH: ridge along the local X of `box`, W long, spanning D (Z).
-- Solid attic (two wedges in gableColor), two thick tilted slabs with overhang, shingle courses, white rake
-- boards and fascia with an ink line, ridge cap, gutters. Options (o):
--   Over (overhang, 1.4), Extend (extra slab on the front -Z side: a roof running down over a porch),
--   Vents (diamond vents on the gable ends, default on), Gutters (default on), Downspouts.
-- Returns RoofInfo for dormers.
function Architecture.GableRoof(L: Layers, box: CFrame, W: number, D: number, wallH: number, rise: number, roofColor: Color3, gableColor: Color3, o: { [string]: any }?): RoofInfo
	local opt = o or {}
	local over = opt.Over or 1.4
	local thick = 0.7
	local half = D / 2
	local angle = math.atan2(rise, half)
	local slope = math.sqrt(half * half + rise * rise)
	local width = W + over * 2

	K.Prism(L.Walls, W, D, rise, box * CFrame.new(0, wallH, 0), gableColor)
	for _, side in { -1, 1 } do
		local reach = over + (if side == -1 then opt.Extend or 0 else 0) -- slab length past the eave
		local length = slope + reach
		local normal = Vector3.new(0, math.cos(angle), side * math.sin(angle))
		local eave = Vector3.new(0, wallH, side * half)
		local up = (Vector3.new(0, wallH + rise, 0) - eave).Unit
		local center = eave - up * reach + up * (length / 2) + normal * (thick / 2)
		local slab = CFrame.fromMatrix(center, Vector3.xAxis, normal)
		local eaveZ = side * length / 2 -- the slab's local Z at its lower edge
		K.Block(L.Roofs, Vector3.new(width, thick, length), box * slab, roofColor)
		for i = 1, math.floor((length - 0.4) / 1.5) do
			K.Block(L.Roofs, Vector3.new(width - 0.5, 0.12, 0.35), box * slab * CFrame.new(0, thick / 2 + 0.04, eaveZ - side * i * 1.5), K.Dark(roofColor), true)
		end
		K.Block(L.Roofs, Vector3.new(width + 0.1, thick + 0.3, 0.35), box * slab * CFrame.new(0, -0.1, eaveZ - side * 0.1), C.Trim, true)
		K.Ink(L.Roofs, Vector3.new(width + 0.15, 0.14, 0.4), box * slab * CFrame.new(0, -0.1 - (thick + 0.3) / 2, eaveZ - side * 0.1))
		for _, e in { -1, 1 } do
			K.Block(L.Roofs, Vector3.new(0.3, thick + 0.3, length), box * slab * CFrame.new(e * (width / 2 - 0.1), -0.1, 0), C.Trim, true)
		end

		if opt.Gutters ~= false then
			local gutter = slab * CFrame.new(0, -thick / 2 - 0.3, eaveZ - side * 0.3)
			K.Block(L.Details, Vector3.new(width - 0.2, 0.45, 0.55), box * gutter, C.Metal, true)
			if opt.Downspouts then
				local g = gutter.Position
				for _, e in { -1, 1 } do
					local x = e * (W / 2 - 0.6)
					local top = Vector3.new(x, g.Y - 0.2, g.Z)
					if reach > over then
						bar(L.Details, box, Vector3.new(x, 0.2, g.Z), top, 0.4, C.Metal) -- roof past the walls: straight down
					else
						local wallZ = side * (half + 0.3)
						local bend = Vector3.new(x, g.Y - 0.9, wallZ)
						bar(L.Details, box, bend, top, 0.4, C.Metal)
						bar(L.Details, box, Vector3.new(x, 0.6, wallZ), bend, 0.4, C.Metal)
						bar(L.Details, box, Vector3.new(x, 0.6, wallZ), Vector3.new(x, 0.25, wallZ + side * 0.8), 0.4, C.Metal)
					end
				end
			end
		end

		if opt.Vents ~= false then
			local vent = box * CFrame.new(side * W / 2, wallH + rise * 0.38, 0) * (if side == 1 then Face.Right else Face.Left) * CFrame.Angles(0, 0, math.pi / 4)
			K.Panel(L.Details, 1.6, 1.6, vent, C.Trim, nil, 0.15)
			K.Block(L.Details, Vector3.new(1.0, 1.0, 0.08), vent * CFrame.new(0, 0, -0.29), K.Dark(gableColor), true)
		end
	end
	K.Block(L.Roofs, Vector3.new(width + 0.2, 0.6, 1.1), box * CFrame.new(0, wallH + rise + thick / math.cos(angle) - 0.1, 0), K.Dark(roofColor))
	return { WallH = wallH, Rise = rise, Half = half, Angle = angle, Thick = thick }
end

-- Interior chimney rising through a roof: brick stack with mortar lines, an ink band and a metal cap.
-- `base` = ground point under it; the stack starts at bottomY (inside the attic) and ends at topY.
function Architecture.Chimney(L: Layers, base: CFrame, bottomY: number, topY: number, color: Color3)
	local P = L.Details
	K.Block(P, Vector3.new(2.2, topY - bottomY + 1, 2.2), base * CFrame.new(0, (bottomY - 1 + topY) / 2, 0), color)
	for _, y in { topY - 1.2, topY - 2.4 } do
		K.Block(P, Vector3.new(2.3, 0.18, 2.3), base * CFrame.new(0, y, 0), color:Lerp(WHITE, 0.4), true)
	end
	K.Ink(P, Vector3.new(2.35, 0.2, 2.35), base * CFrame.new(0, topY - 0.1, 0))
	K.Block(P, Vector3.new(2.9, 0.5, 2.9), base * CFrame.new(0, topY + 0.2, 0), C.MetalDark)
	K.Block(P, Vector3.new(0.7, 0.6, 0.7), base * CFrame.new(0.4, topY + 0.7, 0.3), C.MetalDark, true)
end

-- Exterior chimney built up the outside of a wall (`wall` = ground point on the wall): wide stone base,
-- sloped shoulders, narrower stack, mortar lines, ink band and cap.
function Architecture.SideChimney(L: Layers, wall: CFrame, shoulderY: number, topY: number, color: Color3)
	local P = L.Details
	local mortar = color:Lerp(WHITE, 0.35)
	K.Block(P, Vector3.new(3.2, shoulderY, 1.8), wall * CFrame.new(0, shoulderY / 2, -0.9), color)
	for _, s in { -1, 1 } do
		K.Wedge(P, Vector3.new(1.8, 0.9, 0.6), wall * CFrame.new(s * 1.3, shoulderY + 0.45, -0.9) * CFrame.Angles(0, -s * math.pi / 2, 0), color, true)
	end
	K.Block(P, Vector3.new(2.0, topY - shoulderY, 1.4), wall * CFrame.new(0, (shoulderY + topY) / 2, -0.7), color)
	for y = 2, topY - 1.5, 2.2 do
		local width = if y < shoulderY then 3.2 else 2.0
		local depth = if y < shoulderY then 1.8 else 1.4
		K.Block(P, Vector3.new(width + 0.06, 0.12, 0.06), wall * CFrame.new(0, y, -depth - 0.02), mortar, true)
	end
	K.Ink(P, Vector3.new(2.06, 0.2, 1.46), wall * CFrame.new(0, topY - 0.1, -0.7))
	K.Block(P, Vector3.new(2.6, 0.5, 1.9), wall * CFrame.new(0, topY + 0.2, -0.7), C.MetalDark)
end

------------------------------------------------------------------------------------------- windows and doors

-- Recessed window (`wall` = wall CFrame at the glass center): ink plate, protruding casing, glass set back
-- inside it with a hard comic shadow and a glint, mullions, sill with an ink line. Options (o):
--   Trim (casing color), Grid (6 panes instead of 4), Crown (head trim), Shutters (color), ShutterWidth,
--   Box (flower box color).
-- Width taken on the wall: w/2 + 0.65 each side (+ 0.95 + shutter width with shutters).
function Architecture.Window(L: Layers, wall: CFrame, w: number, h: number, o: { [string]: any }?)
	local opt = o or {}
	local P = L.Details
	local trim = opt.Trim or C.Trim
	K.Ink(P, Vector3.new(w + 1.3, h + 1.3, 0.1), wall * CFrame.new(0, 0, -0.05))
	for _, s in { -1, 1 } do
		K.Block(P, Vector3.new(w + 0.9, 0.45, 0.5), wall * CFrame.new(0, s * (h / 2 + 0.225), -0.35), trim, true)
		K.Block(P, Vector3.new(0.45, h, 0.5), wall * CFrame.new(s * (w / 2 + 0.225), 0, -0.35), trim, true)
	end
	K.Block(P, Vector3.new(w, h, 0.1), wall * CFrame.new(0, 0, -0.15), C.Glass, true)
	K.Block(P, Vector3.new(w, 0.35, 0.04), wall * CFrame.new(0, h / 2 - 0.175, -0.22), K.Dark(C.Glass), true) -- hard shadow under the head
	K.Block(P, Vector3.new(0.28, h * 0.45, 0.04), wall * CFrame.new(w * 0.15, h * 0.12, -0.24) * CFrame.Angles(0, 0, math.rad(-30)), C.GlassShine, true)
	if opt.Grid then
		for _, x in { -w / 6, w / 6 } do
			K.Block(P, Vector3.new(0.14, h, 0.12), wall * CFrame.new(x, 0, -0.28), trim, true)
		end
	else
		K.Block(P, Vector3.new(0.16, h, 0.12), wall * CFrame.new(0, 0, -0.28), trim, true)
	end
	K.Block(P, Vector3.new(w, 0.16, 0.12), wall * CFrame.new(0, 0, -0.28), trim, true)
	K.Block(P, Vector3.new(w + 1.4, 0.35, 1.0), wall * CFrame.new(0, -(h / 2 + 0.625), -0.5), trim, true)
	K.Ink(P, Vector3.new(w + 1.45, 0.1, 1.05), wall * CFrame.new(0, -(h / 2 + 0.85), -0.5))
	if opt.Crown then
		K.Block(P, Vector3.new(w + 1.6, 0.4, 0.8), wall * CFrame.new(0, h / 2 + 0.65, -0.4), trim, true)
		K.Ink(P, Vector3.new(w + 1.65, 0.1, 0.85), wall * CFrame.new(0, h / 2 + 0.9, -0.4))
	end
	if opt.Shutters then
		local sw = opt.ShutterWidth or math.max(1.1, w * 0.38)
		for _, s in { -1, 1 } do
			local x = s * (w / 2 + 0.8 + sw / 2)
			K.Ink(P, Vector3.new(sw + 0.3, h + 0.6, 0.1), wall * CFrame.new(x, 0, -0.05))
			K.Block(P, Vector3.new(sw, h + 0.3, 0.2), wall * CFrame.new(x, 0, -0.2), opt.Shutters, true)
			for _, y in { -h / 4, h / 4 } do
				K.Block(P, Vector3.new(sw - 0.3, 0.12, 0.06), wall * CFrame.new(x, y, -0.33), K.Dark(opt.Shutters), true)
			end
		end
	end
	if opt.Box then
		K.Block(P, Vector3.new(w + 0.8, 0.8, 1.5), wall * CFrame.new(0, -(h / 2 + 1.25), -0.85), opt.Box, true)
		K.Ink(P, Vector3.new(w + 0.85, 0.1, 1.55), wall * CFrame.new(0, -(h / 2 + 1.7), -0.85))
		for i = -1, 1 do
			local at = wall * CFrame.new(i * w / 3, -(h / 2 + 0.7), -1.45)
			K.Block(P, Vector3.new(w * 0.28, 0.35, 0.4), at * CFrame.new(0, -0.25, 0), C.Leaves[1], true)
			K.Block(P, Vector3.one * 0.6, at * CFrame.Angles(math.pi / 4, 0, math.pi / 4), C.Flowers[i + 2], true)
		end
	end
end

-- Round attic window (an inked octagon with a cross). `wall` = wall CFrame at its center.
function Architecture.RoundWindow(L: Layers, wall: CFrame, size: number, trim: Color3?)
	local P = L.Details
	for _, turn in { 0, math.pi / 4 } do
		local spin = CFrame.Angles(0, 0, turn)
		K.Ink(P, Vector3.new(size + 0.6, size + 0.6, 0.1), wall * CFrame.new(0, 0, -0.05) * spin)
		K.Block(P, Vector3.new(size + 0.1, size + 0.1, 0.2), wall * CFrame.new(0, 0, -0.2) * spin, trim or C.Trim, true)
		K.Block(P, Vector3.new(size - 0.7, size - 0.7, 0.1), wall * CFrame.new(0, 0, -0.35) * spin, C.Glass, true)
	end
	K.Block(P, Vector3.new(0.15, size - 0.4, 0.1), wall * CFrame.new(0, 0, -0.45), trim or C.Trim, true)
	K.Block(P, Vector3.new(size - 0.4, 0.15, 0.1), wall * CFrame.new(0, 0, -0.45), trim or C.Trim, true)
end

-- Paneled entrance door, recessed in a protruding casing with a head crown, four raised panels, brass lever
-- handle and threshold (`wall` = wall CFrame at the bottom center). Options: Trim, Glass (upper panels are
-- glass), Sidelights (glass strips each side). Width taken on the wall: w/2 + 0.75 (+ 1.2 with sidelights).
function Architecture.Door(L: Layers, wall: CFrame, w: number, h: number, color: Color3, o: { [string]: any }?)
	local opt = o or {}
	local P = L.Details
	local trim = opt.Trim or C.Trim
	local inner = if opt.Sidelights then w + 2.4 else w
	K.Ink(P, Vector3.new(inner + 1.5, h + 0.95, 0.1), wall * CFrame.new(0, (h + 0.95) / 2, -0.05))
	for _, s in { -1, 1 } do
		K.Block(P, Vector3.new(0.5, h + 0.5, 0.5), wall * CFrame.new(s * (inner / 2 + 0.25), (h + 0.5) / 2, -0.35), trim, true)
	end
	K.Block(P, Vector3.new(inner + 1.0, 0.5, 0.5), wall * CFrame.new(0, h + 0.25, -0.35), trim, true)
	K.Block(P, Vector3.new(inner + 1.6, 0.4, 0.8), wall * CFrame.new(0, h + 0.7, -0.4), trim, true)
	K.Ink(P, Vector3.new(inner + 1.65, 0.1, 0.85), wall * CFrame.new(0, h + 0.95, -0.4))

	local slab = wall * CFrame.new(0, h / 2, -0.175)
	K.Block(P, Vector3.new(w, h, 0.15), slab, color, true)
	for _, px in { -1, 1 } do
		for _, py in { -1, 1 } do
			local panel = if opt.Glass and py == 1 then C.Glass else K.Light(color)
			K.Block(P, Vector3.new(w * 0.34, h * 0.32, 0.08), slab * CFrame.new(px * w * 0.21, py * h * 0.21, -0.11), panel, true)
		end
	end
	K.Block(P, Vector3.new(0.2, 0.75, 0.06), slab * CFrame.new(w * 0.44, -0.02 * h, -0.11), BRASS, true)
	K.Block(P, Vector3.new(0.55, 0.15, 0.15), slab * CFrame.new(w * 0.44 - 0.2, 0, -0.2), BRASS, true)
	K.Block(P, Vector3.new(inner + 1.2, 0.2, 0.8), wall * CFrame.new(0, 0.1, -0.4), C.Stone, true)
	if opt.Sidelights then
		for _, s in { -1, 1 } do
			K.Block(P, Vector3.new(0.4, h, 0.4), wall * CFrame.new(s * (w / 2 + 0.2), h / 2, -0.3), trim, true)
			K.Block(P, Vector3.new(0.8, 0.8, 0.15), wall * CFrame.new(s * (w / 2 + 0.8), 0.4, -0.175), trim, true)
			K.Block(P, Vector3.new(0.8, h - 0.8, 0.1), wall * CFrame.new(s * (w / 2 + 0.8), 0.8 + (h - 0.8) / 2, -0.15), C.Glass, true)
		end
	end
end

-- Canted bay window on a wall (`wall` = ground point on the face at the bay center): a front panel w wide
-- standing dp in front of the wall and two 45-degree side panels, each a paneled skirt up to sillY and inked
-- glass up to topY, with corner posts, a trapezoid cap in roofColor and a trim band. Takes w + 2*dp of wall.
function Architecture.Bay(L: Layers, wall: CFrame, w: number, dp: number, sillY: number, topY: number, wallColor: Color3, roofColor: Color3, trim: Color3?)
	local P = L.Details
	local trimColor = trim or C.Trim
	local panels = { { wall * CFrame.new(0, 0, -dp), w } }
	for _, s in { -1, 1 } do
		table.insert(panels, { wall * CFrame.new(s * (w / 2 + dp / 2), 0, -dp / 2) * CFrame.Angles(0, -s * math.pi / 4, 0), dp * math.sqrt(2) })
	end
	local glassH = topY - sillY - 0.8
	for _, panel in panels do
		local face, width = panel[1], panel[2]
		K.Block(P, Vector3.new(width, sillY, 0.6), face * CFrame.new(0, sillY / 2, 0.3), wallColor)
		K.Block(P, Vector3.new(width - 0.9, sillY - 1.6, 0.08), face * CFrame.new(0, sillY / 2 + 0.3, -0.04), K.Light(wallColor), true)
		K.Ink(P, Vector3.new(width, topY - sillY, 0.1), face * CFrame.new(0, (sillY + topY) / 2, 0.35))
		K.Block(P, Vector3.new(width - 0.6, glassH, 0.1), face * CFrame.new(0, (sillY + topY) / 2, 0.25), C.Glass, true)
		K.Block(P, Vector3.new(0.25, glassH * 0.45, 0.04), face * CFrame.new(width * 0.15, (sillY + topY) / 2 + glassH * 0.1, 0.18) * CFrame.Angles(0, 0, math.rad(-30)), C.GlassShine, true)
		K.Block(P, Vector3.new(width + 0.3, 0.4, 0.8), face * CFrame.new(0, sillY + 0.2, 0), trimColor, true)
		K.Block(P, Vector3.new(width + 0.3, 0.4, 0.8), face * CFrame.new(0, topY - 0.2, 0), trimColor, true)
	end
	for _, corner in { Vector3.new(-w / 2, 0, -dp), Vector3.new(w / 2, 0, -dp), Vector3.new(-w / 2 - dp, 0, 0), Vector3.new(w / 2 + dp, 0, 0) } do
		K.Block(P, Vector3.new(0.5, topY - sillY, 0.5), wall * CFrame.new(corner.X, (sillY + topY) / 2, corner.Z - 0.1), trimColor, true)
	end
	-- trapezoid cap: a block over the front part and a 45-degree turned block over each corner triangle
	local d = dp + 0.4
	local capY = topY + 0.4
	K.Block(P, Vector3.new(w + 0.8, 0.8, d), wall * CFrame.new(0, capY, -d / 2), roofColor)
	for _, s in { -1, 1 } do
		local corner = wall * CFrame.new(s * (w / 2 + 0.4 + d / 4), capY, -d / 4) * CFrame.Angles(0, -s * math.pi / 4, 0)
		K.Block(P, Vector3.new(d * math.sqrt(2), 0.8, d / math.sqrt(2)), corner, roofColor)
	end
	K.Ink(P, Vector3.new(w + 0.85, 0.12, 0.1), wall * CFrame.new(0, capY - 0.4, -d - 0.02))
end

------------------------------------------------------------------------------------------- porches and garages

-- Porch column standing on `base` (ground point of its foot), height including base and capital:
-- "Square", "Tapered" (craftsman: tapering post on a stone pier) or "Turned" (thin, with collars).
function Architecture.Column(P: Instance, base: CFrame, height: number, style: string?, color: Color3)
	if style == "Tapered" then
		local pier = math.min(2.4, height * 0.35)
		K.Block(P, Vector3.new(1.6, pier, 1.6), base * CFrame.new(0, pier / 2, 0), C.Stone)
		K.Block(P, Vector3.new(1.8, 0.25, 1.8), base * CFrame.new(0, pier + 0.125, 0), K.Light(C.Stone), true)
		local rest = height - pier - 0.65
		K.Block(P, Vector3.new(1.1, rest / 2, 1.1), base * CFrame.new(0, pier + 0.25 + rest / 4, 0), color)
		K.Block(P, Vector3.new(0.85, rest / 2, 0.85), base * CFrame.new(0, pier + 0.25 + rest * 3 / 4, 0), color)
		K.Block(P, Vector3.new(1.3, 0.4, 1.3), base * CFrame.new(0, height - 0.2, 0), color, true)
	elseif style == "Turned" then
		K.Block(P, Vector3.new(0.9, 0.6, 0.9), base * CFrame.new(0, 0.3, 0), color)
		K.Block(P, Vector3.new(0.5, height - 1.0, 0.5), base * CFrame.new(0, 0.6 + (height - 1.0) / 2, 0), color)
		for _, f in { 0.2, 0.78 } do
			K.Block(P, Vector3.new(0.8, 0.4, 0.8), base * CFrame.new(0, 0.6 + (height - 1.0) * f, 0) * CFrame.Angles(0, math.pi / 4, 0), color, true)
		end
		K.Block(P, Vector3.new(0.9, 0.4, 0.9), base * CFrame.new(0, height - 0.2, 0), color, true)
	else
		K.Block(P, Vector3.new(1.0, 0.6, 1.0), base * CFrame.new(0, 0.3, 0), color)
		K.Block(P, Vector3.new(0.7, height - 1.0, 0.7), base * CFrame.new(0, 0.6 + (height - 1.0) / 2, 0), color)
		K.Block(P, Vector3.new(1.0, 0.4, 1.0), base * CFrame.new(0, height - 0.2, 0), color, true)
	end
end

-- Railing between two points on a floor: top rail, bottom rail and square balusters.
function Architecture.Railing(P: Instance, from: Vector3, to: Vector3, height: number, color: Color3)
	local length = (to - from).Magnitude
	if length < 0.6 then
		return
	end
	local frame = CFrame.lookAt(from, to)
	K.Block(P, Vector3.new(0.35, 0.25, length), frame * CFrame.new(0, height, -length / 2), color, true)
	K.Block(P, Vector3.new(0.3, 0.2, length), frame * CFrame.new(0, 0.35, -length / 2), color, true)
	local count = math.max(2, math.floor(length / 1.2))
	for i = 1, count - 1 do
		K.Block(P, Vector3.new(0.2, height - 0.45, 0.2), frame * CFrame.new(0, 0.35 + (height - 0.35) / 2, -i * length / count), color, true)
	end
end

-- Porch on the front of a wall (`wall` = ground point on the wall at the porch center). Options:
--   Width, Depth, Floor (deck height, 1.2), Columns (x list), ColumnHeight (deck to roof underside, incl. the
--   beam), Style (column style), Color (trim), Rail (railings between columns), RailColor, SideRails (default
--   on with Rail), StepX, StepWidth,
--   Roof ("Shed" | "Gable" | nil when a house roof above covers it), RoofColor, GableRise.
-- Deck with plank lines, edge board and dark skirt, steps, columns on a beam. Returns the CFrame of the
-- front edge under the roof (center), for hanging decorations.
function Architecture.Porch(L: Layers, wall: CFrame, o: { [string]: any }): CFrame
	local P = L.Details
	local W, Dp, F = o.Width, o.Depth, o.Floor or 1.2
	local trim = o.Color or C.Trim
	local stepX, stepW = o.StepX or 0, o.StepWidth or 3.6
	local colH = o.ColumnHeight or 7
	local columns = o.Columns or {}
	local colZ = -Dp + 0.6

	K.Block(P, Vector3.new(W, F, Dp), wall * CFrame.new(0, F / 2, -Dp / 2), C.WoodLight)
	for x = -W / 2 + 3.5, W / 2 - 1, 3.5 do
		K.Block(P, Vector3.new(0.1, 0.04, Dp - 0.2), wall * CFrame.new(x, F + 0.02, -Dp / 2), K.Dark(C.WoodLight), true)
	end
	K.Block(P, Vector3.new(W + 0.2, 0.35, 0.35), wall * CFrame.new(0, F - 0.175, -Dp - 0.05), trim, true)
	K.Block(P, Vector3.new(W - 0.6, F - 0.45, 0.06), wall * CFrame.new(0, (F - 0.45) / 2, -Dp - 0.03), K.Dark(C.WoodLight), true)
	local steps = math.max(2, math.round(F / 0.6))
	for k = 1, steps - 1 do
		local top = k * F / steps
		K.Block(P, Vector3.new(stepW, top, 0.9), wall * CFrame.new(stepX, top / 2, -Dp - (steps - k) * 0.9 + 0.45), C.Stone)
	end

	if #columns > 0 then
		for _, x in columns do
			Architecture.Column(P, wall * CFrame.new(x, F, colZ), colH - 0.6, o.Style, trim)
		end
		local first, last = columns[1], columns[#columns]
		local span = last - first
		K.Block(P, Vector3.new(span + 1, 0.6, 0.6), wall * CFrame.new((first + last) / 2, F + colH - 0.3, colZ), trim, true)
		K.Ink(P, Vector3.new(span + 1, 0.12, 0.1), wall * CFrame.new((first + last) / 2, F + colH - 0.6, colZ - 0.32))
		for _, x in { first, last } do
			K.Block(P, Vector3.new(0.6, 0.6, -colZ), wall * CFrame.new(x, F + colH - 0.3, colZ / 2), trim, true)
		end
		if o.Rail then
			local railColor = o.RailColor or trim
			local function rail(x1: number, z1: number, x2: number, z2: number)
				Architecture.Railing(P, (wall * CFrame.new(x1, F, z1)).Position, (wall * CFrame.new(x2, F, z2)).Position, 2.4, railColor)
			end
			for i = 1, #columns - 1 do
				local a, b = columns[i] + 0.5, columns[i + 1] - 0.5
				local gapA, gapB = stepX - stepW / 2, stepX + stepW / 2
				if gapA < b and gapB > a then
					rail(a, colZ, gapA, colZ)
					rail(gapB, colZ, b, colZ)
				else
					rail(a, colZ, b, colZ)
				end
			end
			if o.SideRails ~= false then
				rail(first, -0.5, first, colZ + 0.5)
				rail(last, -0.5, last, colZ + 0.5)
			end
		end
	end

	local roofColor = o.RoofColor or C.Roofs[2]
	if o.Roof == "Shed" then
		local pitch = math.rad(14)
		local reach = Dp + 1.0
		local wallY = F + colH + math.abs(colZ) * math.tan(pitch)
		local length = reach / math.cos(pitch)
		local slab = wall * CFrame.new(0, wallY - (reach / 2) * math.tan(pitch), -reach / 2) * CFrame.Angles(-pitch, 0, 0) * CFrame.new(0, 0.25, 0)
		K.Block(L.Roofs, Vector3.new(W + 0.8, 0.5, length), slab, roofColor)
		for i = 1, math.floor((length - 0.4) / 1.5) do
			K.Block(L.Roofs, Vector3.new(W + 0.4, 0.1, 0.3), slab * CFrame.new(0, 0.29, -length / 2 + i * 1.5), K.Dark(roofColor), true)
		end
		K.Block(L.Roofs, Vector3.new(W + 0.9, 0.7, 0.35), slab * CFrame.new(0, -0.1, -length / 2 + 0.17), trim, true)
		K.Ink(L.Roofs, Vector3.new(W + 0.95, 0.12, 0.4), slab * CFrame.new(0, -0.5, -length / 2 + 0.17))
		return slab * CFrame.new(0, -0.55, -length / 2 + 0.17)
	elseif o.Roof == "Gable" then
		Architecture.GableRoof(L, wall * CFrame.new(0, 0, -Dp / 2) * CFrame.Angles(0, math.pi / 2, 0), Dp, W, F + colH, o.GableRise or 2.4, roofColor, trim, { Over = 1.0, Vents = false, Gutters = false })
	end
	return wall * CFrame.new(0, F + colH - 0.6, colZ - 0.4)
end

-- Garage with a front-gable roof, lantern and a sectional door: framing with an ink outline, four sections
-- split by ink seams, raised panels, a window row and a handle (`box` = ground center, front = LookVector).
-- Returns the wall CFrame at the bottom center of the door.
function Architecture.Garage(L: Layers, box: CFrame, gW: number, gD: number, gH: number, wallColor: Color3, roofColor: Color3, finish: string?, rng: Random, trim: Color3?)
	local trimColor = trim or C.Trim
	Architecture.Walls(L, box, gW, gH, gD, wallColor, finish, trimColor, rng)
	Architecture.GableRoof(L, box * CFrame.Angles(0, math.pi / 2, 0), gD, gW, gH, gW * 0.3, roofColor, wallColor)
	local P = L.Details
	local front = box * CFrame.new(0, 0, -gD / 2)
	local dw, dh = gW - 3, math.min(gH - 1.8, 7)
	K.Ink(P, Vector3.new(dw + 1.5, dh + 0.75, 0.1), front * CFrame.new(0, (dh + 0.75) / 2, -0.05))
	for _, s in { -1, 1 } do
		K.Block(P, Vector3.new(0.5, dh + 0.5, 0.5), front * CFrame.new(s * (dw / 2 + 0.25), (dh + 0.5) / 2, -0.35), trimColor, true)
	end
	K.Block(P, Vector3.new(dw + 1.0, 0.5, 0.5), front * CFrame.new(0, dh + 0.25, -0.35), trimColor, true)
	local door = front * CFrame.new(0, dh / 2, -0.16)
	K.Block(P, Vector3.new(dw, dh, 0.12), door, C.Trim, true)
	local section = dh / 4
	for k = 1, 3 do
		K.Ink(P, Vector3.new(dw, 0.1, 0.06), door * CFrame.new(0, -dh / 2 + k * section, -0.08))
	end
	local panel = C.Trim:Lerp(C.Ink, 0.1)
	for col = -1, 1 do
		for row = 0, 2 do
			K.Block(P, Vector3.new(dw / 3 - 0.6, section - 0.6, 0.06), door * CFrame.new(col * dw / 3, -dh / 2 + (row + 0.5) * section, -0.09), panel, true)
		end
		K.Block(P, Vector3.new(dw / 3 - 0.6, section - 0.8, 0.06), door * CFrame.new(col * dw / 3, -dh / 2 + 3.5 * section, -0.09), C.Glass, true)
	end
	K.Block(P, Vector3.new(1.0, 0.2, 0.15), door * CFrame.new(0, -dh / 2 + 0.6, -0.15), C.MetalDark, true)
	K.Block(P, Vector3.new(0.3, 0.3, 0.6), front * CFrame.new(0, dh + 1.05, -0.3), C.MetalDark, true)
	local lamp = K.Block(P, Vector3.new(0.55, 0.6, 0.55), front * CFrame.new(0, dh + 0.95, -0.75), Color3.fromRGB(255, 232, 160), true)
	lamp.Material = Enum.Material.Neon
	K.Spire(P, 0.75, 0.35, front * CFrame.new(0, dh + 1.25, -0.75), C.MetalDark, true)
	return front
end

-- Gabled dormer on the front slope of a roof from GableRoof (`box` = that roof's box, `roof` = its info):
-- a box rising out of the slope with a window (w x h) and its own little gable roof, both running back into
-- the main roof far enough to stay hidden under it.
function Architecture.Dormer(L: Layers, box: CFrame, roof: RoofInfo, x: number, w: number, h: number, wallColor: Color3, roofColor: Color3, trim: Color3?)
	local half, wallH, rise = roof.Half, roof.WallH, roof.Rise
	local zf = -half + 2.4
	local yf = wallH + rise * (half + zf) / half -- roof underside at the dormer's front face
	local yt = yf + 2.0 + h + 0.8
	local bw = w + 1.8
	local dRise = bw * 0.3
	-- back end: where the main roof underside climbs above the dormer's ridge
	local zb = math.min(0, -half * (1 - (yt + dRise - wallH) / rise) + 0.3)
	local depth = zb - zf
	local center = box * CFrame.new(x, 0, (zf + zb) / 2)
	K.Block(L.Walls, Vector3.new(bw, yt - yf + 1, depth), center * CFrame.new(0, (yf - 1 + yt) / 2, 0), wallColor)
	for _, s in { -1, 1 } do
		K.Ink(L.Walls, Vector3.new(0.25, yt - yf, 0.25), box * CFrame.new(x + s * bw / 2, (yf + yt) / 2, zf))
	end
	Architecture.GableRoof(L, center * CFrame.Angles(0, math.pi / 2, 0), depth, bw, yt, dRise, roofColor, wallColor, { Over = 0.6, Vents = false, Gutters = false })
	Architecture.Window(L, box * CFrame.new(x, yf + 2.0 + h / 2, zf), w, h, { Trim = trim })
end

return Architecture
