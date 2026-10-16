--!nonstrict
-- Глобальный топ по заработку (OrderedDataStore) на доске у конца дороги.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local LeaderboardService = {}
local names = {} :: { [number]: string }

function LeaderboardService:Init(S)
	self.S = S
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok then n else "???"
	return names[userId]
end

-- 🏆 Награды за прошлую неделю: топ-3 — эксклюзивный слайм + титул, топ-10 — деньги
local weekTops = {} :: { [number]: { [number]: number } } -- week -> userId -> rank
local inFlight = {} :: { [Player]: boolean }

function LeaderboardService:_weekTop(week: number)
	if weekTops[week] then
		return weekTops[week]
	end
	local okS, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.Weekly.Store .. week)
	if not okS then
		return nil
	end
	local ok, pages = pcall(store.GetSortedAsync, store, false, Config.Weekly.CashTop)
	if not ok then
		return nil
	end
	local ranks = {}
	for i, item in pages:GetCurrentPage() do
		local uid = tonumber(string.sub(item.key, 3))
		if uid and item.value > 0 then
			ranks[uid] = i
		end
	end
	weekTops[week] = ranks
	return ranks
end

function LeaderboardService:_weeklyReward(player: Player, data)
	local prev = Config.WeekIndex() - 1
	if data.WeeklyRewarded == prev or inFlight[player] then
		return
	end
	inFlight[player] = true
	local top = self:_weekTop(prev)
	inFlight[player] = nil
	if not top or not player.Parent or data.WeeklyRewarded == prev then
		return
	end
	data.WeeklyRewarded = prev
	local rank = top[player.UserId]
	if not rank then
		return
	end
	local R = self.S.RewardService
	if rank <= Config.Weekly.TitleTop then
		data.ChampionWeek = Config.WeekIndex()
		data.ChampionRank = rank
		local text = R:_grant(player, { Kind = "Pet", Id = Config.Weekly.PetId })
		self.S.SocialService:NotifyAll(("🏆 %s finished #%d in last week's race! Reward: %s"):format(player.DisplayName, rank, text), Color3.fromRGB(255, 215, 60), "Legendary")
		self.S.ZoneService:UpdateTitle(player)
	end
	local cash = R:_grant(player, { Kind = "Cash", Minutes = Config.Weekly.CashMinutes })
	self.S.SocialService:Notify(player, ("🏆 You were #%d last week! Bonus %s"):format(rank, cash), Color3.fromRGB(255, 215, 60))
end

function LeaderboardService:Start()
	self.S.DataService:OnLoaded(function(player, data)
		task.delay(6, function()
			if player.Parent then
				self:_weeklyReward(player, data)
			end
		end)
	end)
	task.spawn(function()
		while true do
			local week = Config.WeekIndex()
			local okW, weekly = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.Weekly.Store .. week)
			if okW then
				for player, data in self.S.DataService.Profiles do
					if data.WeekId == week then
						pcall(weekly.SetAsync, weekly, "u_" .. player.UserId, math.clamp(math.floor(data.WeekEarned or 0), 0, 2 ^ 52))
					end
				end
				local okP, pages = pcall(weekly.GetSortedAsync, weekly, false, 10)
				if okP then
					local lines = { "📅 WEEKLY RACE", "resets in " .. Format.time(Config.WeekEnds() - os.time()), "top 3 win 🌟 The Champion" }
					for i, item in pages:GetCurrentPage() do
						local uid = tonumber(string.sub(item.key, 3))
						table.insert(lines, ("%d. %s — %s"):format(i, uid and nameOf(uid) or "?", Format.money(item.value)))
					end
					self.S.MapBuilder.WeeklyLabel.Text = table.concat(lines, "\n")
				end
			end
			-- игроки, у которых награда не дошла (DataStore был недоступен) — пробуем снова
			for player, data in self.S.DataService.Profiles do
				self:_weeklyReward(player, data)
			end
			task.wait(150)
		end
	end)
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.LeaderboardStore)
	if not ok then
		return
	end
	local okS, stealsStore = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.StealsBoardStore)
	while true do
		for player, data in self.S.DataService.Profiles do
			local value = math.clamp(math.floor(data.TotalEarned), 0, 2 ^ 52)
			pcall(store.SetAsync, store, "u_" .. player.UserId, value)
			if okS then
				pcall(stealsStore.SetAsync, stealsStore, "u_" .. player.UserId, data.Steals or 0)
			end
		end
		if okS then
			local okP, sp = pcall(stealsStore.GetSortedAsync, stealsStore, false, 10)
			if okP then
				local lines = { "🦹 TOP THIEVES" }
				for i, item in sp:GetCurrentPage() do
					local uid = tonumber(string.sub(item.key, 3))
					table.insert(lines, ("%d. %s — %d steals"):format(i, uid and nameOf(uid) or "?", item.value))
				end
				self.S.MapBuilder.StealsLabel.Text = table.concat(lines, "\n")
			end
		end
		local okPage, pages = pcall(store.GetSortedAsync, store, false, 10)
		if okPage then
			local lines = { "🏆 TOP EARNERS" }
			for i, item in pages:GetCurrentPage() do
				local uid = tonumber(string.sub(item.key, 3))
				table.insert(lines, ("%d. %s — %s"):format(i, uid and nameOf(uid) or "?", Format.money(item.value)))
			end
			self.S.MapBuilder.BoardLabel.Text = table.concat(lines, "\n")
		end
		task.wait(120)
	end
end

return LeaderboardService
