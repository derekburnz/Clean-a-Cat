--!strict
-- FeedbackController: Settings' "Send feedback" (issue 1081, switch feedback; shared/FeedbackRules). It shows the
-- button while the switch is on, with the player's sends this visit (the Player attribute FeedbackSent, set by the
-- server), and sends SendFeedback(choice, note?) when the Feedback card's Send is pressed. The server checks the
-- choice, trims and filters the note, keeps the limits and shows the thank you.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeedbackRules = require(Shared:WaitForChild("FeedbackRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local FeedbackController = {}

local player = Players.LocalPlayer

local function sent(): number
	local raw = player:GetAttribute(FeedbackRules.SENT_ATTRIBUTE)
	return if type(raw) == "number" and raw == raw and raw >= 0 then math.floor(raw) else 0
end

local function refresh()
	UI.setFeedback(LiveFlags.isOn(FeedbackRules.FLAG), sent(), FeedbackRules.PER_VISIT)
end

function FeedbackController.Init(_controllers: { [string]: any }) end

function FeedbackController.Start()
	UI.onFeedbackSend(function(choice: string, note: string)
		if not LiveFlags.isOn(FeedbackRules.FLAG) or sent() >= FeedbackRules.PER_VISIT then
			return
		end
		Remotes.event(FeedbackRules.REMOTE):FireServer(choice, FeedbackRules.cleanNote(note))
	end)
	player:GetAttributeChangedSignal(FeedbackRules.SENT_ATTRIBUTE):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FeedbackRules.FLAG)
		:Connect(refresh)
	refresh()
end

return FeedbackController
