--!nonstrict
-- 3D weapon icons: a ViewportFrame showing the real gun model (GunModels: imported mesh or part-built),
-- side view with the barrel pointing right, in the given skin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GunModels = require(Shared.GunModels)
local WeaponData = require(Shared.WeaponDefinitions)

local GunIcon = {}

-- Shows `weaponId` in `skinId` inside `viewport` (replaces what was there).
function GunIcon.Set(viewport: ViewportFrame, weaponId: string, skinId: string?)
	local weapon = WeaponData.Weapons[weaponId]
	if not weapon then
		return
	end
	viewport:ClearAllChildren()
	local model = GunModels.Build(weapon, skinId)
	model.Parent = viewport

	local center, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 20
	-- camera on the gun's left side looking at it: the barrel (-Z) points to the right of the picture
	local radius = math.max(size.Z, size.Y * 2.2) / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(distance, 0.25 * size.Y, 0), center.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

-- New icon frame. Size/position it like any GuiObject.
function GunIcon.Create(props: { [string]: any }, weaponId: string, skinId: string?): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(170, 170, 180)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-1, -1.5, -0.5)
	for key, value in props do
		if key ~= "Parent" then
			viewport[key] = value
		end
	end
	GunIcon.Set(viewport, weaponId, skinId)
	viewport.Parent = props.Parent
	return viewport
end

return GunIcon
