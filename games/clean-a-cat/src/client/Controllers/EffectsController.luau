--!strict
-- EffectsController: plays effects on the game's moments (Shared.Moments). It only listens.
-- Scrub effects sit behind the LiveFlags switch `scrubEffects`, reveal effects behind `revealEffects` and brush and bow
-- effects behind `fluffEffects`, all off by default, because they change the first session.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Effects = require(script.Parent.Parent:WaitForChild("Effects"))

local SCRUB_FLAG = "scrubEffects"
local REVEAL_FLAG = "revealEffects"
local FLUFF_FLAG = "fluffEffects"
local REVEAL_LIFT = 0.6 -- studs above the cat's pivot, so the sparkles start on the coat and not in the tub
local BOW_LIFT = 1.2 -- studs above the pivot, about where a bow sits
local GLOW_SECONDS = 0.6

-- The coat colour for fur puffs: the cat's Body part when it has one.
local function coatColor(cat: Model): Color3?
	local body = cat:FindFirstChild("Body", true)
	if body and body:IsA("BasePart") then
		return body.Color
	end
	return nil
end

local EffectsController = {}

local foamPreset = "foamTrail" -- later: foamTrailWide with Bubble Soap, foamTrailGold with the Golden Sponge pass

function EffectsController.Init(_controllers: { [string]: any })
	Effects.start()
end

function EffectsController.Start()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local LiveFlags = require(shared:WaitForChild("LiveFlags")) :: any
	local Moments = require(shared:WaitForChild("Moments")) :: any

	local function scrubOn(): boolean
		return LiveFlags.isOn(SCRUB_FLAG)
	end

	Moments.ScrubMove:Connect(
		function(_cat: Model, hitPoint: Vector3, _normal: Vector3, dragSpeed: number)
			if scrubOn() then
				Effects.stream(foamPreset, hitPoint, dragSpeed)
			end
		end
	)
	Moments.ScrubStop:Connect(function()
		Effects.stopStream(foamPreset)
	end)
	Moments.CatClean:Connect(function(cat: Model)
		if not LiveFlags.isOn(REVEAL_FLAG) or not cat:IsDescendantOf(workspace) then
			return
		end
		local center = cat:GetPivot().Position + Vector3.new(0, REVEAL_LIFT, 0)
		Effects.stopStream(foamPreset)
		Effects.burst("revealSparkle", center)
		Effects.burst("shakeDroplets", center)
	end)
	Moments.BrushSwipe:Connect(function(cat: Model, _stroke: number)
		if LiveFlags.isOn(FLUFF_FLAG) and cat:IsDescendantOf(workspace) then
			Effects.burst(
				"furPuff",
				cat:GetPivot().Position + Vector3.new(0, REVEAL_LIFT, 0),
				coatColor(cat)
			)
		end
	end)
	Moments.CatFluffed:Connect(function(cat: Model)
		if LiveFlags.isOn(FLUFF_FLAG) then
			Effects.glow(cat, GLOW_SECONDS)
		end
	end)
	Moments.BowChosen:Connect(function(cat: Model, _bowId: string)
		if LiveFlags.isOn(FLUFF_FLAG) and cat:IsDescendantOf(workspace) then
			Effects.burst("bowHearts", cat:GetPivot().Position + Vector3.new(0, BOW_LIFT, 0))
		end
	end)
	Moments.MudPatchCleared:Connect(
		function(_cat: Model, patchPosition: Vector3, _patchesLeft: number)
			if scrubOn() then
				Effects.burst("mudChunks", patchPosition)
			end
		end
	)
end

return EffectsController
