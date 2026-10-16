--!nonstrict
-- 🏆 Достижения: открываются автоматически, награда — деньги + Rebirth Tokens.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local AchievementService = {}

function AchievementService:Init(S)
	self.S = S
end

function AchievementService:Value(data, stat: string): number
	if stat == "Steals" then
		return data.Steals or 0
	elseif stat == "Rebirths" then
		return data.Rebirths or 0
	elseif stat == "TotalEarned" then
		return data.TotalEarned or 0
	elseif stat == "Index" then
		return self.S.IndexService:Count(data)
	end
	return (data.Stats and data.Stats[stat]) or 0
end

function AchievementService:List(player: Player)
	local data = self.S.DataService:Get(player)
	local list = {}
	if not data then
		return list
	end
	for _, a in Config.Achievements do
		table.insert(list, {
			Id = a.Id,
			Name = a.Name,
			Stat = a.Stat,
			Goal = a.Goal,
			Prog = math.min(a.Goal, self:Value(data, a.Stat)),
			Done = data.Ach and data.Ach[a.Id] == true,
			Tokens = a.Tokens,
		})
	end
	return list
end

function AchievementService:Check(player: Player)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	data.Ach = data.Ach or {}
	local any = false
	for _, a in Config.Achievements do
		if not data.Ach[a.Id] and self:Value(data, a.Stat) >= a.Goal then
			data.Ach[a.Id] = true
			any = true
			local cash = math.floor(math.max(1_000, self.S.EconomyService:GetIncome(player) * 60 * a.Minutes))
			self.S.EconomyService:AddCash(player, cash)
			data.Tokens = (data.Tokens or 0) + a.Tokens
			local extra = if a.Tokens > 0 then " + 🔮" .. a.Tokens else ""
			self.S.SocialService:Notify(player, "🏆 Achievement: " .. a.Name .. "! +" .. Format.money(cash) .. extra, Color3.fromRGB(255, 215, 90), "Legendary")
		end
	end
	if any then
		self.S.IndexService:SendMeta(player)
	end
end

function AchievementService:Start()
	self.S.DataService:OnLoaded(function(player, data)
		-- токены за уже сделанные ребёрты (для старых игроков)
		if not data.TokensInit then
			data.TokensInit = true
			data.Tokens = (data.Tokens or 0) + (data.Rebirths or 0)
		end
		task.delay(3, function()
			if player.Parent then
				self:Check(player)
			end
		end)
	end)
	-- TotalEarned растёт постоянно — проверяем раз в минуту
	while true do
		task.wait(60)
		for player in self.S.DataService.Profiles do
			self:Check(player)
		end
	end
end

return AchievementService
