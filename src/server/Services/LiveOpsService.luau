--!nonstrict
-- Удалённое управление игрой без перепубликации.
-- 1) DataStore "LiveOps"/"live" — читается при старте и раз в 5 минут.
-- 2) MessagingService topic "LiveOps" — мгновенно на все сервера.
-- Формат: { "luck": 2, "cash": 1.5, "gold": 3, "event": "HALLOWEEN", "eventEnds": 1760000000,
--           "announce": "Новый слайм уже в игре!" }
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local LiveOpsService = {}
LiveOpsService.Values = { luck = 1, cash = 1, gold = 1 } :: { [string]: any }

local function sanitizeNumber(v, min, max)
	if type(v) ~= "number" or v ~= v then
		return nil
	end
	return math.clamp(v, min, max)
end

function LiveOpsService:Init(S)
	self.S = S
end

function LiveOpsService:Apply(raw)
	if type(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok then
			return
		end
		raw = decoded
	end
	if type(raw) ~= "table" then
		return
	end
	local v = self.Values
	v.luck = sanitizeNumber(raw.luck, 0.5, 10) or v.luck
	v.cash = sanitizeNumber(raw.cash, 0.5, 10) or v.cash
	v.gold = sanitizeNumber(raw.gold, 0.5, 20) or v.gold
	if type(raw.event) == "string" then
		v.event = string.sub(raw.event, 1, 40)
		v.eventEnds = sanitizeNumber(raw.eventEnds, 0, 4e9) or 0
	end
	if type(raw.announce) == "string" and raw.announce ~= "" and raw.announce ~= v.lastAnnounce then
		v.lastAnnounce = raw.announce
		self.S.SocialService:NotifyAll("📢 " .. string.sub(raw.announce, 1, 120), Color3.fromRGB(255, 255, 255))
	end
end

function LiveOpsService:Start()
	local store
	pcall(function()
		store = DataStoreService:GetDataStore(Config.LiveOpsStore)
	end)

	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(Config.LiveOpsTopic, function(msg)
				self:Apply(msg.Data)
			end)
		end)
	end)

	while true do
		if store then
			local ok, value = pcall(store.GetAsync, store, Config.LiveOpsKey)
			if ok and value then
				self:Apply(value)
			end
		end
		task.wait(300)
	end
end

return LiveOpsService
