--!strict
-- CustomerLeave: a customer whose cat's heart bar ran out turns round and walks off with the cat, head low, and
-- fades away (Moments.CatLeft, issue #528). The server redraws the line a moment later and the real figure goes, so
-- this walks a client-only copy instead. The copy keeps its asset name, so CustomerMotion swings its legs, and its
-- HeartFill stays 0, so the cat in the carrier keeps the leaving pose (CatPose.applyMood) and the customer's head
-- hangs (CustomerPose.mood). Kind to young players: no sad face or cloud, just a short calm exit.
--
-- The way out (#570): a quarter turn to their right and straight out sideways, off the line, as they set off. The
-- line is redrawn at once and the next customer steps up into the spot from behind, so the copy never walks back
-- down the line through them; it starts moving on the first frame and is a body's width clear in about half a second.
--
-- Client only and cosmetic: the copy has no tags and nothing on it collides, catches a ray or touches. Gone in
-- LEAVE_SECONDS. With Reduced Motion it fades where it stands.
--
-- API
--   CustomerLeave.leave(figure)          walks a copy of `figure` away
--   CustomerLeave.at(t) -> (turn, walked, seen)   pure: at `t` seconds, how far round (0 to 1 of the quarter
--                                                 turn), how far walked sideways (studs) and how see-through (0 to 1)
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent)

local CustomerLeave = {}

CustomerLeave.TURN_SECONDS = 0.3
CustomerLeave.RAMP_SECONDS = 0.3 -- from standing to walking pace, while turning
CustomerLeave.WALK_SPEED = 3.2 -- studs a second, a calm walk (CustomerPose swings fully from 2.5)
CustomerLeave.SIDE = -1 -- the turn: -1 a quarter to their right (away from the window seats), 1 to their left
CustomerLeave.LEAVE_SECONDS = 2.6
CustomerLeave.FADE_SECONDS = 0.7 -- the last part of the walk
CustomerLeave.STILL_FADE = 0.5 -- Reduced Motion: fades in place over this
local FOLDER_NAME = "CleanACat_Fx_Leaving"

function CustomerLeave.at(t: number): (number, number, number)
	local turnFor = CustomerLeave.TURN_SECONDS
	local u = math.clamp(t / turnFor, 0, 1)
	local turn = u * u * (3 - 2 * u)
	-- they set off as they turn, speeding up over RAMP_SECONDS, so the spot is clear for the next customer at once
	local ramp = CustomerLeave.RAMP_SECONDS
	local walked = if t <= 0
		then 0
		elseif t < ramp then CustomerLeave.WALK_SPEED * t * t / (2 * ramp)
		else CustomerLeave.WALK_SPEED * (t - ramp / 2)
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
	-- the cat packed back into the carrier was placed by the server where it keeps the figure, on the pavement; seat
	-- it in the carrier as this device draws the figure first, or the copy carries it 16 studs off (issue 871)
	for _, item in figure:GetDescendants() do
		if item.Name == "PackedCat" and item:IsA("Model") and item.Parent then
			local seat = (item.Parent :: Instance):FindFirstChild("CatSeat", true)
			if seat and seat:IsA("Attachment") then
				(item :: Model):PivotTo((seat :: Attachment).WorldCFrame)
			end
		end
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
	-- the real figure stays until the server's Destroy reaches this client; take it out of this client's world in the
	-- same frame so there is only one (B4 on #571: a hide by LocalTransparencyModifier can be undone for a frame by
	-- the walk-in's own show). The server's Destroy still follows; nothing else holds the figure.
	figure.Parent = nil

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
		-- a quarter turn and straight out sideways, off the line (never back down it: #570)
		local out = start * CFrame.Angles(0, CustomerLeave.SIDE * math.pi / 2, 0)
		local facing = start * CFrame.Angles(0, CustomerLeave.SIDE * math.pi / 2 * turn, 0)
		copy:PivotTo(facing + out.LookVector * walked)
		fade(parts, seen)
	end)
end

return CustomerLeave
