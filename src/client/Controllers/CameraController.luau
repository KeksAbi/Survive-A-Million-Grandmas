--!nonstrict
-- Keeps the normal Roblox camera (right-click drag to turn, mouse wheel to zoom) but starts every spawn
-- further out and higher above the character (Config.Camera). Spectating works through CameraSubject.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CameraController = {}

local function setupCamera(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	camera.CameraType = Enum.CameraType.Custom

	-- Force the start zoom for a moment (the camera scripts read it), then give the player the full range.
	player.CameraMinZoomDistance = Config.Camera.StartZoom
	player.CameraMaxZoomDistance = Config.Camera.StartZoom
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()

	-- Start looking down at StartPitch from behind the character; the camera scripts keep this angle.
	local pitch = math.rad(Config.Camera.StartPitch)
	local back = -root.CFrame.LookVector
	local flatBack = Vector3.new(back.X, 0, back.Z).Unit
	local offset = (flatBack * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)) * Config.Camera.StartZoom
	camera.CFrame = CFrame.lookAt(root.Position + offset, root.Position)

	RunService.RenderStepped:Wait()
	player.CameraMinZoomDistance = Config.Camera.MinZoom
	player.CameraMaxZoomDistance = Config.Camera.MaxZoom
end

function CameraController.Init()
	player.CharacterAdded:Connect(setupCamera)
	if player.Character then
		task.spawn(setupCamera, player.Character)
	end
end

return CameraController
