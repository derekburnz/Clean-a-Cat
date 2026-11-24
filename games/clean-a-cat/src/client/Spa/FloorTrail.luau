--!strict
-- FloorTrail: the tutorial's floor trail, from Design-Agent's tutorial.html step 1. Green arrows on the floor flow
-- from the player's feet to a spot (the next customer, for example), a green ring marks the spot and a gold arrow
-- bobs over it. Behind the live switch tutorialTrail, off by default (rule 16: every first-session change ships
-- behind its own switch). Client only and cosmetic: the parts never collide, catch a ray or touch anything.
--
--   FloorTrail.show(spot)   points the way to `spot` (a world position) until hidden
--   FloorTrail.hide()
--   FloorTrail.isShown()
--
-- It follows the player as they walk and never moves them. With reduced motion (Roblox's setting or the comfort
-- toggles) the arrows and the gold arrow hold still. Which step shows it, and when, is the first session's call
-- (issue #5), so nothing here starts it by itself. TrailRules holds the maths.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local TrailRules = require(Shared:WaitForChild("TrailRules"))

local Comfort = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Comfort"))
local Icons =
	require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HUD"):WaitForChild("Icons"))

local FloorTrail = {}

FloorTrail.FLAG = "tutorialTrail"

local GREEN = Color3.fromHex("63E87F")
local FLOW = 0.22 * 4 -- spacings a second the arrows flow (the draft's speed, in our spacing)
local ARM = Vector3.new(0.35, 0.08, 1.3) -- one arm of an arrow: width, height, length (studs)
local ARM_ANGLE = math.rad(40)
local RING = 4 -- studs across
local ARROW_HEIGHT = 7 -- studs over the spot
local BOB = 0.5 -- studs
local SOLID = 0.15 -- transparency of a fully shown arrow

type Arrow = { left: Part, right: Part }

local folder: Folder? = nil
local arrows: { Arrow } = {}
local ring: Part? = nil
local marker: BillboardGui? = nil
local spot: Vector3? = nil
local phase = 0
local clock = 0
local stepping: RBXScriptConnection? = nil

local function part(name: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = GREEN
	p.Parent = parent
	return p
end

-- The floor under the player: a short ray down from the root part, past the character and the trail itself. With no
-- floor in reach (a jump), the feet: an R15 body stands HipHeight below its root part, an R6 one on two-stud legs
-- (its HipHeight is 0). Review-QA on #260.
local DOWN = Vector3.new(0, -12, 0)
local R6_LEGS = 2

local function feet(): (Vector3?, number)
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local found = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local humanoid: Humanoid? = if found then found :: Humanoid else nil
	if character == nil or root == nil or not root:IsA("BasePart") then
		return nil, 0
	end
	local rootPart = root :: BasePart
	local skip: { Instance } = { character }
	local f = folder
	if f then
		table.insert(skip, f)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	local hit = Workspace:Raycast(rootPart.Position, DOWN, params)
	if hit then
		return rootPart.Position, hit.Position.Y + 0.05
	end
	local legs = if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15
		then humanoid.HipHeight
		else R6_LEGS
	return rootPart.Position, rootPart.Position.Y - rootPart.Size.Y / 2 - legs + 0.05
end

local function draw(dt: number)
	local target, f = spot, folder
	if target == nil or f == nil then
		return
	end
	local still = Comfort.reducedMotion()
	if not still then
		phase = (phase + dt * FLOW) % 1
		clock += dt
	end
	local from, floorY = feet()
	local marks = if from
		then TrailRules.marks(from, target, floorY, if still then 0.5 else phase)
		else {}
	for index = 1, TrailRules.MAX_MARKS do
		local arrow = arrows[index]
		if arrow == nil then
			arrow = { left = part("Left", f), right = part("Right", f) }
			arrow.left.Size, arrow.right.Size = ARM, ARM
			arrows[index] = arrow
		end
		local mark = marks[index]
		if mark == nil then
			arrow.left.Transparency, arrow.right.Transparency = 1, 1
		else
			local seen = SOLID + (1 - SOLID) * mark.fade
			arrow.left.Transparency, arrow.right.Transparency = seen, seen
			-- two arms meeting at the tip, like a ">" lying on the floor pointing the way
			local facing = CFrame.lookAt(mark.position, mark.position + mark.direction)
			local tip = facing * CFrame.new(0, ARM.Y / 2, -ARM.Z / 2)
			arrow.left.CFrame = tip * CFrame.Angles(0, ARM_ANGLE, 0) * CFrame.new(0, 0, ARM.Z / 2)
			arrow.right.CFrame = tip * CFrame.Angles(0, -ARM_ANGLE, 0) * CFrame.new(0, 0, ARM.Z / 2)
		end
	end
	local r = ring
	if r then
		r.CFrame = CFrame.new(target.X, floorY + 0.05, target.Z) * CFrame.Angles(0, 0, math.rad(90))
		r.Transparency = if still
			then 0.55
			else 0.55 + 0.2 * (0.5 + 0.5 * math.sin(clock * 2 * math.pi / 2.2))
	end
	local m = marker
	if m then
		local bob = if still then 0 else BOB * math.abs(math.sin(clock * math.pi / 0.55))
		m.StudsOffsetWorldSpace = Vector3.new(0, ARROW_HEIGHT + bob, 0)
	end
end

function FloorTrail.isShown(): boolean
	return spot ~= nil
end

function FloorTrail.hide()
	spot = nil
	local connection = stepping
	if connection then
		connection:Disconnect()
		stepping = nil
	end
	local f = folder
	if f then
		f:Destroy()
	end
	folder, ring, marker, arrows = nil, nil, nil, {}
end

function FloorTrail.show(target: Vector3)
	FloorTrail.hide()
	if not LiveFlags.isOn(FloorTrail.FLAG) then
		return
	end
	spot = target
	local f = Instance.new("Folder")
	f.Name = "PH_TutorialTrail"
	local r = part("Ring", f)
	r.Shape = Enum.PartType.Cylinder
	r.Size = Vector3.new(0.1, RING, RING)
	local anchor = part("ArrowAnchor", f)
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(target)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Arrow"
	gui.Adornee = anchor
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(72, 72)
	gui.LightInfluence = 0
	gui.Parent = anchor
	local box = Instance.new("Frame")
	box.Name = "IconBox"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.Rotation = -90 -- the left-pointing arrow turned to point down at the spot
	box.Parent = gui
	Icons.draw("Pointer", box)
	f.Parent = Workspace
	folder, ring, marker = f, r, gui
	phase, clock = 0, 0
	stepping = RunService.RenderStepped:Connect(draw)
	draw(0)
end

ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FloorTrail.FLAG)
	:Connect(function()
		if not LiveFlags.isOn(FloorTrail.FLAG) then
			FloorTrail.hide()
		end
	end)

return FloorTrail
