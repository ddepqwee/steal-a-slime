--!nonstrict
-- Базы игроков: выдача базы, слоты, отрисовка слаймов, продажа, замок.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
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
	local n = Config.BaseSlots
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
	if not entry or not ped then
		return
	end
	local model = self.S.PetFactory:Build(entry, { Scale = 1.3 })
	local size = model.PrimaryPart.Size
	model:PivotTo(CFrame.new(ped.Position + Vector3.new(0, ped.Size.X / 2 + size.Y * 0.6, 0)) * plot.CFrame.Rotation)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Slot", slot)

	local value = self.S.EconomyService:PetValue(entry)
	local steal = Instance.new("ProximityPrompt")
	steal.Name = "StealPrompt"
	steal.ActionText = "Украсть"
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
	sell.ActionText = "Продать " .. Format.money(value * Config.SellRate)
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
	data.Pets[slot] = { Id = entry.Id, V = entry.V }
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
	self.S.SocialService:Notify(player, "Продано за " .. Format.money(amount), Color3.fromRGB(255, 230, 90))
end

function PlotService:ClearAll(player: Player)
	local plot = plotOf[player]
	if plot and models[plot] then
		for slot in models[plot] do
			self:_clearSlot(plot, slot)
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
	local duration = Config.LockDuration
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
			self.S.SocialService:Notify(other, "Хозяин закрыл базу — тебя выкинуло! 🚪", Color3.fromRGB(255, 160, 120))
		end
	end
	self.S.SocialService:Notify(player, "🔒 База закрыта на " .. duration .. " сек", Color3.fromRGB(255, 120, 140))
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
					self.S.SocialService:Notify(owner, "⚠️ Замок базы открылся!", Color3.fromRGB(255, 180, 80))
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
	plot.Model:SetAttribute("OwnerUserId", nil)
	self:_setSign(plot, "Свободная база")
	plotOf[player] = nil
end

function PlotService:Start()
	-- Касание кнопки замка
	for _, plot in self.Plots do
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
			player:Kick("Сервер заполнен, попробуй другой 🙏")
			return
		end
		self:RenderAll(player)
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
