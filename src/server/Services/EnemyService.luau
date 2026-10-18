--!nonstrict
-- Owns every enemy. ONE Heartbeat loop moves all enemies at Config.Enemies.UpdateRate:
-- no Humanoids, no pathfinding, no per-enemy scripts. Enemies walk straight at the nearest living
-- player (the arena is open), keep apart from each other, slide around map obstacles, and attack.
-- Behaviors (EnemyDefinitions.Behavior): "Melee", "Ranged" (slipper throw), "Boss" (melee + stomp).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)
local EnemyDefinitions = require(Shared.EnemyDefinitions)

local EnemyFactory = require(script.Parent.Parent.World.EnemyFactory)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
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
	IsBoss: boolean,
	Position: Vector3, -- ground position (Y = 0)
	Facing: Vector3,
	AttackReadyAt: number?,
	NextStomp: number?,
	Stomping: boolean,
	Phase: number, -- random offset for the walking bob
	HealthFill: Frame?, -- boss overhead bar
}

local enemies: { [number]: Enemy } = {}
local activeCount = 0
local nextId = 1

local function worldFx(...)
	Remotes.Get("WorldFx"):FireAllClients(...)
end

local function publishCount()
	workspace:SetAttribute("EnemiesAlive", activeCount)
end

-- boss health replicates as workspace attributes (HUD bar) + an overhead bar on the model
local function publishBoss(enemy: Enemy?)
	if enemy then
		workspace:SetAttribute("BossName", enemy.Def.Name)
		workspace:SetAttribute("BossHealth", math.max(0, math.ceil(enemy.Health)))
		workspace:SetAttribute("BossMaxHealth", enemy.MaxHealth)
		if enemy.HealthFill then
			enemy.HealthFill.Size = UDim2.fromScale(math.clamp(enemy.Health / enemy.MaxHealth, 0, 1), 1)
		end
	else
		workspace:SetAttribute("BossName", nil)
		workspace:SetAttribute("BossHealth", nil)
		workspace:SetAttribute("BossMaxHealth", nil)
	end
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
		IsBoss = false,
		Position = ground,
		Facing = facing,
		AttackReadyAt = nil,
		NextStomp = nil,
		Stomping = false,
		Phase = math.random() * math.pi * 2,
		HealthFill = nil,
	}
	enemies[id] = enemy
	activeCount += 1
	publishCount()
	return enemy
end

