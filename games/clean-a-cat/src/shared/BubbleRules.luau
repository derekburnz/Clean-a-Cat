--!strict
-- BubbleRules: Suds's help bubble (switch sudsBubble, off by default). A card at the bottom of the screen with his
-- face, a title, one short line that says why, and one button. Each bubble shows once per save, one at a time, and
-- never opens anything by itself: "Show me" only points the way (the floor trail, and Suds trots there once
-- Motion-FX hooks Moments.SudsPoint), and the player still walks there and taps the thing. The words are
-- Design-Agent's (2026-11-24).
--
-- Pure, so tests/specs/BubbleRules.spec.luau covers it. The client decides which bubble is due from what it sees
-- (BubbleController); the server only keeps the save's list of bubbles already shown (BubbleService), mirrored to the
-- Player attribute ATTRIBUTE so a rejoin never shows one twice.

local BubbleRules = {}

BubbleRules.FLAG = "sudsBubble"
BubbleRules.ATTRIBUTE = "BubblesSeen" -- the save's shown bubble ids, comma separated; nil until the save loads
BubbleRules.OK = "OK!"
BubbleRules.SHOW_ME = "Show me"

export type Bubble = {
	id: string,
	title: string,
	line: string,
	showMe: boolean, -- true: the button says "Show me" and points the way; false: "OK!" and just closes
	button: string?, -- a bubble's own button word in place of both (the like ask's "Sure!", LikeAskViewRules)
}

local function bubble(id: string, title: string, line: string, showMe: boolean): Bubble
	return table.freeze({ id = id, title = title, line = line, showMe = showMe }) :: Bubble
end

