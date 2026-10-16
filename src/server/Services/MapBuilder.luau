--!nonstrict
-- Вся карта строится кодом при старте сервера: земля, дорога-конвейер,
-- 8 открытых баз игроков, порталы, деревья, доска лидеров, освещение.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}
MapBuilder.Plots = {}

local PLOT_SIZE = 56
local PLOT_SPACING = 66
local ROAD_WIDTH = 24
local WALL_H = 4 -- низкие бортики: база открытая, видно дорогу
local LOCK_H = 30 -- высота силового поля, когда база закрыта
local ENTRANCE_W = 14
local COLS = 7

-- Пары цветов: основной (пол) и акцент (бортики/неон)
local THEMES = {
	{ Color3.fromRGB(255, 170, 210), Color3.fromRGB(255, 70, 160) },
	{ Color3.fromRGB(160, 210, 255), Color3.fromRGB(40, 130, 255) },
	{ Color3.fromRGB(170, 240, 160), Color3.fromRGB(40, 200, 90) },
	{ Color3.fromRGB(255, 225, 140), Color3.fromRGB(255, 160, 0) },
	{ Color3.fromRGB(210, 180, 255), Color3.fromRGB(140, 70, 255) },
	{ Color3.fromRGB(150, 245, 230), Color3.fromRGB(0, 200, 180) },
	{ Color3.fromRGB(255, 190, 160), Color3.fromRGB(255, 90, 50) },
	{ Color3.fromRGB(190, 200, 255), Color3.fromRGB(80, 90, 255) },
}

local mapFolder: Folder

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent or mapFolder
	return p
end

local function darker(c: Color3, k: number): Color3
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

local function label(parent: Instance, text: string, size: UDim2, offset: Vector3, color: Color3?)
	local bb = Instance.new("BillboardGui")
	bb.Size = size
	bb.StudsOffset = offset
	bb.MaxDistance = 220
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.Text = text
	t.Parent = bb
	bb.Parent = parent
	return bb
end

-- Табличка-вывеска с SurfaceGui на обеих сторонах
local function signBoard(parent: Instance, cf: CFrame, size: Vector3, bg: Color3, text: string)
	local board = part({ Name = "SignBoard", Parent = parent, Size = size, CFrame = cf, Color = bg, Material = Enum.Material.SmoothPlastic })
	local labels = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0
		t.TextStrokeColor3 = darker(bg, 0.4)
		t.Text = text
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.05, 0)
		pad.PaddingRight = UDim.new(0.05, 0)
		pad.PaddingTop = UDim.new(0.1, 0)
		pad.PaddingBottom = UDim.new(0.1, 0)
		pad.Parent = t
		t.Parent = gui
		gui.Parent = board
		table.insert(labels, t)
	end
	return board, labels
end

function MapBuilder:_lighting()
	Lighting:ClearAllChildren()
	Lighting.ClockTime = 15.2
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2
	Lighting.ExposureCompensation = -0.35
	Lighting.Ambient = Color3.fromRGB(60, 55, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 105, 140)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.32
	atm.Offset = 0.2
	atm.Haze = 0.6
	atm.Glare = 0.3
	atm.Color = Color3.fromRGB(200, 215, 255)
	atm.Decay = Color3.fromRGB(255, 160, 220)
	atm.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 16
	bloom.Threshold = 2.4
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.22
	cc.Contrast = 0.15
	cc.Brightness = 0
	cc.TintColor = Color3.fromRGB(255, 248, 255)
	cc.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.03
	rays.Spread = 0.6
	rays.Parent = Lighting
	local sky = Instance.new("Sky")
	sky.SunAngularSize = 12
	sky.Parent = Lighting
end

