--!strict
-- JarController: the prompt on the player's own tip jar (JarRules, issue 517). It shows "Collect tips, 90 coins"
-- while the server's Player attribute JarCoins says coins are waiting; a tap asks the server (RequestCollectJar),
-- which checks and pays. Nothing opens by itself. Behind the LiveFlags switch tipJar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local JarRules = require(Shared:WaitForChild("JarRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local ANCHOR_NAME = "CleanACat_TipJarPrompt"
local ANCHOR_HEIGHT = 1 -- studs over the jar's spot

local JarController = {}

local anchor: BasePart? = nil
local prompt: ProximityPrompt? = nil

local function refresh()
	local on = LiveFlags.isOn(JarRules.FLAG)
	if on and anchor == nil then
		local part = Instance.new("Part")
		part.Name = ANCHOR_NAME
		part.Size = Vector3.new(1, 1, 1)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CFrame = SpaLayout.spot("SpotTipJar") * CFrame.new(0, ANCHOR_HEIGHT, 0)
		local made = Instance.new("ProximityPrompt")
		made.ActionText = "Collect tips"
		made.HoldDuration = 0
		made.MaxActivationDistance = JarRules.PROMPT_REACH
		made.RequiresLineOfSight = false
		made.Enabled = false
		made.Parent = part
		made.Triggered:Connect(function()
			Remotes.event("RequestCollectJar"):FireServer()
		end)
		part.Parent = Workspace
		anchor = part
		prompt = made
	elseif not on and anchor then
		(anchor :: BasePart):Destroy()
		anchor = nil
		prompt = nil
	end
	local current = prompt
	if current then
		local coins = Players.LocalPlayer:GetAttribute(JarRules.ATTRIBUTE)
		current.Enabled = type(coins) == "number" and coins > 0
		current.ObjectText = if type(coins) == "number" then `{coins} coins` else ""
	end
end

function JarController.Init(_controllers: { [string]: any }) end

function JarController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. JarRules.FLAG)
		:Connect(refresh)
	Players.LocalPlayer:GetAttributeChangedSignal(JarRules.ATTRIBUTE):Connect(refresh)
	-- the plot placed or taken away: the prompt moves with the jar
	SpaLayout.changed(function()
		local part = anchor
		if part then
			part.CFrame = SpaLayout.spot("SpotTipJar") * CFrame.new(0, ANCHOR_HEIGHT, 0)
		end
	end)
	refresh()
end

return JarController
