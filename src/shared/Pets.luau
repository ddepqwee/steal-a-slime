--!nonstrict
-- Каталог слаймов. Rarity = индекс в Config.Rarities.
-- Чтобы добавить слайма в апдейте — допиши строку.
local Pets = {}

Pets.List = {
	-- Common
	{ Id = "Blobby", Name = "Blobby", Rarity = 1, Price = 25, Income = 1, Color = Color3.fromRGB(120, 230, 120), Size = 2.4 },
	{ Id = "Mintgoo", Name = "Mintgoo", Rarity = 1, Price = 60, Income = 2, Color = Color3.fromRGB(150, 255, 210), Size = 2.5 },
	{ Id = "Puddlo", Name = "Puddlo", Rarity = 1, Price = 120, Income = 4, Color = Color3.fromRGB(110, 180, 255), Size = 2.6 },
	-- Uncommon
	{ Id = "Bubbaloo", Name = "Bubbaloo", Rarity = 2, Price = 400, Income = 10, Color = Color3.fromRGB(255, 150, 200), Size = 2.8 },
	{ Id = "Jellito", Name = "Jellito", Rarity = 2, Price = 800, Income = 18, Color = Color3.fromRGB(255, 120, 90), Size = 2.9 },
	{ Id = "Fizzle", Name = "Fizzle", Rarity = 2, Price = 1_500, Income = 30, Color = Color3.fromRGB(255, 240, 100), Size = 3.0 },
	-- Rare
	{ Id = "Gloopster", Name = "Gloopster", Rarity = 3, Price = 5_000, Income = 80, Color = Color3.fromRGB(60, 120, 255), Size = 3.2 },
	{ Id = "Splatty", Name = "Splatty", Rarity = 3, Price = 10_000, Income = 140, Color = Color3.fromRGB(255, 90, 160), Size = 3.3 },
	{ Id = "Wobbler", Name = "Wobbler", Rarity = 3, Price = 20_000, Income = 250, Color = Color3.fromRGB(90, 230, 255), Size = 3.4 },
	-- Epic
	{ Id = "SirSquish", Name = "Sir Squish", Rarity = 4, Price = 75_000, Income = 700, Color = Color3.fromRGB(160, 70, 255), Size = 3.7 },
	{ Id = "GummoBear", Name = "Gummo Bear", Rarity = 4, Price = 150_000, Income = 1_200, Color = Color3.fromRGB(255, 60, 60), Size = 3.8 },
	{ Id = "ToxicTim", Name = "Toxic Tim", Rarity = 4, Price = 300_000, Income = 2_200, Color = Color3.fromRGB(140, 255, 0), Size = 3.9 },
	-- Legendary
	{ Id = "KingGloop", Name = "King Gloop", Rarity = 5, Price = 1_200_000, Income = 7_000, Color = Color3.fromRGB(255, 190, 30), Size = 4.3, Crown = true },
	{ Id = "LavaLarry", Name = "Lava Larry", Rarity = 5, Price = 3_000_000, Income = 15_000, Color = Color3.fromRGB(255, 80, 0), Size = 4.4, Neon = true },
	{ Id = "FrostByte", Name = "Frost Byte", Rarity = 5, Price = 6_000_000, Income = 28_000, Color = Color3.fromRGB(170, 230, 255), Size = 4.5, Glass = true },
	-- Mythic
	{ Id = "CosmoSlime", Name = "Cosmo Slime", Rarity = 6, Price = 25_000_000, Income = 90_000, Color = Color3.fromRGB(90, 40, 200), Size = 5.0, Neon = true, Sparkle = true },
	{ Id = "NeonNugget", Name = "Neon Nugget", Rarity = 6, Price = 60_000_000, Income = 190_000, Color = Color3.fromRGB(0, 255, 150), Size = 5.2, Neon = true, Sparkle = true },
	-- Secret
	{ Id = "GreatBlob", Name = "The Great Blob", Rarity = 7, Price = 300_000_000, Income = 800_000, Color = Color3.fromRGB(255, 255, 255), Size = 6.0, Crown = true, Sparkle = true, Glass = true },
	{ Id = "Glitch", Name = "G̷l̷i̷t̷c̷h̷", Rarity = 7, Price = 1_000_000_000, Income = 2_500_000, Color = Color3.fromRGB(20, 20, 20), Size = 5.5, Neon = true, Sparkle = true, Glitch = true },

	-- ✨ Celestial (нужно 3 ребёрта, чтобы купить)
	{ Id = "Starling", Name = "Starling", Rarity = 8, Price = 5_000_000_000, Income = 9_000_000, Color = Color3.fromRGB(255, 245, 170), Size = 6.0, Neon = true, Sparkle = true, Crown = true },
	{ Id = "NebulaNugget", Name = "Nebula Nugget", Rarity = 8, Price = 15_000_000_000, Income = 25_000_000, Color = Color3.fromRGB(150, 90, 255), Size = 6.2, Neon = true, Sparkle = true },
	{ Id = "SolarSovereign", Name = "Solar Sovereign", Rarity = 8, Price = 50_000_000_000, Income = 75_000_000, Color = Color3.fromRGB(255, 160, 40), Size = 6.6, Neon = true, Sparkle = true, Crown = true },

	-- 🌋 Lava Land (Zone = "Lava")
	{ Id = "MagmaMite", Name = "Magma Mite", Rarity = 3, Price = 30_000, Income = 380, Color = Color3.fromRGB(255, 100, 30), Size = 3.4, Zone = "Lava", Neon = true },
	{ Id = "EmberOoze", Name = "Ember Ooze", Rarity = 4, Price = 450_000, Income = 3_400, Color = Color3.fromRGB(255, 60, 40), Size = 3.9, Zone = "Lava", Neon = true, Sparkle = true },
	{ Id = "VolcanoVex", Name = "Volcano Vex", Rarity = 5, Price = 9_000_000, Income = 42_000, Color = Color3.fromRGB(90, 30, 20), Size = 4.6, Zone = "Lava", Pumpkin = false, Crown = true, Sparkle = true },
	{ Id = "InfernoImp", Name = "Inferno Imp", Rarity = 6, Price = 90_000_000, Income = 280_000, Color = Color3.fromRGB(255, 40, 0), Size = 5.1, Zone = "Lava", Neon = true, Sparkle = true, Glitch = true },
	-- 💎 Crystal Caves (Zone = "Crystal")
	{ Id = "QuartzQuiver", Name = "Quartz Quiver", Rarity = 4, Price = 800_000, Income = 6_000, Color = Color3.fromRGB(230, 230, 255), Size = 4.0, Zone = "Crystal", Glass = true, Sparkle = true },
	{ Id = "AmethystAce", Name = "Amethyst Ace", Rarity = 5, Price = 18_000_000, Income = 80_000, Color = Color3.fromRGB(170, 90, 255), Size = 4.7, Zone = "Crystal", Glass = true, Sparkle = true },
	{ Id = "PrismPrince", Name = "Prism Prince", Rarity = 6, Price = 180_000_000, Income = 520_000, Color = Color3.fromRGB(120, 255, 240), Size = 5.3, Zone = "Crystal", Neon = true, Sparkle = true, Crown = true },
	{ Id = "CrystalColossus", Name = "Crystal Colossus", Rarity = 7, Price = 2_000_000_000, Income = 4_500_000, Color = Color3.fromRGB(150, 200, 255), Size = 6.2, Zone = "Crystal", Glass = true, Sparkle = true, Crown = true },

	-- 🆕 Пак 7: новые слаймы (основная дорога, острова Lava/Crystal/Cloud/Cosmic)
	{ Id = "Snotty", Name = "Snotty", Rarity = 1, Price = 40, Income = 1, Color = Color3.fromRGB(170, 240, 90), Size = 2.4, Antenna = true },
	{ Id = "Dewdrop", Name = "Dewdrop", Rarity = 1, Price = 85, Income = 3, Color = Color3.fromRGB(150, 210, 255), Size = 2.5, Glass = true },
	{ Id = "Mudbug", Name = "Mudbug", Rarity = 1, Price = 180, Income = 6, Color = Color3.fromRGB(150, 110, 70), Size = 2.6, Horns = true },
	{ Id = "Bowie", Name = "Bowie", Rarity = 2, Price = 600, Income = 13, Color = Color3.fromRGB(255, 170, 220), Size = 2.8, Bow = true },
	{ Id = "Zappy", Name = "Zappy", Rarity = 2, Price = 1_100, Income = 24, Color = Color3.fromRGB(255, 250, 90), Size = 2.9, Antenna = true, Neon = true },
	{ Id = "CoolCat", Name = "Cool Cat", Rarity = 2, Price = 2_200, Income = 49, Color = Color3.fromRGB(120, 200, 255), Size = 3.0, Shades = true },
	{ Id = "Pricklet", Name = "Pricklet", Rarity = 3, Price = 7_500, Income = 107, Color = Color3.fromRGB(100, 200, 120), Size = 3.2, Spikes = true },
	{ Id = "FlutterGoo", Name = "Flutter Goo", Rarity = 3, Price = 13_000, Income = 186, Color = Color3.fromRGB(255, 180, 120), Size = 3.3, Wings = true },
	{ Id = "Bubbles", Name = "Bubbles", Rarity = 3, Price = 28_000, Income = 400, Color = Color3.fromRGB(120, 240, 255), Size = 3.4, Glass = true, Sparkle = true },
	{ Id = "ImpOoze", Name = "Imp Ooze", Rarity = 3, Price = 40_000, Income = 571, Color = Color3.fromRGB(200, 40, 60), Size = 3.5, Horns = true },
	{ Id = "DJSlime", Name = "DJ Slime", Rarity = 4, Price = 110_000, Income = 917, Color = Color3.fromRGB(60, 60, 80), Size = 3.7, Shades = true, Antenna = true },
	{ Id = "CupidGoo", Name = "Cupid Goo", Rarity = 4, Price = 220_000, Income = 1_833, Color = Color3.fromRGB(255, 120, 170), Size = 3.8, Wings = true, Bow = true },
	{ Id = "Spikezilla", Name = "Spikezilla", Rarity = 4, Price = 420_000, Income = 3_500, Color = Color3.fromRGB(80, 160, 80), Size = 3.9, Spikes = true, Horns = true },
	{ Id = "Voltra", Name = "Voltra", Rarity = 4, Price = 600_000, Income = 5_000, Color = Color3.fromRGB(120, 120, 255), Size = 4.0, Neon = true, Antenna = true },
	{ Id = "SirFluff", Name = "Sir Fluff", Rarity = 5, Price = 2_000_000, Income = 10_526, Color = Color3.fromRGB(255, 245, 230), Size = 4.3, Crown = true, Bow = true },
	{ Id = "Dragoo", Name = "Dragoo", Rarity = 5, Price = 4_500_000, Income = 23_684, Color = Color3.fromRGB(60, 180, 90), Size = 4.5, Horns = true, Wings = true, Spikes = true },
	{ Id = "Shadowmere", Name = "Shadowmere", Rarity = 5, Price = 8_000_000, Income = 42_105, Color = Color3.fromRGB(40, 30, 60), Size = 4.6, Shades = true, Sparkle = true },
	{ Id = "AngelBlob", Name = "Angel Blob", Rarity = 5, Price = 11_000_000, Income = 57_895, Color = Color3.fromRGB(255, 255, 240), Size = 4.6, Wings = true, Halo = true, Sparkle = true },
	{ Id = "TitanTot", Name = "Titan Tot", Rarity = 6, Price = 35_000_000, Income = 118_644, Color = Color3.fromRGB(220, 120, 40), Size = 5.0, Horns = true, Crown = true, Sparkle = true },
	{ Id = "Seraphoo", Name = "Seraphoo", Rarity = 6, Price = 80_000_000, Income = 271_186, Color = Color3.fromRGB(255, 230, 150), Size = 5.2, Wings = true, Halo = true, Neon = true, Sparkle = true },
	{ Id = "VoidVee", Name = "Void Vee", Rarity = 6, Price = 120_000_000, Income = 406_780, Color = Color3.fromRGB(20, 0, 40), Size = 5.3, Glitch = true, Horns = true, Sparkle = true },
	{ Id = "OmegaOoze", Name = "Omega Ooze", Rarity = 7, Price = 500_000_000, Income = 1_282_051, Color = Color3.fromRGB(255, 60, 200), Size = 5.8, Neon = true, Crown = true, Wings = true, Sparkle = true },
	{ Id = "Kaiju", Name = "Slimezilla", Rarity = 7, Price = 1_500_000_000, Income = 3_846_154, Color = Color3.fromRGB(70, 200, 120), Size = 6.2, Spikes = true, Horns = true, Sparkle = true },
	{ Id = "Eternity", Name = "Eternity", Rarity = 8, Price = 30_000_000_000, Income = 50_000_000, Color = Color3.fromRGB(255, 255, 255), Size = 6.4, Neon = true, Halo = true, Wings = true, Sparkle = true, Crown = true },
	{ Id = "CinderPup", Name = "Cinder Pup", Rarity = 3, Price = 45_000, Income = 643, Color = Color3.fromRGB(255, 120, 60), Size = 3.5, Zone = "Lava", Horns = true },
	{ Id = "Obsidian", Name = "Obsidian Ooze", Rarity = 5, Price = 14_000_000, Income = 73_684, Color = Color3.fromRGB(30, 20, 30), Size = 4.7, Zone = "Lava", Spikes = true, Shades = true, Sparkle = true },
	{ Id = "Frostling", Name = "Frostling", Rarity = 4, Price = 950_000, Income = 7_917, Color = Color3.fromRGB(200, 240, 255), Size = 4.0, Zone = "Crystal", Glass = true, Antenna = true },
	{ Id = "GeodeGuard", Name = "Geode Guard", Rarity = 6, Price = 250_000_000, Income = 847_458, Color = Color3.fromRGB(140, 90, 255), Size = 5.4, Zone = "Crystal", Spikes = true, Glass = true, Sparkle = true },
	{ Id = "PuffBall", Name = "Puff Ball", Rarity = 4, Price = 1_500_000, Income = 12_500, Color = Color3.fromRGB(255, 255, 255), Size = 4.1, Zone = "Cloud", Wings = true },
	{ Id = "RainyRay", Name = "Rainy Ray", Rarity = 5, Price = 25_000_000, Income = 131_579, Color = Color3.fromRGB(160, 190, 255), Size = 4.7, Zone = "Cloud", Glass = true, Antenna = true, Sparkle = true },
	{ Id = "Thunderpuff", Name = "Thunderpuff", Rarity = 5, Price = 45_000_000, Income = 236_842, Color = Color3.fromRGB(255, 240, 120), Size = 4.8, Zone = "Cloud", Neon = true, Horns = true, Sparkle = true },
	{ Id = "Skylord", Name = "Sky Lord", Rarity = 6, Price = 300_000_000, Income = 1_016_949, Color = Color3.fromRGB(140, 210, 255), Size = 5.4, Zone = "Cloud", Wings = true, Crown = true, Sparkle = true },
	{ Id = "Halolulu", Name = "Halolulu", Rarity = 6, Price = 500_000_000, Income = 1_694_915, Color = Color3.fromRGB(255, 250, 220), Size = 5.5, Zone = "Cloud", Halo = true, Wings = true, Neon = true },
	{ Id = "ZeusGoo", Name = "Zeus Goo", Rarity = 7, Price = 4_000_000_000, Income = 10_256_410, Color = Color3.fromRGB(255, 255, 180), Size = 6.3, Zone = "Cloud", Crown = true, Halo = true, Wings = true, Neon = true, Sparkle = true },
	{ Id = "Starlet", Name = "Starlet", Rarity = 5, Price = 60_000_000, Income = 315_789, Color = Color3.fromRGB(255, 240, 160), Size = 4.9, Zone = "Cosmic", Neon = true, Antenna = true, Sparkle = true },
	{ Id = "Meteorite", Name = "Meteorite", Rarity = 6, Price = 700_000_000, Income = 2_372_881, Color = Color3.fromRGB(120, 90, 80), Size = 5.5, Zone = "Cosmic", Spikes = true, Sparkle = true },
	{ Id = "Nebulon", Name = "Nebulon", Rarity = 6, Price = 1_200_000_000, Income = 4_067_797, Color = Color3.fromRGB(160, 60, 255), Size = 5.6, Zone = "Cosmic", Neon = true, Wings = true, Sparkle = true },
	{ Id = "BlackHole", Name = "Black Hole", Rarity = 7, Price = 8_000_000_000, Income = 20_512_821, Color = Color3.fromRGB(10, 0, 20), Size = 6.4, Zone = "Cosmic", Glitch = true, Halo = true, Sparkle = true },
	{ Id = "Supernova", Name = "Supernova", Rarity = 8, Price = 80_000_000_000, Income = 133_333_333, Color = Color3.fromRGB(255, 140, 40), Size = 6.8, Zone = "Cosmic", Neon = true, Crown = true, Spikes = true, Sparkle = true },
	{ Id = "Quasar", Name = "Quasar Prime", Rarity = 8, Price = 200_000_000_000, Income = 333_333_333, Color = Color3.fromRGB(120, 255, 255), Size = 7.0, Zone = "Cosmic", Neon = true, Halo = true, Wings = true, Crown = true, Sparkle = true },

	-- 🎃 Halloween (Event = "Halloween": выпадают только во время ивента)
	{ Id = "CandyCorn", Name = "Candy Corn", Rarity = 3, Price = 15_000, Income = 200, Color = Color3.fromRGB(255, 190, 60), Size = 3.3, Event = "Halloween", Stripes = true },
	{ Id = "GhostlyGoo", Name = "Ghostly Goo", Rarity = 4, Price = 200_000, Income = 1_600, Color = Color3.fromRGB(235, 240, 255), Size = 3.9, Event = "Halloween", Ghost = true },
	{ Id = "PumpkinPete", Name = "Pumpkin Pete", Rarity = 5, Price = 4_000_000, Income = 20_000, Color = Color3.fromRGB(255, 120, 20), Size = 4.5, Event = "Halloween", Pumpkin = true },
	{ Id = "WitchyWobble", Name = "Witchy Wobble", Rarity = 6, Price = 40_000_000, Income = 130_000, Color = Color3.fromRGB(120, 40, 180), Size = 5.0, Event = "Halloween", WitchHat = true, Sparkle = true },
	-- 🌙 Moon slimes (Night = true: появляются только ночью)
	{ Id = "Moonpup", Name = "Moonpup", Rarity = 2, Price = 2_000, Income = 40, Color = Color3.fromRGB(190, 200, 255), Size = 3.0, Night = true, Antenna = true },
	{ Id = "Starglow", Name = "Starglow", Rarity = 3, Price = 25_000, Income = 330, Color = Color3.fromRGB(255, 240, 140), Size = 3.4, Night = true, Neon = true, Sparkle = true },
	{ Id = "Nightshade", Name = "Nightshade", Rarity = 4, Price = 400_000, Income = 3_000, Color = Color3.fromRGB(90, 40, 160), Size = 3.9, Night = true, Wings = true, Shades = true },
	{ Id = "LunarJelly", Name = "Lunar Jelly", Rarity = 5, Price = 9_000_000, Income = 48_000, Color = Color3.fromRGB(200, 220, 255), Size = 4.6, Night = true, Glass = true, Halo = true, Sparkle = true },
	{ Id = "Eclipse", Name = "Eclipse", Rarity = 6, Price = 90_000_000, Income = 300_000, Color = Color3.fromRGB(35, 20, 60), Size = 5.2, Night = true, Halo = true, Neon = true, Sparkle = true },
	{ Id = "MoonQueen", Name = "Moon Queen", Rarity = 7, Price = 1_800_000_000, Income = 4_500_000, Color = Color3.fromRGB(225, 230, 255), Size = 6.1, Night = true, Crown = true, Wings = true, Glass = true, Sparkle = true },

	{ Id = "Headless", Name = "The Headless Blob", Rarity = 7, Price = 600_000_000, Income = 1_600_000, Color = Color3.fromRGB(30, 10, 40), Size = 5.6, Event = "Halloween", Neon = false, Pumpkin = true, Sparkle = true, Glitch = true },
}

