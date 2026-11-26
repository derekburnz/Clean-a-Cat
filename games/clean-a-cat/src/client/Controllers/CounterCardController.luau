--!strict
-- CounterCardController: a CounterCard over each cat waiting on the counter in the player's own spa, and a pale wash
-- of its owner's shirt colour on that cat's mat (issue 745 part 2, switch counterCards with counterLine and heartBar;
-- shared/CounterCardRules says why). FigureService puts each counter cat under its customer's figure as CounterCat
-- (CounterRules), with its place as CounterPlace; the figure carries HeartFill. This only draws: it never asks the
-- server for anything, and the Take prompt on the cat stays the tap.
--
-- A card goes when its cat leaves the counter (packed back into the carrier, taken, or the figure goes) or the switch
-- goes off, and the mats go back to their own colour then.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CounterCardRules = require(Shared:WaitForChild("CounterCardRules"))
local CounterRules = require(Shared:WaitForChild("CounterRules"))
local HeartRules = require(Shared:WaitForChild("HeartRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local WalkRules = require(Shared:WaitForChild("WalkRules"))

local CounterCard = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("CounterCard"))

local CounterCardController = {}

type Shown = {
	card: CounterCard.Card,
	figure: Model,
	connections: { RBXScriptConnection },
}

local shown: { [Model]: Shown } = {} -- by counter cat
local matColors: { [BasePart]: Color3 } = {} -- each tinted mat's own colour, to put back
local guiParent: Instance? = nil

local function on(): boolean
	return CounterCardRules.on(LiveFlags.isOn)
end

local function ownPlot(): Model?
	local slot = SpaLayout.slotOf()
	return if slot then SpaLayout.plotModel(slot) else nil
end

local function shirtOf(figure: Model): Color3?
	local torso = figure:FindFirstChild("UpperTorso") or figure:FindFirstChild("Torso")
	return if torso and torso:IsA("BasePart") then (torso :: BasePart).Color else nil
end

local function mat(place: unknown): BasePart?
	local name = CounterCardRules.matName(place)
	local plot = ownPlot()
	local found = if name and plot then plot:FindFirstChild(name, true) else nil
	return if found and found:IsA("BasePart") then found :: BasePart else nil
end

local function untintAll()
	for part, color in matColors do
		if part.Parent then
			part.Color = color
		end
	end
	table.clear(matColors)
end

-- Every mat with a cat on it takes its owner's wash; every other one gets its own colour back.
local function tintMats()
	local want: { [BasePart]: Color3 } = {}
	for cat, entry in shown do
		local part = mat(cat:GetAttribute(CounterRules.PLACE_ATTRIBUTE))
		local shirt = shirtOf(entry.figure)
		if part and shirt then
			want[part] = CounterCardRules.matColor(shirt)
		end
	end
	for part, color in matColors do
		local wanted: Color3? = want[part]
		if wanted == nil then
			if part.Parent then
				part.Color = color
			end
			matColors[part] = nil
		end
	end
	for part, color in want do
		local own: Color3? = matColors[part]
		if own == nil then
			matColors[part] = part.Color
		end
		part.Color = color
	end
end

local function redraw(cat: Model)
	local entry = shown[cat]
	if entry then
		entry.card.set(
			CounterCardRules.fill(entry.figure:GetAttribute(HeartRules.FILL_ATTRIBUTE)),
			shirtOf(entry.figure)
		)
	end
end

local function drop(cat: Model)
	local entry = shown[cat]
	if entry == nil then
		return
	end
	shown[cat] = nil
	for _, connection in entry.connections do
		connection:Disconnect()
	end
	entry.card.destroy()
	tintMats()
end

local function onCounter(cat: Instance, figure: Model): boolean
	return cat.Parent == figure
		and cat.Name == CounterRules.CAT_NAME
		and type(cat:GetAttribute(CounterRules.PLACE_ATTRIBUTE)) == "number"
end

local function add(cat: Instance, figure: Model)
	if shown[cat :: Model] or not cat:IsA("Model") or not onCounter(cat, figure) or not on() then
		return
	end
	local plot = ownPlot()
	if plot == nil or not figure:IsDescendantOf(plot) or guiParent == nil then
		return
	end
	local model = cat :: Model
	local adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if adornee == nil then
		return
	end
	local entry: Shown = {
		card = CounterCard.new(adornee :: BasePart, guiParent :: Instance),
		figure = figure,
		connections = {},
	}
	shown[model] = entry
	local function check()
		if onCounter(model, figure) and on() then
			entry.card.place(model:GetAttribute(CounterRules.PLACE_ATTRIBUTE))
			redraw(model)
			tintMats()
		else
			drop(model)
		end
	end
	table.insert(
		entry.connections,
		figure:GetAttributeChangedSignal(HeartRules.FILL_ATTRIBUTE):Connect(function()
			redraw(model)
		end)
	)
	table.insert(
		entry.connections,
		model:GetAttributeChangedSignal(CounterRules.PLACE_ATTRIBUTE):Connect(check)
	)
	table.insert(entry.connections, model:GetPropertyChangedSignal("Name"):Connect(check))
	table.insert(entry.connections, model.AncestryChanged:Connect(check))
	entry.card.place(model:GetAttribute(CounterRules.PLACE_ATTRIBUTE))
	redraw(model)
	tintMats()
end

local watched: { [Model]: RBXScriptConnection } = {}

local function watch(instance: Instance)
	if not instance:IsA("Model") or watched[instance :: Model] then
		return
	end
	local figure = instance :: Model
	watched[figure] = figure.ChildAdded:Connect(function(child: Instance)
		add(child, figure)
		-- FigureService parents a newcomer's cat first and gives it its place a moment later: try again then.
		if shown[child :: Model] == nil and child:IsA("Model") then
			child:GetAttributeChangedSignal(CounterRules.PLACE_ATTRIBUTE):Once(function()
				add(child, figure)
			end)
		end
	end)
	for _, child in figure:GetChildren() do
		add(child, figure)
	end
end

local function unwatch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local connection = watched[instance :: Model]
	if connection then
		connection:Disconnect()
		watched[instance :: Model] = nil
	end
end

-- The switch or the plot changed: draw every counter cat again from scratch.
local function rebuild()
	for cat in shown do
		drop(cat)
	end
	untintAll()
	if not on() then
		return
	end
	for figure in watched do
		for _, child in figure:GetChildren() do
			add(child, figure)
		end
	end
end

function CounterCardController.Init(_controllers: { [string]: any }) end

function CounterCardController.Start()
	local player = Players.LocalPlayer
	guiParent = player:WaitForChild("PlayerGui")
	CollectionService:GetInstanceAddedSignal(WalkRules.TAG):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(WalkRules.TAG):Connect(unwatch)
	for _, figure in CollectionService:GetTagged(WalkRules.TAG) do
		watch(figure)
	end
	local flags = { CounterCardRules.FLAG }
	for _, flag in CounterCardRules.NEEDS do
		table.insert(flags, flag)
	end
	for _, flag in flags do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(rebuild)
	end
	player:GetAttributeChangedSignal(SpaLayout.SLOT_ATTRIBUTE):Connect(rebuild)
end

return CounterCardController
