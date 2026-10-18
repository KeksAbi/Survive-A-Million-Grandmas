--!nonstrict
-- Runs the match: Waiting -> (Intermission -> Wave) x10 -> Victory | Defeat -> results -> new match.
-- Only one match loop exists (started once in Start), so waves can never start twice.
-- Replicates state as workspace attributes: MatchState, Wave, WaveKills, WaveTotal, Countdown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)
local EnemyDefinitions = require(Shared.EnemyDefinitions)
local WaveDefinitions = require(Shared.WaveDefinitions)

local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local CombatService = require(script.Parent.CombatService)
local EconomyService = require(script.Parent.EconomyService)
local EnemyService = require(script.Parent.EnemyService)
local GrenadeService = require(script.Parent.GrenadeService)
local PlayerService = require(script.Parent.PlayerService)

local WaveService = {}

-- (victory: boolean, wavesSurvived: number, killsByPlayer: { [Player]: number })
WaveService.MatchEnded = Signal.new()

local WaveConfig = Config.Waves

local state = "Waiting"
local waveKills = 0
local teamKills = 0
local wavesSurvived = 0
local matchKills: { [Player]: number } = {}

local function setState(newState: string)
	state = newState
	workspace:SetAttribute("MatchState", newState)
end

local function notifyAll(text: string, kind: string)
	Remotes.Get("Notify"):FireAllClients(text, kind)
end

local function notify(player: Player, text: string, kind: string)
	Remotes.Get("Notify"):FireClient(player, text, kind)
end

local warnedTypes = {}
local function resolveType(typeName: string): string
	if EnemyDefinitions[typeName] then
		return typeName
	end
	if not warnedTypes[typeName] then
		warnedTypes[typeName] = true
		warn("[WaveService] enemy type " .. typeName .. " not implemented yet, using NormalGrandma")
	end
	return "NormalGrandma"
end

type QueueEntry = { Type: string, Boss: boolean }

