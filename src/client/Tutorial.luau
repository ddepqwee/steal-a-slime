--!nonstrict
-- 🎓 Клиент туториала: карточка задания + светящийся луч от игрока к цели + подсветка цели.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local Tutorial = {}

local TEXTS = {
	"💧 Walk to the road and press E on a slime to BUY it!",
	"⬆️ Go back to your base and press E on your slime to UPGRADE it!",
	"🦹 Sneak into another base, hold E on a slime and RUN HOME with it!",
	"🔒 Thieves are coming! Step on the red LOCK button (or press 🔒 Lock)",
}

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

local function nearest(models, from: Vector3): BasePart?
	local best, bestD = nil, math.huge
	for _, m in models do
		local p = m.PrimaryPart
		if p then
			local d = (p.Position - from).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

local function findTarget(step: number, root: BasePart): BasePart?
	if step == 1 then
		local conveyor = Workspace:FindFirstChild("Conveyor")
		return conveyor and nearest(conveyor:GetChildren(), root.Position)
	elseif step == 2 then
		local plot = myPlot()
		if not plot then
			return nil
		end
		local list = {}
		for _, m in plot:GetChildren() do
			if m:IsA("Model") and m:GetAttribute("Slot") then
				table.insert(list, m)
			end
		end
		return nearest(list, root.Position)
	elseif step == 3 then
		local map = Workspace:FindFirstChild("Map")
		local list = {}
		for _, plot in (map and map:GetChildren() or {}) do
			local owner = plot:GetAttribute("OwnerUserId")
			if plot:IsA("Model") and owner and owner ~= player.UserId and not plot:GetAttribute("Locked") then
				for _, m in plot:GetChildren() do
					if m:IsA("Model") and m:GetAttribute("Slot") then
						table.insert(list, m)
					end
				end
			end
		end
		return nearest(list, root.Position)
	elseif step == 4 then
		local plot = myPlot()
		return plot and plot:FindFirstChild("LockPad")
	end
	return nil
end

function Tutorial.Start(HUD)
	local Remote = Net.event("Tutorial")
	local Action = Net.event("Action")
	local step, total = 99, 4

	-- карточка задания
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 134)
	card.Size = UDim2.fromOffset(520, 58)
	card.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	card.Visible = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 16)
	c.Parent = card
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Color3.fromRGB(90, 50, 10)
	st.Parent = card
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(12, 4)
	label.Size = UDim2.new(1, -110, 1, -8)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(60, 30, 5)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = card
	local skip = Instance.new("TextButton")
	skip.AnchorPoint = Vector2.new(1, 0.5)
	skip.Position = UDim2.new(1, -8, 0.5, 0)
	skip.Size = UDim2.fromOffset(86, 40)
	skip.BackgroundColor3 = Color3.fromRGB(90, 60, 20)
	skip.Font = Enum.Font.FredokaOne
	skip.TextScaled = true
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.Text = "Skip ⏭"
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 10)
	sc.Parent = skip
	skip.Parent = card
	card.Parent = HUD.Root or HUD.Gui
	skip.MouseButton1Click:Connect(function()
		Action:FireServer("TutSkip")
	end)

	-- луч и подсветка
	local att0 = Instance.new("Attachment")
	local att1 = Instance.new("Attachment")
	local beam = Instance.new("Beam")
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 230, 80), Color3.fromRGB(255, 120, 200))
	beam.Width0 = 0.7
	beam.Width1 = 0.7
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Segments = 12
	beam.CurveSize0 = 6
	beam.CurveSize1 = -6
	beam.Transparency = NumberSequence.new(0.15)
	beam.Enabled = false
	beam.Parent = Workspace.Terrain
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 0.6
	hl.FillColor = Color3.fromRGB(255, 230, 80)
	hl.OutlineColor = Color3.fromRGB(255, 255, 255)
	hl.Enabled = false
	hl.Parent = HUD.Gui

	Remote.OnClientEvent:Connect(function(s, t)
		step, total = s, t
		if step > total then
			card.Visible = false
			beam.Enabled = false
			hl.Enabled = false
			return
		end
		card.Visible = true
		label.Text = ("%d/%d  %s"):format(step, total, TEXTS[step] or "")
		card.Size = UDim2.fromOffset(560, 64)
		TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(520, 58) }):Play()
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		if step > total then
			return
		end
		acc += dt
		card.BackgroundColor3 = Color3.fromRGB(255, 200, 60):Lerp(Color3.fromRGB(255, 235, 140), (math.sin(os.clock() * 4) + 1) / 2)
		if acc < 0.25 then
			return
		end
		acc = 0
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local target = root and findTarget(step, root)
		if root and target then
			att0.Parent = root
			att1.Parent = target
			beam.Enabled = true
			hl.Adornee = target:FindFirstAncestorOfClass("Model") or target
			hl.Enabled = true
		else
			beam.Enabled = false
			hl.Enabled = false
		end
	end)
end

return Tutorial
