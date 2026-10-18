--!strict
-- All RemoteEvents live in ReplicatedStorage.Remotes. The server creates them (Init), both sides fetch them (Get).
--
-- Client -> Server (never trusted, always validated):
--   Fire(origin: Vector3, direction: Vector3, aimedEnemyId: number?)   shoot; the id = enemy under the
--       crosshair on the client (only a hint: the server re-checks direction, range and line of sight)
--   Reload()                                    start a reload
--   Equip(weaponId: string)                     switch weapon
--   Purchase(itemId: string)                    buy a weapon id or "Grenade"
--   ThrowGrenade(target: Vector3)               throw toward a ground point (server clamps the distance)
-- Server -> Client:
--   HitFeedback(position: Vector3, damage: number, killed: boolean)   to the shooter only
--   ShotFx(shooterUserId: number, weaponId: string, origin: Vector3, endPosition: Vector3)   to the other players
--   WorldFx(kind: string, ...)                  visual-only events for everyone:
--       "Slipper" (from, to, flightTime) | "Grenade" (from, landing, flightTime, fuse)
--       "Explosion" (position, radius) | "StompWarning" (position, radius, seconds) | "Stomp" (position, radius)
--       "BossIntro" (enemyId, seconds)  boss cutscene
--   Notify(text: string, kind: string)          banner message ("info", "good", "bad", "boss", "gold")
--   MatchResult(result: { Victory: boolean, WavesSurvived: number, Kills: number, CashEarned: number,
--               TeamKills: number, BestWave: number, NextMatchIn: number })   results screen

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "Fire", "Reload", "Equip", "Purchase", "ThrowGrenade", "HitFeedback", "ShotFx", "WorldFx", "Notify", "MatchResult" }

local Remotes = {}

function Remotes.Init()
	assert(RunService:IsServer(), "Remotes.Init is server only")
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

function Remotes.Get(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
