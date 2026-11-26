--!strict
-- OrientationController: phones and tablets play in landscape only (issue 522; the owner's pick on the plan page).
-- While the switch landscapeLock is on, this device's PlayerGui turns with the device between the two landscape
-- sides and never to portrait; switched off, it goes back to what the place sets. Nothing else changes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local FLAG = "landscapeLock"

local OrientationController = {}

local function apply()
	local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") :: PlayerGui?
	if gui == nil then
		return
	end
	gui.ScreenOrientation = if LiveFlags.isOn(FLAG)
		then Enum.ScreenOrientation.LandscapeSensor
		else StarterGui.ScreenOrientation
end

function OrientationController.Init(_controllers: { [string]: any }) end

function OrientationController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(apply)
	Players.LocalPlayer.ChildAdded:Connect(function(child: Instance)
		if child:IsA("PlayerGui") then
			apply()
		end
	end)
	apply()
end

return OrientationController
