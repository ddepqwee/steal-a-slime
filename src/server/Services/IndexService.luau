--!nonstrict
-- Slime Index: коллекция открытых слаймов. За каждые 10% коллекции +5% дохода навсегда.
-- Также отправляет клиенту «мета-состояние» (индекс, квесты, снаряжение) через Remote "Meta".
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Net = require(ReplicatedStorage.Shared.Net)

local IndexService = {}
local MetaRemote

function IndexService:Init(S)
	self.S = S
	MetaRemote = Net.event("Meta")
end

function IndexService:Count(data): number
	local n = 0
	for id in data.Index or {} do
		if Pets.ById[id] then
			n += 1
		end
	end
	return n
end

function IndexService:Bonus(data): number
	if not data then
		return 0
	end
	local pct = self:Count(data) / #Pets.List * 100
	return math.floor(pct / Config.Index.StepPercent) * Config.Index.BonusPerStep
end

function IndexService:Discover(player: Player, id: string)
	local data = self.S.DataService:Get(player)
	if not data or not Pets.ById[id] then
		return
	end
	data.Index = data.Index or {}
	if data.Index[id] then
		return
	end
	local before = self:Bonus(data)
	data.Index[id] = true
	self.S.AchievementService:Check(player)
	local def = Pets.ById[id]
	self.S.SocialService:Notify(player, ("📖 New slime discovered: %s! (%d/%d)"):format(def.Name, self:Count(data), #Pets.List), Color3.fromRGB(180, 220, 255))
	if self:Bonus(data) > before then
		self.S.SocialService:Notify(player, ("📖 Index bonus is now +%d%% cash!"):format(math.floor(self:Bonus(data) * 100 + 0.5)), Color3.fromRGB(120, 255, 160))
		self.S.EconomyService:Refresh(player)
	end
	self:SendMeta(player)
end

function IndexService:SendMeta(player: Player)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	local index = {}
	for id in data.Index or {} do
		table.insert(index, id)
	end
	local gear = {}
	for id in data.Gear or {} do
		table.insert(gear, id)
	end
	MetaRemote:FireClient(player, {
		Index = index,
		Total = #Pets.List,
		Bonus = self:Bonus(data),
		Quests = data.Quests and data.Quests.List or {},
		QuestRewards = self.S.QuestService:Rewards(player),
		Gear = gear,
		Tokens = data.Tokens or 0,
		Perks = data.Perks or {},
		Ach = self.S.AchievementService:List(player),
	})
end

function IndexService:Start()
	self.S.DataService:OnLoaded(function(player, data)
		data.Index = data.Index or {}
		-- всё, что уже стоит на базе, считается открытым
		for _, entry in data.Pets do
			data.Index[entry.Id] = true
		end
		task.delay(1, function()
			if player.Parent then
				self:SendMeta(player)
			end
		end)
	end)
end

return IndexService
