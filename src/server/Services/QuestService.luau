--!nonstrict
-- Ежедневные квесты: 3 задания в день (по UTC), награда = доход за N минут.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local QuestService = {}

function QuestService:Init(S)
	self.S = S
end

local function today(): number
	return os.time() // 86400
end

function QuestService:_ensure(data)
	if data.Quests and data.Quests.Day == today() then
		return
	end
	local rng = Random.new(today() * 7 + math.random(1, 1000))
	local pool = table.clone(Config.Quests)
	local list = {}
	for _ = 1, 3 do
		local q = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(list, {
			Kind = q.Kind,
			Goal = rng:NextInteger(q.Min, q.Max),
			Prog = 0,
			Claimed = false,
		})
	end
	data.Quests = { Day = today(), List = list }
end

function QuestService:Reward(player: Player): number
	return math.floor(math.max(Config.QuestRewardMin, self.S.EconomyService:GetIncome(player) * 60 * Config.QuestRewardMinutes))
end

function QuestService:Rewards(player: Player)
	local r = self:Reward(player)
	return { r, r, r }
end

function QuestService:Add(player: Player, kind: string, n: number)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	self:_ensure(data)
	local changed = false
	for _, q in data.Quests.List do
		if q.Kind == kind and q.Prog < q.Goal then
			q.Prog = math.min(q.Goal, q.Prog + n)
			changed = true
			if q.Prog >= q.Goal then
				self.S.SocialService:Notify(player, "✅ Quest complete! Open 📜 Quests to claim your reward", Color3.fromRGB(140, 255, 160))
			end
		end
	end
	if changed then
		self.S.IndexService:SendMeta(player)
	end
end

function QuestService:Claim(player: Player, idx: number)
	local data = self.S.DataService:Get(player)
	if not data or type(idx) ~= "number" then
		return
	end
	self:_ensure(data)
	local q = data.Quests.List[idx]
	if not q or q.Claimed or q.Prog < q.Goal then
		return
	end
	q.Claimed = true
	local reward = self:Reward(player)
	self.S.EconomyService:AddCash(player, reward)
	self.S.SocialService:Notify(player, "🎉 Quest reward: +" .. Format.money(reward), Color3.fromRGB(255, 230, 90), "Buy")
	self.S.IndexService:SendMeta(player)
end

function QuestService:Start()
	self.S.DataService:OnLoaded(function(_player, data)
		self:_ensure(data)
	end)
	-- новый день → новые квесты у всех онлайн
	while true do
		task.wait(60)
		for player, data in self.S.DataService.Profiles do
			local before = data.Quests and data.Quests.Day
			self:_ensure(data)
			if before ~= data.Quests.Day then
				self.S.SocialService:Notify(player, "📜 New daily quests are available!", Color3.fromRGB(200, 200, 255))
				self.S.IndexService:SendMeta(player)
			end
		end
	end
end

return QuestService
