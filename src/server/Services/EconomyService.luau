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
	local lvl = math.clamp(entry.L or 1, 1, Config.Upgrade.MaxLevel)
	return def.Income * (if v then v.Mult else 1) * Config.Upgrade.IncomeMult ^ (lvl - 1) * (if entry.M then Config.Fuse.MegaMult else 1)
end

-- Цена следующего уровня (или nil на максимуме)
function EconomyService:UpgradeCost(entry): number?
	local def = Pets.ById[entry.Id]
	local lvl = entry.L or 1
	if not def or lvl >= Config.Upgrade.MaxLevel then
		return nil
	end
	local v = entry.V and Config.Variants[entry.V]
	return math.floor(def.Price * (if v then v.Mult else 1) * Config.Upgrade.CostBase * Config.Upgrade.CostMult ^ (lvl - 1) * (if entry.M then Config.Fuse.MegaMult else 1))
end

function EconomyService:PetValue(entry): number
	local def = Pets.ById[entry.Id]
	if not def then
		return 0
	end
	local v = entry.V and Config.Variants[entry.V]
	local lvl = math.clamp(entry.L or 1, 1, Config.Upgrade.MaxLevel)
	return def.Price * (if v then v.Mult else 1) * (1 + (lvl - 1) * 0.5) * (if entry.M then Config.Fuse.MegaMult else 1)
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
	mult *= 1 + self.S.IndexService:Bonus(data)
	mult *= 1 + 0.1 * ((data.Perks and data.Perks.Income) or 0)
	if (data.CashPotionUntil or 0) > os.time() then
		mult *= 2
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
		local st = ls:FindFirstChild("Steals")
		if st then
			st.Value = data.Steals or 0
		end
	end
end

function EconomyService:_fusable(data)
	local counts = {}
	for _, e in data.Pets do
		if not e.M then
			counts[e.Id] = (counts[e.Id] or 0) + 1
		end
	end
	local list = {}
	for id, n in counts do
		table.insert(list, { Id = id, Count = n })
	end
	table.sort(list, function(a, b)
		return a.Count > b.Count
	end)
	return list
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
		SlotCost = P:SlotCost(data) or -1,
		LockLevel = data.LockLevel or 0,
		TrapLevel = data.TrapLevel or 0,
		Buddy = data.Buddy ~= false,
		TrapCost = P:TrapCost(data) or -1,
		LockCost = P:LockUpgradeCost(data) or -1,
		Fusable = self:_fusable(data),
		Rewards = self.S.RewardService:StateFor(player, data),
		SlotsBought = data.ExtraSlots or 0,
		SlotsBuyMax = Config.SlotUpgrade.Max,
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
		local st = Instance.new("IntValue")
		st.Name = "Steals"
		st.Value = data.Steals or 0
		st.Parent = ls
		ls.Parent = player

		self:Refresh(player)

		-- Офлайн-доход
		if data.LastOnline > 0 then
			local away = math.clamp(os.time() - data.LastOnline, 0, Config.OfflineMaxSeconds)
			local offPerk = (data.Perks and data.Perks.Offline) or 0
			local earned = math.floor(self:GetIncome(player) * away * Config.OfflineRate * (1 + 0.1 * offPerk))
			if earned > 0 then
				self:AddCash(player, earned)
				task.delay(3, function()
					self.S.SocialService:Notify(player, "While you were away, your slimes earned " .. Format.money(earned) .. " 💤", Color3.fromRGB(150, 220, 255))
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
