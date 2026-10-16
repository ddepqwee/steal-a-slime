--!nonstrict
-- Весь интерфейс собирается кодом: деньги, доход, кнопки, магазин, ребёрт, тосты, баннер ивента.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)

local player = Players.LocalPlayer
local HUD = {}
local state = nil
local gui: ScreenGui

local FONT = Enum.Font.FredokaOne
local PINK = Color3.fromRGB(255, 110, 200)

local function darkerColor(c: Color3): Color3
	return Color3.new(c.R * 0.45, c.G * 0.45, c.B * 0.45)
end

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 14)
	c.Parent = parent
end

local function stroke(parent, color, t)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(40, 20, 60)
	s.Thickness = t or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function gradient(parent, color)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color)
	g.Rotation = 90
	g.Parent = parent
end

local function text(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	for k, v in props do
		t[k] = v
	end
	t.Parent = parent
	return t
end

local function button(parent, props, color, onClick)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.Font = FONT
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextStrokeTransparency = 0.2
	b.BackgroundColor3 = color
	for k, v in props do
		b[k] = v
	end
	corner(b, 14)
	stroke(b, darkerColor(color), 3)
	gradient(b, color)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	b.Parent = parent
	b.MouseButton1Click:Connect(function()
		local s = b.Size
		b.Size = UDim2.new(s.X.Scale * 0.92, s.X.Offset * 0.92, s.Y.Scale * 0.92, s.Y.Offset * 0.92)
		TweenService:Create(b, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = s }):Play()
		onClick()
	end)
	return b
end

local function panel(name, title)
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromScale(0.5, 0.62)
	f.BackgroundColor3 = Color3.fromRGB(70, 45, 110)
	f.Visible = false
	corner(f, 24)
	stroke(f, Color3.fromRGB(30, 15, 50), 4)
	gradient(f, Color3.fromRGB(70, 45, 110))
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1.3
	ar.Parent = f
	local size = Instance.new("UISizeConstraint")
	size.MinSize = Vector2.new(300, 230)
	size.Parent = f
	text(f, { Text = title, Size = UDim2.fromScale(0.8, 0.13), Position = UDim2.fromScale(0.05, 0.03), TextXAlignment = Enum.TextXAlignment.Left })
	button(f, { Text = "X", Size = UDim2.fromScale(0.1, 0.13), Position = UDim2.fromScale(0.87, 0.03) }, Color3.fromRGB(255, 70, 90), function()
		f.Visible = false
	end)
	f.Parent = gui
	return f
end

