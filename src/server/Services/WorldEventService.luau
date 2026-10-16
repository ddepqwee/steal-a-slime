--!nonstrict
-- Случайные события мира: ☄️ Meteor, 🌧️ Slime Rain, 🦹 Bandit Raid.
-- Запускаются сами каждые 4–7 минут, если на сервере есть игроки.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Format = require(ReplicatedStorage.Shared.Format)

local WorldEventService = {}
local rng = Random.new()
local folder: Folder
local bonkedBandits = {} :: { [Model]: boolean }

function WorldEventService:Init(S)
	self.S = S
	folder = Instance.new("Folder")
	folder.Name = "WorldEvents"
	folder.Parent = Workspace
end

local function anchoredPart(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = props.Parent or folder
	return p
end

local function billboard(parent: Instance, text: string, color: Color3, size: UDim2, offset: Vector3, onTop: boolean?)
	local bb = Instance.new("BillboardGui")
	bb.Size = size
	bb.StudsOffset = offset
	bb.AlwaysOnTop = onTop == true
	bb.LightInfluence = 0
	bb.MaxDistance = 1000
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color
	t.TextStrokeTransparency = 0
	t.Text = text
	t.Parent = bb
	bb.Parent = parent
	return t
end

local function burst(at: Vector3, colors: ColorSequence, count: number)
	local p = anchoredPart({ Size = Vector3.new(1, 1, 1), Position = at, Transparency = 1 })
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 0
	pe.Speed = NumberRange.new(20, 45)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Lifetime = NumberRange.new(0.6, 1.2)
	pe.Size = NumberSequence.new(1.5, 0)
	pe.LightEmission = 1
	pe.Color = colors
	pe.Parent = p
	pe:Emit(count)
	task.delay(2, function()
		p:Destroy()
	end)
end

-- Выдать слайма из события игроку (на базу); true если получилось
function WorldEventService:_grant(player: Player, entry): boolean
	local Plot = self.S.PlotService
	if not Plot:GetPlot(player) then
		return false
	end
	if not Plot:FreeSlot(player) then
		self.S.SocialService:Notify(player, "Base is full! Sell a slime or buy more slots in 🧰 Gear", Color3.fromRGB(255, 120, 120))
		return false
	end
	local slot = Plot:AddPet(player, entry)
	if not slot then
		return false
	end
	Plot:RenderSlot(player, slot)
	self.S.QuestService:Add(player, "Event", 1)
	return true
end

-- Случайная точка в открытом поле (вне баз и дороги)
local function fieldPoint(): Vector3
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	return Vector3.new(rng:NextNumber(-150, 150), 0, side * rng:NextNumber(92, 135))
end

-- ☄️ METEOR: через 10 сек в поле падает редкий слайм, первый зажавший E забирает
function WorldEventService:Meteor()
	local cfg = Config.WorldEvents.Meteor
	local pos = fieldPoint()
	local marker = anchoredPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 22, 22), CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 60, 40), Material = Enum.Material.Neon, Transparency = 0.4 })
	local beam = anchoredPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(300, 3, 3), CFrame = CFrame.new(pos + Vector3.new(0, 150, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, Transparency = 0.5 })
	local label = billboard(marker, "☄️ METEOR " .. cfg.Warn, Color3.fromRGB(255, 160, 60), UDim2.fromOffset(240, 60), Vector3.new(0, 10, 0), true)
	self.S.SocialService:NotifyAll("☄️ A METEOR is falling! A rare slime lands in " .. cfg.Warn .. "s — follow the beam!", Color3.fromRGB(255, 140, 60), "Legendary")
	for i = cfg.Warn, 1, -1 do
		label.Text = "☄️ METEOR " .. i
		task.wait(1)
	end
	-- падение
	local rock = anchoredPart({ Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), Position = pos + Vector3.new(0, 220, 0), Color = Color3.fromRGB(255, 90, 20), Material = Enum.Material.Neon })
	local fire = Instance.new("Fire")
	fire.Size = 20
	fire.Heat = 25
	fire.Parent = rock
	local tw = TweenService:Create(rock, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = pos + Vector3.new(0, 3, 0) })
	tw:Play()
	tw.Completed:Wait()
	rock:Destroy()
	beam:Destroy()
	burst(pos + Vector3.new(0, 3, 0), ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 60, 20)), 120)
	marker.Color = Color3.fromRGB(60, 40, 40)
	marker.Material = Enum.Material.Slate
	marker.Transparency = 0
	label.Text = "☄️ METEOR SLIME"

	local entry = self.S.SpawnService:RollEntry(cfg.MinRarity, 2)
	local def = Pets.ById[entry.Id]
	local model = self.S.PetFactory:Build(entry, { Scale = 1.6 })
	model:PivotTo(CFrame.new(pos + Vector3.new(0, model.PrimaryPart.Size.Y * 0.7 + 0.5, 0)))
	model.Parent = folder
	local claimed = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Claim"
	prompt.ObjectText = def.Name
	prompt.HoldDuration = cfg.ClaimHold
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		if claimed then
			return
		end
		if self:_grant(player, entry) then
			claimed = true
			self.S.SocialService:NotifyAll("☄️ " .. player.DisplayName .. " claimed the METEOR " .. def.Name .. "!", Config.Rarities[def.Rarity].Color)
			model:Destroy()
		end
	end)
	local t0 = os.clock()
	while not claimed and os.clock() - t0 < cfg.Lifetime do
		task.wait(0.5)
	end
	if not claimed and model.Parent then
		self.S.SocialService:NotifyAll("☄️ Nobody claimed the meteor slime... it melted away", Color3.fromRGB(200, 200, 200))
		model:Destroy()
	end
	marker:Destroy()
