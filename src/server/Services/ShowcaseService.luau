--!nonstrict
-- Режим витрины для съёмки иконок/превью/шортсов.
-- Работает ТОЛЬКО в Studio и только если у Workspace стоит атрибут Showcase = true
-- (собирается отдельным проектом showcase.project.json). В живой игре не активен.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pets = require(ReplicatedStorage.Shared.Pets)

local ShowcaseService = {}

function ShowcaseService:Enabled(): boolean
	return RunService:IsStudio() and Workspace:GetAttribute("Showcase") == true
end

function ShowcaseService:Init(S)
	self.S = S
end

function ShowcaseService:Start()
	if not self:Enabled() then
		return
	end
	warn("[Showcase] showcase mode on")
	local top = {}
	for i = #Pets.List, 1, -1 do
		table.insert(top, Pets.List[i])
	end
	local variants = { nil, "Rainbow", nil, "Gold", nil, nil, "Gold", nil, "Rainbow", nil, nil, nil, nil, nil }
	self.S.DataService:OnLoaded(function(player, data)
		task.wait(1)
		data.Cash = 48_700_000_000
		data.Rebirths = 7
		data.Pets = {}
		local director = Workspace:GetAttribute("Director") == true
		for i = 1, 14 do
			-- в режиме режиссёра центральный слот (4) оставляем пустым под «героя» ролика
			if not (director and i == 4) then
				local def = top[((i + 1) % #top) + 1]
				data.Pets[tostring(i)] = { Id = def.Id, V = variants[i] }
			end
		end
		self.S.EconomyService:Refresh(player)
		self.S.PlotService:RenderAll(player)
	end)
end

return ShowcaseService
