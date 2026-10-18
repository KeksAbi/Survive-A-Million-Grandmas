--!nonstrict
-- The 3D gun models: the gun in the player's hand (server, CombatService) and the 3D icons in the shop,
-- hotbar and store (client). Icons and held guns come from the same model, skins included.
--
-- Two sources, checked in this order:
--   1. Detailed mesh models imported in Studio (File > Import 3D) and placed in ReplicatedStorage.WeaponModels,
--      named after the weapon id (Pistol, Shotgun, AssaultRifle). Needed: one part whose name contains "Grip"
--      (the hand holds its top) and one whose name contains "Barrel" (its front end = the muzzle). Orientation,
--      position and size are worked out here, so the import can be rotated or scaled any way.
--      Skins recolor parts whose names end in "_Body" / "_Accent" (the material names from the prompt).
--   2. Otherwise a part-built gun from DESIGNS below.
-- Every gun is returned in grip space: the hand at the origin, barrel toward -Z, up +Y. Each part stores its
-- grip-space CFrame in the "Offset" attribute; an invisible "Handle" part at the grip carries the "Muzzle"
-- attachment (bullets and muzzle flashes start there).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinData = require(ReplicatedStorage:WaitForChild("Shared").SkinDefinitions)

local GunModels = {}

-- Fixed colors; "Body" and "Accent" come from the weapon (or the skin).
local COLORS = {
	Dark = Color3.fromRGB(38, 40, 46),
	Metal = Color3.fromRGB(120, 124, 132),
	Wood = Color3.fromRGB(150, 92, 48),
}

local Z_AXIS = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder (X axis) along the barrel

type PartSpec = { any } -- { name, size, offset, color role, shape? }

-- Length (studs, back of the stock to the muzzle) an imported model is scaled to.
local TARGET_LENGTH = { Pistol = 1.7, Shotgun = 4.3, AssaultRifle = 4.3 }

-- Support = where the left hand holds (pump, handguard; for the pistol: cupping the right hand).
local DESIGNS: { [string]: { Parts: { PartSpec }, Muzzle: Vector3, Support: Vector3 } } = {
	Pistol = {
		Parts = {
			{ "Slide", Vector3.new(0.32, 0.3, 1.45), CFrame.new(0, 0.2, -0.45), "Body" },
			{ "Frame", Vector3.new(0.28, 0.2, 1.15), CFrame.new(0, -0.03, -0.38), "Dark" },
			{ "Barrel", Vector3.new(0.22, 0.14, 0.14), CFrame.new(0, 0.2, -1.25) * Z_AXIS, "Metal", Enum.PartType.Cylinder },
			{ "Grip", Vector3.new(0.27, 0.72, 0.36), CFrame.new(0, -0.38, 0.12) * CFrame.Angles(math.rad(-14), 0, 0), "Accent" },
			{ "Guard", Vector3.new(0.08, 0.24, 0.34), CFrame.new(0, -0.22, -0.2), "Dark" },
			{ "Sight", Vector3.new(0.08, 0.1, 0.1), CFrame.new(0, 0.39, -1.08), "Accent" },
			{ "RearSight", Vector3.new(0.2, 0.08, 0.08), CFrame.new(0, 0.38, 0.18), "Dark" },
		},
		Muzzle = Vector3.new(0, 0.2, -1.36),
		Support = Vector3.new(-0.12, -0.35, -0.05),
	},
	Shotgun = {
		Parts = {
			{ "Receiver", Vector3.new(0.34, 0.42, 0.85), CFrame.new(0, 0.06, 0.05), "Body" },
			{ "Barrel", Vector3.new(2.3, 0.22, 0.22), CFrame.new(0, 0.17, -1.55) * Z_AXIS, "Metal", Enum.PartType.Cylinder },
			{ "Tube", Vector3.new(1.75, 0.18, 0.18), CFrame.new(0, -0.06, -1.25) * Z_AXIS, "Dark", Enum.PartType.Cylinder },
			{ "Pump", Vector3.new(0.3, 0.26, 0.7), CFrame.new(0, -0.07, -1.15), "Accent" },
			{ "Grip", Vector3.new(0.24, 0.5, 0.28), CFrame.new(0, -0.32, 0.38) * CFrame.Angles(math.rad(-12), 0, 0), "Accent" },
			{ "Stock", Vector3.new(0.28, 0.42, 1.05), CFrame.new(0, -0.1, 1.0) * CFrame.Angles(math.rad(7), 0, 0), "Accent" },
			{ "Butt", Vector3.new(0.3, 0.5, 0.12), CFrame.new(0, -0.16, 1.55) * CFrame.Angles(math.rad(7), 0, 0), "Dark" },
			{ "Bead", Vector3.new(0.07, 0.07, 0.07), CFrame.new(0, 0.31, -2.6), "Accent" },
		},
		Muzzle = Vector3.new(0, 0.17, -2.72),
		Support = Vector3.new(0, -0.2, -1.2),
	},
	AssaultRifle = {
		Parts = {
			{ "Receiver", Vector3.new(0.3, 0.4, 1.35), CFrame.new(0, 0.05, -0.2), "Body" },
			{ "Stripe", Vector3.new(0.32, 0.08, 1.1), CFrame.new(0, 0.12, -0.2), "Accent" },
			{ "Handguard", Vector3.new(0.3, 0.3, 0.95), CFrame.new(0, 0.08, -1.3), "Dark" },
			{ "Barrel", Vector3.new(0.9, 0.13, 0.13), CFrame.new(0, 0.12, -2.2) * Z_AXIS, "Metal", Enum.PartType.Cylinder },
			{ "FlashHider", Vector3.new(0.2, 0.19, 0.19), CFrame.new(0, 0.12, -2.7) * Z_AXIS, "Dark", Enum.PartType.Cylinder },
			{ "Magazine", Vector3.new(0.22, 0.7, 0.3), CFrame.new(0, -0.42, -0.55) * CFrame.Angles(math.rad(14), 0, 0), "Dark" },
			{ "Grip", Vector3.new(0.22, 0.5, 0.26), CFrame.new(0, -0.33, 0.25) * CFrame.Angles(math.rad(-14), 0, 0), "Accent" },
			{ "Stock", Vector3.new(0.26, 0.38, 0.95), CFrame.new(0, 0, 0.95), "Body" },
			{ "Butt", Vector3.new(0.28, 0.5, 0.12), CFrame.new(0, -0.04, 1.47), "Dark" },
			{ "Rail", Vector3.new(0.12, 0.12, 0.7), CFrame.new(0, 0.31, -0.25), "Dark" },
			{ "Scope", Vector3.new(0.5, 0.2, 0.2), CFrame.new(0, 0.45, -0.25) * Z_AXIS, "Accent", Enum.PartType.Cylinder },
		},
		Muzzle = Vector3.new(0, 0.12, -2.82),
		Support = Vector3.new(0, -0.1, -1.35),
	},
}

