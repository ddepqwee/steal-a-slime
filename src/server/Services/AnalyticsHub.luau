--!nonstrict
-- 📊 Аналитика Roblox (Creator Dashboard → Analytics): воронка новичка, ребёрты, покупки, ключевые действия.
-- Всё в pcall — аналитика никогда не должна ломать игру.
local AnalyticsService = game:GetService("AnalyticsService")

local AnalyticsHub = {}

-- Шаги воронки новичка (Onboarding funnel). Логируются один раз на игрока.
AnalyticsHub.Funnel = {
	"Joined",
	"Bought first slime",
	"Upgraded a slime",
	"Stole a slime",
	"Locked base",
	"Tutorial complete",
	"First rebirth",
}

function AnalyticsHub:Init(S)
	self.S = S
end

function AnalyticsHub:Step(player: Player, step: number)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	data.Funnel = data.Funnel or {}
	local key = tostring(step)
	if data.Funnel[key] then
		return
	end
	data.Funnel[key] = true
	pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, step, self.Funnel[step])
end

function AnalyticsHub:Custom(player: Player, name: string, value: number?)
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, name, value or 1)
end

function AnalyticsHub:Rebirth(player: Player, level: number)
	pcall(AnalyticsService.LogProgressionCompleteEvent, AnalyticsService, player, "Rebirth", level, "Rebirth " .. level)
	if level == 1 then
		self:Step(player, 7)
	end
end

-- Траты игровой валюты (sink) — для экономики в дашборде
function AnalyticsHub:Spend(player: Player, amount: number, sku: string)
	local data = self.S.DataService:Get(player)
	pcall(AnalyticsService.LogEconomyEvent, AnalyticsService, player, Enum.AnalyticsEconomyFlowType.Sink, "Cash", amount, data and data.Cash or 0, Enum.AnalyticsEconomyTransactionType.Shop.Name, sku)
end

-- Покупки за Robux
function AnalyticsHub:Robux(player: Player, sku: string, price: number)
	pcall(AnalyticsService.LogCustomEvent, AnalyticsService, player, "RobuxPurchase_" .. sku, price)
end

function AnalyticsHub:Start()
	self.S.DataService:OnLoaded(function(player)
		self:Step(player, 1)
	end)
end

return AnalyticsHub
