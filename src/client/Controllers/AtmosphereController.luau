--!nonstrict
-- Boss mood: the MEGA GRANDMA cutscene turns the sky to a dark red dusk, and it STAYS dark
-- (Config.Boss.WaveLighting) until that wave ends; then the normal day fades back. Local and visual only.
-- BossCutsceneController calls BossIntroStarted / BossIntroFinished; a player who joins mid-fight (no
-- cutscene) gets the mood from the workspace BossName attribute.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local AtmosphereController = {}

local active = false
local introPlaying = false -- the cutscene owns the lighting meanwhile
local bossSeen = false -- the boss appeared in the current wave (stays true after she dies)
local day: { [string]: any }? = nil -- the map's normal lighting
local grade: ColorCorrectionEffect? = nil

local function tween(instance: Instance, seconds: number, goal: { [string]: any })
	TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), goal):Play()
end

local function captureDay()
	day = day or {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Ambient = Lighting.Ambient,
	}
end

local function refresh(fadeSeconds: number?)
	if introPlaying then
		return
	end
	if workspace:GetAttribute("MatchState") ~= "Wave" then
		bossSeen = false
	elseif workspace:GetAttribute("BossName") ~= nil then
		bossSeen = true
	end
	local want = bossSeen
	if want == active then
		return
	end
	active = want
	local mood = Config.Boss.WaveLighting
	local seconds = fadeSeconds or mood.FadeSeconds
	if active then
		captureDay()
		local effect = grade or Instance.new("ColorCorrectionEffect")
		effect.Name = "BossWaveGrade"
		effect.Parent = Lighting
		grade = effect
		tween(Lighting, seconds, { ClockTime = mood.ClockTime, Brightness = mood.Brightness, OutdoorAmbient = mood.OutdoorAmbient, Ambient = mood.Ambient })
		tween(effect, seconds, { TintColor = mood.TintColor, Contrast = mood.Contrast, Saturation = mood.Saturation })
	else
		if day then
			tween(Lighting, seconds, day :: { [string]: any })
		end
		if grade then
			tween(grade :: ColorCorrectionEffect, seconds, { TintColor = Color3.new(1, 1, 1), Contrast = 0, Saturation = 0 })
		end
	end
end

-- Called before the cutscene darkens anything: remember the normal day lighting.
function AtmosphereController.BossIntroStarted()
	if not active then
		day = nil
		captureDay()
	end
	introPlaying = true
end

-- Called when the cutscene ends: go from the cutscene's darkness into the boss mood (not back to day).
function AtmosphereController.BossIntroFinished(fadeSeconds: number)
	introPlaying = false
	bossSeen = workspace:GetAttribute("MatchState") == "Wave"
	refresh(fadeSeconds)
end

-- true while the boss mood holds the lighting (the cutscene then must not restore the day itself)
function AtmosphereController.IsBossMood(): boolean
	return active
end

function AtmosphereController.Init()
	for _, name in { "MatchState", "Wave", "BossName" } do
		workspace:GetAttributeChangedSignal(name):Connect(function()
			refresh()
		end)
	end
	refresh()
end

return AtmosphereController
