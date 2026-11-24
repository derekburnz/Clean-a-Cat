--!strict
-- TrailRules: where the tutorial's floor trail puts its arrows (Spa/FloorTrail, switch tutorialTrail), from
-- Design-Agent's tutorial.html step 1: arrows on the floor from the player's feet to a spot, flowing toward it, and
-- stopping short of the ring that marks the spot. Pure maths on positions, so it can be tested without a place.
local TrailRules = {}

TrailRules.SPACING = 2.4 -- studs between arrows
TrailRules.START_GAP = 1.5 -- studs clear of the player's feet
TrailRules.END_GAP = 3 -- studs short of the spot: the ring marks it
TrailRules.FADE = 2 -- studs over which an arrow fades in at the start and out at the end
TrailRules.MAX_MARKS = 24 -- a long walk shows the nearest part of the way

-- An arrow's spot on the floor, the way it points (flat, unit length) and its fade: 0 is solid, 1 is gone.
export type Mark = { position: Vector3, direction: Vector3, fade: number }

-- The arrows from `from` to `to` on a floor at height `floorY`, each facing the way to go. `phase` (0 to 1) slides
-- them one spacing along, so stepping it each frame makes them flow toward the spot.
function TrailRules.marks(from: Vector3, to: Vector3, floorY: number, phase: number): { Mark }
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	local marks: { Mark } = {}
	local finish = length - TrailRules.END_GAP
	if finish <= TrailRules.START_GAP then
		return marks
	end
	local direction = flat.Unit
	local start = Vector3.new(from.X, floorY, from.Z)
	local slide = (phase % 1) * TrailRules.SPACING
	for index = 0, TrailRules.MAX_MARKS - 1 do
		local along = TrailRules.START_GAP + slide + index * TrailRules.SPACING
		if along > finish then
			break
		end
		local fadeIn = math.clamp((along - TrailRules.START_GAP) / TrailRules.FADE, 0, 1)
		local fadeOut = math.clamp((finish - along) / TrailRules.FADE, 0, 1)
		table.insert(marks, {
			position = start + direction * along,
			direction = direction,
			fade = 1 - math.min(fadeIn, fadeOut),
		})
	end
	return marks
end

return table.freeze(TrailRules)
