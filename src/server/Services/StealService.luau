--!nonstrict
-- Кража: хватаешь чужого слайма, несёшь на свою базу. Хозяин может догнать и бонкнуть.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)

local StealService = {}
-- thief -> { victim, slot, entry, model, started }
local carries = {} :: { [Player]: any }
local lastBonk = {} :: { [Player]: number }

function StealService:Init(S)
	self.S = S
end

function StealService:IsCarried(victim: Player, slot: string): boolean
	for _, c in carries do
		if c.victim == victim and c.slot == slot then
			return true
		end
	end
	return false
end

local function humanoidOf(player: Player): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

function StealService:TrySteal(thief: Player, victim: Player, slot: string)
	if thief == victim or carries[thief] or not victim.Parent then
		return
	end
	local Plot = self.S.PlotService
	local victimPlot = Plot:GetPlot(victim)
	local data = self.S.DataService:Get(victim)
	local entry = data and data.Pets[slot]
	if not victimPlot or not entry or self:IsCarried(victim, slot) then
		return
	end
	if Plot:IsLocked(victimPlot) then
		self.S.SocialService:Notify(thief, "This base is locked 🔒", Color3.fromRGB(255, 120, 120))
		return
	end
	if not Plot:GetPlot(thief) or not Plot:FreeSlot(thief) then
		self.S.SocialService:Notify(thief, "No free space on your base!", Color3.fromRGB(255, 120, 120))
		return
	end
	local char = thief.Character
	local head = char and char:FindFirstChild("Head")
	local hum = humanoidOf(thief)
	if not head or not hum or hum.Health <= 0 then
		return
	end

	-- Прячем слайма у жертвы, вешаем копию над головой вора
	local original = Plot:GetSlotModel(victim, slot)
	if original then
		original.Parent = nil
	end
	local carried = self.S.PetFactory:Build(entry, { Scale = 0.75 })
	local root = carried.PrimaryPart
	carried:PivotTo(head.CFrame * CFrame.new(0, 1.2 + root.Size.Y * 0.6, 0))
	for _, d in carried:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
		end
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = head
	w.Part1 = root
	w.Parent = root
	carried.Parent = char

	carries[thief] = { victim = victim, slot = slot, entry = entry, model = carried, original = original, started = os.clock() }
	thief:SetAttribute("Carrying", true)
	self.S.ProgressionService:ApplySpeed(thief)

	local def = Pets.ById[entry.Id]
	self.S.SocialService:Notify(victim, "🚨 " .. thief.DisplayName .. " is stealing your " .. def.Name .. "! Chase and BONK them!", Color3.fromRGB(255, 70, 70))
	self.S.SocialService:Notify(thief, "Run back to your base! 🏃", Color3.fromRGB(120, 255, 160))
	self.S.SocialService:PlaySound(victim, "Steal")
end

function StealService:_finish(thief: Player, success: boolean)
	local c = carries[thief]
	if not c then
		return
	end
	carries[thief] = nil
	if c.model then
		c.model:Destroy()
	end
	thief:SetAttribute("Carrying", false)
	if thief.Parent then
		self.S.ProgressionService:ApplySpeed(thief)
	end

	local Plot = self.S.PlotService
	local victimData = self.S.DataService:Get(c.victim)
	if success and victimData and victimData.Pets[c.slot] and Plot:FreeSlot(thief) then
		Plot:RemovePet(c.victim, c.slot)
		if c.original then
			c.original:Destroy()
		end
		local newSlot = Plot:AddPet(thief, c.entry)
		if newSlot then
			Plot:RenderSlot(thief, newSlot)
		end
		local tData = self.S.DataService:Get(thief)
		if tData then
			tData.Steals += 1
		end
		self.S.QuestService:Add(thief, "Steal", 1)
		self.S.TutorialService:Advance(thief, "Steal")
		self.S.AnalyticsHub:Custom(thief, "Steal", 1)
		self.S.AchievementService:Check(thief)
		local def = Pets.ById[c.entry.Id]
		self.S.SocialService:NotifyAll("🦹 " .. thief.DisplayName .. " stole " .. def.Name .. " from " .. c.victim.DisplayName .. "!", Color3.fromRGB(255, 160, 60))
	else
		-- Возвращаем слайма хозяину
		if c.original and c.victim.Parent and victimData and victimData.Pets[c.slot] then
			local plot = Plot:GetPlot(c.victim)
			local ok = plot ~= nil and pcall(function()
				c.original.Parent = plot.Model
			end)
			if not ok then
				Plot:RenderSlot(c.victim, c.slot)
			end
		elseif c.original then
			c.original:Destroy()
		end
	end
