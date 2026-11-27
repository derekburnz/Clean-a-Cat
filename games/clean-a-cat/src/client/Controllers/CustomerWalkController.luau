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

local CounterRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CounterRules"))
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
	file: boolean, -- a new customer in the file from the pavement: hidden until they set off
}

local walks: { [Model]: Walk } = {}
local watched: { [Model]: boolean } = {} -- figures whose WalkAt is listened to

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

-- (switch counterLine) The figure's cat on the counter goes exactly on its spot (the server's CounterSpotAt) once the
-- figure stands on its mat: places 2 to 6 sat about 4 studs off their mats and some floated outside the counter
-- (issue 923), so the spot no longer rides on the figure's pivot.
local function seatCounterCat(figure: Model)
	local cat = figure:FindFirstChild(CounterRules.CAT_NAME)
	local at = if cat then cat:GetAttribute(CounterRules.SPOT_AT_ATTRIBUTE) else nil
	if cat and cat:IsA("Model") and typeof(at) == "CFrame" then
		(cat :: Model):PivotTo(at :: CFrame)
	end
end

-- A leaving customer's cat goes back into their carrier on the server (FigureService.packCat), placed at the
-- carrier's CatSeat where the server keeps the figure: on the pavement, not where this device walked it. Seat it in
-- the carrier as this device draws it, or it shows about 16 studs off on the street (Sync on 208dc9d, issue 871).
local PACKED_NAME = "PackedCat"
local function seatPacked(item: Instance)
	if not item:IsA("Model") then
		return
	end
	-- the new name can reach this device after the new parent: look once both are in
	task.defer(function()
		local carrier = item.Parent
		if item.Name ~= PACKED_NAME or carrier == nil then
			return
		end
		local seat = carrier:FindFirstChild("CatSeat", true)
		if seat and seat:IsA("Attachment") then
			(item :: Model):PivotTo((seat :: Attachment).WorldCFrame)
		end
	end)
end

local function finish(walk: Walk)
	walks[walk.figure] = nil
	setHidden(walk, false)
	if walk.figure.Parent then
		walk.figure:PivotTo(walk.to)
		seatCounterCat(walk.figure)
	end
end

local function begin(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local figure = instance :: Model
	if not watched[figure] then
		-- a line redrawn in place gives a figure a new walk: it starts again from where it stands now
		watched[figure] = true
		figure:GetAttributeChangedSignal(WalkRules.AT_ATTRIBUTE):Connect(function()
			local old = walks[figure]
			if old then
				walks[figure] = nil
				setHidden(old, false)
			end
			begin(figure)
		end)
		figure.Destroying:Connect(function()
			watched[figure] = nil
			walks[figure] = nil
		end)
		figure.DescendantAdded:Connect(seatPacked)
	end
	if walks[figure] then
		return
	end
	local to = figure:GetAttribute(WalkRules.TO_ATTRIBUTE)
	local at = figure:GetAttribute(WalkRules.AT_ATTRIBUTE)
	if typeof(to) ~= "CFrame" or type(at) ~= "number" then
		seatCounterCat(figure) -- drawn already on its mat
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
		file = figure:GetAttribute(WalkRules.FILE_ATTRIBUTE) == true,
	}
	walks[figure] = walk
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
			-- a new customer waits hidden behind the one ahead in the file; one stepping up stands on their mat
			setHidden(walk, walk.file)
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
