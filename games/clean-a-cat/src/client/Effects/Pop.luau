--!strict
-- Pop: the small grow a HUD piece makes as it appears (issues 801 and 803, agreed with Design-Agent). Pure, so it has
-- specs; the caller sets one UIScale to Pop.scale(t, from, peak) each frame until Pop.done(t).
--
--   Pop.scale(t, from?, peak?) -> number   from FROM, eased up to `peak` by PEAK_AT, then down to 1 by SECONDS
--   Pop.done(t) -> boolean                 settled at 1
local Pop = {}

Pop.FROM = 0.6
Pop.PEAK = 1.08
Pop.PEAK_AT = 0.12 -- seconds
Pop.SECONDS = 0.2

function Pop.done(t: number): boolean
	return t >= Pop.SECONDS
end

function Pop.scale(t: number, from: number?, peak: number?): number
	local start = from or Pop.FROM
	local top = peak or Pop.PEAK
	if t >= Pop.SECONDS then
		return 1
	end
	if t <= Pop.PEAK_AT then
		local k = math.max(t, 0) / Pop.PEAK_AT
		local eased = 1 - (1 - k) * (1 - k)
		return start + (top - start) * eased
	end
	local k = (t - Pop.PEAK_AT) / (Pop.SECONDS - Pop.PEAK_AT)
	return top + (1 - top) * k
end

return Pop
