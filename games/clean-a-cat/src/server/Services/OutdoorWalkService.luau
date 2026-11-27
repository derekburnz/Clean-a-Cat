--!strict
-- OutdoorWalkService: marks each player whose first session's tutorial has ended (OutdoorWalkRules.ATTRIBUTE, from
-- their play time), so the client walks faster outside the spa (switch outdoorWalk, issue 886). Reads only; nothing
-- is saved: play time already is.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local OutdoorWalkRules = require(Shared:WaitForChild("OutdoorWalkRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local CHECK_SECONDS = 5

local OutdoorWalkService = {}

local function check(player: Player)
	if not LiveFlags.isOn(OutdoorWalkRules.FLAG) then
		if player:GetAttribute(OutdoorWalkRules.ATTRIBUTE) ~= nil then
			player:SetAttribute(OutdoorWalkRules.ATTRIBUTE, nil)
		end
		return
	end
	if player:GetAttribute(OutdoorWalkRules.ATTRIBUTE) == true then
		return
	end
	local save = DataService.get(player)
	if save == nil then
		return
	end
	if OutdoorWalkRules.tutorialDone(Telemetry.played(player) or save.playSeconds) then
		player:SetAttribute(OutdoorWalkRules.ATTRIBUTE, true)
	end
end

function OutdoorWalkService.Init(_services: { [string]: any }) end

function OutdoorWalkService.Start()
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				check(player)
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return OutdoorWalkService