end

-- 🌧️ SLIME RAIN: на дорогу и тротуары падают бесплатные слаймы
function WorldEventService:Rain()
	local cfg = Config.WorldEvents.Rain
	self.S.SocialService:NotifyAll("🌧️ SLIME RAIN! Free slimes are falling on the road — grab them!", Color3.fromRGB(120, 220, 255), "Legendary")
	local items = {}
	for i = 1, cfg.Count do
		task.delay(i * 0.35, function()
			local entry = self.S.SpawnService:RollEntry(nil, cfg.LuckMult)
			local def = Pets.ById[entry.Id]
			local model = self.S.PetFactory:Build(entry, { Scale = 1.2 })
			local ground = Vector3.new(rng:NextNumber(-150, 150), 0.5, rng:NextNumber(-16, 16))
			local h = model.PrimaryPart.Size.Y * 0.6
			model:PivotTo(CFrame.new(ground + Vector3.new(0, 80, 0)))
			model.Parent = folder
			local item = { model = model, taken = false }
			table.insert(items, item)
			local start = os.clock()
			local conn
			conn = RunService.Heartbeat:Connect(function()
				local a = math.min(1, (os.clock() - start) / 1.4)
				model:PivotTo(CFrame.new(ground + Vector3.new(0, h + 80 * (1 - a * a), 0)))
				if a >= 1 then
					conn:Disconnect()
				end
			end)
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Grab"
			prompt.ObjectText = def.Name
			prompt.HoldDuration = 0.3
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = model.PrimaryPart
			prompt.Triggered:Connect(function(player)
				if item.taken then
					return
				end
				if self:_grant(player, entry) then
					item.taken = true
					burst(model:GetPivot().Position, ColorSequence.new(Color3.fromRGB(120, 220, 255)), 25)
					model:Destroy()
					if def.Rarity >= 4 then
						self.S.SocialService:NotifyAll("🌧️ " .. player.DisplayName .. " grabbed a " .. Config.Rarities[def.Rarity].Name .. " " .. def.Name .. " from the rain!", Config.Rarities[def.Rarity].Color)
					end
				end
			end)
		end)
	end
	task.wait(cfg.Duration)
	for _, item in items do
		if not item.taken and item.model.Parent then
			burst(item.model:GetPivot().Position, ColorSequence.new(Color3.fromRGB(200, 200, 255)), 10)
			item.model:Destroy()
		end
	end
	self.S.SocialService:NotifyAll("🌧️ The slime rain is over!", Color3.fromRGB(180, 200, 255))
end

-- 🦹 BANDIT RAID: по карте бегают бандиты с мешками денег — бонкни и забери награду
function WorldEventService:BanditBonked(player: Player, npc: Model)
	if bonkedBandits[npc] or not npc.Parent then
		return
	end
	bonkedBandits[npc] = true
	local cfg = Config.WorldEvents.Raid
	local reward = math.floor(math.max(cfg.RewardMin, self.S.EconomyService:GetIncome(player) * cfg.RewardSeconds))
	self.S.EconomyService:AddCash(player, reward)
	self.S.QuestService:Add(player, "Bonk", 1)
	if rng:NextNumber() < cfg.SlimeChance then
		local entry = self.S.SpawnService:RollEntry(2, 1.5)
		if self:_grant(player, entry) then
			local def = Pets.ById[entry.Id]
			self.S.SocialService:NotifyAll("🦹 " .. player.DisplayName .. " found a " .. Config.Rarities[def.Rarity].Name .. " " .. def.Name .. " in a bandit's bag!", Config.Rarities[def.Rarity].Color)
		end
	end
	local root = npc:FindFirstChild("HumanoidRootPart")
	if root then
		burst(root.Position + Vector3.new(0, 3, 0), ColorSequence.new(Color3.fromRGB(255, 230, 80), Color3.fromRGB(120, 255, 120)), 60)
	end
	self.S.SocialService:Notify(player, "💰 BONK! You got " .. Format.money(reward) .. " from a bandit!", Color3.fromRGB(255, 230, 90), "Bonk")
	local hum = npc:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Sit = true
	end
	task.delay(1.2, function()
		npc:Destroy()
		bonkedBandits[npc] = nil
	end)
