--!nonstrict
-- Весь интерфейс собирается кодом: деньги, доход, кнопки, магазин, ребёрт, тосты, баннер ивента.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)
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
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	-- 🥚 Яйца
	local Action0 = Net.event("Action")
	local SHORT = { "C", "U", "R", "E", "L", "M", "S", "✨" }
	for i, egg in Config.Eggs do
		local total = 0
		for r = egg.MinRarity, egg.MaxRarity do
			total += Config.Rarities[r].Weight
		end
		local odds = {}
		for r = egg.MinRarity, egg.MaxRarity do
			local pct = Config.Rarities[r].Weight / total * 100
			table.insert(odds, SHORT[r] .. " " .. (if pct >= 1 then string.format("%d%%", math.floor(pct + 0.5)) else string.format("%.1f%%", pct)))
		end
		local b = button(list, { Text = egg.Icon .. " " .. egg.Name .. "  " .. Format.money(egg.Price) .. "\n" .. table.concat(odds, " · "), LayoutOrder = i }, egg.Color, function()
			Action0:FireServer("Hatch", egg.Id)
		end)
		b.TextScaled = true
	end
	-- 🎟️ Промокоды
	local codeCell = Instance.new("Frame")
	codeCell.LayoutOrder = 10
	codeCell.BackgroundColor3 = Color3.fromRGB(45, 30, 75)
	corner(codeCell, 14)
	codeCell.Parent = list
	local box = Instance.new("TextBox")
	box.PlaceholderText = "🎟️ Enter code"
	box.Text = ""
	box.ClearTextOnFocus = false
	box.Font = FONT
	box.TextScaled = true
	box.TextColor3 = Color3.new(1, 1, 1)
	box.BackgroundColor3 = Color3.fromRGB(25, 15, 45)
	box.Position = UDim2.fromScale(0.04, 0.12)
	box.Size = UDim2.fromScale(0.58, 0.76)
	corner(box, 10)
	box.Parent = codeCell
	button(codeCell, { Text = "Redeem", Size = UDim2.fromScale(0.32, 0.76), Position = UDim2.fromScale(0.65, 0.12) }, Color3.fromRGB(90, 210, 120), function()
		Action0:FireServer("Redeem", box.Text)
		box.Text = ""
	end)
	local _any = false
	local function shopItem(info, color, prompt)
		if info.Id == 0 then
			return
		end
		_any = true
		button(list, { Text = info.Title .. "\n" .. info.Desc .. "\n R$ " .. info.Price, LayoutOrder = 20 }, color, prompt)
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


	local rebirth = panel("Rebirth", "♻️ Rebirth")
	local rebInfo = text(rebirth, { Text = "", Size = UDim2.fromScale(0.55, 0.3), Position = UDim2.fromScale(0.04, 0.17), TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left })
	local Action = Net.event("Action")
	button(rebirth, { Text = "Rebirth!", Size = UDim2.fromScale(0.34, 0.14), Position = UDim2.fromScale(0.62, 0.22) }, Color3.fromRGB(170, 90, 255), function()
		Action:FireServer("Rebirth")
		rebirth.Visible = false
	end)

	-- ===== Новые панели: Gear / Index / Quests =====
	local function scroller(parent, cell)
		local sf = Instance.new("ScrollingFrame")
		sf.BackgroundTransparency = 1
		sf.Position = UDim2.fromScale(0.04, 0.2)
		sf.Size = UDim2.fromScale(0.92, 0.76)
		sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
		sf.CanvasSize = UDim2.new()
		sf.ScrollBarThickness = 6
		sf.Parent = parent
		local g = Instance.new("UIGridLayout")
		g.CellSize = cell
		g.CellPadding = UDim2.fromOffset(8, 8)
		g.SortOrder = Enum.SortOrder.LayoutOrder
		g.Parent = sf
		return sf
	end
	local function clear(sf)
		for _, c in sf:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
	end

	local tokensText = text(rebirth, { Text = "🔮 Tokens: 0", Size = UDim2.fromScale(0.5, 0.07), Position = UDim2.fromScale(0.04, 0.5), TextColor3 = Color3.fromRGB(210, 170, 255), TextXAlignment = Enum.TextXAlignment.Left })
	local perkList = Instance.new("ScrollingFrame")
	perkList.BackgroundTransparency = 1
	perkList.Position = UDim2.fromScale(0.04, 0.59)
	perkList.Size = UDim2.fromScale(0.92, 0.38)
	perkList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	perkList.CanvasSize = UDim2.new()
	perkList.ScrollBarThickness = 6
	perkList.Parent = rebirth
	local pl = Instance.new("UIGridLayout")
	pl.CellSize = UDim2.new(0.49, 0, 0, 52)
	pl.CellPadding = UDim2.fromOffset(6, 6)
	pl.Parent = perkList

	local basePanel = panel("Base", "🏠 Base Upgrades")
	local buddyBtn = button(basePanel, { Text = "🐾 Buddy: ON", Size = UDim2.fromScale(0.26, 0.12), Position = UDim2.fromScale(0.58, 0.04) }, Color3.fromRGB(255, 150, 200), function()
		Net.event("Action"):FireServer("ToggleBuddy")
	end)
	local gearPanel = panel("Gear", "🧰 Gear Shop")
	local gearList = scroller(gearPanel, UDim2.new(1, 0, 0, 70))

	-- строка покупки слотов
	local slotRow = Instance.new("Frame")
	slotRow.BackgroundColor3 = Color3.fromRGB(60, 40, 100)
	slotRow.Position = UDim2.fromScale(0.04, 0.19)
	slotRow.Size = UDim2.fromScale(0.92, 0.14)
	corner(slotRow, 14)
	stroke(slotRow, Color3.fromRGB(140, 255, 200), 2)
	slotRow.Position = UDim2.fromScale(0.04, 0.22)
	slotRow.Size = UDim2.fromScale(0.92, 0.2)
	slotRow.Parent = basePanel
	local lockRow = slotRow:Clone()
	lockRow.Position = UDim2.fromScale(0.04, 0.46)
	lockRow.Parent = basePanel
	local trapRow = slotRow:Clone()
	trapRow.Position = UDim2.fromScale(0.04, 0.7)
	trapRow.Parent = basePanel
	local trapText = text(trapRow, { Text = "🪤 Entrance Trap", Size = UDim2.fromScale(0.62, 0.8), Position = UDim2.fromScale(0.03, 0.1), TextXAlignment = Enum.TextXAlignment.Left })
	local trapBtn = button(trapRow, { Text = "...", Size = UDim2.fromScale(0.3, 0.8), Position = UDim2.fromScale(0.67, 0.1) }, Color3.fromRGB(170, 80, 255), function()
		Action:FireServer("BuyTrap")
	end)
	local lockText = text(lockRow, { Text = "🔒 Lock Upgrade", Size = UDim2.fromScale(0.62, 0.8), Position = UDim2.fromScale(0.03, 0.1), TextXAlignment = Enum.TextXAlignment.Left })
	local lockBtn = button(lockRow, { Text = "...", Size = UDim2.fromScale(0.3, 0.8), Position = UDim2.fromScale(0.67, 0.1) }, Color3.fromRGB(255, 90, 120), function()
		Action:FireServer("BuyLock")
	end)
	local slotText = text(slotRow, { Text = "🫧 +1 Slime Slot", Size = UDim2.fromScale(0.62, 0.8), Position = UDim2.fromScale(0.03, 0.1), TextXAlignment = Enum.TextXAlignment.Left })
	local slotBtn = button(slotRow, { Text = "...", Size = UDim2.fromScale(0.3, 0.8), Position = UDim2.fromScale(0.67, 0.1) }, Color3.fromRGB(80, 200, 120), function()
		Action:FireServer("BuySlot")
	end)
	local indexPanel = panel("Index", "📖 Slime Index")
	local indexInfo = text(indexPanel, { Text = "", Size = UDim2.fromScale(0.5, 0.08), Position = UDim2.fromScale(0.36, 0.06), TextColor3 = Color3.fromRGB(140, 255, 160), TextXAlignment = Enum.TextXAlignment.Right })
	local indexList = scroller(indexPanel, UDim2.new(0.235, 0, 0, 74))
	local questPanel = panel("Quests", "📜 Daily Quests")
	local questList = scroller(questPanel, UDim2.new(1, 0, 0, 74))
	local fusePanel = panel("Fuse", "⚗️ Fuse 3 → MEGA (x6 cash)")
	local fuseList = scroller(fusePanel, UDim2.new(1, 0, 0, 64))
	local fuseKey = ""
	local function rebuildFuse(list)
		local key = ""
		for _, g in list do
			key ..= g.Id .. g.Count .. ","
		end
		if key == fuseKey then
			return
		end
		fuseKey = key
		clear(fuseList)
		if #list == 0 then
			text(fuseList, { Text = "Collect 3 of the same slime to fuse a MEGA!", Size = UDim2.new(1, 0, 0, 40) })
		end
		for i, g in list do
			local def = Pets.ById[g.Id]
			if def then
				local row = Instance.new("Frame")
				row.LayoutOrder = if g.Count >= Config.Fuse.Need then i else 100 + i
				row.BackgroundColor3 = Color3.fromRGB(45, 30, 75)
				corner(row, 14)
				stroke(row, Config.Rarities[def.Rarity].Color, 2)
				row.Parent = fuseList
				text(row, { Text = ("%s  x%d"):format(def.Name, g.Count), Size = UDim2.fromScale(0.6, 0.7), Position = UDim2.fromScale(0.03, 0.15), TextXAlignment = Enum.TextXAlignment.Left })
				if g.Count >= Config.Fuse.Need then
					button(row, { Text = "Fuse!", Size = UDim2.fromScale(0.3, 0.75), Position = UDim2.fromScale(0.67, 0.12) }, Color3.fromRGB(255, 190, 40), function()
						Action:FireServer("Fuse", g.Id)
					end)
				else
					text(row, { Text = g.Count .. "/" .. Config.Fuse.Need, Size = UDim2.fromScale(0.3, 0.6), Position = UDim2.fromScale(0.67, 0.2), TextColor3 = Color3.fromRGB(200, 200, 220) })
				end
			end
		end
	end
	local potionBtns = {}

	-- 🎡 Колесо удачи
	local spinPanel = panel("Spin", "🎡 Lucky Spin (free every 4h)")
	local spinRows = {}
	for i, pr in Config.Spin.Prizes do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Color3.fromRGB(45, 30, 75)
		row.Position = UDim2.new(0.06, 0, 0.18 + (i - 1) * 0.085, 0)
		row.Size = UDim2.fromScale(0.5, 0.075)
		corner(row, 10)
		row.Parent = spinPanel
		text(row, { Text = pr.Label, Size = UDim2.fromScale(0.94, 0.8), Position = UDim2.fromScale(0.03, 0.1) })
		spinRows[i] = row
	end
	local spinResult = text(spinPanel, { Text = "", Size = UDim2.fromScale(0.36, 0.3), Position = UDim2.fromScale(0.6, 0.25), TextColor3 = Color3.fromRGB(255, 240, 150) })
	local spinBtn = button(spinPanel, { Text = "SPIN!", Size = UDim2.fromScale(0.32, 0.16), Position = UDim2.fromScale(0.62, 0.66) }, Color3.fromRGB(255, 120, 60), function()
		Action:FireServer("Spin")
	end)
	local spinning = false
	local hatchFrame = Instance.new("Frame")
	hatchFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	hatchFrame.BackgroundTransparency = 0.45
	hatchFrame.Size = UDim2.fromScale(1, 1)
	hatchFrame.Visible = false
	hatchFrame.ZIndex = 50
	hatchFrame.Parent = gui
	local hatchIcon = text(hatchFrame, { Text = "🥚", Size = UDim2.fromScale(0.3, 0.3), Position = UDim2.fromScale(0.35, 0.25), ZIndex = 51 })
	local hatchName = text(hatchFrame, { Text = "", Size = UDim2.fromScale(0.6, 0.1), Position = UDim2.fromScale(0.2, 0.58), ZIndex = 51 })
	local hatchRarity = text(hatchFrame, { Text = "", Size = UDim2.fromScale(0.4, 0.06), Position = UDim2.fromScale(0.3, 0.69), ZIndex = 51 })
	Net.event("Reward").OnClientEvent:Connect(function(kind, d)
		if kind == "Hatch" then
			local def = Pets.ById[d.Id]
			local egg
			for _, e in Config.Eggs do
				if e.Id == d.Egg then
					egg = e
				end
			end
			hatchFrame.Visible = true
			hatchName.Text = ""
			hatchRarity.Text = ""
			hatchIcon.Text = egg and egg.Icon or "🥚"
			for k = 1, 12 do
				hatchIcon.Rotation = (if k % 2 == 0 then 1 else -1) * (6 + k * 1.5)
				task.wait(0.08)
			end
			hatchIcon.Rotation = 0
			hatchIcon.Text = "🫧"
			local r = Config.Rarities[def.Rarity]
			local v = d.V and Config.Variants[d.V]
			hatchName.Text = (if v then v.Label .. " " else "") .. def.Name
			hatchName.TextColor3 = if v then v.Color else def.Color
			hatchRarity.Text = r.Name
			hatchRarity.TextColor3 = r.Color
			task.wait(1.6)
			hatchFrame.Visible = false
			return
		end
		if kind ~= "Spin" or spinning then
			return
		end
		spinning = true
		spinResult.Text = ""
		local n = #spinRows
		local steps = n * 3 + d.Index
		for k = 1, steps do
			for i, row in spinRows do
				row.BackgroundColor3 = if i == ((k - 1) % n) + 1 then Color3.fromRGB(255, 190, 40) else Color3.fromRGB(45, 30, 75)
			end
			task.wait(0.04 + (k / steps) ^ 3 * 0.25)
		end
		spinResult.Text = "🎉 " .. d.Text
		spinning = false
	end)

	-- 🎁 Подарок за время (справа)
	local giftBtn = button(gui, { Text = "🎁", Size = UDim2.fromOffset(120, 64), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0) }, Color3.fromRGB(255, 120, 180), function()
		Action:FireServer("ClaimGift")
	end)
	HUD.GiftBtn = giftBtn

	local meta = nil
	local questsBtnCap

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
		potionBtns = {}
		for i, pdef in Config.Potions do
			local row = Instance.new("Frame")
			row.LayoutOrder = 100 + i
			row.BackgroundColor3 = Color3.fromRGB(35, 55, 70)
			corner(row, 14)
			row.Parent = gearList
			text(row, { Text = pdef.Icon .. " " .. pdef.Name, Size = UDim2.new(0.62, 0, 0.5, 0), Position = UDim2.fromScale(0.03, 0.05), TextXAlignment = Enum.TextXAlignment.Left })
			text(row, { Text = pdef.Desc, Size = UDim2.new(0.62, 0, 0.36, 0), Position = UDim2.fromScale(0.03, 0.56), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 240, 255) })
			potionBtns[pdef.Id] = button(row, { Text = "...", Size = UDim2.fromScale(0.3, 0.7), Position = UDim2.fromScale(0.67, 0.15) }, Color3.fromRGB(60, 170, 220), function()
				Action:FireServer("BuyPotion", pdef.Id)
			end)
		end
		for i, g in Config.Gear do
			local row = Instance.new("Frame")
			row.LayoutOrder = i
			row.BackgroundColor3 = Color3.fromRGB(45, 30, 75)
			corner(row, 14)
			row.Parent = gearList
			text(row, { Text = g.Icon .. " " .. g.Name, Size = UDim2.new(0.62, 0, 0.5, 0), Position = UDim2.fromScale(0.03, 0.05), TextXAlignment = Enum.TextXAlignment.Left })
			text(row, { Text = g.Desc, Size = UDim2.new(0.62, 0, 0.36, 0), Position = UDim2.fromScale(0.03, 0.56), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(210, 200, 255) })
			if owned[g.Id] then
				text(row, { Text = "✅ OWNED", Size = UDim2.fromScale(0.3, 0.6), Position = UDim2.fromScale(0.67, 0.2), TextColor3 = Color3.fromRGB(140, 255, 160) })
			else
				button(row, { Text = Format.money(g.Price), Size = UDim2.fromScale(0.3, 0.7), Position = UDim2.fromScale(0.67, 0.15) }, Color3.fromRGB(80, 200, 120), function()
					Action:FireServer("BuyGear", g.Id)
				end)
			end
		end
		-- Index
		clear(indexList)
		local found = {}
		for _, id in meta.Index do
			found[id] = true
		end
		indexInfo.Text = ("%d/%d · +%d%% cash"):format(#meta.Index, meta.Total, math.floor(meta.Bonus * 100 + 0.5))
		for i, def in Pets.List do
			local r = Config.Rarities[def.Rarity]
			local cell = Instance.new("Frame")
			cell.LayoutOrder = def.Rarity * 100 + i
			cell.BackgroundColor3 = if found[def.Id] then def.Color:Lerp(Color3.new(0, 0, 0), 0.35) else Color3.fromRGB(30, 25, 40)
			corner(cell, 12)
			stroke(cell, r.Color, 2)
			cell.Parent = indexList
			text(cell, { Text = if found[def.Id] then def.Name else "???", Size = UDim2.new(0.94, 0, 0.5, 0), Position = UDim2.fromScale(0.03, 0.08) })
			text(cell, { Text = (if def.Event then "🎃 " else "") .. r.Name, Size = UDim2.new(0.94, 0, 0.32, 0), Position = UDim2.fromScale(0.03, 0.6), TextColor3 = r.Color })
		end
		-- Quests
		clear(questList)
		local claimable = 0
		for i, q in meta.Quests do
			local qdef
			for _, d in Config.Quests do
				if d.Kind == q.Kind then
					qdef = d
				end
			end
			local row = Instance.new("Frame")
			row.LayoutOrder = i
			row.BackgroundColor3 = Color3.fromRGB(45, 30, 75)
			corner(row, 14)
			row.Parent = questList
			local done = q.Prog >= q.Goal
			text(row, { Text = (qdef and string.format(qdef.Text, q.Goal) or q.Kind), Size = UDim2.new(0.62, 0, 0.5, 0), Position = UDim2.fromScale(0.03, 0.06), TextXAlignment = Enum.TextXAlignment.Left })
			text(row, { Text = ("%d / %d  ·  reward %s"):format(q.Prog, q.Goal, Format.money(meta.QuestRewards[i] or 0)), Size = UDim2.new(0.62, 0, 0.34, 0), Position = UDim2.fromScale(0.03, 0.58), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 240, 150) })
			if q.Claimed then
				text(row, { Text = "✅ Claimed", Size = UDim2.fromScale(0.3, 0.6), Position = UDim2.fromScale(0.67, 0.2), TextColor3 = Color3.fromRGB(140, 255, 160) })
			elseif done then
				claimable += 1
				button(row, { Text = "Claim!", Size = UDim2.fromScale(0.3, 0.7), Position = UDim2.fromScale(0.67, 0.15) }, Color3.fromRGB(255, 190, 40), function()
					Action:FireServer("ClaimQuest", i)
				end)
			else
				text(row, { Text = "⏳", Size = UDim2.fromScale(0.3, 0.6), Position = UDim2.fromScale(0.67, 0.2) })
			end
		end
		-- Achievements (под квестами)
		local header = text(questList, { Text = "🏆 ACHIEVEMENTS", Size = UDim2.new(1, 0, 0, 30), TextColor3 = Color3.fromRGB(255, 215, 90) })
		header.LayoutOrder = 50
		for i, a in meta.Ach or {} do
			local row = Instance.new("Frame")
			row.LayoutOrder = 60 + i + (if a.Done then 100 else 0)
			row.BackgroundColor3 = if a.Done then Color3.fromRGB(40, 70, 50) else Color3.fromRGB(45, 30, 75)
			corner(row, 14)
			row.Parent = questList
			text(row, { Text = (if a.Done then "✅ " else "🏆 ") .. a.Name, Size = UDim2.new(0.62, 0, 0.5, 0), Position = UDim2.fromScale(0.03, 0.06), TextXAlignment = Enum.TextXAlignment.Left })
			local goalText = if a.Stat == "TotalEarned" then Format.money(a.Prog) .. " / " .. Format.money(a.Goal) else a.Prog .. " / " .. a.Goal
			text(row, { Text = a.Stat .. ": " .. goalText, Size = UDim2.new(0.62, 0, 0.34, 0), Position = UDim2.fromScale(0.03, 0.58), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 200, 230) })
			text(row, { Text = if a.Tokens > 0 then "🔮 +" .. a.Tokens else "💰", Size = UDim2.fromScale(0.3, 0.6), Position = UDim2.fromScale(0.67, 0.2), TextColor3 = Color3.fromRGB(210, 170, 255) })
		end
		-- Перки (в панели Rebirth)
		tokensText.Text = "🔮 Rebirth Tokens: " .. (meta.Tokens or 0)
		clear(perkList)
		for i, pk in Config.Perks do
			local lvl = (meta.Perks and meta.Perks[pk.Id]) or 0
			local b = button(perkList, { Text = ("%s Lv.%d/%d\n%s"):format(pk.Name, lvl, pk.Max, if lvl >= pk.Max then "MAX" else "🔮 " .. pk.Cost), LayoutOrder = i }, if lvl >= pk.Max then Color3.fromRGB(80, 80, 100) else Color3.fromRGB(140, 80, 220), function()
				Action:FireServer("BuyPerk", pk.Id)
			end)
			b.TextScaled = true
		end
		if questsBtnCap then
			questsBtnCap.Text = if claimable > 0 then "Claim " .. claimable .. "!" else "Quests"
		end
	end
	Net.event("Meta").OnClientEvent:Connect(function(m)
		meta = m
		rebuildMeta()
	end)
	local allPanels = { shop, rebirth, gearPanel, indexPanel, questPanel, fusePanel, spinPanel, basePanel }

	-- Кнопки слева: сетка 3x3
	local side = Instance.new("Frame")
	side.BackgroundTransparency = 1
	side.AnchorPoint = Vector2.new(0, 0.5)
	side.Position = UDim2.new(0, 10, 0.5, 0)
	side.Size = UDim2.fromOffset(204, 272)
	side.Parent = gui
	HUD.Side = side
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(62, 62)
	gl.CellPadding = UDim2.fromOffset(6, 6)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = side
	local function toggle(p)
		local was = p.Visible
		for _, x in allPanels do
			x.Visible = false
		end
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
	iconButton("🧰", "Gear", Color3.fromRGB(70, 200, 160), function()
		toggle(gearPanel)
	end)
	iconButton("📖", "Index", Color3.fromRGB(90, 140, 255), function()
		toggle(indexPanel)
	end)
	questsBtnCap = iconButton("📜", "Quests", Color3.fromRGB(255, 140, 60), function()
		toggle(questPanel)
	end)
	iconButton("⚗️", "Fuse", Color3.fromRGB(255, 200, 60), function()
		toggle(fusePanel)
	end)
	local spinCap = iconButton("🎡", "Spin", Color3.fromRGB(255, 110, 70), function()
		toggle(spinPanel)
	end)
	iconButton("🏠", "Base", Color3.fromRGB(120, 200, 255), function()
		toggle(basePanel)
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
		slotText.Text = ("🫧 +1 Slime Slot  (%d/%d bought)"):format(s.SlotsBought or 0, s.SlotsBuyMax or 6)
		slotBtn.Text = if (s.SlotCost or -1) < 0 then "MAX" else Format.money(s.SlotCost)
		local durs = Config.LockUpgrade.Durations
		local lv = s.LockLevel or 0
		lockText.Text = ("🔒 Lock Lv.%d  (%ds%s)"):format(lv + 1, durs[lv + 1] or durs[#durs], if durs[lv + 2] then " → " .. durs[lv + 2] .. "s" else "")
		lockBtn.Text = if (s.LockCost or -1) < 0 then "MAX" else Format.money(s.LockCost)
		buddyBtn.Text = if s.Buddy then "🐾 Buddy: ON" else "🐾 Buddy: OFF"
		local tl = s.TrapLevel or 0
		trapText.Text = if tl > 0 then ("🪤 Trap Lv.%d  (stun %ss)"):format(tl, tostring(Config.Trap.Stun[tl])) else "🪤 Entrance Trap (stuns thieves)"
		trapBtn.Text = if (s.TrapCost or -1) < 0 then "MAX" else Format.money(s.TrapCost)
		rebuildFuse(s.Fusable or {})
		local rw = s.Rewards
		if rw then
			spinCap.Text = if rw.SpinIn <= 0 then "SPIN!" else Format.time(rw.SpinIn)
			spinBtn.Text = if rw.SpinIn <= 0 then "SPIN!" else Format.time(rw.SpinIn)
			for id, b in potionBtns do
				if b.Parent and rw.PotionPrices[id] then
					b.Text = Format.money(rw.PotionPrices[id])
				end
			end
			if rw.CashPotionIn > 0 then
				income.Text ..= "  🧪x2 " .. Format.time(rw.CashPotionIn)
			end
			local g = rw.Gift
			if not g or g.Done then
				giftBtn.Visible = false
			else
				giftBtn.Visible = true
				giftBtn.Text = if g.Ready then ("🎁 CLAIM!\n%d/%d"):format(g.Index, g.Total) else ("🎁 %d/%d\n%s"):format(g.Index, g.Total, Format.time(g.ReadyIn))
				giftBtn.BackgroundColor3 = if g.Ready then Color3.fromRGB(90, 220, 110) else Color3.fromRGB(255, 120, 180)
			end
		end
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
