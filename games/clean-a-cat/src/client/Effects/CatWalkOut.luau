--!strict
-- CatWalkOut: a customer's washed cat goes home on its own paws (Sync's issue 773 run: the cat was just removed from
-- the tub about 6 s after Next cat, and Moments.CatReturned had no listener). On CatReturned the cat in the tub is
-- hidden on this device and a local copy plays:
--
--   hop     a happy hop out of the tub onto the floor, HOP_OUT studs towards the way out, with a soft puff on landing
--   walk    a trot to the front of the line (SpaLayout's SpotQueue1, the entrance side on both plots; Gameplay:
--           the owner has left the counter by then), facing the way it goes, with a small bob in each step
--   fade    it fades away over the last FADE seconds of the walk, as if out of the door
--   comfort Reduced Motion: no hop or walk; the cat fades where it is
--
-- Client only and cosmetic. The real cat stays hidden (by each part's own Transparency) for the rest of its life:
-- ScrubController keeps the done tub cat until the next cat is seated or picked up, which can be minutes later with
-- the recap card open, so it never shows again (Review-QA on #792). Its saved values clear on Destroying.
--
-- API
--   CatWalkOut.play(cat, to)                     plays it towards the CFrame `to` (its position; the floor height)
--   CatWalkOut.at(t, walkSeconds) -> (hop, walk, fade)   pure: each step's share (0 to 1) at `t` seconds
--   CatWalkOut.walkSeconds(distance) -> number   pure: the trot's length for `distance` studs
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent)

local CatWalkOut = {}

CatWalkOut.HOP_SECONDS = 0.5
CatWalkOut.HOP_HEIGHT = 1.1
CatWalkOut.HOP_OUT = 2.4 -- studs from the tub towards the way out
CatWalkOut.SPEED = 4.5 -- studs a second
CatWalkOut.MIN_WALK = 1.2
CatWalkOut.MAX_WALK = 4
CatWalkOut.FADE = 0.7
CatWalkOut.BOB = 0.12
CatWalkOut.STEP_HZ = 3.2

function CatWalkOut.walkSeconds(distance: number): number
	return math.clamp(distance / CatWalkOut.SPEED, CatWalkOut.MIN_WALK, CatWalkOut.MAX_WALK)
end

function CatWalkOut.at(t: number, walkSeconds: number): (number, number, number)
	local hop = math.clamp(t / CatWalkOut.HOP_SECONDS, 0, 1)
	local walkT = t - CatWalkOut.HOP_SECONDS
	local walk = if walkSeconds > 0 then math.clamp(walkT / walkSeconds, 0, 1) else 1
	local fadeFrom = math.max(walkSeconds - CatWalkOut.FADE, 0)
	local fade = math.clamp((walkT - fadeFrom) / CatWalkOut.FADE, 0, 1)
	return hop, walk, fade
end

local function smooth(u: number): number
	return u * u * (3 - 2 * u)
end

local saved: { [Instance]: number } = {}

local function hide(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			if saved[d] == nil then
				saved[d] = (d :: any).Transparency
			end
			(d :: any).Transparency = 1
		end
	end
end

local function release(root: Instance)
	for _, d in root:GetDescendants() do
		saved[d] = nil
	end
end

local function forget()
	for d in saved do
		if not d:IsDescendantOf(game) then
			saved[d] = nil
		end
	end
end

-- The copy's parts and decals, collected once when it is made (issue 821: no per frame model walks).
local function fadeParts(root: Instance): { Instance }
	local list: { Instance } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			table.insert(list, d)
		end
	end
	return list
end

local function fade(list: { Instance }, seen: number)
	for _, d in list do
		(d :: any).LocalTransparencyModifier = seen
	end
end

local FOLDER_NAME = "CleanACat_Fx_CatWalkOut"
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

local playing: { [Model]: boolean } = {}

function CatWalkOut.play(cat: Model, to: CFrame)
	if playing[cat] or cat.Parent == nil then
		return
	end
	local cloned = (cat :: Instance):Clone() :: any -- nil when the model is not Archivable
	if cloned == nil then
		return -- not Archivable: leave the cat as it is
	end
	local copy: Model = cloned
	playing[cat] = true
	cat.Destroying:Once(function()
		release(cat)
		playing[cat] = nil
		forget()
	end)
	local still = Effects.reducedMotion()
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d :: BasePart
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		elseif
			d:IsA("ProximityPrompt")
			or d:IsA("Script")
			or d:IsA("LocalScript")
			or d:IsA("BillboardGui")
			or d:IsA("ParticleEmitter")
		then
			d:Destroy()
		end
	end
	local parts = fadeParts(copy)
	local lastSeen = 0
	fade(parts, 0)
	copy.Name = "CleanACat_Fx_CatGoingHome"
	copy.Parent = folder()
	hide(cat)

	local start = cat:GetPivot()
	local box, size = cat:GetBoundingBox()
	local lift = start.Position.Y - (box.Position.Y - size.Y / 2) -- pivot over the cat's feet
	local floorY = to.Position.Y + lift
	local flat = Vector3.new(to.Position.X - start.Position.X, 0, to.Position.Z - start.Position.Z)
	local away = if flat.Magnitude > 0.01 then flat.Unit else start.LookVector
	local landAt = Vector3.new(start.Position.X, floorY, start.Position.Z)
		+ away * math.min(CatWalkOut.HOP_OUT, flat.Magnitude)
	local endAt = Vector3.new(to.Position.X, floorY, to.Position.Z)
	local facing = CFrame.lookAt(Vector3.zero, Vector3.new(away.X, 0, away.Z)).Rotation
	local walkSeconds = CatWalkOut.walkSeconds((endAt - landAt).Magnitude)
	local began = os.clock()
	local landed = false

	local connection: RBXScriptConnection? = nil
	local function finish()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		copy:Destroy()
		forget()
	end
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if still then
			local u = math.clamp(t / CatWalkOut.FADE, 0, 1)
			if u ~= lastSeen then
				lastSeen = u
				fade(parts, u)
			end
			if u >= 1 then
				finish()
			end
			return
		end
		local hop, walk, seen = CatWalkOut.at(t, walkSeconds)
		local cf: CFrame
		if hop < 1 then
			local u = smooth(hop)
			local turn = start.Rotation:Lerp(facing, u)
			local at = start.Position:Lerp(landAt, u)
				+ Vector3.new(0, CatWalkOut.HOP_HEIGHT * 4 * hop * (1 - hop), 0)
			cf = CFrame.new(at) * turn
		else
			if not landed then
				landed = true
				Effects.burst("roadDust", landAt - Vector3.new(0, lift - 0.1, 0))
			end
			local walked = t - CatWalkOut.HOP_SECONDS
			local bob = CatWalkOut.BOB * math.abs(math.sin(math.pi * CatWalkOut.STEP_HZ * walked))
			cf = CFrame.new(landAt:Lerp(endAt, walk) + Vector3.new(0, bob, 0)) * facing
		end
		copy:PivotTo(cf)
		if seen ~= lastSeen then -- the hop and most of the walk stay at 0: nothing to write
			lastSeen = seen
			fade(parts, seen)
		end
		if walk >= 1 and seen >= 1 then
			finish()
		end
	end)
end

return CatWalkOut
