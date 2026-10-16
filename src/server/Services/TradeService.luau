--!nonstrict
-- 🤝 Трейды: запрос → оба кладут до 4 слаймов → оба жмут Ready → сервер проверяет и меняет атомарно.
-- Любое изменение предложения сбрасывает Ready (защита от подмены в последний момент).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Pets = require(ReplicatedStorage.Shared.Pets)

local TradeService = {}
local Remote
local MAX_OFFER = 4
local REQUEST_TTL = 25

local sessions = {} :: { [Player]: any } -- player -> session
local requests = {} :: { [Player]: { from: Player, at: number } } -- target -> request
local lastRequest = {} :: { [Player]: number }

function TradeService:Init(S)
	self.S = S
	Remote = Net.event("Trade")
end

local function same(a, b): boolean
	return a ~= nil and b ~= nil and a.Id == b.Id and a.V == b.V and a.M == b.M and (a.L or 1) == (b.L or 1)
end

function TradeService:_view(sess, me: Player)
	local other = if sess.a == me then sess.b else sess.a
	local data = self.S.DataService:Get(me)
	local function list(p)
		local out = {}
		for slot, entry in sess.offer[p] do
			table.insert(out, { Slot = slot, Id = entry.Id, V = entry.V, M = entry.M, L = entry.L, Income = self.S.EconomyService:PetIncome(entry) })
		end
		return out
	end
	local mine = {}
	for slot, entry in (data and data.Pets or {}) do
		if not sess.offer[me][slot] and not self.S.StealService:IsCarried(me, slot) then
			table.insert(mine, { Slot = slot, Id = entry.Id, V = entry.V, M = entry.M, L = entry.L, Income = self.S.EconomyService:PetIncome(entry) })
		end
	end
	table.sort(mine, function(x, y)
		return x.Income > y.Income
	end)
	return {
		Partner = other.DisplayName,
		Mine = mine,
		MyOffer = list(me),
		TheirOffer = list(other),
		MyReady = sess.ready[me] == true,
		TheirReady = sess.ready[other] == true,
		Max = MAX_OFFER,
	}
end

function TradeService:_push(sess)
	for _, p in { sess.a, sess.b } do
		if p.Parent then
			Remote:FireClient(p, "State", self:_view(sess, p))
		end
	end
end

function TradeService:_close(sess, reason: string?)
	for _, p in { sess.a, sess.b } do
		if sessions[p] == sess then
			sessions[p] = nil
		end
		if p.Parent then
			Remote:FireClient(p, "Closed", reason or "")
		end
	end
end

function TradeService:Request(from: Player, targetId: any)
	local target = typeof(targetId) == "number" and Players:GetPlayerByUserId(targetId)
	if not target or target == from or sessions[from] or sessions[target] then
		return
	end
	local now = os.clock()
	if now - (lastRequest[from] or 0) < 5 then
		return
	end
	lastRequest[from] = now
	-- взаимный запрос = сразу открыть трейд
	local back = requests[from]
	if back and back.from == target and now - back.at < REQUEST_TTL then
		self:Accept(from)
		return
	end
	requests[target] = { from = from, at = now }
	Remote:FireClient(target, "Invite", from.DisplayName, from.UserId)
	self.S.SocialService:Notify(from, "🤝 Trade request sent to " .. target.DisplayName, Color3.fromRGB(140, 220, 255))
end

function TradeService:Accept(target: Player)
	local req = requests[target]
	requests[target] = nil
	if not req or os.clock() - req.at > REQUEST_TTL then
		return
	end
	local from = req.from
	if not from.Parent or sessions[from] or sessions[target] then
		return
	end
	local sess = { a = from, b = target, offer = { [from] = {}, [target] = {} }, ready = {} }
	sessions[from] = sess
	sessions[target] = sess
	self:_push(sess)
end

function TradeService:Decline(target: Player)
	local req = requests[target]
	requests[target] = nil
	if req and req.from.Parent then
		self.S.SocialService:Notify(req.from, "🤝 " .. target.DisplayName .. " declined the trade", Color3.fromRGB(255, 160, 120))
	end
end

function TradeService:_change(player: Player, fn)
	local sess = sessions[player]
	if not sess then
		return
	end
	fn(sess)
	sess.ready = {} -- любое изменение сбрасывает готовность обоих
	self:_push(sess)
end

function TradeService:Add(player: Player, slot: any)
	if type(slot) ~= "string" then
		return
	end
	self:_change(player, function(sess)
		local data = self.S.DataService:Get(player)
		local entry = data and data.Pets[slot]
		local count = 0
		for _ in sess.offer[player] do
			count += 1
		end
		if entry and count < MAX_OFFER and not self.S.StealService:IsCarried(player, slot) then
			sess.offer[player][slot] = table.clone(entry)
		end
	end)
