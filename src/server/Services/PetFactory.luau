--!nonstrict
-- Собирает 3D-модель слайма из примитивов: тело, блик, глаза, корона, свечение, частицы.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Format = require(ReplicatedStorage.Shared.Format)

local PetFactory = {}

function PetFactory:Init(S)
	self.S = S
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function ball(model: Model, root: BasePart?, size: number, color: Color3, offset: CFrame, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(size, size, size)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = root == nil
	p.CFrame = if root then root.CFrame * offset else offset
	p.Parent = model
	if root then
		weld(root, p)
	end
	return p
end

local function cyl(model: Model, root: BasePart, size: Vector3, color: Color3, offset: CFrame): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CFrame = root.CFrame * offset
	p.Parent = model
	weld(root, p)
	return p
end

-- entry = { Id, V }, opts = { Price = number? }
function PetFactory:Build(entry, opts): Model
	opts = opts or {}
	local def = Pets.ById[entry.Id]
	local variant = entry.V and Config.Variants[entry.V]
	local rarity = Config.Rarities[def.Rarity]
	local model = Instance.new("Model")
	model.Name = def.Name
	local s = def.Size * (opts.Scale or 1)
	local color = if variant then variant.Color else def.Color

	local mat = Enum.Material.SmoothPlastic
	if def.Neon then
		mat = Enum.Material.Neon
	elseif def.Glass then
		mat = Enum.Material.Glass
	elseif entry.V == "Gold" then
		mat = Enum.Material.Foil
	end

	-- Корень — невидимый хитбокс, чтобы ProximityPrompt был стабильным
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(s, s * 0.8, s)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.Parent = model
	model.PrimaryPart = root

	-- Тело «капля»: сплюснутый шар + верхушка
	local body = ball(model, root, s, color, CFrame.new(0, 0, 0), mat)
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(s, s, s)
	body.Transparency = if def.Glass then 0.25 else 0
	local top = ball(model, root, s * 0.62, color, CFrame.new(0, s * 0.38, 0), mat)
	top.Transparency = body.Transparency
	-- Блик
	ball(model, root, s * 0.22, Color3.new(1, 1, 1), CFrame.new(-s * 0.22, s * 0.35, -s * 0.33), Enum.Material.Neon).Transparency = 0.3
	if def.Ghost then
		body.Transparency = 0.3
		top.Transparency = 0.3
		body.Material = Enum.Material.SmoothPlastic
		top.Material = Enum.Material.SmoothPlastic
	end
	if def.Stripes then
		-- кэнди-корн: белая верхушка и оранжевый пояс
		top.Color = Color3.fromRGB(255, 250, 235)
		local band = cyl(model, root, Vector3.new(s * 0.22, s * 1.02, s * 1.02), Color3.fromRGB(255, 110, 20), CFrame.new(0, -s * 0.08, 0) * CFrame.Angles(0, 0, math.rad(90)))
		band.Material = Enum.Material.SmoothPlastic
	end
	if def.Pumpkin then
		-- светящееся вырезанное лицо + хвостик
		for _, side in { -1, 1 } do
			local eye = ball(model, root, s * 0.2, Color3.fromRGB(255, 220, 60), CFrame.new(side * s * 0.2, s * 0.14, -s * 0.44), Enum.Material.Neon)
			eye.Size = Vector3.new(s * 0.22, s * 0.16, s * 0.1)
			eye.Shape = Enum.PartType.Block
			eye.CFrame = root.CFrame * CFrame.new(side * s * 0.2, s * 0.14, -s * 0.46) * CFrame.Angles(0, 0, math.rad(side * 25))
		end
		local mouth = ball(model, root, s * 0.1, Color3.fromRGB(255, 220, 60), CFrame.new(0, -s * 0.12, -s * 0.46), Enum.Material.Neon)
		mouth.Shape = Enum.PartType.Block
		mouth.Size = Vector3.new(s * 0.5, s * 0.1, s * 0.1)
		mouth.CFrame = root.CFrame * CFrame.new(0, -s * 0.12, -s * 0.46)
		cyl(model, root, Vector3.new(s * 0.3, s * 0.12, s * 0.12), Color3.fromRGB(70, 140, 50), CFrame.new(0, s * 0.72, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 150, 40)
		glow.Range = 12
		glow.Brightness = 2
		glow.Parent = body
	else
		-- Глаза
		for _, side in { -1, 1 } do
			ball(model, root, s * 0.3, Color3.new(1, 1, 1), CFrame.new(side * s * 0.2, s * 0.12, -s * 0.4))
			local pupil = ball(model, root, s * 0.16, Color3.fromRGB(20, 20, 30), CFrame.new(side * s * 0.2, s * 0.12, -s * 0.53))
			if def.Glitch then
				pupil.Color = Color3.fromRGB(255, 0, 60)
				pupil.Material = Enum.Material.Neon
			end
		end
		-- Румянец
		for _, side in { -1, 1 } do
			local cheek = ball(model, root, s * 0.14, Color3.fromRGB(255, 120, 150), CFrame.new(side * s * 0.34, -s * 0.05, -s * 0.36))
			cheek.Transparency = 0.35
		end
	end
	if def.WitchHat then
		local hatColor = Color3.fromRGB(35, 20, 50)
		cyl(model, root, Vector3.new(s * 0.06, s * 1.0, s * 1.0), hatColor, CFrame.new(0, s * 0.66, 0) * CFrame.Angles(0, 0, math.rad(90)))
		local band = cyl(model, root, Vector3.new(s * 0.1, s * 0.56, s * 0.56), Color3.fromRGB(170, 70, 255), CFrame.new(0, s * 0.73, 0) * CFrame.Angles(0, 0, math.rad(90)))
		band.Material = Enum.Material.Neon
		local steps = 9
		for i = 1, steps do
			local k = 0.5 * (1 - (i - 1) / steps)
			local lean = (i / steps) ^ 2 * s * 0.18
			cyl(model, root, Vector3.new(s * 0.09, s * k, s * k), hatColor, CFrame.new(-lean, s * (0.72 + i * 0.075), 0) * CFrame.Angles(0, 0, math.rad(90)))
		end
	end
	-- Корона
	if def.Crown then
		local crown = Instance.new("Part")
		crown.Shape = Enum.PartType.Cylinder
		crown.Size = Vector3.new(s * 0.25, s * 0.45, s * 0.45)
		crown.Color = Color3.fromRGB(255, 205, 40)
		crown.Material = Enum.Material.Foil
		crown.CanCollide = false
		crown.Massless = true
		crown.CFrame = root.CFrame * CFrame.new(0, s * 0.78, 0) * CFrame.Angles(0, 0, math.rad(90))
		crown.Parent = model
		weld(root, crown)
	end

	-- Свечение по редкости
	if def.Rarity >= 4 or variant then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 6 + def.Rarity * 2
		light.Brightness = 1.5
		light.Parent = body
	end
	if def.Sparkle or def.Rarity >= 5 or variant then
		local pe = Instance.new("ParticleEmitter")
		pe.Rate = 6 + def.Rarity * 2
		pe.Lifetime = NumberRange.new(0.8, 1.6)
		pe.Speed = NumberRange.new(1, 3)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.LightEmission = 1
		pe.Size = NumberSequence.new(0.35, 0)
		pe.Color = ColorSequence.new(rarity.Color)
		pe.Parent = body
	end
	if entry.V == "Rainbow" or def.Glitch then
		CollectionService:AddTag(body, "Rainbow")
		CollectionService:AddTag(top, "Rainbow")
	end
	CollectionService:AddTag(model, "Slime")

	-- Табличка
	local bb = Instance.new("BillboardGui")
	bb.Name = "Info"
	bb.Size = UDim2.fromOffset(200, 74)
	bb.StudsOffset = Vector3.new(0, s * 0.9 + 1.6, 0)
	bb.MaxDistance = 70
	bb.LightInfluence = 0
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = bb
	local function line(name, text, color, h)
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, h)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = color
		t.TextStrokeTransparency = 0
		t.Text = text
		t.Parent = bb
		return t
	end
	local rarityText = rarity.Name
	if variant then
		rarityText = variant.Label .. " " .. rarityText
	end
	if def.Event == "Halloween" then
		rarityText = "🎃 " .. rarityText
	end
	line("Rarity", rarityText, if variant then variant.Color else rarity.Color, 16)
	local lvl = entry.L or 1
	line("Name", def.Name .. (if lvl > 1 then "  " .. string.rep("⭐", math.min(lvl - 1, 3)) .. (if lvl > 4 then " Lv." .. lvl else "") else ""), Color3.new(1, 1, 1), 22)
	line("Income", Format.money(self.S.EconomyService:PetIncome(entry)) .. "/s", Color3.fromRGB(120, 255, 120), 18)
	if opts.Price then
		line("Price", Format.money(opts.Price), Color3.fromRGB(255, 230, 90), 18)
	end
	bb.Parent = root

	model:SetAttribute("PetId", entry.Id)
	model:SetAttribute("Variant", entry.V or "")
	return model
end

return PetFactory
