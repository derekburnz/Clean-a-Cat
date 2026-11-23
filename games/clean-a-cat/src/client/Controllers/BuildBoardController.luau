--!strict
-- BuildBoardController: the builder board beside the Tools board, as a placeholder part with one prompt per
-- build. The player walks up and taps a prompt; BuildService checks and starts the build. A running build's
-- prompt shows its countdown, and a built one's prompt goes away. Nothing opens by itself.
-- Behind the LiveFlags switch `builds`.
--
--   BuildBoardController.finished:Connect(fn)  fn(id) when a build finishes (also one that finished while away),
--                                              for the celebration effects and the builder panel
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildRules = require(Shared:WaitForChild("BuildRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))

local FLAG = "builds"
local BOARD_SIZE = Vector3.new(4, 5, 0.4)

local BuildBoardController = {}

BuildBoardController.finished = Signal.new() :: Signal.Signal<string>

local board: Part? = nil
local prompts: { [string]: ProximityPrompt } = {}
local connections: { RBXScriptConnection } = {}
local ticker: thread? = nil
local builds: { [string]: BuildRules.Build } = {}
local built: { [string]: boolean } = {}
local clockOffset = 0 -- server os.time() minus local os.time(), so countdowns use the server's clock

local function countdown(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	return if h > 0
		then string.format("%d:%02d:%02d", h, m, s % 60)
		else string.format("%d:%02d", m, s % 60)
end

local function refreshPrompts()
	local now = os.time() + clockOffset
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
	local part = Instance.new("Part")
	part.Name = "PH_BuildBoard"
	part.Size = BOARD_SIZE
	part.Color = Color3.fromRGB(120, 150, 190)
	part.Anchored = true
	part.CFrame = CFrame.new(BuildRules.BOARD_POSITION + Vector3.new(0, BOARD_SIZE.Y / 2, 0))
	for index, id in BuildRules.IDS do
		local spot = Instance.new("Attachment")
		spot.Name = id
		spot.Position = Vector3.new(0, BOARD_SIZE.Y / 2 - index, BOARD_SIZE.Z / 2)
		spot.Parent = part
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
	refreshPrompts()
	part.Parent = Workspace
	board = part
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
	if board then
		board:Destroy()
		board = nil
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
	refresh()
end

return BuildBoardController