-- ===== Тосты =====
local toastHolder
local function toast(msg: string, color: Color3)
	if msg == "" then
		return
	end
	local t = text(toastHolder, {
		Text = msg,
		TextColor3 = color,
		Size = UDim2.new(1, 0, 0, 30),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	TweenService:Create(t, TweenInfo.new(0.25), { TextTransparency = 0, TextStrokeTransparency = 0.2 }):Play()
	task.delay(4, function()
		local tw = TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
		tw:Play()
		tw.Completed:Wait()
		t:Destroy()
	end)
	local items = {}
	for _, c in toastHolder:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(items, c)
		end
	end
	if #items > 5 then
		items[1]:Destroy()
	end
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

function HUD.Build()
	gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	HUD.Gui = gui

	-- Деньги
	local top = Instance.new("Frame")
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 8)
	top.Size = UDim2.fromOffset(230, 62)
	top.BackgroundColor3 = Color3.fromRGB(70, 200, 90)
	corner(top, 31)
	stroke(top, Color3.fromRGB(20, 70, 30), 3)
	gradient(top, Color3.fromRGB(60, 190, 80))
	top.Parent = gui
	local coin = text(top, { Text = "💰", Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(8, 7) })
	coin.TextStrokeTransparency = 1
	local cash = text(top, { Text = "$0", Size = UDim2.new(1, -66, 0, 36), Position = UDim2.fromOffset(58, 3), TextXAlignment = Enum.TextXAlignment.Left })
	local income = text(top, { Text = "+$0/s", Size = UDim2.new(1, -66, 0, 20), Position = UDim2.fromOffset(58, 38), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 250, 190) })
	local slotsPill = Instance.new("Frame")
	slotsPill.AnchorPoint = Vector2.new(0.5, 0)
	slotsPill.Position = UDim2.new(0.5, 0, 0, 74)
	slotsPill.Size = UDim2.fromOffset(150, 24)
	slotsPill.BackgroundColor3 = Color3.fromRGB(40, 25, 70)
	slotsPill.BackgroundTransparency = 0.15
	corner(slotsPill, 12)
	slotsPill.Parent = gui
	HUD.SlotsPill = slotsPill
	local slots = text(slotsPill, { Text = "", Size = UDim2.new(1, -12, 1, -4), Position = UDim2.fromOffset(6, 2), TextColor3 = Color3.fromRGB(230, 230, 255) })

	-- Баннер ивента
	local banner = text(gui, {
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.fromOffset(380, 26),
		TextColor3 = Color3.fromRGB(255, 230, 90),
	})

	-- Тосты
	toastHolder = Instance.new("Frame")
	toastHolder.BackgroundTransparency = 1
	toastHolder.AnchorPoint = Vector2.new(0.5, 1)
	toastHolder.Position = UDim2.new(0.5, 0, 1, -110)
	toastHolder.Size = UDim2.fromOffset(560, 200)
	toastHolder.Parent = gui
	local tl = Instance.new("UIListLayout")
	tl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tl.Padding = UDim.new(0, 2)
	tl.Parent = toastHolder

	-- Панели
	local shop = panel("Shop", "🛒 Shop")
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.04, 0.2)
	list.Size = UDim2.fromScale(0.92, 0.76)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 6
	list.Parent = shop
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.48, 0, 0, 92)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.Parent = list
	local any = false
	local function shopItem(info, color, prompt)
		if info.Id == 0 then
			return
		end
		any = true
		button(list, { Text = info.Title .. "\n" .. info.Desc .. "\n R$ " .. info.Price }, color, prompt)
	end
	for _, info in Config.GamePasses do
		shopItem(info, Color3.fromRGB(255, 170, 40), function()
			MarketplaceService:PromptGamePassPurchase(player, info.Id)
		end)
	end
	for _, info in Config.Products do
		shopItem(info, Color3.fromRGB(80, 170, 255), function()
			MarketplaceService:PromptProductPurchase(player, info.Id)
		end)
	end
	if not any then
		text(list, { Text = "Boosts coming soon ✨", Size = UDim2.new(1, 0, 0, 40) })
	end

	local rebirth = panel("Rebirth", "♻️ Rebirth")
	local rebInfo = text(rebirth, { Text = "", Size = UDim2.fromScale(0.9, 0.42), Position = UDim2.fromScale(0.05, 0.2), TextColor3 = Color3.new(1, 1, 1) })
	local Action = Net.event("Action")
	button(rebirth, { Text = "Rebirth!", Size = UDim2.fromScale(0.6, 0.18), Position = UDim2.fromScale(0.2, 0.72) }, Color3.fromRGB(170, 90, 255), function()
		Action:FireServer("Rebirth")
		rebirth.Visible = false
	end)

	-- Кнопки слева: компактная сетка 2x3
	local side = Instance.new("Frame")
	side.BackgroundTransparency = 1
	side.AnchorPoint = Vector2.new(0, 0.5)
	side.Position = UDim2.new(0, 10, 0.5, 0)
	side.Size = UDim2.fromOffset(150, 230)
	side.Parent = gui
	HUD.Side = side
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(70, 70)
	gl.CellPadding = UDim2.fromOffset(8, 8)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = side
	local function toggle(p)
		local was = p.Visible
		shop.Visible = false
		rebirth.Visible = false
		p.Visible = not was
	end
	local order = 0
	local function iconButton(icon, caption, color, onClick)
		order += 1
		local b = Instance.new("TextButton")
		b.Text = ""
		b.LayoutOrder = order
		b.AutoButtonColor = false
		b.BackgroundColor3 = color
		corner(b, 18)
		stroke(b, darkerColor(color), 3)
		gradient(b, color)
		local ic = text(b, { Text = icon, Size = UDim2.new(1, 0, 0.62, 0), Position = UDim2.fromScale(0, 0.04) })
		ic.TextStrokeTransparency = 1
		local cap = text(b, { Text = caption, Size = UDim2.new(0.92, 0, 0.28, 0), Position = UDim2.fromScale(0.04, 0.66) })
		b.Parent = side
		b.MouseButton1Click:Connect(function()
			b.Rotation = -6
			TweenService:Create(b, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Rotation = 0 }):Play()
			onClick()
		end)
		b.MouseEnter:Connect(function()
			TweenService:Create(ic, TweenInfo.new(0.12), { Position = UDim2.fromScale(0, -0.03) }):Play()
		end)
		b.MouseLeave:Connect(function()
			TweenService:Create(ic, TweenInfo.new(0.12), { Position = UDim2.fromScale(0, 0.04) }):Play()
		end)
		return cap
	end
	iconButton("🛒", "Shop", Color3.fromRGB(255, 175, 40), function()
		toggle(shop)
	end)
	iconButton("♻️", "Rebirth", Color3.fromRGB(170, 95, 255), function()
		toggle(rebirth)
	end)
	local speedBtn = iconButton("⚡", "Speed", Color3.fromRGB(50, 180, 255), function()
		Action:FireServer("BuySpeed")
	end)
	local dailyBtn = iconButton("🎁", "Daily", Color3.fromRGB(80, 210, 110), function()
		Action:FireServer("Daily")
	end)
	iconButton("🔒", "Lock", Color3.fromRGB(255, 75, 100), function()
		Action:FireServer("Lock")
	end)
	iconButton("👥", "Invite", PINK, function()
		pcall(function()
			local options = Instance.new("ExperienceInviteOptions")
			options.PromptMessage = "Come steal slimes with me! +10% cash per friend"
			SocialService:PromptGameInvite(player, options)
		end)
	end)

	-- Обновление состояния
	Net.event("State").OnClientEvent:Connect(function(s)
		state = s
		cash.Text = Format.money(s.Cash)
		income.Text = "+" .. Format.money(s.Income) .. "/s"
		slots.Text = "🫧 Slimes: " .. s.UsedSlots .. "/" .. s.Slots
		speedBtn.Text = if s.SpeedCost < 0 then "MAX" else Format.money(s.SpeedCost)
		dailyBtn.Text = if s.DailyIn <= 0 then "Claim!" else Format.time(s.DailyIn)
		rebInfo.Text = ("Rebirths: %d\nCost: %s\nReward: +%d%% cash forever\n(cash, slimes and speed reset)"):format(
			s.Rebirths,
			Format.money(s.RebirthCost),
			math.floor(s.RebirthBonus * 100)
		)
	end)

	Net.event("Notify").OnClientEvent:Connect(function(msg, color, sound)
		toast(msg, color)
		playSound(sound)
	end)

	task.spawn(function()
		while true do
			local t = ReplicatedStorage:GetAttribute("EventText") or ""
			local ends = ReplicatedStorage:GetAttribute("EventEnds") or 0
			if t ~= "" then
				banner.Text = "⚡ " .. t .. " — " .. Format.time(ends - os.time())
			else
				banner.Text = ""
			end
			task.wait(0.5)
		end
	end)
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