end

function StealService:CancelForVictim(victim: Player)
	for thief, c in carries do
		if c.victim == victim then
			self:_finish(thief, false)
		end
	end
end

function StealService:Drop(thief: Player, bonker: Player?)
	local c = carries[thief]
	if not c then
		return
	end
	self:_finish(thief, false)
	if bonker then
		self.S.SocialService:NotifyAll("💥 " .. bonker.DisplayName .. " bonked the thief " .. thief.DisplayName .. "!", Color3.fromRGB(120, 200, 255))
	end
end

-- Бита для защиты
function StealService:_giveBonk(player: Player)
	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack or backpack:FindFirstChild("Bonk Bat") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "Bonk Bat"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	-- 🏏 Деревянная бита с розовой обмоткой и слаймом на конце (ось биты = X рукоятки)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(1.8, 0.36, 0.36)
	handle.Color = Color3.fromRGB(70, 40, 30)
	handle.Material = Enum.Material.Fabric
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local WOOD = Color3.fromRGB(226, 172, 105)
	local PINK = Color3.fromRGB(255, 90, 190)
	local GOO = Color3.fromRGB(120, 255, 140)
	local function piece(shape, size: Vector3, offset: CFrame, color: Color3, mat, props)
		local p = Instance.new("Part")
		p.Shape = shape
		p.Size = size
		p.Color = color
		p.Material = mat
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
		for k, v in props or {} do
			p[k] = v
		end
		local w = Instance.new("Weld")
		w.Part0 = handle
		w.Part1 = p
		w.C0 = offset
		w.Parent = p
		p.Parent = tool
		return p
	end
	local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
	piece(CYL, Vector3.new(0.2, 0.62, 0.62), CFrame.new(-0.98, 0, 0), Color3.fromRGB(50, 28, 20), Enum.Material.Wood) -- набалдашник
	for _, x in { -0.55, -0.1, 0.35 } do
		piece(CYL, Vector3.new(0.12, 0.41, 0.41), CFrame.new(x, 0, 0), PINK, Enum.Material.SmoothPlastic) -- обмотка
	end
	piece(CYL, Vector3.new(1.0, 0.56, 0.56), CFrame.new(1.35, 0, 0), WOOD, Enum.Material.Wood) -- сужение
	piece(CYL, Vector3.new(2.3, 0.86, 0.86), CFrame.new(2.95, 0, 0), WOOD, Enum.Material.Wood) -- бочка
	piece(BALL, Vector3.new(0.86, 0.86, 0.86), CFrame.new(4.1, 0, 0), WOOD, Enum.Material.Wood) -- скруглённый конец
	piece(CYL, Vector3.new(0.16, 0.9, 0.9), CFrame.new(2.1, 0, 0), PINK, Enum.Material.Neon) -- неоновое кольцо
	-- слайм, налипший на конец, и капли
	piece(BALL, Vector3.new(1.05, 1.05, 1.05), CFrame.new(4.15, 0.08, 0), GOO, Enum.Material.SmoothPlastic, { Transparency = 0.15, Reflectance = 0.1 })
	piece(BALL, Vector3.new(0.42, 0.42, 0.42), CFrame.new(3.55, 0.4, 0.12), GOO, Enum.Material.SmoothPlastic, { Transparency = 0.15 })
	piece(BALL, Vector3.new(0.3, 0.3, 0.3), CFrame.new(3.15, 0.1, 0.42), GOO, Enum.Material.SmoothPlastic, { Transparency = 0.15 })
	piece(BALL, Vector3.new(0.24, 0.24, 0.24), CFrame.new(3.6, -0.43, -0.1), GOO, Enum.Material.SmoothPlastic, { Transparency = 0.15 })
	-- рука держит у набалдашника, бита смотрит вверх
	tool.Grip = CFrame.new(-0.45, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
	tool.ToolTip = "BONK thieves!"
	tool.Activated:Connect(function()
		-- взмах: стандартный Animate проигрывает анимацию удара по toolanim = "Slash"
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
		game:GetService("Debris"):AddItem(anim, 1)
		self:Bonk(player, false)
	end)
	tool.Parent = backpack
end

function StealService:Bonk(player: Player, mega: boolean?)
	local now = os.clock()
	if now - (lastBonk[player] or 0) < Config.BonkCooldown then
		return
	end
	lastBonk[player] = now
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local range = if mega then Config.BonkRange * 1.8 else Config.BonkRange
	-- бандиты из событий мира
	for _, npc in CollectionService:GetTagged("Bandit") do
		local nRoot = npc:FindFirstChild("HumanoidRootPart")
		if nRoot then
			local offset = nRoot.Position - root.Position
			if offset.Magnitude <= range + 1 and offset.Unit:Dot(root.CFrame.LookVector) > 0 then
				self.S.WorldEventService:BanditBonked(player, npc)
			end
		end
	end
	for _, run in CollectionService:GetTagged("Runaway") do
		if run:IsA("Model") then
			local off = (run:GetPivot().Position - root.Position) * Vector3.new(1, 0, 1)
			if off.Magnitude <= range + 4 then
				self.S.WorldEventService:RunawayHit(player, run)
			end
		end
	end
	for _, boss in CollectionService:GetTagged("Boss") do
		local bRoot = boss.PrimaryPart
		if bRoot then
			local off = (bRoot.Position - root.Position) * Vector3.new(1, 0, 1)
			if off.Magnitude <= range + bRoot.Size.X * 0.5 then
				self.S.WorldEventService:BossHit(player, boss)
			end
		end
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local oChar = other.Character
			local oRoot = oChar and oChar:FindFirstChild("HumanoidRootPart")
			local oHum = oChar and oChar:FindFirstChildOfClass("Humanoid")
			if oRoot and oHum then
				local offset = oRoot.Position - root.Position
				local inFront = offset.Unit:Dot(root.CFrame.LookVector) > 0.2
				if offset.Magnitude <= range and inFront then
					if carries[other] then
						self:Drop(other, player)
						self.S.QuestService:Add(player, "Bonk", 1)
						self.S.DataService:Stat(player, "Bonks")
					end
					oHum.Sit = true
					if mega then
						oRoot.AssemblyLinearVelocity = offset.Unit * 60 + Vector3.new(0, 30, 0)
					end
					self.S.SocialService:PlaySound(other, "Bonk")
				end
			end
		end
	end
end

function StealService:Start()
	local function setup(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			self:_giveBonk(player)
		end)
		if player.Character then
			task.spawn(self._giveBonk, self, player)
		end
	end
	Players.PlayerAdded:Connect(setup)
	for _, p in Players:GetPlayers() do
		setup(p)
	end

	Players.PlayerRemoving:Connect(function(player)
		if carries[player] then
			self:_finish(player, false)
		end
		self:CancelForVictim(player)
		lastBonk[player] = nil
	end)

	RunService.Heartbeat:Connect(function()
		for thief, c in carries do
			local char = thief.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not root or not hum or hum.Health <= 0 or not c.model.Parent then
				self:_finish(thief, false)
			elseif os.clock() - c.started > Config.StealTimeout then
				self.S.SocialService:Notify(thief, "Too slow — the slime ran home!", Color3.fromRGB(255, 120, 120))
				self:_finish(thief, false)
			else
				local plot = self.S.PlotService:GetPlot(thief)
				if plot and self.S.MapBuilder:IsInPlot(plot, root.Position) then
					self:_finish(thief, true)
				end
			end
		end
	end)
end

return StealService