-- Turns an enemy into the wave's boss: HUD boss bar + a health bar above its head.
function EnemyService.MarkBoss(enemy: Enemy)
	enemy.IsBoss = true
	enemy.Model:SetAttribute("Boss", true)

	local gui = Instance.new("BillboardGui")
	gui.Name = "BossBar"
	gui.Size = UDim2.fromOffset(220, 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, enemy.Def.RootHeight + 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(25, 20, 30)
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(235, 45, 45)
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner:Clone().Parent = fill
	gui.Parent = enemy.Root
	enemy.HealthFill = fill

	publishBoss(enemy)
end

local function kill(enemy: Enemy, killer: Player?)
	enemy.Alive = false
	enemies[enemy.Id] = nil
	activeCount -= 1
	publishCount()
	if enemy.IsBoss then
		publishBoss(nil)
	end
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
	if enemy.IsBoss then
		publishBoss(enemy)
	else
		enemy.Model:SetAttribute("HealthRatio", enemy.Health / enemy.MaxHealth) -- client health bar
	end
	return true, false
end

-- Damages every enemy whose body is within `radius` (flat distance) of `center`.
-- Returns one { Position, Damage, Killed } per enemy hit (for the attacker's hit feedback).
function EnemyService.DamageInRadius(center: Vector3, radius: number, amount: number, attacker: Player?): { any }
	local inside = {}
	for id, enemy in enemies do
		if enemy.Alive then
			local offset = enemy.Position - Vector3.new(center.X, 0, center.Z)
			if offset.Magnitude <= radius + enemy.Def.Radius then
				table.insert(inside, id)
			end
		end
	end
	local results = {}
	for _, id in inside do
		local enemy = enemies[id]
		if enemy then
			local position = enemy.Position + Vector3.new(0, enemy.Def.RootHeight, 0)
			local hit, killed = EnemyService.Damage(id, amount, attacker)
			if hit then
				table.insert(results, { Position = position, Damage = amount, Killed = killed })
			end
		end
	end
	return results
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
			local t = (center - origin):Dot(direction)
			if t > 0 and t <= maxDistance + enemy.Def.Radius and t < bestT then -- only enemies in front
				local point = origin + direction * t
				local offset = center - point
				local flat = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
				local halfHeight = enemy.Def.RootHeight + 0.4 * (enemy.Def.Scale or 1)
				if flat <= enemy.Def.Radius + 0.3 + tolerance and math.abs(offset.Y) <= halfHeight + tolerance then
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
	publishBoss(nil)
end

-- Keeps `position` out of every obstacle circle. When the target is behind an obstacle, adds a sideways
-- step so the enemy slides around it instead of pressing into its front.
local function avoidObstacles(enemy: Enemy, position: Vector3, toTarget: Vector3, stepDistance: number): Vector3
	local bodyRadius = enemy.Def.Radius + Config.Enemies.ObstacleMargin
	for _, obstacle in MapBuilder.GetObstacles() do
		local away = position - obstacle.Position
		local minDistance = obstacle.Radius + bodyRadius
		local distance = away.Magnitude
		if distance < minDistance then
			local normal = if distance > 0.001 then away / distance else Vector3.new(1, 0, 0)
			position = obstacle.Position + normal * minDistance
			if toTarget.Magnitude > 0.01 and normal:Dot(toTarget.Unit) < -0.2 then
				local tangent = Vector3.new(-normal.Z, 0, normal.X)
				local side = tangent:Dot(toTarget)
				if math.abs(side) < 0.01 then
					side = if enemy.Id % 2 == 0 then 1 else -1 -- dead ahead: split left/right
				end
				position += tangent * (if side > 0 then 1 else -1) * stepDistance
			end
		end
	end
	return position
end

-- Ranged attack: a slipper flies to where the target stands now; it hits if they are still there on landing.
local function throwSlipper(enemy: Enemy, target)
	local def = enemy.Def
	local from = enemy.Position + Vector3.new(0, def.RootHeight + 1, 0)
	local landing = target.Root.Position
	local flightTime = math.max(0.25, (landing - from).Magnitude / def.ProjectileSpeed)
	worldFx("Slipper", from, landing, flightTime)
	task.delay(flightTime, function()
		for _, entry in PlayerService.GetLivingPlayers() do
			local offset = entry.Root.Position - landing
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= def.ProjectileHitRadius and math.abs(offset.Y) < 6 then
				entry.Humanoid:TakeDamage(def.Damage)
				break -- one slipper, one victim
			end
		end
	end)
end

-- Boss stomp: red warning circle for StompWindup seconds, then damage to every player inside.
local function stomp(enemy: Enemy)
	local def = enemy.Def
	enemy.Stomping = true
	local center = enemy.Position
	worldFx("StompWarning", center, def.StompRadius, def.StompWindup)
	task.delay(def.StompWindup, function()
		enemy.Stomping = false
		enemy.NextStomp = os.clock() + def.StompCooldown
		if not enemy.Alive then
			return
		end
		worldFx("Stomp", center, def.StompRadius)
		for _, entry in PlayerService.GetLivingPlayers() do
			local offset = entry.Root.Position - center
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= def.StompRadius then
				entry.Humanoid:TakeDamage(def.StompDamage)
			end
		end
	end)
end

-- Cutscenes: while frozen, no enemy moves or attacks (and nothing writes their CFrames).
local frozenUntil = 0
function EnemyService.Freeze(seconds: number)
	frozenUntil = math.max(frozenUntil, os.clock() + seconds)
end

local accumulator = 0

local function step(dt: number)
	accumulator += dt
	if accumulator < 1 / Config.Enemies.UpdateRate then
		return
	end
	local stepDt = math.min(accumulator, 0.25)
	accumulator = 0

	if activeCount == 0 or os.clock() < frozenUntil then
		return
	end
	local living = PlayerService.GetLivingPlayers()
	if #living == 0 then
		return
	end

	local now = os.clock()
	local wall = Config.Map.WallDistance - 2

	-- snapshot for spacing
	local list = {}
	for _, enemy in enemies do
		table.insert(list, enemy)
	end

	for i, enemy in list do
		if not enemy.Alive then
			continue
		end
		local def = enemy.Def
		local behavior = def.Behavior
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
		local towards = if distance > 0.01 then toTarget / distance else Vector3.zero

		-- movement
		local move = Vector3.zero
		local stepLength = def.Speed * stepDt
		if behavior == "Ranged" then
			if distance > def.PreferredRange then
				move = towards * math.min(stepLength, distance - def.PreferredRange)
			elseif distance < def.MinRange then
				move = -towards * stepLength * 0.6 -- back off
			end
		elseif not enemy.Stomping then
			local stopDistance = def.AttackRange * 0.75
			if distance > stopDistance then
				move = towards * math.min(stepLength, distance - stopDistance)
			end
		end

		-- keep apart from nearby enemies so they don't stack into one blob
		local push = Vector3.zero
		for j, other in list do
			if j ~= i and other.Alive then
				local away = pos - other.Position
				local d = away.Magnitude
				local minGap = def.Radius + other.Def.Radius
				if d < minGap and d > 0.001 then
					push += away / d * (minGap - d) * (other.Def.Radius / def.Radius) -- small ones yield to big ones
				end
			end
		end
		if push.Magnitude > 0 then
			move += push * math.min(1, 6 * stepDt)
		end

		local newPos = avoidObstacles(enemy, pos + move, toTarget, stepLength)
		newPos = Vector3.new(math.clamp(newPos.X, -wall, wall), 0, math.clamp(newPos.Z, -wall, wall))
		local moved = (newPos - pos).Magnitude > 0.001
		enemy.Position = newPos
		if distance > 0.01 then
			enemy.Facing = towards
		end

		-- attacks (a short wind-up when first in range, then the cooldown)
		if distance <= def.AttackRange then
			if enemy.AttackReadyAt == nil then
				enemy.AttackReadyAt = now + (if behavior == "Ranged" then 0.5 + math.random() else 0.35)
			elseif now >= enemy.AttackReadyAt and not enemy.Stomping then
				if behavior == "Ranged" then
					throwSlipper(enemy, target)
				else
					target.Humanoid:TakeDamage(def.Damage)
				end
				enemy.AttackReadyAt = now + def.AttackCooldown
			end
		else
			enemy.AttackReadyAt = nil
		end
		if behavior == "Boss" and not enemy.Stomping then
			enemy.NextStomp = enemy.NextStomp or (now + def.StompCooldown * 0.5)
			if now >= enemy.NextStomp and distance <= def.StompRadius then
				stomp(enemy)
			end
		end

		-- write the root (welds move the rest); cosmetic waddle while walking, shiver while stomping
		local bob, sway = 0, 0
		local t = now * 9 + enemy.Phase
		if enemy.Stomping then
			bob = math.abs(math.sin(now * 30)) * 0.6
		elseif moved then
			bob = math.abs(math.sin(t)) * Config.Enemies.BobHeight * (def.Scale or 1)
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
