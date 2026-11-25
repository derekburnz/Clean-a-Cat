--!strict
-- WashMeter: the fill bar over the wash's area steps (switch washMeter; the owner on 2026-11-25, after his My Pet
-- Salon video: "a bar meter on the top that they fill when doing the task ... if the bar hits full they just shake it
-- off and go next task ... make bar hit full around 90% done so people don't have to get it perfect"). The bar fills
-- as the player scrubs, brushes, lathers, rinses or clips. When it is full the cat shakes off what is left
-- (Moments.ShakeOff) and the next step starts SHAKE_SECONDS later. Pure, so tests/specs/WashMeter.spec.luau covers it;
-- ScrubController counts the work and the HUD draws the bar (ScrubController.meterChanged).
local WashMeter = {}

WashMeter.FLAG = "washMeter"
WashMeter.FULL_AT = 0.9 -- share of an area step done when the bar is full
WashMeter.SHAKE_SECONDS = 0.7 -- the shake off, before the next step starts
-- The full bar stays up this long from the shake, so its "Squeaky clean!" cheer shows (Review-QA on #468), unless
-- the player gets on with the next step first.
WashMeter.HOLD_SECONDS = 1.3
-- The steps with a bar, as ScrubController.meterChanged names them.
WashMeter.STEPS = table.freeze({ "scrub", "brush", "lather", "rinse", "claws" }) :: { string }

-- How many of `total` things must be done for a full bar at `fullAt` (FULL_AT when nil): at least one, never more
-- than all of them.
function WashMeter.needed(total: number, fullAt: number?): number
	local count = math.max(math.floor(total), 1)
	local share = math.clamp(fullAt or WashMeter.FULL_AT, 0, 1)
	return math.clamp(math.ceil(count * share - 1e-9), 1, count)
end

-- How full the bar is, 0 to 1, with `done` of `total` things done.
function WashMeter.fill(done: number, total: number, fullAt: number?): number
	if done ~= done or done <= 0 then
		return 0
	end
	return math.min(done / WashMeter.needed(total, fullAt), 1)
end

-- True once `done` of `total` fills the bar.
function WashMeter.full(done: number, total: number, fullAt: number?): boolean
	return done >= WashMeter.needed(total, fullAt)
end

return table.freeze(WashMeter)
