--!nonstrict
-- Comic-style models for the central park: the tiered Fountain, playground equipment (Slide, CurvySlide,
-- SwingSet, ClimbingFrame, Sandbox, Seesaw, SpringRider), the picnic area (PicnicTable, Pergola, Grill) and lawn
-- decorations (BirdBath, Sundial, SoccerGoal, PicnicBlanket, RoseArch). Every builder takes a parent and a
-- CFrame on the ground (LookVector = the model's front) and returns its Model; MapBuilder places them and
-- registers the round enemy obstacles.

local ComicKit = require(script.Parent.ComicKit)

local K = ComicKit
local C = ComicKit.Colors

local ParkProps = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local RED = rgb(230, 60, 50)
local YELLOW = rgb(255, 205, 40)
local BLUE = rgb(60, 130, 230)
local GREEN = rgb(90, 190, 90)
local SAND = rgb(240, 215, 140)

-- Bar between two world points (round-ish posts, rails, chute pieces). Vertical bars are built upright.
local function bar(parent: Instance, a: Vector3, b: Vector3, thickness: number, color: Color3, deco: boolean?): BasePart
	local d = b - a
	if math.abs(d.X) + math.abs(d.Z) < 0.01 then
		return K.Block(parent, Vector3.new(thickness, math.abs(d.Y), thickness), CFrame.new((a + b) / 2), color, deco)
	end
	return K.Block(parent, Vector3.new(thickness, thickness, d.Magnitude), CFrame.lookAt((a + b) / 2, b), color, deco)
end

local function water(part: BasePart, transparency: number): BasePart
	part.Transparency = transparency
	return part
end

-- Water spray particles on a part (client-rendered).
local function spray(part: BasePart, rate: number, speed: number, spread: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(speed * 0.8, speed)
	emitter.SpreadAngle = Vector2.new(spread, spread)
	emitter.Acceleration = Vector3.new(0, -24, 0)
	emitter.Lifetime = NumberRange.new(0.8, 1.2)
	emitter.Size = NumberSequence.new(0.35, 0.1)
	emitter.Color = ColorSequence.new(rgb(190, 235, 255))
	emitter.LightEmission = 0.3
	emitter.Transparency = NumberSequence.new(0.1, 0.6)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = part
end

-------------------------------------------------------------------------------------------------------- fountain

-- Circular fountain: a raised 12-sided stone basin with an inked rim on a round step, stylized water with foam
-- marks, a pedestal carrying two tiers whose rims pour water curtains, a golden fish on top spouting a jet, and
-- spray particles. Footprint radius about 10.
function ParkProps.Fountain(parent: Instance, position: Vector3): Model
	local model = K.Model("Fountain")
	local stone, light, dark = C.Stone, K.Light(C.Stone), K.Dark(C.Stone)
	local base = CFrame.new(position)
	K.Disc(model, 20.6, 0.1, position, C.Ink, true)
	K.Disc(model, 20, 0.4, position, dark)
	local side = 2 * 8.7 * math.tan(math.rad(15)) + 0.3
	for i = 0, 11 do
		local wall = base * CFrame.Angles(0, i * math.pi / 6, 0) * CFrame.new(0, 0, -8.7)
		K.Block(model, Vector3.new(side, 2.0, 1.4), wall * CFrame.new(0, 1.4, 0), stone)
		K.Ink(model, Vector3.new(side + 0.15, 0.1, 1.95), wall * CFrame.new(0, 2.42, 0))
		K.Block(model, Vector3.new(side + 0.2, 0.4, 1.9), wall * CFrame.new(0, 2.65, 0), light, true)
	end
	water(K.Disc(model, 16.6, 0.3, position + Vector3.new(0, 1.6, 0), C.Water, true), 0.1)
	for i = 0, 7 do
		local radius = if i % 2 == 0 then 6.2 else 3.6
		K.Block(model, Vector3.new(radius * 0.45, 0.06, 0.25), base * CFrame.Angles(0, i * math.pi / 4 + 0.3, 0) * CFrame.new(0, 1.93, -radius), C.GlassShine, true)
	end

	-- pedestal and two tiers with water curtains
	for _, turn in { 0, math.pi / 4 } do
		K.Block(model, Vector3.new(2.6, 3.0, 2.6), base * CFrame.new(0, 3.1, 0) * CFrame.Angles(0, turn, 0), stone)
		K.Block(model, Vector3.new(1.5, 2.6, 1.5), base * CFrame.new(0, 6.0, 0) * CFrame.Angles(0, turn + math.pi / 8, 0), stone, true)
	end
	for _, tier in { { 4.6, 4.6, 8 }, { 7.3, 2.6, 6 } } do
		local y, radius, strands = tier[1], tier[2], tier[3]
		K.Disc(model, radius * 1.4, 0.5, position + Vector3.new(0, y - 0.9, 0), dark, true)
		K.Disc(model, radius * 2 + 0.3, 0.12, position + Vector3.new(0, y - 0.42, 0), C.Ink, true)
		K.Disc(model, radius * 2, 0.5, position + Vector3.new(0, y - 0.4, 0), light, true)
		water(K.Disc(model, radius * 2 - 0.6, 0.12, position + Vector3.new(0, y + 0.08, 0), C.Water, true), 0.1)
		for i = 0, strands - 1 do
			local around = base * CFrame.Angles(0, i * math.pi * 2 / strands + 0.2, 0)
			local top = (around * CFrame.new(0, y - 0.3, -radius - 0.1)).Position
			local bottom = (around * CFrame.new(0, if y > 6 then 4.5 else 1.8, -radius - 0.5)).Position
			water(bar(model, top, bottom, 0.3, C.Water, true), 0.35)
		end
	end

	-- golden leaping fish on a rock: faceted body, big tail fan, side fins, eyes; a jet out of its mouth
	local gold = rgb(255, 190, 50)
	K.Gem(model, 1.2, position + Vector3.new(0, 8.0, 0), dark, Random.new(4))
	local fish = base * CFrame.new(0, 9.9, 0.3) * CFrame.Angles(math.rad(45), 0, 0)
	K.Block(model, Vector3.new(1.2, 1.2, 2.6), fish, gold)
	K.Block(model, Vector3.new(0.95, 0.95, 2.3), fish * CFrame.Angles(0, 0, math.pi / 4), K.Light(gold), true)
	K.Prism(model, 0.2, 1.9, 1.3, fish * CFrame.new(0, 0, 1.2) * CFrame.Angles(math.rad(90), 0, 0), K.Dark(gold), true) -- tail fan pointing back
	for _, s in { -1, 1 } do
		K.Wedge(model, Vector3.new(0.12, 0.5, 0.8), fish * CFrame.new(s * 0.65, -0.3, 0.2), K.Dark(gold), true)
		K.Block(model, Vector3.new(0.12, 0.32, 0.32), fish * CFrame.new(s * 0.6, 0.2, -0.8), C.Trim, true)
		K.Ink(model, Vector3.new(0.14, 0.16, 0.16), fish * CFrame.new(s * 0.62, 0.2, -0.85))
	end
	local mouth = (fish * CFrame.new(0, 0, -1.35)).Position
	local jet = water(K.Block(model, Vector3.new(0.45, 2.4, 0.45), CFrame.new(mouth + Vector3.new(0, 1.2, 0)), C.Water, true), 0.25)
	water(K.Block(model, Vector3.one * 0.9, CFrame.new(mouth + Vector3.new(0, 2.5, 0)) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), C.GlassShine, true), 0.2)
	spray(jet, 35, 9, 18)
	model.Parent = parent
	return model
end

------------------------------------------------------------------------------------------------------ playground

-- Slide tower shared by both slides: four posts, a deck, side rails, a spire roof and a ladder at the back (+Z).
-- The deck is centered on `cframe`; its front edge is at local z = -1.7.
local function slideTower(parent: Instance, cframe: CFrame, roof: Color3)
	for _, x in { -1.5, 1.5 } do
		for _, z in { -1.5, 1.5 } do
			K.Block(parent, Vector3.new(0.45, 6.6, 0.45), cframe * CFrame.new(x, 3.3, z), BLUE)
		end
		K.Block(parent, Vector3.new(0.2, 0.2, 3.2), cframe * CFrame.new(x, 6.0, 0), YELLOW, true)
	end
	K.Block(parent, Vector3.new(3.4, 0.4, 3.4), cframe * CFrame.new(0, 5.0, 0), YELLOW)
	K.Ink(parent, Vector3.new(3.45, 0.08, 3.45), cframe * CFrame.new(0, 4.78, 0))
	K.Spire(parent, 4.2, 2.0, cframe * CFrame.new(0, 6.6, 0), roof, true)
	for _, x in { -0.7, 0.7 } do
		bar(parent, (cframe * CFrame.new(x, 0, 3.6)).Position, (cframe * CFrame.new(x, 5.2, 1.6)).Position, 0.25, BLUE, true)
	end
	for k = 1, 5 do
		local t = k / 6
		K.Block(parent, Vector3.new(1.4, 0.18, 0.18), cframe * CFrame.new(0, 5.2 * t, 3.6 - 2.0 * t), YELLOW, true)
	end
end

-- Chute piece from a to b (world points on its bed): yellow bed with red side walls (only the outer wall when
-- `outer` is given: +1 / -1 = local side).
local function chute(parent: Instance, a: Vector3, b: Vector3, outer: number?)
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	K.Block(parent, Vector3.new(1.6, 0.2, len + 0.15), cf, YELLOW, true)
	for _, s in { -1, 1 } do
		if not outer or outer == s then
			K.Block(parent, Vector3.new(0.2, 0.6, len + 0.15), cf * CFrame.new(s * 0.85, 0.25, 0), RED, true)
		end
	end
	K.Ink(parent, Vector3.new(1.65, 0.06, len + 0.15), cf * CFrame.new(0, -0.12, 0))
end

-- Straight slide: tower with a ladder, a long angled chute to the front with side walls, a run-out and a leg.
function ParkProps.Slide(parent: Instance, cframe: CFrame): Model
	local model = K.Model("Slide")
	slideTower(model, cframe, RED)
	local top, bottom = (cframe * CFrame.new(0, 5.2, -1.7)).Position, (cframe * CFrame.new(0, 0.8, -8.0)).Position
	chute(model, top, bottom)
	chute(model, bottom, (cframe * CFrame.new(0, 0.7, -9.4)).Position)
	K.Block(model, Vector3.new(0.35, 2.6, 0.35), cframe * CFrame.new(0, 1.3, -5.0), BLUE, true)
	model.Parent = parent
	return model
end

-- Curvy slide: tower and a chute that winds a quarter turn to the left on its way down, with outer walls and
-- support posts.
function ParkProps.CurvySlide(parent: Instance, cframe: CFrame): Model
	local model = K.Model("CurvySlide")
	slideTower(model, cframe, GREEN)
	local pivot = cframe * CFrame.new(-3.5, 0, -1.7)
	local points = {}
	for k = 0, 4 do
		local theta = k * (math.pi / 2) / 4
		local y = 5.2 - 4.4 * k / 4
		table.insert(points, (pivot * CFrame.new(3.5 * math.cos(theta), y, -3.5 * math.sin(theta))).Position)
	end
	for k = 1, 4 do
		local a, b = points[k], points[k + 1]
		local cf = CFrame.lookAt((a + b) / 2, b)
		local outer = if cf.RightVector:Dot((a + b) / 2 - pivot.Position) > 0 then 1 else -1
		chute(model, a, b, outer)
		if k % 2 == 1 then
			local mid = (a + b) / 2
			K.Block(model, Vector3.new(0.35, mid.Y - 0.1, 0.35), CFrame.new(Vector3.new(mid.X, (mid.Y - 0.1) / 2, mid.Z)), BLUE, true)
		end
	end
	local last = points[5]
	chute(model, last, last + (last - points[4]).Unit * 1.4 - Vector3.new(0, 0.1, 0))
	model.Parent = parent
	return model
end

-- Swing set along local X: A-frame legs, braces, a top beam with caps, two swings on chains.
function ParkProps.SwingSet(parent: Instance, cframe: CFrame): Model
	local model = K.Model("SwingSet")
	for _, x in { -5, 5 } do
		for _, z in { -1.8, 1.8 } do
			bar(model, (cframe * CFrame.new(x, 0, z)).Position, (cframe * CFrame.new(x, 7, 0)).Position, 0.35, RED)
		end
		K.Block(model, Vector3.new(0.25, 0.25, 2.6), cframe * CFrame.new(x, 2.5, 0), YELLOW, true)
		K.Block(model, Vector3.new(0.6, 0.6, 0.6), cframe * CFrame.new(x * 1.08, 7.1, 0), YELLOW, true)
	end
	K.Block(model, Vector3.new(10.4, 0.4, 0.4), cframe * CFrame.new(0, 7.1, 0), RED)
	for i, x in { -2.2, 2.2 } do
		for _, dx in { -0.6, 0.6 } do
			K.Block(model, Vector3.new(0.08, 5.3, 0.08), cframe * CFrame.new(x + dx, 4.35, 0), C.MetalDark, true)
		end
		K.Block(model, Vector3.new(1.5, 0.2, 0.7), cframe * CFrame.new(x, 1.65, 0), if i == 1 then BLUE else GREEN, true)
		K.Ink(model, Vector3.new(1.55, 0.06, 0.75), cframe * CFrame.new(x, 1.52, 0))
	end
	model.Parent = parent
	return model
end

-- Climbing frame: a 3 x 3 grid of posts with rails on two levels, a small deck with a flag on one corner.
function ParkProps.ClimbingFrame(parent: Instance, cframe: CFrame): Model
	local model = K.Model("ClimbingFrame")
	for _, x in { -3, 0, 3 } do
		for _, z in { -3, 0, 3 } do
			K.Block(model, Vector3.new(0.35, 4.6, 0.35), cframe * CFrame.new(x, 2.3, z), BLUE, x ~= 0 or z ~= 0)
		end
	end
	for _, y in { 2.3, 4.5 } do
		for _, v in { -3, 0, 3 } do
			K.Block(model, Vector3.new(6.2, 0.22, 0.22), cframe * CFrame.new(0, y, v), YELLOW, true)
			K.Block(model, Vector3.new(0.22, 0.22, 6.2), cframe * CFrame.new(v, y, 0), YELLOW, true)
		end
	end
	K.Block(model, Vector3.new(3.2, 0.3, 3.2), cframe * CFrame.new(1.5, 4.7, 1.5), RED, true)
	K.Ink(model, Vector3.new(3.25, 0.08, 3.25), cframe * CFrame.new(1.5, 4.52, 1.5))
	K.Block(model, Vector3.new(0.12, 2.4, 0.12), cframe * CFrame.new(3, 5.8, 3), C.MetalDark, true)
	K.Prism(model, 0.06, 1.0, 1.2, cframe * CFrame.new(3, 6.4, 3) * CFrame.Angles(0, 0, -math.pi / 2), RED, true)
	model.Parent = parent
	return model
end

-- Sandbox: wooden border with corner seats, sand, a sand castle with a flag, a bucket and a spade.
function ParkProps.Sandbox(parent: Instance, cframe: CFrame): Model
	local model = K.Model("Sandbox")
	for _, s in { -1, 1 } do
		K.Block(model, Vector3.new(7.4, 0.7, 0.5), cframe * CFrame.new(0, 0.35, s * 3.45), C.Wood)
		K.Block(model, Vector3.new(0.5, 0.7, 6.4), cframe * CFrame.new(s * 3.45, 0.35, 0), C.Wood)
		for _, t in { -1, 1 } do
			K.Block(model, Vector3.new(1.2, 0.2, 1.2), cframe * CFrame.new(s * 3.2, 0.8, t * 3.2), C.WoodLight, true)
		end
	end
	K.Block(model, Vector3.new(6.4, 0.3, 6.4), cframe * CFrame.new(0, 0.4, 0), SAND, true)
	local castle = cframe * CFrame.new(-1.0, 0.55, 0.6)
	K.Block(model, Vector3.new(1.6, 0.8, 1.6), castle * CFrame.new(0, 0.4, 0), K.Dark(SAND), true)
	for _, x in { -0.7, 0.7 } do
		for _, z in { -0.7, 0.7 } do
			K.Block(model, Vector3.new(0.45, 1.2, 0.45), castle * CFrame.new(x, 0.6, z), K.Dark(SAND), true)
		end
	end
	K.Block(model, Vector3.new(0.06, 0.9, 0.06), castle * CFrame.new(0, 1.25, 0), C.Ink, true)
	K.Block(model, Vector3.new(0.05, 0.3, 0.45), castle * CFrame.new(0, 1.55, 0.25), RED, true)
	K.Cylinder(model, Vector3.new(0.8, 0.7, 0.7), cframe * CFrame.new(1.6, 0.95, -1.2) * CFrame.Angles(0, 0, math.pi / 2), BLUE, true)
	K.Block(model, Vector3.new(0.12, 0.12, 1.1), cframe * CFrame.new(1.2, 0.7, 1.4) * CFrame.Angles(0.3, 0.6, 0), YELLOW, true)
	K.Block(model, Vector3.new(0.45, 0.06, 0.5), cframe * CFrame.new(1.45, 0.6, 1.85) * CFrame.Angles(0.3, 0.6, 0), RED, true)
	model.Parent = parent
	return model
end

-- Seesaw along local X: pivot stand, tilted plank, colored seats with T handles.
function ParkProps.Seesaw(parent: Instance, cframe: CFrame): Model
	local model = K.Model("Seesaw")
	for _, s in { -1, 1 } do
		K.Wedge(model, Vector3.new(0.3, 1.1, 0.8), cframe * CFrame.new(0, 0.55, s * 0.4) * CFrame.Angles(0, if s == 1 then math.pi else 0, 0), C.MetalDark, true)
	end
	K.Cylinder(model, Vector3.new(0.5, 0.35, 1.2), cframe * CFrame.new(0, 1.15, 0) * CFrame.Angles(0, math.pi / 2, 0), RED, true)
	local plank = cframe * CFrame.new(0, 1.25, 0) * CFrame.Angles(0, 0, math.rad(10))
	K.Block(model, Vector3.new(8, 0.3, 0.9), plank, YELLOW, true)
	K.Ink(model, Vector3.new(8.05, 0.06, 0.95), plank * CFrame.new(0, -0.17, 0))
	for i, s in { -1, 1 } do
		K.Block(model, Vector3.new(1.0, 0.25, 1.0), plank * CFrame.new(s * 3.3, 0.27, 0), if i == 1 then BLUE else GREEN, true)
		K.Block(model, Vector3.new(0.15, 0.9, 0.15), plank * CFrame.new(s * 2.5, 0.6, 0), RED, true)
		K.Block(model, Vector3.new(0.15, 0.15, 0.9), plank * CFrame.new(s * 2.5, 1.0, 0), RED, true)
	end
	model.Parent = parent
	return model
end

-- Spring rider ("Duck" or "Horse") on a coil spring and a round base. Faces LookVector.
function ParkProps.SpringRider(parent: Instance, cframe: CFrame, kind: string): Model
	local model = K.Model("SpringRider")
	K.Disc(model, 1.6, 0.2, cframe.Position, C.MetalDark, true)
	for k = 0, 3 do
		K.Block(model, Vector3.new(0.7, 0.18, 0.7), cframe * CFrame.new(0, 0.35 + k * 0.25, 0) * CFrame.Angles(0, k * math.pi / 4, 0), C.Metal, true)
	end
	local body = cframe * CFrame.new(0, 1.7, 0)
	if kind == "Duck" then
		K.Block(model, Vector3.new(1.3, 1.0, 1.9), body, YELLOW)
		K.Block(model, Vector3.new(1.1, 0.8, 1.5), body * CFrame.new(0, 0.1, 0.1) * CFrame.Angles(0.5, 0, 0), YELLOW, true)
		K.Block(model, Vector3.new(0.9, 0.9, 0.9), body * CFrame.new(0, 1.0, -0.8), YELLOW, true)
		K.Wedge(model, Vector3.new(0.6, 0.3, 0.6), body * CFrame.new(0, 0.85, -1.5) * CFrame.Angles(0, math.pi, 0), rgb(255, 140, 40), true)
		for _, s in { -1, 1 } do
			K.Ink(model, Vector3.new(0.08, 0.2, 0.2), body * CFrame.new(s * 0.46, 1.15, -1.0))
		end
	else
		K.Block(model, Vector3.new(1.0, 1.0, 2.2), body, RED)
		bar(model, (body * CFrame.new(0, 0.3, -0.9)).Position, (body * CFrame.new(0, 1.4, -1.4)).Position, 0.6, RED, true)
		K.Block(model, Vector3.new(0.7, 0.6, 1.1), body * CFrame.new(0, 1.5, -1.7), RED, true)
		K.Block(model, Vector3.new(0.2, 0.9, 0.25), body * CFrame.new(0, 1.2, -1.2), YELLOW, true)
		K.Wedge(model, Vector3.new(0.15, 0.4, 0.3), body * CFrame.new(0.2, 1.95, -1.5), RED, true)
		K.Block(model, Vector3.new(0.25, 0.8, 0.25), body * CFrame.new(0, 0.2, 1.2) * CFrame.Angles(0.5, 0, 0), YELLOW, true)
	end
	K.Block(model, Vector3.new(1.2, 0.12, 0.12), body * CFrame.new(0, 1.0, -0.5), C.MetalDark, true)
	model.Parent = parent
	return model
end

------------------------------------------------------------------------------------------------------ picnic area

-- Wooden picnic table along local X: three top planks, two benches, crossed A-frame legs and bench supports.
function ParkProps.PicnicTable(parent: Instance, cframe: CFrame): Model
	local model = K.Model("PicnicTable")
	for _, z in { -0.95, 0, 0.95 } do
		K.Block(model, Vector3.new(5.6, 0.25, 0.88), cframe * CFrame.new(0, 2.6, z), C.WoodLight)
	end
	for _, s in { -1, 1 } do
		K.Block(model, Vector3.new(5.6, 0.25, 0.9), cframe * CFrame.new(0, 1.5, s * 2.0), C.WoodLight)
		K.Ink(model, Vector3.new(5.65, 0.06, 0.95), cframe * CFrame.new(0, 1.35, s * 2.0))
		for _, x in { -2.2, 2.2 } do
			bar(model, (cframe * CFrame.new(x, 0, s * 1.7)).Position, (cframe * CFrame.new(x, 2.5, -s * 0.3)).Position, 0.3, C.Wood, true)
		end
	end
	for _, x in { -2.2, 2.2 } do
		K.Block(model, Vector3.new(0.3, 0.25, 4.6), cframe * CFrame.new(x, 1.32, 0), C.Wood, true)
	end
	K.Ink(model, Vector3.new(5.65, 0.06, 2.75), cframe * CFrame.new(0, 2.45, 0))
	model.Parent = parent
	return model
end

-- Wooden pergola (w along X, d along Z): six posts on stone plinths, two main beams, cross joists, a slatted
-- roof and a few climbing vine clumps.
function ParkProps.Pergola(parent: Instance, cframe: CFrame, w: number, d: number, rng: Random): Model
	local model = K.Model("Pergola")
	local h = 7.5
	for _, x in { -w / 2, 0, w / 2 } do
		for _, z in { -d / 2, d / 2 } do
			K.Block(model, Vector3.new(1.0, 0.6, 1.0), cframe * CFrame.new(x, 0.3, z), C.Stone)
			K.Block(model, Vector3.new(0.6, h, 0.6), cframe * CFrame.new(x, h / 2, z), C.Wood)
		end
	end
	for _, z in { -d / 2, d / 2 } do
		K.Block(model, Vector3.new(w + 2, 0.55, 0.5), cframe * CFrame.new(0, h + 0.2, z), C.Wood, true)
	end
	for x = -w / 2 - 0.5, w / 2 + 0.6, 1.5 do
		K.Block(model, Vector3.new(0.3, 0.4, d + 1.6), cframe * CFrame.new(x, h + 0.65, 0), K.Dark(C.Wood), true)
	end
	for z = -d / 2 + 0.3, d / 2, 1.2 do
		K.Block(model, Vector3.new(w + 1, 0.2, 0.25), cframe * CFrame.new(0, h + 0.95, z), C.WoodLight, true)
	end
	for i = 1, 4 do
		local at = cframe * CFrame.new((i - 2.5) * w / 4, h + 1.1, (if i % 2 == 0 then 1 else -1) * d / 3)
		K.Gem(model, 1.4, at.Position, C.Leaves[i % #C.Leaves + 1], rng, true)
	end
	model.Parent = parent
	return model
end

-- Kettle barbecue grill on three legs with a lid handle.
function ParkProps.Grill(parent: Instance, cframe: CFrame): Model
	local model = K.Model("Grill")
	for i = 0, 2 do
		local foot = (cframe * CFrame.Angles(0, i * math.pi * 2 / 3, 0) * CFrame.new(0, 0, -0.8)).Position
		bar(model, foot, (cframe * CFrame.new(0, 1.8, 0)).Position, 0.14, C.MetalDark, true)
	end
	K.Cylinder(model, Vector3.new(0.9, 1.5, 1.5), cframe * CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.pi / 2), C.Ink)
	K.Gem(model, 1.3, (cframe * CFrame.new(0, 2.65, 0)).Position, rgb(60, 60, 70), Random.new(3), true)
	K.Block(model, Vector3.new(0.5, 0.15, 0.15), cframe * CFrame.new(0, 3.3, 0), C.Wood, true)
	model.Parent = parent
	return model
end

------------------------------------------------------------------------------------------------- lawn decorations

-- Bird bath: eight-sided pedestal, bowl with water and a little blue bird on the rim.
function ParkProps.BirdBath(parent: Instance, cframe: CFrame): Model
	local model = K.Model("BirdBath")
	for _, turn in { 0, math.pi / 4 } do
		K.Block(model, Vector3.new(0.8, 2.2, 0.8), cframe * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, turn, 0), C.Stone)
	end
	K.Disc(model, 2.6, 0.35, (cframe * CFrame.new(0, 2.2, 0)).Position, K.Light(C.Stone), true)
	water(K.Disc(model, 2.0, 0.06, (cframe * CFrame.new(0, 2.52, 0)).Position, C.Water, true), 0.1)
	local bird = cframe * CFrame.new(0.9, 2.85, 0)
	K.Block(model, Vector3.new(0.35, 0.35, 0.55), bird, BLUE, true)
	K.Block(model, Vector3.new(0.3, 0.3, 0.3), bird * CFrame.new(0, 0.25, -0.3), BLUE, true)
	K.Block(model, Vector3.new(0.1, 0.1, 0.2), bird * CFrame.new(0, 0.25, -0.5), rgb(255, 160, 40), true)
	model.Parent = parent
	return model
end

-- Sundial: eight-sided pedestal, round brass plate, inked hour marks and a wedge gnomon.
function ParkProps.Sundial(parent: Instance, cframe: CFrame): Model
	local model = K.Model("Sundial")
	for _, turn in { 0, math.pi / 4 } do
		K.Block(model, Vector3.new(1.0, 2.0, 1.0), cframe * CFrame.new(0, 1.0, 0) * CFrame.Angles(0, turn, 0), C.Stone)
	end
	K.Disc(model, 1.9, 0.15, (cframe * CFrame.new(0, 2.0, 0)).Position, rgb(220, 170, 60), true)
	for i = 0, 3 do
		K.Ink(model, Vector3.new(0.08, 0.04, 0.4), cframe * CFrame.new(0, 2.16, 0) * CFrame.Angles(0, i * math.pi / 4, 0) * CFrame.new(0, 0, -0.65))
	end
	K.Wedge(model, Vector3.new(0.08, 0.6, 0.8), cframe * CFrame.new(0, 2.45, 0.1), rgb(180, 130, 40), true)
	model.Parent = parent
	return model
end

-- Small soccer goal facing LookVector: posts, crossbar, back frame and inked net lines.
function ParkProps.SoccerGoal(parent: Instance, cframe: CFrame): Model
	local model = K.Model("SoccerGoal")
	for _, x in { -3, 3 } do
		K.Block(model, Vector3.new(0.3, 3.0, 0.3), cframe * CFrame.new(x, 1.5, 0), C.Trim)
		bar(model, (cframe * CFrame.new(x, 3.0, 0)).Position, (cframe * CFrame.new(x, 0, 2.2)).Position, 0.2, C.Trim, true)
	end
	K.Block(model, Vector3.new(6.3, 0.3, 0.3), cframe * CFrame.new(0, 3.0, 0), C.Trim, true)
	K.Block(model, Vector3.new(6.2, 0.2, 0.2), cframe * CFrame.new(0, 0.1, 2.2), C.Trim, true)
	for x = -2, 2, 1 do
		bar(model, (cframe * CFrame.new(x, 3.0, 0.05)).Position, (cframe * CFrame.new(x, 0.1, 2.2)).Position, 0.06, C.Ink, true)
	end
	for _, f in { 0.33, 0.66 } do
		K.Block(model, Vector3.new(6.0, 0.06, 0.06), cframe * CFrame.new(0, 3.0 * (1 - f), 2.2 * f), C.Ink, true)
	end
	model.Parent = parent
	return model
end

-- Checkered picnic blanket with a basket, and a soccer ball beside it.
function ParkProps.PicnicBlanket(parent: Instance, cframe: CFrame): Model
	local model = K.Model("PicnicBlanket")
	K.Block(model, Vector3.new(4, 0.05, 4), cframe * CFrame.new(0, 0.03, 0), RED, true)
	for i = -1, 1 do
		K.Block(model, Vector3.new(0.6, 0.06, 4), cframe * CFrame.new(i * 1.3, 0.035, 0), C.Trim, true)
		K.Block(model, Vector3.new(4, 0.06, 0.6), cframe * CFrame.new(0, 0.036, i * 1.3), C.Trim, true)
	end
	K.Block(model, Vector3.new(1.2, 0.8, 0.8), cframe * CFrame.new(0.8, 0.45, -0.6), C.WoodLight, true)
	bar(model, (cframe * CFrame.new(0.3, 0.85, -0.6)).Position, (cframe * CFrame.new(0.8, 1.4, -0.6)).Position, 0.1, C.Wood, true)
	bar(model, (cframe * CFrame.new(0.8, 1.4, -0.6)).Position, (cframe * CFrame.new(1.3, 0.85, -0.6)).Position, 0.1, C.Wood, true)
	local ball = (cframe * CFrame.new(3.2, 0.45, 1.5)).Position
	K.Gem(model, 0.85, ball, C.Trim, Random.new(9), true)
	K.Ink(model, Vector3.new(0.3, 0.3, 0.3), CFrame.new(ball + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0.4, 0.4, 0))
	model.Parent = parent
	return model
end

-- Rose arch over a path (the path runs along local Z): two lattice posts, an arched top of three angled bars,
-- climbing roses.
function ParkProps.RoseArch(parent: Instance, cframe: CFrame, rng: Random): Model
	local model = K.Model("RoseArch")
	local half = 2.2
	for _, s in { -1, 1 } do
		for _, z in { -0.4, 0.4 } do
			K.Block(model, Vector3.new(0.25, 5.2, 0.25), cframe * CFrame.new(s * half, 2.6, z), C.Trim)
		end
		for y = 1, 4, 1.5 do
			K.Block(model, Vector3.new(0.15, 0.15, 0.9), cframe * CFrame.new(s * half, y, 0), C.Trim, true)
		end
	end
	local p1, p2, p3, p4 = Vector3.new(-half, 5.2, 0), Vector3.new(-1.1, 6.3, 0), Vector3.new(1.1, 6.3, 0), Vector3.new(half, 5.2, 0)
	for _, seg in { { p1, p2 }, { p2, p3 }, { p3, p4 } } do
		bar(model, (cframe * CFrame.new(seg[1])).Position, (cframe * CFrame.new(seg[2])).Position, 0.3, C.Trim, true)
	end
	for i = 1, 6 do
		local spot = ({ p1, p2, p3, p4, Vector3.new(-half, 3, 0), Vector3.new(half, 2.4, 0) })[i]
		local at = (cframe * CFrame.new(spot)).Position
		K.Gem(model, 0.9, at, C.Leaves[2], rng, true)
		K.Block(model, Vector3.one * 0.45, CFrame.new(at + Vector3.new(0, 0.35, -0.3)) * CFrame.Angles(0.6, i, 0.3), rgb(225, 40, 60), true)
	end
	model.Parent = parent
	return model
end

return ParkProps
