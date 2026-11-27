--!strict
-- ToastRules: the short notices as small cards (UI/ToastCard, switch toastCards, issue 877) and which kind of card a
-- notice gets. Pure, so tests/specs/ToastRules.spec.luau covers it.
local ToastRules = {}

ToastRules.FLAG = "toastCards"
-- (issue 1024) The big reward popup: a "You got it!" moment in the middle of the screen for a pet, a crate, a gift, a
-- check-in day or something bought, with its picture on a sunburst, as popular Roblox games show a reward.
ToastRules.POP_FLAG = "rewardPop"

export type Look = "reward" | "warning" | "news"

-- The card's type for a notice: mint for a reward, peach for a "not yet", lilac for news.
function ToastRules.lookOf(text: string, kind: ("info" | "warning")?): Look
	if kind == "warning" then
		return "warning"
	end
	local lower = string.lower(text)
	if
		string.sub(text, 1, 1) == "+"
		or string.find(lower, "is yours", 1, true) ~= nil
		or string.find(lower, "is ready", 1, true) ~= nil
		or string.find(lower, "coins back", 1, true) ~= nil
	then
		return "reward"
	end
	if
		string.find(lower, "can't", 1, true) ~= nil
		or string.find(lower, "more coins to", 1, true) ~= nil
	then
		return "warning"
	end
	return "news"
end

export type Picture = { kind: "portrait" | "icon", name: string }

-- The picture a notice shows (issue 1024: most notices came with none). `icon` is the cat or pet the server named;
-- `isPortrait(name)` says whether a cat or pet of that name has a portrait. A notice about a pet or cat shows its
-- face; anything else shows the HUD icon of what it gives. nil only when nothing fits.
function ToastRules.pictureOf(
	text: string,
	icon: string?,
	isPortrait: (string) -> boolean
): Picture?
	if icon ~= nil and isPortrait(icon) then
		return { kind = "portrait", name = icon }
	end
	local lower = string.lower(text)
	local function has(words: string): boolean
		return string.find(lower, words, 1, true) ~= nil
	end
	-- a crate first: "Ginger left you a crate!" gives the crate, not the cat
	if has("crate") then
		return { kind = "icon", name = "Crate" }
	end
	local got = string.match(text, "^You got (%w+)!")
	if got and isPortrait(got) then
		return { kind = "portrait", name = got }
	end
	-- any cat or pet named as the notice's first word ("Clover is star 2", "Mochi moved into your window") or
	-- anywhere after "washed " or before " is yours"
	for _, name in
		{
			string.match(text, "^(%w+)") or "",
			string.match(text, "washed (%w+)") or "",
			string.match(text, "(%w+) is yours") or "",
			string.match(text, "get (%w+)$") or "",
			string.match(text, "Index: (%w+)") or "",
		}
	do
		if name ~= "" and isPortrait(name) then
			return { kind = "portrait", name = name }
		end
	end
	if string.match(text, "^Day %d+:") or has("gift") then
		return { kind = "icon", name = "Gift" }
	end
	if has(" bow ") then
		return { kind = "icon", name = "Bow" }
	end
	if has("cat index") then
		return { kind = "icon", name = "Index" }
	end
	if has("works here") or has("helper") then
		return { kind = "icon", name = "Helper" }
	end
	if has("special visitor") then
		return { kind = "icon", name = "Star" }
	end
	if has("is ready") or has("building the") then
		return { kind = "icon", name = "Build" }
	end
	if has("coins") then
		return { kind = "icon", name = "Coins" }
	end
	if has("is yours") then
		return { kind = "icon", name = "Gift" }
	end
	return nil
end

export type Pop = { title: string, sub: string }

-- The big popup's words for a notice that is a reward worth stopping for (issue 1024), or nil for one that stays a
-- small card: a pet, a crate, a gift, a check-in day, something bought or a fuse. Coins, builds and news stay small,
-- they come often. The title is the first sentence, the rest goes under it.
function ToastRules.popOf(text: string, kind: ("info" | "warning")?): Pop?
	if kind == "warning" then
		return nil
	end
	local lower = string.lower(text)
	local big = string.match(text, "^You got %w+!") ~= nil
		or string.find(lower, "crate", 1, true) ~= nil
		or string.find(lower, "is yours", 1, true) ~= nil
		or string.find(lower, "are yours", 1, true) ~= nil
		or string.match(text, "^Day %d+:") ~= nil
		or string.match(text, "^%w+ is star %d+$") ~= nil
		or string.find(lower, "cat index complete", 1, true) ~= nil
	if not big or string.find(lower, "no crate", 1, true) ~= nil then
		return nil
	end
	local title, rest = string.match(text, "^(.-[!%.])%s+(.+)$")
	if title == nil or rest == nil then
		title, rest = string.match(text, "^(Day %d+:)%s*(.+)$")
	end
	if title and rest then
		-- the popup closes on any tap, so it never says "tap it": it says where the crate is (Review-QA on #1026)
		if string.match(rest, "^Tap ") and string.find(lower, "crate", 1, true) ~= nil then
			rest = "It's waiting on your spa floor"
		end
		return { title = title, sub = rest }
	end
	return { title = text, sub = "" }
end

return table.freeze(ToastRules)
