--!nonstrict
-- Top-down follow camera: high above and behind the player at a fixed angle, never rotates.
-- Follows the own character, or (while dead) whatever SpectateController set as CameraSubject.
-- Mouse wheel zooms between Config.Camera.ZoomMin and ZoomMax.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CameraController = {}

local zoom = 1
local hasSnapped = false

local function getFocusPart(): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 and humanoid.RootPart then
		return humanoid.RootPart
	end
	local subject = camera.CameraSubject
	if subject and subject:IsA("Humanoid") then
		return subject.RootPart
	elseif subject and subject:IsA("BasePart") then
		return subject
	end
	return nil
end

local function update(dt: number)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Config.Camera.FieldOfView
	local focus = getFocusPart()
	if not focus then
		return
	end
	local target = focus.Position
	local offset = Vector3.new(0, Config.Camera.Height, Config.Camera.Distance) * zoom
	local goal = CFrame.lookAt(target + offset, target)
	if not hasSnapped or (camera.CFrame.Position - goal.Position).Magnitude > 60 then
		camera.CFrame = goal -- first frame or teleport: no slow glide across the map
		hasSnapped = true
	else
		camera.CFrame = camera.CFrame:Lerp(goal, math.min(1, dt * Config.Camera.Smoothness))
	end
end

function CameraController.Init()
	RunService:BindToRenderStep("TopDownCamera", Enum.RenderPriority.Camera.Value + 1, update)
	UserInputService.InputChanged:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom = math.clamp(zoom - input.Position.Z * 0.1, Config.Camera.ZoomMin, Config.Camera.ZoomMax)
		end
	end)
end

return CameraController
