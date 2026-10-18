--!nonstrict
-- Small health bar over every damaged grandma (the boss has its own big bars).
-- Reads the "HealthRatio" attribute EnemyService sets on enemy models; the bar lives on the client only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyDefinitions = require(ReplicatedStorage:WaitForChild("Shared").EnemyDefinitions)

local EnemyBarController = {}

local function attach(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local fill: Frame? = nil
	model:GetAttributeChangedSignal("HealthRatio"):Connect(function()
		if model:GetAttribute("Boss") then
			return
		end
		local ratio = model:GetAttribute("HealthRatio") or 1
		if not fill then
			local root = model:FindFirstChild("Root")
			local def = EnemyDefinitions[tostring(model:GetAttribute("EnemyType"))]
			if not root or not def then
				return
			end
			local gui = Instance.new("BillboardGui")
			gui.Name = "HealthBar"
			gui.Size = UDim2.fromOffset(56, 8)
			gui.StudsOffsetWorldSpace = Vector3.new(0, def.RootHeight * 1.3 + 0.6, 0)
			gui.AlwaysOnTop = true
			gui.MaxDistance = 120
			gui.LightInfluence = 0
			local back = Instance.new("Frame")
			back.Size = UDim2.fromScale(1, 1)
			back.BackgroundColor3 = Color3.fromRGB(25, 20, 30)
			back.BorderSizePixel = 0
			back.Parent = gui
			local bar = Instance.new("Frame")
			bar.BackgroundColor3 = Color3.fromRGB(110, 230, 90)
			bar.BorderSizePixel = 0
			bar.Parent = back
			gui.Parent = root
			fill = bar
		end
		local bar = fill :: Frame
		bar.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		bar.BackgroundColor3 = if ratio > 0.5 then Color3.fromRGB(110, 230, 90) elseif ratio > 0.25 then Color3.fromRGB(255, 200, 50) else Color3.fromRGB(235, 60, 60)
	end)
end

function EnemyBarController.Init()
	local folder = workspace:WaitForChild("Enemies")
	folder.ChildAdded:Connect(attach)
	for _, model in folder:GetChildren() do
		attach(model)
	end
end

return EnemyBarController
