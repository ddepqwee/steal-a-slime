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
local PLOT_SPACING = 90 -- 34 шага между базами
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
	atm.Density = 0.22
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
	-- главный остров + песчаный берег + океан вокруг
	part({ Name = "Ground", Size = Vector3.new(600, 6, 460), Position = Vector3.new(0, -3, 0), Color = Color3.fromRGB(110, 205, 95), Material = Enum.Material.Grass })
	part({ Name = "Beach", Size = Vector3.new(640, 6, 500), Position = Vector3.new(0, -3.6, 0), Color = Color3.fromRGB(245, 225, 160), Material = Enum.Material.Sand })
	local terrain = Workspace.Terrain
	terrain.WaterColor = Color3.fromRGB(60, 170, 220)
	terrain.WaterTransparency = 0.35
	terrain.WaterWaveSize = 0.2
	terrain.WaterReflectance = 0.6
	pcall(function()
		terrain:FillBlock(CFrame.new(0, -14, 0), Vector3.new(3200, 20, 3200), Enum.Material.Water)
	end)
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
		part({ Name = "Walkway", Size = Vector3.new(roadLen, 0.3, 22), Position = Vector3.new(0, 0.15, side * (ROAD_WIDTH / 2 + 11.5)), Color = Color3.fromRGB(175, 165, 200), Material = Enum.Material.Pavement })
	end
	self.RoadStart = Vector3.new(-roadLen / 2 + 6, 0.4, 0)
	self.RoadEnd = Vector3.new(roadLen / 2 - 6, 0.4, 0)
	self.Roads = { Main = { Start = self.RoadStart, End = self.RoadEnd } }

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
	local pedFx = {}
	local slot = 0
	for row = 1, 3 do
		for col = 1, COLS do
			slot += 1
			local x = (col - (COLS + 1) / 2) * 7
			local z = ({ 6, 18, -6 })[row]
			local base = at(x, 0, z)
			local ring = part({ Name = "PedRing", Parent = model, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 6.4, 6.4), CFrame = base * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = accent, Material = Enum.Material.Neon, CanCollide = false })
			local ped = part({ Name = "Pedestal" .. slot, Parent = model, Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 5, 5), CFrame = base * CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Marble })
			-- светящийся ободок сверху + столб света (включается под редких слаймов)
			local rim = part({ Name = "PedRim", Parent = model, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 5.3, 5.3), CFrame = base * CFrame.new(0, 2.45, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = accent, Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.6 })
			local beam = part({ Name = "PedBeam", Parent = model, Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 4.4, 4.4), CFrame = base * CFrame.new(0, 10.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = accent, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Transparency = 1, CastShadow = false })
			local glow = Instance.new("PointLight")
			glow.Range = 0
			glow.Brightness = 2
			glow.Parent = rim
			ped:SetAttribute("Accent", accent)
			pedFx[slot] = { Ring = ring, Rim = rim, Beam = beam, Light = glow }
			ped:SetAttribute("Slot", slot)
			pedestals[slot] = ped
		end
	end

	-- Кнопка замка: круглая неоновая
	local padCF = at(-half + 6, 0, -half + 7)
	part({ Name = "LockPadBase", Parent = model, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 6.5, 6.5), CFrame = padCF * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 255, 255) })
	local lockPad = part({ Name = "LockPad", Parent = model, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 5, 5), CFrame = padCF * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 60, 90), Material = Enum.Material.Neon })
	local lockLabel = label(lockPad, "🔒 LOCK", UDim2.fromScale(7, 2.4), Vector3.new(0, 3.5, 0))

	local trapPad = part({ Name = "TrapPad", Parent = model, Size = Vector3.new(ENTRANCE_W - 1, 0.2, 5), CFrame = at(0, 1.1, -half + 3.5), Color = Color3.fromRGB(170, 70, 255), Material = Enum.Material.Neon, Transparency = 1, CanCollide = false, CanTouch = false })

	local plot = {
		PedFx = pedFx,
		TrapPad = trapPad,
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
		local pos = Vector3.new(rng:NextNumber(-285, 285), 0, rng:NextNumber(-215, 215))
		local inPlay = (math.abs(pos.X) < 245 and math.abs(pos.Z) < 115) or (pos.X > 200 and math.abs(pos.Z) < 60)
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

	local board2 = part({ Name = "StealsBoard", Size = Vector3.new(1, 22, 30), Position = Vector3.new(self.RoadEnd.X + 26, 13, 36), Color = Color3.fromRGB(70, 30, 40) })
	part({ Name = "BoardFrame", Size = Vector3.new(1.2, 23, 31), Position = board2.Position + Vector3.new(0.2, 0, 0), Color = Color3.fromRGB(255, 110, 70), Material = Enum.Material.Neon })
	local gui2 = gui:Clone()
	gui2.Parent = board2
	self.StealsLabel = gui2:FindFirstChild("List")
	self.StealsLabel.Text = "🦹 TOP THIEVES\n..."
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
		atm.Density = 0.26
	end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		cc.TintColor = Color3.fromRGB(255, 235, 225)
	end
	local rng = Random.new(31)
	-- тыквы вдоль дороги и у баз
	for x = -195, 195, 26 do
		for _, side in { -1, 1 } do
			pumpkin(Vector3.new(x + rng:NextNumber(-3, 3), 0.3, side * 17.5), rng:NextNumber(2, 3.2), rng)
		end
	end
	for _ = 1, 40 do
		local pos = Vector3.new(rng:NextNumber(-260, 260), 0, rng:NextNumber(-200, 200))
		if not (math.abs(pos.X) < 240 and math.abs(pos.Z) < 110) then
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

-- 🌍 Острова ребёртов: отдельные острова со своими дорогами, видны с главного острова
local function bigSign(pos: Vector3, text: string, color: Color3)
	local anchor = part({ Name = "IslandSign", Size = Vector3.new(1, 1, 1), Position = pos, Transparency = 1, CanCollide = false })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(70, 18)
	bb.MaxDistance = 3000
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color
	t.TextStrokeTransparency = 0
	t.Text = text
	t.Parent = bb
	bb.Parent = anchor
end

function MapBuilder:_landmark(zone, c: Vector3, len: number, rng: Random)
	local top = c.Y + 3
	if zone.Id == "Lava" then
		-- вулкан
		local vx = c.X + len * 0.3
		local vz = c.Z - 42 * math.sign(c.Z)
		for i = 0, 6 do
			local r = 70 - i * 9
			part({ Name = "Volcano", Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, r, r), CFrame = CFrame.new(vx, top + 4.5 + i * 9, vz) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(55 - i * 3, 35, 30), Material = Enum.Material.Basalt })
		end
		local crater = part({ Name = "Crater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 12, 12), CFrame = CFrame.new(vx, top + 63.6, vz) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 100, 10), Material = Enum.Material.Neon })
		local fire = Instance.new("Fire")
		fire.Size = 30
		fire.Heat = 30
		fire.Parent = crater
		local smoke = Instance.new("Smoke")
		smoke.Size = 40
		smoke.RiseVelocity = 12
		smoke.Opacity = 0.15
		smoke.Color = Color3.fromRGB(60, 50, 50)
		smoke.Parent = crater
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 120, 30)
		l.Range = 60
		l.Brightness = 3
		l.Parent = crater
	elseif zone.Id == "Crystal" then
		-- кристальный шпиль
		local sx = c.X - len * 0.3
		local sz = c.Z - 42 * math.sign(c.Z)
		for k = 1, 5 do
			local h = if k == 1 then 90 else rng:NextNumber(30, 55)
			local off = if k == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-14, 14), 0, rng:NextNumber(-14, 14))
			part({ Name = "Spire", Size = Vector3.new(if k == 1 then 12 else 6, h, if k == 1 then 12 else 6), CFrame = CFrame.new(Vector3.new(sx, top + h / 2 - 2, sz) + off) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 3), rng:NextNumber(-0.15, 0.15)), Color = if k % 2 == 0 then Color3.fromRGB(190, 120, 255) else Color3.fromRGB(120, 220, 255), Material = Enum.Material.Neon, Transparency = 0.1 })
		end
	elseif zone.Id == "Cloud" then
		-- радуга-арка и облачные холмы
		local colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 240, 80), Color3.fromRGB(90, 230, 110), Color3.fromRGB(80, 160, 255), Color3.fromRGB(170, 90, 255) }
		for band, col in colors do
			local r = 60 - band * 4
			for k = 0, 20 do
				local a = k / 20 * math.pi
				part({ Name = "Rainbow", Size = Vector3.new(4, 4.5, 4), Position = Vector3.new(c.X + math.cos(a) * r, top + math.sin(a) * r, c.Z + 48), Color = col, Material = Enum.Material.Neon, CanCollide = false })
			end
		end
		for _ = 1, 30 do
			local sz = rng:NextNumber(14, 28)
			part({ Name = "CloudPuff", Shape = Enum.PartType.Ball, Size = Vector3.new(sz, sz, sz), Position = Vector3.new(c.X + rng:NextNumber(-len / 2 - 20, len / 2 + 20), c.Y - rng:NextNumber(2, 10), c.Z + (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(55, 75)), Color = Color3.new(1, 1, 1), CastShadow = false })
		end
	elseif zone.Id == "Cosmic" then
		-- планеты с кольцами и звёзды
		for k = 1, 4 do
			local r = rng:NextNumber(16, 34)
			local pos = Vector3.new(c.X + rng:NextNumber(-len / 2, len / 2), top + rng:NextNumber(45, 90), c.Z + rng:NextNumber(-90, 90))
			local col = ({ Color3.fromRGB(255, 120, 60), Color3.fromRGB(90, 200, 255), Color3.fromRGB(200, 90, 255), Color3.fromRGB(255, 220, 120) })[k]
			part({ Name = "Planet", Shape = Enum.PartType.Ball, Size = Vector3.new(r, r, r), Position = pos, Color = col, Material = Enum.Material.Neon, CanCollide = false })
			part({ Name = "PlanetRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, r * 1.8, r * 1.8), CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(70), 0, math.rad(90)), Color = col:Lerp(Color3.new(1, 1, 1), 0.4), Material = Enum.Material.Neon, Transparency = 0.4, CanCollide = false })
		end
		local stars = part({ Name = "Starfield", Size = Vector3.new(len, 1, 200), Position = Vector3.new(c.X, top + 60, c.Z), Transparency = 1, CanCollide = false })
		local pe = Instance.new("ParticleEmitter")
		pe.Rate = 40
		pe.Lifetime = NumberRange.new(4, 7)
		pe.Speed = NumberRange.new(0, 1)
		pe.LightEmission = 1
		pe.Size = NumberSequence.new(0.6, 0)
		pe.Parent = stars
	end
end

function MapBuilder:_zones()
	self.ZonePads = {}
	for zi, zone in Config.Zones do
		local c = Vector3.new(zone.X, zone.Y, zone.Z)
		local len = 380
		local top = c.Y + 3
		local floating = c.Y > 10
		local rng = Random.new(100 + zi)
		-- тело острова
		part({ Name = "IslandTop", Size = Vector3.new(len + 60, 14, 150), Position = Vector3.new(c.X, top - 7, c.Z), Color = zone.Floor, Material = zone.Mat })
		part({ Name = "IslandEdge", Size = Vector3.new(len + 64, 4, 154), Position = Vector3.new(c.X, top - 12, c.Z), Color = zone.Floor:Lerp(Color3.new(0, 0, 0), 0.3), Material = zone.Mat })
		if floating then
			-- скалистое «днище» парящего острова
			for k = 1, 4 do
				local w = (len + 40) * (1 - k * 0.2)
				part({ Name = "IslandRoot", Size = Vector3.new(w, 10, 140 * (1 - k * 0.2)), Position = Vector3.new(c.X, top - 14 - k * 9, c.Z), Color = Color3.fromRGB(120, 100, 90):Lerp(zone.Floor, 0.3), Material = Enum.Material.Rock })
			end
		end
		-- дорога
		part({ Name = "ZoneRoad", Size = Vector3.new(len, 0.4, ROAD_WIDTH), Position = Vector3.new(c.X, top + 0.2, c.Z), Color = zone.Road })
		for _, side in { -1, 1 } do
			part({ Name = "ZoneRail", Size = Vector3.new(len, 0.4, 0.6), Position = Vector3.new(c.X, top + 0.5, c.Z + side * (ROAD_WIDTH / 2 + 0.5)), Color = zone.Accent, Material = Enum.Material.Neon, CanCollide = false })
		end
		for x = -len / 2 + 10, len / 2 - 10, 14 do
			for _, a in { 35, -35 } do
				part({ Name = "Arrow", Size = Vector3.new(4, 0.1, 1), CFrame = CFrame.new(c.X + x, top + 0.45, c.Z) * CFrame.Angles(0, math.rad(a), 0), Color = zone.Accent, Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.4 })
			end
		end
		-- декор
		for _ = 1, 30 do
			local x = c.X + rng:NextNumber(-len / 2, len / 2)
			local z = c.Z + (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(22, 60)
			if zone.Id == "Lava" then
				if rng:NextNumber() < 0.5 then
					local r = rng:NextNumber(8, 16)
					local pool = part({ Name = "Lava", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, r, r), CFrame = CFrame.new(x, top + 0.1, z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 90, 10), Material = Enum.Material.Neon, CanCollide = false })
					local l = Instance.new("PointLight")
					l.Color = Color3.fromRGB(255, 110, 30)
					l.Range = r * 1.5
					l.Brightness = 2
					l.Parent = pool
				else
					local h = rng:NextNumber(6, 18)
					part({ Name = "Rock", Size = Vector3.new(rng:NextNumber(4, 8), h, rng:NextNumber(4, 8)), CFrame = CFrame.new(x, top + h / 2, z) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)), Color = Color3.fromRGB(45, 30, 30), Material = Enum.Material.Basalt })
				end
			elseif zone.Id == "Crystal" then
				local h = rng:NextNumber(8, 24)
				part({ Name = "Crystal", Size = Vector3.new(rng:NextNumber(2.5, 5), h, rng:NextNumber(2.5, 5)), CFrame = CFrame.new(x, top + h / 2 - 1, z) * CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, 3), rng:NextNumber(-0.35, 0.35)), Color = if rng:NextNumber() < 0.5 then Color3.fromRGB(120, 220, 255) else Color3.fromRGB(190, 120, 255), Material = Enum.Material.Neon, Transparency = 0.15, CanCollide = false })
			elseif zone.Id == "Cloud" then
				local sz = rng:NextNumber(6, 14)
				part({ Name = "Fluff", Shape = Enum.PartType.Ball, Size = Vector3.new(sz, sz, sz), Position = Vector3.new(x, top + sz * 0.2, z), Color = Color3.fromRGB(255, 255, 255):Lerp(zone.Accent, rng:NextNumber(0, 0.4)), CanCollide = false })
			elseif zone.Id == "Cosmic" then
				local h = rng:NextNumber(4, 14)
				part({ Name = "Obelisk", Size = Vector3.new(2, h, 2), CFrame = CFrame.new(x, top + h / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = if rng:NextNumber() < 0.5 then zone.Accent else Color3.fromRGB(90, 200, 255), Material = Enum.Material.Neon })
			end
		end
		self:_landmark(zone, c, len, rng)

		local start = Vector3.new(c.X - len / 2 + 6, top + 0.4, c.Z)
		self.Roads[zone.Id] = { Start = start, End = Vector3.new(c.X + len / 2 - 6, top + 0.4, c.Z), Zone = zone }
		bigSign(Vector3.new(c.X, top + 70, c.Z), zone.Name .. "\n🔒 Rebirth " .. zone.Rebirth .. "+", zone.Accent)
		-- возврат на базу
		local back = part({ Name = "ReturnPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 9, 9), CFrame = CFrame.new(start + Vector3.new(8, -0.1, 24)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 255, 160), Material = Enum.Material.Neon })
		label(back, "🏠 BACK TO BASE", UDim2.fromScale(12, 3), Vector3.new(0, 5, 0), Color3.fromRGB(140, 255, 170))
		-- портал в лобби у начала главной дороги
		local padZ = ({ -26, 26, -54, 54 })[zi] or (zi * 20)
		local padPos = Vector3.new(self.RoadStart.X + 14, 0.5, padZ)
		local pad = part({ Name = "ZonePad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 10, 10), CFrame = CFrame.new(padPos) * CFrame.Angles(0, 0, math.rad(90)), Color = zone.Accent, Material = Enum.Material.Neon })
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			part({ Name = "PadRing", Size = Vector3.new(1.4, 1.4, 1.4), Position = padPos + Vector3.new(math.cos(a) * 6.5, 6 + math.sin(a) * 6.5, 0), Color = zone.Accent, Material = Enum.Material.Neon, CanCollide = false })
		end
		label(pad, zone.Name .. "\n🔒 Rebirth " .. zone.Rebirth, UDim2.fromScale(14, 5), Vector3.new(0, 15, 0), zone.Accent)
		table.insert(self.ZonePads, { Zone = zone, Pad = pad, Return = back, Arrive = CFrame.new(start + Vector3.new(14, 3, 18)) })
	end
end

-- 🗼 Sky Obby: спиральная паркур-башня с сундуком наверху
function MapBuilder:_obby()
	local cfg = Config.Obby
	local center = Vector3.new(self.RoadEnd.X + 75, 0, 0)
	part({ Name = "ObbyPillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(cfg.Stages * 4.6 + 8, 8, 8), CFrame = CFrame.new(center + Vector3.new(0, (cfg.Stages * 4.6 + 8) / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(250, 245, 255), Material = Enum.Material.Marble })
	local colors = { Color3.fromRGB(255, 90, 160), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 210, 60), Color3.fromRGB(120, 255, 140), Color3.fromRGB(180, 120, 255) }
	local last
	for i = 1, cfg.Stages do
		local a = i * math.rad(32)
		local r = 15
		local y = i * 4.6
		local size = if i < 10 then 7 elseif i < 19 then 5.5 else 4.2
		local pos = center + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
		last = part({ Name = "ObbyStep", Size = Vector3.new(size, 1, size), CFrame = CFrame.new(pos) * CFrame.Angles(0, -a, 0), Color = colors[(i % #colors) + 1], Material = Enum.Material.Neon })
	end
	local top = last.Position + Vector3.new(0, 4, 0)
	local plat = part({ Name = "ObbyTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 22, 22), CFrame = CFrame.new(center + Vector3.new(0, top.Y - 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 220, 90), Material = Enum.Material.Foil })
	local chest = part({ Name = "ObbyChest", Size = Vector3.new(5, 3.5, 3.5), Position = plat.Position + Vector3.new(0, 2.4, 0), Color = Color3.fromRGB(150, 90, 40), Material = Enum.Material.Wood })
	part({ Name = "ChestLid", Size = Vector3.new(5.2, 1, 3.7), Position = chest.Position + Vector3.new(0, 2.2, 0), Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Foil })
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 220, 90)
	l.Range = 20
	l.Brightness = 2
	l.Parent = chest
	local sign = part({ Name = "ObbySign", Size = Vector3.new(1, 1, 1), Position = center + Vector3.new(0, 14, 0), Transparency = 1, CanCollide = false })
	label(sign, "🗼 SKY OBBY\n🎁 Chest at the top!", UDim2.fromScale(16, 6), Vector3.zero, Color3.fromRGB(255, 230, 120))
	self.ObbyChest = chest
end

function MapBuilder:Init()
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = Workspace
	self:_lighting()
	self:_ground()
	local depth = ROAD_WIDTH / 2 + 22 + PLOT_SIZE / 2
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
	self:_zones()
	self:_obby()
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
