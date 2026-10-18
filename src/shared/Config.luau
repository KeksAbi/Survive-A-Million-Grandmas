--!strict
-- Global tuning values. Everything gameplay-related that is not a weapon, enemy or wave lives here.

return {
	Debug = {
		-- true = everyone owns all weapons from the start (testing only; the shop sells them normally).
		GiveAllWeapons = false,
	},

	Camera = {
		-- Normal Roblox camera (right-click drag turns it, mouse wheel zooms), just starting further out and higher.
		StartZoom = 28, -- studs from the character when spawning
		StartPitch = 40, -- degrees looking down when spawning
		MinZoom = 0.5, -- fully zoomed in = first person (FPS aiming, crosshair locked to the center)
		MaxZoom = 50,
	},

	Player = {
		MaxHealth = 100,
		StartingCash = 40,
		WalkSpeed = 16,
		SpawnInvulnerability = 2, -- seconds of ForceField after spawning
		StartingWeapon = "Pistol",
	},

	Waves = {
		FirstIntermissionSeconds = 10,
		IntermissionSeconds = 8,
		ResultsSeconds = 12, -- results screen before the next match starts
		CompletionBonus = 50, -- cash to every player when a wave is cleared ...
		CompletionBonusPerWave = 10, -- ... plus this times the wave number
		HealthGrowthPerWave = 0.08, -- enemy HP +8% per wave after the first
		ExtraPlayerCountScale = 0.5, -- +50% enemies per extra player
		ExtraPlayerBossHealthScale = 0.35, -- +35% boss HP per extra player
		FinalBossHealthScale = 1.5, -- the last wave's boss is tougher
		MinSpawnInterval = 0.25,
	},

	Enemies = {
		MaxActive = 60, -- hard cap of simultaneously alive enemies
		UpdateRate = 20, -- movement/AI ticks per second (one loop for ALL enemies)
		-- Body size per type is EnemyDefinitions.Radius (used for spacing, obstacles and hit tolerance).
		ObstacleMargin = 0.2, -- extra gap kept to map obstacles
		BobHeight = 0.25, -- cosmetic walking bob
	},

	Combat = {
		MaxShotOriginDistance = 14, -- shot origin must be this close to the shooter's head
		MaxRange = 300,
		-- Fire-rate check uses a shot budget: one shot refills per FireCooldown, up to this many can be banked.
		-- Shots often arrive in clumps over the network; a strict gap check would throw most rifle shots away.
		FireBurstAllowance = 2,
		SwapDelay = 0.2, -- seconds after switching weapons before the new one can fire
		MaxRemotesPerSecond = 40, -- per player, all combat remotes together
		-- Lag forgiveness: a shot that passes this close to an enemy's body still hits. Enemies on the
		-- server are slightly ahead of what the client sees, so without this near-perfect shots miss.
		HitTolerance = 1.2,
	},

	Grenade = {
		Cost = 60,
		MaxCarried = 5,
		Damage = 100,
		Radius = 15,
		Fuse = 2, -- seconds from throw to explosion
		FlightTime = 0.8, -- seconds in the air (then it sits and blinks until the fuse ends)
		MaxThrowDistance = 70,
		Cooldown = 0.6,
	},

	Map = {
		GroundSize = 420,
		WallDistance = 140, -- invisible wall + picket fence ring around the arena
		SpawnDistance = 128, -- enemies spawn this far from the center
	},
}
