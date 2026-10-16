--!nonstrict
-- Уведомления, звуки, буст за друзей, бонус группы, ежедневная награда.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)

local SocialService = {}
local NotifyRemote = Net.event("Notify")
local friendCache = {} :: { [string]: boolean }

function SocialService:Init(S)
	self.S = S
end

function SocialService:Notify(player: Player, text: string, color: Color3?, sound: string?)
	-- звук передаём ключом (Buy/Steal/Legendary/...), клиент сам знает ID из AudioIds
	NotifyRemote:FireClient(player, text, color or Color3.new(1, 1, 1), sound or "")
end

function SocialService:NotifyAll(text: string, color: Color3?, sound: string?)
	NotifyRemote:FireAllClients(text, color or Color3.new(1, 1, 1), sound or "")
end

function SocialService:PlaySound(player: Player, sound: string)
	NotifyRemote:FireClient(player, "", Color3.new(1, 1, 1), sound)
end

local function pairKey(a: number, b: number)
	return if a < b then a .. ":" .. b else b .. ":" .. a
end

local function areFriends(a: Player, b: Player): boolean
	local k = pairKey(a.UserId, b.UserId)
	if friendCache[k] == nil then
		local ok, res = pcall(a.IsFriendsWithAsync, a, b.UserId)
		friendCache[k] = ok and res == true
	end
	return friendCache[k]
end

function SocialService:RecalcFriends()
	local list = Players:GetPlayers()
	for _, p in list do
		local n = 0
		for _, o in list do
			if o ~= p and areFriends(p, o) then
				n += 1
			end
		end
		local boost = math.min(n * Config.FriendBoostEach, Config.FriendBoostMax)
		p:SetAttribute("FriendBoost", boost)
		if self.S.DataService:Get(p) then
			self.S.EconomyService:Refresh(p)
		end
	end
end

function SocialService:ClaimDaily(player: Player)
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	local now = os.time()
	local since = now - data.LastDaily
	if since < Config.DailyCooldown then
		self:Notify(player, "Next reward in " .. Format.time(Config.DailyCooldown - since), Color3.fromRGB(255, 200, 120))
		return
	end
	if since < Config.DailyCooldown * 2.4 then
		data.DailyStreak = math.min(data.DailyStreak + 1, Config.DailyStreakMax)
	else
		data.DailyStreak = 1
	end
	data.LastDaily = now
	local reward = math.max(500 * data.DailyStreak, self.S.EconomyService:GetIncome(player) * 120 * data.DailyStreak)
	self.S.EconomyService:AddCash(player, reward)
	self:Notify(player, "🎁 Day " .. data.DailyStreak .. ": +" .. Format.money(reward) .. "! Come back tomorrow for more", Color3.fromRGB(255, 220, 90))
end

function SocialService:Start()
	self.S.DataService:OnLoaded(function(player)
		if Config.GroupId ~= 0 then
			local ok, inGroup = pcall(player.IsInGroup, player, Config.GroupId)
			player:SetAttribute("InGroup", ok and inGroup)
			if not (ok and inGroup) then
				task.delay(20, function()
					if player.Parent then
						self:Notify(player, "Join the group → +10% cash forever! 💜", Color3.fromRGB(200, 160, 255))
					end
				end)
			end
		end
		self:RecalcFriends()
		self:Notify(player, "Welcome to " .. Config.GameName .. " 💧 Buy slimes on the road!", Color3.fromRGB(255, 170, 240))
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			self:RecalcFriends()
		end)
	end)

	-- Подсказки для новичков и напоминание про друзей
	while true do
		task.wait(240)
		self:NotifyAll("👥 Play with friends: +10% cash for each friend on the server!", Color3.fromRGB(160, 220, 255))
	end
end

return SocialService