function MapBuilder:_ground()
	part({ Name = "Ground", Size = Vector3.new(900, 4, 900), Position = Vector3.new(0, -2, 0), Color = Color3.fromRGB(110, 205, 95), Material = Enum.Material.Grass })
	local roadLen = PLOT_SPACING * 4 + 70
	-- Дорога: тёмная лента + светящиеся бортики + бегущие стрелки
	part({ Name = "Road", Size = Vector3.new(roadLen, 0.4, ROAD_WIDTH), Position = Vector3.new(0, 0.2, 0), Color = Color3.fromRGB(55, 45, 80), Material = Enum.Material.SmoothPlastic })
	part({ Name = "RoadInner", Size = Vector3.new(roadLen, 0.42, ROAD_WIDTH - 6), Position = Vector3.new(0, 0.21, 0), Color = Color3.fromRGB(75, 60, 110), Material = Enum.Material.SmoothPlastic })
	for x = -roadLen / 2 + 8, roadLen / 2 - 8, 12 do
		for _, a in { 35, -35 } do
			part({ Name = "Arrow", Size = Vector3.new(4, 0.1, 1), CFrame = CFrame.new(x, 0.47, 0) * CFrame.Angles(0, math.rad(a), 0), Color = Color3.fromRGB(255, 120, 230), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.45 })
		end
	end
	for _, side in { -1, 1 } do
		part({ Name = "Rail", Size = Vector3.new(roadLen, 1, 1.2), Position = Vector3.new(0, 0.7, side * (ROAD_WIDTH / 2 + 0.6)), Color = Color3.fromRGB(225, 225, 235) })
		part({ Name = "RailGlow", Size = Vector3.new(roadLen, 0.2, 0.4), Position = Vector3.new(0, 1.25, side * (ROAD_WIDTH / 2 + 0.6)), Color = Color3.fromRGB(90, 170, 255), Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.35 })
	end
	-- Тротуар между дорогой и базами
	for _, side in { -1, 1 } do
		part({ Name = "Walkway", Size = Vector3.new(roadLen, 0.3, 8), Position = Vector3.new(0, 0.15, side * (ROAD_WIDTH / 2 + 5)), Color = Color3.fromRGB(175, 165, 200), Material = Enum.Material.Pavement })
	end
	self.RoadStart = Vector3.new(-roadLen / 2 + 6, 0.4, 0)
	self.RoadEnd = Vector3.new(roadLen / 2 - 6, 0.4, 0)

	-- Порталы-кольца на концах дороги
	for i, x in { self.RoadStart.X - 2, self.RoadEnd.X + 2 } do
		local color = if i == 1 then Color3.fromRGB(80, 255, 200) else Color3.fromRGB(255, 80, 180)
		local center = Vector3.new(x, 13, 0)
		local segments = 20
		local radius = 13
		for s = 0, segments - 1 do
			local a = s / segments * math.pi * 2
			local pos = center + Vector3.new(0, math.sin(a) * radius, math.cos(a) * radius)
			part({ Name = "Ring", Size = Vector3.new(2.5, 2.5, 4.4), CFrame = CFrame.new(pos) * CFrame.Angles(-a, 0, 0), Color = color, Material = Enum.Material.Neon, CanCollide = false })
		end
		local field = part({ Name = "PortalField", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, radius * 2, radius * 2), CFrame = CFrame.new(center), Color = color, Material = Enum.Material.ForceField, Transparency = 0.2, CanCollide = false })
		local pe = Instance.new("ParticleEmitter")
		pe.Rate = 25
		pe.Lifetime = NumberRange.new(1, 2)
		pe.Speed = NumberRange.new(2, 6)
		pe.LightEmission = 1
		pe.Color = ColorSequence.new(color)
		pe.Size = NumberSequence.new(0.7, 0)
		pe.Parent = field
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 30
		light.Brightness = 2
		light.Parent = field
	end
	local titleAnchor = part({ Name = "TitleAnchor", Size = Vector3.new(1, 1, 1), Position = Vector3.new(self.RoadStart.X - 2, 31, 0), Transparency = 1, CanCollide = false })
	label(titleAnchor, "🫧 STEAL A SLIME 🫧", UDim2.fromScale(36, 7), Vector3.zero, Color3.fromRGB(255, 160, 240))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.6, 10)
	spawn.Position = Vector3.new(0, 0.7, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = mapFolder
end

function MapBuilder:_plot(index: number, center: Vector3, facing: Vector3)
	local cf = CFrame.lookAt(center, center + facing)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = mapFolder
	local half = PLOT_SIZE / 2
	local main, accent = THEMES[index][1], THEMES[index][2]
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end

	-- Пол: шахматная плитка двух оттенков
	part({ Name = "Floor", Parent = model, Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE), CFrame = at(0, 0.5, 0), Color = darker(main, 0.78) })
	local TILE = 8
	local n = PLOT_SIZE // TILE
	for ix = 0, n - 1 do
		for iz = 0, n - 1 do
			if (ix + iz) % 2 == 0 then
				local x = -half + TILE / 2 + ix * TILE
				local z = -half + TILE / 2 + iz * TILE
				part({ Name = "Tile", Parent = model, Size = Vector3.new(TILE, 0.05, TILE), CFrame = at(x, 1.02, z), Color = darker(main, 0.9), CanCollide = false, CanQuery = false })
			end
		end
	end

	-- Низкие бортики с неоновой полосой
	local function wall(size: Vector3, pos: CFrame)
		part({ Name = "Wall", Parent = model, Size = size, CFrame = pos, Color = Color3.fromRGB(235, 235, 245) })
		part({ Name = "Trim", Parent = model, Size = Vector3.new(size.X + 0.1, 0.4, size.Z + 0.1), CFrame = pos * CFrame.new(0, size.Y / 2 + 0.2, 0), Color = accent, Material = Enum.Material.Neon, CanCollide = false })
	end
	local sideW = (PLOT_SIZE - ENTRANCE_W) / 2
	wall(Vector3.new(PLOT_SIZE, WALL_H, 1.5), at(0, WALL_H / 2 + 1, half))
	wall(Vector3.new(1.5, WALL_H, PLOT_SIZE), at(-half, WALL_H / 2 + 1, 0))
	wall(Vector3.new(1.5, WALL_H, PLOT_SIZE), at(half, WALL_H / 2 + 1, 0))
	for _, s in { -1, 1 } do
		wall(Vector3.new(sideW, WALL_H, 1.5), at(s * (ENTRANCE_W / 2 + sideW / 2), WALL_H / 2 + 1, -half))
	end
	-- Угловые столбики-фонари
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local base = at(c[1] * half, 0, c[2] * half)
		part({ Name = "Post", Parent = model, Size = Vector3.new(2.4, 8, 2.4), CFrame = base * CFrame.new(0, 5, 0), Color = Color3.fromRGB(255, 255, 255) })
		local lamp = part({ Name = "Lamp", Parent = model, Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = base * CFrame.new(0, 10, 0), Color = accent, Material = Enum.Material.Neon, CanCollide = false })
		local light = Instance.new("PointLight")
		light.Color = accent
		light.Range = 18
		light.Brightness = 1.2
		light.Parent = lamp
	end

	-- Арка над входом с вывеской владельца
	for _, s in { -1, 1 } do
		part({ Name = "ArchPost", Parent = model, Size = Vector3.new(1.6, 14, 1.6), CFrame = at(s * (ENTRANCE_W / 2 + 0.8), 8, -half), Color = accent, Material = Enum.Material.SmoothPlastic })
	end
	local _, signLabels = signBoard(model, at(0, 14.5, -half), Vector3.new(ENTRANCE_W + 10, 4.5, 0.8), accent, "Free Base")

	-- Силовое поле замка: по периметру, появляется только когда база закрыта
	local lockWalls = {}
	local function lockWall(size: Vector3, pos: CFrame)
		local w = part({ Name = "LockWall", Parent = model, Size = size, CFrame = pos, Color = Color3.fromRGB(255, 50, 90), Material = Enum.Material.ForceField, Transparency = 1, CanCollide = false })
		table.insert(lockWalls, w)
	end
	lockWall(Vector3.new(PLOT_SIZE, LOCK_H, 0.6), at(0, LOCK_H / 2 + 1, -half - 1))
	lockWall(Vector3.new(PLOT_SIZE, LOCK_H, 0.6), at(0, LOCK_H / 2 + 1, half + 1))
	lockWall(Vector3.new(0.6, LOCK_H, PLOT_SIZE), at(-half - 1, LOCK_H / 2 + 1, 0))
	lockWall(Vector3.new(0.6, LOCK_H, PLOT_SIZE), at(half + 1, LOCK_H / 2 + 1, 0))
	lockWall(Vector3.new(PLOT_SIZE + 2, 0.6, PLOT_SIZE + 2), at(0, LOCK_H + 1, 0))

	-- Пьедесталы: круглые подиумы с неоновым кольцом
	local pedestals = {}
	local slot = 0
	for row = 1, 3 do
		for col = 1, COLS do
			slot += 1
			local x = (col - (COLS + 1) / 2) * 7
			local z = ({ 6, 18, -6 })[row]
			local base = at(x, 0, z)
			part({ Name = "PedRing", Parent = model, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 6, 6), CFrame = base * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = accent, Material = Enum.Material.Neon, CanCollide = false })
			local ped = part({ Name = "Pedestal" .. slot, Parent = model, Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 5, 5), CFrame = base * CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic })
			ped:SetAttribute("Slot", slot)
			pedestals[slot] = ped
		end
	end

	-- Кнопка замка: круглая неоновая
	local padCF = at(-half + 6, 0, -half + 7)
	part({ Name = "LockPadBase", Parent = model, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 6.5, 6.5), CFrame = padCF * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 255, 255) })
	local lockPad = part({ Name = "LockPad", Parent = model, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 5, 5), CFrame = padCF * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 60, 90), Material = Enum.Material.Neon })
	local lockLabel = label(lockPad, "🔒 LOCK", UDim2.fromScale(7, 2.4), Vector3.new(0, 3.5, 0))

	local plot = {
		Index = index,
		CFrame = cf,
		Model = model,
		Pedestals = pedestals,
		LockWalls = lockWalls,
		SignLabels = signLabels,
		LockPad = lockPad,
		LockLabel = lockLabel.Text,
		SpawnCFrame = at(0, 4, -half + 10) * CFrame.Angles(0, math.pi, 0),
		Half = half,
	}
	table.insert(self.Plots, plot)
