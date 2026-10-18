--!nonstrict
-- Turns raw input into game actions. Other controllers listen to these signals instead of UserInputService.
-- PC: LMB fire, R reload, 1/2/3 weapon slots, G grenade. (Touch buttons are added by the HUD in Phase 5.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage:WaitForChild("Shared").Signal)

local InputController = {}

InputController.FireBegan = Signal.new()
InputController.FireEnded = Signal.new()
InputController.ReloadPressed = Signal.new()
InputController.SlotPressed = Signal.new() -- (slot: number)
InputController.GrenadePressed = Signal.new()

local SLOT_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
}

function InputController.Init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			InputController.FireBegan:Fire()
		elseif input.KeyCode == Enum.KeyCode.R then
			InputController.ReloadPressed:Fire()
		elseif input.KeyCode == Enum.KeyCode.G then
			InputController.GrenadePressed:Fire()
		elseif SLOT_KEYS[input.KeyCode] then
			InputController.SlotPressed:Fire(SLOT_KEYS[input.KeyCode])
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			InputController.FireEnded:Fire()
		end
	end)
end

return InputController
