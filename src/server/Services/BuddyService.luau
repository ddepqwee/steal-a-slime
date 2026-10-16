--!nonstrict
-- 🐾 Buddy: мини-копия лучшего слайма игрока бегает за ним (косметика, включается в Base).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BuddyService = {}
local buddies = {} :: { [Player]: { model: Model, key: string, cf: CFrame } }
local folder: Folder

function BuddyService:Init(S)
	self.S = S
	folder = Instance.new("Folder")
	folder.Name = "Buddies"
	folder.Parent = Workspace
end

function BuddyService:_best(player: Player)
	local data = self.S.DataService:Get(player)
	if not data or not data.Buddy then
		return nil
	end
	local best, bestIncome = nil, -1
	for _, e in data.Pets do
		local inc = self.S.EconomyService:PetIncome(e)
		if inc > bestIncome then
			best, bestIncome = e, inc
		end
	end
	return best
end

function BuddyService:_clear(player: Player)
	local b = buddies[player]
	if b then
		b.model:Destroy()
		buddies[player] = nil
	end
end

function BuddyService:Refresh(player: Player)
	local entry = self:_best(player)
	if not entry then
		self:_clear(player)
		return
	end
	local key = entry.Id .. "|" .. tostring(entry.V) .. "|" .. tostring(entry.M) .. "|" .. tostring(entry.L)
	local cur = buddies[player]
	if cur and cur.key == key and cur.model.Parent then
		return
	end
	self:_clear(player)
	local model = self.S.PetFactory:Build(entry, { Scale = 0.45 })
	local info = model.PrimaryPart:FindFirstChild("Info")
	if info then
		info.Size = UDim2.fromOffset(120, 40)
		info.MaxDistance = 40
		for _, l in info:GetChildren() do
			if l:IsA("TextLabel") and l.Name ~= "Name" then
				l:Destroy()
			end
		end
	end
	model.Parent = folder
	buddies[player] = { model = model, key = key, cf = model:GetPivot() }
end

function BuddyService:Start()
	self.S.DataService:OnLoaded(function(player)
		task.wait(2)
		self:Refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		self:_clear(p)
	end)
	-- плавное следование
	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		for player, b in buddies do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and b.model.Parent then
				local h = b.model.PrimaryPart.Size.Y * 0.6
				local target = root.CFrame * CFrame.new(3, -2.2 + h + math.abs(math.sin(t * 6)) * 0.6, 3.5)
				local pos = b.cf.Position:Lerp(target.Position, math.clamp(dt * 8, 0, 1))
				if (pos - target.Position).Magnitude > 40 then
					pos = target.Position -- телепорт игрока — догоняем мгновенно
				end
				b.cf = CFrame.lookAt(pos, pos + root.CFrame.LookVector)
				b.model:PivotTo(b.cf)
			end
		end
	end)
	-- раз в 5 сек проверяем, не появился ли слайм получше
	while true do
		task.wait(5)
		for player in self.S.DataService.Profiles do
			self:Refresh(player)
		end
	end
end

return BuddyService
