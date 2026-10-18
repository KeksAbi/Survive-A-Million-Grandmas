--!nonstrict
-- On-screen buttons for touch devices: FIRE (hold), RELOAD, GRENADE. They fire the same InputController
-- signals as the keyboard and mouse, so the rest of the game doesn't know the difference.
-- Moving uses Roblox's thumbstick; turning the camera = dragging the screen; aim = screen center.

local UserInputService = game:GetService("UserInputService")

local HUDController = require(script.Parent.HUDController)
local InputController = require(script.Parent.InputController)

local MobileController = {}

local function roundButton(parent: Frame, text: string, size: number, position: UDim2, color: Color3): TextButton
	local kit = HUDController.Kit
	local button = kit.Make("TextButton", {
		Text = "",
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.15,
		Parent = parent,
	}, { kit.Corner(size // 2), kit.Stroke(3) }) :: TextButton
	kit.Label({ Text = text, Size = UDim2.new(1, -18, 0.5, 0), Position = UDim2.new(0, 9, 0.25, 0), Parent = button })
	return button
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

function MobileController.Init()
	if not UserInputService.TouchEnabled then
		return
	end
	local theme = HUDController.Kit.Theme
	-- above Roblox's jump button (bottom right): it is 70 px on phones and 120 px on bigger touch screens
	local viewport = workspace.CurrentCamera.ViewportSize
	local bigScreen = math.min(viewport.X, viewport.Y) > 500
	local panel = HUDController.CreateContainer("MobileButtons", Vector2.new(1, 1), UDim2.new(1, -16, 1, if bigScreen then -230 else -100), Vector2.new(230, 210))

	local fire = roundButton(panel, "FIRE", 116, UDim2.new(1, -62, 1, -62), theme.Red)
	fire.InputBegan:Connect(function(input)
		if isPress(input) then
			InputController.FireBegan:Fire()
		end
	end)
	fire.InputEnded:Connect(function(input)
		if isPress(input) then
			InputController.FireEnded:Fire()
		end
	end)

	local reload = roundButton(panel, "R", 64, UDim2.new(1, -40, 0, 34), theme.Blue)
	reload.Activated:Connect(function()
		InputController.ReloadPressed:Fire()
	end)

	local grenade = roundButton(panel, "G", 64, UDim2.new(0, 40, 1, -40), Color3.fromRGB(80, 125, 55))
	grenade.Activated:Connect(function()
		InputController.GrenadePressed:Fire()
	end)
end

return MobileController
