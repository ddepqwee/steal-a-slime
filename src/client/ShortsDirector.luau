--!nonstrict
-- Клиентская часть «режиссёра»: кинокамеры и движение персонажа по сценарию.
-- Активна только в Studio при Workspace.Director = true. F9 — запустить сцену (или авто через 8 сек).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local ShortsDirector = {}

local function myPlot(): Model?
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return nil
	end
	for _, m in map:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("OwnerUserId") == player.UserId then
			return m
		end
	end
	return nil
end

local function hideClutter()
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
	pcall(function()
		game:GetService("ProximityPromptService").Enabled = false
	end)
end

function ShortsDirector.Start(HUD)
	if not (RunService:IsStudio() and Workspace:GetAttribute("Director") == true) then
		return
	end
	local Remote = Net.event("Director")
	local camera = Workspace.CurrentCamera
	local stage = "Idle"
	local d = {} :: any
	local t0 = os.clock()
	local started = false

	local function begin()
		if started then
			return
		end
		started = true
		hideClutter()
		HUD.SetCinematic(true)
		Remote:FireServer("Start")
	end

	UserInputService.InputBegan:Connect(function(input, gp)
		if not gp and input.KeyCode == Enum.KeyCode.F9 then
			begin()
		end
	end)
	task.delay(8, begin)

	local function punch(fov: number)
		camera.FieldOfView = fov
		TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { FieldOfView = 58 }):Play()
	end

	Remote.OnClientEvent:Connect(function(s, data)
		stage = s
		d = data or {}
		t0 = os.clock()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local plot = myPlot()
		if s == "End" then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = 70
			HUD.SetCinematic(false)
			started = false
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		if s == "Follow" then
			camera.FieldOfView = 58
		elseif s == "Bought" then
			punch(48)
			-- ставим персонажа у входа на базу, чтобы потом бежать за вором
			if char and plot then
				char:PivotTo(plot.Floor.CFrame * CFrame.new(9, 4, -18))
			end
		elseif s == "Stolen" then
			punch(45)
			if hum then
				hum.WalkSpeed = 28
			end
		elseif s == "Win" then
			punch(46)
			if hum then
				hum.WalkSpeed = 16
				hum:MoveTo(char:GetPivot().Position)
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		if stage == "Idle" or stage == "End" then
			return
		end
		local t = os.clock() - t0
		local plot = myPlot()
		local base = plot and plot.Floor.CFrame
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")

		if stage == "Follow" and d.Model and d.Model.Parent then
			local p = d.Model:GetPivot().Position
			local a = 1.2 + t * 0.25
			camera.CFrame = CFrame.lookAt(p + Vector3.new(math.cos(a) * 13, 4.5, math.sin(a) * 13), p + Vector3.new(0, 1.5, 0))
		elseif stage == "Bought" and base and d.Slot then
			local ped = plot:FindFirstChild("Pedestal" .. d.Slot)
			if ped then
				local target = ped.Position + Vector3.new(0, 4, 0)
				local from = (base * CFrame.new(10 - t * 2, 12 - t, -26 + t * 3)).Position
				camera.CFrame = CFrame.lookAt(from, target)
			end
		elseif (stage == "Thief") and base and d.Model and d.Model.Parent then
			local p = d.Model:GetPivot().Position
			camera.CFrame = CFrame.lookAt(p + base:VectorToWorldSpace(Vector3.new(9, 5, -9)), p + Vector3.new(0, 2, 0))
		elseif stage == "Stolen" and d.Model and d.Model.Parent and root then
			local p = d.Model:GetPivot().Position
			-- первые 1.5 сек — крупный план вора со слаймом, потом камера за спиной погони
			if t < 1.5 and base then
				camera.CFrame = CFrame.lookAt(p + base:VectorToWorldSpace(Vector3.new(-5, 4, -7)), p + Vector3.new(0, 3, 0))
			else
				local dir = (p - root.Position) * Vector3.new(1, 0, 1)
				if dir.Magnitude > 0.1 then
					dir = dir.Unit
				else
					dir = Vector3.new(0, 0, 1)
				end
				camera.CFrame = CFrame.lookAt(root.Position - dir * 11 + Vector3.new(0, 5.5, 0), p + Vector3.new(0, 2, 0))
				if hum then
					hum:MoveTo(p)
				end
				if (p - root.Position).Magnitude < 5.5 then
					stage = "Bonking"
					Remote:FireServer("Bonk")
				end
			end
		elseif stage == "Bonking" and d.Model and d.Model.Parent and root then
			local p = d.Model:GetPivot().Position
			camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(6, 6, 6), p)
		elseif stage == "Win" and base and d.Slot then
			local ped = plot:FindFirstChild("Pedestal" .. d.Slot)
			if ped then
				local c = ped.Position + Vector3.new(0, 4, 0)
				local a = math.rad(-90) + t * 0.5
				local off = base:VectorToWorldSpace(Vector3.new(math.cos(a) * 14, 6, math.sin(a) * 14))
				camera.CFrame = CFrame.lookAt(c + off, c)
			end
		end
	end)
end

return ShortsDirector
