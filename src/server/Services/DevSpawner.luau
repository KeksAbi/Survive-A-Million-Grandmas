--!nonstrict
-- TEMPORARY (Phase 2): keeps a trickle of grandmas coming so combat can be tested before WaveService exists.
-- Disabled by Config.Debug.DevSpawner = false, and paused while workspace attribute "WavesActive" is true.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local EnemyService = require(script.Parent.EnemyService)
local PlayerService = require(script.Parent.PlayerService)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

local DevSpawner = {}

local DEV_CAP = 15

function DevSpawner.Start()
	if not Config.Debug.DevSpawner then
		return
	end
	task.spawn(function()
		while true do
			task.wait(Config.Debug.DevSpawnInterval)
			if workspace:GetAttribute("WavesActive") then
				continue
			end
			if #PlayerService.GetLivingPlayers() == 0 or EnemyService.GetActiveCount() >= DEV_CAP then
				continue
			end
			EnemyService.Spawn("NormalGrandma", MapBuilder.GetRandomSpawnPosition())
		end
	end)
end

return DevSpawner
