--!strict
-- VisitorArrival: a special visitor walks in (Moments.VisitorArrived, issue #528). It has to read as special without
-- stopping play: nothing freezes, no camera move, no screen cover.
--
--   glow      a soft warm gold outline fades in over GLOW_IN, holds, and fades out by GLOW_SECONDS
--   sparkles  three small gold bursts at the visitor's feet, one on each SPARKLE_BEATS
--   star      the HUD's Star icon floats over the visitor's head for as long as they are in the spa,
--             bobbing STAR_BOB studs and turning a little, so the player can find them in the line at a glance
--   comfort   Reduced Motion: the glow just appears and fades, the star sits still. Less sparkle: one burst.
--
-- Client only and cosmetic. Phone budget: one Highlight (inside Effects' Highlight budget; none when it is full),
-- one BillboardGui with the HUD Star image (already uploaded to the group), a few burst particles. The star's loop steps only while it is within
-- STAR_FAR studs of the camera and lets go when the visitor leaves.
--
-- API
--   VisitorArrival.arrive(visitor)   plays it; a second call for the same visitor does nothing
--   VisitorArrival.glowAt(t) -> number           pure: the outline's see-through (0 to 1) at `t` seconds
--   VisitorArrival.star(t, seed) -> (lift, degrees, scale)   pure: the star's bob at `t` seconds
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent)
local Icons =
	require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HUD"):WaitForChild("Icons"))

local VisitorArrival = {}

VisitorArrival.GLOW_IN = 0.4
VisitorArrival.GLOW_HOLD = 1.2
VisitorArrival.GLOW_SECONDS = 2.6 -- all gone by then
VisitorArrival.GLOW_SEEN = 0.25 -- the outline's see-through at its strongest
VisitorArrival.SPARKLE_BEATS = table.freeze({ 0, 0.3, 0.6 })
VisitorArrival.STAR_SIZE = 1.1 -- studs
VisitorArrival.STAR_OVER = 1.0 -- studs over the top of the visitor
VisitorArrival.STAR_BOB = 0.18 -- studs each way
VisitorArrival.STAR_PERIOD = 2.2 -- seconds per bob
VisitorArrival.STAR_TURN = 12 -- degrees each way
VisitorArrival.STAR_FAR = 60 -- studs: the star is hidden and still past this
local GOLD = Color3.fromRGB(255, 214, 120)
local GOLD_LIGHT = Color3.fromRGB(255, 240, 196)

function VisitorArrival.glowAt(t: number): number
	local seen = VisitorArrival.GLOW_SEEN
	if t <= 0 then
		return 1
	end
	local fadeFrom = VisitorArrival.GLOW_IN + VisitorArrival.GLOW_HOLD
	if t < VisitorArrival.GLOW_IN then
		local u = t / VisitorArrival.GLOW_IN
		return 1 - (1 - seen) * (1 - (1 - u) * (1 - u))
	elseif t < fadeFrom then
		return seen
	elseif t < VisitorArrival.GLOW_SECONDS then
		local u = (t - fadeFrom) / (VisitorArrival.GLOW_SECONDS - fadeFrom)
		return seen + (1 - seen) * u * u
	end
	return 1
end

function VisitorArrival.star(t: number, seed: number): (number, number, number)
	local w = 2 * math.pi / VisitorArrival.STAR_PERIOD
	local phase = seed * 2 * math.pi
	local lift = VisitorArrival.STAR_BOB * math.sin(w * t + phase)
	local degrees = VisitorArrival.STAR_TURN * math.sin(w * 0.5 * t + phase)
	local scale = 1 + 0.06 * math.sin(w * 2 * t + phase)
	return lift, degrees, scale
end

local playing: { [Model]: boolean } = {}
local seedCount = 0

local function makeStar(adornee: BasePart, over: number): (BillboardGui, ImageLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CleanACat_Fx_VisitorStar"
	gui.Size = UDim2.fromScale(VisitorArrival.STAR_SIZE, VisitorArrival.STAR_SIZE)
	gui.StudsOffsetWorldSpace = Vector3.new(0, over, 0)
	gui.MaxDistance = VisitorArrival.STAR_FAR
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.Adornee = adornee
	-- the HUD's own Star icon (Review-QA on #547: crossed bars read as a plus sign)
	local star = Instance.new("ImageLabel")
	star.Name = "Star"
	star.BackgroundTransparency = 1
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.Position = UDim2.fromScale(0.5, 0.5)
	star.Size = UDim2.fromScale(1, 1)
	star.ScaleType = Enum.ScaleType.Fit
	star.Image = Icons.IMAGES.Star
	star.Parent = gui
	gui.Parent = adornee
	return gui, star
end

local function glow(visitor: Model)
	local highlight = Effects.highlight(visitor, GOLD_LIGHT, GOLD)
	if highlight == nil then
		return
	end
	local h = highlight :: Highlight
	if Effects.reducedMotion() then
		h.OutlineTransparency = VisitorArrival.GLOW_SEEN
		h.FillTransparency = 1
		task.delay(VisitorArrival.GLOW_SECONDS, function()
			h:Destroy()
		end)
		return
	end
	local start = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t >= VisitorArrival.GLOW_SECONDS or h.Parent == nil then
			if connection then
				connection:Disconnect()
			end
			h:Destroy()
			return
		end
		local seen = VisitorArrival.glowAt(t)
		h.OutlineTransparency = seen
		h.FillTransparency = 0.85 + 0.15 * seen -- the faintest warm wash, never a solid fill
	end)
end

function VisitorArrival.arrive(visitor: Model)
	if playing[visitor] or not visitor:IsDescendantOf(Workspace) then
		return
	end
	playing[visitor] = true
	local box, size = visitor:GetBoundingBox()
	local feet = box.Position - Vector3.new(0, size.Y / 2 - 0.2, 0)

	glow(visitor)
	local beats: { number } = if Effects.lessSparkle() then { 0 } else VisitorArrival.SPARKLE_BEATS
	for _, at in beats do
		task.delay(at, function()
			if visitor.Parent then
				Effects.burst("revealSparkle", feet, GOLD)
			end
		end)
	end

	local adornee = visitor.PrimaryPart or visitor:FindFirstChildWhichIsA("BasePart", true)
	if adornee == nil then
		playing[visitor] = nil
		return
	end
	local part = adornee :: BasePart
	local over = (box.Position.Y + size.Y / 2) - part.Position.Y + VisitorArrival.STAR_OVER
	local gui, star = makeStar(part, over)
	seedCount += 1
	local seed = (seedCount * 0.618) % 1
	local still = Effects.reducedMotion()
	local start = os.clock()
	local connection: RBXScriptConnection? = nil
	local function finish()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		playing[visitor] = nil
		if gui.Parent then
			gui:Destroy()
		end
	end
	-- the star pops in once (unless still), then bobs
	if not still then
		star.Size = UDim2.fromScale(0.05, 0.05)
		TweenService:Create(
			star,
			TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(1, 1) }
		):Play()
		connection = RunService.RenderStepped:Connect(function()
			if visitor.Parent == nil or part.Parent == nil or gui.Parent == nil then
				finish()
				return
			end
			local camera = Workspace.CurrentCamera
			if
				camera
				and (camera.CFrame.Position - part.Position).Magnitude > VisitorArrival.STAR_FAR
			then
				return -- hidden by MaxDistance; no need to move it
			end
			local lift, degrees, scale = VisitorArrival.star(os.clock() - start, seed)
			gui.StudsOffsetWorldSpace = Vector3.new(0, over + lift, 0)
			star.Rotation = degrees
			if os.clock() - start > 0.35 then
				star.Size = UDim2.fromScale(scale, scale)
			end
		end)
	end
	visitor.AncestryChanged:Connect(function()
		if not visitor:IsDescendantOf(Workspace) then
			finish()
		end
	end)
end

return VisitorArrival
