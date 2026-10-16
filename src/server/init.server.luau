--!nonstrict
-- Точка входа сервера: подключает все сервисы движка в нужном порядке.
local Services = script:WaitForChild("Services")

local ORDER = {
	"MapBuilder",
	"DataService",
	"MonetizationService",
	"LiveOpsService",
	"EventService",
	"EconomyService",
	"PlotService",
	"PetFactory",
	"SpawnService",
	"StealService",
	"ProgressionService",
	"SocialService",
	"IndexService",
	"AchievementService",
	"QuestService",
	"GearService",
	"WorldEventService",
	"RewardService",
	"ZoneService",
	"BuddyService",
	"TutorialService",
	"LeaderboardService",
	"ShowcaseService",
	"DirectorService",
}

local S = {}
for _, name in ORDER do
	S[name] = require(Services:WaitForChild(name))
end
for _, name in ORDER do
	if S[name].Init then
		S[name]:Init(S)
	end
end
for _, name in ORDER do
	if S[name].Start then
		task.spawn(function()
			S[name]:Start()
		end)
	end
end

print(("[Engine] %d services started"):format(#ORDER))
