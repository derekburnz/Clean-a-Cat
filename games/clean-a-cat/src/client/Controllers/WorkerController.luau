--!strict
-- WorkerController: the prompts at the workers' stations on the player's own plot (WorkerRules, issue 509). Before a
-- worker is hired their pad (drawn by WorkerService) shows "Hire Jo, 150 coins"; once hired, one prompt changes what
-- they take next (a tap steps through the modes) and another takes them up a level. The server checks everything and
-- shows the result on the Player attributes WorkerMode_<id> and WorkerLevel_<id>; the prompts only follow them.
-- Lou comes with a game pass, so he has no hire prompt. Nothing opens by itself.
-- With `pets` on, a third prompt gives the worker the best pet from the player's pen (until Design's Pets window).
-- It also fires Moments.WorkerFinished(cat) when a worker's clean cat sits down in their tub, on any plot.
-- Behind the LiveFlags switch `workers`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(Shared:WaitForChild("Moments"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local StaffNameRules = require(Shared:WaitForChild("StaffNameRules"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local FOLDER_NAME = "CleanACat_WorkerPrompts"
local ANCHOR_HEIGHT = 2.5 -- studs over the floor, about the pad's screen

local WorkerController = {}

local folder: Folder? = nil
local anchors: { [string]: BasePart } = {}
local connections: { RBXScriptConnection } = {}
-- The player's pets as the server last sent them (Pets), and each station's refresh for when they change.
local pets: { CrateRules.Pet } = {}
local shows: { () -> () } = {}

-- The pen's best pet (the highest boost, then the newest), or nil.
local function bestInPen(): CrateRules.Pet?
	local best: CrateRules.Pet? = nil
	for _, pet in pets do
		if pet.slot == nil then
			local boost = CrateRules.boost(pet.kind, pet.star)
			if best == nil or boost >= CrateRules.boost(best.kind, best.star) then
				best = pet
			end
		end
	end
	return best
end

local function attribute(kind: string, id: string): unknown
	return Players.LocalPlayer:GetAttribute(`{kind}_{id}`)
end

-- The worker's name as the player renamed them (StaffNameService: already filtered by Roblox), or the default.
local function nameOf(id: string): string
	local renamed = if LiveFlags.isOn(StaffNameRules.FLAG) then attribute("StaffName", id) else nil
	return if type(renamed) == "string" and renamed ~= ""
		then renamed
		else WorkerRules.WORKERS[id].name
end

local function prompt(parent: Instance, key: Enum.KeyCode, pad: Enum.KeyCode): ProximityPrompt
	local made = Instance.new("ProximityPrompt")
	made.HoldDuration = 0
	made.MaxActivationDistance = WorkerRules.PROMPT_REACH
	made.RequiresLineOfSight = false
	made.KeyboardKeyCode = key
	made.GamepadKeyCode = pad
	made.Parent = parent
	return made
end

local function build(id: string)
	local info = WorkerRules.WORKERS[id]
	local anchor = Instance.new("Part")
	anchor.Name = id
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = SpaLayout.spot(info.spot) * CFrame.new(0, ANCHOR_HEIGHT, 0)
	anchors[id] = anchor
	local main = prompt(anchor, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	local level = prompt(anchor, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	local give = prompt(anchor, Enum.KeyCode.G, Enum.KeyCode.ButtonL1)
	local function show()
		local hired = attribute("WorkerLevel", id) ~= nil
		local best = if hired and LiveFlags.isOn(CrateRules.FLAG) then bestInPen() else nil
		give.Enabled = best ~= nil
		give.ActionText = "Give a pet"
		give.ObjectText = if best then `{best.kind} to {nameOf(id)}` else ""
		if not hired then
			main.Enabled = not info.pass
			main.ActionText = `Hire {info.name}`
			main.ObjectText = `{WorkerRules.priceOf(id, LiveFlags.isOn) or 0} coins`
			level.Enabled = false
			return
		end
		local mode = WorkerRules.cleanMode(attribute("WorkerMode", id)) or WorkerRules.DEFAULT_MODE
		main.Enabled = true
		main.ActionText = `Takes: {WorkerRules.MODE_NAMES[mode]}`
		main.ObjectText = `{nameOf(id)}, tap to change`
		local cost =
			WorkerRules.levelCost({ level = WorkerRules.cleanLevel(attribute("WorkerLevel", id)) })
		-- with hudTidy on, levels are bought in the Helpers window only (issue 738)
		level.Enabled = cost ~= nil and not LiveFlags.isOn(WorkerRules.HUD_TIDY_FLAG)
		level.ActionText = "Level up"
		level.ObjectText = if cost then `{nameOf(id)}, {cost} coins` else ""
	end
	show()
	table.insert(
		connections,
		main.Triggered:Connect(function()
			if attribute("WorkerLevel", id) == nil then
				Remotes.event("RequestHireWorker"):FireServer(id)
			else
				local mode = WorkerRules.cleanMode(attribute("WorkerMode", id))
				Remotes.event("RequestWorkerMode"):FireServer(id, WorkerRules.nextMode(mode))
			end
		end)
	)
	table.insert(
		connections,
		level.Triggered:Connect(function()
			Remotes.event("RequestWorkerLevel"):FireServer(id)
		end)
	)
	table.insert(
		connections,
		give.Triggered:Connect(function()
			local best = bestInPen()
			if best then
				Remotes.event("RequestPlacePet"):FireServer(best.id, `{id}1`)
			end
		end)
	)
	table.insert(shows, show)
	for _, kind in { "WorkerLevel", "WorkerMode", "StaffName" } do
		table.insert(
			connections,
			Players.LocalPlayer:GetAttributeChangedSignal(`{kind}_{id}`):Connect(show)
		)
	end
	anchor.Parent = folder
end

local function enable()
	if folder then
		return
	end
	local made = Instance.new("Folder")
	made.Name = FOLDER_NAME
	folder = made
	for _, id in WorkerRules.IDS do
		build(id)
	end
	made.Parent = Workspace
end

local function disable()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(anchors)
	table.clear(shows)
	local made = folder
	folder = nil
	if made then
		made:Destroy()
	end
end

local function refresh()
	if LiveFlags.isOn(WorkerRules.FLAG) then
		enable()
	else
		disable()
	end
end

-- A worker's clean cat, which the server parents with WorkerProgress already 1 (WorkerService.seatCat).
local function watchFinished(instance: Instance)
	if
		instance:IsA("Model")
		and instance:GetAttribute(WorkerRules.WORKER_ATTRIBUTE) ~= nil
		and instance:GetAttribute("Cat") ~= nil
		and instance:GetAttribute(WorkerRules.PROGRESS_ATTRIBUTE) == 1
	then
		Moments.WorkerFinished:Fire(instance :: Model)
	end
end

function WorkerController.Init(_controllers: { [string]: any }) end

function WorkerController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. WorkerRules.FLAG)
		:Connect(refresh)
	-- the hire prompt shows Jo's price (switch joPrice, issue 841)
	ReplicatedStorage
		:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. WorkerRules.PRICE_FLAG)
		:Connect(refresh)
	ReplicatedStorage
		:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. WorkerRules.HUD_TIDY_FLAG)
		:Connect(function()
			for _, show in shows do
				show()
			end
		end)
	-- the plot placed or taken away: the prompts move with the stations
	SpaLayout.changed(function()
		for id, anchor in anchors do
			anchor.CFrame = SpaLayout.spot(WorkerRules.WORKERS[id].spot)
				* CFrame.new(0, ANCHOR_HEIGHT, 0)
		end
	end)
	Workspace.DescendantAdded:Connect(watchFinished)
	Remotes.event("Pets").OnClientEvent:Connect(function(raw: unknown)
		local list: { CrateRules.Pet } = {}
		if type(raw) == "table" then
			for _, entry in raw :: { any } do
				if
					type(entry) == "table"
					and type(entry.id) == "number"
					and type(entry.kind) == "string"
					and type(entry.star) == "number"
				then
					table.insert(list, {
						id = entry.id,
						kind = entry.kind,
						star = entry.star,
						slot = if type(entry.slot) == "string" then entry.slot else nil,
					})
				end
			end
		end
		pets = list
		for _, show in shows do
			show()
		end
	end)
	refresh()
end

return WorkerController
