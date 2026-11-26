--!strict
-- VisitorController: special visitors on this device (switch specialVisitors, issue 510). The server owns them
-- (SpaService, SpecialRules) and draws each as a customer figure with the attribute Special in the owner's door line.
-- This only turns a visitor's figure in the player's own line into Moments.VisitorArrived for the motion and sound
-- lanes: `again` false on the first figure of a visit, true on a redrawn one.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(Shared:WaitForChild("Moments"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SpecialRules = require(Shared:WaitForChild("SpecialRules"))
local WalkRules = require(Shared:WaitForChild("WalkRules"))

local VisitorController = {}

-- The cat of the visitor whose arrival played, while their figure stays in the line.
local visiting: string? = nil
local figures: { [Model]: boolean } = {}

local function isOwn(figure: Instance): boolean
	local slot = SpaLayout.slotOf()
	local plot = if slot then SpaLayout.plotModel(slot) else nil
	return plot ~= nil and figure:IsDescendantOf(plot)
end

local function onFigure(instance: Instance)
	if
		not instance:IsA("Model")
		or instance:GetAttribute(SpecialRules.FIGURE_ATTRIBUTE) ~= true
		or not LiveFlags.isOn(SpecialRules.FLAG)
	then
		return
	end
	-- the tag may come before the figure is parented into the plot
	task.defer(function()
		if instance.Parent == nil or not isOwn(instance) then
			return
		end
		local figure = instance :: Model
		local kind = figure:GetAttribute("CatKind")
		local again = visiting ~= nil and visiting == kind
		visiting = if type(kind) == "string" then kind else nil
		figures[figure] = true
		figure.Destroying:Connect(function()
			figures[figure] = nil
			-- a redraw makes the new figure before the old one goes; the visit is over once none is left a moment
			task.delay(1, function()
				if next(figures) == nil then
					visiting = nil
				end
			end)
		end)
		Moments.VisitorArrived:Fire(figure, again)
	end)
end

function VisitorController.Init(_controllers: { [string]: any }) end

function VisitorController.Start()
	CollectionService:GetInstanceAddedSignal(WalkRules.TAG):Connect(onFigure)
	for _, figure in CollectionService:GetTagged(WalkRules.TAG) do
		onFigure(figure)
	end
end

return VisitorController
