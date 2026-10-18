--!strict
-- The 10 waves. Counts are for ONE player; WaveService adds Config.Waves.ExtraPlayerCountScale per extra player.
-- Enemies: type -> count (spawned gradually in random order). Boss: spawned once, about a third into the wave.
-- SpawnInterval: seconds between two spawns (shrinks a bit with more players).
-- Types that don't exist yet in EnemyDefinitions are replaced by NormalGrandma (bosses are skipped).

export type WaveDefinition = {
	Enemies: { [string]: number },
	Boss: string?,
	SpawnInterval: number,
}

local Waves: { WaveDefinition } = {
	{ Enemies = { NormalGrandma = 10 }, SpawnInterval = 0.9 },
	{ Enemies = { NormalGrandma = 16 }, SpawnInterval = 0.8 },
	{ Enemies = { NormalGrandma = 16, SlipperGrandma = 6 }, SpawnInterval = 0.75 },
	{ Enemies = { NormalGrandma = 18, ScooterGrandma = 8 }, SpawnInterval = 0.7 },
	{ Enemies = { NormalGrandma = 16, SlipperGrandma = 6, ScooterGrandma = 6 }, Boss = "MegaGrandma", SpawnInterval = 0.7 },
	{ Enemies = { NormalGrandma = 26, SlipperGrandma = 8, ScooterGrandma = 8 }, SpawnInterval = 0.6 },
	{ Enemies = { NormalGrandma = 20, SlipperGrandma = 6, ScooterGrandma = 16 }, SpawnInterval = 0.55 },
	{ Enemies = { NormalGrandma = 22, SlipperGrandma = 16, ScooterGrandma = 8 }, SpawnInterval = 0.5 },
	{ Enemies = { NormalGrandma = 34, SlipperGrandma = 12, ScooterGrandma = 12 }, SpawnInterval = 0.45 },
	{ Enemies = { NormalGrandma = 40, SlipperGrandma = 16, ScooterGrandma = 16 }, Boss = "MegaGrandma", SpawnInterval = 0.4 },
}

return Waves
