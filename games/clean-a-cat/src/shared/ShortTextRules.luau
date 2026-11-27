--!strict
-- ShortTextRules: the words behind the switch shortText (issue 1027, Derek's playtest of 2026-11-27: "lots of bloat text
-- that doesn't need to be there"). UI/ShortText applies them to every window. A line is either dropped whole (the
-- picture and the title already say it) or cut to the fewest words that still say it. Numbers, prices and odds stay:
-- nothing that matters to a purchase is hidden. Pure, so tests/specs/ShortTextRules.spec.luau covers it.
local Passes = require(script.Parent:WaitForChild("Passes"))

local ShortTextRules = {}

ShortTextRules.FLAG = "shortText"

-- Lines dropped whole: the picture and the title already say them.
local DROP: { [string]: boolean } = {
	["So you can find the spa again"] = true,
	["Our group, for news and events"] = true,
	["On its page, if you enjoy it"] = true,
	["Always shown, for every cat"] = true,
	-- the shop cards and the starter pack's cards: the title and the picture (x2, x3, +1) already say these
	["Double coins on cats you wash by hand"] = true,
	["Triple coins on hand washes, in place of 2x"] = true,
	["Build a tub and a room at once"] = true,
	["A third helper with his own stand"] = true,
	["A second pet for you and helpers"] = true,
	["One more pet for you and each helper"] = true,
	["A golden pet that shines"] = true,
}
for key, info in Passes.INFO do
	-- the passes' long descriptions: the picture shows x2, +1 or the helper. Not the Golden Sponge's, whose name does
	-- not say what it does: it is cut to its number below (Review-QA on PR 1106)
	if key ~= "GoldenSponge" then
		DROP[info.text] = true
	end
end

-- Lines cut short: a Lua pattern over the whole line and its short form.
local CUT: { { string } } = {
	-- the Golden Sponge's card is the one whose title does not say what it does: keep its number
	{ "^Gold sponge, %+20%% on hand washes$", "+20%% on hand washes" },
	{ "^Gold bubbles, %+20%% on hand washes$", "+20%% on hand washes" },
	{
		"^The best sponge with gold bubbles, and %+20%% on every cat you wash by hand$",
		"+20%% on hand washes",
	},
	{ "^Hire at their pad · (.+ coins)$", "%1" },
	{ "^Comes with the Extra Worker pass$", "Extra Worker pass" },
	{ "^Comes when (%S+) is hired$", "Hire %1 first" },
	{ "^Your next gift waits for the next day you play%.$", "Next gift tomorrow" },
	{ "^Day (%d+) waits for the next day you play%.$", "Day %1 tomorrow" },
	{ "^(%+%d+%%) tips or pay$", "%1" },
}

-- The short words for `text`, "" to hide the line, or nil to leave it as it is.
function ShortTextRules.apply(text: string): string?
	if DROP[text] then
		return ""
	end
	for _, rule in CUT do
		local short, count = string.gsub(text, rule[1], rule[2])
		if count > 0 and short ~= text then
			return short
		end
	end
	return nil
end

return ShortTextRules
