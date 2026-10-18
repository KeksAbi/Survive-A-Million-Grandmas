--!nonstrict
-- Client bootstrap. Controllers only display and request; the server decides everything.

local StarterGui = game:GetService("StarterGui")

local Controllers = script.Parent.Controllers

-- No Roblox tools are used: hide the default backpack bar so it doesn't take the 1-9 keys.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local InputController = require(Controllers.InputController)
local HUDController = require(Controllers.HUDController)
local CameraController = require(Controllers.CameraController)
local GunController = require(Controllers.GunController)
local SpectateController = require(Controllers.SpectateController)
local ShopController = require(Controllers.ShopController)
local WorldFxController = require(Controllers.WorldFxController)
local MobileController = require(Controllers.MobileController)
local EnemyBarController = require(Controllers.EnemyBarController)
local AdminController = require(Controllers.AdminController)
local AtmosphereController = require(Controllers.AtmosphereController)
local StoreController = require(Controllers.StoreController)
local Effects = require(script.Parent.Effects)

InputController.Init()
HUDController.Init()
CameraController.Init()
GunController.Init()
SpectateController.Init()
ShopController.Init()
WorldFxController.Init()
MobileController.Init()
EnemyBarController.Init()
AdminController.Init()
AtmosphereController.Init()
StoreController.Init()
Effects.StartMusic()
