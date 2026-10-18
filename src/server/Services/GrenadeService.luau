--!nonstrict
-- Grenades: bought in the shop ($60, carry up to Config.Grenade.MaxCarried), thrown with G.
-- The client only sends where it aims; the server clamps the distance, lands the grenade on the ground,
-- and after the fuse damages every enemy in the radius. Count replicates as player attribute "Grenades".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local EconomyService = require(script.Parent.EconomyService)
local EnemyService = require(script.Parent.EnemyService)

local GrenadeService = {}

local GrenadeConfig = Config.Grenade

local counts: { [Player]: number } = {}
local lastThrow: { [Player]: number } = {}

local function publish(player: Player)
	player:SetAttribute("Grenades", counts[player] or 0)
end

function GrenadeService.GetCount(player: Player): number
	return counts[player] or 0
end

-- Adds one grenade. Returns false if the bag is full.
function GrenadeService.Add(player: Player): boolean
	local count = counts[player] or 0
	if count >= GrenadeConfig.MaxCarried then
		return false
	end
	counts[player] = count + 1
	publish(player)
	return true
end

function GrenadeService.Reset(player: Player)
	counts[player] = 0
	publish(player)
end

local function explode(position: Vector3, thrower: Player)
	Remotes.Get("WorldFx"):FireAllClients("Explosion", position, GrenadeConfig.Radius)
	local hits = EnemyService.DamageInRadius(position, GrenadeConfig.Radius, GrenadeConfig.Damage, thrower)
	if thrower.Parent == Players then
		local feedback = Remotes.Get("HitFeedback")
		for _, hit in hits do
			feedback:FireClient(thrower, hit.Position, hit.Damage, hit.Killed)
		end
	end
end

local function onThrow(player: Player, target: any)
	if typeof(target) ~= "Vector3" or target.Magnitude ~= target.Magnitude or target.Magnitude > 1e5 then
		return
	end
	local now = os.clock()
	if now - (lastThrow[player] or 0) < GrenadeConfig.Cooldown then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if not humanoid or humanoid.Health <= 0 or not head then
		return
	end

	-- no grenade in the bag: buy one on the spot (G with an empty bag = buy + throw)
	if (counts[player] or 0) <= 0 then
		if not EconomyService.TrySpend(player, GrenadeConfig.Cost) then
			lastThrow[player] = now -- the cooldown also limits "not enough cash" replies
			Remotes.Get("Notify"):FireClient(player, "NOT ENOUGH CASH! GRENADE COSTS $" .. GrenadeConfig.Cost, "bad")
			return
		end
		counts[player] = 1
	end
	counts[player] -= 1
	lastThrow[player] = now
	publish(player)

	local origin = head.Position + Vector3.new(0, 1, 0)
	local flat = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
	if flat.Magnitude > GrenadeConfig.MaxThrowDistance then
		flat = flat.Unit * GrenadeConfig.MaxThrowDistance
	elseif flat.Magnitude < 3 then
		flat = Vector3.new(head.CFrame.LookVector.X, 0, head.CFrame.LookVector.Z).Unit * 3
	end
	local landing = Vector3.new(origin.X + flat.X, 0.6, origin.Z + flat.Z) -- the arena floor is flat at Y = 0
	local wall = Config.Map.WallDistance - 1
	landing = Vector3.new(math.clamp(landing.X, -wall, wall), landing.Y, math.clamp(landing.Z, -wall, wall))

	Remotes.Get("WorldFx"):FireAllClients("Grenade", origin, landing, GrenadeConfig.FlightTime, GrenadeConfig.Fuse)
	task.delay(GrenadeConfig.Fuse, explode, landing, player)
end

function GrenadeService.Init()
	Remotes.Get("ThrowGrenade").OnServerEvent:Connect(onThrow)
	Players.PlayerAdded:Connect(GrenadeService.Reset)
	Players.PlayerRemoving:Connect(function(player)
		counts[player] = nil
		lastThrow[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		GrenadeService.Reset(player)
	end
end

return GrenadeService
