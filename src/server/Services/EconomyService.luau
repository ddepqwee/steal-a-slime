--!nonstrict
-- Деньги, доход в секунду, множители, офлайн-доход, синхронизация состояния с клиентом.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)

local EconomyService = {}
local StateRemote = Net.event("State")
local cache = {} :: { [Player]: { base: number, mult: number } }

function EconomyService:Init(S)
	self.S = S
end

function EconomyService:PetIncome(entry): number
	local def = Pets.ById[entry.Id]
	if not def then
		return 0
	end
	local v = entry.V and Config.Variants[entry.V]
	return def.Income * (if v then v.Mult else 1)
end

function EconomyService:PetValue(entry): number
	local def = Pets.ById[entry.Id]
	if not def then
		return 0
	end
	local v = entry.V and Config.Variants[entry.V]
	return def.Price * (if v then v.Mult else 1)
end

function EconomyService:_compute(player: Player)
	local data = self.S.DataService:Get(player)
	if not data then
		return { base = 0, mult = 1 }
	end
	local base = 0
	for _, entry in data.Pets do
		base += self:PetIncome(entry)
	end
	local mult = 1 + data.Rebirths * Config.Rebirth.IncomeBonus
	if self.S.MonetizationService:HasPass(player, "DoubleCash") then
		mult *= 2
	end
	mult *= 1 + (tonumber(player:GetAttribute("FriendBoost")) or 0)
	if player:GetAttribute("InGroup") then
		mult *= 1 + Config.GroupIncomeBonus
	end
	return { base = base, mult = mult }
end

function EconomyService:Refresh(player: Player)
	cache[player] = self:_compute(player)
	self:SendState(player)
end

-- Доход в секунду с учётом всех множителей (без временных ивентов)
function EconomyService:GetIncome(player: Player): number
	local c = cache[player] or self:_compute(player)
	return c.base * c.mult
end

function EconomyService:AddCash(player: Player, amount: number)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	data.Cash += amount
	if amount > 0 then
		data.TotalEarned += amount
	end
	self:_leaderstats(player, data)
end

function EconomyService:TrySpend(player: Player, amount: number): boolean
	local data = self.S.DataService:Get(player)
	if not data or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	self:_leaderstats(player, data)
	return true
end

function EconomyService:_leaderstats(player: Player, data)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Cash.Value = Format.money(data.Cash)
		ls.Rebirths.Value = data.Rebirths
	end
end

function EconomyService:SendState(player: Player)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	local P = self.S.ProgressionService
	local now = os.time()
	StateRemote:FireClient(player, {
		Cash = data.Cash,
		Income = self:GetIncome(player) * self.S.EventService:GetCashMult(),
		Rebirths = data.Rebirths,
		RebirthCost = P:RebirthCost(data),
		RebirthBonus = Config.Rebirth.IncomeBonus,
		SpeedLevel = data.SpeedLevel,
		SpeedCost = P:SpeedCost(data),
		SpeedMax = Config.Speed.MaxLevel,
		Slots = self.S.PlotService:MaxSlots(player),
		UsedSlots = self.S.PlotService:UsedSlots(player),
		DailyIn = math.max(0, (data.LastDaily + Config.DailyCooldown) - now),
		Streak = data.DailyStreak,
		Steals = data.Steals,
	})
end

function EconomyService:Start()
	self.S.DataService:OnLoaded(function(player, data)
		local ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local cash = Instance.new("StringValue")
		cash.Name = "Cash"
		cash.Parent = ls
		local reb = Instance.new("IntValue")
		reb.Name = "Rebirths"
		reb.Parent = ls
		ls.Parent = player

		self:Refresh(player)

		-- Офлайн-доход
		if data.LastOnline > 0 then
			local away = math.clamp(os.time() - data.LastOnline, 0, Config.OfflineMaxSeconds)
			local earned = math.floor(self:GetIncome(player) * away * Config.OfflineRate)
			if earned > 0 then
				self:AddCash(player, earned)
				task.delay(3, function()
					self.S.SocialService:Notify(player, "Пока тебя не было, слаймы заработали " .. Format.money(earned) .. " 💤", Color3.fromRGB(150, 220, 255))
				end)
			end
		end
		self:_leaderstats(player, data)
	end)

	Players.PlayerRemoving:Connect(function(p)
		cache[p] = nil
	end)

	-- Главный тик экономики
	local n = 0
	while true do
		task.wait(1)
		n += 1
		local eventMult = self.S.EventService:GetCashMult()
		for player in self.S.DataService.Profiles do
			local income = self:GetIncome(player) * eventMult
			if income > 0 then
				self:AddCash(player, income)
			end
			self:SendState(player)
		end
		if n % 10 == 0 then
			for player in self.S.DataService.Profiles do
				cache[player] = self:_compute(player)
			end
		end
	end
end

return EconomyService