end

function WorldEventService:Raid()
	local cfg = Config.WorldEvents.Raid
	self.S.SocialService:NotifyAll("🦹 BANDIT RAID! 12 bandits are running around — chase & BONK them for cash!", Color3.fromRGB(255, 170, 60), "Legendary")
	local names = { "Bandit Bob", "Sneaky Sam", "Greedy Gus", "Robber Rex", "Shady Shay", "Loot Larry" }
	local bandits = {}
	for i = 1, cfg.Count do
		local at = CFrame.new(Vector3.new(rng:NextNumber(-140, 140), 4, rng:NextNumber(-10, 10)))
		local npc = self.S.DirectorService:_makeThief(names[((i - 1) % #names) + 1], at)
		local hum = npc:FindFirstChildOfClass("Humanoid")
		hum.WalkSpeed = cfg.Speed
		-- мешок денег над головой
		local head = npc:FindFirstChild("Head")
		if head then
			local bag = Instance.new("Part")
			bag.Shape = Enum.PartType.Ball
			bag.Size = Vector3.new(2.2, 2.2, 2.2)
			bag.Color = Color3.fromRGB(240, 200, 60)
			bag.Material = Enum.Material.Foil
			bag.CanCollide = false
			bag.Massless = true
			bag.CFrame = head.CFrame * CFrame.new(0, 2, 0)
			bag.Parent = npc
			local w = Instance.new("WeldConstraint")
			w.Part0 = head
			w.Part1 = bag
			w.Parent = bag
			billboard(bag, "💰", Color3.new(1, 1, 1), UDim2.fromOffset(40, 40), Vector3.new(0, 1.8, 0))
		end
		CollectionService:AddTag(npc, "Bandit")
		table.insert(bandits, npc)
		-- бродят у дороги и убегают от игроков
		task.spawn(function()
			local nextWander = 0
			while npc.Parent do
				local root = npc:FindFirstChild("HumanoidRootPart")
				if not root then
					break
				end
				local nearest, dist = nil, math.huge
				for _, p in Players:GetPlayers() do
					local pr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					if pr then
						local d = (pr.Position - root.Position).Magnitude
						if d < dist then
							nearest, dist = pr, d
						end
					end
				end
				if nearest and dist < cfg.FleeRange then
					local away = (root.Position - nearest.Position) * Vector3.new(1, 0, 1)
					away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
					-- лёгкий зигзаг, чтобы погоня была интереснее
					away = (CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), 0) * CFrame.new(away)).Position
					local target = root.Position + away * 22
					target = Vector3.new(math.clamp(target.X, -165, 165), 0, math.clamp(target.Z, -140, 140))
					hum:MoveTo(target)
					nextWander = os.clock() + 1.5
				elseif os.clock() > nextWander then
					hum:MoveTo(Vector3.new(rng:NextNumber(-150, 150), 0, rng:NextNumber(-18, 18)))
					nextWander = os.clock() + rng:NextNumber(2, 4)
				end
				task.wait(0.3)
			end
		end)
	end
	task.wait(cfg.Duration)
	local left = 0
	for _, npc in bandits do
		if npc.Parent then
			left += 1
			npc:Destroy()
		end
	end
	if left > 0 then
		self.S.SocialService:NotifyAll("🦹 " .. left .. " bandit(s) escaped with their loot!", Color3.fromRGB(220, 180, 140))
	else
		self.S.SocialService:NotifyAll("🦹 All bandits were bonked! Great job!", Color3.fromRGB(140, 255, 160))
	end
end

function WorldEventService:RunRandom()
	local roll = rng:NextNumber()
	if roll < 0.4 then
		self:Meteor()
	elseif roll < 0.75 then
		self:Rain()
	else
		self:Raid()
	end
end

function WorldEventService:Start()
	if self.S.DirectorService:Enabled() then
		return
	end
	local cfg = Config.WorldEvents
	task.wait(90) -- первое событие через полторы минуты после старта сервера
	while true do
		if #Players:GetPlayers() > 0 then
			local ok, err = pcall(self.RunRandom, self)
			if not ok then
				warn("[WorldEvent]", err)
			end
		end
		task.wait(rng:NextNumber(cfg.MinGap, cfg.MaxGap))
	end
end

return WorldEventService
