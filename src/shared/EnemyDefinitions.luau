--!strict
-- Enemy data. Add an entry here and (if it has a new look) a builder in server/World/EnemyFactory.luau.
-- Behavior: "Melee" = chase and hit in range. (Ranged / Boss behaviors are added in later phases.)

export type EnemyDefinition = {
	Name: string,
	Behavior: string,
	Health: number,
	Speed: number, -- studs per second
	Damage: number,
	AttackCooldown: number,
	AttackRange: number, -- studs, root-to-root distance at which the attack lands
	CashReward: number,
	RootHeight: number, -- height of the root part center above the ground
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
	},
}

return Definitions
