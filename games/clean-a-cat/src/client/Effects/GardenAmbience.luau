--!strict
-- GardenAmbience: the built Garden feels alive (Model-Agent's CleanACat_Area_Garden, PR 674; build #515). Calm and
-- cosy, nothing that asks for attention:
--
--   petals   a few soft pink petals drift down from the blossom tree (child Model ending _Canopy), turning slowly
--            as they fall and fading before they reach the grass
--   breathe  each of the tree's blossom clouds rises and settles a hint (BREATHE studs) out of step with the others,
--            as if in a light breeze
--   comfort  Reduced Motion: no petals and the clouds stay still. Less sparkle: half the petals
--
-- Client only and cosmetic. Phone budget: one ParticleEmitter per built garden at PETAL_RATE (low tier) and a few
-- part moves at 15 Hz, both only while the garden is within NEAR studs of the camera; past that the clouds are put
-- back exactly and the petals stop. A garden is the plot's built area: a Model with Built = true and a _Canopy child.
--
-- API
--   GardenAmbience.start()                     watches the gardens in Workspace
--   GardenAmbience.breatheAt(t, seed) -> number   pure: a cloud's lift in studs at `t` seconds
--   GardenAmbience.petalRate(tier, less) -> number   pure: petals a second
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent)

local GardenAmbience = {}

GardenAmbience.BREATHE = 0.06 -- studs
GardenAmbience.BREATHE_SECONDS = 4.2
GardenAmbience.NEAR = 50
GardenAmbience.STEP = 1 / 15
GardenAmbience.PETAL_RATE = table.freeze({ low = 1, high = 2 })
local PETAL = Color3.fromRGB(255, 196, 214)
local PETAL_DEEP = Color3.fromRGB(242, 150, 180)

function GardenAmbience.breatheAt(t: number, seed: number): number
	return GardenAmbience.BREATHE
		* math.sin(2 * math.pi * (t / GardenAmbience.BREATHE_SECONDS + seed))
end

function GardenAmbience.petalRate(tier: string, less: boolean): number
	local rate = if tier == "high"
		then GardenAmbience.PETAL_RATE.high
		else GardenAmbience.PETAL_RATE.low
	return if less then rate / 2 else rate
end

type Cloud = { part: BasePart, rest: CFrame, seed: number }
type Garden = {
	model: Model,
	clouds: { Cloud },
	emitter: ParticleEmitter?,
	moved: boolean,
}

local gardens: { [Model]: Garden } = {}
local stepping: RBXScriptConnection? = nil
local lastStep = 0

local function canopyOf(model: Model): Model?
	for _, child in model:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, -#"_Canopy") == "_Canopy" then
			return child :: Model
		end
	end
	return nil
end

local function makeEmitter(parent: BasePart): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "CleanACat_Fx_Petals"
	e.Texture = "" -- Roblox's soft dot, as every preset
	e.Color = ColorSequence.new(PETAL, PETAL_DEEP)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.14),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.15),
		NumberSequenceKeypoint.new(0.75, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(3.5, 5)
	e.Speed = NumberRange.new(0.2, 0.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0.15, -0.55, 0.05)
	e.Drag = 0.6
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Rate = 0
	e.Enabled = false
	e.Parent = parent
	return e
end

local function rest(garden: Garden)
	if garden.moved then
		for _, cloud in garden.clouds do
			if cloud.part.Parent then
				cloud.part.CFrame = cloud.rest
			end
		end
		garden.moved = false
	end
	local e = garden.emitter
	if e and e.Enabled then
		e.Enabled = false
	end
end

local function step()
	local now = os.clock()
	if now - lastStep < GardenAmbience.STEP then
		return
	end
	lastStep = now
	local camera = Workspace.CurrentCamera
	local from = if camera then camera.CFrame.Position else nil
	local still = Effects.reducedMotion()
	local rate = GardenAmbience.petalRate(Effects.tier(), Effects.lessSparkle())
	for model, garden in gardens do
		if model.Parent == nil then
			gardens[model] = nil
			continue
		end
		local first = garden.clouds[1]
		local where = if first then first.rest.Position else model:GetPivot().Position
		local near = from == nil or (where - from).Magnitude <= GardenAmbience.NEAR
		if not near or still then
			rest(garden)
			continue
		end
		for _, cloud in garden.clouds do
			if cloud.part.Parent then
				cloud.part.CFrame = cloud.rest
					+ Vector3.new(0, GardenAmbience.breatheAt(now, cloud.seed), 0)
			end
		end
		garden.moved = true
		local e = garden.emitter
		if e then
			if e.Rate ~= rate then
				e.Rate = rate
			end
			if not e.Enabled then
				e.Enabled = true
			end
		end
	end
	if next(gardens) == nil and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

local function watch(instance: Instance)
	if not instance:IsA("Model") or gardens[instance :: Model] then
		return
	end
	local model = instance :: Model
	if model:GetAttribute("Built") ~= true then
		return
	end
	local canopy = canopyOf(model)
	if canopy == nil then
		return
	end
	local clouds: { Cloud } = {}
	local biggest: BasePart? = nil
	for index, d in (canopy :: Model):GetChildren() do
		if d:IsA("BasePart") then
			local part = d :: BasePart
			table.insert(clouds, { part = part, rest = part.CFrame, seed = (index * 0.37) % 1 })
			local best = biggest
			if best == nil or part.Size.Magnitude > best.Size.Magnitude then
				biggest = part
			end
		end
	end
	if #clouds == 0 then
		return
	end
	local garden: Garden = {
		model = model,
		clouds = clouds,
		emitter = if biggest then makeEmitter(biggest) else nil,
		moved = false,
	}
	gardens[model] = garden
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			rest(garden)
			gardens[model] = nil
		end
	end)
	if stepping == nil then
		stepping = RunService.Heartbeat:Connect(step)
	end
end

local started = false
function GardenAmbience.start()
	if started then
		return
	end
	started = true
	for _, d in Workspace:GetDescendants() do
		watch(d)
	end
	Workspace.DescendantAdded:Connect(function(d)
		-- the garden's parts arrive after its Model with streaming, so look again a moment later
		if d:IsA("Model") then
			task.defer(watch, d)
		end
	end)
end

return GardenAmbience
