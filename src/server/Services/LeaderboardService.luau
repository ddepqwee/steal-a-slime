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

function LeaderboardService:Start()
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
