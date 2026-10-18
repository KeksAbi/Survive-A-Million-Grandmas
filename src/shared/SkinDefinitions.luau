--!strict
-- Cosmetic gun skins. Requires = gamepass key in Config.Monetization.Passes (nil = free for everyone).
-- A skin only recolors the placeholder gun (and tints its tracers); it never changes stats.

export type SkinDefinition = {
	Id: string,
	Name: string,
	Requires: string?,
	BodyColor: Color3?, -- nil = the weapon's own colors
	AccentColor: Color3?,
	Material: Enum.Material?,
	TracerColor: Color3?,
}

local Skins: { [string]: SkinDefinition } = {
	Default = { Id = "Default", Name = "CLASSIC" },
	Gold = {
		Id = "Gold",
		Name = "GOLDEN",
		Requires = "VIP",
		BodyColor = Color3.fromRGB(255, 196, 40),
		AccentColor = Color3.fromRGB(255, 240, 160),
		Material = Enum.Material.Metal,
		TracerColor = Color3.fromRGB(255, 210, 60),
	},
	Candy = {
		Id = "Candy",
		Name = "CANDY",
		Requires = "SkinPack",
		BodyColor = Color3.fromRGB(255, 120, 190),
		AccentColor = Color3.fromRGB(255, 255, 255),
		TracerColor = Color3.fromRGB(255, 150, 210),
	},
	Toxic = {
		Id = "Toxic",
		Name = "TOXIC",
		Requires = "SkinPack",
		BodyColor = Color3.fromRGB(30, 34, 30),
		AccentColor = Color3.fromRGB(110, 255, 60),
		Material = Enum.Material.Neon,
		TracerColor = Color3.fromRGB(120, 255, 80),
	},
	Galaxy = {
		Id = "Galaxy",
		Name = "GALAXY",
		Requires = "SkinPack",
		BodyColor = Color3.fromRGB(40, 20, 90),
		AccentColor = Color3.fromRGB(180, 90, 255),
		Material = Enum.Material.Neon,
		TracerColor = Color3.fromRGB(170, 110, 255),
	},
}

local Order = { "Default", "Gold", "Candy", "Toxic", "Galaxy" }

return {
	Skins = Skins,
	Order = Order,
}
