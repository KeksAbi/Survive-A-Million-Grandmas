--!strict
-- Enemy data. Add an entry here and a builder in server/World/EnemyFactory.luau.
-- Behaviors (EnemyService):
--   "Melee"  chase the nearest player and hit in range (also contact damage for fast types).
--   "Ranged" keep between MinRange and PreferredRange, throw a projectile every AttackCooldown.
--   "Boss"   melee + a telegraphed stomp (red warning circle, then area damage).

export type EnemyDefinition = {
	Name: string,
	Behavior: string,
	Health: number,
	Speed: number, -- studs per second
	Damage: number,
	AttackCooldown: number,
	AttackRange: number, -- studs, root-to-root distance at which the attack lands / is thrown
	CashReward: number,
	RootHeight: number, -- height of the root part center above the ground
	Radius: number, -- body radius: spacing between enemies, obstacle avoidance, hit tolerance
	Scale: number?, -- model size multiplier (default 1)
	HitboxSize: Vector3?, -- default 3.6 x 7.2 x 3.8 (covers arms and bun), multiplied by Scale
	HitboxOffset: Vector3?, -- hitbox center relative to the root, default (0, 0.5, -0.5) (arms reach forward)
	-- Ranged
	PreferredRange: number?,
	MinRange: number?,
	ProjectileSpeed: number?,
	ProjectileHitRadius: number?,
	-- Boss
	StompDamage: number?,
	StompRadius: number?,
	StompCooldown: number?,
	StompWindup: number?,
}

local Definitions: { [string]: EnemyDefinition } = {
	NormalGrandma = {
		Name = "Normal Grandma",
		Behavior = "Melee",
		Health = 60,
		Speed = 8,
		Damage = 10,
		AttackCooldown = 1.2,
		AttackRange = 3.6,
		CashReward = 12,
		RootHeight = 3,
		Radius = 1.1,
	},
	SlipperGrandma = {
		Name = "Slipper Grandma",
		Behavior = "Ranged",
		Health = 55,
		Speed = 7,
		Damage = 8,
		AttackCooldown = 2,
		AttackRange = 34,
		CashReward = 18,
		RootHeight = 3,
		Radius = 1.1,
		PreferredRange = 24,
		MinRange = 14,
		ProjectileSpeed = 45,
		ProjectileHitRadius = 3.5,
	},
	ScooterGrandma = {
		Name = "Scooter Grandma",
		Behavior = "Melee",
		Health = 45,
		Speed = 14,
		Damage = 12, -- contact damage
		AttackCooldown = 1,
		AttackRange = 4.2,
		CashReward = 20,
		RootHeight = 3,
		Radius = 1.6,
		HitboxSize = Vector3.new(3.4, 7.2, 6.4), -- scooter + basket in front
		HitboxOffset = Vector3.new(0, 0.5, -0.8),
	},
	MegaGrandma = {
		Name = "MEGA GRANDMA",
		Behavior = "Boss",
		Health = 700,
		Speed = 6,
		Damage = 25,
		AttackCooldown = 1.6,
		AttackRange = 9,
		CashReward = 200,
		RootHeight = 12,
		Radius = 4.4,
		Scale = 4,
		StompDamage = 35,
		StompRadius = 16,
		StompCooldown = 6,
		StompWindup = 0.9,
	},
}

return Definitions