local function buildQueue(waveIndex: number, playerCount: number): { QueueEntry }
	local def = WaveDefinitions[waveIndex]
	local countScale = 1 + WaveConfig.ExtraPlayerCountScale * math.max(0, playerCount - 1)
	local queue = {}
	for typeName, count in def.Enemies do
		local resolved = resolveType(typeName)
		for _ = 1, math.max(1, math.floor(count * countScale + 0.5)) do
			table.insert(queue, { Type = resolved, Boss = false })
		end
	end
	for i = #queue, 2, -1 do -- shuffle so types arrive mixed
		local j = math.random(1, i)
		queue[i], queue[j] = queue[j], queue[i]
	end
	if def.Boss and EnemyDefinitions[def.Boss] then
		table.insert(queue, math.max(1, math.floor(#queue / 3)), { Type = def.Boss, Boss = true })
	end
	return queue
end

local function setWaveAttributes(wave: number, kills: number, total: number)
	workspace:SetAttribute("Wave", wave)
	workspace:SetAttribute("WaveKills", kills)
	workspace:SetAttribute("WaveTotal", total)
end

-- Countdown before a wave. Returns false if everyone left.
local function intermission(waveIndex: number): boolean
	setState("Intermission")
	setWaveAttributes(waveIndex, 0, 0)
	notifyAll("WAVE " .. waveIndex .. " INCOMING!", "info")
	local seconds = if waveIndex == 1 then WaveConfig.FirstIntermissionSeconds else WaveConfig.IntermissionSeconds
	for t = seconds, 1, -1 do
		workspace:SetAttribute("Countdown", t)
		task.wait(1)
		if #Players:GetPlayers() == 0 then
			return false
		end
	end
	workspace:SetAttribute("Countdown", 0)
	return true
end

-- Spawns the wave gradually and waits for it to end. Returns "Cleared", "Defeat" or "Abandoned".
local function runWave(waveIndex: number): string
	local def = WaveDefinitions[waveIndex]
	local playerCount = #Players:GetPlayers()
	local queue = buildQueue(waveIndex, playerCount)

	local healthScale = 1 + WaveConfig.HealthGrowthPerWave * (waveIndex - 1)
	local bossScale = (1 + WaveConfig.ExtraPlayerBossHealthScale * math.max(0, playerCount - 1))
		* (if waveIndex == #WaveDefinitions then WaveConfig.FinalBossHealthScale else 1)
	local interval = math.max(WaveConfig.MinSpawnInterval, def.SpawnInterval / (1 + 0.25 * math.max(0, playerCount - 1)))

	waveKills = 0
	setWaveAttributes(waveIndex, 0, #queue)
	setState("Wave")

	local nextIndex, nextSpawnAt = 1, 0
	while true do
		if #Players:GetPlayers() == 0 then
			return "Abandoned"
		end
		if #PlayerService.GetLivingPlayers() == 0 then
			return "Defeat"
		end

		local now = os.clock()
		if nextIndex <= #queue and now >= nextSpawnAt then
			local entry = queue[nextIndex]
			local spawnAt = if entry.Boss then Config.Boss.SpawnPosition else MapBuilder.GetRandomSpawnPosition()
			local enemy = EnemyService.Spawn(entry.Type, spawnAt, if entry.Boss then bossScale else healthScale)
			if enemy then
				nextIndex += 1
				nextSpawnAt = now + interval
				if entry.Boss then
					-- intro cutscene on every screen: the world freezes and players are shielded meanwhile
					local seconds = Config.Boss.CutsceneSeconds
					EnemyService.MarkBoss(enemy)
					EnemyService.Freeze(seconds)
					PlayerService.ShieldAll(seconds + 1)
					Remotes.Get("WorldFx"):FireAllClients("BossIntro", enemy.Id, seconds, enemy.Position, enemy.Facing)
					nextSpawnAt = now + seconds
					task.delay(seconds, notifyAll, "DEFEAT THE MEGA GRANDMA!", "boss")
				end
			else
				nextSpawnAt = now + 0.5 -- MaxActive reached: try again shortly
			end
		end

		if nextIndex > #queue and EnemyService.GetActiveCount() == 0 then
			return "Cleared"
		end
		task.wait(0.1)
	end
end

local function waveCleared(waveIndex: number)
	wavesSurvived = waveIndex
	local bonus = WaveConfig.CompletionBonus + WaveConfig.CompletionBonusPerWave * waveIndex
	for _, player in Players:GetPlayers() do
		EconomyService.AddCash(player, bonus)
	end
	if waveIndex < #WaveDefinitions then
		notifyAll("WAVE COMPLETED! +$" .. bonus, "good")
	end
	PlayerService.RespawnAndHealAll()
end

local function resetMatch()
	EnemyService.ClearAll()
	teamKills = 0
	wavesSurvived = 0
	table.clear(matchKills)
	for _, player in Players:GetPlayers() do
		EconomyService.Reset(player)
		CombatService.ResetLoadout(player)
		GrenadeService.Reset(player)
	end
	PlayerService.RespawnAndHealAll()
end

-- Returns "Victory", "Defeat" or "Abandoned".
local function runMatch(): string
	local firstWave = math.clamp(Config.Debug.StartWave or 1, 1, #WaveDefinitions)
	for waveIndex = firstWave, #WaveDefinitions do
		if not intermission(waveIndex) then
			return "Abandoned"
		end
		local outcome = runWave(waveIndex)
		if outcome ~= "Cleared" then
			return outcome
		end
		waveCleared(waveIndex)
	end
	return "Victory"
end

local function endMatch(victory: boolean)
	setState(if victory then "Victory" else "Defeat")
	EnemyService.ClearAll()
	notifyAll(if victory then "VICTORY!" else "GAME OVER", if victory then "gold" else "bad")

	local resultRemote = Remotes.Get("MatchResult")
	for _, player in Players:GetPlayers() do
		local best = math.max(player:GetAttribute("BestWave") or 0, wavesSurvived)
		player:SetAttribute("BestWave", best)
		resultRemote:FireClient(player, {
			Victory = victory,
			WavesSurvived = wavesSurvived,
			Kills = matchKills[player] or 0,
			CashEarned = EconomyService.GetEarned(player),
			TeamKills = teamKills,
			BestWave = best,
			NextMatchIn = WaveConfig.ResultsSeconds,
		})
	end
	WaveService.MatchEnded:Fire(victory, wavesSurvived, table.clone(matchKills))

	for t = WaveConfig.ResultsSeconds, 1, -1 do
		workspace:SetAttribute("Countdown", t)
		task.wait(1)
	end
end

function WaveService.Start()
	PlayerService.CanSpawnOnJoin = function()
		return state ~= "Wave"
	end

	PlayerService.PlayerJoined:Connect(function(player: Player, spawned: boolean)
		if not spawned then
			notify(player, "WAVE IN PROGRESS! YOU JOIN NEXT WAVE", "info")
		end
	end)
	PlayerService.PlayerDied:Connect(function(player: Player)
		if state == "Wave" then
			notify(player, "ELIMINATED! BACK NEXT WAVE", "bad")
		end
	end)
	EnemyService.EnemyKilled:Connect(function(enemy, killer: Player?)
		if state ~= "Wave" then
			return
		end
		if enemy.IsBoss then
			notifyAll("MEGA GRANDMA DEFEATED!", "gold")
		end
		waveKills += 1
		teamKills += 1
		workspace:SetAttribute("WaveKills", waveKills)
		if killer then
			matchKills[killer] = (matchKills[killer] or 0) + 1
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		matchKills[player] = nil
	end)

	task.spawn(function()
		while true do
			setState("Waiting")
			workspace:SetAttribute("Wave", nil)
			while #Players:GetPlayers() == 0 do
				task.wait(1)
			end
			resetMatch()
			local outcome = runMatch()
			if outcome == "Abandoned" then
				EnemyService.ClearAll()
			else
				endMatch(outcome == "Victory")
			end
		end
	end)
end

return WaveService
