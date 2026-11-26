--!strict
-- FinishRules: Finish now on a running build (issue 515; tuning section 8, finishNow.price). The owner's words:
-- paid skips on any build, waiting is always free. The price goes by the time left: 5 minutes or less is tier 1,
-- 30 minutes tier 2, 2 hours tier 3, 8 hours tier 4, more tier 5 (5, 15, 35, 75 and 99 Robux in the design; the
-- real price is the developer product's, read from Roblox). Under HIDE_UNDER seconds left there is no price at all,
-- so the first short build of the tutorial never shows one.
--
-- A finish bought for a build that ended on its own before the purchase came through (the prompt stayed open, or
-- the receipt came back on a later join) is kept as a credit of its tier: the next Finish now it covers is free.
-- Credits live in the save as finishCredits, a count by tier ("1" to "5"). A credit covers a build of its own tier or
-- the tier just below (CREDIT_REACH), so a dear credit is never spent on a cheap finish from one tap (Review-QA on
-- PR 588); a cheaper build is priced as usual and the credit waits for one it fits.
-- Pure, so tests/specs/FinishRules.spec.luau covers it; BuildService runs it. Behind the LiveFlags switch finishNow.

local FinishRules = {}

FinishRules.FLAG = "finishNow"
FinishRules.HIDE_UNDER = 15 -- seconds left; under this the button is gone (Growth's rule, issue 531)
FinishRules.CREDIT_REACH = 1 -- tiers below its own that a credit still covers
FinishRules.HOLD_SECONDS = 0.5 -- the Finish now prompt is held this long, so a passing tap never buys

export type Tier = {
	key: string, -- the developer product's key in shared/Products
	upTo: number, -- seconds left this tier covers, from the tier before
	robux: number, -- the design's price, for the owner's product list; the button shows Roblox's price
}

FinishRules.TIERS = table.freeze({
	table.freeze({ key = "FinishTier1", upTo = 5 * 60, robux = 5 }),
	table.freeze({ key = "FinishTier2", upTo = 30 * 60, robux = 15 }),
	table.freeze({ key = "FinishTier3", upTo = 2 * 3600, robux = 35 }),
	table.freeze({ key = "FinishTier4", upTo = 8 * 3600, robux = 75 }),
	table.freeze({ key = "FinishTier5", upTo = math.huge, robux = 99 }),
}) :: { Tier }

export type Build = { item: string, endsAt: number }
export type State = {
	stations: { [string]: boolean },
	builds: { [string]: Build },
}

-- The tier for `secondsLeft`, or nil when there is no price (under HIDE_UNDER, or not a real number).
function FinishRules.tier(secondsLeft: number): number?
	if secondsLeft ~= secondsLeft or secondsLeft < FinishRules.HIDE_UNDER then
		return nil
	end
	for index, tier in FinishRules.TIERS do
		if secondsLeft <= tier.upTo then
			return index
		end
	end
	return nil
end

-- The tier whose product key is `key`, or nil.
function FinishRules.tierOfKey(key: string): number?
	for index, tier in FinishRules.TIERS do
		if tier.key == key then
			return index
		end
	end
	return nil
end

-- The save's credits as whole counts above 0 by tier ("1" to "5"); anything else in a damaged save is dropped.
function FinishRules.cleanCredits(raw: unknown): { [string]: number }
	local out: { [string]: number } = {}
	if type(raw) ~= "table" then
		return out
	end
	for index in FinishRules.TIERS do
		local count = (raw :: { [string]: unknown })[tostring(index)]
		if type(count) == "number" and count == count and count >= 1 and count < math.huge then
			out[tostring(index)] = math.floor(count)
		end
	end
	return out
end

-- The cheapest credit that covers a finish of tier `tier` (its own tier, or up to CREDIT_REACH tiers dearer): its
-- tier, or nil when there is none.
function FinishRules.creditFor(credits: { [string]: number }, tier: number): number?
	for index = tier, math.min(tier + FinishRules.CREDIT_REACH, #FinishRules.TIERS) do
		if (credits[tostring(index)] or 0) >= 1 then
			return index
		end
	end
	return nil
end

function FinishRules.addCredit(credits: { [string]: number }, tier: number)
	local key = tostring(tier)
	credits[key] = (credits[key] or 0) + 1
end

-- Spends one credit of tier `tier`. False when there is none.
function FinishRules.spendCredit(credits: { [string]: number }, tier: number): boolean
	local key = tostring(tier)
	local count = credits[key] or 0
	if count < 1 then
		return false
	end
	if count > 1 then
		credits[key] = count - 1
	else
		(credits :: { [string]: number? })[key] = nil
	end
	return true
end

-- The slot a paid finish of tier `paid` finishes at `now`: `prefer` when its build is still running, else any
-- running build. A build whose time left is now under the tier paid for (or under HIDE_UNDER) is still finished;
-- one that needs a dearer tier than paid is not. Nil when nothing fits: the purchase becomes a credit.
function FinishRules.target(state: State, now: number, paid: number, prefer: string?): string?
	local function fits(slot: string): boolean
		local build = state.builds[slot]
		if build == nil or build.endsAt <= now then
			return false
		end
		local need = FinishRules.tier(build.endsAt - now)
		return need == nil or need <= paid
	end
	if prefer and fits(prefer) then
		return prefer
	end
	-- the slots in a fixed order, so the same state always picks the same build
	local slots: { string } = {}
	for slot in state.builds do
		table.insert(slots, slot)
	end
	table.sort(slots)
	for _, slot in slots do
		if fits(slot) then
			return slot
		end
	end
	return nil
end

-- Finishes the build in `slot` now, as if its time had passed. Returns its item id, or nil when the slot is empty.
function FinishRules.finish(state: State, slot: string): string?
	local build = state.builds[slot]
	if build == nil then
		return nil
	end
	state.stations[build.item] = true
	state.builds[slot] = nil
	return build.item
end

return table.freeze(FinishRules)
