--!strict
-- The one list of RemoteEvents. The server (NetService) creates them in ReplicatedStorage.Remotes at start;
-- the client waits for them. Every client -> server call is validated and rate limited in NetService.
-- Write each remote's arguments and what the server checks beside its name, so a reviewer can compare.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.FolderName = "Remotes"

-- Client -> server: (args) and what the server checks.
Remotes.ClientToServer = {
	"Ping", -- ()  an example to copy: no arguments, 2 a second at most
	-- Spa loop (SpaService, behind scrubPrototype). catId must be the player's current cat; order and timing are
	-- SpaRules' checks on the server. seq numbers the client's reports; the server echoes it in CatStage.
	"RequestCat", -- ()  1 a second; resends the current dirty cat or hands out a new one
	"ReportScrubbed", -- (catId: int, seq: int)  2 a second; dirty -> clean
	"ReportBrushStroke", -- (catId: int, seq: int)  8 a second; counts toward SpaRules.BRUSH_STROKES
	"RequestPickBow", -- (catId: int, seq: int, bowId: one of SpaRules.BOWS)  2 a second; fluffed -> styled
	"RequestPhoto", -- (catId: int, seq: int)  2 a second; styled -> done and pays once, no sooner than MIN_VISIT_SECONDS
	"RequestPickCustomer", -- (index: int 2..SpaRules.QUEUE_SIZE)  1 a second; switches scrubPrototype, customers and
	-- queuePick on; moves that customer to the front of the door line and nothing else (SpaRules.pickNext)
	"RequestOpenBox", -- ()  1 a second; switches scrubPrototype, sudsWash and openingBox on, save loaded, and the server
	-- holding the kitten back for the box (SudsRules.waitsForBox): marks the box opened; the player then carries him
	"RequestPlaceKitten", -- ()  1 a second; the box opened this session and not yet handed out (SudsBox false), no cat
	-- out, and the player's character within SudsRules.PLACE_REACH studs of their tub: hands the kitten to the tub
	-- Carrying a customer's cat in (SpaService, switches scrubPrototype and customerCarry; CarryRules).
	"RequestTakeCat", -- ()  1 a second (burst 2); the cat is with the front customer (CarryCat "door") and the player's
	-- character within CarryRules.TAKE_REACH studs of SpotQueue1: the cat goes into their arms (CarryCat "arms")
	"RequestPlaceCat", -- ()  1 a second (burst 2); the cat is in their arms (CarryCat "arms") and the character within
	-- CarryRules.PLACE_REACH studs of their tub: the cat is in the tub and CatReady follows
	-- Tools board (ToolService, behind toolsBoard).
	"RequestBuyTool", -- (toolId: one of ToolRules.IDS)  1 a second; switch on, save loaded, near the board, enough coins, not owned
	-- Builds (BuildService, behind builds).
	"RequestBuild", -- (id: one of BuildRules.IDS)  1 a second; switch on, save loaded, near the board, slot free, order, coins
	-- Funnel (FunnelService, behind onboardingFunnel).
	"ReportStep", -- (step: one of TelemetryRules.CLIENT_STEPS) or (name, detail: a pair in TelemetryRules.CLIENT_EVENTS)
	-- 2 a second (burst 4); logged once per save (first_move also once per session as playtime_v1's moved), side
	-- events only in the save's first session; nothing else changes
	-- Build notification (NotifyService, behind longBuildOffer).
	"ReportOptIn", -- (result: one of NotifyRules.RESULTS)  1 a second; logged as notify_opt_in, nothing else changes
	-- Suds's help bubble (BubbleService, behind sudsBubble).
	"ReportBubbleSeen", -- (id: one of BubbleRules.IDS)  2 a second; switch on, save loaded; marks that bubble shown in the
	-- save so it never shows again, nothing else changes
}

-- Server -> client.
Remotes.ServerToClient = {
	"Notice", -- (kind: "info" | "warning", text: string)  a short line the client shows as a toast
	"CatReady", -- (catId: number, kind: string?, needs: { CatRules.Need }?, locked: { CatRules.Need }?, stray: boolean?, brushStrokes: number, dirt: number?)
	-- a dirty cat is in the tub; kind and needs come with a customer's cat or a stray, locked lists needs whose station
	-- is not built, stray is true for a stray (switch strays) that moves into the window once clean; kind is SudsRules.NAME
	-- for the opening's kitten (switch sudsWash), who skips the bows; dirt is the cat's dirt level 1 to 4 (switch dirtLevels): the
	-- client takes off the mud and tangle pieces above it
	"CustomerQueue", -- (kinds: { string }, needs: { { string } }, dirt: { number }?)  the cats waiting at the door, front first, what each needs and, with dirtLevels on, each one's dirt level (switch customers)
	"Residents", -- (list: { { cat: string, bow: string? } })  the display window's cats, in order (switch strays)
	"WindowTips", -- (coins: number, total: number)  window cats tipped; total is the save's coins (switch strays)
	"CatIndex", -- (index: { [cat]: { washed: boolean, resident: boolean } })  the stamped cats (switch catIndex)
	"Builds", -- (builds: { [slot]: { item, endsAt } }, built: { string }, serverNow: number)  for the board and countdowns
	"BuildFinished", -- (id: string)  a build just finished, or finished while the player was away: celebrate (switch builds)
	"PhotoPaid", -- (catId: number, coins: number, total: number, recap: RecapRules.Recap?)  the photo paid; total is the save's coins; recap for a customer, or the kitten's score card (mascot), while recapCard is on
	"CatStage", -- (catId: number, seq: number, stage: SpaRules.Stage, strokes: number, photoWaiting: boolean)  the server's view
	-- after every spa report, so a client whose step was refused falls back to it instead of getting stuck
}

function Remotes.folder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if existing ~= nil then
		return existing :: Folder
	end
	return ReplicatedStorage:WaitForChild(Remotes.FolderName) :: Folder
end

function Remotes.event(name: string): RemoteEvent
	return Remotes.folder():WaitForChild(name) :: RemoteEvent
end

return Remotes
