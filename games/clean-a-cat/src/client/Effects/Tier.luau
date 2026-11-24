--!strict
-- Tier: pure rules for device tier, Reduce Motion and stream rate. No Roblox services, so they have specs.
local Tier = {}

-- Low on touch-only devices or a low saved graphics level (1 to 10 scale; 0 means automatic and counts as high).
function Tier.pick(
	touchEnabled: boolean,
	keyboardEnabled: boolean,
	qualityLevel: number
): "low" | "high"
	if touchEnabled and not keyboardEnabled then
		return "low"
	end
	if qualityLevel > 0 and qualityLevel <= 3 then
		return "low"
	end
	return "high"
end

-- Stream rate for the foam from drag speed (studs per second): nothing when still, full rate at a fast drag.
-- Reduce Motion halves it.
function Tier.foamRate(
	maxRate: number,
	dragSpeed: number,
	fastDrag: number,
	reducedMotion: boolean
): number
	local rate = maxRate * math.clamp(dragSpeed / fastDrag, 0, 1)
	if reducedMotion then
		rate *= 0.5
	end
	return math.floor(rate + 0.5)
end

-- Burst size with Reduce Motion: halved but never zero, so the action still answers.
function Tier.burst(count: number, reducedMotion: boolean): number
	if reducedMotion then
		return math.max(1, math.floor(count / 2))
	end
	return count
end

-- Stink wisp rate over a dirty cat: full while every mud patch is on, thinning as patches clear, none at zero.
-- Never below 1 while any mud is left, so the last patch still reads. Reduce Motion halves it.
function Tier.stinkRate(
	maxRate: number,
	left: number,
	total: number,
	reducedMotion: boolean
): number
	if left <= 0 or total <= 0 then
		return 0
	end
	local rate = maxRate * math.clamp(left / total, 0, 1)
	if reducedMotion then
		rate *= 0.5
	end
	return math.max(1, math.floor(rate + 0.5))
end

return Tier
