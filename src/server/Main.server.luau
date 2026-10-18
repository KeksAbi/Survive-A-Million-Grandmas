--!nonstrict
-- Server bootstrap. Order matters: remotes and the world first, then services that use them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local Services = script.Parent.Services
local World = script.Parent.World

local MapBuilder = require(World.MapBuilder)
local EconomyService = require(Services.EconomyService)
local PlayerService = require(Services.PlayerService)
local EnemyService = require(Services.EnemyService)
local CombatService = require(Services.CombatService)
local DevSpawner = require(Services.DevSpawner)

Remotes.Init()
MapBuilder.Build()

EconomyService.Init()
EnemyService.Init()
CombatService.Init()
PlayerService.Init() -- last: fires CharacterSpawned, which the services above listen to

DevSpawner.Start()

print("[SurviveMillionGrandmas] server started")
