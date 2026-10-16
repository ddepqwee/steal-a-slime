--!nonstrict
-- ============================================================
--  ГЛАВНЫЙ КОНФИГ ИГРЫ. Новый плейс на движке = новый Config + Pets.
-- ============================================================
local Config = {}

Config.GameName = "Steal a Slime!"
Config.DataStoreName = "SlimeData_v1"
Config.LeaderboardStore = "SlimeTopEarned_v1"
Config.StealsBoardStore = "SlimeTopSteals_v1"

-- Админы: им доступен режим съёмки шортсов (F6/F7). Вставь свой UserId.
Config.Admins = {} :: { number }
Config.AdminNames = { "daggers1233" } :: { string }

-- Группа Roblox: бонус +10% к доходу за вступление (0 = выключено)
Config.GroupId = 0
Config.GroupIncomeBonus = 0.10

-- Экономика
Config.StartCash = 100
Config.BaseSlots = 12
Config.ExtraSlotsFromPass = 3
-- Докупка слотов за игровые деньги: до +6, цена растёт
Config.SlotUpgrade = { Max = 6, BaseCost = 500, CostMult = 3.2 }
Config.OfflineMaxSeconds = 2 * 60 * 60
Config.OfflineRate = 0.25 -- доля дохода, которую получаешь офлайн
Config.SellRate = 0.5

-- Спавн слаймов на дороге
Config.SpawnInterval = 2.5
Config.ConveyorSpeed = 9
Config.GoldChance = 0.04 -- x3 дохода
Config.RainbowChance = 0.005 -- x8 дохода
-- Мутации. Chance — шанс на дороге (Gold/Rainbow масштабируются ивентами и удачей).
Config.Variants = {
	Gold = { Mult = 3, Color = Color3.fromRGB(255, 200, 40), Label = "GOLD", Icon = "🟡" },
	Candy = { Mult = 4, Color = Color3.fromRGB(255, 130, 200), Label = "CANDY", Icon = "🍬", Season = "Halloween" },
	Diamond = { Mult = 5, Color = Color3.fromRGB(120, 230, 255), Label = "DIAMOND", Icon = "💎" },
	Rainbow = { Mult = 8, Color = Color3.fromRGB(255, 80, 200), Label = "RAINBOW", Icon = "🌈" },
	Galaxy = { Mult = 12, Color = Color3.fromRGB(70, 30, 140), Label = "GALAXY", Icon = "🌌" },
}
Config.VariantRoll = {
	{ V = "Galaxy", Chance = 0.0015 },
	{ V = "Rainbow", Chance = 0.005, Luck = true },
	{ V = "Diamond", Chance = 0.015 },
	{ V = "Candy", Chance = 0.03 },
	{ V = "Gold", Chance = 0.04, Gold = true },
}

-- Мутация своего слайма за деньги (кнопка R). Шансы показываются игроку.
Config.Mutate = {
	CostMult = 1.5, -- от текущей стоимости слайма
	Odds = { { V = "Gold", W = 50 }, { V = "Diamond", W = 30 }, { V = "Rainbow", W = 15 }, { V = "Galaxy", W = 5 } },
}

-- Слияние: 3 одинаковых слайма → MEGA (доход x6)
Config.Fuse = { Need = 3, MegaMult = 6, MegaSize = 1.35 }

-- Прокачка замка базы
Config.LockUpgrade = { Durations = { 60, 80, 100, 130 }, Costs = { 5_000, 75_000, 1_200_000 } }

-- Кража и защита
Config.StealHold = 1.2
Config.StealTimeout = 45
Config.CarrySpeedMult = 0.8
Config.LockDuration = 60
Config.LockCooldown = 10
Config.BonkCooldown = 0.8
Config.BonkRange = 8

-- Прокачка скорости
Config.Speed = { BaseWalk = 16, Step = 1.5, MaxLevel = 30, BaseCost = 100, CostMult = 1.55, VipBonus = 4 }

-- Ребёрт
Config.Rebirth = { BaseCost = 1_000_000, CostMult = 4, IncomeBonus = 0.5 }

