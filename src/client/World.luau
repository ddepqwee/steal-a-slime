--!nonstrict
-- Клиентская логика мира: какие подсказки видит игрок, проход через свой замок, радужные эффекты.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local World = {}

local function setupPrompt(prompt: ProximityPrompt)
	local owner = prompt:GetAttribute("OwnerUserId")
	if prompt.Name == "StealPrompt" then
		prompt.Enabled = owner ~= player.UserId
	elseif prompt.Name == "SellPrompt" then
		prompt.Enabled = owner == player.UserId
	end
end

local function setupBarrier(plot: Instance)
	for _, wall in plot:GetChildren() do
		if wall:IsA("BasePart") and wall.Name == "LockWall" then
			local function apply()
				if plot:GetAttribute("OwnerUserId") == player.UserId and wall.CanCollide then
					wall.CanCollide = false -- хозяин проходит через своё силовое поле
				end
			end
			wall:GetPropertyChangedSignal("CanCollide"):Connect(apply)
			plot:GetAttributeChangedSignal("OwnerUserId"):Connect(apply)
			apply()
		end
	end
end

function World.Start()
	for _, d in Workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			setupPrompt(d)
		end
	end
	Workspace.DescendantAdded:Connect(function(d)
		if d:IsA("ProximityPrompt") then
			setupPrompt(d)
		end
	end)

	local map = Workspace:WaitForChild("Map")
	for _, c in map:GetChildren() do
		if c:IsA("Model") and c.Name:match("^Plot") then
			setupBarrier(c)
		end
	end
	map.ChildAdded:Connect(function(c)
		if c:IsA("Model") and c.Name:match("^Plot") then
			task.wait()
			setupBarrier(c)
		end
	end)

	-- Радужные слаймы
	RunService.RenderStepped:Connect(function()
		local hue = (os.clock() * 0.25) % 1
		for _, p in CollectionService:GetTagged("Rainbow") do
			if p:IsA("BasePart") then
				p.Color = Color3.fromHSV(hue, 0.8, 1)
			end
		end
	end)
end

return World
