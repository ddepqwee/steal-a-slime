--!nonstrict
-- Game Passes + Developer Products. Защита от двойной выдачи через историю чеков.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local MonetizationService = {}
local owned = {} :: { [Player]: { [string]: boolean } }
local productByid = {}
local passById = {}
local MAX_RECEIPTS = 60

function MonetizationService:Init(S)
	self.S = S
	for name, info in Config.Products do
		if info.Id ~= 0 then
			productByid[info.Id] = name
		end
	end
	for name, info in Config.GamePasses do
		if info.Id ~= 0 then
			passById[info.Id] = name
		end
	end
end

function MonetizationService:HasPass(player: Player, name: string): boolean
	local t = owned[player]
	return t ~= nil and t[name] == true
end

local function setOwned(player: Player, name: string)
	owned[player] = owned[player] or {}
	owned[player][name] = true
	player:SetAttribute("Pass_" .. name, true)
end

function MonetizationService:_checkPasses(player: Player)
	owned[player] = owned[player] or {}
	for name, info in Config.GamePasses do
		if info.Id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, info.Id)
			if ok and has then
				setOwned(player, name)
			end
		end
	end
	self.S.EconomyService:Refresh(player)
	self.S.ProgressionService:ApplySpeed(player)
end

-- Обработчики продуктов. Возвращают true при успешной выдаче.
local handlers = {}

handlers.Cash = function(self, player, info)
	local Econ = self.S.EconomyService
	local amount = math.max(info.Min, Econ:GetIncome(player) * 60 * info.Minutes)
	Econ:AddCash(player, amount)
	self.S.SocialService:Notify(player, "+" .. Format.money(amount) .. " 💰", Color3.fromRGB(120, 255, 120))
	return true
end

handlers.LuckySpawn = function(self, player)
	self.S.SpawnService:QueueLucky(player)
	self.S.SocialService:NotifyAll(player.DisplayName .. " bought LUCKY SPAWN! 🍀 Next slime is LEGENDARY!", Color3.fromRGB(255, 200, 0))
	return true
end

handlers.ServerLuck = function(self, player, info)
	self.S.EventService:AddServerLuck(info.Minutes * 60)
	self.S.SocialService:NotifyAll(player.DisplayName .. " activated SERVER LUCK x2 for everyone! 🎉", Color3.fromRGB(80, 255, 200))
	return true
end

function MonetizationService:_processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = self.S.DataService:Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local rid = receipt.PurchaseId
	if table.find(data.Receipts, rid) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local name = productByid[receipt.ProductId]
	local info = name and Config.Products[name]
	if not info then
		warn("[Shop] unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local handler = handlers[info.Kind]
	local ok, granted = pcall(handler, self, player, info)
	if not ok or not granted then
		warn("[Shop] grant error", name, granted)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(data.Receipts, rid)
	while #data.Receipts > MAX_RECEIPTS do
		table.remove(data.Receipts, 1)
	end
	self.S.DataService:Save(player, false)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService:Start()
	MarketplaceService.ProcessReceipt = function(receipt)
		return self:_processReceipt(receipt)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local name = passById[passId]
		if purchased and name then
			setOwned(player, name)
			self.S.EconomyService:Refresh(player)
			self.S.ProgressionService:ApplySpeed(player)
			self.S.PlotService:RefreshSlots(player)
			self.S.SocialService:NotifyAll(player.DisplayName .. " bought " .. Config.GamePasses[name].Title .. "! ⭐", Color3.fromRGB(255, 220, 80))
		end
	end)

	self.S.DataService:OnLoaded(function(player)
		self:_checkPasses(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		owned[p] = nil
	end)
end

return MonetizationService