-- Соц. механики
Config.FriendBoostEach = 0.10
Config.FriendBoostMax = 0.50
Config.DailyCooldown = 20 * 60 * 60
Config.DailyStreakMax = 7

-- Редкости: вес шанса спавна и цвет
Config.Rarities = {
	{ Name = "Common", Weight = 560, Color = Color3.fromRGB(200, 200, 200) },
	{ Name = "Uncommon", Weight = 260, Color = Color3.fromRGB(90, 220, 90) },
	{ Name = "Rare", Weight = 110, Color = Color3.fromRGB(70, 150, 255) },
	{ Name = "Epic", Weight = 45, Color = Color3.fromRGB(170, 80, 255) },
	{ Name = "Legendary", Weight = 18, Color = Color3.fromRGB(255, 170, 0) },
	{ Name = "Mythic", Weight = 5, Color = Color3.fromRGB(255, 50, 90) },
	{ Name = "Secret", Weight = 1, Color = Color3.fromRGB(20, 255, 220) },
	{ Name = "Celestial", Weight = 0.25, Color = Color3.fromRGB(255, 240, 150), RequireRebirth = 3 },
}
Config.AnnounceFromRarity = 5 -- с Legendary объявляем на весь сервер

-- Монетизация. Создай пассы/продукты на create.roblox.com и впиши сюда их ID.
-- Пока Id = 0, кнопка в магазине скрыта.
Config.GamePasses = {
	DoubleCash = { Id = 0, Title = "2x Cash", Desc = "Double cash forever", Price = 199 },
	VIP = { Id = 0, Title = "VIP", Desc = "+25% luck, +speed, VIP tag", Price = 299 },
	ExtraSlots = { Id = 0, Title = "+3 Slots", Desc = "More room on your base", Price = 149 },
	LongLock = { Id = 0, Title = "Mega Lock", Desc = "Base lock lasts 2x longer", Price = 99 },
}
Config.Products = {
	CashSmall = { Id = 0, Title = "Cash Pack", Desc = "10 minutes of income", Kind = "Cash", Minutes = 10, Min = 1_000, Price = 29 },
	CashBig = { Id = 0, Title = "Cash Vault", Desc = "1 hour of income", Kind = "Cash", Minutes = 60, Min = 10_000, Price = 129 },
	LuckySpawn = { Id = 0, Title = "Lucky Spawn", Desc = "Next slime: Legendary 74.2% · Mythic 20.6% · Secret 4.1% · Celestial 1% (+mutation chance)", Kind = "LuckySpawn", Price = 79 },
	ServerLuck = { Id = 0, Title = "Server Luck x2", Desc = "15 min of luck for the whole server", Kind = "ServerLuck", Minutes = 15, Price = 99 },
}

-- Расписание авто-ивентов (UTC). Работают сами, без апдейтов.
Config.Schedule = {
	{ Name = "LUCKY RAIN x2", EveryHours = 1, StartMinute = 0, Duration = 10, Luck = 2 },
	{ Name = "GOLDEN RUSH", EveryHours = 3, StartMinute = 30, Duration = 10, Gold = 5 },
	{ Name = "CASH STORM x2", EveryHours = 4, StartMinute = 45, Duration = 10, Cash = 2 },
}

-- Прокачка слаймов: доход x IncomeMult^(L-1), цена шага = Price * CostBase * CostMult^(L-1)
Config.Upgrade = { MaxLevel = 10, IncomeMult = 1.5, CostBase = 0.6, CostMult = 1.7, SizePerLevel = 0.05 }

-- Слайм-индекс: за каждые StepPercent% коллекции +BonusPerStep к доходу
Config.Index = { StepPercent = 10, BonusPerStep = 0.05 }

