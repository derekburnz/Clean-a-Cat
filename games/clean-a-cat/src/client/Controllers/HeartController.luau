--!strict
-- HeartController: the waiting customers' heart bars on this device (switch heartBar, issue 507). The server owns
-- the bars (SpaService, HeartRules): it puts each one on the customer's figure as HeartFill and says when a customer
-- leaves (CustomerLeft). This only turns those into Moments for the sound and motion lanes, for the player's own door
-- line: HeartLow when a bar falls to HeartRules.GRUMPY_AT, CatLeft as a customer leaves.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeartRules = require(Shared:WaitForChild("HeartRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(Shared:WaitForChild("Moments"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local WalkRules = require(Shared:WaitForChild("WalkRules"))

local HeartController = {}

local PLACE_ATTRIBUTE = "LinePlace" -- FigureService: the customer's place in the line as shown

-- Each watched figure's last fill, so HeartLow fires once as the bar crosses the line, not every update.
local lastFill: { [Model]: number } = {}

local function ownPlot(): Model?
	local slot = SpaLayout.slotOf()
	return if slot then SpaLayout.plotModel(slot) else nil
end

local function isOwn(figure: Instance): boolean
	local plot = ownPlot()
	return plot ~= nil and figure:IsDescendantOf(plot)
end

local function onFill(figure: Model)
	local raw = figure:GetAttribute(HeartRules.FILL_ATTRIBUTE)
	if type(raw) ~= "number" then
		lastFill[figure] = nil
		return
	end
	local before = lastFill[figure]
	lastFill[figure] = raw
	if
		before ~= nil
		and before > HeartRules.GRUMPY_AT
		and raw <= HeartRules.GRUMPY_AT
		and LiveFlags.isOn(HeartRules.FLAG)
		and isOwn(figure)
	then
		Moments.HeartLow:Fire(figure)
	end
end

local function watch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local figure = instance :: Model
	local fill = figure:GetAttribute(HeartRules.FILL_ATTRIBUTE)
	lastFill[figure] = if type(fill) == "number" then fill else nil
	figure:GetAttributeChangedSignal(HeartRules.FILL_ATTRIBUTE):Connect(function()
		onFill(figure)
	end)
	figure.Destroying:Connect(function()
		lastFill[figure] = nil
	end)
end

local function onLeft(rawPlace: unknown, _rawKind: unknown)
	if type(rawPlace) ~= "number" or not LiveFlags.isOn(HeartRules.FLAG) then
		return
	end
	for _, figure in CollectionService:GetTagged(WalkRules.TAG) do
		if
			figure:IsA("Model")
			and figure:GetAttribute(PLACE_ATTRIBUTE) == rawPlace
			and isOwn(figure)
		then
			Moments.CatLeft:Fire(figure :: Model)
			return
		end
	end
end

function HeartController.Init(_controllers: { [string]: any }) end

function HeartController.Start()
	CollectionService:GetInstanceAddedSignal(WalkRules.TAG):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(WalkRules.TAG):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			lastFill[instance :: Model] = nil
		end
	end)
	for _, figure in CollectionService:GetTagged(WalkRules.TAG) do
		watch(figure)
	end
	Remotes.event("CustomerLeft").OnClientEvent:Connect(onLeft)
end

return HeartController