end

function MapBuilder:_trees()
	local rng = Random.new(1337)
	local leaves = { Color3.fromRGB(255, 160, 210), Color3.fromRGB(130, 225, 110), Color3.fromRGB(180, 140, 255), Color3.fromRGB(255, 200, 110) }
	local placed = 0
	while placed < 110 do
		local pos = Vector3.new(rng:NextNumber(-420, 420), 0, rng:NextNumber(-420, 420))
		local inPlay = math.abs(pos.X) < 205 and math.abs(pos.Z) < 105
		if not inPlay then
			placed += 1
			local h = rng:NextNumber(9, 18)
			part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 2.4, 2.4), CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(140, 95, 65) })
			local color = leaves[rng:NextInteger(1, #leaves)]
			local r = rng:NextNumber(8, 13)
			part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(r, r, r), Position = pos + Vector3.new(0, h + r * 0.25, 0), Color = color })
			part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(r * 0.7, r * 0.7, r * 0.7), Position = pos + Vector3.new(r * 0.4, h + r * 0.55, r * 0.2), Color = darker(color, 1.08) })
		end
	end
	-- Облака
	for _ = 1, 18 do
		local c = Vector3.new(rng:NextNumber(-380, 380), rng:NextNumber(90, 140), rng:NextNumber(-380, 380))
		for k = 1, 4 do
			local s = rng:NextNumber(14, 26)
			part({ Name = "Cloud", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), Position = c + Vector3.new((k - 2.5) * 12, rng:NextNumber(-3, 3), rng:NextNumber(-5, 5)), Color = Color3.new(1, 1, 1), CanCollide = false, CastShadow = false, Transparency = 0.05 })
		end
	end
