--!nonstrict
-- Owns every enemy. ONE Heartbeat loop moves all enemies at Config.Enemies.UpdateRate:
-- no Humanoids, no pathfinding, no per-enemy scripts. Enemies walk straight at the nearest living
-- player (the arena is open), push apart from each other, and hit when in range.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)
local EnemyDefinitions = require(Shared.EnemyDefinitions)

local EnemyFactory = require(script.Parent.Parent.World.EnemyFactory)
local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)

local EnemyService = {}

EnemyService.EnemyKilled = Signal.new() -- (enemy, killer: Player?)
EnemyService.Folder = nil :: Folder?

type Enemy = {
	Id: number,
	TypeName: string,
	Def: any,
	Model: Model,
	Root: BasePart,
	Health: number,
	MaxHealth: number,
	Alive: boolean,
	Position: Vector3, -- ground position (Y = 0)
	Facing: Vector3,
	AttackReadyAt: number?,
	Phase: number, -- random offset for the walking bob
}

local enemies: { [number]: Enemy } = {}
local activeCount = 0
local nextId = 1

local function publishCount()
	workspace:SetAttribute("EnemiesAlive", activeCount)
end

-- Spawns one enemy at a ground position. Returns nil when the MaxActive cap is reached.
function EnemyService.Spawn(typeName: string, position: Vector3, healthScale: number?): Enemy?
	if activeCount >= Config.Enemies.MaxActive then
		return nil
	end
	local def = EnemyDefinitions[typeName]
	assert(def, "Unknown enemy type " .. tostring(typeName))

	local model, root = EnemyFactory.Build(typeName, def)
	local id = nextId
	nextId += 1

	local ground = Vector3.new(position.X, 0, position.Z)
	local facing = Vector3.new(-ground.X, 0, -ground.Z)
	facing = if facing.Magnitude > 0.01 then facing.Unit else Vector3.new(0, 0, -1)
	model:PivotTo(CFrame.lookAt(ground + Vector3.new(0, def.RootHeight, 0), ground + Vector3.new(0, def.RootHeight, 0) + facing))
	model:SetAttribute("EnemyId", id)
	model:SetAttribute("EnemyType", typeName)
	model.Parent = EnemyService.Folder

	local health = math.floor(def.Health * (healthScale or 1) + 0.5)
	local enemy: Enemy = {
		Id = id,
		TypeName = typeName,
		Def = def,
		Model = model,
		Root = root,
		Health = health,
		MaxHealth = health,
		Alive = true,
		Position = ground,
		Facing = facing,
		AttackReadyAt = nil,
		Phase = math.random() * math.pi * 2,
	}
	enemies[id] = enemy
	activeCount += 1
	publishCount()
	return enemy
end

local function kill(enemy: Enemy, killer: Player?)
	enemy.Alive = false
	enemies[enemy.Id] = nil
	activeCount -= 1
	publishCount()
	enemy.Model:Destroy()

	if killer and killer.Parent == Players then
		EconomyService.AddCash(killer, enemy.Def.CashReward)
	end
	EnemyService.EnemyKilled:Fire(enemy, killer)
end

-- Applies server-validated damage. Returns (hit, killed).
function EnemyService.Damage(enemyId: number, amount: number, attacker: Player?): (boolean, boolean)
	local enemy = enemies[enemyId]
	if not enemy or not enemy.Alive or amount <= 0 then
		return false, false
	end
	enemy.Health -= amount
	if enemy.Health <= 0 then
		kill(enemy, attacker)
		return true, true
	end
	return true, false
end

function EnemyService.Get(enemyId: number): Enemy?
	return enemies[enemyId]
end

-- Maps a raycast hit back to an enemy id (only enemy Hitbox parts are queryable).
function EnemyService.GetEnemyIdFromInstance(instance: Instance): number?
	local model = instance:FindFirstAncestorOfClass("Model")
	if model and model.Parent == EnemyService.Folder then
		return model:GetAttribute("EnemyId")
	end
	return nil
end

