--!nonstrict
-- Конвейер: слаймы появляются из портала и едут по дороге. Купи — и он прыгнет к тебе на базу.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Format = require(ReplicatedStorage.Shared.Format)

local SpawnService = {}
local active = {} :: { { model: Model, pos: number, sold: boolean, entry: any, price: number, phase: number } }
local luckyQueue = 0
local rng = Random.new()
local folder: Folder

function SpawnService:Init(S)
	self.S = S
	folder = Instance.new("Folder")
	folder.Name = "Conveyor"
	folder.Parent = Workspace
end

function SpawnService:QueueLucky(_player: Player)
	luckyQueue += 1
end

function SpawnService:RollRarity(luck: number, minRarity: number?): number
	local total = 0
	local weights = {}
	for i, r in Config.Rarities do
		local w = r.Weight
		if i >= 3 then
			w *= luck
		end
		if minRarity and i < minRarity then
			w = 0
		end
		weights[i] = w
		total += w
	end
	local roll = rng:NextNumber(0, total)
	for i, w in weights do
		roll -= w
		if roll <= 0 then
			return i
		end
	end
	return 1
end

function SpawnService:RollVariant(luck: number, seasonName: string?): string?
	local r = rng:NextNumber()
	local acc = 0
	for _, v in Config.VariantRoll do
		local def = Config.Variants[v.V]
		if not def.Season or def.Season == seasonName then
			local c = v.Chance
			if v.Luck then
				c *= luck
			end
			if v.Gold then
				c *= self.S.EventService:GetGoldMult()
			end
			acc += c
			if r < acc then
				return v.V
			end
		end
	end
	return nil
end

function SpawnService:RollEntry(minRarity: number?, luckMult: number?)
	local luck = self.S.EventService:GetLuck() * (luckMult or 1)
	local rarity = self:RollRarity(luck, minRarity)
	local season = self.S.EventService:Season()
	local seasonName = season and season.Name or nil
	local eventChance = if season then math.min(0.9, season.EventPetChance * self.S.EventService:SeasonMult()) else 0
	local pool = Pets.Pool(rarity, seasonName, eventChance, rng:NextNumber())
	while #pool == 0 and rarity > 1 do
		rarity -= 1
		pool = Pets.Pool(rarity, seasonName, eventChance, rng:NextNumber())
	end
	local def = pool[rng:NextInteger(1, #pool)]
	local variant = self:RollVariant(luck, seasonName)
	return { Id = def.Id, V = variant }, def
end

function SpawnService:Spawn(minRarity: number?, forced: any?)
	local entry, def
	if forced then
		entry, def = forced, Pets.ById[forced.Id]
	else
		entry, def = self:RollEntry(minRarity)
	end
	local price = self.S.EconomyService:PetValue(entry)
	local model = self.S.PetFactory:Build(entry, { Price = price, Scale = 1.6 })
	local item = { model = model, pos = 0, sold = false, entry = entry, price = price, phase = rng:NextNumber(0, 6) }

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy " .. Format.money(price)
	prompt.ObjectText = def.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		self:TryBuy(player, item)
	end)

	model.Parent = folder
	table.insert(active, item)

	if def.Rarity >= Config.AnnounceFromRarity or entry.V == "Rainbow" then
		local rarityName = Config.Rarities[def.Rarity].Name
		local prefix = if entry.V then Config.Variants[entry.V].Label .. " " else ""
		self.S.SocialService:NotifyAll("✨ A " .. prefix .. rarityName .. " " .. def.Name .. " appeared on the road! ✨", Config.Rarities[def.Rarity].Color, "Legendary")
	end
	return item
end

function SpawnService:TryBuy(player: Player, item)
	if item.sold then
		return
	end
	local Plot = self.S.PlotService
	if not Plot:GetPlot(player) then
		return
	end
	if not Plot:FreeSlot(player) then
		self.S.SocialService:Notify(player, "Base is full! Sell a slime or buy more slots in 🧰 Gear", Color3.fromRGB(255, 120, 120))
		return
	end
	if not self.S.EconomyService:TrySpend(player, item.price) then
		self.S.SocialService:Notify(player, "Not enough cash 💸", Color3.fromRGB(255, 120, 120))
		return
	end
	item.sold = true
	local slot = Plot:AddPet(player, item.entry)
	if not slot then
		self.S.EconomyService:AddCash(player, item.price)
		item.sold = false
		return
	end
	self.S.SocialService:PlaySound(player, "Buy")
	self.S.QuestService:Add(player, "Buy", 1)

	-- Прыжок слайма на базу (косметика); данные уже сохранены
	local model = item.model
	local prompt = model.PrimaryPart:FindFirstChild("BuyPrompt")
	if prompt then
		prompt:Destroy()
	end
	local plot = Plot:GetPlot(player)
	local ped = plot.Pedestals[tonumber(slot)]
	local from = model:GetPivot()
	local to = CFrame.new(ped.Position + Vector3.new(0, 3, 0))
	local t0 = os.clock()
	local DURATION = 1.4
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local a = math.min(1, (os.clock() - t0) / DURATION)
		local p = from.Position:Lerp(to.Position, a) + Vector3.new(0, math.sin(a * math.pi) * 25, 0)
		model:PivotTo(CFrame.new(p) * from.Rotation)
		if a >= 1 then
			conn:Disconnect()
			model:Destroy()
			if player.Parent then
				Plot:RenderSlot(player, slot)
			end
		end
	end)
	return slot
end

function SpawnService:Start()
	local roadStart = self.S.MapBuilder.RoadStart
	local roadEnd = self.S.MapBuilder.RoadEnd
	local length = (roadEnd - roadStart).Magnitude
	local dir = (roadEnd - roadStart).Unit

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for i = #active, 1, -1 do
			local item = active[i]
			if item.sold then
				table.remove(active, i)
			else
				item.pos += Config.ConveyorSpeed * dt
				if item.pos >= length then
					item.model:Destroy()
					table.remove(active, i)
				else
					local hop = math.abs(math.sin(now * 4 + item.phase)) * 1.2
					local base = roadStart + dir * item.pos
					local h = item.model.PrimaryPart.Size.Y * 0.6
					item.model:PivotTo(CFrame.new(base + Vector3.new(0, h + hop, 0)) * CFrame.Angles(0, now * 1.3 + item.phase, 0))
				end
			end
		end
	end)

	while true do
		if #Players:GetPlayers() > 0 then
			if luckyQueue > 0 then
				luckyQueue -= 1
				self:Spawn(5)
			elseif self.S.DirectorService:Enabled() then
				-- в режиме режиссёра дорогу заполняет сценарий + редкие слаймы
				if math.random() < 0.5 then
					self:Spawn(3)
				end
			elseif self.S.ShowcaseService:Enabled() then
				self:Spawn(4)
			else
				self:Spawn(nil)
			end
		end
		task.wait(Config.SpawnInterval)
	end
end

return SpawnService
