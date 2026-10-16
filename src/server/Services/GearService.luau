--!nonstrict
-- Gear Shop: снаряжение за игровые деньги. Куплено = навсегда (переживает ребёрт).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local GearService = {}
local byId = {}
local cloakReady = {} :: { [Player]: number }

local DEFAULT_JUMP = 7.2

function GearService:Init(S)
	self.S = S
	for _, g in Config.Gear do
		byId[g.Id] = g
	end
end

local function handle(color: Color3, size: Vector3, material: Enum.Material?): Part
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = size
	h.Color = color
	h.Material = material or Enum.Material.SmoothPlastic
	h.CanCollide = false
	h.Massless = true
	return h
end

local function humanoid(player: Player): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

function GearService:_makeTool(player: Player, id: string): Tool?
	local g = byId[id]
	if not g then
		return nil
	end
	local tool = Instance.new("Tool")
	tool.Name = g.Name
	tool.ToolTip = g.Desc
	tool.CanBeDropped = false
	tool:SetAttribute("GearId", id)

	if id == "SpeedCoil" then
		local h = handle(Color3.fromRGB(60, 200, 255), Vector3.new(0.6, 1.6, 0.6), Enum.Material.Neon)
		h.Parent = tool
		tool.Equipped:Connect(function()
			player:SetAttribute("GearSpeed", 8)
			self.S.ProgressionService:ApplySpeed(player)
		end)
		tool.Unequipped:Connect(function()
			player:SetAttribute("GearSpeed", 0)
			self.S.ProgressionService:ApplySpeed(player)
		end)
	elseif id == "GravityBoots" then
		local h = handle(Color3.fromRGB(120, 255, 120), Vector3.new(0.8, 0.8, 1.2), Enum.Material.Neon)
		h.Parent = tool
		tool.Equipped:Connect(function()
			local hum = humanoid(player)
			if hum then
				hum.UseJumpPower = false
				hum.JumpHeight = DEFAULT_JUMP * 2.2
			end
		end)
		tool.Unequipped:Connect(function()
			local hum = humanoid(player)
			if hum then
				hum.JumpHeight = DEFAULT_JUMP
			end
		end)
	elseif id == "MegaBat" then
		local h = handle(Color3.fromRGB(255, 200, 40), Vector3.new(5.5, 0.9, 0.9), Enum.Material.Foil)
		h.Shape = Enum.PartType.Cylinder
		h.Parent = tool
		tool.Grip = CFrame.new(-2.2, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		tool.Activated:Connect(function()
			self.S.StealService:Bonk(player, true)
		end)
	elseif id == "Cloak" then
		local h = handle(Color3.fromRGB(180, 160, 255), Vector3.new(1, 1, 1), Enum.Material.Glass)
		h.Transparency = 0.4
		h.Parent = tool
		tool.Activated:Connect(function()
			self:_cloak(player)
		end)
	end
	return tool
end

function GearService:_cloak(player: Player)
	local now = os.clock()
	if now < (cloakReady[player] or 0) then
		self.S.SocialService:Notify(player, "👻 Cloak recharging: " .. math.ceil(cloakReady[player] - now) .. "s", Color3.fromRGB(200, 180, 255))
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum then
		return
	end
	cloakReady[player] = now + 30
	local saved = {}
	for _, d in char:GetDescendants() do
		-- украденный слайм над головой остаётся видимым — честно для жертвы
		if (d:IsA("BasePart") or d:IsA("Decal")) and d.Name ~= "HumanoidRootPart" and d:FindFirstAncestorWhichIsA("Model") == char then
			saved[d] = d.Transparency
			d.Transparency = 1
		end
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	player:SetAttribute("Invisible", true)
	self.S.SocialService:Notify(player, "👻 You are invisible for 8 seconds!", Color3.fromRGB(200, 180, 255))
	task.delay(8, function()
		for d, t in saved do
			if d.Parent then
				d.Transparency = t
			end
		end
		if hum.Parent then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		end
		player:SetAttribute("Invisible", false)
	end)
end

function GearService:Give(player: Player)
	local data = self.S.DataService:Get(player)
	local backpack = player:FindFirstChild("Backpack")
	if not data or not backpack then
		return
	end
	for _, g in Config.Gear do
		if data.Gear and data.Gear[g.Id] and not backpack:FindFirstChild(g.Name) and not (player.Character and player.Character:FindFirstChild(g.Name)) then
			local tool = self:_makeTool(player, g.Id)
			if tool then
				tool.Parent = backpack
			end
		end
	end
end

function GearService:Buy(player: Player, id: any)
	local g = type(id) == "string" and byId[id]
	local data = self.S.DataService:Get(player)
	if not g or not data then
		return
	end
	data.Gear = data.Gear or {}
	if data.Gear[id] then
		return
	end
	if not self.S.EconomyService:TrySpend(player, g.Price) then
		self.S.SocialService:Notify(player, "You need " .. Format.money(g.Price), Color3.fromRGB(255, 120, 120))
		return
	end
	data.Gear[id] = true
	self:Give(player)
	self.S.SocialService:Notify(player, g.Icon .. " " .. g.Name .. " unlocked! Check your hotbar", Color3.fromRGB(140, 255, 200), "Buy")
	self.S.IndexService:SendMeta(player)
end

function GearService:Start()
	local function hook(player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("GearSpeed", 0)
			task.wait(0.6)
			self:Give(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	self.S.DataService:OnLoaded(function(player)
		task.wait(0.6)
		self:Give(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		cloakReady[p] = nil
	end)
end

return GearService
