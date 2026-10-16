--!strict
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trimZeros(s: string): string
	if string.find(s, "%.") then
		s = (string.gsub(s, "0+$", ""))
		s = (string.gsub(s, "%.$", ""))
	end
	return s
end

function Format.short(n: number): string
	if n ~= n or n == math.huge then
		return "∞"
	end
	local neg = n < 0
	n = math.abs(n)
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local s: string
	if i == 1 then
		s = tostring(math.floor(n))
	elseif n >= 100 then
		s = tostring(math.floor(n))
	elseif n >= 10 then
		s = trimZeros(string.format("%.1f", math.floor(n * 10) / 10))
	else
		s = trimZeros(string.format("%.2f", math.floor(n * 100) / 100))
	end
	return (if neg then "-" else "") .. s .. SUFFIXES[i]
end

function Format.money(n: number): string
	return "$" .. Format.short(n)
end

function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 86400 then
		local d = seconds // 86400
		return string.format("%dd %dh", d, (seconds % 86400) // 3600)
	end
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

return Format
