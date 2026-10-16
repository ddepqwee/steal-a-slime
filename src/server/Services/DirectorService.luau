--!nonstrict
-- «Режиссёр» роликов для YouTube Shorts. Только Studio + Workspace.Director = true.
-- Сценарий: редкий слайм выезжает → игрок покупает → NPC-вор крадёт → погоня → BONK → победа.
-- Сервер ведёт NPC и слаймов, клиент (ShortsDirector) ставит камеры и двигает персонажа.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Pets = require(ReplicatedStorage.Shared.Pets)

local DirectorService = {}
local Remote

-- Варианты сюжета: разные герои и имена воров, чтобы ролики не были одинаковыми
local HEROES = {
	{ Id = "GreatBlob", V = "Rainbow" },
	{ Id = "Glitch" },
	{ Id = "CosmoSlime", V = "Gold" },
	{ Id = "NeonNugget", V = "Rainbow" },
	{ Id = "KingGloop", V = "Rainbow" },
	{ Id = "LavaLarry", V = "Gold" },
}
local THIEVES = { "xX_SlimeThief_Xx", "noob_robber228", "SneakyPete", "ProStealer_YT", "Bacon_Bandit", "GreedyGus" }
local SHIRTS = {
	Color3.fromRGB(30, 30, 30), Color3.fromRGB(200, 30, 40), Color3.fromRGB(40, 90, 220), Color3.fromRGB(90, 200, 80),
}

function DirectorService:Enabled(): boolean
	return RunService:IsStudio() and Workspace:GetAttribute("Director") == true
end

function DirectorService:Init(S)
	self.S = S
	Remote = Net.event("Director")
end

local function send(player, stage, data)
	Remote:FireClient(player, stage, data)
end

