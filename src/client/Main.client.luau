--!nonstrict
-- Client bootstrap. Controllers only display and request; the server decides everything.

local Controllers = script.Parent.Controllers

local InputController = require(Controllers.InputController)
local HUDController = require(Controllers.HUDController)
local GunController = require(Controllers.GunController)

InputController.Init()
HUDController.Init()
GunController.Init()
