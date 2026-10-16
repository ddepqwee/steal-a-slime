--!nonstrict
-- 🎨 Интерфейс v2: единая дизайн-система (3D-кнопки, карточки, вкладки, бейджи),
-- всё в «дизайн-пикселях» и масштабируется UIScale под любой экран (ПК / телефон / планшет).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local HUD: any = {}
local state = nil
local gui: ScreenGui
local root: Frame -- весь HUD живёт в root, который масштабируется целиком
local rootScale: UIScale

-- ===================== Дизайн-токены =====================
local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local C = {
	Ink = Color3.fromRGB(26, 14, 46),
	Body = Color3.fromRGB(52, 38, 98),
	Body2 = Color3.fromRGB(30, 22, 62),
	Card = Color3.fromRGB(62, 48, 116),
	CardHi = Color3.fromRGB(84, 66, 150),
	Well = Color3.fromRGB(24, 16, 48),
	Sub = Color3.fromRGB(206, 196, 245),
	Gold = Color3.fromRGB(255, 205, 60),
	Green = Color3.fromRGB(70, 214, 96),
	Lime = Color3.fromRGB(170, 255, 120),
	Red = Color3.fromRGB(255, 70, 92),
	Blue = Color3.fromRGB(64, 156, 255),
	Purple = Color3.fromRGB(160, 92, 255),
	Orange = Color3.fromRGB(255, 146, 36),
	Pink = Color3.fromRGB(255, 104, 196),
	Teal = Color3.fromRGB(36, 206, 170),
	Gray = Color3.fromRGB(110, 104, 140),
}

local function lighten(c: Color3, a: number): Color3
	return c:Lerp(WHITE, a)
end
local function darken(c: Color3, a: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), a)
end

local function new(class: string, props, parent)
	local o = Instance.new(class)
	for k, v in props do
		o[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end

local function corner(p, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 12) }, p)
end
local function round(p)
	return new("UICorner", { CornerRadius = UDim.new(1, 0) }, p)
end
local function stroke(p, color, t, trans)
	return new("UIStroke", {
		Color = color or C.Ink,
		Thickness = t or 3,
		Transparency = trans or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, p)
end
local function grad(p, top: Color3, bottom: Color3, rot: number?)
	return new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rot or 90 }, p)
end
local function frame(parent, props)
	local f = new("Frame", { BorderSizePixel = 0, BackgroundTransparency = 1 }, nil)
	for k, v in props or {} do
		f[k] = v
	end
	f.Parent = parent
	return f
end

-- Текст с аккуратной обводкой (UIStroke вместо старого TextStroke)
local function label(parent, txt: string, size: number, props)
	local t = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = FONT,
		Text = txt,
		TextColor3 = WHITE,
		TextSize = size,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 1),
	}, nil)
	for k, v in props or {} do
		t[k] = v
	end
	new("UIStroke", { Color = C.Ink, Thickness = if size >= 28 then 3 elseif size >= 18 then 2 else 1.5 }, t)
	t.Parent = parent
	return t
end
-- Подгон текста под коробку, но не крупнее maxSize (чтобы размеры шрифтов были согласованы)
local function fit(t, maxSize: number, minSize: number?)
	t.TextScaled = true
	new("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = minSize or 8 }, t)
	return t
end
local function textStroke(t, color: Color3)
	local s = t:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = color
	end
end
local function emoji(parent, txt: string, size: number, props)
	local t = label(parent, txt, size, props)
	t:FindFirstChildOfClass("UIStroke"):Destroy()
	return t
end

-- ===================== Масштаб под экран =====================
-- Приём: root размером (1/s, 1/s) экрана + UIScale s → ровно весь экран,
-- а все позиции и размеры внутри масштабируются вместе (ничего не наезжает).
local function updateScale()
	local cam = Workspace.CurrentCamera
	if not cam or not root then
		return
	end
	local vp = cam.ViewportSize
	local s = math.clamp(math.min(vp.X / 1180, vp.Y / 700), 0.5, 1.15)
	rootScale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
end

local function playSound(id: string)
	if id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0.6
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

-- ===================== 3D-кнопка =====================
-- opts: Text, Color, Size, Position, AnchorPoint, TextSize, LayoutOrder, Radius, Depth, OnClick
local function btn(parent, opts)
	local depth = opts.Depth or 5
	local radius = opts.Radius or 12
	local color = opts.Color or C.Green
	local root = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = opts.Size or UDim2.fromOffset(120, 44),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		LayoutOrder = opts.LayoutOrder or 0,
	}, parent)
	local base = frame(root, { BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1) })
	corner(base, radius)
	stroke(base, C.Ink, 3)
	local face = frame(root, { BackgroundTransparency = 0, Size = UDim2.new(1, 0, 1, -depth) })
	corner(face, radius)
	local g = grad(face, WHITE, WHITE)
	local shine = frame(face, { BackgroundTransparency = 0.8, BackgroundColor3 = WHITE, Position = UDim2.fromOffset(5, 3), Size = UDim2.new(1, -10, 0.38, 0) })
	corner(shine, math.max(2, radius - 4))
	local lbl = label(face, opts.Text or "", opts.TextSize or 20, { Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(5, 2), TextWrapped = false })
	fit(lbl, opts.TextSize or 20, 8)

	local obj = { Root = root, Face = face, Label = lbl }
	function obj.SetColor(c: Color3)
		face.BackgroundColor3 = WHITE -- UIGradient умножается на цвет фона, поэтому фон белый
		g.Color = ColorSequence.new(lighten(c, 0.28), c)
		base.BackgroundColor3 = darken(c, 0.45)
		textStroke(lbl, darken(c, 0.62))
	end
	function obj.SetText(s: string)
		lbl.Text = s
	end
	obj.SetColor(color)

	local function up()
		face.Position = UDim2.new()
		shine.BackgroundTransparency = 0.8
	end
	root.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, depth - 1)
	end)
	root.MouseButton1Up:Connect(up)
	root.MouseLeave:Connect(up)
	root.MouseEnter:Connect(function()
		shine.BackgroundTransparency = 0.65
	end)
	root.Activated:Connect(function()
		up()
		if opts.OnClick then
			opts.OnClick()
		end
	end)
	return obj
end

-- Круглый слайм-аватар с глазками (для индекса, фьюза, хэтча)
local function slimeIcon(parent, color: Color3, size: number, props)
	local body = frame(parent, { BackgroundTransparency = 0, BackgroundColor3 = WHITE, Size = UDim2.fromOffset(size, size * 0.86) })
	for k, v in props or {} do
		body[k] = v
	end
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, body)
	grad(body, lighten(color, 0.35), darken(color, 0.15))
	stroke(body, darken(color, 0.6), math.max(2, size / 22))
	local shine = frame(body, { BackgroundTransparency = 0.45, BackgroundColor3 = WHITE, Position = UDim2.fromScale(0.18, 0.12), Size = UDim2.fromScale(0.26, 0.16) })
	round(shine)
	for _, x in { 0.33, 0.67 } do
		local eye = frame(body, { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(25, 20, 30), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.52), Size = UDim2.fromScale(0.15, 0.2) })
		round(eye)
		local glint = frame(eye, { BackgroundTransparency = 0, BackgroundColor3 = WHITE, Position = UDim2.fromScale(0.5, 0.15), Size = UDim2.fromScale(0.38, 0.32) })
		round(glint)
	end
	return body
end

