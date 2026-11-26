--!strict
-- ToastRules: the short notices as small cards (UI/ToastCard, switch toastCards, issue 877) and which kind of card a
-- notice gets. Pure, so tests/specs/ToastRules.spec.luau covers it.
local ToastRules = {}

ToastRules.FLAG = "toastCards"

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

return table.freeze(ToastRules)
