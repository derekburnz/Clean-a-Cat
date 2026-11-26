--!strict
-- CustomerLeave: a customer whose cat's heart bar ran out turns round and walks off with the cat, head low, and
-- fades away (Moments.CatLeft, issue #528). The server redraws the line a moment later and the real figure goes, so
-- this walks a client-only copy instead. The copy keeps its asset name, so CustomerMotion swings its legs, and its
-- HeartFill stays 0, so the cat in the carrier keeps the leaving pose (CatPose.applyMood) and the customer's head
-- hangs (CustomerPose.mood). Kind to young players: no sad face or cloud, just a short calm exit.
--
-- Client only and cosmetic: the copy has no tags and nothing on it collides, catches a ray or touches. Gone in
-- LEAVE_SECONDS. With Reduced Motion it fades where it stands.
--
-- API
--   CustomerLeave.leave(figure)          walks a copy of `figure` away
--   CustomerLeave.at(t) -> (turn, walked, seen)   pure: at `t` seconds, how far round (0 to 1), how far walked
--                                                 (studs) and how see-through (0 to 1)
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent)

local CustomerLeave = {}

CustomerLeave.TURN_SECONDS = 0.45
CustomerLeave.WALK_SPEED = 2.8 -- studs a second, a calm walk (CustomerPose swings fully from 2.5)
CustomerLeave.LEAVE_SECONDS = 2.6
CustomerLeave.FADE_SECONDS = 0.7 -- the last part of the walk
CustomerLeave.STILL_FADE = 0.5 -- Reduced Motion: fades in place over this
local FOLDER_NAME = "CleanACat_Fx_Leaving"

function CustomerLeave.at(t: number): (number, number, number)
	local turnFor = CustomerLeave.TURN_SECONDS
	local u = math.clamp(t / turnFor, 0, 1)
	local turn = u * u * (3 - 2 * u)
	local walked = math.max(0, t - turnFor * 0.6) * CustomerLeave.WALK_SPEED -- the first step starts as the turn ends
	local fadeFrom = CustomerLeave.LEAVE_SECONDS - CustomerLeave.FADE_SECONDS
	local seen = math.clamp((t - fadeFrom) / CustomerLeave.FADE_SECONDS, 0, 1)
	return turn, walked, seen
end

local function folder(): Folder
	local found = Workspace:FindFirstChild(FOLDER_NAME)
	if found and found:IsA("Folder") then
		return found :: Folder
	end
	local made = Instance.new("Folder")
	made.Name = FOLDER_NAME
	made.Parent = Workspace
	return made
end

local function quiet(copy: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, d in copy:GetDescendants() do
		for _, tag in CollectionService:GetTags(d) do
			CollectionService:RemoveTag(d, tag)
		end
		if d:IsA("BasePart") then
			local p = d :: BasePart
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			table.insert(parts, p)
		elseif
			d:IsA("ProximityPrompt")
			or d:IsA("ClickDetector")
			or d:IsA("Script")
			or d:IsA("LocalScript")
		then
			d:Destroy()
		end
	end
	for _, tag in CollectionService:GetTags(copy) do
		CollectionService:RemoveTag(copy, tag)
	end
	return parts
end

local function fade(parts: { BasePart }, seen: number)
	for _, p in parts do
		p.LocalTransparencyModifier = seen
	end
end

function CustomerLeave.leave(figure: Model)
	if not figure:IsDescendantOf(Workspace) then
		return
	end
	local wasArchivable = figure.Archivable
	figure.Archivable = true
	local ok, made = pcall(function(): Model?
		return figure:Clone() :: Model
	end)
	figure.Archivable = wasArchivable
	local cloned: Model? = if ok then made else nil
	if cloned == nil then
		return
	end
	local copy = cloned :: Model
	local parts = quiet(copy)
	copy:SetAttribute("HeartFill", 0)
	local start = figure:GetPivot()
	copy:PivotTo(start)
	copy.Parent = folder()
	-- the real figure stays until the server redraws the line; hide it now so there is only one
	for _, d in figure:GetDescendants() do
		if d:IsA("BasePart") then
			(d :: BasePart).LocalTransparencyModifier = 1
		end
	end

	local still = Effects.reducedMotion()
	local began = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.PreRender:Connect(function()
		local t = os.clock() - began
		local finished = if still
			then t >= CustomerLeave.STILL_FADE
			else t >= CustomerLeave.LEAVE_SECONDS
		if finished or copy.Parent == nil then
			if connection then
				connection:Disconnect()
			end
			copy:Destroy()
			return
		end
		if still then
			fade(parts, t / CustomerLeave.STILL_FADE)
			return
		end
		local turn, walked, seen = CustomerLeave.at(t)
		-- turn round on the spot, then walk the way they now face (back the way they came, away from the door)
		local facing = start * CFrame.Angles(0, math.pi * turn, 0)
		copy:PivotTo(facing + facing.LookVector * walked)
		fade(parts, seen)
	end)
end

return CustomerLeave