-- Снаряжение (Gear Shop) — покупается за игровые деньги, остаётся навсегда
Config.Gear = {
	{ Id = "SpeedCoil", Name = "Speed Coil", Icon = "🌀", Desc = "+8 speed while holding", Price = 2_500 },
	{ Id = "GravityBoots", Name = "Gravity Boots", Icon = "🥾", Desc = "Jump 2x higher while holding", Price = 25_000 },
	{ Id = "MegaBat", Name = "Mega Bat", Icon = "🏏", Desc = "Bigger BONK range + knockback", Price = 250_000 },
	{ Id = "Cloak", Name = "Invisibility Cloak", Icon = "👻", Desc = "Turn invisible for 8s (30s cooldown)", Price = 5_000_000 },
}

-- Случайные события мира
Config.WorldEvents = {
	MinGap = 240, -- секунд между событиями
	MaxGap = 420,
	Meteor = { Warn = 10, ClaimHold = 2.5, MinRarity = 5, Lifetime = 60 },
	Rain = { Count = 18, Duration = 30, LuckMult = 3 },
	Raid = { Count = 12, Duration = 60, RewardSeconds = 20, RewardMin = 150, SlimeChance = 0.08, Speed = 17, FleeRange = 18 },
}

-- Ежедневные квесты (3 в день из пула)
Config.Quests = {
	{ Kind = "Buy", Text = "Buy %d slimes", Min = 5, Max = 15 },
	{ Kind = "Steal", Text = "Steal %d slimes", Min = 1, Max = 3 },
	{ Kind = "Bonk", Text = "Bonk %d thieves or bandits", Min = 2, Max = 5 },
	{ Kind = "Upgrade", Text = "Upgrade slimes %d times", Min = 3, Max = 8 },
	{ Kind = "Event", Text = "Claim %d slimes from world events", Min = 1, Max = 3 },
}
Config.QuestRewardMinutes = 8 -- награда = доход за N минут
Config.QuestRewardMin = 1_000

-- 🥚 Яйца: вылупляется случайный слайм из диапазона редкостей (веса как на дороге)
Config.Eggs = {
	{ Id = "Meadow", Name = "Meadow Egg", Icon = "🥚", Price = 1_000, MinRarity = 1, MaxRarity = 3, Color = Color3.fromRGB(150, 230, 130) },
	{ Id = "Bubble", Name = "Bubble Egg", Icon = "🫧", Price = 100_000, MinRarity = 2, MaxRarity = 5, Color = Color3.fromRGB(110, 190, 255) },
	{ Id = "Royal", Name = "Royal Egg", Icon = "👑", Price = 10_000_000, MinRarity = 3, MaxRarity = 6, Color = Color3.fromRGB(255, 200, 60) },
	{ Id = "Cosmic", Name = "Cosmic Egg", Icon = "🌌", Price = 1_000_000_000, MinRarity = 4, MaxRarity = 8, Color = Color3.fromRGB(150, 90, 255) },
}

-- 🎟️ Промокоды (регистр не важен). Kind: Cash (минуты дохода) / Slime (MinRarity) / Luck
Config.Codes = {
	SLIME = { Kind = "Cash", Minutes = 10, Min = 2_000 },
	RELEASE = { Kind = "Slime", MinRarity = 3 },
	SPOOKY = { Kind = "Slime", MinRarity = 4 },
	LUCKY = { Kind = "Luck" },
}

-- 👑 King of the Hill и ✨ Golden Hunt
Config.Hill = { Duration = 60, Radius = 14, IncomeSeconds = 2, Min = 25, SoloMult = 2 }
Config.Hunt = { Count = 12, Duration = 90, IncomeSeconds = 15, Min = 200 }

-- 🪤 Ловушка у входа базы: оглушает чужих игроков
Config.Trap = { Stun = { 2, 3, 4.5 }, Costs = { 20_000, 400_000, 8_000_000 }, Cooldown = 6 }

-- 🔮 Перки за Rebirth Tokens (вечные)
Config.Perks = {
	{ Id = "Income", Name = "💰 Income", Desc = "+10% cash per level", Max = 10, Cost = 1 },
	{ Id = "Offline", Name = "💤 Offline", Desc = "+10% offline earnings per level", Max = 5, Cost = 1 },
	{ Id = "Start", Name = "🏁 Head Start", Desc = "x3 start cash after rebirth per level", Max = 5, Cost = 1 },
	{ Id = "Speed", Name = "👟 Swift", Desc = "+1 walk speed per level", Max = 5, Cost = 2 },
}

