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
}

Pets.ById = {}
Pets.ByRarity = {}
for _, p in Pets.List do
	Pets.ById[p.Id] = p
	Pets.ByRarity[p.Rarity] = Pets.ByRarity[p.Rarity] or {}
	table.insert(Pets.ByRarity[p.Rarity], p)
end

return Pets