local function prepare(part: BasePart, offset: CFrame, base: CFrame)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = base * offset
	part:SetAttribute("Offset", offset)
end

-- Adds the invisible "Handle" at the grip with attachments: Muzzle, RightGrip (right hand), LeftGrip (left hand).
local function finish(model: Model, muzzle: Vector3, support: Vector3, base: CFrame): Model
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.1, 0.1, 0.1)
	handle.Transparency = 1
	prepare(handle, CFrame.identity, base)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Muzzle"
	attachment.Position = muzzle
	attachment.Parent = handle
	-- hand targets, oriented like an R15 hand holding it: fingers (hand -Y) along the gun, so the hand's +Y
	-- points back (+Z). Right hand: thumb (hand LookVector) up. Left hand under the gun: palm up, thumb left.
	local right = Instance.new("Attachment")
	right.Name = "RightGrip"
	right.CFrame = CFrame.fromMatrix(Vector3.new(0.04, -0.25, 0.05), Vector3.xAxis, Vector3.zAxis)
	right.Parent = handle
	local left = Instance.new("Attachment")
	left.Name = "LeftGrip"
	left.CFrame = if support.Z < -0.5
		then CFrame.fromMatrix(support, Vector3.yAxis, Vector3.zAxis) -- under the pump / handguard
		else CFrame.fromMatrix(support, Vector3.xAxis, Vector3.zAxis) -- pistol: cupping the right hand
	left.Parent = handle
	handle.Parent = model
	model.PrimaryPart = handle
	model.Name = "Gun"
	return model
end

local function findPart(model: Model, word: string): BasePart?
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and string.find(string.lower(part.Name), word, 1, true) then
			return part
		end
	end
	return nil
end

-- Half the extent of a part along a world direction.
local function halfExtent(part: BasePart, direction: Vector3): number
	local cf, size = part.CFrame, part.Size
	return (math.abs(cf.RightVector:Dot(direction)) * size.X + math.abs(cf.UpVector:Dot(direction)) * size.Y
		+ math.abs(cf.LookVector:Dot(direction)) * size.Z) / 2
end

-- The world axis (+-X/Y/Z) closest to `v`, skipping axes in `exclude`.
local function nearestAxis(v: Vector3, exclude: { Vector3 }): Vector3
	local best, bestDot = Vector3.zAxis, -1
	for _, axis in { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis } do
		local skip = false
		for _, other in exclude do
			if math.abs(axis:Dot(other)) > 0.9 then
				skip = true
			end
		end
		local d = math.abs(axis:Dot(v))
		if not skip and d > bestDot then
			best, bestDot = axis * (if axis:Dot(v) < 0 then -1 else 1), d
		end
	end
	return best
end