-- 🏆 Достижения: Stat → порог. Награда: деньги (минуты дохода) + Rebirth Tokens
Config.Achievements = {
	{ Id = "Steal1", Name = "First Heist", Stat = "Steals", Goal = 1, Minutes = 3, Tokens = 0 },
	{ Id = "Steal10", Name = "Sneaky Fingers", Stat = "Steals", Goal = 10, Minutes = 10, Tokens = 1 },
	{ Id = "Steal100", Name = "Master Thief", Stat = "Steals", Goal = 100, Minutes = 30, Tokens = 2 },
	{ Id = "Bonk10", Name = "Bonk Squad", Stat = "Bonks", Goal = 10, Minutes = 5, Tokens = 0 },
	{ Id = "Bonk100", Name = "Bonk Lord", Stat = "Bonks", Goal = 100, Minutes = 20, Tokens = 1 },
	{ Id = "Up10", Name = "Trainer", Stat = "Upgrades", Goal = 10, Minutes = 5, Tokens = 0 },
	{ Id = "Up100", Name = "Slime Coach", Stat = "Upgrades", Goal = 100, Minutes = 20, Tokens = 1 },
	{ Id = "Fuse1", Name = "Mad Scientist", Stat = "Fused", Goal = 1, Minutes = 10, Tokens = 1 },
	{ Id = "Fuse10", Name = "MEGA Maker", Stat = "Fused", Goal = 10, Minutes = 30, Tokens = 2 },
	{ Id = "Mut5", Name = "Mutant", Stat = "Mutations", Goal = 5, Minutes = 10, Tokens = 0 },
	{ Id = "Event5", Name = "Event Hunter", Stat = "EventClaims", Goal = 5, Minutes = 10, Tokens = 1 },
	{ Id = "Obby1", Name = "Sky Walker", Stat = "ObbyWins", Goal = 1, Minutes = 10, Tokens = 1 },
	{ Id = "Boss1", Name = "King Slayer", Stat = "BossMVP", Goal = 1, Minutes = 20, Tokens = 2 },
	{ Id = "Reb1", Name = "Reborn", Stat = "Rebirths", Goal = 1, Minutes = 5, Tokens = 1 },
	{ Id = "Reb5", Name = "Eternal", Stat = "Rebirths", Goal = 5, Minutes = 20, Tokens = 2 },
	{ Id = "Idx25", Name = "Collector", Stat = "Index", Goal = 25, Minutes = 15, Tokens = 1 },
	{ Id = "Idx50", Name = "Slimeologist", Stat = "Index", Goal = 50, Minutes = 30, Tokens = 2 },
	{ Id = "Rich", Name = "Billionaire", Stat = "TotalEarned", Goal = 1_000_000_000, Minutes = 30, Tokens = 2 },
}

-- 🌍 Зоны с отдельными дорогами (открываются ребёртами)
Config.Zones = {
	{ Id = "Lava", Name = "🌋 LAVA LAND", Rebirth = 1, MinRarity = 2, Luck = 2, ZoneChance = 0.5, X = 0, Y = 0, Z = -360,
		Floor = Color3.fromRGB(60, 35, 35), Accent = Color3.fromRGB(255, 90, 20), Road = Color3.fromRGB(40, 20, 20), Mat = Enum.Material.Basalt },
	{ Id = "Crystal", Name = "💎 CRYSTAL CAVES", Rebirth = 3, MinRarity = 3, Luck = 3, ZoneChance = 0.5, X = 0, Y = 0, Z = 360,
		Floor = Color3.fromRGB(40, 45, 80), Accent = Color3.fromRGB(120, 220, 255), Road = Color3.fromRGB(25, 25, 60), Mat = Enum.Material.Glacier },
	{ Id = "Cloud", Name = "☁️ CLOUD KINGDOM", Rebirth = 5, MinRarity = 4, Luck = 4, ZoneChance = 0.55, X = -620, Y = 80, Z = 0,
		Floor = Color3.fromRGB(245, 245, 255), Accent = Color3.fromRGB(255, 200, 240), Road = Color3.fromRGB(190, 200, 240), Mat = Enum.Material.SmoothPlastic },
	{ Id = "Cosmic", Name = "🌌 COSMIC VOID", Rebirth = 8, MinRarity = 5, Luck = 5, ZoneChance = 0.6, X = 660, Y = 55, Z = 0,
		Floor = Color3.fromRGB(20, 10, 40), Accent = Color3.fromRGB(170, 90, 255), Road = Color3.fromRGB(10, 5, 25), Mat = Enum.Material.Slate },
}