-- Closest enemy whose body (an upright box around the root) passes within `tolerance` studs of the ray.
-- Returns (enemyId, point on the ray) or nil. Linear over alive enemies (max 60).
function EnemyService.FindEnemyNearRay(origin: Vector3, direction: Vector3, maxDistance: number, tolerance: number): (number?, Vector3?)
	local bestId, bestT, bestPoint = nil, math.huge, nil
	for id, enemy in enemies do
		if enemy.Alive then
			local center = enemy.Position + Vector3.new(0, enemy.Def.RootHeight, 0)
			local t = math.clamp((center - origin):Dot(direction), 0, maxDistance)
			if t < bestT then
				local point = origin + direction * t
				local offset = center - point
				local flat = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
				local halfHeight = enemy.Def.RootHeight + 0.4
				if flat <= 1.4 + tolerance and math.abs(offset.Y) <= halfHeight + tolerance then
					bestId, bestT, bestPoint = id, t, point
				end
			end
		end
	end
	return bestId, bestPoint
end

function EnemyService.GetActiveCount(): number
	return activeCount
end

-- Removes every enemy without rewards (match reset).
function EnemyService.ClearAll()
	for _, enemy in enemies do
		enemy.Alive = false
		enemy.Model:Destroy()
	end
	table.clear(enemies)
	activeCount = 0
	publishCount()
end

local accumulator = 0

local function step(dt: number)
	accumulator += dt
	if accumulator < 1 / Config.Enemies.UpdateRate then
		return
	end
	local stepDt = math.min(accumulator, 0.25)
	accumulator = 0

	if activeCount == 0 then
		return
	end
	local living = PlayerService.GetLivingPlayers()
	if #living == 0 then
		return
	end

	local now = os.clock()
	local wall = Config.Map.WallDistance - 2
	local separation = Config.Enemies.SeparationRadius

	-- snapshot for separation
	local list = {}
	for _, enemy in enemies do
		table.insert(list, enemy)
	end

	for i, enemy in list do
		if not enemy.Alive then
			continue
		end
		local def = enemy.Def
		local pos = enemy.Position

		-- nearest living player (flat distance)
		local target, bestSq = nil, math.huge
		for _, entry in living do
			local offset = entry.Root.Position - pos
			local sq = offset.X * offset.X + offset.Z * offset.Z
			if sq < bestSq then
				target, bestSq = entry, sq
			end
		end
		local toTarget = target.Root.Position - pos
		toTarget = Vector3.new(toTarget.X, 0, toTarget.Z)
		local distance = math.sqrt(bestSq)

		-- chase
		local move = Vector3.zero
		local stopDistance = def.AttackRange * 0.75
		if distance > stopDistance and distance > 0.01 then
			move = toTarget.Unit * math.min(def.Speed * stepDt, distance - stopDistance)
		end

		-- push apart from nearby enemies so they don't stack into one blob
		local push = Vector3.zero
		for j, other in list do
			if j ~= i and other.Alive then
				local away = pos - other.Position
				local d = away.Magnitude
				if d < separation and d > 0.001 then
					push += away / d * (separation - d)
				end
			end
		end
		if push.Magnitude > 0 then
			move += push * math.min(1, 6 * stepDt)
		end

		local newPos = pos + move
		newPos = Vector3.new(math.clamp(newPos.X, -wall, wall), 0, math.clamp(newPos.Z, -wall, wall))
		local moved = (newPos - pos).Magnitude > 0.001
		enemy.Position = newPos
		if distance > 0.01 then
			enemy.Facing = toTarget.Unit
		end

		-- attack (short wind-up when first reaching the player, then the cooldown)
		if distance <= def.AttackRange then
			if enemy.AttackReadyAt == nil then
				enemy.AttackReadyAt = now + 0.35
			elseif now >= enemy.AttackReadyAt then
				target.Humanoid:TakeDamage(def.Damage)
				enemy.AttackReadyAt = now + def.AttackCooldown
			end
		else
			enemy.AttackReadyAt = nil
		end

		-- write the root (welds move the rest); cosmetic waddle while walking
		local bob, sway = 0, 0
		if moved then
			local t = now * 9 + enemy.Phase
			bob = math.abs(math.sin(t)) * Config.Enemies.BobHeight
			sway = math.sin(t) * 0.08
		end
		local rootPos = newPos + Vector3.new(0, def.RootHeight + bob, 0)
		enemy.Root.CFrame = CFrame.lookAt(rootPos, rootPos + enemy.Facing) * CFrame.Angles(0, 0, sway)
	end
end

function EnemyService.Init()
	local folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace
	EnemyService.Folder = folder
	publishCount()
	RunService.Heartbeat:Connect(step)
end

return EnemyService
