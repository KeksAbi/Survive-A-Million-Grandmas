--!nonstrict
-- Plays the server's visual-only WorldFx events (slippers, grenades, explosions, boss stomps).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local Effects = require(script.Parent.Parent.Effects)
local BossCutsceneController = require(script.Parent.BossCutsceneController)

local WorldFxController = {}

local HANDLERS = {
	Slipper = Effects.Slipper,
	Grenade = Effects.Grenade,
	Explosion = Effects.Explosion,
	StompWarning = Effects.StompWarning,
	Stomp = Effects.Stomp,
	BossIntro = function(enemyId: number, seconds: number)
		task.spawn(BossCutsceneController.Play, enemyId, seconds)
	end,
}

function WorldFxController.Init()
	Remotes.Get("WorldFx").OnClientEvent:Connect(function(kind: string, ...)
		local handler = HANDLERS[kind]
		if handler then
			handler(...)
		end
	end)
end

return WorldFxController
