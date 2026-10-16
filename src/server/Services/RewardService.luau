--!nonstrict
-- 🎁 Подарки за время в сессии, 🎡 колесо удачи (раз в 4 часа), 🧪 зелья.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Pets = require(ReplicatedStorage.Shared.Pets)

local RewardService = {}
local session = {} :: { [Player]: { start: number, claimed: number } }
local RewardRemote

function RewardService:Init(S)
	self.S = S
	RewardRemote = Net.event("Reward")
end

function RewardService:_cash(player: Player, minutes: number): number
	local amount = math.floor(math.max(Config.GiftCashMin, self.S.EconomyService:GetIncome(player) * 60 * minutes))
	self.S.EconomyService:AddCash(player, amount)
	return amount
end

-- Выдать приз (общий для подарков и колеса). Возвращает текст.
function RewardService:_grant(player: Player, prize): string
	if prize.Kind == "Cash" then
		return "+" .. Format.money(self:_cash(player, prize.Minutes))
	elseif prize.Kind == "Luck" then
		self.S.EventService:AddPotionLuck(10 * 60)
		self.S.SocialService:NotifyAll("🍀 " .. player.DisplayName .. " gave the whole server LUCK x1.5!", Color3.fromRGB(120, 255, 140))
		return "🍀 Server Luck x1.5 (10 min)"
	elseif prize.Kind == "CashPotion" then
		local data = self.S.DataService:Get(player)
		data.CashPotionUntil = math.max(data.CashPotionUntil or 0, os.time()) + 15 * 60
		self.S.EconomyService:Refresh(player)
		return "🧪 Cash x2 (15 min)"
	elseif prize.Kind == "Slime" then
		local entry = self.S.SpawnService:RollEntry(prize.MinRarity, 1.5)
		local def = Pets.ById[entry.Id]
		if self.S.WorldEventService:_grant(player, entry) then
			return "🫧 " .. Config.Rarities[def.Rarity].Name .. " " .. def.Name .. "!"
		end
		-- нет места — компенсируем деньгами
		return "+" .. Format.money(self:_cash(player, 10)) .. " (base full)"
	end
	return ""
end

-- ===== Подарки за время =====
function RewardService:GiftInfo(player: Player)
	local s = session[player]
	if not s then
		return nil
	end
	local nextGift = Config.PlayGifts[s.claimed + 1]
	if not nextGift then
		return { Done = true }
	end
	local ready = os.clock() - s.start >= nextGift.Min * 60
	return { Index = s.claimed + 1, Total = #Config.PlayGifts, ReadyIn = math.max(0, nextGift.Min * 60 - (os.clock() - s.start)), Ready = ready }
end

function RewardService:ClaimGift(player: Player)
	local s = session[player]
	local info = self:GiftInfo(player)
	if not s or not info or info.Done or not info.Ready then
		return
	end
	s.claimed += 1
	local text = self:_grant(player, Config.PlayGifts[s.claimed])
	self.S.SocialService:Notify(player, "🎁 Gift " .. s.claimed .. "/" .. #Config.PlayGifts .. ": " .. text, Color3.fromRGB(255, 220, 120), "Buy")
end

-- ===== Колесо удачи =====
function RewardService:SpinReadyIn(data): number
	return math.max(0, (data.LastSpin or 0) + Config.Spin.Cooldown - os.time())
end

function RewardService:Spin(player: Player)
	local data = self.S.DataService:Get(player)
	if not data or self:SpinReadyIn(data) > 0 then
		return
	end
	data.LastSpin = os.time()
	local total = 0
	for _, p in Config.Spin.Prizes do
		total += p.W
	end
	local r = math.random() * total
	local idx = 1
	for i, p in Config.Spin.Prizes do
		r -= p.W
		if r <= 0 then
			idx = i
			break
		end
	end
	-- клиент крутит анимацию, приз выдаём сразу (сохранение не зависит от анимации)
	local text = self:_grant(player, Config.Spin.Prizes[idx])
	RewardRemote:FireClient(player, "Spin", { Index = idx, Text = text })
end

-- ===== Зелья =====
function RewardService:PotionPrice(player: Player, potion): number
	return math.floor(math.max(potion.PriceMin, self.S.EconomyService:GetIncome(player) * potion.PriceIncomeSec))
end

function RewardService:BuyPotion(player: Player, id: any)
	local potion
	for _, p in Config.Potions do
		if p.Id == id then
			potion = p
		end
	end
	local data = self.S.DataService:Get(player)
	if not potion or not data then
		return
	end
	local price = self:PotionPrice(player, potion)
	if not self.S.EconomyService:TrySpend(player, price) then
		self.S.SocialService:Notify(player, "You need " .. Format.money(price), Color3.fromRGB(255, 120, 120))
		return
	end
	if potion.Id == "Cash" then
		data.CashPotionUntil = math.max(data.CashPotionUntil or 0, os.time()) + potion.Minutes * 60
		self.S.EconomyService:Refresh(player)
		self.S.SocialService:Notify(player, "🧪 Cash x2 active for " .. potion.Minutes .. " min!", Color3.fromRGB(140, 255, 160), "Buy")
	elseif potion.Id == "Luck" then
		self.S.EventService:AddPotionLuck(potion.Minutes * 60)
		self.S.SocialService:NotifyAll("🍀 " .. player.DisplayName .. " drank a Server Luck Potion! x1.5 luck for everyone", Color3.fromRGB(120, 255, 140), "Legendary")
	end
end

-- Компактное состояние для HUD (отправляется в State каждую секунду)
function RewardService:StateFor(player: Player, data)
	local prices = {}
	for _, p in Config.Potions do
		prices[p.Id] = self:PotionPrice(player, p)
	end
	return {
		Gift = self:GiftInfo(player),
		SpinIn = self:SpinReadyIn(data),
		CashPotionIn = math.max(0, (data.CashPotionUntil or 0) - os.time()),
		PotionPrices = prices,
	}
end

function RewardService:Start()
	self.S.DataService:OnLoaded(function(player)
		session[player] = { start = os.clock(), claimed = 0 }
	end)
	Players.PlayerRemoving:Connect(function(p)
		session[p] = nil
	end)
end

return RewardService
