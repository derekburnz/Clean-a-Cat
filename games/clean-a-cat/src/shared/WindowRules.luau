--!strict
-- WindowRules: strays and the display window. A muddy stray turns up now and then instead of a customer;
-- once clean it moves into the window for good and tips while the player is online and while away, up to the
-- tip jar's cap. Pure, so tests/specs/WindowRules.spec.luau covers it. Numbers are draft tuning from the first
-- session plan (gdd-draft.md); Design-Agent owns them. Guard rail: the window earns well under washing.

local WindowRules = {}

WindowRules.CUSHIONS = 4 -- window cats at most
WindowRules.STRAY_EVERY = 4 -- every 4th cat handed out is a stray while the window has room
WindowRules.TIP_COINS = 1 -- each window cat tips this many coins ...
WindowRules.TIP_SECONDS = 10 -- ... every this many seconds
WindowRules.JAR_SECONDS = 3600 -- the away tip jar holds at most 1 hour of tips

export type Resident = {
	cat: string,
	bow: string?,
	since: number,
}

-- The save's residents that are well formed, up to CUSHIONS, in order. `isCat(name)` says whether a name is a
-- real cat (CatRules.rarityOf). A save edited by an old or broken server can hold anything.
function WindowRules.validResidents(raw: unknown, isCat: (name: string) -> boolean): { Resident }
	local out: { Resident } = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, entry in raw :: { unknown } do
		if #out >= WindowRules.CUSHIONS then
			break
		end
		if type(entry) == "table" then
			local e = entry :: { [string]: unknown }
			local cat = e.cat
			local bow = e.bow
			local since = e.since
			if type(cat) == "string" and isCat(cat) then
				table.insert(out, {
					cat = cat,
					bow = if type(bow) == "string" then bow else nil,
					since = if type(since) == "number" and since == since then since else 0,
				})
			end
		end
	end
	return out
end

-- Is the next cat a stray? `handedOut` counts cats handed out this session before this one. A brand new save
-- (no stars, empty window) starts with a stray, so every player owns a cat inside the first minute.
function WindowRules.isStrayTurn(handedOut: number, residents: number, brandNew: boolean): boolean
	if residents >= WindowRules.CUSHIONS then
		return false
	end
	if handedOut == 0 then
		return brandNew
	end
	return handedOut % WindowRules.STRAY_EVERY == 0
end

-- Coins the window tips over `seconds` (whole tip periods only), capped at the jar for time away.
function WindowRules.tips(residents: number, seconds: number, capped: boolean): number
	if not (seconds > 0) or residents <= 0 then
		return 0
	end
	local span = if capped then math.min(seconds, WindowRules.JAR_SECONDS) else seconds
	local count = math.min(residents, WindowRules.CUSHIONS)
	return count * WindowRules.TIP_COINS * math.floor(span / WindowRules.TIP_SECONDS)
end

return table.freeze(WindowRules)
