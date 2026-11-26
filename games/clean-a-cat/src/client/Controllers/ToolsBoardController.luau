--!strict
-- ToolsBoardController: the Tools board beside the tub, Model-Agent's board (Spa/BoardProp; the plain slab when the
-- model is missing) with one prompt per tool on its shelves. The player walks up and taps the prompt (a button on
-- touch, a key or gamepad button elsewhere); the server (ToolService) checks and takes the coins. An owned tool's
-- prompt goes away, and so does its display on the shelf. Nothing opens by itself.
-- Behind the LiveFlags switch `toolsBoard`. With `bowTiers` on too, the row below the tools sells the next bow tier
-- (BowRules, issue 508), and goes away once the Golden bow is bought.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BoardProp = require(script.Parent.Parent:WaitForChild("Spa"):WaitForChild("BoardProp"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BowRules = require(Shared:WaitForChild("BowRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local ToolRules = require(Shared:WaitForChild("ToolRules"))

local FLAG = "toolsBoard"
local SPEC: BoardProp.Spec = {
	asset = "CleanACat_Prop_ToolsBoard",
	title = "Tools",
	placeholder = "PH_ToolsBoard",
	size = Vector3.new(4, 5, 0.4),
	color = Color3.fromRGB(180, 140, 100),
}

local ToolsBoardController = {}

local board: BoardProp.Board? = nil
local connections: { RBXScriptConnection } = {}

local function owns(id: string): boolean
	return Players.LocalPlayer:GetAttribute(ToolRules.ATTRIBUTE_PREFIX .. id) == true
end

local function enable()
	if board then
		return
	end
	local offered = ToolRules.offered(LiveFlags.isOn)
	-- every tool keeps its own shelf (its place in IDS, where the model's display stands), so with one switched off
	-- the next tool's prompt is never on the empty shelf (Review-QA on #432)
	local sellsBows = LiveFlags.isOn(BowRules.FLAG)
	local made =
		BoardProp.make(SPEC, SpaLayout.spot("Tools"), #ToolRules.IDS + (if sellsBows then 1 else 0))
	-- a tool on sale shows on its shelf until it is owned; one switched off never shows
	local function showDisplay(id: string)
		BoardProp.showDisplay(made, id, table.find(offered, id) ~= nil and not owns(id))
	end
	for _, id in ToolRules.IDS do
		showDisplay(id)
	end
	for _, id in offered do
		local tool = ToolRules.TOOLS[id]
		local row = table.find(ToolRules.IDS, id) :: number
		local spot = made.rows[row]
		local prompt = Instance.new("ProximityPrompt")
		BoardProp.rowKeys(prompt, row)
		prompt.ActionText = `Buy {tool.name}`
		prompt.ObjectText = `{tool.price} coins`
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = ToolRules.PROMPT_REACH
		prompt.RequiresLineOfSight = false
		prompt.Enabled = not owns(id)
		prompt.Parent = spot
		table.insert(
			connections,
			prompt.Triggered:Connect(function()
				Remotes.event("RequestBuyTool"):FireServer(id)
			end)
		)
		table.insert(
			connections,
			Players.LocalPlayer
				:GetAttributeChangedSignal(ToolRules.ATTRIBUTE_PREFIX .. id)
				:Connect(function()
					prompt.Enabled = not owns(id)
					showDisplay(id)
				end)
		)
	end
	if sellsBows then
		local prompt = Instance.new("ProximityPrompt")
		BoardProp.rowKeys(prompt, #ToolRules.IDS + 1)
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = ToolRules.PROMPT_REACH
		prompt.RequiresLineOfSight = false
		prompt.Parent = made.rows[#ToolRules.IDS + 1]
		local onSale: string? = nil
		-- the next tier from the one in use, which the server shows as BowTier
		local function showNext()
			local tier = BowRules.clean(Players.LocalPlayer:GetAttribute(BowRules.ATTRIBUTE))
				or BowRules.FIRST
			local bows: { [string]: boolean } = {}
			for _, each in BowRules.TIERS do
				bows[each] = true
				if each == tier then
					break
				end
			end
			onSale = BowRules.nextTier(bows)
			local info = if onSale then BowRules.TIER[onSale] else nil
			prompt.Enabled = info ~= nil
			if info then
				prompt.ActionText = `Buy {info.name} bow`
				prompt.ObjectText = `{info.price} coins, +{info.bonus} a cat`
			end
		end
		showNext()
		table.insert(
			connections,
			prompt.Triggered:Connect(function()
				if onSale then
					Remotes.event("RequestBuyBow"):FireServer(onSale)
				end
			end)
		)
		table.insert(
			connections,
			Players.LocalPlayer:GetAttributeChangedSignal(BowRules.ATTRIBUTE):Connect(showNext)
		)
	end
	made.root.Parent = Workspace
	board = made
end

local function disable()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
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

function ToolsBoardController.Init(_controllers: { [string]: any }) end

function ToolsBoardController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(refresh)
	-- the bow row comes and goes with its own switch
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. BowRules.FLAG)
		:Connect(function()
			disable()
			refresh()
		end)
	-- A tool's own switch (the Pro Brush's) changed: the board is drawn again with or without it.
	for _, id in ToolRules.IDS do
		local toolFlag = ToolRules.TOOLS[id].flag
		if toolFlag then
			ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. toolFlag)
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
			BoardProp.moveTo(made, SpaLayout.spot("Tools"))
		end
	end)
	refresh()
end

return ToolsBoardController
