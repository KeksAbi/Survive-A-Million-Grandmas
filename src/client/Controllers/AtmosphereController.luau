--!nonstrict
-- Boss-wave mood: while the current wave has a boss (its countdown and the wave itself), the sky turns to a
-- dark red dusk (Config.Boss.WaveLighting). Back to the normal day when that wave ends. Local and visual only.
-- The cutscene darkens further on top and restores to this mood afterwards (it saves the lighting it found).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local WaveDefinitions = require(Shared.WaveDefinitions)

local AtmosphereController = {}

local active = false
local day = nil -- lighting before the mood started
local grade: ColorCorrectionEffect? = nil

local function tween(instance: Instance, goal: { [string]: any })
	local info = TweenInfo.new(Config.Boss.WaveLighting.FadeSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(instance, info, goal):Play()
end

local function isBossWave(): boolean
	local state = workspace:GetAttribute("MatchState")
	local wave = workspace:GetAttribute("Wave")
	if state ~= "Intermission" and state ~= "Wave" or typeof(wave) ~= "number" then
		return false
	end
	local def = WaveDefinitions[wave]
	return def ~= nil and def.Boss ~= nil
end

local function refresh()
	local want = isBossWave()
	if want == active then
		return
	end
	active = want
	local mood = Config.Boss.WaveLighting
	if active then
		day = day or { -- captured once: the map's normal lighting never changes
			ClockTime = Lighting.ClockTime,
			Brightness = Lighting.Brightness,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			Ambient = Lighting.Ambient,
		}
		if not grade then
			grade = Instance.new("ColorCorrectionEffect")
			grade.Name = "BossWaveGrade"
			grade.Parent = Lighting
		end
		tween(Lighting, { ClockTime = mood.ClockTime, Brightness = mood.Brightness, OutdoorAmbient = mood.OutdoorAmbient, Ambient = mood.Ambient })
		tween(grade, { TintColor = mood.TintColor, Contrast = mood.Contrast, Saturation = mood.Saturation })
	else
		if day then
			tween(Lighting, day)
		end
		if grade then
			tween(grade, { TintColor = Color3.new(1, 1, 1), Contrast = 0, Saturation = 0 })
		end
	end
end

function AtmosphereController.Init()
	workspace:GetAttributeChangedSignal("MatchState"):Connect(refresh)
	workspace:GetAttributeChangedSignal("Wave"):Connect(refresh)
	refresh()
end

return AtmosphereController
