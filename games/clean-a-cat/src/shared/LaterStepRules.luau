--!strict
-- LaterStepRules: the later wash steps a cat takes after the fluff and before the bows (#267): the Bubble Bath for a
-- smell and the Pawdicure for long claws. Pure functions for ScrubController and the specs. The numbers are drafts
-- in WashDraft. These steps are only a look on the player's device: the server pays from the save, as for the dryer.
local CatRules = require(script.Parent:WaitForChild("CatRules"))
local WashDraft = require(script.Parent:WaitForChild("WashDraft"))

local LaterStepRules = {}

-- The later needs this cat's wash goes through, in the wash's order: each one it needs whose station is built (not
-- in `locked`) and that is on (CatRules.needOn: its switch, or the dirt levels').
function LaterStepRules.steps(
	needs: { CatRules.Need },
	locked: { CatRules.Need },
	isOn: (flag: string) -> boolean
): { CatRules.Need }
	local out: { CatRules.Need } = {}
	for _, need in CatRules.LATER_NEEDS do
		if
			table.find(needs, need) ~= nil
			and table.find(locked, need) == nil
			and CatRules.needOn(need, isOn)
		then
			table.insert(out, need)
		end
	end
	return out
end

-- How many of `count` suds puffs a swirl of `travel` studs has cleared: all of them at `full` studs
-- (WashDraft.SWIRL_TRAVEL when nil; WashPace's with the switch washPace).
function LaterStepRules.sudsGone(travel: number, count: number, full: number?): number
	if count <= 0 then
		return 0
	end
	return math.clamp(math.floor(travel / (full or WashDraft.SWIRL_TRAVEL) * count), 0, count)
end

-- True once a press held from `since` has lasted `hold` seconds (WashDraft.CLAW_HOLD when nil) at `now`.
function LaterStepRules.held(since: number, now: number, hold: number?): boolean
	return now - since >= (hold or WashDraft.CLAW_HOLD)
end

return table.freeze(LaterStepRules)
