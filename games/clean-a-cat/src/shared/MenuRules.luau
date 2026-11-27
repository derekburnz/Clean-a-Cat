--!strict
-- MenuRules: the switch menuOnly (issues 1028 and 1033, Derek's playtest of 2026-11-27: "too many options that can be
-- done in person that should be through menu" and "hiring sam pad shouldn't even exist"). With it on, a choice that
-- has a menu is made only in that menu, and the room keeps the prompts that are a physical act (picking up a cat, the
-- tub, the crate, the tip jar, the gift stand). Each part goes only while the window that takes over is on, so a
-- player is never left with no way to do it:
--
--   helpers   (helpersWindow) no hire pads, and no Hire or Takes prompt at a stand: hire and Takes in the Helpers
--             window; the server takes a hire from anywhere
--   build     (buildWindow) the Tools board and the builder board lose their Buy and Build prompts; a running
--             build keeps its own prompt (its countdown and Finish now) and the bell stays
--   queue     (queueWindow) no Wash next prompts over the waiting customers: Who's next? picks
--
-- A guide card whose "Show me" walked to one of those (BubbleRules) opens its window instead (windowFor).
-- Pure, so tests/specs/MenuRules.spec.luau covers it.
local MenuRules = {}

MenuRules.FLAG = "menuOnly"
MenuRules.HELPERS_FLAG = "helpersWindow" -- HelperViewRules.FLAG
MenuRules.BUILD_FLAG = "buildWindow" -- BuildViewRules.FLAG
MenuRules.QUEUE_FLAG = "queueWindow" -- QueueWindowController's
MenuRules.FLAGS = table.freeze({
	MenuRules.FLAG,
	MenuRules.HELPERS_FLAG,
	MenuRules.BUILD_FLAG,
	MenuRules.QUEUE_FLAG,
})

type IsOn = (flag: string) -> boolean

-- Helpers are hired and their Takes set in the Helpers window only.
function MenuRules.helpers(isOn: IsOn): boolean
	return isOn(MenuRules.FLAG) and isOn(MenuRules.HELPERS_FLAG)
end

-- Builds, tools and bows are bought in the Build window only.
function MenuRules.build(isOn: IsOn): boolean
	return isOn(MenuRules.FLAG) and isOn(MenuRules.BUILD_FLAG)
end

-- The next customer is picked in Who's next? only.
function MenuRules.queue(isOn: IsOn): boolean
	return isOn(MenuRules.FLAG) and isOn(MenuRules.QUEUE_FLAG)
end

-- The guide cards (BubbleRules ids) whose "Show me" opens a window under menuOnly, and the window each opens.
MenuRules.CARD_WINDOWS = table.freeze({
	hireJo = "Helpers",
	newSoap = "Build",
	wetCat = "Build",
	build = "Build",
	longBuild = "Build",
	longBuildTub = "Build",
}) :: { [string]: string }

-- The window guide card `id` opens instead of its floor trail, or nil when it keeps the trail.
function MenuRules.windowFor(id: string, isOn: IsOn): string?
	local window = MenuRules.CARD_WINDOWS[id]
	if window == "Helpers" and MenuRules.helpers(isOn) then
		return window
	elseif window == "Build" and MenuRules.build(isOn) then
		return window
	end
	return nil
end

return MenuRules
