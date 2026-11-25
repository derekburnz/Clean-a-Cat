--!strict
-- CatMotion: client-only procedural motion for the cat rigs (Model-Agent's generator, issue #11). One RunService
-- loop for every cat. The curves live in CatPose; this module only finds the joints and pivots them.
--
-- The rig is anchored Parts: Body is the PrimaryPart, Head and Tail are Models pivoted at their joints, the eyes
-- and ears are Models inside Head. Body never moves here, so mud on the body stays put and the server can still
-- move the whole cat: every target is worked out from Body's current CFrame and the rest offsets taken when the
-- cat was first seen, never read back from a part this module moved. Nothing here replicates.
--
-- API
--   CatMotion.start(tier, isOn)     isOn() is read once a second; when it turns false every cat goes back to rest
--   CatMotion.shake(cat)            the shake-off (CatClean)
--   CatMotion.wiggle(cat)           the happy wiggle (CatFluffed)
-- Cats are found by the `Cat` attribute the generator sets on each cat Model, once it is inside Workspace.
-- A waiting cat's mood follows the HeartFill number attribute (0 to 1) that Gameplay sets on the cat or on the
-- customer holding its carrier (issue #528); a cat with none in reach has no mood.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CatPose = require(script.Parent:WaitForChild("CatPose"))
local Comfort = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Comfort"))

type EyePart = { part: BasePart, offset: CFrame, size: Vector3 }

type Rig = {
	model: Model,
	body: BasePart,
	head: PVInstance?,
	headRest: CFrame, -- head pivot in Body's space
	tail: PVInstance?,
	tailRest: CFrame,
	earL: PVInstance?,
	earLRest: CFrame, -- ear pivot in the head's rest space
	earR: PVInstance?,
	earRRest: CFrame,
	eyes: { { rest: CFrame, parts: { EyePart } } }, -- eye pivot in the head's space, parts in the eye's space
	eyesShut: boolean,
	pose: CatPose.Pose,
	state: CatPose.State,
	nextAt: number,
	moved: boolean,
	moodFrom: Instance?, -- the cat or the ancestor that carries HeartFill
	moodLookAt: number, -- when to look for one again, while there is none
}

local CatMotion = {}

local rigs: { [Model]: Rig } = {}
local started = false
local tier: "low" | "high" = "high"
local enabled = false
local seedCount = 0

-- Roblox's Reduced Motion or the Settings card's Less screen shake or Less sparkle (UI/Comfort).
local function reducedMotion(): boolean
	return Comfort.reducedMotion()
end

local function findJoint(parent: Instance, key: string): PVInstance?
	for _, child in parent:GetChildren() do
		if child:IsA("PVInstance") and CatPose.jointKey(child.Name) == key then
			return child :: PVInstance
		end
	end
	return nil
end

local function findBody(model: Model): BasePart?
	local primary = model.PrimaryPart
	if primary and CatPose.jointKey(primary.Name) == "Body" then
		return primary
	end
	local body = findJoint(model, "Body")
	return if body and body:IsA("BasePart") then body :: BasePart else nil
end

local function eyeParts(eye: PVInstance): { EyePart }
	local list: { EyePart } = {}
	local pivot = eye:GetPivot()
	for _, part in eye:GetDescendants() do
		if part:IsA("BasePart") then
			local basePart = part :: BasePart
			table.insert(list, {
				part = basePart,
				offset = pivot:ToObjectSpace(basePart.CFrame),
				size = basePart.Size,
			})
		end
	end
	return list
end

local MOOD_ATTRIBUTE = "HeartFill"
local MOOD_REACH = 4 -- the cat, its carrier, the customer, and one more

-- The cat or nearest ancestor (a few steps up) that carries HeartFill, or nil.
local function moodSource(model: Model): Instance?
	local at: Instance? = model
	for _ = 0, MOOD_REACH do
		local here = at
		if here == nil or here:IsA("Workspace") then
			return nil
		end
		if type(here:GetAttribute(MOOD_ATTRIBUTE)) == "number" then
			return here
		end
		at = here.Parent
	end
	return nil
end

local function moodOf(rig: Rig, now: number): number?
	local from = rig.moodFrom
	if from == nil or from.Parent == nil then
		-- Gameplay may set the attribute after the cat arrives, so look again, once a second
		if now < rig.moodLookAt then
			return nil
		end
		rig.moodLookAt = now + 1
		from = moodSource(rig.model)
		rig.moodFrom = from
		if from == nil then
			return nil
		end
	end
	local fill = (from :: Instance):GetAttribute(MOOD_ATTRIBUTE)
	return if type(fill) == "number" then fill else nil
end

local function attach(model: Model)
	if rigs[model] or not model:IsDescendantOf(Workspace) then
		return
	end
	local body = findBody(model)
	if body == nil then
		return
	end
	local bodyCF = body.CFrame
	local head = findJoint(model, "Head")
	local tail = findJoint(model, "Tail")
	local headCF = if head then head:GetPivot() else bodyCF
	local earL = if head then findJoint(head, "EarL") else nil
	local earR = if head then findJoint(head, "EarR") else nil
	local eyes = {}
	if head then
		for _, key in { "Eye1", "Eye2" } do
			local eye = findJoint(head, key)
			if eye then
				table.insert(
					eyes,
					{ rest = headCF:ToObjectSpace(eye:GetPivot()), parts = eyeParts(eye) }
				)
			end
		end
	end
	seedCount += 1
	local now = os.clock()
	rigs[model] = {
		model = model,
		body = body,
		head = head,
		headRest = bodyCF:ToObjectSpace(headCF),
		tail = tail,
		tailRest = if tail then bodyCF:ToObjectSpace(tail:GetPivot()) else CFrame.identity,
		earL = earL,
		earLRest = if earL then headCF:ToObjectSpace(earL:GetPivot()) else CFrame.identity,
		earR = earR,
		earRRest = if earR then headCF:ToObjectSpace(earR:GetPivot()) else CFrame.identity,
		eyes = eyes,
		eyesShut = false,
		pose = CatPose.newPose(),
		state = CatPose.newState(CatPose.hash(seedCount, 7), now),
		nextAt = 0,
		moved = false,
		moodFrom = moodSource(model),
		moodLookAt = now + 1,
	}
end

local function pivotTo(instance: PVInstance?, target: CFrame)
	if instance and instance.Parent then
		instance:PivotTo(target)
	end
end

local function apply(rig: Rig, pose: CatPose.Pose)
	local bodyCF = rig.body.CFrame
	local headCF = bodyCF
		* rig.headRest
		* CFrame.Angles(pose.headPitch, pose.headYaw, pose.headRoll)
	pivotTo(rig.head, headCF)
	pivotTo(rig.earL, headCF * rig.earLRest * CFrame.Angles(0, 0, pose.earL))
	pivotTo(rig.earR, headCF * rig.earRRest * CFrame.Angles(0, 0, pose.earR))
	pivotTo(rig.tail, bodyCF * rig.tailRest * CFrame.Angles(pose.tailPitch, pose.tailYaw, 0))
	-- Head:PivotTo carried the eyes along, so a blink only needs writing while one plays and once after it.
	if pose.blink > 0 or rig.eyesShut then
		local squash = 1 - CatPose.BLINK_SQUASH * pose.blink
		for _, eye in rig.eyes do
			local eyeCF = headCF * eye.rest
			for _, entry in eye.parts do
				local o = entry.offset
				entry.part.Size = Vector3.new(entry.size.X, entry.size.Y * squash, entry.size.Z)
				entry.part.CFrame = eyeCF * CFrame.new(o.X, o.Y * squash, o.Z) * o.Rotation
			end
		end
		rig.eyesShut = pose.blink > 0
	end
end

local restPose = CatPose.newPose()

local function toRest(rig: Rig)
	if rig.moved and rig.body.Parent then
		rig.eyesShut = true -- writes the eyes back to full size once
		apply(rig, restPose)
	end
	rig.moved = false
end

local function step()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local from = camera.CFrame.Position
	local now = os.clock()
	local reduced = reducedMotion()
	local budget = CatPose.maxCats(tier)
	for model, rig in rigs do
		if model.Parent == nil or rig.body.Parent == nil then
			rigs[model] = nil
			continue
		end
		local distance = (rig.body.Position - from).Magnitude
		local interval = if budget > 0 then CatPose.step(distance, tier) else nil
		if interval == nil then
			toRest(rig)
			continue
		end
		budget -= 1
		if CatPose.busy(rig.state, now) then
			interval = CatPose.baseStep(tier)
		end
		if now < rig.nextAt then
			continue
		end
		rig.nextAt = now + interval
		CatPose.sample(rig.pose, rig.state, now, reduced)
		local fill = moodOf(rig, now)
		if fill then
			CatPose.applyMood(rig.pose, rig.state, now, fill, reduced)
		end
		apply(rig, rig.pose)
		rig.moved = true
	end
end

local function isCat(instance: Instance?): boolean
	return instance ~= nil and instance:IsA("Model") and instance:GetAttribute("Cat") ~= nil
end

-- With streaming on, a cat's joints can arrive after the cat Model. A Body, Head or Tail that turns up late
-- rebuilds that cat's rig, so the rest offsets are always taken from a whole, unmoved cat.
local function consider(instance: Instance)
	if isCat(instance) then
		attach(instance :: Model)
		return
	end
	local parent = instance.Parent
	if not isCat(parent) then
		return
	end
	local model = parent :: Model
	local key = CatPose.jointKey(instance.Name)
	local rig = rigs[model]
	if
		rig
		and (
			key == "Body"
			or (key == "Head" and rig.head == nil)
			or (key == "Tail" and rig.tail == nil)
		)
	then
		toRest(rig)
		rigs[model] = nil
	end
	if key then
		attach(model)
	end
end

function CatMotion.start(deviceTier: "low" | "high", isOn: () -> boolean)
	if started then
		return
	end
	started = true
	tier = deviceTier
	enabled = isOn()
	for _, instance in Workspace:GetDescendants() do
		consider(instance)
	end
	Workspace.DescendantAdded:Connect(consider)
	local checkAt = 0
	RunService.PreSimulation:Connect(function()
		local now = os.clock()
		if now >= checkAt then
			checkAt = now + 1
			local on = isOn()
			if enabled and not on then
				for _, rig in rigs do
					toRest(rig)
				end
			end
			enabled = on
		end
		if enabled then
			step()
		end
	end)
end

function CatMotion.shake(cat: Model)
	local rig = rigs[cat]
	if rig then
		rig.state.shakeAt = os.clock()
	end
end

function CatMotion.wiggle(cat: Model)
	local rig = rigs[cat]
	if rig then
		rig.state.wiggleAt = os.clock()
	end
end

return CatMotion
