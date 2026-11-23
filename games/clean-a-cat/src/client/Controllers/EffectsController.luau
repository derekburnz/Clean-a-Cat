--!strict
-- EffectsController: plays effects on the game's moments (Shared.Moments). It only listens.
-- Scrub effects sit behind the LiveFlags switch `scrubEffects` and reveal effects behind `revealEffects`, both off by
-- default, because they change the first session.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Effects = require(script.Parent.Parent:WaitForChild("Effects"))

local SCRUB_FLAG = "scrubEffects"
local REVEAL_FLAG = "revealEffects"
local REVEAL_LIFT = 0.6 -- studs above the cat's pivot, so the sparkles start on the coat and not in the tub

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
	Moments.MudPatchCleared:Connect(
		function(_cat: Model, patchPosition: Vector3, _patchesLeft: number)
			if scrubOn() then
				Effects.burst("mudChunks", patchPosition)
			end
		end
	)
end

return EffectsController
