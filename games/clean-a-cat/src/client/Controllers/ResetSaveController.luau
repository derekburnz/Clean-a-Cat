--!strict
-- ResetSaveController: Settings' "Reset my game" (issue 1037, switch resetSave; shared/ResetRules says who may). It
-- shows the button only while the server sets the Player attribute CanResetSave, and sends RequestResetSave() with no
-- arguments after the button's second tap. The server checks again, resets the save and kicks to rejoin.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ResetRules = require(Shared:WaitForChild("ResetRules"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local ResetSaveController = {}

local player = Players.LocalPlayer

local function allowed(): boolean
	return player:GetAttribute(ResetRules.ATTRIBUTE) == true
end

function ResetSaveController.Init(_controllers: { [string]: any }) end

function ResetSaveController.Start()
	UI.onResetSave(function()
		if allowed() then
			Remotes.event(ResetRules.REMOTE):FireServer()
		end
	end)
	player:GetAttributeChangedSignal(ResetRules.ATTRIBUTE):Connect(function()
		UI.setCanReset(allowed())
	end)
	UI.setCanReset(allowed())
end

return ResetSaveController
