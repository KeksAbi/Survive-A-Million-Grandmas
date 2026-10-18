--!nonstrict
-- Over-the-shoulder shooting. The client aims (camera center ray), draws effects immediately and sends
-- Fire(origin, direction). The server re-checks everything and applies damage (CombatService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local WeaponData = require(Shared.WeaponDefinitions)

local Effects = require(script.Parent.Parent.Effects)
local InputController = require(script.Parent.InputController)
local HUDController = require(script.Parent.HUDController)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local GunController = {}

local SHOULDER_OFFSET = Vector3.new(2, 0.6, 0)
local CAMERA_DISTANCE = 11

local fireRemote = Remotes.Get("Fire")
local reloadRemote = Remotes.Get("Reload")
local equipRemote = Remotes.Get("Equip")

local triggerHeld = false
local nextFire = 0
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

local function getHumanoid(): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function getMuzzlePosition(): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local gun = character:FindFirstChild("Gun")
	local handle = gun and gun:FindFirstChild("Handle")
	local muzzle = handle and handle:FindFirstChild("Muzzle")
	if muzzle then
		return muzzle.WorldPosition
	end
	local head = character:FindFirstChild("Head")
	return head and head.Position
end

-- Where the crosshair (screen center) points in the world.
local function getAimPoint(range: number): Vector3
	aimParams.FilterDescendantsInstances = { player.Character, Effects.Folder }
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local result = workspace:Raycast(ray.Origin, ray.Direction * (range + 20), aimParams)
	return if result then result.Position else ray.Origin + ray.Direction * (range + 20)
end

local function spreadDirection(direction: Vector3, degrees: number): Vector3
	if degrees <= 0 then
		return direction
	end
	local angle = math.rad(degrees) * math.sqrt(math.random())
	local roll = math.random() * math.pi * 2
	return (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

local function tryFire()
	local weapon = WeaponData.Weapons[player:GetAttribute("Weapon") or ""]
	if not weapon or not getHumanoid() or player:GetAttribute("Reloading") or HUDController.ModalOpen then
		return
	end
	local now = os.clock()
	if now < nextFire then
		return
	end
	if (player:GetAttribute("Ammo") or 0) <= 0 then
		reloadRemote:FireServer()
		nextFire = now + 0.3
		return
	end
	nextFire = now + weapon.FireCooldown

	local origin = getMuzzlePosition()
	if not origin then
		return
	end
	local aimPoint = getAimPoint(weapon.Range)
	local direction = aimPoint - origin
	direction = if direction.Magnitude > 0.1 then direction.Unit else camera.CFrame.LookVector
	fireRemote:FireServer(origin, direction)

	-- instant local feedback (cosmetic; the server decides real hits)
	Effects.MuzzleFlash(origin)
	Effects.PlaySound("Fire_" .. weapon.Id, origin)
	local distance = math.min((aimPoint - origin).Magnitude, weapon.Range)
	for _ = 1, weapon.Pellets do
		local dir = if weapon.Pellets > 1 then spreadDirection(direction, weapon.SpreadDegrees) else direction
		Effects.Trail(origin, origin + dir * distance)
	end
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.AutoRotate = false
	humanoid.CameraOffset = SHOULDER_OFFSET
	player.CameraMinZoomDistance = CAMERA_DISTANCE
	player.CameraMaxZoomDistance = CAMERA_DISTANCE
	triggerHeld = false
end

-- Runs right after the default camera: lock the mouse to the crosshair and turn the body to the camera.
local function aimStep()
	local humanoid = getHumanoid()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or HUDController.ModalOpen then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		return
	end
	if not UserInputService.TouchEnabled or UserInputService.MouseEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
end

function GunController.Init()
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	RunService:BindToRenderStep("GunAim", Enum.RenderPriority.Camera.Value + 1, aimStep)

	InputController.FireBegan:Connect(function()
		triggerHeld = true
		tryFire()
	end)
	InputController.FireEnded:Connect(function()
		triggerHeld = false
	end)
	InputController.ReloadPressed:Connect(function()
		if getHumanoid() then
			reloadRemote:FireServer()
		end
	end)
	InputController.SlotPressed:Connect(function(slot: number)
		local weaponId = WeaponData.Order[slot]
		if not weaponId or player:GetAttribute("Weapon") == weaponId then
			return
		end
		if player:GetAttribute("Owns" .. weaponId) then
			equipRemote:FireServer(weaponId)
		else
			local weapon = WeaponData.Weapons[weaponId]
			HUDController.Notify(string.upper(weapon.Name) .. " COSTS $" .. tostring(weapon.Cost), "bad")
		end
	end)

	-- automatic weapons keep firing while the trigger is held
	RunService.Heartbeat:Connect(function()
		if triggerHeld then
			local weapon = WeaponData.Weapons[player:GetAttribute("Weapon") or ""]
			if weapon and weapon.Automatic then
				tryFire()
			end
		end
	end)

	Remotes.Get("HitFeedback").OnClientEvent:Connect(function(position: Vector3, damage: number, killed: boolean)
		HUDController.ShowHitmarker(killed)
		Effects.HitSpark(position)
		Effects.DamageNumber(position, damage, killed)
		if killed then
			Effects.DeathPuff(position)
			Effects.PlaySound("GrandmaPoof", position)
		else
			Effects.PlaySound("Hit", position)
		end
	end)

	Remotes.Get("ShotFx").OnClientEvent:Connect(function(_userId: number, _weaponId: string, origin: Vector3, endPosition: Vector3)
		Effects.MuzzleFlash(origin)
		Effects.Trail(origin, endPosition)
	end)
end

return GunController
