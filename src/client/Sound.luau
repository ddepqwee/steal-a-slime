--!nonstrict
-- 🔊 Звуки и музыка. SFX — свои (audio/*.ogg → AudioIds), музыка — лицензированная библиотека Roblox (APM).
-- Музыка сама меняется: день / ночь / битва (босс, рейд) / погоня (Runaway) / праздник (дождь, охота).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Ids = require(ReplicatedStorage.Shared.AudioIds)

local Sound = {}
Sound.MusicOn = true
Sound.SfxOn = true

local VOLUME = {
	Click = 0.35,
	Buy = 0.5,
	Pop = 0.55,
	Steal = 0.28,
	Bonk = 0.6,
	Legendary = 0.55,
	Reward = 0.5,
	Whoosh = 0.3,
	Error = 0.32,
	Rebirth = 0.6,
}

local MUSIC_VOLUME = 0.28
local PLAYLISTS = {
	Day = { "rbxassetid://1836057733", "rbxassetid://1845756489", "rbxassetid://1841647093" }, -- Leisure Simulation Game, Town Talk, Life in an Elevator
	Night = { "rbxassetid://1838457617", "rbxassetid://1837849285" }, -- Clair De Lune, Night Vision
	Battle = { "rbxassetid://1843497734" }, -- Chaos
	Chase = { "rbxassetid://1839246711" }, -- Jumpstyle
	Party = { "rbxassetid://1846368080" }, -- Stadium Rave
}
local EVENT_MOOD = { Boss = "Battle", Raid = "Battle", Runaway = "Chase", Rain = "Party", Hunt = "Party" }

local group = Instance.new("SoundGroup")
group.Name = "SFX"
group.Parent = SoundService
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Music"
musicGroup.Parent = SoundService

local pool = {} :: { [string]: { Sound } }

function Sound.Play(name: string, pitch: number?)
	if not Sound.SfxOn or not name or name == "" then
		return
	end
	local id = Ids[name]
	if not id then
		return
	end
	pool[name] = pool[name] or {}
	local s
	for _, x in pool[name] do
		if not x.IsPlaying then
			s = x
			break
		end
	end
	if not s then
		if #pool[name] >= 4 then
			s = pool[name][1]
		else
			s = Instance.new("Sound")
			s.SoundId = id
			s.Volume = VOLUME[name] or 0.5
			s.SoundGroup = group
			s.Parent = SoundService
			table.insert(pool[name], s)
		end
	end
	s.PlaybackSpeed = pitch or 1
	s.TimePosition = 0
	s:Play()
end

-- ===== Музыка =====
local current: Sound? = nil
local currentMood = ""
local index = {}

local function nextTrack(mood: string): string
	local list = PLAYLISTS[mood]
	index[mood] = ((index[mood] or math.random(1, #list)) % #list) + 1
	return list[index[mood]]
end

local function startTrack(mood: string)
	local old = current
	local s = Instance.new("Sound")
	s.SoundId = nextTrack(mood)
	s.Volume = 0
	s.Looped = #PLAYLISTS[mood] == 1
	s.SoundGroup = musicGroup
	s.Parent = SoundService
	s:Play()
	current = s
	currentMood = mood
	TweenService:Create(s, TweenInfo.new(2), { Volume = if Sound.MusicOn then MUSIC_VOLUME else 0 }):Play()
	s.Ended:Connect(function()
		if current == s then
			startTrack(currentMood)
		end
	end)
	if old then
		local tw = TweenService:Create(old, TweenInfo.new(1.5), { Volume = 0 })
		tw:Play()
		tw.Completed:Once(function()
			old:Destroy()
		end)
	end
end

local function desiredMood(): string
	local ev = ReplicatedStorage:GetAttribute("WorldEvent") or ""
	if EVENT_MOOD[ev] then
		return EVENT_MOOD[ev]
	end
	return if ReplicatedStorage:GetAttribute("Night") == true then "Night" else "Day"
end

function Sound.SetMusic(on: boolean)
	Sound.MusicOn = on
	if current then
		TweenService:Create(current, TweenInfo.new(0.6), { Volume = if on then MUSIC_VOLUME else 0 }):Play()
	end
end

function Sound.SetSfx(on: boolean)
	Sound.SfxOn = on
end

function Sound.Start()
	task.spawn(function()
		task.wait(2)
		while true do
			local mood = desiredMood()
			if mood ~= currentMood then
				startTrack(mood)
			end
			task.wait(1)
		end
	end)
end

return Sound
