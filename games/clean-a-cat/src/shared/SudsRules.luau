--!strict
-- SudsRules: the opening's kitten who becomes Suds, the spa's mascot (claim #285, Design-Agent's
-- opening-and-tutorial-plan 2026-11-24). Pure, so tests/specs/SudsRules.spec.luau covers it.
--
-- A brand new save's first cat is a muddy kitten (switch sudsWash). The player washes him with the usual steps,
-- minus the bows: his style moment is the collar at the naming (Design-Agent). His card always shows three stars,
-- as a score only: the save's stars, coins, tips and the Cat Index never change for him (Derek: "dont include
-- him"), so the star tiers, the pick gate and the first customer stay as they are.
--
-- The save keeps how far the player got (save.suds), so leaving part way resumes the right way:
--   NONE  never met him: with openingBox on the scene plays (again), else he waits in the tub
--   BOX   the box is open: he waits in the tub
--   DONE  washed and named: he never comes back as a cat to wash
local SudsRules = {}

SudsRules.NAME = "Suds" -- Model-Agent's ReplicatedStorage.Assets.CleanACat_Cat_Suds... models; never on CatRules.ROSTER
SudsRules.STAND_IN = "Inky" -- the black roster cat, drawn while the Suds models are missing
SudsRules.FLAG = "sudsWash"
SudsRules.NEEDS = table.freeze({ "mud", "tangles" }) :: { string }
SudsRules.STARS = 3 -- his score; never added to the save
SudsRules.NO_BOWS = "noBows" -- in the wash plan (ScrubController.plan): the step bar leaves the bows out for him
SudsRules.ATTRIBUTE = "SudsStage" -- Player attribute: the save's stage, set by the server, for the client's opening

SudsRules.NONE = 0
SudsRules.BOX = 1
SudsRules.DONE = 2

-- A save's stage made safe: a whole number from NONE to DONE, else NONE. For a value read from a save or attribute.
function SudsRules.cleanStage(raw: unknown): number
	if type(raw) ~= "number" or raw ~= raw or raw % 1 ~= 0 then
		return SudsRules.NONE
	end
	return math.clamp(raw, SudsRules.NONE, SudsRules.DONE)
end

-- Whether a save's next cat is the kitten: the switch is on, he is not washed yet, and either the player has met
-- him or the save is brand new (no stars, no window cats). An older save never gets him when the switch goes on.
function SudsRules.isNext(
	stage: number,
	stars: number,
	residents: number,
	isOn: (flag: string) -> boolean
): boolean
	if not isOn(SudsRules.FLAG) then
		return false
	end
	local clean = SudsRules.cleanStage(stage)
	if clean >= SudsRules.DONE then
		return false
	end
	return clean > SudsRules.NONE or (stars <= 0 and residents <= 0)
end

-- The model name for his look: the Suds model when the place has it, else the stand-in's. `has` says whether
-- ReplicatedStorage.Assets holds a name.
function SudsRules.asset(suffix: string, has: (name: string) -> boolean): string
	local own = `CleanACat_Cat_{SudsRules.NAME}{suffix}`
	return if has(own) then own else `CleanACat_Cat_{SudsRules.STAND_IN}{suffix}`
end

return table.freeze(SudsRules)
