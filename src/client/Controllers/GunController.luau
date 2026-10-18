--!nonstrict
-- Free-mouse aiming: the crosshair replaces the mouse cursor and bullets fly toward it (the body is not
-- turned; it faces where the player walks). The client draws effects immediately and sends Fire(origin, direction); the server re-checks
-- everything and applies damage (CombatService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local WeaponData = require(Shared.WeaponDefinitions)
local SkinData = require(Shared.SkinDefinitions)

local Effects = require(script.Parent.Parent.Effects)
local InputController = require(script.Parent.InputController)
local HUDController = require(script.Parent.HUDController)
local ViewmodelController = require(script.Parent.ViewmodelController)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local GunController = {}

local fireRemote = Remotes.Get("Fire")
local reloadRemote = Remotes.Get("Reload")
local equipRemote = Remotes.Get("Equip")

local triggerHeld = false
local nextFire = 0
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude
local shotParams = RaycastParams.new() -- same filter as the server's bullet rays
shotParams.FilterType = Enum.RaycastFilterType.Include

-- tracer color of a player's gun skin (nil = default yellow)
local function tracerColor(shooter: Player?): Color3?
	local skin = shooter and SkinData.Skins[tostring(shooter:GetAttribute("Skin") or "")]
	return skin and skin.TracerColor
end

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

-- First person = fully zoomed in: the camera sits on its focus point. (Measuring the distance to the head
-- failed when looking down: the camera then moves a little away from the head.)
local function isFirstPerson(): boolean
	local character = player.Character
	return character ~= nil and character:FindFirstChild("Head") ~= nil
		and (camera.CFrame.Position - camera.Focus.Position).Magnitude < 1
end

-- Phones/tablets without a mouse: aim through the screen center (the camera is turned by dragging).
local function isTouchAiming(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- Touch aim assist: the enemy closest to the aim direction (flat angle) within the assist cone.
local function findAssistTarget(origin: Vector3, direction: Vector3): (Vector3?, number?)
	local enemies = workspace:FindFirstChild("Enemies")
	if not enemies then
		return nil
	end
	local flatDir = Vector3.new(direction.X, 0, direction.Z)
	if flatDir.Magnitude < 0.01 then
		return nil
	end
	flatDir = flatDir.Unit
	local best, bestId, bestAngle = nil, nil, math.rad(Config.Mobile.AimAssistDegrees)
	for _, model in enemies:GetChildren() do
		local root = model:FindFirstChild("Root")
		if root then
			local offset = root.Position - origin
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude > 0.5 and flat.Magnitude <= Config.Mobile.AimAssistRange then
				local angle = math.acos(math.clamp(flatDir:Dot(flat.Unit), -1, 1))
				if angle < bestAngle then
					best, bestId, bestAngle = root.Position, model:GetAttribute("EnemyId"), angle
				end
			end
		end
	end
	return best, bestId
end

-- Screen point to aim through: the center in first person and on touch devices, otherwise the mouse cursor.
local function getAimScreenPoint(): Vector2
	if isFirstPerson() or isTouchAiming() then
		return camera.ViewportSize / 2
	end
	return UserInputService:GetMouseLocation()
end

-- Where the shot should go.
-- First person: exactly what the screen center looks at (up/down included), like an FPS.
-- Otherwise, the camera ray through the mouse cursor:
--   hits an enemy  -> aim exactly at that point;
--   hits anything else (ground, props) -> aim at that spot raised to `muzzleHeight`, so the bullet flies
--   level toward the cursor and keeps going instead of diving into the ground.
local function getAimPoint(muzzleHeight: number): (Vector3, number?)
	aimParams.FilterDescendantsInstances = { player.Character, Effects.Folder }
	local screenPoint = getAimScreenPoint()
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, aimParams)
	-- enemy under the crosshair (sent to the server as a hint for "favor the shooter")
	local enemyId: number? = nil
	local enemies = workspace:FindFirstChild("Enemies")
	if result and enemies and result.Instance:IsDescendantOf(enemies) then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		enemyId = model and model:GetAttribute("EnemyId")
		return result.Position, enemyId
	end
	if isFirstPerson() then
		return (if result then result.Position else ray.Origin + ray.Direction * 500), nil
	end
	if result then
		return Vector3.new(result.Position.X, muzzleHeight, result.Position.Z), nil
	end
	-- cursor in the sky: intersect the ray with the horizontal plane at muzzle height
	local t = if math.abs(ray.Direction.Y) > 0.001 then (muzzleHeight - ray.Origin.Y) / ray.Direction.Y else 100
	return ray.Origin + ray.Direction * math.max(t, 1), nil
end

local function tryFire()
	local weapon = WeaponData.Weapons[player:GetAttribute("Weapon") or ""]
	if not weapon or not getHumanoid() or player:GetAttribute("Reloading") or HUDController.ModalOpen or HUDController.CutsceneActive then
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
	local aimPoint, aimedEnemyId = getAimPoint(origin.Y)
	-- Aim from the gun tip, so the bullet line goes exactly through the crosshair point. Only when the
	-- target is so close that the crosshair point is at or behind the gun tip (point-blank), aim from the
	-- head instead, otherwise the shot would turn around.
	local head = player.Character and player.Character:FindFirstChild("Head")
	local aimFrom = origin
	if head then
		local fromHead = aimPoint - head.Position
		if (aimPoint - origin).Magnitude < 3 or (aimPoint - origin):Dot(fromHead) <= 0 then
			aimFrom = head.Position
		end
	end
	local level = aimedEnemyId == nil and aimPoint.Y == origin.Y and not isFirstPerson() -- cursor on the ground: a flat shot
	local direction = aimPoint - aimFrom
	if level then
		direction = Vector3.new(direction.X, 0, direction.Z)
	end
	if direction.Magnitude < 1 then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		direction = if root then root.CFrame.LookVector else camera.CFrame.LookVector -- cursor on yourself
	end
	direction = direction.Unit
	if isTouchAiming() then
		local assisted, assistedId = findAssistTarget(origin, direction)
		if assisted then
			aimPoint = assisted
			aimedEnemyId = assistedId
			direction = (assisted - aimFrom).Unit
		end
	end
	fireRemote:FireServer(origin, direction, aimedEnemyId)

	-- instant local feedback (cosmetic; the server decides real hits). In first person the flash and the
	-- tracers start at the on-screen gun (viewmodel) instead of the hidden one in the hand.
	local fxOrigin = ViewmodelController.GetMuzzle() or origin
	ViewmodelController.Kick()
	Effects.MuzzleFlash(fxOrigin)
	Effects.PlaySound("Fire_" .. weapon.Id, origin)
	-- tracers end where the bullet really stops: the same ray the server casts (enemies + map, starting
	-- behind the muzzle), so they never fly through trees, benches or the fountain
	local include = {}
	for _, name in { "Enemies", "Map" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(include, folder)
		end
	end
	shotParams.FilterDescendantsInstances = include
	local backOffset = Config.Combat.RayBackOffset
	for pellet = 1, weapon.Pellets do
		local dir = if weapon.Pellets > 1 then WeaponData.PelletDirection(direction, weapon, pellet) else direction
		local hit = workspace:Raycast(origin - dir * backOffset, dir * (weapon.Range + backOffset), shotParams)
		local endPosition = if hit then hit.Position else origin + dir * weapon.Range
		if pellet == 1 and aimedEnemyId and (aimPoint - origin).Magnitude < (endPosition - origin).Magnitude then
			endPosition = aimPoint -- crosshair was on a grandma: the server counts it, so the tracer stops there
		end
		Effects.Trail(fxOrigin, endPosition, tracerColor(player))
		local enemiesFolder = workspace:FindFirstChild("Enemies")
		if hit and not (enemiesFolder and hit.Instance:IsDescendantOf(enemiesFolder)) then
			Effects.HitSpark(endPosition) -- bullet hit the map
		end
	end
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.AutoRotate = true -- the body faces the walking direction (first person: the camera turns it)
	triggerHeld = false
end

-- Every frame after the camera: the crosshair replaces the mouse cursor.
local function aimStep()
	local humanoid = getHumanoid()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	-- MouseBehavior is left to the camera scripts (they lock it while right-click turning the camera)
	if HUDController.CutsceneActive then
		UserInputService.MouseIconEnabled = false
		triggerHeld = false
		return
	end
	if not humanoid or not root or HUDController.ModalOpen then
		UserInputService.MouseIconEnabled = true
		HUDController.SetCrosshair(nil)
		return
	end
	UserInputService.MouseIconEnabled = false
	HUDController.SetCrosshair(getAimScreenPoint())
end

function GunController.Init()
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	RunService:BindToRenderStep("GunAim", Enum.RenderPriority.Camera.Value + 2, aimStep)

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
			Remotes.Get("Purchase"):FireServer(weaponId) -- number key on an unowned gun = buy it (server checks cash)
		end
		nextFire = os.clock() + Config.Combat.SwapDelay -- same swap delay the server enforces
	end)

	-- G: throw a grenade at the ground point under the crosshair (server buys one if the bag is empty)
	InputController.GrenadePressed:Connect(function()
		if not getHumanoid() or HUDController.ModalOpen or HUDController.CutsceneActive then
			return
		end
		aimParams.FilterDescendantsInstances = { player.Character, Effects.Folder }
		local screenPoint = getAimScreenPoint()
		local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
		local result = workspace:Raycast(ray.Origin, ray.Direction * 500, aimParams)
		local target = if result then result.Position else ray.Origin + ray.Direction * 80
		Remotes.Get("ThrowGrenade"):FireServer(target)
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

	Remotes.Get("ShotFx").OnClientEvent:Connect(function(userId: number, _weaponId: string, origin: Vector3, endPosition: Vector3)
		Effects.MuzzleFlash(origin)
		Effects.Trail(origin, endPosition, tracerColor(Players:GetPlayerByUserId(userId)))
	end)
end

return GunController
