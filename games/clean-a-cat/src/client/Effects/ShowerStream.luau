--!strict
-- ShowerStream: a thin line of water from the shower's nozzle into the fur while rinsing (issue 899, with
-- Gameplay-Engineer's switch showerAim; Derek: "make the rinsing actually show water better and point the right
-- direction"). EffectsController calls it on each RinseSpray while showerAim is on, with the nozzle from
-- ToolOnCat.nozzle(); the showerStream drops fly along it and the rinseSpray splash stays small at the point.
--
-- The line is a Beam between two Attachments on Terrain: pale blue, a little see-through, a touch thicker at the
-- fur where the water spreads, with a gentle wobble in its width so it reads as running water, not a rod. It hides
-- HOLD seconds after the last call. Less sparkle keeps it (it is the water, not a sparkle).
--
--   ShowerStream.show(from, to)   the line from world point `from` (the nozzle) to `to` (where it meets the fur)
--   ShowerStream.hide()
--   ShowerStream.width(t) -> (number, number)   pure: the line's width at the nozzle and at the fur at t seconds
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ShowerStream = {}

ShowerStream.WIDTH0 = 0.09 -- studs at the nozzle
ShowerStream.WIDTH1 = 0.16 -- studs at the fur
ShowerStream.WOBBLE = 0.15 -- share of the width
ShowerStream.WOBBLE_HZ = 9
ShowerStream.HOLD = 0.15 -- seconds after the last show
ShowerStream.COLOR = Color3.fromRGB(190, 225, 255)

function ShowerStream.width(t: number): (number, number)
	local k = 1 + ShowerStream.WOBBLE * math.sin(t * math.pi * 2 * ShowerStream.WOBBLE_HZ)
	return ShowerStream.WIDTH0 * k, ShowerStream.WIDTH1 * k
end

type Line = { a: Attachment, b: Attachment, beam: Beam }

local line: Line? = nil
local shownAt = 0
local stepping: RBXScriptConnection? = nil

local function make(): Line
	local a = Instance.new("Attachment")
	a.Name = "CleanACat_Fx_ShowerFrom"
	local b = Instance.new("Attachment")
	b.Name = "CleanACat_Fx_ShowerTo"
	local beam = Instance.new("Beam")
	beam.Name = "CleanACat_Fx_ShowerStream"
	beam.Attachment0 = a
	beam.Attachment1 = b
	beam.Color = ColorSequence.new(ShowerStream.COLOR, Color3.new(1, 1, 1))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.8, 0.2),
		NumberSequenceKeypoint.new(1, 0.45),
	})
	beam.LightEmission = 0.25
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Width0 = ShowerStream.WIDTH0
	beam.Width1 = ShowerStream.WIDTH1
	beam.Enabled = false
	a.Parent = Workspace.Terrain
	b.Parent = Workspace.Terrain
	beam.Parent = a
	return { a = a, b = b, beam = beam }
end

local function current(): Line
	local l = line
	if l and l.a.Parent and l.b.Parent and l.beam.Parent then
		return l
	end
	if l then
		l.a:Destroy()
		l.b:Destroy()
	end
	local made = make()
	line = made
	return made
end

function ShowerStream.hide()
	local l = line
	if l then
		l.beam.Enabled = false
	end
	if stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

function ShowerStream.show(from: Vector3, to: Vector3)
	local l = current()
	l.a.WorldPosition = from
	l.b.WorldPosition = to
	l.beam.Enabled = true
	shownAt = os.clock()
	if stepping == nil then
		local began = shownAt
		stepping = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			if now - shownAt > ShowerStream.HOLD then
				ShowerStream.hide()
				return
			end
			local w0, w1 = ShowerStream.width(now - began)
			l.beam.Width0 = w0
			l.beam.Width1 = w1
		end)
	end
end

return ShowerStream
