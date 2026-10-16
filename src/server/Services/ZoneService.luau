--!nonstrict
-- Порталы в зоны (по ребёртам), возврат на базу, сундук Sky Obby и титулы над головой.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Pets = require(ReplicatedStorage.Shared.Pets)

local ZoneService = {}
local debounce = {} :: { [Player]: number }

function ZoneService:Init(S)
	self.S = S
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	return model and Players:GetPlayerFromCharacter(model)
end

local function ready(player: Player): boolean
	local now = os.clock()
	if now - (debounce[player] or 0) < 1.5 then
		return false
	end
	debounce[player] = now
	return true
end

function ZoneService:Enter(player: Player, z)
	local data = self.S.DataService:Get(player)
	if not data or not player.Character then
		return
	end
	if data.Rebirths < z.Zone.Rebirth then
		self.S.SocialService:Notify(player, "🔒 " .. z.Zone.Name .. " unlocks at Rebirth " .. z.Zone.Rebirth .. " (you have " .. data.Rebirths .. ")", z.Zone.Accent)
		return
	end
	if player:GetAttribute("Carrying") then
		self.S.SocialService:Notify(player, "You can't use portals while carrying a slime!", Color3.fromRGB(255, 120, 120))
		return
	end
	player.Character:PivotTo(z.Arrive)
	player:SetAttribute("Zone", z.Zone.Id)
	self.S.SocialService:Notify(player, "Welcome to " .. z.Zone.Name .. "! Exclusive slimes spawn here 🌟", z.Zone.Accent)
end

function ZoneService:Return(player: Player)
	-- нельзя «телепортировать» украденного слайма домой
	if player:GetAttribute("Carrying") then
		self.S.StealService:Drop(player)
	end
	local plot = self.S.PlotService:GetPlot(player)
	if plot and player.Character then
		player.Character:PivotTo(plot.SpawnCFrame)
	end
	player:SetAttribute("Zone", nil)
end

-- Сундук на вершине обби
function ZoneService:OpenChest(player: Player)
	local cfg = Config.Obby
	local now = os.time()
	local data = self.S.DataService:Get(player)
	if not data then
		return
	end
	local left = (data.ObbyChestAt or 0) - now
	if left > 0 then
		self.S.SocialService:Notify(player, "🎁 Chest refills in " .. Format.time(left), Color3.fromRGB(255, 220, 120))
		return
	end
	data.ObbyChestAt = now + cfg.Cooldown
	self.S.DataService:Stat(player, "ObbyWins")
	local reward = math.floor(math.max(cfg.RewardMin, self.S.EconomyService:GetIncome(player) * 60 * cfg.RewardMinutes))
	self.S.EconomyService:AddCash(player, reward)
	self.S.SocialService:NotifyAll("🗼 " .. player.DisplayName .. " beat the SKY OBBY and opened the chest!", Color3.fromRGB(255, 230, 120))
	self.S.SocialService:Notify(player, "🎁 +" .. Format.money(reward) .. "!", Color3.fromRGB(255, 230, 90), "Buy")
	if math.random() < cfg.SlimeChance then
		local entry = self.S.SpawnService:RollEntry(4, 1.5)
		if self.S.WorldEventService:_grant(player, entry) then
			local def = Pets.ById[entry.Id]
			self.S.SocialService:Notify(player, "🎁 Bonus slime: " .. def.Name .. "!", Config.Rarities[def.Rarity].Color)
		end
	end
	-- спуск вниз к основанию башни
	task.delay(1.5, function()
		local chest = self.S.MapBuilder.ObbyChest
		if player.Character and chest then
			player.Character:PivotTo(CFrame.new(chest.Position.X + 22, 5, chest.Position.Z))
		end
	end)
end

-- 🏷️ Титулы над головой
local TITLES = {
	{ Text = "👑 SLIME LEGEND", Color = Color3.fromRGB(255, 220, 80), Check = function(d)
		return d.Rebirths >= 10
	end },
	{ Text = "🦹 MASTER THIEF", Color = Color3.fromRGB(255, 120, 80), Check = function(d)
		return (d.Steals or 0) >= 50
	end },
	{ Text = "📖 COLLECTOR", Color = Color3.fromRGB(140, 220, 255), Check = function(d, S)
		return S.IndexService:Count(d) >= math.floor(#Pets.List * 0.6)
	end },
	{ Text = "♻️ REBORN", Color = Color3.fromRGB(200, 150, 255), Check = function(d)
		return d.Rebirths >= 3
	end },
	{ Text = "🦝 SNEAKY", Color = Color3.fromRGB(255, 190, 120), Check = function(d)
		return (d.Steals or 0) >= 10
	end },
	{ Text = "🫧 NEWBIE", Color = Color3.fromRGB(220, 220, 230), Check = function()
		return true
	end },
}

function ZoneService:UpdateTitle(player: Player)
	local data = self.S.DataService:Get(player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not data or not head then
		return
	end
	local chosen = TITLES[#TITLES]
	for _, t in TITLES do
		if t.Check(data, self.S) then
			chosen = t
			break
		end
	end
	local vip = self.S.MonetizationService:HasPass(player, "VIP")
	local bb = head:FindFirstChild("TitleTag")
	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = "TitleTag"
		bb.Size = UDim2.fromOffset(200, 26)
		bb.StudsOffset = Vector3.new(0, 2.6, 0)
		bb.MaxDistance = 80
		bb.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextStrokeTransparency = 0
		t.Parent = bb
		bb.Parent = head
	end
	bb.Text.Text = (if vip then "⭐ VIP · " else "") .. chosen.Text
	bb.Text.TextColor3 = chosen.Color
end

function ZoneService:Start()
	for _, z in self.S.MapBuilder.ZonePads do
		z.Pad.Touched:Connect(function(hit)
			local p = playerFromHit(hit)
			if p and ready(p) then
				self:Enter(p, z)
			end
		end)
		z.Return.Touched:Connect(function(hit)
			local p = playerFromHit(hit)
			if p and ready(p) then
				self:Return(p)
			end
		end)
	end
	local chest = self.S.MapBuilder.ObbyChest
	if chest then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open Chest"
		prompt.ObjectText = "Sky Obby Reward"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = chest
		prompt.Triggered:Connect(function(p)
			self:OpenChest(p)
		end)
	end

	local function hook(player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Zone", nil)
			task.wait(1)
			self:UpdateTitle(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	self.S.DataService:OnLoaded(function(player)
		task.wait(2)
		self:UpdateTitle(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		debounce[p] = nil
	end)
	-- упал в океан → домой на базу
	task.spawn(function()
		while true do
			task.wait(1)
			for _, p in Players:GetPlayers() do
				local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				if r and r.Position.Y < -1.5 then
					self:Return(p)
					self.S.SocialService:Notify(p, "🌊 Splash! Back to your base", Color3.fromRGB(120, 200, 255))
				end
			end
		end
	end)
	while true do
		task.wait(30)
		for player in self.S.DataService.Profiles do
			self:UpdateTitle(player)
		end
	end
end

return ZoneService