-- Полоса прогресса
local function bar(parent, color: Color3, props)
	local well = frame(parent, { BackgroundTransparency = 0, BackgroundColor3 = C.Well, Size = UDim2.new(1, 0, 0, 18) })
	for k, v in props or {} do
		well[k] = v
	end
	round(well)
	stroke(well, C.Ink, 2)
	local fill = frame(well, { BackgroundTransparency = 0, BackgroundColor3 = WHITE, Size = UDim2.fromScale(0, 1) })
	round(fill)
	grad(fill, lighten(color, 0.35), color)
	local txt = label(well, "", 13, { TextWrapped = false })
	fit(txt, 14, 7)
	return function(frac: number, s: string?)
		fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
		fill.Visible = frac > 0.001
		txt.Text = s or ""
	end
end

-- Строка-карточка: иконка слева, заголовок, подпись, место справа под кнопку
-- opts: Height, Color, Icon, Title, Sub, RightWidth, LayoutOrder, Size
local function card(parent, opts)
	local h = opts.Height or 80
	local f = frame(parent, {
		BackgroundTransparency = 0,
		BackgroundColor3 = WHITE,
		Size = opts.Size or UDim2.new(1, 0, 0, h),
		LayoutOrder = opts.LayoutOrder or 0,
	})
	corner(f, 16)
	stroke(f, C.Ink, 3)
	local bg = grad(f, C.CardHi, C.Card)
	local accent = opts.Color or C.Purple
	local tileSize = opts.TileSize or (h - 18)
	local tile = frame(f, { BackgroundTransparency = 0, BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), Size = UDim2.fromOffset(tileSize, tileSize) })
	corner(tile, 12)
	local tileStroke = stroke(tile, darken(accent, 0.55), 2.5)
	local tileGrad = grad(tile, lighten(accent, 0.3), darken(accent, 0.12))
	local iconL = emoji(tile, opts.Icon or "", math.floor(tileSize * 0.58), {})
	local image = new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), Image = "", ScaleType = Enum.ScaleType.Fit }, tile)
	corner(image, 10)
	local tx = 9 + tileSize + 12
	local right = opts.RightWidth or 0
	local titleH = opts.TitleH or math.floor((h - 16) * 0.48)
	local title = label(f, opts.Title or "", 22, { Position = UDim2.fromOffset(tx, 8), Size = UDim2.new(1, -tx - right - 12, 0, titleH), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false })
	fit(title, 22, 10)
	local sub = label(f, opts.Sub or "", 16, {
		Position = UDim2.fromOffset(tx, 8 + titleH),
		Size = UDim2.new(1, -tx - right - 12, 0, h - 16 - titleH),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = C.Sub,
	})
	fit(sub, 16, 9)
	local obj = { Frame = f, Tile = tile, Icon = iconL, Image = image, Title = title, Sub = sub, X = tx, Right = right }
	function obj.SetAccent(c: Color3)
		tileStroke.Color = darken(c, 0.55)
		tileGrad.Color = ColorSequence.new(lighten(c, 0.3), darken(c, 0.12))
	end
	function obj.SetDone(on: boolean)
		bg.Color = if on then ColorSequence.new(Color3.fromRGB(60, 120, 80), Color3.fromRGB(40, 90, 60)) else ColorSequence.new(C.CardHi, C.Card)
	end
	obj.SetAccent(accent)
	return obj
end

local function chip(parent, txt: string, color: Color3, props)
	local f = frame(parent, { BackgroundTransparency = 0, BackgroundColor3 = WHITE, Size = UDim2.fromOffset(120, 30), AutomaticSize = Enum.AutomaticSize.X })
	for k, v in props or {} do
		f[k] = v
	end
	round(f)
	stroke(f, C.Ink, 2.5)
	local g = grad(f, lighten(color, 0.2), darken(color, 0.15))
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, f)
	local t = label(f, txt, 17, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false })
	textStroke(t, darken(color, 0.65))
	return f, t, function(c: Color3)
		g.Color = ColorSequence.new(lighten(c, 0.2), darken(c, 0.15))
		textStroke(t, darken(c, 0.65))
	end
end

local function header(parent, txt: string, order: number, color: Color3?)
	local t = label(parent, txt, 22, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order, TextColor3 = color or C.Gold, TextXAlignment = Enum.TextXAlignment.Left })
	return t
end

local function scroll(parent, cell: UDim2?, props)
	local sf = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.CardHi,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
	}, nil)
	for k, v in props or {} do
		sf[k] = v
	end
	new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, sf)
	if cell then
		new("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	else
		new("UIListLayout", { Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	end
	sf.Parent = parent
	return sf
end

local function clear(sf)
	for _, c in sf:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- ===================== Панели =====================
local panels = {}
local function closeAll()
	for _, p in panels do
		p.Frame.Visible = false
	end
end
local function openPanel(p)
	closeAll()
	p.Frame.Visible = true
	p.Scale.Scale = 0.82
	TweenService:Create(p.Scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if p.OnOpen then
		p.OnOpen()
	end
end
local function togglePanel(p)
	if p.Frame.Visible then
		p.Frame.Visible = false
	else
		openPanel(p)
	end
end

local function makePanel(name: string, icon: string, title: string, accent: Color3, w: number?, h: number?)
	local W: number = w or 720
	local H: number = h or 480
	local f = frame(root, {
		Name = name,
		BackgroundTransparency = 0,
		BackgroundColor3 = WHITE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(W, H),
		Visible = false,
		ZIndex = 5,
	})
	corner(f, 24)
	stroke(f, C.Ink, 5)
	grad(f, C.Body, C.Body2)
	local rim = frame(f, { Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4) })
	corner(rim, 21)
	stroke(rim, WHITE, 2, 0.88)

	local head = frame(f, { BackgroundTransparency = 0, BackgroundColor3 = WHITE, Size = UDim2.new(1, 0, 0, 68) })
	corner(head, 24)
	local top, bottom = lighten(accent, 0.22), darken(accent, 0.08)
	grad(head, top, bottom)
	local fill = frame(head, { BackgroundTransparency = 0, BackgroundColor3 = WHITE, Position = UDim2.new(0, 0, 1, -24), Size = UDim2.new(1, 0, 0, 24) })
	grad(fill, top:Lerp(bottom, 44 / 68), bottom)
	frame(head, { BackgroundTransparency = 0, BackgroundColor3 = C.Ink, Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 4) })
	-- лёгкие диагональные «блики» в шапке
	for i = 0, 2 do
		local s = frame(head, { BackgroundTransparency = 0.9, BackgroundColor3 = WHITE, Position = UDim2.new(0.55 + i * 0.09, 0, -0.4, 0), Size = UDim2.new(0, 22, 1.8, 0), Rotation = 25 })
		s.ClipsDescendants = false
	end
	head.ClipsDescendants = true
	emoji(head, icon, 40, { Size = UDim2.fromOffset(58, 58), Position = UDim2.fromOffset(16, 5) })
	local titleL = label(head, title, 36, { Size = UDim2.new(1, -330, 0, 52), Position = UDim2.fromOffset(78, 8), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false })
	fit(titleL, 36, 14)
	textStroke(titleL, darken(accent, 0.65))
	local sub = label(head, "", 19, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -64, 0.5, 0), Size = UDim2.fromOffset(250, 34), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false })
	fit(sub, 19, 9)
	textStroke(sub, darken(accent, 0.65))

	local body = frame(f, { Position = UDim2.fromOffset(18, 86), Size = UDim2.new(1, -36, 1, -102) })
	local p = { Frame = f, Body = body, Sub = sub, Accent = accent }
	btn(f, {
		Text = "✕",
		Color = C.Red,
		Size = UDim2.fromOffset(56, 56),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -10, 0, 10),
		TextSize = 30,
		Radius = 28,
		OnClick = function()
			f.Visible = false
		end,
	})
	p.Scale = new("UIScale", {}, f)
	table.insert(panels, p)
	return p