-- In the order they win when two are due at once.
BubbleRules.BUBBLES = table.freeze({
	bubble("openSpa", "Let's open the spa!", "A customer is on the way.", false), -- after Suds's naming card
	bubble("firstCustomer", "First customer!", "Wash their cat to earn coins.", true), -- the first customer's cat
	bubble("stationReady", "It's ready!", "Try it on the next cat.", false), -- a build finished
	bubble("wetCat", "Wet cat!", "Build a dryer to dry them.", true), -- the first cat that needs a dryer not built
	bubble("newSoap", "New soap!", "Bigger bubbles, faster scrubs.", true), -- Bubble Soap affordable
	bubble("build", "Let's build!", "Upgrades make your spa better.", true), -- the Brush Table affordable
	bubble("longBuild", "Before you go", "The VIP Room builds while you're away.", true), -- the VIP Room affordable
	-- switch tubBuilds (issue 515, Design-Agent 2026-11-26): the Third Tub affordable and not started, in place of the
	-- VIP Room's, which is far later then
	bubble("longBuildTub", "Before you go", "The Third Tub builds while you're away.", true),
	-- switch quests (issue 516, gdd: "Quests at 6:00"): the Quests button has just arrived (QuestsOpen)
	bubble("quests", "Quests!", "Coins every day, a crate each week.", false),
	-- switch giftStand (issue 521): the stand lit at 7:00 (GiftLit); "Show me" opens its card. Shown through the ask
	-- line (AskController's "gift"), not BubbleController's own facts
	bubble("gift", "A gift for you!", "Your stand has a free pet. Take a look!", true),
	-- switch contextAsks (issue 877): only with it on, both guide cards with the trail
	bubble("special", "A special visitor!", "Wash their cat for a big tip.", true), -- one is at the door
	bubble("crate", "You got a crate!", "Open it for a pet that helps.", true), -- the first crate held
	-- Jo affordable and not hired yet (issue 913): his pad, with Jo walking up (Moments.JoArrives)
	bubble("hireJo", "Hire your first helper", "Jo washes cats for you.", true),
}) :: { Bubble }

-- Context asks (switch contextAsks, issue 877; the owner on 2026-11-26: "use context tutorials based on what the
-- player unlocks/can do/can buy" and "only have popups like this when their is something your guiding them to do
-- next"). With it on: the cards that only announce something are CUT, the guide cards say the next action in their
-- title (WORDS), every "Show me" card starts its floor trail the moment it shows, and the two new guide cards
-- (ONLY_CONTEXT) can show. With it off every card is as before and the new two never show.
BubbleRules.CONTEXT_FLAG = "contextAsks"
BubbleRules.CUT =
	table.freeze({ openSpa = true, stationReady = true, quests = true }) :: { [string]: boolean }
BubbleRules.ONLY_CONTEXT =
	table.freeze({ special = true, crate = true, hireJo = true }) :: { [string]: boolean }
BubbleRules.WORDS = table.freeze({
	firstCustomer = {
		"Bring the cat to the tub",
		"Pick it up and carry it there.",
	},
	wetCat = { "Build a dryer", "Wet cats need one to dry." },
	newSoap = { "Buy the Bubble Soap", "It makes scrubs faster." },
	build = { "Build an upgrade", "Head to the Build board." },
	longBuild = { "Start the VIP Room", "It builds while you're away." },
	longBuildTub = { "Start the Third Tub", "It builds while you're away." },
}) :: { [string]: { string } }

-- The opening's own bubbles: part of the first minutes' steps, so they never wait in the ask line (switch askQueue).
-- Every other bubble is the ask "bubble" there: it waits its turn, a minute from any other ask.
BubbleRules.OPENING =
	table.freeze({ openSpa = true, firstCustomer = true }) :: { [string]: boolean }

local byId: { [string]: Bubble } = {}
local ids: { string } = {}
for _, b in BubbleRules.BUBBLES do
	byId[b.id] = b
	table.insert(ids, b.id)
end
BubbleRules.IDS = table.freeze(ids)

function BubbleRules.get(id: string): Bubble?
	return byId[id]
end

-- The save's field, trusted only for known ids set to true (a damaged save or an old id is dropped).
function BubbleRules.cleanSeen(raw: unknown): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(raw) == "table" then
		for id, value in raw :: { [unknown]: unknown } do
			if type(id) == "string" and byId[id] ~= nil and value == true then
				out[id] = true
			end
		end
	end
	return out
end

-- The attribute's text for a seen set: known ids in BUBBLES order, comma separated ("" when none).
function BubbleRules.pack(seen: { [string]: boolean }): string
	local out: { string } = {}
	for _, id in ids do
		if seen[id] then
			table.insert(out, id)
		end
	end
	return table.concat(out, ",")
end

-- The seen set from the attribute, or nil while it is not a string (the save has not loaded yet).
function BubbleRules.unpack(raw: unknown): { [string]: boolean }?
	if type(raw) ~= "string" then
		return nil
	end
	local out: { [string]: boolean } = {}
	for id in string.gmatch(raw, "[^,]+") do
		if byId[id] ~= nil then
			out[id] = true
		end
	end
	return out
end

local context: { [string]: Bubble } = {}
for id, words in BubbleRules.WORDS do
	local b = byId[id]
	context[id] =
		table.freeze({ id = id, title = words[1], line = words[2], showMe = b.showMe }) :: Bubble
end

-- Whether the switch contextAsks is on for `isOn` (off when nil).
function BubbleRules.contextOn(isOn: ((flag: string) -> boolean)?): boolean
	return isOn ~= nil and isOn(BubbleRules.CONTEXT_FLAG)
end

-- The bubble to show now: the first in BUBBLES whose fact is true and that this save has not shown. nil when none.
-- With contextAsks on (`isOn`), a CUT card never shows and a guide card comes in its WORDS.
function BubbleRules.pick(
	facts: { [string]: boolean },
	seen: { [string]: boolean },
	isOn: ((flag: string) -> boolean)?
): Bubble?
	local on = BubbleRules.contextOn(isOn)
	for _, b in BubbleRules.BUBBLES do
		local allowed = if on then not BubbleRules.CUT[b.id] else not BubbleRules.ONLY_CONTEXT[b.id]
		if allowed and facts[b.id] and not seen[b.id] then
			return if on then context[b.id] or b else b
		end
	end
	return nil
end

return table.freeze(BubbleRules)
