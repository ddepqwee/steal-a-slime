--!nonstrict
local HUD = require(script:WaitForChild("HUD"))
local World = require(script:WaitForChild("World"))
local ShortsCam = require(script:WaitForChild("ShortsCam"))
local ShortsDirector = require(script:WaitForChild("ShortsDirector"))
local Tutorial = require(script:WaitForChild("Tutorial"))

HUD.Build()
task.spawn(World.Start)
ShortsCam.Start(HUD)
ShortsDirector.Start(HUD)
Tutorial.Start(HUD)
