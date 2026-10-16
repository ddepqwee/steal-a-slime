--!nonstrict
-- 🎓 Туториал для новичков: 4 шага с наградами. Шаги засчитываются по реальным действиям.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)

local TutorialService = {}
local Remote

-- Event — какое действие засчитывает шаг; Reward — деньги за шаг
TutorialService.Steps = {
	{ Event = "Buy", Reward = 150 },
	{ Event = "Upgrade", Reward = 300 },
	{ Event = "Steal", Reward = 600 },
	{ Event = "Lock", Reward = 1000 },
}
local DONE = 99

function TutorialService:Init(S)
	self.S = S
	Remote = Net.event("Tutorial")
end

function TutorialService:Send(player: Player)
	local data = self.S.DataService:Get(player)
	if data then
		Remote:FireClient(player, data.Tutorial or DONE, #self.Steps)
	end
end

function TutorialService:_next(player: Player, data, rewarded: boolean)
	local step = self.Steps[data.Tutorial]
	if rewarded and step then
		self.S.EconomyService:AddCash(player, step.Reward)
		self.S.SocialService:Notify(player, "🎓 Step complete! +" .. Format.money(step.Reward), Color3.fromRGB(140, 255, 160), "Buy")
	end
	data.Tutorial += 1
	if data.Tutorial > #self.Steps then
		data.Tutorial = DONE
		self.S.SocialService:Notify(player, "🎓 Tutorial complete! Try 🥚 Eggs, ⚗️ Fuse and rebirth to unlock 🌋 Lava Land!", Color3.fromRGB(255, 220, 90), "Legendary")
	end
	self:Send(player)
end

-- Вызывается из игровых сервисов при действии игрока
function TutorialService:Advance(player: Player, event: string)
	local data = self.S.DataService:Get(player)
	if not data or not data.Tutorial or data.Tutorial == DONE then
		return
	end
	local step = self.Steps[data.Tutorial]
	if step and step.Event == event then
		self:_next(player, data, true)
	end
end

function TutorialService:Skip(player: Player)
	local data = self.S.DataService:Get(player)
	if not data or not data.Tutorial or data.Tutorial == DONE then
		return
	end
	self:_next(player, data, false)
end

function TutorialService:Start()
	self.S.DataService:OnLoaded(function(player, data)
		-- у игроков с прогрессом туториал сразу пройден
		if not data.TutorialChecked then
			data.TutorialChecked = true
			if (data.Rebirths or 0) > 0 or (data.TotalEarned or 0) > 20_000 then
				data.Tutorial = DONE
			end
		end
		data.Tutorial = data.Tutorial or 1
		task.delay(4, function()
			if player.Parent then
				self:Send(player)
			end
		end)
	end)
end

return TutorialService
