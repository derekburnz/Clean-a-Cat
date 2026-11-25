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
-- Budget: 30 updates a second near the camera, 15 past 30 studs, none past 60 (back to rest), at most MAX customers.
--
-- API
--   CustomerMotion.start(isOn)     isOn() is read once a second; when false every customer goes back to rest
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Comfort = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Comfort"))
local CustomerPose = require(script.Parent:WaitForChild("CustomerPose"))

local CustomerMotion = {}

CustomerMotion.PREFIX = "CleanACat_NPC_Customer_"
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
	moved: boolean,
}

local rigs: { [Model]: Rig } = {}
local started = false
local enabled = false
local seedCount = 0

local function isCustomer(instance: Instance?): boolean
	return instance ~= nil
		and instance:IsA("Model")
		and string.sub(instance.Name, 1, #CustomerMotion.PREFIX) == CustomerMotion.PREFIX
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
		return
	end
	local legLength = model:GetAttribute("LegLength")
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
		moved = false,
	}
end

local function turn(rig: Rig, key: string, bodyCF: CFrame, rotation: CFrame)
	local joint = rig.joints[key]
	if joint and joint.instance.Parent then
		joint.instance:PivotTo(bodyCF * joint.rest * rotation)
	end
end

local function apply(rig: Rig, pose: CustomerPose.Pose)
	local bodyCF = rig.body.CFrame
	turn(rig, "LegL", bodyCF, CFrame.Angles(pose.legL, 0, 0))
	turn(rig, "LegR", bodyCF, CFrame.Angles(pose.legR, 0, 0))
	turn(rig, "ArmL", bodyCF, CFrame.Angles(pose.armL, 0, 0))
	turn(rig, "ArmR", bodyCF, CFrame.Angles(pose.armR, 0, 0))
	turn(
		rig,
		"Head",
		bodyCF,
		CFrame.Angles(0, pose.headYaw, 0) * CFrame.Angles(-pose.headPitch, 0, 0)
	)
end

local restPose = CustomerPose.newPose()

local function toRest(rig: Rig)
	if rig.moved and rig.body.Parent then
		apply(rig, restPose)
	end
	rig.moved = false
end

local function update(rig: Rig, now: number)
	local dt = math.min(now - rig.updatedAt, 0.25)
	rig.updatedAt = now
	local position = rig.body.Position
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
	local pitch, yaw = CustomerPose.idle(now, rig.seed, Comfort.reducedMotion())
	CustomerPose.sample(rig.pose, rig.phase, rig.amount, pitch, yaw)
	apply(rig, rig.pose)
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
			rig.last = rig.body.Position
			rig.updatedAt = now
			continue
		end
		budget -= 1
		local interval = if distance > CustomerMotion.NEAR
			then CustomerMotion.STEP * 2
			else CustomerMotion.STEP
		if now - rig.updatedAt >= interval then
			update(rig, now)
		end
	end
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
	RunService.PreSimulation:Connect(function()
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