-- Imported mesh gun -> grip-space model.
local function fromImported(template: Model, weapon, skin, base: CFrame): Model
	local model = template:Clone()
	local grip = findPart(model, "grip")
	local barrel = findPart(model, "barrel")
	local boxCFrame, boxSize = model:GetBoundingBox()

	-- barrel direction: the box's longest axis, pointing from the grip toward the barrel
	local axes = { boxCFrame.RightVector * boxSize.X, boxCFrame.UpVector * boxSize.Y, boxCFrame.LookVector * boxSize.Z }
	table.sort(axes, function(a, b)
		return a.Magnitude > b.Magnitude
	end)
	local forward = axes[1].Unit
	local up = Vector3.yAxis
	if grip and barrel then
		local toBarrel = barrel.Position - grip.Position
		if toBarrel:Dot(forward) < 0 then
			forward = -forward
		end
		forward = nearestAxis(forward, {})
		up = nearestAxis(toBarrel - forward * toBarrel:Dot(forward), { forward }) -- barrel sits above the grip
	else
		forward = -Vector3.zAxis
	end
	local right = forward:Cross(up)

	-- scale to the target length
	local length = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local along = (part.Position - boxCFrame.Position):Dot(forward)
			length = math.max(length, 2 * (math.abs(along) + halfExtent(part, forward)))
		end
	end
	local target = TARGET_LENGTH[weapon.Id] or 2
	if length > 0.01 and math.abs(target / length - 1) > 0.02 then
		model:ScaleTo(model:GetScale() * target / length)
		boxCFrame = model:GetBoundingBox()
		grip = findPart(model, "grip")
		barrel = findPart(model, "barrel")
	end

	-- grip point: the top of the grip part (where the hand closes), else the box center
	local gripPoint = boxCFrame.Position
	if grip then
		gripPoint = grip.Position + up * halfExtent(grip, up) * 0.6
	end
	local gripSpace = CFrame.fromMatrix(gripPoint, right, up, -forward)

	-- muzzle: front end of the barrel part (else the front of the whole box)
	local muzzleWorld
	if barrel then
		-- the front-most "barrel" piece (e.g. Barrel_Metal + Barrel_FlashHider)
		local best = -math.huge
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and string.find(string.lower(part.Name), "barrel", 1, true) then
				local front = (part.Position - gripPoint):Dot(forward) + halfExtent(part, forward)
				if front > best then
					best = front
					muzzleWorld = gripPoint + forward * front + up * (part.Position - gripPoint):Dot(up)
				end
			end
		end
	else
		local front = 0
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				front = math.max(front, (part.Position - gripPoint):Dot(forward) + halfExtent(part, forward))
			end
		end
		muzzleWorld = gripPoint + forward * front
	end

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local lower = string.lower(part.Name)
			local color = if string.find(lower, "_body", 1, true) then skin.BodyColor
				elseif string.find(lower, "_accent", 1, true) then skin.AccentColor
				else nil
			if color then
				-- skins replace the imported look of the body/accent pieces
				for _, child in part:GetChildren() do
					if child:IsA("SurfaceAppearance") then
						child:Destroy()
					end
				end
				if part:IsA("MeshPart") then
					part.TextureID = ""
				end
				part.Color = color
				if skin.Material then
					part.Material = skin.Material
				end
			end
			prepare(part, gripSpace:ToObjectSpace(part.CFrame), base)
		end
	end
	-- left hand: under the barrel, 45% of the way to the muzzle (short guns: under the right hand)
	local muzzleLocal = gripSpace:PointToObjectSpace(muzzleWorld)
	local support = if -muzzleLocal.Z > 2.5 then Vector3.new(0, -0.15, muzzleLocal.Z * 0.45) else Vector3.new(-0.12, -0.35, -0.05)
	return finish(model, muzzleLocal, support, base)
end

-- Builds the gun for `weapon` (a WeaponDefinitions entry) in a skin, placed at `origin` (default: world
-- origin). Parts are unanchored, non-colliding and massless.
function GunModels.Build(weapon, skinId: string?, origin: CFrame?): Model
	local skin = SkinData.Skins[skinId or "Default"] or SkinData.Skins.Default
	local base = origin or CFrame.identity

	local folder = ReplicatedStorage:FindFirstChild("WeaponModels")
	local template = folder and folder:FindFirstChild(weapon.Id)
	if template and template:IsA("Model") then
		local ok, result = pcall(fromImported, template, weapon, skin, base)
		if ok then
			return result
		end
		warn("[GunModels] could not use ReplicatedStorage.WeaponModels." .. weapon.Id .. ": " .. tostring(result))
	end

	local design = DESIGNS[weapon.Id] or DESIGNS.Pistol
	local colors = {
		Body = skin.BodyColor or weapon.Look.BodyColor,
		Accent = skin.AccentColor or weapon.Look.AccentColor,
		Dark = COLORS.Dark,
		Metal = COLORS.Metal,
		Wood = COLORS.Wood,
	}
	local model = Instance.new("Model")
	for _, spec in design.Parts do
		local name, size, offset, role, shape = spec[1], spec[2], spec[3], spec[4], spec[5]
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = colors[role]
		part.Material = if (role == "Body" or role == "Accent") and skin.Material then skin.Material else Enum.Material.SmoothPlastic
		if shape then
			part.Shape = shape
		end
		prepare(part, offset, base)
		part.Parent = model
	end
	return finish(model, design.Muzzle, design.Support, base)
end

return GunModels
