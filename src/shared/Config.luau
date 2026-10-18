--!strict
-- Global tuning values. Everything gameplay-related that is not a weapon, enemy or wave lives here.

return {
	Debug = {
		-- true = everyone owns all weapons from the start (testing only; the shop sells them normally).
		GiveAllWeapons = false,
		-- true = enemy hit areas are drawn as see-through red boxes (to check what counts as a hit).
		ShowHitboxes = false,
		-- Matches start at this wave (testing: 5 = straight to the MEGA GRANDMA). Keep 1 for real play.
		StartWave = 1,
	},

	-- Gamepasses and developer products. Create them in the Creator Dashboard (your experience > Monetization >
	-- Passes / Developer Products) and paste the ids here. Id 0 = not set up: its button shows "COMING SOON".
	-- Price is only shown as a fallback; the real price comes from Roblox.
	Monetization = {
		Passes = {
			DoubleCash = { Id = 2039865868, Price = 149, Name = "2X CASH", Description = "Double cash from every grandma" },
			VIP = { Id = 2036092022, Price = 299, Name = "VIP", Description = "VIP tag, golden gun, golden sparkles" },
			SkinPack = { Id = 2037814053, Price = 99, Name = "SKIN PACK", Description = "3 extra gun skins" },
		},
		Products = {
			Revive = { Id = 3719683078, Price = 29, Name = "REVIVE" }, -- one revive credit (used right away if dead)
		},
		RevivesPerWave = 1, -- revive credits usable per player per wave
	},

	Data = {
		StoreName = "PlayerStats_v1", -- change the suffix only to start everyone from zero
		AutosaveSeconds = 120,
		Retries = 3, -- per DataStore call, with 1 s, 2 s, 4 s waits
		MaxStoredReceipts = 50, -- processed purchase ids kept per player (stops double grants)
	},

	Admin = {
		-- Who gets the admin panel (F2 or the ADMIN button, top right): these user ids, plus the place owner
		-- and everyone in a Studio playtest. The server checks every admin request again.
		UserIds = {} :: { number },
		AllowPlaceOwner = true,
		AllowInStudio = true,
		CashAmount = 1000, -- "+$" button
		JumpCountdownSeconds = 3, -- countdown after jumping to a wave
	},

	Camera = {
		-- Normal Roblox camera (right-click drag turns it, mouse wheel zooms), just starting further out and higher.
		StartZoom = 28, -- studs from the character when spawning
		StartPitch = 40, -- degrees looking down when spawning
		MinZoom = 0.5, -- fully zoomed in = first person (FPS aiming, crosshair locked to the center)
		MaxZoom = 50,
	},

	Boss = {
		CutsceneSeconds = 7, -- enemies frozen + players shielded while the intro cutscene plays
		SpawnPosition = Vector3.new(0, 0, -118), -- rises out of the ground in front of the retirement home
		-- After the boss cutscene the sky stays a dark red dusk until that wave ends, then day fades back.
		WaveLighting = {
			FadeSeconds = 2.5,
			ClockTime = 18.6,
			Brightness = 0.8,
			OutdoorAmbient = Color3.fromRGB(90, 35, 40),
			Ambient = Color3.fromRGB(60, 25, 30),
			TintColor = Color3.fromRGB(255, 185, 185), -- red grade (lighter than the cutscene, enemies stay readable)
			Contrast = 0.15,
			Saturation = -0.15,
		},
	},

	Mobile = {
		-- Touch devices aim through the screen center; shots bend toward an enemy within this cone.
		AimAssistDegrees = 12,
		AimAssistRange = 120,
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
		HitTolerance = 1.5,
		-- "Favor the shooter": when the client's crosshair was on an enemy, the server accepts that hit if the
		-- shot points at the enemy within this many studs and nothing on the map blocks the line of sight.
		ClaimTolerance = 3,
		-- Hit checks start this far BEHIND the muzzle (inside the shooter, which bullets ignore). Point-blank
		-- enemies overlap the gun tip, and a ray that starts inside a part never hits that part.
		RayBackOffset = 4,
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

	-- Sound asset ids ("rbxassetid://123..."). Empty = silent. Pick sounds in the Creator Store
	-- (Toolbox > Audio), check they are free to use, and paste the ids here. Music: instrumental only.
	Sounds = {
		Fire_Pistol = "",
		Fire_Shotgun = "",
		Fire_AssaultRifle = "",
		Hit = "",
		GrandmaPoof = "",
		Explosion = "",
		Stomp = "",
		Reload = "",
		WaveStart = "", -- notification kind "info"
		WaveComplete = "", -- "good"
		BossIncoming = "", -- "boss"
		BossRoar = "", -- cutscene title slam
		Thunder = "", -- cutscene lightning
		Rumble = "", -- cutscene: boss rising out of the ground
		Victory = "", -- "gold"
		Error = "", -- "bad" (game over, not enough cash)
		Music = "", -- looping background music
		Volume = 0.6,
		MusicVolume = 0.25,
	},

	Map = {
		GroundSize = 420,
		WallDistance = 140, -- invisible wall + picket fence ring around the arena
		SpawnDistance = 128, -- enemies spawn this far from the center
	},
}
