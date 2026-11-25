--!strict
-- BuildBoardController: the builder board beside the Tools board, Model-Agent's board (Spa/BoardProp; the plain slab
-- when the model is missing) with one prompt per build on its rows. The player walks up and taps a prompt; BuildService checks and starts the build. A running build's
-- prompt shows its countdown, and a built one's prompt goes away. Nothing opens by itself.
-- Behind the LiveFlags switch `builds`.
-- With `longBuildOffer` on as well, a running build of an hour or more gets a bell prompt, "Tell me when it's
-- done": only a tap on it asks Roblox for the notification opt-in prompt (#38). A player Roblox would not ask sees
-- "Ready in 8 h. Come back to see it!" on the board instead. What happened goes to the server as ReportOptIn.
--
--   BuildBoardController.finished:Connect(fn)  fn(id) when a build finishes (also one that finished while away),
--                                              for the celebration effects and the builder panel
local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BoardProp = require(script.Parent.Parent:WaitForChild("Spa"):WaitForChild("BoardProp"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local NotifyRules = require(Shared:WaitForChild("NotifyRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local FLAG = "builds"
local BELL_FLAG = "longBuildOffer"
local SPEC: BoardProp.Spec = {
	asset = "CleanACat_Prop_BuildBoard",
	title = "Builds",
	placeholder = "PH_BuildBoard",
	size = Vector3.new(4, 5, 0.4),
	color = Color3.fromRGB(120, 150, 190),
}

local BuildBoardController = {}

BuildBoardController.finished = Signal.new() :: Signal.Signal<string>

local board: BoardProp.Board? = nil
local prompts: { [string]: ProximityPrompt } = {}
local connections: { RBXScriptConnection } = {}
local ticker: thread? = nil
local builds: { [string]: BuildRules.Build } = {}
local built: { [string]: boolean } = {}
local clockOffset = 0 -- server os.time() minus local os.time(), so countdowns use the server's clock
local bell: ProximityPrompt? = nil
local comeBack: BillboardGui? = nil
local canOptIn: boolean? = nil -- Roblox would show the opt-in prompt; checked once, before any ask
local askedFor: { [number]: boolean } = {} -- builds (by end time) the bell was tapped for: it never asks twice
local toldCannot = false -- cannot_prompt reported this session

local function countdown(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	return if h > 0
		then string.format("%d:%02d:%02d", h, m, s % 60)
		else string.format("%d:%02d", m, s % 60)
end

-- The running long build that finishes last, or nil.
local function longRunning(now: number): BuildRules.Build?
	local found: BuildRules.Build? = nil
	for _, build in builds do
		local current = found
		if
			NotifyRules.isLong(build.item)
			and build.endsAt > now
			and (current == nil or build.endsAt > current.endsAt)
		then
			found = build
		end
	end
	return found
end

local function refreshBell(now: number)
	local prompt = bell
	local label = comeBack
	if prompt == nil or label == nil then
		return
	end
	local long = if LiveFlags.isOn(BELL_FLAG) then longRunning(now) else nil
	prompt.Enabled = long ~= nil and canOptIn == true and not askedFor[long.endsAt]
	label.Enabled = long ~= nil and canOptIn == false
	if long and canOptIn == false then
		local text = label:FindFirstChildOfClass("TextLabel")
		if text then
			(text :: TextLabel).Text = NotifyRules.comeBackText(long.endsAt - now)
		end
		if not toldCannot then
			toldCannot = true
			Remotes.event("ReportOptIn"):FireServer("cannot_prompt")
		end
	end
end

local function refreshPrompts()
	local now = os.time() + clockOffset
	refreshBell(now)
	for id, prompt in prompts do
		local item = BuildRules.ITEMS[id]
		local running: BuildRules.Build? = builds[item.slot]
		if built[id] then
			prompt.Enabled = false
		elseif running and running.item == id then
			prompt.Enabled = true
			prompt.ActionText = `Building {item.name}`
			prompt.ObjectText = countdown(running.endsAt - now)
		else
			prompt.Enabled = true
			prompt.ActionText = `Build {item.name}`
			prompt.ObjectText = `{item.price} coins, {countdown(item.seconds)}`
		end
	end
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
	refreshPrompts()
end

local function enable()
	if board then
		return
	end
	local offered = BuildRules.offered(LiveFlags.isOn)
	local made = BoardProp.make(SPEC, SpaLayout.spot("SpotBuilder"), #offered)
	for index, id in offered do
		local spot = made.rows[index]
		local prompt = Instance.new("ProximityPrompt")
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = BuildRules.PROMPT_REACH
		prompt.RequiresLineOfSight = false
		prompt.Parent = spot
		prompts[id] = prompt
		table.insert(
			connections,
			prompt.Triggered:Connect(function()
				Remotes.event("RequestBuild"):FireServer(id)
			end)
		)
	end
	-- The bell and the come back line, by the model's bell (at the slab's foot).
	local foot = made.bell
	local bellPrompt = Instance.new("ProximityPrompt")
	bellPrompt.ActionText = "Tell me when it's done"
	bellPrompt.HoldDuration = 0
	bellPrompt.MaxActivationDistance = BuildRules.PROMPT_REACH
	bellPrompt.RequiresLineOfSight = false
	bellPrompt.Enabled = false
	bellPrompt.Parent = foot
	bell = bellPrompt
	table.insert(
		connections,
		bellPrompt.Triggered:Connect(function()
			local long = longRunning(os.time() + clockOffset)
			if long == nil or askedFor[long.endsAt] then
				return
			end
			askedFor[long.endsAt] = true
			bellPrompt.Enabled = false
			-- Only this tap opens Roblox's prompt.
			if pcall(function()
				ExperienceNotificationService:PromptOptIn()
			end) then
				Remotes.event("ReportOptIn"):FireServer("shown")
			end
		end)
	)
	table.insert(
		connections,
		ExperienceNotificationService.OptInPromptClosed:Connect(function()
			Remotes.event("ReportOptIn"):FireServer("closed")
		end)
	)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ComeBack"
	gui.Size = UDim2.fromScale(5, 0.8) -- studs
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.MaxDistance = 40
	gui.Enabled = false
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0.4
	text.Parent = gui
	gui.Adornee = foot
	gui.Parent = made.root
	comeBack = gui
	if canOptIn == nil then
		task.spawn(function()
			local ok, result = pcall(function()
				return ExperienceNotificationService:CanPromptOptInAsync()
			end)
			canOptIn = ok and result == true
		end)
	end
	refreshPrompts()
	made.root.Parent = Workspace
	board = made
	table.insert(connections, Remotes.event("Builds").OnClientEvent:Connect(onBuilds))
	table.insert(
		connections,
		Remotes.event("BuildFinished").OnClientEvent:Connect(function(rawId: unknown)
			if type(rawId) == "string" and BuildRules.ITEMS[rawId] then
				BuildBoardController.finished:Fire(rawId)
			end
		end)
	)
	-- The countdowns tick once a second.
	ticker = task.spawn(function()
		while true do
			task.wait(1)
			refreshPrompts()
		end
	end)
end

local function disable()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if ticker then
		task.cancel(ticker)
		ticker = nil
	end
	table.clear(prompts)
	bell = nil
	comeBack = nil
	local made = board
	board = nil
	if made then
		made.root:Destroy()
	end
end

local function refresh()
	if LiveFlags.isOn(FLAG) then
		enable()
	else
		disable()
	end
end

function BuildBoardController.Init(_controllers: { [string]: any }) end

function BuildBoardController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(refresh)
	-- An item's own switch (the Bubble Bath's, the Pawdicure's) changed: the board is drawn again with or without it.
	for _, id in BuildRules.IDS do
		local itemFlag = BuildRules.ITEMS[id].flag
		if itemFlag then
			ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. itemFlag)
				:Connect(function()
					disable()
					refresh()
				end)
		end
	end
	-- The plot placed or taken away: the board moves to its spot.
	SpaLayout.changed(function()
		local made = board
		if made then
			BoardProp.moveTo(made, SpaLayout.spot("SpotBuilder"))
		end
	end)
	refresh()
end

return BuildBoardController
