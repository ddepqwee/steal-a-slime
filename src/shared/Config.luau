--!nonstrict
-- ============================================================
--  ГЛАВНЫЙ КОНФИГ ИГРЫ. Новый плейс на движке = новый Config + Pets.
-- ============================================================
local Config = {}

Config.GameName = "Steal a Slime!"
Config.DataStoreName = "SlimeData_v1"
Config.LeaderboardStore = "SlimeTopEarned_v1"

-- Админы: им доступен режим съёмки шортсов (F6/F7). Вставь свой UserId.
Config.Admins = {} :: { number }
Config.AdminNames = { "daggers1233" } :: { string }

-- Группа Roblox: бонус +10% к доходу за вступление (0 = выключено)
Config.GroupId = 0
Config.GroupIncomeBonus = 0.10

-- Экономика
Config.StartCash = 100
Config.BaseSlots = 10
Config.ExtraSlotsFromPass = 4
Config.OfflineMaxSeconds = 2 * 60 * 60
Config.OfflineRate = 0.25 -- доля дохода, которую получаешь офлайн
Config.SellRate = 0.5

-- Спавн слаймов на дороге
Config.SpawnInterval = 2.5
Config.ConveyorSpeed = 9
Config.GoldChance = 0.04 -- x3 дохода
Config.RainbowChance = 0.005 -- x8 дохода
Config.Variants = {
	Gold = { Mult = 3, Color = Color3.fromRGB(255, 200, 40), Label = "GOLD" },
	Rainbow = { Mult = 8, Color = Color3.fromRGB(255, 80, 200), Label = "RAINBOW" },
}

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
}
Config.AnnounceFromRarity = 5 -- с Legendary объявляем на весь сервер

-- Монетизация. Создай пассы/продукты на create.roblox.com и впиши сюда их ID.
-- Пока Id = 0, кнопка в магазине скрыта.
Config.GamePasses = {
	DoubleCash = { Id = 0, Title = "2x Cash", Desc = "Double cash forever", Price = 199 },
	VIP = { Id = 0, Title = "VIP", Desc = "+25% luck, +speed, VIP tag", Price = 299 },
	ExtraSlots = { Id = 0, Title = "+4 Slots", Desc = "More room on your base", Price = 149 },
	LongLock = { Id = 0, Title = "Mega Lock", Desc = "Base lock lasts 2x longer", Price = 99 },
}
Config.Products = {
	CashSmall = { Id = 0, Title = "Cash Pack", Desc = "10 minutes of income", Kind = "Cash", Minutes = 10, Min = 1_000, Price = 29 },
	CashBig = { Id = 0, Title = "Cash Vault", Desc = "1 hour of income", Kind = "Cash", Minutes = 60, Min = 10_000, Price = 129 },
	LuckySpawn = { Id = 0, Title = "Lucky Spawn", Desc = "Next slime: Legendary 75% · Mythic 20.8% · Secret 4.2% (+GOLD/RAINBOW chance)", Kind = "LuckySpawn", Price = 79 },
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
	Raid = { Count = 4, Duration = 45, RewardMinutes = 3, RewardMin = 2_000 },
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
