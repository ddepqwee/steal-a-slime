--!nonstrict
-- Режим съёмки для YouTube Shorts (только для админов из Config.Admins и в Studio).
-- F6 — спрятать весь интерфейс; F7 — переключить камеру:
--   Обычная → Облёт дороги → Слежка за самым редким слаймом → Вид сверху на базу → Кинематографичный пролёт.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Pets)

local player = Players.LocalPlayer
local ShortsCam = {}

local MODES = { "Normal", "RoadOrbit", "FollowRare", "BaseTop", "Flythrough" }

local function isAdmin(): boolean
	return RunService:IsStudio() or table.find(Config.Admins, player.UserId) ~= nil or table.find(Config.AdminNames, player.Name) ~= nil
end

local function rarest(): Model?
	local best, bestScore = nil, -1
	for _, m in CollectionService:GetTagged("Slime") do
		if m:IsA("Model") and m.PrimaryPart and m:IsDescendantOf(Workspace) then
			local def = Pets.ById[m:GetAttribute("PetId")]
			if def then
				local score = def.Rarity * 10 + (if m:GetAttribute("Variant") ~= "" then 5 else 0)
				if score > bestScore then
					best, bestScore = m, score
				end
			end
		end
	end
	return best
end

function ShortsCam.Start(HUD)
	if not isAdmin() then
		return
	end
	local camera = Workspace.CurrentCamera
	local mode = 1
	local hidden = false
	local t0 = os.clock()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F6 then
			hidden = not hidden
			HUD.SetVisible(not hidden)
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, not hidden)
		elseif input.KeyCode == Enum.KeyCode.F7 then
			mode = mode % #MODES + 1
			t0 = os.clock()
			camera.CameraType = if MODES[mode] == "Normal" then Enum.CameraType.Custom else Enum.CameraType.Scriptable
			camera.FieldOfView = if MODES[mode] == "Normal" then 70 else 60
		end
	end)

	RunService.RenderStepped:Connect(function()
		local m = MODES[mode]
		if m == "Normal" then
			return
		end
		local t = os.clock() - t0
		if m == "RoadOrbit" then
			local a = t * 0.15
			local pos = Vector3.new(math.cos(a) * 70, 35, math.sin(a) * 70)
			camera.CFrame = CFrame.lookAt(pos, Vector3.new(0, 3, 0))
		elseif m == "FollowRare" then
			local target = rarest()
			if target then
				local p = target:GetPivot().Position
				local a = t * 0.4
				camera.CFrame = CFrame.lookAt(p + Vector3.new(math.cos(a) * 12, 5, math.sin(a) * 12), p)
			end
		elseif m == "BaseTop" then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 45, 18), root.Position)
			end
		elseif m == "Flythrough" then
			local x = -150 + (t * 12) % 300
			camera.CFrame = CFrame.lookAt(Vector3.new(x, 9, 20), Vector3.new(x + 25, 3, 0))
		end
	end)

	print("[ShortsCam] F6 — hide UI, F7 — switch camera")
end

return ShortsCam
