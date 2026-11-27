--!strict
-- HelperFetchController: walks each helper to the counter for their cat and back on this device (HelperFetchRules,
-- switch helperFetch, issue 884). The server marks the helper's staff model in their stand (FetchFrom, FetchTo,
-- FetchAt, FetchCat, FetchWay); this moves the model along that walk by server time, faces the way it goes, and shows
-- the cat in their arms while they carry it. Motion-FX's CustomerMotion swings a CleanACat_NPC_Staff_ model's legs
-- and arms from that movement. At the end the helper is put back exactly where the server drew them. Client only and
-- cosmetic: the server never moves the helper, so nothing replicates per frame, and every player sees the same walk.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HelperFetchRules = require(Shared:WaitForChild("HelperFetchRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local STAFF_PREFIX = "CleanACat_NPC_Staff_"

local HelperFetchController = {}

type Walk = {
	staff: Model,
	home: CFrame, -- where the server drew the helper
	height: number,
	way: string,
	from: Vector3,
	to: Vector3,
	at: number,
	catName: string,
	held: Model?,
}

local walks: { [Model]: Walk } = {}
local watched: { [Model]: boolean } = {}
local step: RBXScriptConnection? = nil

-- A client-only copy of the cat they carry: anchored, never colliding, catching a ray or touching anything.
local function heldCopy(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local asset = if assets then assets:FindFirstChild(name) else nil
	if not (asset and asset:IsA("Model")) then
		return nil
	end
	local copy = (asset :: Model):Clone() :: Model
	for _, item in copy:GetDescendants() do
		if item:IsA("BasePart") then
			local part = item :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		elseif item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		end
	end
	copy:ScaleTo(HelperFetchRules.HELD_SCALE)
	copy.Name = "CleanACat_FetchHeld"
	return copy
end

local function stop(walk: Walk)
	walks[walk.staff] = nil
	local held = walk.held
	walk.held = nil
	if held then
		held:Destroy()
	end
	if walk.staff.Parent then
		walk.staff:PivotTo(walk.home)
	end
end

local function advance()
	local now = Workspace:GetServerTimeNow()
	for staff, walk in walks do
		if staff.Parent == nil or not LiveFlags.isOn(HelperFetchRules.FLAG) then
			stop(walk)
			continue
		end
		local pose = HelperFetchRules.pose(walk.way, walk.from, walk.to, now - walk.at)
		if pose.done then
			stop(walk)
			continue
		end
		-- the walk keeps the height the server drew them at; it turns them to face the way they go
		local at = Vector3.new(pose.position.X, walk.home.Position.Y, pose.position.Z)
		local frame = CFrame.lookAt(at, at + pose.facing)
		staff:PivotTo(frame)
		if pose.holding then
			local held = walk.held
			if held == nil then
				held = heldCopy(walk.catName)
				walk.held = held
				if held then
					held.Parent = Workspace
				end
			end
			if held then
				held:PivotTo(
					frame
						* CFrame.new(
							0,
							walk.height * HelperFetchRules.HELD_UP,
							-HelperFetchRules.HELD_AHEAD
						)
				)
			end
		elseif walk.held then
			local held = walk.held :: Model
			walk.held = nil
			held:Destroy()
		end
	end
	if next(walks) == nil and step then
		(step :: RBXScriptConnection):Disconnect()
		step = nil
	end
end

local function begin(staff: Model)
	local from = staff:GetAttribute(HelperFetchRules.FROM_ATTRIBUTE)
	local to = staff:GetAttribute(HelperFetchRules.TO_ATTRIBUTE)
	local at = staff:GetAttribute(HelperFetchRules.AT_ATTRIBUTE)
	local catName = staff:GetAttribute(HelperFetchRules.CAT_ATTRIBUTE)
	local way = staff:GetAttribute(HelperFetchRules.WAY_ATTRIBUTE)
	if
		typeof(from) ~= "Vector3"
		or typeof(to) ~= "Vector3"
		or type(at) ~= "number"
		or type(catName) ~= "string"
		or type(way) ~= "string"
		or not LiveFlags.isOn(HelperFetchRules.FLAG)
	then
		return
	end
	local was = walks[staff]
	local oldHeld = if was then was.held else nil
	if oldHeld then
		oldHeld:Destroy()
	end
	-- the server's own spot, taken before this ever moves the model (a walk already under way keeps its home)
	local home = if was then was.home else staff:GetPivot()
	local _, size = staff:GetBoundingBox()
	walks[staff] = {
		staff = staff,
		home = home,
		height = size.Y,
		way = way,
		from = from :: Vector3,
		to = to :: Vector3,
		at = at :: number,
		catName = catName :: string,
		held = nil,
	}
	if step == nil then
		step = RunService.RenderStepped:Connect(advance)
	end
end

local function watch(item: Instance)
	if not item:IsA("Model") or string.sub(item.Name, 1, #STAFF_PREFIX) ~= STAFF_PREFIX then
		return
	end
	local staff = item :: Model
	if watched[staff] then
		return
	end
	watched[staff] = true
	staff:GetAttributeChangedSignal(HelperFetchRules.AT_ATTRIBUTE):Connect(function()
		begin(staff)
	end)
	staff.Destroying:Once(function()
		watched[staff] = nil
		local walk = walks[staff]
		if walk then
			stop(walk)
		end
	end)
	-- a helper already on a walk when this device saw them (a join mid-walk)
	if staff:GetAttribute(HelperFetchRules.AT_ATTRIBUTE) ~= nil then
		begin(staff)
	end
end

function HelperFetchController.Init(_controllers: { [string]: any }) end

function HelperFetchController.Start()
	Workspace.DescendantAdded:Connect(watch)
	for _, item in Workspace:GetDescendants() do
		watch(item)
	end
end

return HelperFetchController
