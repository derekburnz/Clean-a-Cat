--!strict
-- JarRules: the tip jar that fills while the player is away (issue 517; tuning section 13 and build.Garden.effect).
-- Each hired worker puts RATE coins an hour in the jar while the player is away, for at most the jar's hours of fill
-- (8, or 12 with the Garden, which also fills it 1.25 times as fast). Coins wait in the jar (save.jarCoins) until
-- the player taps it. The time it last filled from is save.jarAt (os.time(), the server's clock). Online time
-- never fills it: the workers pay straight away then. Pure, so tests/specs/JarRules.spec.luau covers it; JarService
-- runs it. Behind the LiveFlags switch tipJar.

local JarRules = {}

JarRules.FLAG = "tipJar"
JarRules.ATTRIBUTE = "JarCoins" -- Player attribute: the coins waiting in the jar, for the jar's prompt
JarRules.RATE = 30 -- jar.rate: coins an hour per hired worker while away
JarRules.PROMPT_REACH = 10 -- studs; the jar's prompt shows within this distance
JarRules.SERVER_REACH = 16 -- studs; the server's distance check, with room for lag

-- The most the jar holds for `workers` hired workers, `hours` of fill at `times` the rate.
function JarRules.cap(workers: number, hours: number, times: number): number
	return math.floor(JarRules.RATE * times * workers * hours)
end

-- The jar after the player was away from `at` until `now`: its coins, never above the cap. A jar never stamped
-- (`at` 0), a clock that went back, or no workers adds nothing.
function JarRules.fill(
	coins: number,
	at: number,
	now: number,
	workers: number,
	hours: number,
	times: number
): number
	local held = if coins == coins and coins > 0 then math.floor(coins) else 0
	if at <= 0 or now <= at or workers <= 0 then
		return held
	end
	local away = math.min(now - at, hours * 3600)
	local added = math.floor(JarRules.RATE * times * workers * away / 3600)
	return math.min(held + added, math.max(held, JarRules.cap(workers, hours, times)))
end

return table.freeze(JarRules)
