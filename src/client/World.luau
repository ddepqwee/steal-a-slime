--!nonstrict
-- Клиентская логика мира: какие подсказки видит игрок, проход через свой замок, радужные эффекты.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local World = {}

local function setupPrompt(prompt: ProximityPrompt)
	local owner = prompt:GetAttribute("OwnerUserId")
	if prompt.Name == "StealPrompt" then
		prompt.Enabled = owner ~= player.UserId
	elseif prompt.Name == "SellPrompt" or prompt.Name == "MutatePrompt" then
		prompt.Enabled = owner == player.UserId
	elseif prompt.Name == "UpgradePrompt" then
		prompt.Enabled = owner == player.UserId and prompt.ActionText ~= "MAX LEVEL"
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

	-- ❄️ Снегопад вокруг камеры (только в зимний сезон, только у этого игрока — дёшево)
	local snowPart = Instance.new("Part")
	snowPart.Name = "SnowEmitter"
	snowPart.Anchored = true
	snowPart.CanCollide = false
	snowPart.CanQuery = false
	snowPart.CanTouch = false
	snowPart.Transparency = 1
	snowPart.Size = Vector3.new(120, 1, 120)
	local snow = Instance.new("ParticleEmitter")
	snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snow.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	snow.LightEmission = 0.4
	snow.Size = NumberSequence.new(0.35)
	snow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.1), NumberSequenceKeypoint.new(0.9, 0.1), NumberSequenceKeypoint.new(1, 1) })
	snow.Lifetime = NumberRange.new(5, 7)
	snow.Rate = 160
	snow.Speed = NumberRange.new(6, 9)
	snow.SpreadAngle = Vector2.new(15, 15)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Acceleration = Vector3.new(1.5, 0, 0.5)
	snow.RotSpeed = NumberRange.new(-40, 40)
	snow.Enabled = false
	snow.Parent = snowPart
	snowPart.Parent = Workspace
	RunService.RenderStepped:Connect(function()
		local on = ReplicatedStorage:GetAttribute("Season") == "Winter"
		snow.Enabled = on
		if on then
			local cam = Workspace.CurrentCamera
			if cam then
				snowPart.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 35, 0))
			end
		end
	end)
end

return World
