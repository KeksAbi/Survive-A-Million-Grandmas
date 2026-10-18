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

InputController.Init()
HUDController.Init()
CameraController.Init()
GunController.Init()
SpectateController.Init()
ShopController.Init()
WorldFxController.Init()
