--!strict
-- LiveFlags: live on/off switches, so a feature can be turned on or off in every running server within about
-- a minute, with no publish and no restart. Each switch is one boolean entry in the DataStore named STORE.
-- The flags workflow (tools/opencloud/flags.sh) writes them; LiveFlagService reads them every CHECK_SECONDS
-- and copies each to a ReplicatedStorage attribute (ATTRIBUTE_PREFIX .. key) so client code can read it too.
--
-- Two kinds of switch:
-- - A plain key in KEYS is ON unless the store says an explicit false. A missing entry, a wrong type or a
--   failed read leaves it on, so a broken store can never switch the game off. Use it as a kill switch.
-- - A key also listed in OFF_BY_DEFAULT is OFF unless the store says an explicit true, so a missing entry or
--   a broken store never switches it on. New features ship this way: merged and published while off, then
--   turned on with the flags workflow, with the off switch kept for instant rollback.
--
-- Keep one key per line in the shape below: flags.sh reads the names straight from this file.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlags = {}

LiveFlags.STORE = "CleanACat_Flags"
LiveFlags.ATTRIBUTE_PREFIX = "LiveFlag_"
LiveFlags.CHECK_SECONDS = 60

LiveFlags.KEYS = {
	"exampleFeature", -- an example to copy: say what the switch does and which module reads it; off by default
	"scrubPrototype", -- the scrub and reveal prototype (Controllers/ScrubController); off by default
	"scrubEffects", -- foam and mud particles while scrubbing (Controllers/EffectsController); off by default
	"revealEffects", -- sparkles and water droplets when a cat comes clean (Controllers/EffectsController); off by default
	"fluffEffects", -- fur puffs, the fluffed glow and bow hearts (Controllers/EffectsController); off by default
	"catMotion", -- cat idle, blink, ear twitch, shake-off and happy wiggle (Effects/CatMotion); off by default
	"dryEffects", -- warm air wisps from the dryer nozzle (Controllers/EffectsController); off by default
	"toolsBoard", -- the Tools board and Bubble Soap (ToolService, Controllers/ToolsBoardController); off by default
	"customers", -- customers at the door bring rolled cats and pay on return (SpaService, Controllers/DoorController); off by default
	"strays", -- strays, the display window and its tips (SpaService, WindowService, Controllers/WindowController); off by default
	"catIndex", -- Cat Index stamps and the full set bonus (IndexService, Controllers/IndexController); off by default
	"builds", -- station and room builds with timers that run while away (BuildService, Controllers/BuildBoardController); off by default
	"spaPlot", -- the spa plot in Workspace and every spot on it (PlotService, Shared/SpaLayout); off by default
	"onboardingFunnel", -- the onboarding_v1 funnel and its side events (Telemetry, FunnelService); off by default
	"scrubTurn", -- the cat turns in the tub to show its muddy side (Controllers/ScrubController); off by default
	"longBuildOffer", -- the bell on long builds and the build finished notification (NotifyService, BuildBoardController); off by default
	"spaVisitors", -- players may walk into other players' spas; off means look only (Controllers/PlotController); off by default
	"stations", -- built stations and build pads in the player's plot, and the dry step (StationService, ScrubController); off by default
	"customerFigures", -- real customers holding carriers at the door, drawn by the server (FigureService, DoorController); off by default
}

LiveFlags.OFF_BY_DEFAULT = {
	exampleFeature = true,
	scrubPrototype = true,
	scrubEffects = true,
	revealEffects = true,
	fluffEffects = true,
	catMotion = true,
	dryEffects = true,
	toolsBoard = true,
	customers = true,
	strays = true,
	catIndex = true,
	builds = true,
	spaPlot = true,
	onboardingFunnel = true,
	scrubTurn = true,
	longBuildOffer = true,
	spaVisitors = true,
	stations = true,
	customerFigures = true,
} :: { [string]: boolean }

-- What a stored value means for a key. `stored` is whatever the DataStore returned (nil when missing).
function LiveFlags.resolve(key: string, stored: unknown): boolean
	if LiveFlags.OFF_BY_DEFAULT[key] then
		return stored == true
	end
	return stored ~= false
end

-- Is the switch on right now? Works on the server and the client. Before LiveFlagService's first read the
-- attribute is missing, which gives each switch its default.
function LiveFlags.isOn(key: string): boolean
	return LiveFlags.resolve(key, ReplicatedStorage:GetAttribute(LiveFlags.ATTRIBUTE_PREFIX .. key))
end

return LiveFlags
