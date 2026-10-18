--!nonstrict
-- Admin panel (top right, only for players the server marked with the `Admin` attribute).
-- F2 or the ADMIN button opens it. Buttons only send Admin requests; AdminService checks and applies them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local WaveDefinitions = require(Shared.WaveDefinitions)

local HUDController = require(script.Parent.HUDController)

local player = Players.LocalPlayer

local AdminController = {}

local built = false

local function build()
	built = true
	local kit = HUDController.Kit
	local theme = kit.Theme
	local adminRemote = Remotes.Get("Admin")

	local waveCount = #WaveDefinitions
	local columns = 5
	local waveRows = math.ceil(waveCount / columns)
	local actions = {
		{ Text = "SKIP WAVE", Action = "SkipWave", Color = theme.Blue },
		{ Text = "START NOW", Action = "SkipCountdown", Color = theme.Blue },
		{ Text = "+$" .. Config.Admin.CashAmount, Action = "AddCash", Color = theme.Gold },
		{ Text = "ALL GUNS", Action = "GiveWeapons", Color = theme.Gold },
		{ Text = "KILL ALL", Action = "KillAll", Color = theme.Red },
		{ Text = "HEAL ALL", Action = "Heal", Color = theme.Green },
	}
	local width, pad, waveHeight, actionHeight = 260, 10, 40, 40
	local panelHeight = 36 + pad + 20 + waveRows * (waveHeight + 6) + pad + math.ceil(#actions / 2) * (actionHeight + 6) + pad
	local container = HUDController.CreateContainer("Admin", Vector2.new(1, 0), UDim2.new(1, -16, 0, 60), Vector2.new(width, 40 + panelHeight))

	local function button(parent: Instance, text: string, color: Color3, position: UDim2, size: UDim2): TextButton
		local b = kit.Make("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = color,
			Position = position,
			Size = size,
			Parent = parent,
		}, { kit.Corner(8), kit.Stroke(3) }) :: TextButton
		kit.Label({ Text = text, Size = UDim2.new(1, -10, 1, -12), Position = UDim2.fromOffset(5, 6), Parent = b })
		return b
	end

	local toggle = button(container, "ADMIN (F2)", theme.Dark, UDim2.new(1, -120, 0, 0), UDim2.fromOffset(120, 32))
	local panel = kit.Make("Frame", {
		Visible = false,
		BackgroundColor3 = theme.Dark,
		BackgroundTransparency = 0.1,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.fromOffset(width, panelHeight),
		Parent = container,
	}, { kit.Corner(10), kit.Stroke(3) }) :: Frame

	local title = kit.Make("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = theme.Red, Parent = panel }, { kit.Corner(10) })
	kit.Label({ Text = "ADMIN PANEL", Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Parent = title })

	local y = 36 + pad
	kit.Label({ Text = "JUMP TO WAVE", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -2 * pad, 0, 18), Position = UDim2.fromOffset(pad, y), Parent = panel })
	y += 22
	local cellWidth = (width - 2 * pad - (columns - 1) * 6) / columns
	for wave = 1, waveCount do
		local column = (wave - 1) % columns
		local row = math.floor((wave - 1) / columns)
		local isBoss = WaveDefinitions[wave].Boss ~= nil
		local b = button(
			panel,
			tostring(wave),
			if isBoss then Color3.fromRGB(170, 30, 30) else Color3.fromRGB(55, 60, 80),
			UDim2.fromOffset(pad + column * (cellWidth + 6), y + row * (waveHeight + 6)),
			UDim2.fromOffset(cellWidth, waveHeight)
		)
		b.Activated:Connect(function()
			adminRemote:FireServer("JumpToWave", wave)
		end)
	end
	y += waveRows * (waveHeight + 6) + pad - 6

	local halfWidth = (width - 2 * pad - 6) / 2
	for index, entry in actions do
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local b = button(panel, entry.Text, entry.Color, UDim2.fromOffset(pad + column * (halfWidth + 6), y + row * (actionHeight + 6)), UDim2.fromOffset(halfWidth, actionHeight))
		b.Activated:Connect(function()
			adminRemote:FireServer(entry.Action)
		end)
	end

	local function setOpen(open: boolean)
		panel.Visible = open
	end
	toggle.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F2 then
			setOpen(not panel.Visible)
		end
	end)
end

function AdminController.Init()
	local function refresh()
		if player:GetAttribute("Admin") == true and not built then
			build()
		end
	end
	player:GetAttributeChangedSignal("Admin"):Connect(refresh)
	refresh()
end

return AdminController