function DirectorService:_makeThief(name: string, at: CFrame): Model
	local desc = Instance.new("HumanoidDescription")
	local shirt = SHIRTS[math.random(1, #SHIRTS)]
	desc.HeadColor = Color3.fromRGB(255, 205, 150)
	desc.LeftArmColor = desc.HeadColor
	desc.RightArmColor = desc.HeadColor
	desc.TorsoColor = shirt
	desc.LeftLegColor = Color3.fromRGB(40, 40, 60)
	desc.RightLegColor = Color3.fromRGB(40, 40, 60)
	local ok, npc = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
	if not ok then
		npc = Instance.new("Model")
		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Size = Vector3.new(2, 2, 1)
		hrp.Parent = npc
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(2, 1, 1)
		head.Parent = npc
		local hum = Instance.new("Humanoid")
		hum.Parent = npc
		npc.PrimaryPart = hrp
	end
	npc.Name = name
	local hum = npc:FindFirstChildOfClass("Humanoid")
	hum.DisplayName = name
	hum.WalkSpeed = 15
	hum.NameDisplayDistance = 80
	npc:PivotTo(at)
	npc.Parent = Workspace
	local root = npc:FindFirstChild("HumanoidRootPart")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return npc
end

local function walkTo(npc: Model, pos: Vector3, timeout: number)
	local hum = npc:FindFirstChildOfClass("Humanoid")
	local done = false
	local conn = hum.MoveToFinished:Connect(function()
		done = true
	end)
	hum:MoveTo(pos)
	local t = os.clock()
	while not done and os.clock() - t < timeout do
		task.wait(0.05)
	end
	conn:Disconnect()
end

local function bonkFx(at: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 1
	p.Position = at
	p.Parent = Workspace
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 0
	pe.Speed = NumberRange.new(15, 30)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Lifetime = NumberRange.new(0.5, 0.9)
	pe.Size = NumberSequence.new(1.2, 0)
	pe.LightEmission = 1
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 230, 80), Color3.fromRGB(255, 80, 160))
	pe.Parent = p
	pe:Emit(60)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(10, 4)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.Text = "BONK!"
	t.TextColor3 = Color3.fromRGB(255, 230, 60)
	t.TextStrokeTransparency = 0
	t.Rotation = -8
	t.Parent = bb
	bb.Parent = p
	TweenService:Create(bb, TweenInfo.new(1.2, Enum.EasingStyle.Back), { StudsOffset = Vector3.new(0, 8, 0) }):Play()
	task.delay(2, function()
		p:Destroy()
	end)
end

function DirectorService:Run(player: Player)
	if self.running then
		return
	end
	self.running = true
	local Plot = self.S.PlotService
	local plot = Plot:GetPlot(player)
	local data = self.S.DataService:Get(player)
	if not plot or not data then
		self.running = false
		return
	end
	data.Cash = math.max(data.Cash, 1e12)
	local hero = HEROES[math.random(1, #HEROES)]
	local heroDef = Pets.ById[hero.Id]
	local thiefName = THIEVES[math.random(1, #THIEVES)]

	-- Сцена 1: герой выезжает из портала
	local item = self.S.SpawnService:Spawn(nil, { Id = hero.Id, V = hero.V })
	send(player, "Follow", { Model = item.model, Name = heroDef.Name })
	local entrance = plot.CFrame * CFrame.new(0, 0, -plot.Half - 6)
	local t0 = os.clock()
	while item.model.Parent and os.clock() - t0 < 12 do
		local x = item.model:GetPivot().Position.X
		if x >= entrance.Position.X - 2 then
			break
		end
		task.wait(0.05)
	end

	-- Сцена 2: покупка и прыжок на базу
	local slot = self.S.SpawnService:TryBuy(player, item)
	send(player, "Bought", { Slot = slot, Name = heroDef.Name })
	task.wait(3)
	if not slot then
		self.running = false
		send(player, "End", {})
		return
	end
	local ped = plot.Pedestals[tonumber(slot)]

	-- Сцена 3: появляется вор и крадёт
	local thief = self:_makeThief(thiefName, entrance * CFrame.new(-10, 4, -6))
	send(player, "Thief", { Model = thief, Name = thiefName })
	task.wait(1.2)
	local pedLocal = plot.CFrame:PointToObjectSpace(ped.Position)
	walkTo(thief, (plot.CFrame * CFrame.new(pedLocal.X, 3, pedLocal.Z - 4)).Position, 6)
	task.wait(0.4)
	local original = Plot:GetSlotModel(player, slot)
	if original then
		original.Parent = nil
	end
	local carried = self.S.PetFactory:Build(data.Pets[slot] or hero, { Scale = 0.75 })
	local head = thief:FindFirstChild("Head")
	carried:PivotTo(head.CFrame * CFrame.new(0, 1.2 + carried.PrimaryPart.Size.Y * 0.6, 0))
	for _, d in carried:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
		end
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = head
	w.Part1 = carried.PrimaryPart
	w.Parent = carried.PrimaryPart
	carried.Parent = thief
	self.S.SocialService:Notify(player, "🚨 " .. thiefName .. " крадёт твоего " .. heroDef.Name .. "! Догони и бонкни!", Color3.fromRGB(255, 70, 70))
	send(player, "Stolen", { Model = thief, Name = thiefName, Pet = heroDef.Name })

	-- Сцена 4: побег и погоня
	local escape = (entrance * CFrame.new(18, 3, -8)).Position
	task.spawn(walkTo, thief, escape, 8)
	self.bonked = false
	local tChase = os.clock()
	while not self.bonked and os.clock() - tChase < 9 do
		task.wait(0.05)
	end

	-- Сцена 5: BONK и возврат
	local hum = thief:FindFirstChildOfClass("Humanoid")
	hum:MoveTo(thief:GetPivot().Position)
	bonkFx(head.Position)
	carried:Destroy()
	hum.Sit = true
	local root = thief:FindFirstChild("HumanoidRootPart")
	root.AssemblyLinearVelocity = (root.Position - (player.Character and player.Character:GetPivot().Position or root.Position)).Unit * 40 + Vector3.new(0, 35, 0)
	self.S.SocialService:NotifyAll("💥 " .. player.DisplayName .. " бонкнул вора " .. thiefName .. "!", Color3.fromRGB(120, 200, 255))
	if original then
		original.Parent = plot.Model
	else
		Plot:RenderSlot(player, slot)
	end
	send(player, "Win", { Slot = slot, Name = heroDef.Name })
	task.wait(5)
	thief:Destroy()
	send(player, "End", {})
	self.running = false
end

function DirectorService:Start()
	if not self:Enabled() then
		return
	end
	warn("[Director] режим режиссёра включён — F9 запускает сцену")
	Remote.OnServerEvent:Connect(function(player, action)
		if action == "Start" then
			task.spawn(self.Run, self, player)
		elseif action == "Bonk" then
			self.bonked = true
		end
	end)
end

return DirectorService
