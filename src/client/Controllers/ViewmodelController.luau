--!nonstrict
-- First-person gun (viewmodel): in first person Roblox hides the own character and its gun, so a local copy
-- of the equipped gun (GunModels, current skin) is drawn at the bottom right of the screen, like in FPS games.
-- Walk bob, camera sway, recoil kick (Kick), reload dip and a raise when switching guns. Client-only, visual.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GunModels = require(Shared.GunModels)
local WeaponData = require(Shared.WeaponDefinitions)

local HUDController = require(script.Parent.HUDController)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local ViewmodelController = {}

-- Where the grip sits relative to the camera (right, down, forward) and how big the gun is drawn, so it
-- stays a corner of the screen and never covers the view.
local HOLD = {
	Pistol = CFrame.new(0.55, -0.55, -1.5),
	Shotgun = CFrame.new(0.5, -0.55, -1.45),
	AssaultRifle = CFrame.new(0.5, -0.55, -1.45),
}
local DEFAULT_HOLD = CFrame.new(0.5, -0.55, -1.45)
local VIEW_SCALE = { Pistol = 0.5, Shotgun = 0.42, AssaultRifle = 0.42 }

local model: Model? = nil
local modelKey = ""
local kick = 0 -- recoil, 1 = full kick, decays to 0
local raise = 1 -- 1 = fully lowered (just switched), eases to 0
local reloadBlend = 0
local swayX, swayY = 0, 0
local lastLook: Vector3? = nil

local function clear()
	if model then
		model:Destroy()
		model = nil
	end
	modelKey = ""
end

local function isFirstPerson(): (boolean, Humanoid?)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid or humanoid.Health <= 0 or HUDController.CutsceneActive then
		return false, nil
	end
	-- fully zoomed in: the camera sits on its focus point (works when looking down too)
	return (camera.CFrame.Position - camera.Focus.Position).Magnitude < 1, humanoid
end

local function rebuild(weaponId: string, skinId: string)
	clear()
	local weapon = WeaponData.Weapons[weaponId]
	if not weapon then
		return
	end
	local gun = GunModels.Build(weapon, skinId)
	gun:ScaleTo(VIEW_SCALE[weaponId] or 0.45)
	for _, part in gun:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanQuery = false
			part.CastShadow = false
		end
	end
	gun.Name = "Viewmodel"
	gun.Parent = camera
	model = gun
	modelKey = weaponId .. "/" .. skinId
	raise = 1
end

local function step(dt: number)
	local first, humanoid = isFirstPerson()
	if not first then
		clear()
		lastLook = nil
		return
	end
	local weaponId = tostring(player:GetAttribute("Weapon") or "Pistol")
	local skinId = tostring(player:GetAttribute("Skin") or "Default")
	if modelKey ~= weaponId .. "/" .. skinId then
		rebuild(weaponId, skinId)
	end
	local gun = model
	if not gun then
		return
	end

	-- springs
	kick = math.max(0, kick - dt * 7)
	raise = math.max(0, raise - dt * 4)
	local reloading = player:GetAttribute("Reloading") == true
	reloadBlend += ((if reloading then 1 else 0) - reloadBlend) * math.min(1, dt * 10)

	-- sway: the gun lags a little behind camera turns
	local look = camera.CFrame.LookVector
	if lastLook then
		local delta = camera.CFrame:VectorToObjectSpace(look - lastLook)
		swayX = math.clamp(swayX - delta.X * 2.5, -0.15, 0.15)
		swayY = math.clamp(swayY - delta.Y * 2.5, -0.15, 0.15)
	end
	lastLook = look
	swayX -= swayX * math.min(1, dt * 8)
	swayY -= swayY * math.min(1, dt * 8)

	-- walk bob
	local speed = if humanoid then humanoid.MoveDirection.Magnitude else 0
	local t = os.clock() * 9
	local bob = CFrame.new(math.cos(t * 0.5) * 0.035 * speed, math.abs(math.sin(t * 0.5)) * 0.04 * speed, 0)

	local ease = raise * raise
	local offset = (HOLD[weaponId] or DEFAULT_HOLD)
		* bob
		* CFrame.new(swayX, swayY, 0)
		* CFrame.new(0, -0.9 * ease - 0.35 * reloadBlend, 0.3 * kick)
		* CFrame.Angles(math.rad(10) * kick - math.rad(35) * reloadBlend - math.rad(20) * ease, 0, math.rad(25) * reloadBlend)
	gun:PivotTo(camera.CFrame * offset)
end

-- Recoil after a shot (called by GunController).
function ViewmodelController.Kick()
	kick = 1
end

-- World position of the viewmodel's muzzle while it is shown (tracers and flashes start there), else nil.
function ViewmodelController.GetMuzzle(): Vector3?
	local handle = model and model:FindFirstChild("Handle")
	local muzzle = handle and handle:FindFirstChild("Muzzle")
	return muzzle and muzzle.WorldPosition
end

function ViewmodelController.Init()
	-- after the camera has moved this frame
	RunService:BindToRenderStep("Viewmodel", Enum.RenderPriority.Camera.Value + 1, step)
	player.CharacterRemoving:Connect(clear)
end

return ViewmodelController
