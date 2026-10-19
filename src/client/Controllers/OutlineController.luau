--!nonstrict
-- Comic ink outlines (Config.Comic): one outline-only Highlight per map outline group (Models the server's
-- ComicKit tags with Config.Comic.OutlineTag), one for all grandmas together (workspace.Enemies is a Model)
-- and one per character. Roblox draws at most 31 Highlights at once, so nothing here is per prop.
-- Occluded depth mode: outlines never show through walls. The own outline is off in first person.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local OutlineController = {}

local player = Players.LocalPlayer
local ownOutline: Highlight? = nil

local function outline(target: Instance): Highlight
	local existing = target:FindFirstChild("ComicOutline")
	if existing and existing:IsA("Highlight") then
		return existing
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "ComicOutline"
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0
	highlight.OutlineColor = Config.Comic.InkColor
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = target
	highlight.Parent = target
	return highlight
end

local function watchCharacters(owner: Player)
	local function added(character: Model)
		local highlight = outline(character)
		if owner == player then
			ownOutline = highlight
		end
	end
	if owner.Character then
		added(owner.Character)
	end
	owner.CharacterAdded:Connect(added)
end

function OutlineController.Init()
	local comic = Config.Comic
	if not comic.Outlines then
		return
	end

	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local function outlineGroup(group: Instance)
		if touchOnly and table.find(comic.SkipOutlinesOnTouch, group.Name) then
			return
		end
		outline(group)
	end
	for _, group in CollectionService:GetTagged(comic.OutlineTag) do
		outlineGroup(group)
	end
	CollectionService:GetInstanceAddedSignal(comic.OutlineTag):Connect(outlineGroup)

	if comic.OutlineEnemies then
		task.spawn(function()
			local enemies = workspace:WaitForChild("Enemies")
			if enemies:IsA("Model") then
				outline(enemies)
			end
		end)
	end

	if comic.OutlineCharacters then
		for _, other in Players:GetPlayers() do
			watchCharacters(other)
		end
		Players.PlayerAdded:Connect(watchCharacters)
		RunService.RenderStepped:Connect(function()
			local highlight = ownOutline
			if not (highlight and highlight.Parent) then
				return
			end
			local head = player.Character and player.Character:FindFirstChild("Head")
			local camera = workspace.CurrentCamera
			local firstPerson = head and camera and (camera.CFrame.Position - head.Position).Magnitude < comic.FirstPersonDistance
			highlight.Enabled = not firstPerson
		end)
	end
end

return OutlineController
