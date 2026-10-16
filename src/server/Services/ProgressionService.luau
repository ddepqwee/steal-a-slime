--!nonstrict
-- Прокачка скорости, ребёрты и обработка действий игрока из UI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
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
	if player:GetAttribute("Carrying") then
		speed *= Config.CarrySpeedMult
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
	data.Cash = Config.StartCash * (data.Rebirths + 1)
	data.Pets = {}
	data.SpeedLevel = 0
	self:ApplySpeed(player)
	self.S.EconomyService:Refresh(player)
	self.S.EconomyService:AddCash(player, 0)
	self.S.SocialService:NotifyAll("♻️ " .. player.DisplayName .. " rebirthed! (#" .. data.Rebirths .. ")", Color3.fromRGB(200, 140, 255))
	self.S.DataService:Save(player, false)
end

function ProgressionService:Start()
	ActionRemote.OnServerEvent:Connect(function(player, action)
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
