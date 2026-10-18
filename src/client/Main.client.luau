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
local GunController = require(Controllers.GunController)

InputController.Init()
HUDController.Init()
GunController.Init()
