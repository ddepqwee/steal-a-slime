--!nonstrict
-- Сохранения игроков: сессионный лок (защита от дюпа между серверами),
-- ретраи, автосейв, сохранение при выключении сервера.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}
DataService.Profiles = {} :: { [Player]: { [string]: any } }

local LOCK_TIMEOUT = 150
local AUTOSAVE = 90

local store
local loadedCallbacks = {}
local leavingCallbacks = {}

local function template()
	return {
		Cash = Config.StartCash,
		Rebirths = 0,
		SpeedLevel = 0,
		Pets = { ["1"] = { Id = "Blobby" } }, -- стартовый слайм; [slot] = { Id, V? }
		TotalEarned = 0,
		Steals = 0,
		LastDaily = 0,
		DailyStreak = 0,
		Receipts = {},
		LastOnline = 0,
		FirstJoin = os.time(),
		Index = { Blobby = true },
		Gear = {},
		ExtraSlots = 0,
		LockLevel = 0,
		LastSpin = 0,
		TrapLevel = 0,
		Tokens = 0,
		Perks = {},
		Stats = {},
		Ach = {},
		Codes = {},
		Buddy = true,
		CashPotionUntil = 0,
		Quests = nil,
	}
end

local function reconcile(data)
	for k, v in template() do
		if data[k] == nil then
			data[k] = v
		end
	end
	return data
end

function DataService:Init(S)
	self.S = S
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStore unavailable (enable API Services in Studio):", result)
	end
end

function DataService:Get(player: Player)
	return self.Profiles[player]
end

function DataService:OnLoaded(cb)
	table.insert(loadedCallbacks, cb)
	for player, data in self.Profiles do
		task.spawn(cb, player, data)
	end
end

-- Счётчики для достижений
function DataService:Stat(player: Player, key: string, n: number?)
	local data = self.Profiles[player]
	if not data then
		return
	end
	data.Stats = data.Stats or {}
	data.Stats[key] = (data.Stats[key] or 0) + (n or 1)
	if self.S.AchievementService then
		self.S.AchievementService:Check(player)
	end
end

function DataService:OnLeaving(cb)
	table.insert(leavingCallbacks, cb)
end

local function key(player: Player)
	return "u_" .. player.UserId
end

function DataService:_load(player: Player)
	if not store then
		return reconcile({})
	end
	for attempt = 1, 5 do
		local result
		local ok, err = pcall(function()
			store:UpdateAsync(key(player), function(old)
				old = old or template()
				local lock = old.Lock
				local foreign = lock and lock.Job ~= game.JobId and (os.time() - (lock.Time or 0)) < LOCK_TIMEOUT
				if foreign and attempt < 5 then
					result = "locked"
					return nil
				end
				old.Lock = { Job = game.JobId, Time = os.time() }
				result = old
				return old
			end)
		end)
		if not player.Parent then
			return nil
		end
		if ok and type(result) == "table" then
			return reconcile(result)
		end
		if not ok then
			warn("[Data] load error", player.Name, err)
		end
		task.wait(attempt * 2)
	end
	return nil
end

function DataService:Save(player: Player, release: boolean?)
	local data = self.Profiles[player]
	if not data or not store then
		return false
	end
	data.LastOnline = os.time()
	local ok, err
	for attempt = 1, 3 do
		ok, err = pcall(function()
			store:UpdateAsync(key(player), function(old)
				if old and old.Lock and old.Lock.Job ~= game.JobId then
					-- Данные захватил другой сервер — не перезаписываем
					return nil
				end
				data.Lock = if release then nil else { Job = game.JobId, Time = os.time() }
				return data
			end)
		end)
		if ok then
			break
		end
		task.wait(attempt)
	end
	if not ok then
		warn("[Data] save error", player.Name, err)
	end
	return ok
end

function DataService:_onJoin(player: Player)
	local data = self:_load(player)
	if not player.Parent then
		return
	end
	if not data then
		player:Kick("Could not load your save. Please rejoin in a minute 🙏")
		return
	end
	self.Profiles[player] = data
	for _, cb in loadedCallbacks do
		task.spawn(cb, player, data)
	end
end

function DataService:_onLeave(player: Player)
	if not self.Profiles[player] then
		return
	end
	for _, cb in leavingCallbacks do
		pcall(cb, player)
	end
	self:Save(player, true)
	self.Profiles[player] = nil
end

function DataService:Start()
	Players.PlayerAdded:Connect(function(p)
		self:_onJoin(p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(self._onJoin, self, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		self:_onLeave(p)
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player in self.Profiles do
			pending += 1
			task.spawn(function()
				self:_onLeave(player)
				pending -= 1
			end)
		end
		local t = os.clock()
		while pending > 0 and os.clock() - t < 25 do
			task.wait(0.1)
		end
	end)

	while true do
		task.wait(AUTOSAVE)
		for player in self.Profiles do
			task.spawn(self.Save, self, player, false)
		end
	end
end

return DataService
