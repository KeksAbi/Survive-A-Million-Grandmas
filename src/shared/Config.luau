--!strict
-- Global tuning values. Everything gameplay-related that is not a weapon, enemy or wave lives here.

return {
	Debug = {
		-- Spawns grandmas continuously so the combat prototype is playable before WaveService exists.
		-- WaveService turns this off by setting workspace attribute "WavesActive" = true.
		DevSpawner = true,
		DevSpawnInterval = 1.5,
	},

	Player = {
		MaxHealth = 100,
		StartingCash = 40,
		WalkSpeed = 16,
		SpawnInvulnerability = 2, -- seconds of ForceField after spawning
		StartingWeapon = "Pistol",
	},

	Enemies = {
		MaxActive = 60, -- hard cap of simultaneously alive enemies
		UpdateRate = 20, -- movement/AI ticks per second (one loop for ALL enemies)
		SeparationRadius = 2.2, -- enemies closer than this push each other apart
		BobHeight = 0.25, -- cosmetic walking bob
	},

	Combat = {
		MaxShotOriginDistance = 14, -- shot origin must be this close to the shooter's head
		MaxRange = 300,
		FireToleranceSeconds = 0.06, -- allowed early fire (network jitter)
		MaxRemotesPerSecond = 40, -- per player, all combat remotes together
	},

	Map = {
		GroundSize = 420,
		WallDistance = 140, -- invisible wall + picket fence ring around the arena
		SpawnDistance = 128, -- enemies spawn this far from the center
	},
}
