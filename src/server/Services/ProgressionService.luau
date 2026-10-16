--!nonstrict
-- Прокачка скорости, ребёрты и обработка действий игрока из UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Net = require(ReplicatedStorage.Shared.Net)

local ProgressionService = {}
local ActionRemote = Net.event("Action")
local lastAction = {} :: { [Player]: number }

function ProgressionService:Init(S)
	self.S = S
end

function ProgressionService:SpeedCost(data): number
	if data.SpeedLevel >= Config.Speed.MaxLevel then
		return -1
	end
	return math.floor(Config.Speed.BaseCost * Config.Speed.CostMult ^ data.SpeedLevel)
end

function ProgressionService:RebirthCost(data): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostMult ^ data.Rebirths)
end

function ProgressionService:ApplySpeed(player: Player)
	local data = self.S.DataService:Get(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not data or not hum then
		return
	end
	local speed = Config.Speed.BaseWalk + data.SpeedLevel * Config.Speed.Step
	if self.S.MonetizationService:HasPass(player, "VIP") then
		speed += Config.Speed.VipBonus
	end
	speed += tonumber(player:GetAttribute("GearSpeed")) or 0
	speed += (data.Perks and data.Perks.Speed) or 0
	if player:GetAttribute("Carrying") then
		speed *= Config.CarrySpeedMult
	end
	if player:GetAttribute("Stunned") then
		speed = 0
	end
	hum.WalkSpeed = speed
end

function ProgressionService:BuySpeed(player: Player)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	local cost = self:SpeedCost(data)
	if cost < 0 then
		return
	end
	if self.S.EconomyService:TrySpend(player, cost) then
		data.SpeedLevel += 1
		self:ApplySpeed(player)
		self.S.SocialService:Notify(player, "⚡ Speed: level " .. data.SpeedLevel, Color3.fromRGB(120, 220, 255))
	else
		self.S.SocialService:Notify(player, "You need " .. Format.money(cost), Color3.fromRGB(255, 120, 120))
	end
end

function ProgressionService:SlotCost(data): number?
	local bought = data.ExtraSlots or 0
	if bought >= Config.SlotUpgrade.Max then
		return nil
	end
	return math.floor(Config.SlotUpgrade.BaseCost * Config.SlotUpgrade.CostMult ^ bought)
end

function ProgressionService:BuySlot(player: Player)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	local cost = self:SlotCost(data)
	if not cost then
		return
	end
	if not self.S.EconomyService:TrySpend(player, cost) then
		self.S.SocialService:Notify(player, "You need " .. Format.money(cost), Color3.fromRGB(255, 120, 120))
		return
	end
	data.ExtraSlots = (data.ExtraSlots or 0) + 1
	self.S.PlotService:RefreshSlots(player)
	self.S.SocialService:Notify(player, "🫧 +1 slime slot! (" .. self.S.PlotService:MaxSlots(player) .. " total)", Color3.fromRGB(140, 255, 200), "Buy")
end

function ProgressionService:MutateCost(entry): number
	return math.floor(self.S.EconomyService:PetValue(entry) * Config.Mutate.CostMult)
end

function ProgressionService:Mutate(player: Player, slot: string)
	local data = self.S.DataService:Get(player)
	local entry = data and data.Pets[slot]
	if not entry or self.S.StealService:IsCarried(player, slot) then
		return
	end
	local cost = self:MutateCost(entry)
	if not self.S.EconomyService:TrySpend(player, cost) then
		self.S.SocialService:Notify(player, "You need " .. Format.money(cost), Color3.fromRGB(255, 120, 120))
		return
	end
	local total = 0
	for _, o in Config.Mutate.Odds do
		total += o.W
	end
	local r = math.random() * total
	local result = Config.Mutate.Odds[1].V
	for _, o in Config.Mutate.Odds do
		r -= o.W
		if r <= 0 then
			result = o.V
			break
		end
	end
	entry.V = result
	self.S.DataService:Stat(player, "Mutations")
	self.S.EconomyService:Refresh(player)
	self.S.PlotService:RenderSlot(player, slot)
	local v = Config.Variants[result]
	local def = Pets.ById[entry.Id]
	if result == "Galaxy" or result == "Rainbow" then
		self.S.SocialService:NotifyAll(v.Icon .. " " .. player.DisplayName .. " mutated " .. def.Name .. " into " .. v.Label .. "!", v.Color, "Legendary")
	else
		self.S.SocialService:Notify(player, v.Icon .. " Mutation: " .. v.Label .. " (x" .. v.Mult .. " cash)", v.Color, "Buy")
	end
end

function ProgressionService:Fuse(player: Player, petId: any)
	local data = self.S.DataService:Get(player)
	if not data or type(petId) ~= "string" then
		return
	end
	local slots = {}
	for slot, entry in data.Pets do
		if entry.Id == petId and not entry.M and not self.S.StealService:IsCarried(player, slot) then
			table.insert(slots, slot)
		end
	end
	if #slots < Config.Fuse.Need then
		return
	end
	table.sort(slots, function(a, b)
		return tonumber(a) < tonumber(b)
	end)
	local bestV, bestMult, bestL = nil, 1, 1
	for i = 1, Config.Fuse.Need do
		local e = data.Pets[slots[i]]
		local v = e.V and Config.Variants[e.V]
		if v and v.Mult > bestMult then
			bestV, bestMult = e.V, v.Mult
		end
		bestL = math.max(bestL, e.L or 1)
	end
	for i = 2, Config.Fuse.Need do
		self.S.PlotService:RemovePet(player, slots[i])
	end
	data.Pets[slots[1]] = { Id = petId, V = bestV, L = bestL, M = true }
	self.S.DataService:Stat(player, "Fused")
	self.S.EconomyService:Refresh(player)
	self.S.PlotService:RenderSlot(player, slots[1])
	self.S.SocialService:NotifyAll("⚗️ " .. player.DisplayName .. " fused a MEGA " .. Pets.ById[petId].Name .. "!", Color3.fromRGB(255, 220, 80), "Legendary")
end

function ProgressionService:LockUpgradeCost(data): number?
	return Config.LockUpgrade.Costs[(data.LockLevel or 0) + 1]
end

function ProgressionService:BuyLockUpgrade(player: Player)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	local cost = self:LockUpgradeCost(data)
	if not cost then
		return
	end
	if not self.S.EconomyService:TrySpend(player, cost) then
		self.S.SocialService:Notify(player, "You need " .. Format.money(cost), Color3.fromRGB(255, 120, 120))
		return
	end
	data.LockLevel = (data.LockLevel or 0) + 1
	self.S.SocialService:Notify(player, "🔒 Lock upgraded! Now lasts " .. Config.LockUpgrade.Durations[data.LockLevel + 1] .. "s", Color3.fromRGB(255, 160, 180), "Buy")
end

function ProgressionService:TrapCost(data): number?
	return Config.Trap.Costs[(data.TrapLevel or 0) + 1]
end

function ProgressionService:BuyTrap(player: Player)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	local cost = self:TrapCost(data)
	if not cost then
		return
	end
	if not self.S.EconomyService:TrySpend(player, cost) then
		self.S.SocialService:Notify(player, "You need " .. Format.money(cost), Color3.fromRGB(255, 120, 120))
		return
	end
	data.TrapLevel = (data.TrapLevel or 0) + 1
	self.S.PlotService:RefreshTrap(player)
	self.S.SocialService:Notify(player, "🪤 Trap Lv." .. data.TrapLevel .. "! Thieves get stunned for " .. Config.Trap.Stun[data.TrapLevel] .. "s", Color3.fromRGB(200, 120, 255), "Buy")
end

function ProgressionService:BuyPerk(player: Player, id: any)
	local data = self.S.DataService:Get(player)
	local perk
	for _, p in Config.Perks do
		if p.Id == id then
			perk = p
		end
	end
	if not data or not perk then
		return
	end
	data.Perks = data.Perks or {}
	local lvl = data.Perks[perk.Id] or 0
	if lvl >= perk.Max then
		return
	end
	if (data.Tokens or 0) < perk.Cost then
		self.S.SocialService:Notify(player, "🔮 You need " .. perk.Cost .. " Rebirth Token(s)", Color3.fromRGB(200, 160, 255))
		return
	end
	data.Tokens -= perk.Cost
	data.Perks[perk.Id] = lvl + 1
	self:ApplySpeed(player)
	self.S.EconomyService:Refresh(player)
	self.S.IndexService:SendMeta(player)
	self.S.SocialService:Notify(player, "🔮 " .. perk.Name .. " Lv." .. (lvl + 1) .. "!", Color3.fromRGB(200, 160, 255), "Buy")
end

function ProgressionService:UpgradePet(player: Player, slot: string)
	local data = self.S.DataService:Get(player)
	local entry = data and data.Pets[slot]
	if not entry or self.S.StealService:IsCarried(player, slot) then
		return
	end
	local cost = self.S.EconomyService:UpgradeCost(entry)
	if not cost then
		return
	end
	if not self.S.EconomyService:TrySpend(player, cost) then
		self.S.SocialService:Notify(player, "You need " .. Format.money(cost), Color3.fromRGB(255, 120, 120))
		return
	end
	entry.L = (entry.L or 1) + 1
	self.S.EconomyService:Refresh(player)
	self.S.PlotService:RenderSlot(player, slot)
	self.S.QuestService:Add(player, "Upgrade", 1)
	self.S.DataService:Stat(player, "Upgrades")
	self.S.TutorialService:Advance(player, "Upgrade")
	self.S.SocialService:Notify(player, "⬆️ Upgraded to Lv." .. entry.L .. "! Income x" .. Config.Upgrade.IncomeMult, Color3.fromRGB(140, 255, 160), "Buy")
end

function ProgressionService:Rebirth(player: Player)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	local cost = self:RebirthCost(data)
	if data.Cash < cost then
		self.S.SocialService:Notify(player, "Rebirth requires " .. Format.money(cost), Color3.fromRGB(255, 120, 120))
		return
	end
	self.S.StealService:CancelForVictim(player)
	self.S.PlotService:ClearAll(player)
	data.Rebirths += 1
	data.Tokens = (data.Tokens or 0) + 1
	local startLvl = (data.Perks and data.Perks.Start) or 0
	data.Cash = Config.StartCash * (data.Rebirths + 1) * 3 ^ startLvl
	data.Pets = {}
	data.SpeedLevel = 0
	self:ApplySpeed(player)
	self.S.EconomyService:Refresh(player)
	self.S.EconomyService:AddCash(player, 0)
	self.S.SocialService:NotifyAll("♻️ " .. player.DisplayName .. " rebirthed! (#" .. data.Rebirths .. ")", Color3.fromRGB(200, 140, 255))
	self.S.SocialService:Notify(player, "🔮 +1 Rebirth Token! Spend it on permanent perks in ♻️ Rebirth", Color3.fromRGB(200, 160, 255))
	self.S.AchievementService:Check(player)
	self.S.IndexService:SendMeta(player)
	self.S.DataService:Save(player, false)
end

function ProgressionService:Start()
	ActionRemote.OnServerEvent:Connect(function(player, action, arg)
		local now = os.clock()
		if now - (lastAction[player] or 0) < 0.25 then
			return
		end
		lastAction[player] = now
		if action == "BuySpeed" then
			self:BuySpeed(player)
		elseif action == "Rebirth" then
			self:Rebirth(player)
		elseif action == "Daily" then
			self.S.SocialService:ClaimDaily(player)
		elseif action == "Lock" then
			self.S.PlotService:Lock(player)
		elseif action == "TutSkip" then
			self.S.TutorialService:Skip(player)
		elseif action == "Hatch" then
			self.S.RewardService:Hatch(player, arg)
		elseif action == "Redeem" then
			self.S.RewardService:Redeem(player, arg)
		elseif action == "ToggleBuddy" then
			local d = self.S.DataService:Get(player)
			if d then
				d.Buddy = not d.Buddy
				self.S.BuddyService:Refresh(player)
			end
		elseif action == "BuyTrap" then
			self:BuyTrap(player)
		elseif action == "BuyPerk" then
			self:BuyPerk(player, arg)
		elseif action == "ClaimGift" then
			self.S.RewardService:ClaimGift(player)
		elseif action == "Spin" then
			self.S.RewardService:Spin(player)
		elseif action == "BuyPotion" then
			self.S.RewardService:BuyPotion(player, arg)
		elseif action == "Fuse" then
			self:Fuse(player, arg)
		elseif action == "BuyLock" then
			self:BuyLockUpgrade(player)
		elseif action == "BuySlot" then
			self:BuySlot(player)
		elseif action == "BuyGear" then
			self.S.GearService:Buy(player, arg)
		elseif action == "ClaimQuest" then
			self.S.QuestService:Claim(player, arg)
		end
		self.S.EconomyService:SendState(player)
	end)

	local function hook(player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("Humanoid", 10)
			self:ApplySpeed(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	self.S.DataService:OnLoaded(function(player)
		self:ApplySpeed(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastAction[p] = nil
	end)
end

return ProgressionService
