--!strict
-- LeaveLinesController: feeds UI/LeaveLines (issue 726, switch leaveLines). While Roblox's menu is open
-- (GuiService.MenuIsOpen: the escape menu and its "leave the game?" screen) it shows LeaveLineRules' two lines, each
-- built from what is true for this player right now: a helper hired and the tip jar on, and the check in card's
-- days. Client only; it asks the server nothing.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CheckinRules = require(Shared:WaitForChild("CheckinRules"))
local JarRules = require(Shared:WaitForChild("JarRules"))
local LeaveLineRules = require(Shared:WaitForChild("LeaveLineRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local LeaveLinesController = {}

local player = Players.LocalPlayer

local function number(raw: unknown): number?
	return if type(raw) == "number" and raw == raw then raw else nil
end

local function refresh()
	local helpers = false
	for _, id in WorkerRules.IDS do
		helpers = helpers or player:GetAttribute(`WorkerLevel_{id}`) ~= nil
	end
	local state: LeaveLineRules.State = {
		helpers = helpers,
		jar = LiveFlags.isOn(JarRules.FLAG) and LiveFlags.isOn(WorkerRules.FLAG),
		checkin = LiveFlags.isOn(CheckinRules.FLAG),
		ready = number(player:GetAttribute(CheckinRules.READY_ATTRIBUTE)),
		days = number(player:GetAttribute(CheckinRules.DAYS_ATTRIBUTE)) or 0,
	}
	UI.setLeaveLines(LeaveLineRules.top(state), LeaveLineRules.bottom(state))
	UI.showLeaveLines(LiveFlags.isOn(LeaveLineRules.FLAG) and GuiService.MenuIsOpen)
end

function LeaveLinesController.Init(_controllers: { [string]: any }) end

function LeaveLinesController.Start()
	GuiService.MenuOpened:Connect(refresh)
	GuiService.MenuClosed:Connect(refresh)
	for _, id in WorkerRules.IDS do
		player:GetAttributeChangedSignal(`WorkerLevel_{id}`):Connect(refresh)
	end
	player:GetAttributeChangedSignal(CheckinRules.READY_ATTRIBUTE):Connect(refresh)
	player:GetAttributeChangedSignal(CheckinRules.DAYS_ATTRIBUTE):Connect(refresh)
	for _, flag in { LeaveLineRules.FLAG, JarRules.FLAG, WorkerRules.FLAG, CheckinRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(refresh)
	end
	refresh()
end

return LeaveLinesController