end

function MapBuilder:_board()
	local board = part({ Name = "Leaderboard", Size = Vector3.new(1, 22, 30), Position = Vector3.new(self.RoadEnd.X + 26, 13, 0), Color = Color3.fromRGB(45, 30, 70) })
	part({ Name = "BoardFrame", Size = Vector3.new(1.2, 23, 31), Position = board.Position + Vector3.new(0.2, 0, 0), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Neon })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui.LightInfluence = 0
	gui.Parent = board
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(1, 1)
	list.Font = Enum.Font.FredokaOne
	list.TextScaled = true
	list.TextColor3 = Color3.new(1, 1, 1)
	list.Text = "🏆 TOP EARNERS\n..."
	list.Parent = gui
	self.BoardLabel = list
end

-- 🎃 Хэллоуин: закатный свет, тыквы, оранжевые фонари, летучие мыши
local function pumpkin(pos: Vector3, size: number, rng: Random)
	local body = part({ Name = "Pumpkin", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), Position = pos + Vector3.new(0, size / 2, 0), Color = Color3.fromRGB(255, 120, 20), CanCollide = false })
	body.Shape = Enum.PartType.Ball
	part({ Name = "Stem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(size * 0.3, size * 0.15, size * 0.15), CFrame = CFrame.new(pos + Vector3.new(0, size * 1.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 130, 50) })
	local yaw = rng:NextNumber(0, math.pi * 2)
	local face = CFrame.new(body.Position) * CFrame.Angles(0, yaw, 0)
	for _, side in { -1, 1 } do
		part({ Name = "PumpkinEye", Size = Vector3.new(size * 0.22, size * 0.18, 0.2), CFrame = face * CFrame.new(side * size * 0.2, size * 0.1, -size * 0.45) * CFrame.Angles(0, 0, math.rad(side * 25)), Color = Color3.fromRGB(255, 220, 70), Material = Enum.Material.Neon, CanCollide = false })
	end
	part({ Name = "PumpkinMouth", Size = Vector3.new(size * 0.55, size * 0.12, 0.2), CFrame = face * CFrame.new(0, -size * 0.13, -size * 0.46), Color = Color3.fromRGB(255, 220, 70), Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 40)
	light.Range = size * 3
	light.Brightness = 1.5
	light.Parent = body
end

function MapBuilder:_halloween()
	Lighting.ClockTime = 17.6
	Lighting.Brightness = 1.6
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 90, 130)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		atm.Color = Color3.fromRGB(255, 170, 120)
		atm.Decay = Color3.fromRGB(120, 60, 160)
		atm.Density = 0.38
	end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		cc.TintColor = Color3.fromRGB(255, 235, 225)
	end
	local rng = Random.new(31)
	-- тыквы вдоль дороги и у баз
	for x = -150, 150, 22 do
		for _, side in { -1, 1 } do
			pumpkin(Vector3.new(x + rng:NextNumber(-3, 3), 0.3, side * 17.5), rng:NextNumber(2, 3.2), rng)
		end
	end
	for _ = 1, 40 do
		local pos = Vector3.new(rng:NextNumber(-260, 260), 0, rng:NextNumber(-200, 200))
		if not (math.abs(pos.X) < 175 and math.abs(pos.Z) < 95) then
			pumpkin(pos, rng:NextNumber(3, 7), rng)
		end
	end
	-- фонари баз в оранжевый
	for _, d in mapFolder:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Lamp" then
			d.Color = Color3.fromRGB(255, 140, 30)
			local l = d:FindFirstChildOfClass("PointLight")
			if l then
				l.Color = Color3.fromRGB(255, 140, 30)
				l.Range = 22
			end
		end
	end
	local sign = part({ Name = "HalloweenSign", Size = Vector3.new(1, 1, 1), Position = Vector3.new(self.RoadStart.X - 2, 37, 0), Transparency = 1, CanCollide = false })
	label(sign, "🎃 HALLOWEEN EVENT 🎃", UDim2.fromScale(30, 5), Vector3.zero, Color3.fromRGB(255, 150, 40))
end

function MapBuilder:Init()
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = Workspace
	self:_lighting()
	self:_ground()
	local depth = ROAD_WIDTH / 2 + 10 + PLOT_SIZE / 2
	local idx = 0
	for _, side in { 1, -1 } do
		for i = 1, 4 do
			idx += 1
			local x = (i - 2.5) * PLOT_SPACING
			self:_plot(idx, Vector3.new(x, 0, side * depth), Vector3.new(0, 0, -side))
		end
	end
	self:_trees()
	self:_board()
	local season = Config.Season
	local now = os.time()
	if season and season.Name == "Halloween" and now >= season.Start and now < season.End then
		self:_halloween()
	end
end

function MapBuilder:IsInPlot(plot, position: Vector3): boolean
	local p = plot.CFrame:PointToObjectSpace(position)
	return math.abs(p.X) < plot.Half and math.abs(p.Z) < plot.Half and p.Y < 40
end

return MapBuilder
