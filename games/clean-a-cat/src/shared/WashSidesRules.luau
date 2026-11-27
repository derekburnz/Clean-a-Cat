--!strict
-- WashSidesRules: the wash works on the cat from more than one side (switch washSides, issue 899). Derek on dev,
-- 2026-11-26: "minigames should make them do stuff from multiple sides not just all at the front".
--
-- Each wash starts with the cat facing the camera (the front view, WashScreenRules.frontFrom). Half way through the
-- scrub, the lather and the rinse (Design-Agent's call: at about 50% of the step's bar) the cat turns once, quickly
-- and smoothly, so the rest of the step is done on another side:
--   * scrub: he turns to bring round the middle of the mud still hidden from the camera (often his back);
--   * lather: a quarter turn, so the second half of the foam goes on his side;
--   * rinse: he turns to bring round the foam still on him, so the player rinses that side too.
-- The brush, the claws and the bow keep the front. A turn never runs twice in one step. Pure: ScrubController turns
-- the cat; specs cover this.
local ScrubRules = require(script.Parent:WaitForChild("ScrubRules"))

local WashSidesRules = {}

WashSidesRules.FLAG = "washSides"
WashSidesRules.AT = 0.5 -- the step's bar fill at which the cat turns
WashSidesRules.LATHER_TURN = math.pi / 2 -- radians: the lather's quarter turn
WashSidesRules.STEPS =
	table.freeze({ scrub = true, lather = true, rinse = true }) :: { [string]: boolean }

-- Whether `step` (WashMeter's step name) at `fill` (0 to 1) turns the cat now, given the steps already turned.
function WashSidesRules.due(step: string?, fill: number, turned: { [string]: boolean }): boolean
	return step ~= nil
		and WashSidesRules.STEPS[step] == true
		and fill == fill
		and fill >= WashSidesRules.AT
		and fill < 1
		and turned[step] ~= true
end

-- The yaw (radians about the up axis, as CFrame.Angles(0, yaw, 0)) for `step`'s turn, or nil for none. The lather
-- turns a fixed quarter. The scrub and the rinse bring round the middle of what is left (`offsets`: the mud patches
-- or foam puffs still on him, as positions from his pivot) that does not face `toCamera` (from his pivot to the
-- camera), by ScrubRules.turnToShow's own facing test; nil when all of it faces the camera already.
function WashSidesRules.yawFor(step: string, offsets: { Vector3 }, toCamera: Vector3): number?
	if step == "lather" then
		return WashSidesRules.LATHER_TURN
	end
	return ScrubRules.turnToShow(offsets, toCamera, #offsets)
end

return table.freeze(WashSidesRules)
