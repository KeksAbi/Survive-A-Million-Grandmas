--!nonstrict
-- While the local player is dead (or joined mid-wave), follow a living teammate with the camera.
-- The default camera scripts switch back to the own character automatically when it respawns.

local Players = game:GetService("Players")

local HUDController = require(script.Parent.HUDController)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local SpectateController = {}

local target: Player? = nil

local function livingHumanoid(p: Player): Humanoid?
	local character = p.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function update()
	local own = livingHumanoid(player)
	if own then
		if target then
			target = nil
			camera.CameraSubject = own
		end
		HUDController.SetStatus(nil)
		return
	end

	local matchState = workspace:GetAttribute("MatchState")
	if matchState ~= "Wave" then
		HUDController.SetStatus(nil)
		return
	end

	if not target or target.Parent ~= Players or not livingHumanoid(target) then
		target = nil
		for _, other in Players:GetPlayers() do
			if other ~= player and livingHumanoid(other) then
				target = other
				break
			end
		end
	end
	local spectated = target
	local humanoid = spectated and livingHumanoid(spectated)
	if spectated and humanoid then
		camera.CameraSubject = humanoid
		HUDController.SetStatus("ELIMINATED - SPECTATING " .. string.upper(spectated.DisplayName) .. " - BACK NEXT WAVE")
	else
		HUDController.SetStatus("ELIMINATED - BACK NEXT WAVE")
	end
end

function SpectateController.Init()
	task.spawn(function()
		while true do
			update()
			task.wait(0.5)
		end
	end)
end

return SpectateController