end

-- Вкладки: tabs = { {Name, Color}, ... } → возвращает массив content-фреймов
local function makeTabs(body, tabs)
	local row = frame(body, { Size = UDim2.new(1, 0, 0, 46) })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local pages, buttons = {}, {}
	local function select(i)
		for k, pg in pages do
			pg.Visible = k == i
			buttons[k].SetColor(if k == i then tabs[k].Color else C.Gray)
		end
	end
	for i, t in tabs do
		pages[i] = frame(body, { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -56), Visible = i == 1 })
		buttons[i] = btn(row, {
			Text = t.Name,
			Color = t.Color,
			Size = UDim2.new(1 / #tabs, -8 + 8 / #tabs, 1, 0),
			TextSize = 19,
			LayoutOrder = i,
			Depth = 4,
			OnClick = function()
				select(i)
			end,
		})
	end
	select(1)
	return pages, select
end

-- ===================== Тосты =====================
local toastHolder
local function toast(msg: string, color: Color3)
	if msg == "" then
		return
	end
	local pill = frame(toastHolder, { BackgroundTransparency = 0.12, BackgroundColor3 = C.Body2, Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X })
	round(pill)
	local st = stroke(pill, color, 2.5)
	new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, pill)
	local t = label(pill, msg, 19, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, TextColor3 = color })
	local sc = new("UIScale", { Scale = 0.6 }, pill)
	TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(4, function()
		local info = TweenInfo.new(0.4)
		TweenService:Create(pill, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(st, info, { Transparency = 1 }):Play()
		TweenService:Create(t, info, { TextTransparency = 1 }):Play()
		local s = t:FindFirstChildOfClass("UIStroke")
		if s then
			TweenService:Create(s, info, { Transparency = 1 }):Play()
		end
		task.wait(0.45)
		pill:Destroy()
	end)
	local items = {}
	for _, c in toastHolder:GetChildren() do
		if c:IsA("Frame") then
			table.insert(items, c)
		end
	end
	if #items > 5 then
		items[1]:Destroy()
	end
end

-- Описания карточек магазина (короче и понятнее, чем в Config)
local SHOP_ICONS = {
	DoubleCash = "💸",
	VIP = "👑",
	ExtraSlots = "🫧",
	LongLock = "🔒",
	CashSmall = "💵",
	CashBig = "🏦",
	LuckySpawn = "🍀",
	ServerLuck = "🌟",
}
local SHOP_BLURB = {
	DoubleCash = "x2 cash from every slime. Forever!",
	VIP = "+20% cash, faster walk & a shiny VIP tag",
	ExtraSlots = "+3 slime pedestals on your base",
	LongLock = "Your base lock lasts twice as long",
	LuckySpawn = "Instant Legendary+ slime on your base! 1% Celestial · 4% Secret · 21% Mythic",
	ServerLuck = "x2 luck for EVERYONE for 15 minutes",
}
local SHOP_RIBBON = { VIP = { "BEST", C.Gold }, DoubleCash = { "POPULAR", C.Red }, LuckySpawn = { "HOT", C.Pink } }
local SHOP_ORDER = { VIP = 1, DoubleCash = 2, ExtraSlots = 3, LongLock = 4, LuckySpawn = 1, CashBig = 2, ServerLuck = 3, CashSmall = 4 }

-- ===================== Сборка =====================
function HUD.Build()
	gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	HUD.Gui = gui
	root = frame(gui, { Name = "Root", Size = UDim2.fromScale(1, 1) })
	rootScale = new("UIScale", {}, root)
	HUD.Root = root
	updateScale()
	local Action = Net.event("Action")

	-- ---------- Верх: деньги ----------
	local top = frame(root, { BackgroundTransparency = 0, BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(290, 70) })
	round(top)
	stroke(top, C.Ink, 4)
	grad(top, Color3.fromRGB(64, 52, 120), Color3.fromRGB(34, 26, 70))
	local coin = frame(top, { BackgroundTransparency = 0, BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Size = UDim2.fromOffset(56, 56) })
	round(coin)
	stroke(coin, Color3.fromRGB(150, 90, 0), 3)
	grad(coin, Color3.fromRGB(255, 236, 120), Color3.fromRGB(255, 170, 20))
	local coinT = label(coin, "$", 34, { TextColor3 = Color3.fromRGB(255, 255, 230) })
	textStroke(coinT, Color3.fromRGB(150, 80, 0))
	local cash = label(top, "$0", 36, { Size = UDim2.new(1, -86, 0, 40), Position = UDim2.fromOffset(72, 4), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false })
	fit(cash, 36, 14)
	local income = label(top, "+$0/s", 18, { Size = UDim2.new(1, -86, 0, 22), Position = UDim2.fromOffset(72, 42), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Lime, TextWrapped = false })
	fit(income, 18, 9)
	local cashScale = new("UIScale", {}, coin)

	-- ---------- Ряд инфо-чипов под деньгами ----------
	local infoRow = frame(root, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 86), Size = UDim2.fromOffset(900, 30) })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, infoRow)
	HUD.SlotsPill = infoRow
	local _, slotsT = chip(infoRow, "🫧 0/0", Color3.fromRGB(80, 70, 150), { LayoutOrder = 1 })
	local _, timeT, setTimeColor = chip(infoRow, "☀️", Color3.fromRGB(255, 190, 60), { LayoutOrder = 0 })
	local potionChip, potionT = chip(infoRow, "", Color3.fromRGB(60, 170, 220), { LayoutOrder = 2, Visible = false })
	local eventChip, eventT = chip(infoRow, "", C.Orange, { LayoutOrder = 3, Visible = false })

	-- ---------- Тосты ----------
	toastHolder = frame(root, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.fromOffset(900, 230) })
	new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, toastHolder)
	new("UIScale", { Scale = 0.9 }, toastHolder)

	-- =========================================================
	-- 🛒 SHOP
	-- =========================================================
	local shop = makePanel("Shop", "🛒", "Shop", C.Orange)
	shop.Sub.Text = "Support the game ❤️"
	local shopPages = makeTabs(shop.Body, {
		{ Name = "⭐ Passes", Color = C.Gold },
		{ Name = "⚡ Boosts", Color = C.Blue },
		{ Name = "🥚 Eggs", Color = C.Green },
		{ Name = "🎟️ Codes", Color = C.Pink },
	})
	local passList = scroll(shopPages[1], UDim2.new(0.5, -5, 0, 136))
	local boostList = scroll(shopPages[2], UDim2.new(0.5, -5, 0, 136))
	local eggList = scroll(shopPages[3], UDim2.new(0.5, -5, 0, 136))

	local cashProducts = {} -- {info, subLabel}
	local passCards = {} -- key -> {info, btnObj}
	local function shopCard(list, key, info, isPass)
		if info.Id == 0 then
			return
		end
		local c = card(list, { Height = 136, Color = if isPass then C.Gold else C.Blue, Icon = SHOP_ICONS[key] or "⭐", Title = info.Title, Sub = SHOP_BLURB[key] or info.Desc, TileSize = 108, TitleH = 32, LayoutOrder = SHOP_ORDER[key] or 9 })
		c.Sub.Size = UDim2.new(1, -c.X - 10, 0, 44)
		c.Sub.Position = UDim2.fromOffset(c.X, 40)
		local priceBtn = btn(c.Frame, {
			Text = "R$ " .. info.Price,
			Color = C.Green,
			Size = UDim2.new(1, -c.X - 12, 0, 40),
			Position = UDim2.new(0, c.X, 1, -50),
			TextSize = 22,
			OnClick = function()
				if isPass then
					MarketplaceService:PromptGamePassPurchase(player, info.Id)
				else
					MarketplaceService:PromptProductPurchase(player, info.Id)
				end
			end,
		})
		local rib = SHOP_RIBBON[key]
		if rib then
			local r = chip(c.Frame, rib[1], rib[2], { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, -3), Size = UDim2.fromOffset(0, 26), Rotation = 5, ZIndex = 3 })
			local _ = r
		end
		if info.Kind == "Cash" then
			table.insert(cashProducts, { info = info, sub = c.Sub })
		end
		if isPass then
			passCards[key] = { info = info, btn = priceBtn }
		end
		-- реальная иконка и цена из Roblox (то, что загружено в Creator Hub)
		task.spawn(function()
			local ok, pi = pcall(function()
				return MarketplaceService:GetProductInfo(info.Id, if isPass then Enum.InfoType.GamePass else Enum.InfoType.Product)
			end)
			if ok and pi then
				if pi.IconImageAssetId and pi.IconImageAssetId ~= 0 then
					c.Image.Image = "rbxassetid://" .. pi.IconImageAssetId
					c.Icon.Visible = false
				end
				if pi.PriceInRobux and not priceBtn.Owned then
					priceBtn.SetText("R$ " .. pi.PriceInRobux)
				end
			end
		end)
	end
	for key, info in Config.GamePasses do
		shopCard(passList, key, info, true)
	end
	for key, info in Config.Products do
		shopCard(boostList, key, info, false)
	end
	local function refreshOwned()
		for _, pc in passCards do
			task.spawn(function()
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pc.info.Id)
				end)
				if ok and owns then
					pc.btn.Owned = true
					pc.btn.SetText("✅ OWNED")
					pc.btn.SetColor(C.Gray)
				end
			end)
		end
	end
	task.spawn(refreshOwned)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_, _, bought)
		if bought then
			task.wait(1)
			refreshOwned()
		end
	end)

	-- 🥚 Яйца
	local SHORT = { "C", "U", "R", "E", "L", "M", "S", "✨" }
	local eggBtns = {}
	for i, egg in Config.Eggs do
		local c = card(eggList, { Height = 136, Color = egg.Color, Icon = egg.Icon, Title = egg.Name, Sub = "", TileSize = 108, TitleH = 32, LayoutOrder = i })
		c.Sub.Visible = false
		local odds = frame(c.Frame, { Position = UDim2.fromOffset(c.X, 42), Size = UDim2.new(1, -c.X - 10, 0, 40) })
		new("UIGridLayout", { CellSize = UDim2.fromOffset(42, 18), CellPadding = UDim2.fromOffset(3, 3), SortOrder = Enum.SortOrder.LayoutOrder }, odds)
		local total = 0
		for r = egg.MinRarity, egg.MaxRarity do
			total += Config.Rarities[r].Weight
		end
		for r = egg.MinRarity, egg.MaxRarity do
			local pct = Config.Rarities[r].Weight / total * 100
			local rc = Config.Rarities[r].Color
			local o = frame(odds, { BackgroundTransparency = 0, BackgroundColor3 = darken(rc, 0.35), LayoutOrder = r })
			round(o)
			local t = label(o, SHORT[r] .. " " .. (if pct >= 1 then string.format("%d%%", math.floor(pct + 0.5)) else string.format("%.1f%%", pct)), 12, { TextWrapped = false })
			fit(t, 12, 6)
		end
		eggBtns[i] = {
			egg = egg,
			btn = btn(c.Frame, {
				Text = "🥚 " .. Format.money(egg.Price),
				Color = C.Green,
				Size = UDim2.new(1, -c.X - 12, 0, 40),
				Position = UDim2.new(0, c.X, 1, -50),
				TextSize = 22,
				OnClick = function()
					Action:FireServer("Hatch", egg.Id)
				end,
			}),
		}
	end

	-- 🎟️ Коды
	do
		local pg = shopPages[4]
		local box = frame(pg, { BackgroundTransparency = 0, BackgroundColor3 = WHITE, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 170) })
		corner(box, 18)
		stroke(box, C.Ink, 3)
		grad(box, C.CardHi, C.Card)
		label(box, "🎟️ Redeem a code", 28, { Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 36), TextXAlignment = Enum.TextXAlignment.Left })
		local input = new("TextBox", {
			PlaceholderText = "Type code here...",
			PlaceholderColor3 = Color3.fromRGB(140, 130, 180),
			Text = "",
			ClearTextOnFocus = false,
			Font = FONT,
			TextSize = 26,
			TextColor3 = WHITE,
			BackgroundColor3 = C.Well,
			Position = UDim2.fromOffset(20, 64),
			Size = UDim2.new(1, -230, 0, 58),
		}, box)
		corner(input, 14)
		stroke(input, C.Ink, 3)
		btn(box, {
			Text = "Redeem",
			Color = C.Green,
			Position = UDim2.new(1, -196, 0, 64),
			Size = UDim2.fromOffset(176, 58),
			TextSize = 26,
			OnClick = function()
				Action:FireServer("Redeem", input.Text)
				input.Text = ""
			end,
		})
		label(box, "Psst… new players try code SLIME 😉", 17, { Position = UDim2.fromOffset(20, 132), Size = UDim2.new(1, -40, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Sub })
		label(pg, "❤️ Like & favorite the game — new codes drop at like milestones!", 20, { Position = UDim2.fromOffset(0, 200), Size = UDim2.new(1, 0, 0, 60), TextColor3 = C.Gold })
	end

	-- =========================================================
	-- ♻️ REBIRTH
	-- =========================================================
	local rebirth = makePanel("Rebirth", "♻️", "Rebirth", C.Purple)
	local rebCard = frame(rebirth.Body, { BackgroundTransparency = 0, BackgroundColor3 = WHITE, Size = UDim2.new(1, 0, 0, 158) })
	corner(rebCard, 18)
	stroke(rebCard, C.Ink, 3)
	grad(rebCard, C.CardHi, C.Card)
	local rebTitle = label(rebCard, "", 28, { Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -250, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false })
	fit(rebTitle, 28, 12)
	local rebInfo = label(rebCard, "", 17, { Position = UDim2.fromOffset(18, 50), Size = UDim2.new(1, -250, 0, 50), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.Sub })
	fit(rebInfo, 17, 9)
	local rebBar = bar(rebCard, C.Purple, { Position = UDim2.new(0, 18, 0, 112), Size = UDim2.new(1, -250, 0, 26) })
	local rebBtn = btn(rebCard, {
		Text = "♻️ REBIRTH",
		Color = C.Purple,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(206, 84),
		TextSize = 30,
		OnClick = function()
			Action:FireServer("Rebirth")
			rebirth.Frame.Visible = false
		end,
	})
	local perkHead = label(rebirth.Body, "🔮 Perks — spend Rebirth Tokens", 21, { Position = UDim2.fromOffset(2, 168), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(215, 175, 255) })
	local perkList = scroll(rebirth.Body, UDim2.new(0.5, -5, 0, 82), { Position = UDim2.fromOffset(0, 202), Size = UDim2.new(1, 0, 1, -202) })

	-- =========================================================
	-- 🏠 BASE
	-- =========================================================
	local basePanel = makePanel("Base", "🏠", "Base Upgrades", Color3.fromRGB(70, 170, 255))
	local baseList = scroll(basePanel.Body)
	local function upgradeRow(order, icon, color, onClick)
		local c = card(baseList, { Height = 86, Color = color, Icon = icon, Title = "", Sub = "", RightWidth = 170, LayoutOrder = order })
		local b = btn(c.Frame, { Text = "...", Color = C.Green, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(156, 54), TextSize = 22, OnClick = onClick })
		return c, b
	end
	local slotCard, slotBtn = upgradeRow(1, "🫧", C.Green, function()
		Action:FireServer("BuySlot")
	end)
	local lockCard, lockBtn = upgradeRow(2, "🔒", C.Red, function()
		Action:FireServer("BuyLock")
	end)
	local trapCard, trapBtn = upgradeRow(3, "🪤", C.Purple, function()
		Action:FireServer("BuyTrap")
	end)
	local buddyCard, buddyBtn = upgradeRow(4, "🐾", C.Pink, function()
		Action:FireServer("ToggleBuddy")
	end)
	buddyCard.Title.Text = "Buddy Slime"
	buddyCard.Sub.Text = "Your best slime follows you around"

	-- =========================================================
	-- 🧰 GEAR
	-- =========================================================
	local gearPanel = makePanel("Gear", "🧰", "Gear Shop", C.Teal)
	gearPanel.Sub.Text = "Keep forever!"
	local gearList = scroll(gearPanel.Body)

	-- =========================================================
	-- 📖 INDEX
	-- =========================================================
	local indexPanel = makePanel("Index", "📖", "Slime Index", C.Blue)
	local indexBar = bar(indexPanel.Body, C.Blue, { Size = UDim2.new(1, 0, 0, 26) })
	local indexList = scroll(indexPanel.Body, UDim2.new(0.2, -8, 0, 116), { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36) })

	-- =========================================================
	-- 📜 QUESTS
	-- =========================================================
	local questPanel = makePanel("Quests", "📜", "Quests", C.Orange)
	questPanel.Sub.Text = "New quests every day"
	local questList = scroll(questPanel.Body)

	-- =========================================================
	-- ⚗️ FUSE
	-- =========================================================
	local fusePanel = makePanel("Fuse", "⚗️", "Fuse Machine", Color3.fromRGB(240, 180, 30))
	fusePanel.Sub.Text = "3 same → MEGA (x6 cash)"
	local fuseList = scroll(fusePanel.Body)
	local fuseKey = ""
	local fuseReady = 0
	local function rebuildFuse(list)
		local key = ""
		local ready = 0
		for _, g in list do
			key ..= g.Id .. g.Count .. ","
			if g.Count >= Config.Fuse.Need then
				ready += 1
			end
		end
		fuseReady = ready
		if key == fuseKey then
			return
		end
		fuseKey = key
		clear(fuseList)
		if #list == 0 then
			label(fuseList, "Collect 3 of the same slime to fuse a MEGA slime! 🧪", 22, { Size = UDim2.new(1, 0, 0, 80), TextColor3 = C.Sub })
		end
		for i, g in list do
			local def = Pets.ById[g.Id]
			if def then
				local can = g.Count >= Config.Fuse.Need
				local r = Config.Rarities[def.Rarity]
				local c = card(fuseList, { Height = 80, Color = r.Color, Icon = "", Title = def.Name, Sub = r.Name .. "  ·  you have " .. g.Count .. "/" .. Config.Fuse.Need, RightWidth = 150, LayoutOrder = if can then i else 100 + i })
				c.Title.TextColor3 = lighten(r.Color, 0.3)
				slimeIcon(c.Tile, def.Color, 50, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55) })
				if can then
					btn(c.Frame, { Text = "⚗️ FUSE!", Color = C.Gold, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(136, 52), TextSize = 22, OnClick = function()
						Action:FireServer("Fuse", g.Id)
					end })
				else
					local set = bar(c.Frame, r.Color, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(132, 22) })
					set(g.Count / Config.Fuse.Need, g.Count .. "/" .. Config.Fuse.Need)
				end
			end
		end
	end

	-- =========================================================
	-- 🎡 SPIN
	-- =========================================================
	local spinPanel = makePanel("Spin", "🎡", "Lucky Spin", Color3.fromRGB(255, 96, 70))
	spinPanel.Sub.Text = "Free every 4 hours"
	local prizeGrid = frame(spinPanel.Body, { Size = UDim2.new(0.6, 0, 1, 0) })
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 66), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, prizeGrid)
	local spinTiles = {}
	for i, pr in Config.Spin.Prizes do
		local t = frame(prizeGrid, { BackgroundTransparency = 0, BackgroundColor3 = WHITE, LayoutOrder = i })
		corner(t, 14)
		local st = stroke(t, C.Ink, 3)
		local g = grad(t, C.CardHi, C.Card)
		local l = label(t, pr.Label, 20, { Size = UDim2.new(1, -14, 1, -8), Position = UDim2.fromOffset(7, 4) })
		fit(l, 20, 9)
		spinTiles[i] = { st = st, g = g }
	end
	local spinSide = frame(spinPanel.Body, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.38, 0, 1, 0) })
	local wheel = emoji(spinSide, "🎡", 96, { Size = UDim2.new(1, 0, 0, 130) })
	local spinResult = label(spinSide, "Spin to win!", 24, { Position = UDim2.fromOffset(0, 136), Size = UDim2.new(1, 0, 0, 80), TextColor3 = C.Gold })
	fit(spinResult, 24, 10)
	local spinBtn = btn(spinSide, { Text = "SPIN!", Color = Color3.fromRGB(255, 110, 60), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -10, 0, 84), TextSize = 34, OnClick = function()
		Action:FireServer("Spin")
	end })
	local function lightTile(idx)
		for i, t in spinTiles do
			local on = i == idx
			t.st.Color = if on then WHITE else C.Ink
			t.st.Thickness = if on then 4 else 3
			t.g.Color = if on then ColorSequence.new(Color3.fromRGB(255, 230, 110), Color3.fromRGB(255, 160, 30)) else ColorSequence.new(C.CardHi, C.Card)
		end
	end

	-- =========================================================
	-- 🥚 Хэтч-оверлей
	-- =========================================================
	local hatchFrame = frame(root, { BackgroundTransparency = 0.35, BackgroundColor3 = Color3.fromRGB(10, 5, 25), Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 50 })
	local hatchBox = frame(hatchFrame, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 520), ZIndex = 51 })
	local rays = frame(hatchBox, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(10, 10), ZIndex = 51 })
	local rayList = {}
	for i = 0, 5 do
		local r = frame(rays, { BackgroundTransparency = 0.75, BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 560), Rotation = i * 30, ZIndex = 51 })
		local rg = new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, r)
		rg.Rotation = 90
		table.insert(rayList, r)
	end
	local glow = frame(hatchBox, { BackgroundTransparency = 0.4, BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(250, 250), ZIndex = 52 })
	round(glow)
	local hatchEgg = emoji(hatchBox, "🥚", 150, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(220, 220), ZIndex = 53 })
	local hatchSlimeHolder = frame(hatchBox, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(190, 165), ZIndex = 53 })
	local hatchSlimeScale = new("UIScale", {}, hatchSlimeHolder)
	local hatchName = label(hatchBox, "", 48, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.7, 0), Size = UDim2.fromOffset(600, 58), ZIndex = 54, TextWrapped = false })
	fit(hatchName, 48, 16)
	local hatchRarity = label(hatchBox, "", 30, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.82, 0), Size = UDim2.fromOffset(600, 40), ZIndex = 54 })
	local hatching = false
	local function showHatch(d)
		if hatching then
			return
		end
		hatching = true
		local def = Pets.ById[d.Id]
		local egg
		for _, e in Config.Eggs do
			if e.Id == d.Egg then
				egg = e
			end
		end
		local r = Config.Rarities[def.Rarity]
		local v = d.V and Config.Variants[d.V]
		hatchFrame.Visible = true
		hatchName.Text = ""
		hatchRarity.Text = ""
		glow.BackgroundColor3 = egg and egg.Color or WHITE
		hatchEgg.Visible = true
		hatchEgg.Text = egg and egg.Icon or "🥚"
		for _, c in hatchSlimeHolder:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		local spinConn = true
		task.spawn(function()
			while spinConn do
				for _, r in rayList do
					r.Rotation += 2
				end
				task.wait()
			end
		end)
		for k = 1, 14 do
			hatchEgg.Rotation = (if k % 2 == 0 then 1 else -1) * (5 + k * 1.6)
			task.wait(0.07)
		end
		hatchEgg.Rotation = 0
		hatchEgg.Visible = false
		glow.BackgroundColor3 = r.Color
		slimeIcon(hatchSlimeHolder, if v then v.Color else def.Color, 190, { ZIndex = 53 })
		for _, c in hatchSlimeHolder:GetDescendants() do
			if c:IsA("GuiObject") then
				c.ZIndex = 53
			end
		end
		hatchSlimeScale.Scale = 0.3
		TweenService:Create(hatchSlimeScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		hatchName.Text = (if v then v.Label .. " " else "") .. def.Name
		hatchName.TextColor3 = lighten(if v then v.Color else def.Color, 0.25)
		hatchRarity.Text = "★ " .. r.Name .. " ★"
		hatchRarity.TextColor3 = r.Color
		task.wait(1.9)
		spinConn = false
		hatchFrame.Visible = false
		hatching = false
	end

	local spinning = false
	Net.event("Reward").OnClientEvent:Connect(function(kind, d)
		if kind == "Hatch" then
			task.spawn(showHatch, d)
			return
		end
		if kind ~= "Spin" or spinning then
			return
		end
		spinning = true
		spinResult.Text = "..."
		local n = #spinTiles
		local steps = n * 3 + d.Index
		for k = 1, steps do
			lightTile(((k - 1) % n) + 1)
			wheel.Rotation += 25
			task.wait(0.04 + (k / steps) ^ 3 * 0.26)
		end
		spinResult.Text = "🎉 " .. d.Text
		spinning = false
	end)

	-- ---------- 🎁 Подарок за игру (справа) ----------
	local giftBtn = btn(root, { Text = "🎁", Color = C.Pink, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(124, 78), TextSize = 22, Radius = 18, OnClick = function()
		Action:FireServer("ClaimGift")
	end })
	giftBtn.Label.TextWrapped = true
	HUD.GiftBtn = giftBtn.Root

	-- =========================================================
	-- Мета (gear / index / quests / perks) — перестраивается по событию Meta
	-- =========================================================
	local meta = nil
	local potionBtns = {}
	local questClaimable = 0
	local perkAffordable = false
	local QUEST_ICON = { Buy = "🛒", Steal = "🦹", Bonk = "💥", Upgrade = "⬆️", Event = "⚡" }

	local function rebuildMeta()
		if not meta then
			return
		end
		-- Gear
		clear(gearList)
		local owned = {}
		for _, id in meta.Gear do
			owned[id] = true
		end
		header(gearList, "🧰 Tools", 0, C.Teal)
		for i, g in Config.Gear do
			local c = card(gearList, { Height = 84, Color = C.Teal, Icon = g.Icon, Title = g.Name, Sub = g.Desc, RightWidth = 160, LayoutOrder = i })
			if owned[g.Id] then
				c.SetDone(true)
				chip(c.Frame, "✅ OWNED", C.Green, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(0, 36) })
			else
				btn(c.Frame, { Text = Format.money(g.Price), Color = C.Green, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(146, 52), TextSize = 22, OnClick = function()
					Action:FireServer("BuyGear", g.Id)
				end })
			end
		end
		header(gearList, "🧪 Potions", 50, Color3.fromRGB(120, 210, 255))
		potionBtns = {}
		for i, pdef in Config.Potions do
			local c = card(gearList, { Height = 84, Color = Color3.fromRGB(60, 170, 220), Icon = pdef.Icon, Title = pdef.Name, Sub = pdef.Desc, RightWidth = 160, LayoutOrder = 50 + i })
			potionBtns[pdef.Id] = btn(c.Frame, { Text = "...", Color = Color3.fromRGB(60, 170, 230), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(146, 52), TextSize = 22, OnClick = function()
				Action:FireServer("BuyPotion", pdef.Id)
			end })
		end

		-- Index
		clear(indexList)
		local found = {}
		for _, id in meta.Index do
			found[id] = true
		end
		indexPanel.Sub.Text = ("+%d%% cash bonus"):format(math.floor(meta.Bonus * 100 + 0.5))
		indexBar(#meta.Index / math.max(1, meta.Total), ("Discovered %d / %d  ·  every %d%% = +%d%% cash"):format(#meta.Index, meta.Total, Config.Index.StepPercent, math.floor(Config.Index.BonusPerStep * 100 + 0.5)))
		for i, def in Pets.List do
			local r = Config.Rarities[def.Rarity]
			local has = found[def.Id]
			local cell = frame(indexList, { BackgroundTransparency = 0, BackgroundColor3 = WHITE, LayoutOrder = def.Rarity * 100 + i })
			corner(cell, 14)
			stroke(cell, if has then r.Color else C.Ink, 2.5)
			grad(cell, if has then darken(r.Color, 0.45) else Color3.fromRGB(44, 38, 64), if has then darken(r.Color, 0.7) else Color3.fromRGB(28, 24, 42))
			if has then
				slimeIcon(cell, def.Color, 50, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8) })
			else
				local q = frame(cell, { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(60, 54, 84), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(50, 43) })
				new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, q)
				label(q, "?", 26, { TextColor3 = Color3.fromRGB(150, 140, 180) })
			end
			local n = label(cell, if has then def.Name else "???", 15, { Position = UDim2.new(0, 4, 0, 58), Size = UDim2.new(1, -8, 0, 24), TextWrapped = false })
			fit(n, 15, 7)
			local rl = label(cell, r.Name, 13, { Position = UDim2.new(0, 4, 0, 82), Size = UDim2.new(1, -8, 0, 20), TextColor3 = r.Color, TextWrapped = false })
			fit(rl, 13, 7)
			if def.Event or def.Night then
				emoji(cell, if def.Night then "🌙" else "🎃", 18, { Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(22, 22) })
			end
		end

		-- Quests + Achievements
		clear(questList)
		questClaimable = 0
		header(questList, "📅 Daily Quests", 0)
		for i, q in meta.Quests do
			local qdef
			for _, d in Config.Quests do
				if d.Kind == q.Kind then
					qdef = d
				end
			end
			local done = q.Prog >= q.Goal
			local c = card(questList, { Height = 90, Color = C.Orange, Icon = QUEST_ICON[q.Kind] or "📜", Title = (qdef and string.format(qdef.Text, q.Goal) or q.Kind), Sub = "", RightWidth = 160, LayoutOrder = i, TitleH = 34 })
			c.Sub.Visible = false
			local set = bar(c.Frame, if done then C.Green else C.Orange, { Position = UDim2.fromOffset(c.X, 46), Size = UDim2.new(1, -c.X - 172, 0, 22) })
			set(q.Prog / q.Goal, ("%d / %d"):format(math.min(q.Prog, q.Goal), q.Goal))
			local rw = label(c.Frame, "Reward " .. Format.money(meta.QuestRewards[i] or 0), 14, { Position = UDim2.fromOffset(c.X, 69), Size = UDim2.new(1, -c.X - 172, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Gold, TextWrapped = false })
			fit(rw, 14, 7)
			if q.Claimed then
				c.SetDone(true)
				chip(c.Frame, "✅ Done", C.Green, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(0, 36) })
			elseif done then
				questClaimable += 1
				btn(c.Frame, { Text = "CLAIM!", Color = C.Gold, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(146, 54), TextSize = 24, OnClick = function()
					Action:FireServer("ClaimQuest", i)
				end })
			else
				chip(c.Frame, "⏳ In progress", C.Gray, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(0, 32) })
			end
		end
		header(questList, "🏆 Achievements", 50)
		for i, a in meta.Ach or {} do
			local c = card(questList, { Height = 78, Color = if a.Done then C.Green else C.Gold, Icon = if a.Done then "✅" else "🏆", Title = a.Name, Sub = "", RightWidth = 110, LayoutOrder = 60 + i + (if a.Done then 100 else 0), TitleH = 30 })
			c.Sub.Visible = false
			c.SetDone(a.Done)
			local set = bar(c.Frame, if a.Done then C.Green else C.Gold, { Position = UDim2.fromOffset(c.X, 44), Size = UDim2.new(1, -c.X - 122, 0, 20) })
			local goalText = if a.Stat == "TotalEarned" then Format.money(math.min(a.Prog, a.Goal)) .. " / " .. Format.money(a.Goal) else math.min(a.Prog, a.Goal) .. " / " .. a.Goal .. " " .. a.Stat:lower()
			set(a.Prog / a.Goal, goalText)
			if a.Tokens > 0 then
				chip(c.Frame, "🔮 +" .. a.Tokens, C.Purple, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(0, 32) })
			end
		end

		-- Перки
		clear(perkList)
		local tokens = meta.Tokens or 0
		perkHead.Text = "🔮 Perks — you have " .. tokens .. " Rebirth Token" .. (if tokens == 1 then "" else "s")
		perkAffordable = false
		for i, pk in Config.Perks do
			local lvl = (meta.Perks and meta.Perks[pk.Id]) or 0
			local maxed = lvl >= pk.Max
			local icon, name = string.match(pk.Name, "^(%S+)%s+(.+)$")
			local c = card(perkList, { Height = 82, Color = C.Purple, Icon = icon or "🔮", Title = (name or pk.Name) .. "  Lv." .. lvl .. "/" .. pk.Max, Sub = pk.Desc, RightWidth = 96, LayoutOrder = i })
			if maxed then
				c.SetDone(true)
				chip(c.Frame, "MAX", C.Green, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(0, 32) })
			else
				if tokens >= pk.Cost then
					perkAffordable = true
				end
				btn(c.Frame, { Text = "🔮 " .. pk.Cost, Color = if tokens >= pk.Cost then C.Purple else C.Gray, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(84, 48), TextSize = 20, OnClick = function()
					Action:FireServer("BuyPerk", pk.Id)
				end })
			end
		end
		if HUD._refreshBadges then
			HUD._refreshBadges()
		end
	end
	Net.event("Meta").OnClientEvent:Connect(function(m)
		meta = m
		rebuildMeta()
	end)

	-- =========================================================
	-- Кнопки слева
	-- =========================================================
	local side = frame(root, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.52, 0), Size = UDim2.fromOffset(3 * 78 + 2 * 8, 4 * 86 + 3 * 8) })
	HUD.Side = side
	new("UIGridLayout", { CellSize = UDim2.fromOffset(78, 86), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, side)
	local order = 0
	local function sideButton(icon: string, caption: string, color: Color3, onClick)
		order += 1
		local holder = frame(side, { LayoutOrder = order })
		local b = btn(holder, { Text = "", Color = color, Size = UDim2.fromOffset(78, 74), Radius = 20, Depth = 6, OnClick = function()
			local ic = holder:FindFirstChild("Icon", true)
			if ic then
				ic.Rotation = -12
				TweenService:Create(ic, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Rotation = 0 }):Play()
			end
			onClick()
		end })
		emoji(b.Face, icon, 38, { Name = "Icon", Size = UDim2.new(1, 0, 1, -6), Position = UDim2.fromOffset(0, 0) })
		local cap = label(holder, caption, 17, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 6, 0, 24), TextWrapped = false, ZIndex = 3 })
		fit(cap, 17, 8)
		textStroke(cap, darken(color, 0.7))
		local badge = frame(holder, { BackgroundTransparency = 0, BackgroundColor3 = C.Red, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(28, 28), Visible = false, ZIndex = 4 })
		round(badge)
		stroke(badge, WHITE, 2.5)
		local bt = label(badge, "!", 18, { ZIndex = 4, TextWrapped = false })
		fit(bt, 18, 8)
		local bscale = new("UIScale", {}, badge)
		return { Cap = cap, Badge = badge, BadgeText = bt, BadgeScale = bscale }
	end
	local function setBadge(sb, on: boolean, txt: string?)
		sb.Badge.Visible = on
		sb.BadgeText.Text = txt or "!"
	end
	-- пульсация бейджей
	task.spawn(function()
		while true do
			local s = 1 + math.sin(os.clock() * 6) * 0.12
			for _, sb in HUD._sideButtons or {} do
				sb.BadgeScale.Scale = s
			end
			task.wait(0.05)
		end
	end)

	local sb = {}
	sb.Shop = sideButton("🛒", "Shop", C.Orange, function()
		togglePanel(shop)
	end)
	sb.Gear = sideButton("🧰", "Gear", C.Teal, function()
		togglePanel(gearPanel)
	end)
	sb.Index = sideButton("📖", "Index", C.Blue, function()
		togglePanel(indexPanel)
	end)
	sb.Quests = sideButton("📜", "Quests", Color3.fromRGB(255, 120, 50), function()
		togglePanel(questPanel)
	end)
	sb.Fuse = sideButton("⚗️", "Fuse", Color3.fromRGB(240, 185, 30), function()
		togglePanel(fusePanel)
	end)
	sb.Spin = sideButton("🎡", "Spin", Color3.fromRGB(255, 90, 70), function()
		togglePanel(spinPanel)
	end)
	sb.Base = sideButton("🏠", "Base", Color3.fromRGB(80, 175, 255), function()
		togglePanel(basePanel)
	end)
	sb.Rebirth = sideButton("♻️", "Rebirth", C.Purple, function()
		togglePanel(rebirth)
	end)
	sb.Speed = sideButton("⚡", "Speed", Color3.fromRGB(40, 190, 255), function()
		Action:FireServer("BuySpeed")
	end)
	sb.Daily = sideButton("🎁", "Daily", C.Green, function()
		Action:FireServer("Daily")
	end)
	sb.Lock = sideButton("🔒", "Lock", C.Red, function()
		Action:FireServer("Lock")
	end)
	sb.Invite = sideButton("👥", "Invite", C.Pink, function()
		pcall(function()
			local options = Instance.new("ExperienceInviteOptions")
			options.PromptMessage = "Come steal slimes with me! +10% cash per friend"
			SocialService:PromptGameInvite(player, options)
		end)
	end)
	HUD._sideButtons = sb

	function HUD._refreshBadges()
		local s = state
		setBadge(sb.Quests, questClaimable > 0, tostring(questClaimable))
		setBadge(sb.Fuse, fuseReady > 0, tostring(fuseReady))
		if s then
			local canReb = s.Cash >= s.RebirthCost
			setBadge(sb.Rebirth, canReb or perkAffordable, "!")
			setBadge(sb.Spin, s.Rewards ~= nil and s.Rewards.SpinIn <= 0, "!")
			setBadge(sb.Daily, s.DailyIn <= 0, "!")
		end
	end

	-- =========================================================
	-- Состояние
	-- =========================================================
	local lastCash = nil
	Net.event("State").OnClientEvent:Connect(function(s)
		state = s
		cash.Text = Format.money(s.Cash)
		income.Text = "+" .. Format.money(s.Income) .. "/s"
		if lastCash and s.Cash > lastCash + math.max(10, s.Income * 3) then
			-- крупный приход денег — «пульс» монеты
			cashScale.Scale = 1.3
			TweenService:Create(cashScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		lastCash = s.Cash
		slotsT.Text = ("🫧 %d/%d slimes"):format(s.UsedSlots, s.Slots)

		-- Base
		slotCard.Title.Text = "+1 Slime Slot"
		slotCard.Sub.Text = ("Bought %d / %d extra pedestals"):format(s.SlotsBought or 0, s.SlotsBuyMax or 6)
		local slotMax = (s.SlotCost or -1) < 0
		slotBtn.SetText(if slotMax then "MAX" else Format.money(s.SlotCost))
		slotBtn.SetColor(if slotMax then C.Gray elseif s.Cash >= s.SlotCost then C.Green else Color3.fromRGB(150, 140, 170))
		local durs = Config.LockUpgrade.Durations
		local lv = s.LockLevel or 0
		lockCard.Title.Text = ("Lock Lv.%d"):format(lv + 1)
		lockCard.Sub.Text = ("Base lock lasts %ds%s"):format(durs[lv + 1] or durs[#durs], if durs[lv + 2] then " → next " .. durs[lv + 2] .. "s" else "")
		local lockMax = (s.LockCost or -1) < 0
		lockBtn.SetText(if lockMax then "MAX" else Format.money(s.LockCost))
		lockBtn.SetColor(if lockMax then C.Gray elseif s.Cash >= s.LockCost then C.Green else Color3.fromRGB(150, 140, 170))
		local tl = s.TrapLevel or 0
		trapCard.Title.Text = if tl > 0 then ("Entrance Trap Lv.%d"):format(tl) else "Entrance Trap"
		trapCard.Sub.Text = if tl > 0 then ("Stuns thieves for %ss"):format(tostring(Config.Trap.Stun[tl])) else "Stuns thieves who enter your base"
		local trapMax = (s.TrapCost or -1) < 0
		trapBtn.SetText(if trapMax then "MAX" else Format.money(s.TrapCost))
		trapBtn.SetColor(if trapMax then C.Gray elseif s.Cash >= s.TrapCost then C.Green else Color3.fromRGB(150, 140, 170))
		buddyBtn.SetText(if s.Buddy then "ON" else "OFF")
		buddyBtn.SetColor(if s.Buddy then C.Green else C.Gray)

		rebuildFuse(s.Fusable or {})

		-- Rewards / потион / подарок / спин
		local rw = s.Rewards
		if rw then
			local spinReady = rw.SpinIn <= 0
			sb.Spin.Cap.Text = if spinReady then "SPIN!" else Format.time(rw.SpinIn)
			spinBtn.SetText(if spinReady then "SPIN!" else "⏳ " .. Format.time(rw.SpinIn))
			spinBtn.SetColor(if spinReady then Color3.fromRGB(255, 110, 60) else C.Gray)
			for id, b in potionBtns do
				if b.Root.Parent and rw.PotionPrices[id] then
					b.SetText(Format.money(rw.PotionPrices[id]))
				end
			end
			if rw.CashPotionIn > 0 then
				potionChip.Visible = true
				potionT.Text = "🧪 x2 cash " .. Format.time(rw.CashPotionIn)
			else
				potionChip.Visible = false
			end
			local g = rw.Gift
			if not g or g.Done then
				giftBtn.Root.Visible = false
			else
				giftBtn.Root.Visible = true
				giftBtn.Label.TextWrapped = true
				giftBtn.SetText(if g.Ready then ("🎁 CLAIM!\n%d/%d"):format(g.Index, g.Total) else ("🎁 %d/%d\n%s"):format(g.Index, g.Total, Format.time(g.ReadyIn)))
				giftBtn.SetColor(if g.Ready then C.Green else C.Pink)
			end
		end
		sb.Speed.Cap.Text = if s.SpeedCost < 0 then "MAX" else Format.money(s.SpeedCost)
		sb.Daily.Cap.Text = if s.DailyIn <= 0 then "Claim!" else Format.time(s.DailyIn)

		-- Rebirth
		rebTitle.Text = ("Rebirth #%d"):format(s.Rebirths + 1)
		local nextZone
		for _, z in Config.Zones do
			if z.Rebirth > s.Rebirths and (not nextZone or z.Rebirth < nextZone.Rebirth) then
				nextZone = z
			end
		end
		rebInfo.Text = ("+%d%% cash forever · +1 🔮 token\nResets cash, slimes & speed%s"):format(
			math.floor(s.RebirthBonus * 100),
			if nextZone then ("\nNext island: %s at Rebirth %d"):format(nextZone.Name, nextZone.Rebirth) else ""
		)
		rebBar(s.Cash / math.max(1, s.RebirthCost), Format.money(math.min(s.Cash, s.RebirthCost)) .. " / " .. Format.money(s.RebirthCost))
		rebirth.Sub.Text = "Rebirths: " .. s.Rebirths
		rebBtn.SetColor(if s.Cash >= s.RebirthCost then C.Purple else C.Gray)

		-- Shop: доступность яиц, сумма кэш-паков
		for _, e in eggBtns do
			e.btn.SetColor(if s.Cash >= e.egg.Price then C.Green else Color3.fromRGB(150, 140, 170))
		end
		for _, cp in cashProducts do
			local amount = math.max(cp.info.Min or 0, s.Income * 60 * (cp.info.Minutes or 10))
			cp.sub.Text = ("Get %s instantly! (%d min of your income)"):format(Format.money(amount), cp.info.Minutes or 10)
		end
		HUD._refreshBadges()
	end)

	Net.event("Notify").OnClientEvent:Connect(function(msg, color, sound)
		toast(msg, color)
		playSound(sound)
	end)

	task.spawn(function()
		while true do
			local isNight = ReplicatedStorage:GetAttribute("Night") == true
			local left = Format.time((ReplicatedStorage:GetAttribute("PhaseEnds") or os.time()) - os.time())
			timeT.Text = if isNight then "🌙 Moon slimes! " .. left else "☀️ Night in " .. left
			setTimeColor(if isNight then Color3.fromRGB(110, 100, 230) else Color3.fromRGB(255, 180, 50))
			local t = ReplicatedStorage:GetAttribute("EventText") or ""
			local ends = ReplicatedStorage:GetAttribute("EventEnds") or 0
			if t ~= "" then
				eventChip.Visible = true
				eventT.Text = t .. "  ·  " .. Format.time(ends - os.time())
			else
				eventChip.Visible = false
			end
			task.wait(0.5)
		end
	end)

	-- масштаб под экран
	local function hookCamera()
		local cam = Workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
		end
		updateScale()
	end
	hookCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)
end

function HUD.SetCinematic(on: boolean)
	if HUD.Side then
		HUD.Side.Visible = not on
	end
	if HUD.SlotsPill then
		HUD.SlotsPill.Visible = not on
	end
end

function HUD.SetVisible(v: boolean)
	if gui then
		gui.Enabled = v
	end
end

function HUD.GetState()
	return state
end

return HUD
