--!strict
-- Weapon data. Every number the combat code uses comes from here.
-- Spread is the cone half-angle in degrees. Automatic weapons fire while the button is held.

export type WeaponDefinition = {
	Id: string,
	Name: string,
	Cost: number,
	Damage: number, -- per pellet
	Pellets: number,
	SpreadDegrees: number,
	FireCooldown: number,
	MagSize: number,
	ReloadTime: number,
	Automatic: boolean,
	Range: number,
	Look: { BodyColor: Color3, AccentColor: Color3, Size: Vector3 }, -- placeholder gun model
	HoldScale: number, -- size in the hands, times Config.Combat.HeldGunScale
}

local Weapons: { [string]: WeaponDefinition } = {
	Pistol = {
		Id = "Pistol",
		Name = "Pistol",
		Cost = 0,
		Damage = 25,
		Pellets = 1,
		SpreadDegrees = 0.4,
		FireCooldown = 0.35,
		MagSize = 12,
		ReloadTime = 1.1,
		Automatic = false,
		Range = 200,
		HoldScale = 0.7,
		Look = {
			BodyColor = Color3.fromRGB(45, 45, 52),
			AccentColor = Color3.fromRGB(90, 90, 100),
			Size = Vector3.new(0.3, 0.55, 1.1),
		},
	},
	Shotgun = {
		Id = "Shotgun",
		Name = "Shotgun",
		Cost = 150,
		Damage = 10,
		Pellets = 8,
		SpreadDegrees = 6,
		FireCooldown = 1,
		MagSize = 6,
		ReloadTime = 1.5,
		Automatic = false,
		Range = 90,
		HoldScale = 0.8,
		Look = {
			BodyColor = Color3.fromRGB(60, 60, 66),
			AccentColor = Color3.fromRGB(140, 85, 40),
			Size = Vector3.new(0.35, 0.5, 2.2),
		},
	},
	AssaultRifle = {
		Id = "AssaultRifle",
		Name = "Assault Rifle",
		Cost = 350,
		Damage = 11,
		Pellets = 1,
		SpreadDegrees = 1.6,
		FireCooldown = 0.11,
		MagSize = 24,
		ReloadTime = 1.7,
		Automatic = true,
		Range = 200,
		HoldScale = 1.0,
		Look = {
			BodyColor = Color3.fromRGB(35, 38, 45),
			AccentColor = Color3.fromRGB(200, 170, 70),
			Size = Vector3.new(0.35, 0.6, 2.4),
		},
	},
}

-- Order of the hotbar slots (keys 1, 2, 3).
local Order = { "Pistol", "Shotgun", "AssaultRifle" }

-- Direction of one bullet. Single-bullet guns scatter randomly inside the cone. Multi-pellet guns
-- (shotgun) use a FIXED pattern: pellet 1 in the center, the rest spiral out to the cone edge. Client
-- and server compute the same pattern, so the tracers you see are exactly the pellets the server checks.
local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))
local function PelletDirection(direction: Vector3, weapon: WeaponDefinition, pellet: number): Vector3
	local degrees = weapon.SpreadDegrees
	if degrees <= 0 then
		return direction
	end
	local angle, roll
	if weapon.Pellets > 1 then
		angle = math.rad(degrees) * math.sqrt((pellet - 1) / (weapon.Pellets - 1))
		roll = pellet * GOLDEN_ANGLE
	else
		angle = math.rad(degrees) * math.sqrt(math.random())
		roll = math.random() * math.pi * 2
	end
	return (CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

return {
	Weapons = Weapons,
	Order = Order,
	PelletDirection = PelletDirection,
}
