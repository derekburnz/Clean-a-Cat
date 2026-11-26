--!strict
-- BuildWindowController: the Build window (UI/BuildWindow, issue 751), behind the switch buildWindow. It keeps the
-- server's build state from the Builds remote (the same one the Builds board reads: the running builds, the built
-- ids, the server's time) and the Player attributes for tools (Tool_<id>) and the bow in use (BowTier), draws the rows
-- (BuildViewRules) and asks the server on a press: RequestBuild(id), RequestBuyTool(id) or RequestBuyBow(tier). The
-- server checks coins, order and slots and says why when it refuses (with buildWindow on it does not ask the player to
-- stand by the board). While the window shows, a running build's countdown redraws each second.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BowRules = require(Shared:WaitForChild("BowRules"))
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local BuildViewRules = require(Shared:WaitForChild("BuildViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Passes = require(Shared:WaitForChild("Passes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ToolRules = require(Shared:WaitForChild("ToolRules"))
local Wallet = require(Shared:WaitForChild("Wallet"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local BuildWindowController = {}

local player = Players.LocalPlayer
local builds: { [string]: BuildRules.Build } = {}
local built: { [string]: boolean } = {}
local clockOffset = 0
local ticking = false

local function owns(id: string): boolean
	return player:GetAttribute(ToolRules.ATTRIBUTE_PREFIX .. id) == true
end

local function draw()
	local builders = if player:GetAttribute(Passes.ATTRIBUTE_PREFIX .. "SecondBuilder") == true
		then 2
		else 1
	local bowTier = player:GetAttribute(BowRules.ATTRIBUTE)
	local rawCoins = player:GetAttribute(Wallet.ATTRIBUTE)
	local coins = if type(rawCoins) == "number" then rawCoins else 0
	UI.setBuild(
		BuildViewRules.markShort(
			BuildViewRules.builds(builds, built, os.time() + clockOffset, LiveFlags.isOn, builders),
			coins
		),
		BuildViewRules.markShort(
			BuildViewRules.upgrades(
				LiveFlags.isOn,
				owns,
				if type(bowTier) == "string" then bowTier else nil
			),
			coins
		)
	)
end

local function anyRunning(): boolean
	return next(builds) ~= nil
end

-- While the window shows and a build runs, redraw each second for its countdown.
local function tick()
	if ticking then
		return
	end
	ticking = true
	task.spawn(function()
		while UI.isOpen(BuildViewRules.WINDOW) and anyRunning() do
			draw()
			task.wait(1)
		end
		ticking = false
	end)
end

local function onBuilds(rawBuilds: unknown, rawBuilt: unknown, rawNow: unknown)
	builds = BuildRules.cleanBuilds(rawBuilds)
	table.clear(built)
	if type(rawBuilt) == "table" then
		for _, id in rawBuilt :: { unknown } do
			if type(id) == "string" and BuildRules.ITEMS[id] then
				built[id] = true
			end
		end
	end
	if type(rawNow) == "number" and rawNow == rawNow then
		clockOffset = rawNow - os.time()
	end
	draw()
	tick()
end

function BuildWindowController.Init(_controllers: { [string]: any }) end

function BuildWindowController.Start()
	Remotes.event("Builds").OnClientEvent:Connect(onBuilds)
	UI.onBuildPress(function(kind: string, id: string)
		if not LiveFlags.isOn(BuildViewRules.FLAG) then
			return
		end
		if kind == "build" then
			Remotes.event("RequestBuild"):FireServer(id)
		elseif kind == "tool" then
			Remotes.event("RequestBuyTool"):FireServer(id)
		elseif kind == "bow" then
			Remotes.event("RequestBuyBow"):FireServer(id)
		end
	end)
	UI.onOpened(function(name: string)
		if name == BuildViewRules.WINDOW then
			draw()
			tick()
		end
	end)
	-- coins too, so a row turns green the moment the player can afford it (#825)
	local names =
		{ BowRules.ATTRIBUTE, Passes.ATTRIBUTE_PREFIX .. "SecondBuilder", Wallet.ATTRIBUTE }
	for _, id in ToolRules.IDS do
		table.insert(names, ToolRules.ATTRIBUTE_PREFIX .. id)
	end
	for _, name in names do
		player:GetAttributeChangedSignal(name):Connect(draw)
	end
	local flags = { BuildViewRules.FLAG, BowRules.FLAG, "toolsBoard", "builds" }
	for _, flag in BuildRules.itemFlags() do
		table.insert(flags, flag)
	end
	for _, flag in flags do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(draw)
	end
	draw()
end

return BuildWindowController
