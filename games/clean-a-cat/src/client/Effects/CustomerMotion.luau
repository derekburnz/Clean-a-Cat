--!strict
-- CustomerMotion: client-only walk and idle for the customers (Model-Agent's CleanACat_NPC_Customer_* townsfolk,
-- PR 460; Derek, 2026-11-25: the customers' "look/walk in" bothers him most). One loop for every customer, the same
-- way CatMotion moves the cats: the body is never moved here, so Gameplay (server or client) can move the whole
-- customer; every joint target comes from the body's current CFrame and the rest offsets taken when the customer
-- was first seen. Nothing here replicates.
--
-- The walk follows the body: its speed over the floor sets the swing (CustomerPose.walkAmount) and the cadence
-- (matched to the model's LegLength attribute so the feet do not slide). Standing, the head looks round and nods
-- now and then. The right arm carries the cat carrier, so it only sways a hint. Reduced motion holds the idle head;
-- the walk stays, since legs gliding without a step read worse.
--
-- A customer whose cat's heart bar (the HeartFill attribute) runs low taps a foot while standing (CustomerPose.mood).
--
-- The spa staff (CleanACat_NPC_Staff_*, same joints) walk the same way with both arms swinging, and while their
-- Washing attribute is true (Gameplay, workers #509) they stand and scrub (StaffPose.scrub, issue #528).
--
-- A helper carrying a cat on Gameplay's walk to the counter (helperFetch, the Fetch attributes read by server time)
-- holds it in both arms (StaffPose.carry). The builder (a model named "Builder" with Role "Builder", issue 891) moves
-- the same way, and while his Building attribute is true he hammers (StaffPose.hammer); his Hammer, held at his right
-- hand, follows that arm.
--
-- Budget: 30 updates a second near the camera, 15 past 30 studs, none past 60 (back to rest), at most MAX customers.
--
-- API
--   CustomerMotion.start(isOn)     isOn() is read once a second; when false every customer goes back to rest
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Comfort = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Comfort"))
local CounterCrate = require(script.Parent:WaitForChild("CounterCrate"))
local CustomerPose = require(script.Parent:WaitForChild("CustomerPose"))
local HelperWash = require(script.Parent:WaitForChild("HelperWash"))
local StaffPose = require(script.Parent:WaitForChild("StaffPose"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HelperFetchRules = require(Shared:WaitForChild("HelperFetchRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local CustomerMotion = {}

-- Client only, for Studio checks (issue 1062), read on the client with execute_luau; nothing replicates. On each
-- customer RIG_ATTRIBUTE says how far attach got: "no body", "no joints" or "rig <joints>", written only on attach.
CustomerMotion.RIG_ATTRIBUTE = "MotionRig"

CustomerMotion.PREFIX = "CleanACat_NPC_Customer_"
CustomerMotion.STAFF_PREFIX = "CleanACat_NPC_Staff_"
CustomerMotion.BUILDER_NAME = "Builder" -- StationService's name for the human builder (issue 891)
CustomerMotion.BUILDER_ROLE = "Builder" -- his model's Role attribute
CustomerMotion.MAX = 10
CustomerMotion.NEAR = 30 -- studs: full rate inside
CustomerMotion.FAR = 60 -- studs: no motion past
CustomerMotion.STEP = 1 / 30

local LEG_LENGTH = 2.2 -- studs, when a model has no LegLength attribute

type Joint = { instance: PVInstance, rest: CFrame }

type Rig = {
	model: Model,
	body: BasePart,
	joints: { [string]: Joint },
	pose: CustomerPose.Pose,
	seed: number,
	legLength: number,
	last: Vector3,
	speed: number,
	amount: number,
	phase: number,
	updatedAt: number,
	appliedAt: CFrame, -- the body's CFrame when the pose was last written
	moved: boolean,
	staff: boolean,
	wash: number, -- the wash pose's blend, 0 to 1 (staff only)
	armIn: number, -- radians the carrying arm is turned back in from the server's CarryArmOut (empty hand)
	carry: number, -- the carry pose's blend, 0 to 1 (staff only)
	builder: boolean,
	hammer: number, -- the hammering pose's blend, 0 to 1 (builder only)
	tool: Joint?, -- the builder's Hammer, its rest in the right arm's frame
	carrier: Model?, -- the figure's Carrier (FigureService hangs it under the arm), looked up at most once a second
	carrierPart: BasePart?, -- one of its parts: CounterCrate hides the carrier by Transparency
	carrierAt: number, -- os.clock() of the last look for it
	helper: HelperWash.State?, -- (switch helperWash) the wash steps of a staff member at their stand
	sideL: number, -- radians the arms turn sideways, across the body (HelperWash); 0 otherwise
	sideR: number,
	near: boolean, -- within HelperWash.NEAR of the camera this frame
	lean: number, -- radians the torso leans forward at the hips (HelperWash, issue 1137); 0 otherwise
	leanWritten: number, -- the lean last written to the torso parts
	leaned: boolean, -- staff that have leaned at least once (only they are ever straightened by baseOf)
	torso: { { part: BasePart, offset: CFrame } }, -- staff: the torso's other parts, in the Body part's frame
	hip: CFrame, -- the lean's pivot in the Body part's frame: the bottom of the torso
	grips: { [string]: CFrame }, -- each hand's Grip in its arm's pivot frame, by arm key, found once
	noGrip: { [string]: boolean }, -- arms looked at that have no Grip
	reach: HelperWash.Reach?, -- staff: their forward reach for HelperWash's solve
}

-- A staff rig's forward reach (set below, used by the closure attach gives each staff rig).
local reachOf: (rig: Rig, lean: number, arm: number, side: number, left: boolean) -> CFrame?

-- Whether a helper is holding the cat on Gameplay's walk at server time `now` (HelperFetchRules.pose).
function CustomerMotion.holding(model: Model, now: number): boolean
	local from = model:GetAttribute(HelperFetchRules.FROM_ATTRIBUTE)
	local to = model:GetAttribute(HelperFetchRules.TO_ATTRIBUTE)
	local at = model:GetAttribute(HelperFetchRules.AT_ATTRIBUTE)
	local way = model:GetAttribute(HelperFetchRules.WAY_ATTRIBUTE)
	if
		typeof(from) ~= "Vector3"
		or typeof(to) ~= "Vector3"
		or type(at) ~= "number"
		or type(way) ~= "string"
	then
		return false
	end
	local pose = HelperFetchRules.pose(
		way :: string,
		from :: Vector3,
		to :: Vector3,
		now - (at :: number),
		HelperFetchRules.viaOf(model)
	)
	return pose.holding and not pose.done
end

-- Gameplay turns the carrying arm out by the figure's CarryArmOut degrees on the server so the carrier hangs clear of
-- the body (issues 871 and 874). The straight arm is the default (issue 1062, Derek on dev: an arm sticking out with
-- nothing in the hand): the arm stays turned out only while a carrier that shows hangs from the hand, or while the
-- reach that sets the crate down plays. Otherwise it turns back in by as much and the hand hangs straight. That covers
-- the carrier hidden (CounterCrate's CarrierHidden), none built or none come in yet, and customers too far away or
-- past MAX, which rest with the arm straight too. When the PackedCat shows for the leave, it turns out again.
function CustomerMotion.armIn(holding: boolean, outDegrees: unknown, reaching: boolean): number
	if holding or reaching or type(outDegrees) ~= "number" then
		return 0
	end
	return math.rad(outDegrees :: number)
end

-- Does a carrier that shows hang from the hand: a Carrier with a part drawn, and not hidden by CounterCrate.
function CustomerMotion.carrierShows(
	hidden: boolean,
	carrier: boolean,
	transparency: number?
): boolean
	return not hidden and carrier and transparency ~= nil and transparency < 1
end

function CustomerMotion.armInFor(model: Model, now: number, carrierPart: BasePart?): number
	local out = model:GetAttribute("CarryArmOut")
	if type(out) ~= "number" then
		return 0
	end
	local reachAt = model:GetAttribute(CounterCrate.REACH_ATTRIBUTE)
	local reaching = type(reachAt) == "number"
		and now - (reachAt :: number) < CounterCrate.REACH_SECONDS
	local part = if carrierPart and carrierPart.Parent then carrierPart else nil
	local holding = CustomerMotion.carrierShows(
		model:GetAttribute(CounterCrate.EMPTY_HAND_ATTRIBUTE) == true,
		part ~= nil,
		if part then part.Transparency else nil
	)
	return CustomerMotion.armIn(holding, out, reaching)
end

local rigs: { [Model]: Rig } = {}
local started = false
local enabled = false
local seedCount = 0

local function isStaff(name: string): boolean
	return string.sub(name, 1, #CustomerMotion.STAFF_PREFIX) == CustomerMotion.STAFF_PREFIX
end

local function isBuilder(instance: Instance): boolean
	return instance.Name == CustomerMotion.BUILDER_NAME
		and instance:GetAttribute("Role") == CustomerMotion.BUILDER_ROLE
end

-- Is `name` a customer's or staff member's own Model? Their joints carry the same prefix
-- ("CleanACat_NPC_Customer_Mo_ArmR"), so a name that ends in a joint is never one (issue 1062: with streaming, the
-- joint Models arrive after the figure and were taken for customers of their own, so the figure's rig was never built
-- and no customer walked or turned the empty hand back in).
function CustomerMotion.isRigName(name: string): boolean
	return (string.sub(name, 1, #CustomerMotion.PREFIX) == CustomerMotion.PREFIX or isStaff(name))
		and CustomerPose.jointKey(name) == nil
end

local function isCustomer(instance: Instance?): boolean
	return instance ~= nil
		and instance:IsA("Model")
		and (CustomerMotion.isRigName(instance.Name) or isBuilder(instance))
end

local function findBody(model: Model): BasePart?
	local primary = model.PrimaryPart
	if primary and CustomerPose.jointKey(primary.Name) == "Body" then
		return primary
	end
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and CustomerPose.jointKey(child.Name) == "Body" then
			return child :: BasePart
		end
	end
	return primary
end

local function attach(model: Model)
	if rigs[model] or not model:IsDescendantOf(Workspace) then
		return
	end
	local body = findBody(model)
	if body == nil then
		model:SetAttribute(CustomerMotion.RIG_ATTRIBUTE, "no body")
		return
	end
	local bodyCF = body.CFrame
	local joints: { [string]: Joint } = {}
	for _, child in model:GetChildren() do
		local key = CustomerPose.jointKey(child.Name)
		if key and key ~= "Body" and child:IsA("PVInstance") then
			local pv = child :: PVInstance
			joints[key] = { instance = pv, rest = bodyCF:ToObjectSpace(pv:GetPivot()) }
		end
	end
	if next(joints) == nil then
		model:SetAttribute(CustomerMotion.RIG_ATTRIBUTE, "no joints")
		return
	end
	local builder = isBuilder(model)
	local tool: Joint? = nil
	local hammer = if builder then model:FindFirstChild("Hammer") else nil
	local arm = joints.ArmR
	if hammer and hammer:IsA("PVInstance") and arm then
		local pv = hammer :: PVInstance
		tool = { instance = pv, rest = arm.rest:Inverse() * bodyCF:ToObjectSpace(pv:GetPivot()) }
	end
	local legLength = model:GetAttribute("LegLength")
	local staff = isStaff(model.Name) or builder
	local torso: { { part: BasePart, offset: CFrame } } = {}
	if staff then
		for _, child in model:GetChildren() do
			if
				child ~= (body :: Instance)
				and child:IsA("BasePart")
				and CustomerPose.jointKey(child.Name) == "Body"
			then
				local part = child :: BasePart
				table.insert(torso, { part = part, offset = bodyCF:ToObjectSpace(part.CFrame) })
			end
		end
	end
	seedCount += 1
	local x = math.sin(seedCount * 12.9898) * 43758.5453
	rigs[model] = {
		model = model,
		body = body,
		joints = joints,
		pose = CustomerPose.newPose(),
		seed = x - math.floor(x),
		legLength = if type(legLength) == "number" and legLength > 0 then legLength else LEG_LENGTH,
		last = body.Position,
		speed = 0,
		amount = 0,
		phase = 0,
		updatedAt = os.clock(),
		appliedAt = body.CFrame,
		moved = false,
		staff = staff,
		wash = 0,
		armIn = 0,
		carry = 0,
		builder = builder,
		hammer = 0,
		tool = tool,
		carrier = nil,
		carrierPart = nil,
		carrierAt = -math.huge,
		helper = nil,
		sideL = 0,
		sideR = 0,
		near = false,
		lean = 0,
		leanWritten = 0,
		leaned = false,
		torso = torso,
		hip = CFrame.new(0, -body.Size.Y / 2, 0),
		grips = {},
		noGrip = {},
		reach = nil,
	}
	local rig = rigs[model]
	if staff then
		rig.reach = function(lean: number, arm: number, side: number, left: boolean): CFrame?
			return reachOf(rig, lean, arm, side, left)
		end
	end
	local names = {}
	for key in joints do
		table.insert(names, key)
	end
	table.sort(names)
	model:SetAttribute(CustomerMotion.RIG_ATTRIBUTE, "rig " .. table.concat(names, " "))
end

-- The Body part's frame standing straight. Staff always stand upright, and the lean turns about the hip, which stays
-- put, so the upright frame comes back from the leaned one: the hip point and the facing, flattened. That also undoes a
-- lean a walk or a move copied from a leaned pivot (HelperFetchController takes the model's pivot as home).
local function baseOf(rig: Rig): CFrame
	local cf = rig.body.CFrame
	-- only a rig that has leaned is ever straightened: a figure built or placed a little off upright stays as it is
	if not rig.leaned or (rig.leanWritten == 0 and cf.UpVector.Y > 0.9995) then
		return cf
	end
	local hip = cf * rig.hip.Position
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		local up = cf.UpVector
		flat = Vector3.new(up.X, 0, up.Z) -- leaned past level: the top points the way they face
	end
	return CFrame.lookAt(hip, hip + flat.Unit) * rig.hip:Inverse()
end

-- The Body part's frame leaned `lean` forward (their -Z) about the hip.
local function leaned(rig: Rig, base: CFrame, lean: number): CFrame
	if lean == 0 then
		return base
	end
	return base * rig.hip * CFrame.Angles(-lean, 0, 0) * rig.hip:Inverse()
end

local torsoParts: { BasePart } = {}
local torsoFrames: { CFrame } = {}

-- Moves the Body part and the torso's other parts to `bodyCF` (staff only, and only when the lean changed or a move
-- straightened them), all in one BulkMoveTo.
local function writeTorso(rig: Rig, bodyCF: CFrame)
	if #rig.torso == 0 and not rig.staff then
		return
	end
	if rig.lean == 0 and rig.leanWritten == 0 and rig.body.CFrame == bodyCF then
		return
	end
	if rig.lean == rig.leanWritten and rig.body.CFrame == bodyCF then
		return
	end
	table.clear(torsoParts)
	table.clear(torsoFrames)
	table.insert(torsoParts, rig.body)
	table.insert(torsoFrames, bodyCF)
	for _, item in rig.torso do
		if item.part.Parent then
			table.insert(torsoParts, item.part)
			table.insert(torsoFrames, bodyCF * item.offset)
		end
	end
	Workspace:BulkMoveTo(torsoParts, torsoFrames, Enum.BulkMoveMode.FireCFrameChanged)
	rig.leanWritten = rig.lean
	if rig.lean ~= 0 then
		rig.leaned = true
	end
end

-- A hand's Grip in its arm's pivot frame (the arm is rigid, so once is enough); nil when the arm has none.
local function gripIn(rig: Rig, left: boolean): CFrame?
	local key = if left then "ArmL" else "ArmR"
	local found: CFrame? = rig.grips[key]
	if found == nil and not rig.noGrip[key] then
		local joint = rig.joints[key]
		local grip = if joint
			then joint.instance:FindFirstChild(if left then "GripL" else "Grip", true)
			else nil
		if joint and grip and grip:IsA("Attachment") then
			local made = joint.instance:GetPivot():ToObjectSpace((grip :: Attachment).WorldCFrame)
			rig.grips[key] = made
			found = made
		else
			rig.noGrip[key] = true
		end
	end
	return found
end

-- Where a hand's Grip would be with the waist leaned `lean` and that arm at `arm` and `side` (as apply turns it).
reachOf = function(rig: Rig, lean: number, arm: number, side: number, left: boolean): CFrame?
	local joint = rig.joints[if left then "ArmL" else "ArmR"]
	local inArm = gripIn(rig, left)
	if joint == nil or inArm == nil then
		return nil
	end
	local bodyCF = leaned(rig, baseOf(rig), lean)
	local rotation = if left
		then CFrame.Angles(0, -side, 0) * CFrame.Angles(arm, 0, 0)
		else CFrame.Angles(0, 0, -rig.armIn) * CFrame.Angles(0, side, 0) * CFrame.Angles(
			arm,
			0,
			0
		)
	return bodyCF * joint.rest * rotation * (inArm :: CFrame)
end

local function turn(rig: Rig, key: string, bodyCF: CFrame, rotation: CFrame)
	local joint = rig.joints[key]
	if joint and joint.instance.Parent then
		joint.instance:PivotTo(bodyCF * joint.rest * rotation)
	end
end

local function apply(rig: Rig, pose: CustomerPose.Pose)
	local base = baseOf(rig)
	local bodyCF = leaned(rig, base, rig.lean)
	writeTorso(rig, bodyCF)
	rig.appliedAt = rig.body.CFrame
	turn(rig, "LegL", base, CFrame.Angles(pose.legL, 0, 0))
	turn(rig, "LegR", base, CFrame.Angles(pose.legR, 0, 0))
	-- a sideways turn about the shoulder's Y moves a forward-reaching hand across the body (HelperWash's strokes)
	turn(rig, "ArmL", bodyCF, CFrame.Angles(0, -rig.sideL, 0) * CFrame.Angles(pose.armL, 0, 0))
	local armR = CFrame.Angles(0, 0, -rig.armIn)
		* CFrame.Angles(0, rig.sideR, 0)
		* CFrame.Angles(pose.armR, 0, 0)
	turn(rig, "ArmR", bodyCF, armR)
	local tool = rig.tool
	local arm = rig.joints.ArmR
	if tool and arm and tool.instance.Parent then
		tool.instance:PivotTo(bodyCF * arm.rest * armR * tool.rest)
	end
	turn(
		rig,
		"Head",
		bodyCF,
		CFrame.Angles(0, pose.headYaw, 0) * CFrame.Angles(-pose.headPitch, 0, 0)
	)
end

local restPose = CustomerPose.newPose()

local CARRIER_LOOK_SECONDS = 1

-- The figure's carrier part, found again at most once a second while there is none (it can be built or stream in
-- after the figure), so no model walk runs every frame (issue 821).
local function carrierPartOf(rig: Rig, clock: number): BasePart?
	local carrier = rig.carrier
	if carrier == nil or not carrier:IsDescendantOf(rig.model) then
		rig.carrier = nil
		rig.carrierPart = nil
		if clock - rig.carrierAt < CARRIER_LOOK_SECONDS then
			return nil
		end
		rig.carrierAt = clock
		local found = rig.model:FindFirstChild("Carrier", true)
		if found == nil or not found:IsA("Model") then
			return nil
		end
		carrier = found :: Model
		rig.carrier = carrier
	end
	local part = rig.carrierPart
	if part == nil or not part:IsDescendantOf(carrier :: Model) then
		local model = carrier :: Model
		local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		part = if primary and primary:IsA("BasePart") then primary :: BasePart else nil
		rig.carrierPart = part
	end
	return part
end

-- Back to rest: the pose at rest, with the carrying arm straight unless a carrier shows in the hand (issue 1062), so a
-- far or unanimated customer never keeps the server's turned-out arm with nothing in it. Written again only when
-- something changed or a move put the joints back at the server's rest.
local function stopHelper(rig: Rig)
	local helper = rig.helper
	if helper then
		rig.helper = nil
		HelperWash.stop(helper)
	end
	rig.sideL = 0
	rig.sideR = 0
	rig.lean = 0
end

local function toRest(rig: Rig)
	stopHelper(rig)
	if rig.body.Parent == nil then
		rig.moved = false
		return
	end
	local want = CustomerMotion.armInFor(rig.model, os.clock(), carrierPartOf(rig, os.clock()))
	if
		rig.moved
		or want ~= rig.armIn
		or rig.leanWritten ~= 0
		or (want ~= 0 and rig.body.CFrame ~= rig.appliedAt)
	then
		rig.armIn = want
		apply(rig, restPose)
	end
	rig.moved = false
end

local function update(rig: Rig, now: number)
	local dt = math.min(now - rig.updatedAt, 0.25)
	rig.updatedAt = now
	-- the hip, which a lean leaves in place, so leaning over the tub never reads as a step
	local position = rig.body.CFrame * rig.hip.Position
	local moved = Vector3.new(position.X - rig.last.X, 0, position.Z - rig.last.Z).Magnitude
	rig.last = position
	if moved > 20 then
		moved = 0 -- a teleport (a new spot in the queue), not a walk
	end
	-- the server's moves arrive in steps, so the speed is smoothed before it drives the legs
	local raw = if dt > 0 then moved / dt else 0
	rig.speed = CustomerPose.approach(rig.speed, raw, 6, dt)
	rig.amount = CustomerPose.approach(rig.amount, CustomerPose.walkAmount(rig.speed), 8, dt)
	local cadence = CustomerPose.cadence(
		math.max(rig.speed, CustomerPose.WALK_FULL * 0.6),
		rig.legLength,
		CustomerPose.LEG_SWING
	)
	if rig.amount > 0.01 then
		rig.phase = (rig.phase + cadence * dt) % 1
	else
		rig.phase = 0
	end
	local still = Comfort.reducedMotion()
	local pitch, yaw = CustomerPose.idle(now, rig.seed, still)
	CustomerPose.sample(rig.pose, rig.phase, rig.amount, pitch, yaw)
	-- the cat's heart bar, set by Gameplay on the customer (issue #528)
	local fill = rig.model:GetAttribute("HeartFill")
	if type(fill) == "number" then
		CustomerPose.mood(rig.pose, fill, now, rig.seed, 1 - rig.amount, still)
	end
	if rig.staff then
		StaffPose.freeArms(rig.pose)
		local washing = rig.model:GetAttribute("Washing") == true
		rig.wash = CustomerPose.approach(rig.wash, if washing then 1 else 0, StaffPose.BLEND, dt)
		local amount = rig.wash * (1 - rig.amount)
		local sideL, sideR, lean = nil, nil, nil
		local reach = rig.reach
		if washing and reach and HelperWash.on() then
			local helper = rig.helper or HelperWash.new()
			rig.helper = helper
			sideL, sideR, lean = HelperWash.pose(
				helper,
				rig.model,
				rig.pose,
				now,
				rig.seed,
				amount,
				still,
				dt,
				reach
			)
		end
		if sideL == nil or sideR == nil or lean == nil then
			-- no step to show (switch off, no cat in the stand, or the wash just ended): the plain rub
			stopHelper(rig)
			StaffPose.scrub(rig.pose, now, rig.seed, amount, still)
		else
			rig.sideL = sideL
			rig.sideR = sideR
			rig.lean = lean
		end
		local carrying = LiveFlags.isOn(HelperFetchRules.FLAG)
			and CustomerMotion.holding(rig.model, Workspace:GetServerTimeNow())
		rig.carry = CustomerPose.approach(rig.carry, if carrying then 1 else 0, StaffPose.BLEND, dt)
		StaffPose.carry(rig.pose, rig.carry)
	end
	if rig.builder then
		local building = rig.model:GetAttribute("Building") == true
		rig.hammer =
			CustomerPose.approach(rig.hammer, if building then 1 else 0, StaffPose.BLEND, dt)
		StaffPose.hammer(rig.pose, now, rig.seed, rig.hammer * (1 - rig.amount), still)
	end
	-- a customer setting their cat's crate down on the counter reaches the carrying arm forward (issue #757)
	local reachAt = rig.model:GetAttribute(CounterCrate.REACH_ATTRIBUTE)
	if type(reachAt) == "number" and not still then
		rig.pose.armR += CounterCrate.reachAt(now - reachAt)
	end
	rig.armIn = CustomerPose.approach(
		rig.armIn,
		CustomerMotion.armInFor(rig.model, now, carrierPartOf(rig, os.clock())),
		8,
		dt
	)
	apply(rig, rig.pose)
	local helper = rig.helper
	if helper then
		HelperWash.place(helper, rig.model, rig.near, now, Comfort.lessSparkle())
	end
	rig.moved = true
end

local function step()
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local from = camera.CFrame.Position
	local now = os.clock()
	local budget = CustomerMotion.MAX
	for model, rig in rigs do
		if model.Parent == nil or rig.body.Parent == nil then
			stopHelper(rig) -- the tool and water are client-only copies in Workspace: they go with the helper
			rigs[model] = nil
			continue
		end
		if not enabled then
			toRest(rig)
			continue
		end
		local distance = (rig.body.Position - from).Magnitude
		if distance > CustomerMotion.FAR or budget <= 0 then
			toRest(rig)
			rig.last = rig.body.CFrame * rig.hip.Position
			rig.updatedAt = now
			continue
		end
		budget -= 1
		rig.near = distance <= HelperWash.NEAR
		local interval = if distance > CustomerMotion.NEAR
			then CustomerMotion.STEP * 2
			else CustomerMotion.STEP
		if now - rig.updatedAt >= interval then
			update(rig, now)
		elseif rig.moved and rig.body.CFrame ~= rig.appliedAt then
			-- the body moved since the last write (a replicated server move also puts every joint back at rest), so
			-- the same pose is written again this frame: no stutter between 30 Hz updates (Review-QA on #462)
			apply(rig, rig.pose)
			local helper = rig.helper
			if helper then
				HelperWash.place(helper, rig.model, rig.near, now, Comfort.lessSparkle())
			end
		end
	end
end

-- Runs fn() with `model`'s joints back at the server's rest: no swing, and the carrying arm as FigureService turned it
-- out. Then it puts this frame's pose back. CustomerLeave clones the figure inside it, so the walk-off copy's rig takes
-- the true rest (Sync on 1082, issue 1062: a copy cloned with the arm turned in walked off with it turned in).
-- A carrying helper's arms for StaffCarry (issue 1138): the Body part's upright frame, and in that frame each arm's
-- shoulder (its pivot) and hand (its Grip) as this frame's pose holds them: { shoulderL, handL, shoulderR, handR }.
-- nil when `model` is no staff rig here or an arm has no Grip.
function CustomerMotion.carryArms(model: Model): (CFrame?, { Vector3 }?)
	local rig = rigs[model]
	if rig == nil or not rig.staff or rig.body.Parent == nil then
		return nil, nil
	end
	local base = baseOf(rig)
	local out: { Vector3 } = {}
	for _, left in { true, false } do
		local joint = rig.joints[if left then "ArmL" else "ArmR"]
		local grip = reachOf(rig, 0, if left then rig.pose.armL else rig.pose.armR, 0, left)
		if joint == nil or grip == nil then
			return nil, nil
		end
		local shoulder: Vector3 = (joint :: Joint).rest.Position
		local hand: Vector3 = base:PointToObjectSpace((grip :: CFrame).Position)
		table.insert(out, shoulder)
		table.insert(out, hand)
	end
	return base, out
end

function CustomerMotion.atRest(model: Model, fn: () -> ())
	local rig = rigs[model]
	if rig == nil or rig.body.Parent == nil then
		fn()
		return
	end
	local armIn = rig.armIn
	rig.armIn = 0
	apply(rig, restPose)
	fn() -- the caller keeps it from erroring (CustomerLeave clones inside its own pcall)
	rig.armIn = armIn
	apply(rig, rig.pose)
end

-- With streaming on, a customer's joints can arrive after the Model; a late one rebuilds the rig from rest.
local function consider(instance: Instance)
	if isCustomer(instance) then
		attach(instance :: Model)
		return
	end
	local parent = instance.Parent
	if not isCustomer(parent) then
		return
	end
	local model = parent :: Model
	local key = CustomerPose.jointKey(instance.Name)
	if key == nil then
		return
	end
	local rig = rigs[model]
	if rig and (key == "Body" or rig.joints[key] == nil) then
		toRest(rig)
		rigs[model] = nil
	end
	attach(model)
end

function CustomerMotion.start(isOn: () -> boolean)
	if started then
		return
	end
	started = true
	enabled = isOn()
	for _, instance in Workspace:GetDescendants() do
		consider(instance)
	end
	Workspace.DescendantAdded:Connect(consider)
	local checkAt = 0
	-- PreRender: after this frame's replicated moves land and before the frame draws, so a server move never shows
	-- a customer at rest for a frame
	RunService.PreRender:Connect(function()
		local now = os.clock()
		if now >= checkAt then
			checkAt = now + 1
			local ok, on = pcall(isOn)
			enabled = ok and on == true
		end
		step()
	end)
end

return CustomerMotion
