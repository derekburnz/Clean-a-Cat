--!strict
-- CustomerWalkController: walks each customer at a door to their mat on this device (switch townsfolk, #446; the
-- owner on 2026-11-25: what bothers him most about the customers is how they look and walk in). FigureService puts
-- each of Model-Agent's townsfolk where it comes from (the pavement, or its old mat after a serve) and marks it with
-- its mat and the server time it sets off (WalkRules). This moves the whole customer there in a straight line at the
-- model's WalkSpeed, facing the way it walks and turning to the door at the end; Motion-FX's CustomerMotion swings
-- the legs and arms from that movement. A customer waiting to set off behind another is hidden, so a file of new
-- customers never stands in one spot. Client only: the server never moves a customer, so nothing replicates per
-- frame, and every player sees the same walk because all go by server time.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WalkRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WalkRules"))

local CustomerWalkController = {}

type Walk = {
	figure: Model,
	from: CFrame,
	to: CFrame,
	at: number,
	duration: number,
	facing: CFrame, -- the turn the customer walks with
	hidden: boolean,
}

local walks: { [Model]: Walk } = {}

local function setHidden(walk: Walk, hidden: boolean)
	if walk.hidden == hidden then
		return
	end
	walk.hidden = hidden
	for _, descendant in walk.figure:GetDescendants() do
		if descendant:IsA("BasePart") then
			(descendant :: BasePart).LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function finish(walk: Walk)
	walks[walk.figure] = nil
	setHidden(walk, false)
	if walk.figure.Parent then
		walk.figure:PivotTo(walk.to)
	end
end

local function begin(instance: Instance)
	if not instance:IsA("Model") or walks[instance :: Model] then
		return
	end
	local figure = instance :: Model
	local to = figure:GetAttribute(WalkRules.TO_ATTRIBUTE)
	local at = figure:GetAttribute(WalkRules.AT_ATTRIBUTE)
	if typeof(to) ~= "CFrame" or type(at) ~= "number" then
		return
	end
	local mat = to :: CFrame
	local from = figure:GetPivot()
	local speed = figure:GetAttribute("WalkSpeed")
	local distance = Vector3.new(mat.X - from.X, 0, mat.Z - from.Z).Magnitude
	local facing = mat.Rotation
	if WalkRules.facesTravel(from.Position, mat.Position, mat.LookVector) then
		local ahead = Vector3.new(mat.X, from.Y, mat.Z)
		facing = CFrame.lookAt(from.Position, ahead).Rotation
	end
	local walk: Walk = {
		figure = figure,
		from = from,
		to = mat,
		at = at :: number,
		duration = WalkRules.duration(distance, if type(speed) == "number" then speed else nil),
		facing = facing,
		hidden = false,
	}
	walks[figure] = walk
	figure.Destroying:Connect(function()
		walks[figure] = nil
	end)
end

local function step()
	if next(walks) == nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	for _, walk in walks do
		if walk.figure.Parent == nil then
			walks[walk.figure] = nil
			continue
		end
		local elapsed = now - walk.at
		local progress = WalkRules.progress(elapsed, walk.duration)
		if progress == nil then
			setHidden(walk, true) -- waiting behind the customer ahead in the file
			continue
		end
		if progress >= 1 then
			finish(walk)
			continue
		end
		setHidden(walk, false)
		local position = walk.from.Position:Lerp(walk.to.Position, progress)
		local turn = math.clamp(1 - (walk.duration - elapsed) / WalkRules.TURN_SECONDS, 0, 1)
		walk.figure:PivotTo(CFrame.new(position) * walk.facing:Lerp(walk.to.Rotation, turn))
	end
end

function CustomerWalkController.Init(_controllers: { [string]: any }) end

function CustomerWalkController.Start()
	CollectionService:GetInstanceAddedSignal(WalkRules.TAG):Connect(begin)
	for _, figure in CollectionService:GetTagged(WalkRules.TAG) do
		begin(figure)
	end
	RunService.RenderStepped:Connect(step)
end

return CustomerWalkController