end

function TradeService:Remove(player: Player, slot: any)
	if type(slot) ~= "string" then
		return
	end
	self:_change(player, function(sess)
		sess.offer[player][slot] = nil
	end)
end

function TradeService:Ready(player: Player)
	local sess = sessions[player]
	if not sess then
		return
	end
	sess.ready[player] = true
	if sess.ready[sess.a] and sess.ready[sess.b] then
		self:_commit(sess)
	else
		self:_push(sess)
	end
end

function TradeService:_commit(sess)
	local a, b = sess.a, sess.b
	local DS, Plot = self.S.DataService, self.S.PlotService
	local da, db = DS:Get(a), DS:Get(b)
	if not da or not db then
		self:_close(sess, "Trade cancelled")
		return
	end
	local giveA, giveB = 0, 0
	for slot, snap in sess.offer[a] do
		if not same(da.Pets[slot], snap) or self.S.StealService:IsCarried(a, slot) then
			self:_close(sess, "Trade cancelled: offer changed")
			return
		end
		giveA += 1
	end
	for slot, snap in sess.offer[b] do
		if not same(db.Pets[slot], snap) or self.S.StealService:IsCarried(b, slot) then
			self:_close(sess, "Trade cancelled: offer changed")
			return
		end
		giveB += 1
	end
	if giveA + giveB == 0 then
		self:_close(sess, "Nothing to trade")
		return
	end
	-- места: после отдачи своих должно хватить на чужих
	if Plot:MaxSlots(a) - Plot:UsedSlots(a) + giveA < giveB then
		self:_close(sess, a.DisplayName .. "'s base is too full")
		return
	end
	if Plot:MaxSlots(b) - Plot:UsedSlots(b) + giveB < giveA then
		self:_close(sess, b.DisplayName .. "'s base is too full")
		return
	end
	-- обмен (без yield между шагами — атомарно в рамках сервера)
	local toB, toA = {}, {}
	for slot, snap in sess.offer[a] do
		table.insert(toB, snap)
		Plot:RemovePet(a, slot)
	end
	for slot, snap in sess.offer[b] do
		table.insert(toA, snap)
		Plot:RemovePet(b, slot)
	end
	for _, e in toA do
		local s = Plot:AddPet(a, e)
		if s then
			Plot:RenderSlot(a, s)
		end
	end
	for _, e in toB do
		local s = Plot:AddPet(b, e)
		if s then
			Plot:RenderSlot(b, s)
		end
	end
	sessions[a] = nil
	sessions[b] = nil
	for _, p in { a, b } do
		Remote:FireClient(p, "Closed", "✅ Trade complete!")
		DS:Save(p, false)
		self.S.AnalyticsHub:Custom(p, "Trade", 1)
	end
	local best
	for _, e in table.move(toA, 1, #toA, #toB + 1, table.clone(toB)) do
		local def = Pets.ById[e.Id]
		if def and (not best or def.Rarity > best.Rarity) then
			best = def
		end
	end
	if best and best.Rarity >= Config.AnnounceFromRarity then
		self.S.SocialService:NotifyAll(("🤝 %s and %s traded a %s %s!"):format(a.DisplayName, b.DisplayName, Config.Rarities[best.Rarity].Name, best.Name), Color3.fromRGB(140, 220, 255))
	else
		self.S.SocialService:NotifyAll("🤝 " .. a.DisplayName .. " and " .. b.DisplayName .. " made a trade!", Color3.fromRGB(140, 220, 255))
	end
end

function TradeService:Cancel(player: Player)
	local sess = sessions[player]
	if sess then
		self:_close(sess, "🤝 " .. player.DisplayName .. " cancelled the trade")
	end
end

-- Внешние сервисы зовут, когда у игрока меняются слаймы (продажа, кража, фьюз…)
function TradeService:Touch(player: Player)
	local sess = sessions[player]
	if sess then
		sess.ready = {}
		self:_push(sess)
	end
end

function TradeService:Start()
	Remote.OnServerEvent:Connect(function(player, action, arg)
		if action == "Request" then
			self:Request(player, arg)
		elseif action == "Accept" then
			self:Accept(player)
		elseif action == "Decline" then
			self:Decline(player)
		elseif action == "Add" then
			self:Add(player, arg)
		elseif action == "Remove" then
			self:Remove(player, arg)
		elseif action == "Ready" then
			self:Ready(player)
		elseif action == "Cancel" then
			self:Cancel(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		self:Cancel(p)
		requests[p] = nil
		lastRequest[p] = nil
		for target, req in requests do
			if req.from == p then
				requests[target] = nil
			end
		end
	end)
end

return TradeService
