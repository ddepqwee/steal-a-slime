--!nonstrict
-- 🌙 День и ночь. Цикл считается от серверного времени, поэтому на всех серверах одинаковый.
-- Ночью: ночные Moon-слаймы на дорогах, удача x1.5, неон и подсветка баз светятся ярче.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local DayNightService = {}
local night = false

-- Дневные и ночные значения освещения
local DAY = {
	Ambient = Color3.fromRGB(60, 55, 80),
	Outdoor = Color3.fromRGB(110, 105, 140),
	Exposure = -0.35,
	AtmColor = Color3.fromRGB(200, 215, 255),
	AtmDecay = Color3.fromRGB(255, 160, 220),
	Tint = Color3.fromRGB(255, 248, 255),
	Bloom = 0.35,
}
local NIGHT = {
	Ambient = Color3.fromRGB(70, 62, 120),
	Outdoor = Color3.fromRGB(105, 100, 175),
	Exposure = 0.15,
	AtmColor = Color3.fromRGB(90, 95, 170),
	AtmDecay = Color3.fromRGB(70, 40, 130),
	Tint = Color3.fromRGB(215, 215, 255),
	Bloom = 0.9,
}

function DayNightService:Init(S)
	self.S = S
end

-- isNight, секунд до смены фазы, прогресс фазы 0..1
function DayNightService:Phase(): (boolean, number, number)
	local cfg = Config.DayNight
	local t = Workspace:GetServerTimeNow() % (cfg.Day + cfg.Night)
	if t < cfg.Day then
		return false, cfg.Day - t, t / cfg.Day
	end
	return true, cfg.Day + cfg.Night - t, (t - cfg.Day) / cfg.Night
end

function DayNightService:IsNight(): boolean
	return night
end

function DayNightService:LuckMult(): number
	return if night then Config.DayNight.LuckMult else 1
end

local function darkness(clock: number): number
	-- 0 = день, 1 = ночь; плавные сумерки и рассвет
	if clock >= 6.5 and clock <= 17.4 then
		return 0
	elseif clock > 17.4 and clock < 19 then
		return (clock - 17.4) / 1.6
	elseif clock >= 5 and clock < 6.5 then
		return 1 - (clock - 5) / 1.5
	end
	return 1
end

function DayNightService:_apply()
	local isNight, _, prog = self:Phase()
	local clock
	if isNight then
		clock = (17.6 + prog * (24 + 6.6 - 17.6)) % 24
	else
		clock = 6.6 + prog * (17.6 - 6.6)
	end
	Lighting.ClockTime = clock
	local k = darkness(clock)
	Lighting.Ambient = DAY.Ambient:Lerp(NIGHT.Ambient, k)
	Lighting.OutdoorAmbient = DAY.Outdoor:Lerp(NIGHT.Outdoor, k)
	Lighting.ExposureCompensation = DAY.Exposure + (NIGHT.Exposure - DAY.Exposure) * k
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		atm.Color = DAY.AtmColor:Lerp(NIGHT.AtmColor, k)
		atm.Decay = DAY.AtmDecay:Lerp(NIGHT.AtmDecay, k)
	end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		cc.TintColor = DAY.Tint:Lerp(NIGHT.Tint, k)
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Intensity = DAY.Bloom + (NIGHT.Bloom - DAY.Bloom) * k
	end

	if isNight ~= night then
		local first = ReplicatedStorage:GetAttribute("Night") == nil
		night = isNight
		if not first then
			if night then
				self.S.SocialService:NotifyAll("🌙 Night has fallen! Moon slimes are on the roads · x" .. Config.DayNight.LuckMult .. " luck!", Color3.fromRGB(170, 180, 255), "Legendary")
			else
				self.S.SocialService:NotifyAll("☀️ Good morning! The Moon slimes went to sleep.", Color3.fromRGB(255, 230, 120))
			end
		end
	end
	ReplicatedStorage:SetAttribute("Night", night)
	ReplicatedStorage:SetAttribute("PhaseEnds", os.time() + math.floor(select(2, self:Phase())))
end

function DayNightService:Start()
	-- в режимах съёмки шортсов время суток фиксированное
	if RunService:IsStudio() and (Workspace:GetAttribute("Showcase") == true or Workspace:GetAttribute("Director") == true) then
		return
	end
	task.wait(1) -- после того как MapBuilder настроил Lighting
	while true do
		self:_apply()
		task.wait(0.5)
	end
end

return DayNightService
