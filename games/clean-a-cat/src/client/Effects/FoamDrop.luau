--!strict
-- FoamDrop: the last foam slides off the cat at the end of the rinse and lands round its feet as a few soft blobs
-- that flatten and fade (Derek's salon video, 2026-11-25; Moments.ShakeOff with step "rinse", switch washMeter).
-- Client only and cosmetic: a handful of anchored balls that never collide, catch a ray or touch, all gone in
-- about 1.4 s. With reduced motion the blobs just appear on the floor and fade.
--
-- API
--   FoamDrop.drop(cat)                    drops BLOBS blobs from the lower coat to the floor round the cat
--   FoamDrop.at(t, still) -> (fall, squash, seen)   pure: at `t` seconds, how far down (0 at the coat, 1 on the
--                                         floor), how flat (1 round, SQUASH flat) and how see-through (0 to 1)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent)

local FoamDrop = {}

FoamDrop.BLOBS = table.freeze({ low = 4, high = 6 })
FoamDrop.FALL = 0.28 -- seconds from the coat to the floor, speeding up
FoamDrop.SETTLE = 0.14 -- seconds to flatten on landing
FoamDrop.HOLD = 0.45 -- seconds lying there
FoamDrop.FADE = 0.5 -- seconds to fade out
FoamDrop.SQUASH = 0.45 -- height kept when flat
FoamDrop.SEEN = 0.08 -- transparency while whole
FoamDrop.SIZE = table.freeze({ 0.38, 0.6 }) -- studs across, smallest and biggest
local WHITE = Color3.fromRGB(255, 255, 255)
local BLUSH = Color3.fromRGB(232, 244, 255)

function FoamDrop.total(): number
	return FoamDrop.FALL + FoamDrop.SETTLE + FoamDrop.HOLD + FoamDrop.FADE
end

function FoamDrop.at(t: number, still: boolean): (number, number, number)
	local fall, settle, hold = FoamDrop.FALL, FoamDrop.SETTLE, FoamDrop.HOLD
	if still then
		-- no fall and no squash: on the floor, flat, then the same fade
		local fadeFrom = fall + settle + hold
		local fade = math.clamp((t - fadeFrom) / FoamDrop.FADE, 0, 1)
		return 1, FoamDrop.SQUASH, FoamDrop.SEEN + (1 - FoamDrop.SEEN) * fade
	end
	if t < fall then
		local u = math.max(t, 0) / fall
		return u * u, 1, FoamDrop.SEEN
	end
	local landed = t - fall
	if landed < settle then
		-- a quick splat, eased out
		local u = landed / settle
		local e = 1 - (1 - u) * (1 - u)
		return 1, 1 - (1 - FoamDrop.SQUASH) * e, FoamDrop.SEEN
	end
	local fade = math.clamp((landed - settle - hold) / FoamDrop.FADE, 0, 1)
	return 1, FoamDrop.SQUASH, FoamDrop.SEEN + (1 - FoamDrop.SEEN) * fade
end

type Blob = { part: Part, from: Vector3, to: Vector3, size: number }

local function floorUnder(point: Vector3, skip: { Instance }): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	local hit = Workspace:Raycast(point, Vector3.new(0, -8, 0), params)
	return if hit then hit.Position.Y else nil
end

function FoamDrop.drop(cat: Model)
	if not cat:IsDescendantOf(Workspace) then
		return
	end
	local box, size = cat:GetBoundingBox()
	local count = if Effects.tier() == "low" then FoamDrop.BLOBS.low else FoamDrop.BLOBS.high
	if Effects.lessSparkle() then
		count = math.max(2, math.floor(count / 2))
	end
	local folder = Instance.new("Folder")
	folder.Name = "CleanACat_FoamDrop"
	folder.Parent = Workspace
	local skip: { Instance } = { cat, folder }
	local blobs: { Blob } = {}
	local radius = math.max(size.X, size.Z) / 2
	local lowY = box.Position.Y - size.Y * 0.15
	local bottom = box.Position.Y - size.Y / 2
	for i = 1, count do
		local angle = (i / count) * 2 * math.pi + (i % 2) * 0.35
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local from = Vector3.new(box.Position.X, lowY, box.Position.Z) + out * radius * 0.7
		local landX = from + out * radius * 0.35
		local floorY = floorUnder(Vector3.new(landX.X, lowY, landX.Z), skip) or bottom
		local s = FoamDrop.SIZE[1] + (FoamDrop.SIZE[2] - FoamDrop.SIZE[1]) * ((i * 0.618) % 1)
		local part = Instance.new("Part")
		part.Name = "Foam"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = if i % 3 == 0 then BLUSH else WHITE
		part.Size = Vector3.new(s, s, s)
		part.Transparency = 1
		-- a sphere mesh, so the blob can flatten (a Ball part keeps all three sizes equal)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		part.Parent = folder
		table.insert(
			blobs,
			{ part = part, from = from, to = Vector3.new(landX.X, floorY, landX.Z), size = s }
		)
	end
	local still = Effects.reducedMotion()
	local start = os.clock()
	local connection: RBXScriptConnection? = nil
	local function frame()
		local t = os.clock() - start
		if t >= FoamDrop.total() or folder.Parent == nil then
			if connection then
				connection:Disconnect()
			end
			folder:Destroy()
			return
		end
		local fall, squash, seen = FoamDrop.at(t, still)
		for _, blob in blobs do
			local height = blob.size * squash
			local over = blob.from:Lerp(blob.to, fall)
			-- the blob's bottom meets the floor when it lands, so it sits on it rather than in it
			local y = if fall >= 1 then blob.to.Y + height / 2 else over.Y
			blob.part.Size =
				Vector3.new(blob.size / math.sqrt(squash), height, blob.size / math.sqrt(squash))
			blob.part.CFrame = CFrame.new(over.X, y, over.Z)
			blob.part.Transparency = seen
		end
	end
	connection = RunService.RenderStepped:Connect(frame)
	frame()
end

return FoamDrop
