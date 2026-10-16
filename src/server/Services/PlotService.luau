--!nonstrict
-- Базы игроков: выдача базы, слоты, отрисовка слаймов, продажа, замок.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Format = require(ReplicatedStorage.Shared.Format)

local PlotService = {}
local plotOf = {} :: { [Player]: any }
local models = {} :: { [any]: { [string]: Model } } -- plot -> slot -> model

function PlotService:Init(S)
	self.S = S
	self.Plots = S.MapBuilder.Plots
end

function PlotService:GetPlot(player: Player)
	return plotOf[player]
end

function PlotService:MaxSlots(player: Player): number
	local data = self.S.DataService:Get(player)
	local n = Config.BaseSlots + (if data then data.ExtraSlots or 0 else 0)
	if self.S.MonetizationService:HasPass(player, "ExtraSlots") then
		n += Config.ExtraSlotsFromPass
	end
	local plot = plotOf[player]
	return if plot then math.min(n, #plot.Pedestals) else n
end

function PlotService:UsedSlots(player: Player): number
	local data = self.S.DataService:Get(player)
	local n = 0
	if data then
		for _ in data.Pets do
			n += 1
		end
	end
	return n
end

function PlotService:FreeSlot(player: Player): string?
	local data = self.S.DataService:Get(player)
	if not data then
		return nil
	end
	for i = 1, self:MaxSlots(player) do
		local k = tostring(i)
		if data.Pets[k] == nil then
			return k
		end
	end
	return nil
end

function PlotService:IsLocked(plot): boolean
	return (plot.LockedUntil or 0) > os.clock()
end

-- Подсветка пьедестала по редкости стоящего на нём слайма
function PlotService:_stylePed(plot, slot: string, entry)
	local fx = plot.PedFx and plot.PedFx[tonumber(slot)]
	if not fx then
		return
	end
	local ped = plot.Pedestals[tonumber(slot)]
	local accent = ped and ped:GetAttribute("Accent") or Color3.new(1, 1, 1)
	if not entry then
		fx.Ring.Color = accent
		fx.Ring.Transparency = 0.3
		fx.Rim.Transparency = 0.85
		fx.Beam.Transparency = 1
		fx.Light.Range = 0
		return
	end
	local def = Pets.ById[entry.Id]
	local r = def and Config.Rarities[def.Rarity]
	local v = entry.V and Config.Variants[entry.V]
	local col = if v then v.Color else (r and r.Color or accent)
	local rarity = def and def.Rarity or 1
	fx.Ring.Color = col
	fx.Ring.Transparency = 0
	fx.Rim.Color = col
	fx.Rim.Transparency = 0.15
	fx.Light.Color = col
	fx.Light.Range = 6 + rarity * 1.5
	fx.Beam.Color = col
	fx.Beam.Transparency = if rarity >= 5 or entry.M then 0.82 - math.min(rarity - 5, 3) * 0.03 else 1
end

function PlotService:_clearSlot(plot, slot: string)
	local m = models[plot] and models[plot][slot]
	if m then
		m:Destroy()
		models[plot][slot] = nil
	end
end

function PlotService:RenderSlot(player: Player, slot: string)
	local plot = plotOf[player]
	local data = self.S.DataService:Get(player)
	if not plot or not data then
		return
	end
	self:_clearSlot(plot, slot)
	local entry = data.Pets[slot]
	local ped = plot.Pedestals[tonumber(slot)]
	self:_stylePed(plot, slot, entry)
	if not entry or not ped then
		return
	end
	local model = self.S.PetFactory:Build(entry, { Scale = 1.3 * (1 + ((entry.L or 1) - 1) * Config.Upgrade.SizePerLevel) })
	local size = model.PrimaryPart.Size
	model:PivotTo(CFrame.new(ped.Position + Vector3.new(0, ped.Size.X / 2 + size.Y * 0.6, 0)) * plot.CFrame.Rotation)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Slot", slot)

	local value = self.S.EconomyService:PetValue(entry)
	local steal = Instance.new("ProximityPrompt")
	steal.Name = "StealPrompt"
	steal.ActionText = "Steal"
	steal.ObjectText = model.Name
	steal.HoldDuration = Config.StealHold
	steal.MaxActivationDistance = 9
	steal.RequiresLineOfSight = false
	steal.KeyboardKeyCode = Enum.KeyCode.E
	steal:SetAttribute("OwnerUserId", player.UserId)
	steal.Parent = model.PrimaryPart
	steal.Triggered:Connect(function(thief)
		self.S.StealService:TrySteal(thief, player, slot)
	end)

	local sell = Instance.new("ProximityPrompt")
	sell.Name = "SellPrompt"
	sell.ActionText = "Sell " .. Format.money(value * Config.SellRate)
	sell.ObjectText = model.Name
	sell.HoldDuration = 0.8
	sell.MaxActivationDistance = 9
	sell.RequiresLineOfSight = false
	sell.KeyboardKeyCode = Enum.KeyCode.F
	sell.UIOffset = Vector2.new(0, 70)
	sell:SetAttribute("OwnerUserId", player.UserId)
	sell.Parent = model.PrimaryPart
	sell.Triggered:Connect(function(who)
		if who == player then
			self:Sell(player, slot)
		end
	end)

	local cost = self.S.EconomyService:UpgradeCost(entry)
	local up = Instance.new("ProximityPrompt")
	up.Name = "UpgradePrompt"
	up.ActionText = if cost then "Upgrade " .. Format.money(cost) else "MAX LEVEL"
	up.ObjectText = model.Name .. " Lv." .. (entry.L or 1)
	up.HoldDuration = 0
	up.MaxActivationDistance = 9
	up.RequiresLineOfSight = false
	up.KeyboardKeyCode = Enum.KeyCode.E
	up:SetAttribute("OwnerUserId", player.UserId)
	up.Enabled = cost ~= nil
	up.Parent = model.PrimaryPart
	up.Triggered:Connect(function(who)
		if who == player then
			self.S.ProgressionService:UpgradePet(player, slot)
		end
	end)

	local mutCost = self.S.ProgressionService:MutateCost(entry)
	local mut = Instance.new("ProximityPrompt")
	mut.Name = "MutatePrompt"
	mut.ActionText = "Mutate " .. Format.money(mutCost)
	mut.ObjectText = "🧬 Gold 50% · Diamond 30% · Rainbow 15% · Galaxy 5%"
	mut.HoldDuration = 0.6
	mut.MaxActivationDistance = 9
	mut.RequiresLineOfSight = false
	mut.KeyboardKeyCode = Enum.KeyCode.R
	mut.UIOffset = Vector2.new(0, 140)
	mut:SetAttribute("OwnerUserId", player.UserId)
	mut.Parent = model.PrimaryPart
	mut.Triggered:Connect(function(who)
		if who == player then
			self.S.ProgressionService:Mutate(player, slot)
		end
	end)

	model.Parent = plot.Model
	models[plot] = models[plot] or {}
	models[plot][slot] = model
end

function PlotService:RenderAll(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	for i = 1, #plot.Pedestals do
		self:RenderSlot(player, tostring(i))
	end
	self:RefreshSlots(player)
end

-- Подсветка пьедесталов: доступные / закрытые пассом
function PlotService:RefreshSlots(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	local max = self:MaxSlots(player)
	for i, ped in plot.Pedestals do
		if self.S.ShowcaseService:Enabled() then
			max = #plot.Pedestals
		end
		ped.Transparency = if i <= max then 0 else 0.6
		ped.Color = if i <= max then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(255, 215, 90)
	end
end

function PlotService:GetSlotModel(player: Player, slot: string): Model?
	local plot = plotOf[player]
	return plot and models[plot] and models[plot][slot]
end

function PlotService:AddPet(player: Player, entry): string?
	local data = self.S.DataService:Get(player)
	local slot = self:FreeSlot(player)
	if not data or not slot then
		return nil
	end
	data.Pets[slot] = { Id = entry.Id, V = entry.V, L = entry.L, M = entry.M }
	self.S.IndexService:Discover(player, entry.Id)
	self.S.EconomyService:Refresh(player)
	return slot
end

function PlotService:RemovePet(player: Player, slot: string)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	data.Pets[slot] = nil
	local plot = plotOf[player]
	if plot then
		self:_clearSlot(plot, slot)
		self:_stylePed(plot, slot, nil)
	end
	self.S.EconomyService:Refresh(player)
end

function PlotService:Sell(player: Player, slot: string)
	local data = self.S.DataService:Get(player)
	local entry = data and data.Pets[slot]
	if not entry or self.S.StealService:IsCarried(player, slot) then
		return
	end
	local amount = math.floor(self.S.EconomyService:PetValue(entry) * Config.SellRate)
	self:RemovePet(player, slot)
	self.S.EconomyService:AddCash(player, amount)
	self.S.SocialService:Notify(player, "Sold for " .. Format.money(amount), Color3.fromRGB(255, 230, 90))
end

function PlotService:ClearAll(player: Player)
	local plot = plotOf[player]
	if plot and models[plot] then
		for slot in models[plot] do
			self:_clearSlot(plot, slot)
		end
	end
	if plot then
		for i = 1, #plot.Pedestals do
			self:_stylePed(plot, tostring(i), nil)
		end
	end
end

function PlotService:Lock(player: Player)
	local plot = plotOf[player]
	if not plot or self:IsLocked(plot) then
		return
	end
	if os.clock() < (plot.LockReadyAt or 0) then
		return
	end
	local data = self.S.DataService:Get(player)
	local lockLvl = math.clamp((data and data.LockLevel or 0) + 1, 1, #Config.LockUpgrade.Durations)
	local duration = Config.LockUpgrade.Durations[lockLvl]
	if self.S.MonetizationService:HasPass(player, "LongLock") then
		duration *= 2
	end
	plot.LockedUntil = os.clock() + duration
	plot.LockReadyAt = plot.LockedUntil + Config.LockCooldown
	self:_setWalls(plot, true)
	-- Выталкиваем чужих игроков из закрытой базы к входу
	for _, other in Players:GetPlayers() do
		local root = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and self.S.MapBuilder:IsInPlot(plot, root.Position) then
			other.Character:PivotTo(plot.CFrame * CFrame.new(0, 4, -plot.Half - 8))
			self.S.SocialService:Notify(other, "The owner locked the base — you got kicked out! 🚪", Color3.fromRGB(255, 160, 120))
		end
	end
	self.S.SocialService:Notify(player, "🔒 Base locked for " .. duration .. "s", Color3.fromRGB(255, 120, 140))
end

function PlotService:RefreshTrap(player: Player)
	local plot = plotOf[player]
	local data = self.S.DataService:Get(player)
	if not plot or not data then
		return
	end
	local on = (data.TrapLevel or 0) > 0
	plot.TrapPad.Transparency = if on then 0.75 else 1
	plot.TrapPad.CanTouch = on
end

function PlotService:_trapHit(plot, hit: BasePart)
	local owner = plot.Owner
	local victim = Players:GetPlayerFromCharacter(hit.Parent)
	if not owner or not victim or victim == owner or victim:GetAttribute("Invisible") or victim:GetAttribute("Stunned") then
		return
	end
	local data = self.S.DataService:Get(owner)
	local lvl = data and data.TrapLevel or 0
	if lvl <= 0 or os.clock() < (plot.TrapReady or 0) then
		return
	end
	plot.TrapReady = os.clock() + Config.Trap.Cooldown
	local stun = Config.Trap.Stun[math.min(lvl, #Config.Trap.Stun)]
	local hum = victim.Character and victim.Character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	victim:SetAttribute("Stunned", true)
	self.S.ProgressionService:ApplySpeed(victim)
	hum.JumpHeight = 0
	plot.TrapPad.Transparency = 0.2
	self.S.SocialService:Notify(victim, "🪤 You stepped on a trap! Stunned for " .. stun .. "s", Color3.fromRGB(200, 120, 255))
	self.S.SocialService:Notify(owner, "🪤 Your trap caught " .. victim.DisplayName .. "!", Color3.fromRGB(200, 120, 255))
	task.delay(stun, function()
		victim:SetAttribute("Stunned", false)
		if hum.Parent then
			hum.JumpHeight = 7.2
		end
		if victim.Parent then
			self.S.ProgressionService:ApplySpeed(victim)
		end
		if plot.Owner then
			plot.TrapPad.Transparency = 0.75
		end
	end)
end

function PlotService:_setWalls(plot, on: boolean)
	for _, w in plot.LockWalls do
		w.CanCollide = on
		w.Transparency = if on then 0.35 else 1
	end
	plot.Model:SetAttribute("Locked", on)
end

function PlotService:_setSign(plot, text: string)
	for _, l in plot.SignLabels do
		l.Text = text
	end
end

function PlotService:_tickLocks()
	for _, plot in self.Plots do
		local owner = plot.Owner
		if self:IsLocked(plot) then
			plot.LockLabel.Text = "🔒 " .. Format.time(plot.LockedUntil - os.clock())
		else
			if plot.Model:GetAttribute("Locked") then
				self:_setWalls(plot, false)
				if owner then
					self.S.SocialService:Notify(owner, "⚠️ Your base lock is off!", Color3.fromRGB(255, 180, 80))
				end
			end
			local cd = (plot.LockReadyAt or 0) - os.clock()
			plot.LockLabel.Text = if cd > 0 then "⏳ " .. math.ceil(cd) else "🔒 LOCK"
		end
	end
end

function PlotService:_assign(player: Player)
	for _, plot in self.Plots do
		if not plot.Owner then
			plot.Owner = player
			plotOf[player] = plot
			plot.Model:SetAttribute("OwnerUserId", player.UserId)
			self:_setSign(plot, player.DisplayName .. "'s Base")
			return plot
		end
	end
	return nil
end

function PlotService:_release(player: Player)
	local plot = plotOf[player]
	if not plot then
		return
	end
	self:ClearAll(player)
	plot.Owner = nil
	plot.LockedUntil = 0
	plot.LockReadyAt = 0
	self:_setWalls(plot, false)
	plot.TrapPad.Transparency = 1
	plot.TrapPad.CanTouch = false
	plot.Model:SetAttribute("OwnerUserId", nil)
	self:_setSign(plot, "Free Base")
	plotOf[player] = nil
end

function PlotService:Start()
	-- Касание кнопки замка и ловушки
	for _, plot in self.Plots do
		plot.TrapPad.Touched:Connect(function(hit)
			self:_trapHit(plot, hit)
		end)
		plot.LockPad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player and plot.Owner == player then
				self:Lock(player)
			end
		end)
	end

	self.S.DataService:OnLoaded(function(player)
		local plot = self:_assign(player)
		if not plot then
			player:Kick("Server is full, try another one 🙏")
			return
		end
		self:RenderAll(player)
		self:RefreshTrap(player)
		local function onChar(char)
			local root = char:WaitForChild("HumanoidRootPart", 10)
			if root and plotOf[player] then
				task.wait(0.1)
				char:PivotTo(plotOf[player].SpawnCFrame)
			end
		end
		player.CharacterAdded:Connect(onChar)
		if player.Character then
			task.spawn(onChar, player.Character)
		end
	end)
	self.S.DataService:OnLeaving(function(player)
		self:_release(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_release(player)
	end)

	while true do
		self:_tickLocks()
		task.wait(0.5)
	end
end

return PlotService
