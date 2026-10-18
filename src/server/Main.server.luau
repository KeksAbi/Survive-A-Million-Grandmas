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
local GrenadeService = require(Services.GrenadeService)
local ShopService = require(Services.ShopService)
local WaveService = require(Services.WaveService)
local AdminService = require(Services.AdminService)

Remotes.Init()
MapBuilder.Build()

EconomyService.Init()
EnemyService.Init()
CombatService.Init()
GrenadeService.Init()
ShopService.Init()
PlayerService.Init() -- after the services that listen to CharacterSpawned
WaveService.Start() -- the match loop
AdminService.Init()

print("[SurviveMillionGrandmas] server started")