-- 🗼 Sky Obby: сундук на вершине
Config.Obby = { Stages = 26, Cooldown = 15 * 60, RewardMinutes = 10, RewardMin = 2_500, SlimeChance = 0.15 }

-- Подарки за время в сессии (минуты). Последний — слайм Epic+.
Config.PlayGifts = {
	{ Min = 2, Kind = "Cash", Minutes = 2 },
	{ Min = 5, Kind = "Cash", Minutes = 4 },
	{ Min = 10, Kind = "Luck" },
	{ Min = 15, Kind = "Cash", Minutes = 8 },
	{ Min = 25, Kind = "Slime", MinRarity = 3 },
	{ Min = 40, Kind = "Cash", Minutes = 15 },
	{ Min = 60, Kind = "Slime", MinRarity = 4 },
}
Config.GiftCashMin = 300

-- Колесо удачи: бесплатный спин раз в 4 часа
Config.Spin = {
	Cooldown = 4 * 60 * 60,
	Prizes = {
		{ Kind = "Cash", Minutes = 3, W = 30, Label = "💵 Cash x3m" },
		{ Kind = "Cash", Minutes = 10, W = 22, Label = "💰 Cash x10m" },
		{ Kind = "Cash", Minutes = 30, W = 8, Label = "🤑 Cash x30m" },
		{ Kind = "Luck", W = 15, Label = "🍀 Server Luck" },
		{ Kind = "CashPotion", W = 12, Label = "🧪 Cash x2" },
		{ Kind = "Slime", MinRarity = 4, W = 10, Label = "🟣 Epic+ Slime" },
		{ Kind = "Slime", MinRarity = 5, W = 3, Label = "🟠 Legendary+ Slime" },
	},
}

-- Зелья (за игровые деньги, цена зависит от дохода)
Config.Potions = {
	{ Id = "Cash", Name = "Cash Potion", Icon = "🧪", Desc = "x2 cash for you · 15 min", Minutes = 15, PriceIncomeSec = 300, PriceMin = 1_500 },
	{ Id = "Luck", Name = "Server Luck Potion", Icon = "🍀", Desc = "x1.5 luck for everyone · 10 min", Minutes = 10, PriceIncomeSec = 600, PriceMin = 5_000 },
}

-- 👑 Босс
Config.Boss = { BaseHP = 40, HPPerPlayer = 25, Duration = 90, ShockEvery = 7, ShockRange = 26, RewardMinutes = 2, RewardMin = 500 }

-- Сезонный ивент: включается/выключается сам по дате (UTC)
Config.Season = {
	Name = "Halloween",
	Title = "🎃 HALLOWEEN EVENT",
	Start = 1792108800, -- 2026-10-16
	End = 1793664000, -- 2026-11-03
	EventPetChance = 0.35, -- шанс, что выпадет ивентовый слайм этой редкости
	SpookyEveryHours = 2,
	SpookyMinute = 15,
	SpookyDuration = 10,
	SpookyMult = 3,
}

-- LiveOps: удалённое управление через Open Cloud (DataStore + MessagingService)
Config.LiveOpsStore = "LiveOps"
Config.LiveOpsKey = "live"
Config.LiveOpsTopic = "LiveOps"

-- Звуки (rbxassetid). Пустая строка = без звука.
Config.Sounds = { Buy = "", Steal = "", Legendary = "", Bonk = "" }

return Config
