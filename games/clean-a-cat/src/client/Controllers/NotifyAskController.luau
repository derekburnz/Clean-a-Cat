--!strict
-- NotifyAskController: Suds's one notification ask (NotifyAskRules, issue 814, switch notifyAsk). When the server says
-- it is due (NotifyAskDue) and Roblox would show this player the opt-in prompt (CanPromptOptInAsync: never under 13 or
-- once opted in), it waits its turn in the ask queue (id "notify", so never in a wash or a recap and a minute from any
-- other ask) and shows Design's bubble. Only a tap on Sure! calls PromptOptIn; the X just closes. Either way the
-- server saves it as shown, so it never comes back.
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AskRules = require(Shared:WaitForChild("AskRules"))
local BubbleRules = require(Shared:WaitForChild("BubbleRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local NotifyAskRules = require(Shared:WaitForChild("NotifyAskRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Client = script.Parent.Parent
local UI = require(Client:WaitForChild("UI"))

local ID = NotifyAskRules.ASK_ID

local NotifyAskController = {}

local player = Players.LocalPlayer
local ask: any = nil -- AskController
local canPrompt: boolean? = nil -- nil until Roblox answered
local asking = false
local wanted = false
local shown = false -- this session: the bubble went up

local function on(): boolean
	return LiveFlags.isOn(NotifyAskRules.FLAG) and LiveFlags.isOn(BubbleRules.FLAG) and ask.on()
end

local function show()
	if shown or player:GetAttribute(NotifyAskRules.ATTRIBUTE) ~= true or not on() then
		ask.skip(ID)
		wanted = false
		return
	end
	shown = true
	Remotes.event("RequestNotifyAskSeen"):FireServer()
	local pressed = false
	UI.showBubble(NotifyAskRules.BUBBLE, function()
		pressed = true
		-- only this tap opens Roblox's prompt
		if pcall(function()
			ExperienceNotificationService:PromptOptIn()
		end) then
			Remotes.event("ReportOptIn"):FireServer("shown")
		end
	end, function(closed: boolean)
		wanted = false
		local answer: AskRules.Answer = if pressed then "yes" elseif closed then "no" else "closed"
		ask.done(ID, answer)
	end)
end

local function sync()
	local due = player:GetAttribute(NotifyAskRules.ATTRIBUTE) == true and on() and not shown
	if not due then
		if wanted then
			wanted = false
			ask.drop(ID)
		end
		return
	end
	if canPrompt == nil then
		if not asking then
			asking = true
			task.spawn(function()
				local ok, result = pcall(function()
					return ExperienceNotificationService:CanPromptOptInAsync()
				end)
				canPrompt = ok and result == true
				asking = false
				sync()
			end)
		end
		return
	end
	if canPrompt and not wanted then
		wanted = ask.want(ID, show, UI.hideBubble)
	end
end

function NotifyAskController.Init(controllers: { [string]: any })
	ask = controllers.AskController
end

function NotifyAskController.Start()
	player:GetAttributeChangedSignal(NotifyAskRules.ATTRIBUTE):Connect(sync)
	for _, flag in { NotifyAskRules.FLAG, BubbleRules.FLAG, AskRules.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(sync)
	end
	sync()
end

return NotifyAskController