Pets.ById = {}
Pets.ByRarity = {}
Pets.NightByRarity = {}
for _, p in Pets.List do
	Pets.ById[p.Id] = p
	Pets.ByRarity[p.Rarity] = Pets.ByRarity[p.Rarity] or {}
	table.insert(Pets.ByRarity[p.Rarity], p)
	if p.Night then
		Pets.NightByRarity[p.Rarity] = Pets.NightByRarity[p.Rarity] or {}
		table.insert(Pets.NightByRarity[p.Rarity], p)
	end
end

-- Пул слаймов редкости: обычные + (если ивент идёт) ивентовые с отдельным шансом
function Pets.Pool(rarity: number, activeEvent: string?, eventChance: number, roll: number, zone: string?, zoneChance: number?, zoneRoll: number?)
	local normal, event, zonal = {}, {}, {}
	for _, p in Pets.ByRarity[rarity] or {} do
		if p.Night then
			continue -- ночные слаймы выбираются отдельно (SpawnService)
		elseif p.Zone ~= nil then
			if p.Zone == zone then
				table.insert(zonal, p)
			end
		elseif p.Event == nil then
			table.insert(normal, p)
		elseif p.Event == activeEvent then
			table.insert(event, p)
		end
	end
	if #zonal > 0 and ((zoneRoll or 1) < (zoneChance or 0) or (#normal == 0 and #event == 0)) then
		return zonal
	end
	if #event > 0 and (roll < eventChance or #normal == 0) then
		return event
	end
	return normal
end

return Pets
