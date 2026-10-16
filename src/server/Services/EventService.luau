--!nonstrict
-- Авто-ивенты по расписанию + серверная удача (продукт) + LiveOps-оверрайды.
-- Клиент видит баннер через атрибуты ReplicatedStorage: EventText / EventEnds.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local EventService = {}
local serverLuckUntil = 0

function EventService:Init(S)
	self.S = S
end

-- Возвращает активные расписанные ивенты: { {Name, Ends, Luck?, Gold?, Cash?} }
function EventService:Active()
	local now = os.time()
	local result = {}
	local hourIndex = now // 3600
	local minute = (now % 3600) // 60
	for _, ev in Config.Schedule do
		if hourIndex % ev.EveryHours == 0 and minute >= ev.StartMinute and minute < ev.StartMinute + ev.Duration then
			local ends = hourIndex * 3600 + (ev.StartMinute + ev.Duration) * 60
			table.insert(result, { Name = ev.Name, Ends = ends, Luck = ev.Luck, Gold = ev.Gold, Cash = ev.Cash })
		end
	end
	local season = self:Season()
	if season then
		table.insert(result, { Name = season.Title, Ends = season.End })
		if hourIndex % season.HourEvery == 0 and minute >= season.HourMinute and minute < season.HourMinute + season.HourDuration then
			table.insert(result, { Name = season.HourName .. " x" .. season.HourMult, Ends = hourIndex * 3600 + (season.HourMinute + season.HourDuration) * 60, Season = season.HourMult })
		end
	end
	local live = self.S.LiveOpsService.Values
	if live.event and (live.eventEnds or 0) > now then
		table.insert(result, { Name = live.event, Ends = live.eventEnds })
	end
	if serverLuckUntil > now then
		table.insert(result, { Name = "SERVER LUCK x2", Ends = serverLuckUntil, Luck = 2 })
	end
	if (self.PotionLuckUntil or 0) > now then
		table.insert(result, { Name = "🍀 LUCK POTION x1.5", Ends = self.PotionLuckUntil, Luck = 1.5 })
	end
	return result
end

local function product(field)
	local m = 1
	for _, ev in EventService:Active() do
		if ev[field] then
			m *= ev[field]
		end
	end
	return m
end

function EventService:Season()
	return Config.ActiveSeason()
end

-- Множитель шанса ивентовых слаймов (Spooky Hour)
function EventService:SeasonMult(): number
	return product("Season")
end

function EventService:GetLuck(): number
	return product("Luck") * self.S.LiveOpsService.Values.luck
end

function EventService:GetGoldMult(): number
	return product("Gold") * self.S.LiveOpsService.Values.gold
end

function EventService:GetCashMult(): number
	return product("Cash") * self.S.LiveOpsService.Values.cash
end

function EventService:AddPotionLuck(seconds: number)
	self.PotionLuckUntil = math.max(self.PotionLuckUntil or 0, os.time()) + seconds
end

function EventService:AddServerLuck(seconds: number)
	serverLuckUntil = math.max(serverLuckUntil, os.time()) + seconds
end

function EventService:Start()
	local lastText = nil
	while true do
		local active = self:Active()
		local text, ends = "", 0
		if #active > 0 then
			local names = {}
			for _, ev in active do
				table.insert(names, ev.Name)
				ends = math.max(ends, ev.Ends)
			end
			text = table.concat(names, " + ")
		end
		if text ~= lastText then
			if text ~= "" then
				self.S.SocialService:NotifyAll("⚡ Event: " .. text .. "!", Color3.fromRGB(255, 230, 90))
			end
			lastText = text
		end
		local season = self:Season()
		ReplicatedStorage:SetAttribute("Season", season and season.Name or "")
		ReplicatedStorage:SetAttribute("EventText", text)
		ReplicatedStorage:SetAttribute("EventEnds", ends)
		task.wait(1)
	end
end

return EventService
