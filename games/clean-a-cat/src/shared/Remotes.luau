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
	"RequestTakeCat", -- (place: int?)  1 a second (burst 2); the next cat is with the front customer (CarryCat "door")
	-- and the player's character within CarryRules.TAKE_REACH studs of SpotQueue1, or with counterLine on of the cat at
	-- counter place `place` (1 to SpaRules.MAX_QUEUE + 1 of the line as shown; nil is 1): that cat goes into their arms
	-- (CarryCat "arms"). A place past 1 needs counterLine and a served customer (stars > 0), and is a pick: the front
	-- customer's cat goes back on the counter at the front of the line (CounterRules.swapIn)
	"RequestPlaceCat", -- ()  1 a second (burst 2); the cat is in their arms (CarryCat "arms") and the character within
	-- CarryRules.PLACE_REACH studs of their tub: the cat is in the tub and CatReady follows
	-- Tools board (ToolService, behind toolsBoard).
	"RequestBuyTool", -- (toolId: one of ToolRules.IDS)  1 a second; switch on, save loaded, near the board (or anywhere
	-- with buildWindow), enough coins, not owned
	"RequestBuyBow", -- (tier: one of BowRules.TIERS)  1 a second; switches toolsBoard and bowTiers on, save loaded, near
	-- the board (or anywhere with buildWindow), the next tier in order, enough coins
	-- Workers (WorkerService, behind workers, scrubPrototype and customers). Each needs the save loaded; hiring also
	-- needs the character within WorkerRules.SERVER_REACH studs of that worker's pad (mode and level come from the HUD).
	"RequestHireWorker", -- (id: one of WorkerRules.IDS)  1 a second; near the pad, not a pass worker, not hired, coins
	"RequestWorkerMode", -- (id, mode: one of WorkerRules.MODES)  2 a second; the worker is hired
	"RequestWorkerLevel", -- (id)  1 a second; the worker is hired, below the top level, enough coins
	-- Crates and pets (PetService, behind pets). Every pet id must be one of the player's own.
	"RequestOpenCrate", -- (kind: one of CrateRules.KINDS)  1 a second; the save holds one: the pet is rolled and kept
	"RequestPlacePet", -- (petId: int, slot: string?)  2 a second; one of CrateRules.slots, or nil for the pen
	"RequestFusePets", -- (a: int, b: int, c: int)  1 a second; three different pets, same kind and star, below star 3
	-- Builds (BuildService, behind builds).
	"RequestBuild", -- (id: one of BuildRules.IDS)  1 a second; switch on, save loaded, near the board (or anywhere with
	-- buildWindow), slot free, order, coins
	"RequestFinish", -- (slot: one of BuildRules.SLOTS)  1 a second; switches builds and finishNow on, save loaded, near the
	-- board, a build running there with FinishRules.HIDE_UNDER seconds or more left: a saved credit that covers its
	-- tier finishes it at once, else Roblox's purchase prompt opens for that tier (PurchaseService grants it)
	-- Tip jar (JarService, behind tipJar).
	"RequestCollectJar", -- ()  1 a second; switch on, save loaded, the character within JarRules.SERVER_REACH studs of the
	-- player's SpotTipJar, coins in the jar: pays them and empties the jar
	-- Check in card (CheckinService, behind checkinCard).
	"RequestCheckin", -- ()  1 a second; switch on, save loaded, today's day not taken yet (and for a save that never
	-- took one, 3:45 of play): gives that day's reward once
	"ReportTimeZone", -- (hours: int -12..14)  1 a second; switch on, save loaded, no time zone saved yet: saves it once
	-- Game passes (PassService, behind passes).
	"RequestPass", -- (key: one of Passes.KEYS)  1 a second; switch on, save loaded, the pass created and priced, not
	-- owned yet: opens Roblox's purchase prompt for it (the only way one opens)
	-- Robux crates (CrateShopService, behind crateShop and pets).
	"RequestBuyCrate", -- (key: one of CrateRules.SHOP_KEYS)  1 a second; switches on, save loaded, this player's
	-- PolicyService info allows paid random items, the product created and priced: opens Roblox's purchase prompt
	-- Starter pack (StarterService, behind starterPack and passes).
	"RequestStarter", -- ()  1 a second; switches on, save loaded, the pack offered (StarterRules.offered) and its product
	-- created and priced: opens Roblox's purchase prompt for it (PurchaseService grants it)
	"RequestStarterOpened", -- ()  1 a second; switch on, save loaded: the player opened the pack window, saved once
	-- Gift stand (GiftService, behind giftStand and pets).
	"RequestGiftFavourite", -- (favourited: true)  1 a second; switches on, save loaded: the player's own favourite prompt
	-- said yes (the device tells it; trusted for this one free pet), saved once
	"RequestGiftCheck", -- ()  1 every 2 s; switches on: asks Roblox whether the player is in the group, shown as GiftGroup
	"RequestGiftClaim", -- ()  1 every 2 s; switches on, save loaded, the stand lit for this player, the favourite saved
	-- and the player in the group (asked again on the server): gives Starcoat once and writes the save
	-- Free Rewards rows on the gift card (FreeRewardService, behind freeRewards, giftStand and pets).
	"ReportAsk", -- (id: string, answer: "yes" | "no" | "closed" | nil)  2 a second; an AskRules id the queue showed
	-- (answer nil) or that was answered: logged as ask_shown / ask_answered, at most 60 a visit (AskReportService)
	"RequestLikeAsk", -- ()  1 a second; switches on, save loaded, never asked and not paid: stamps likeAskedAt once
	-- (server os.time()); FreeLikeReadyAt shows when Claim unlocks. The like itself is never read or needed
	"RequestLikeAnswer", -- (answer: "yes" | "no" | "closed")  1 a second; likeAsk on and the ask due (LikeAskDue):
	-- clears it; "no" saves the visit, so it is not asked again for three visits (LikeAskService)
	"RequestFreeReward", -- (key: "like" | "play")  1 a second; switches on, save loaded, that row not paid yet; like:
	-- asked FreeRewardRules.LIKE_WAIT (10) or more seconds ago, pays 150 coins; play: 1800 s of play in total, gives
	-- one normal crate. Each once per save
	-- Visiting (VisitService, behind visiting).
	"RequestVisiting", -- (allowed: boolean)  1 a second; switch on, save loaded: the owner lets other players into
	-- their spa or not (save.visiting); while not, visitors inside are moved out
	-- Staff names (StaffNameService, behind staffRename).
	"RequestRenameStaff", -- (workerId: one of WorkerRules.IDS, text: string of at most 100)  1 a second; switch on, save
	-- loaded, that worker hired: the cleaned name (StaffNameRules.clean; "" is the default) is saved raw and shown only
	-- after Roblox's text filter
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
	"CustomerQueue", -- (kinds: { string }, needs: { { string } }, dirt: { number }?, hearts: { { number } }?)  the cats waiting at the door, front first, what each needs, with dirtLevels on each one's dirt level, and with heartBar on each one's heart bar { since, lasts, stops, paused } in server time (switch customers)
	"CustomerLeft", -- (place: number, kind: string)  the customer at that place of the line as shown left with their cat, their heart bar empty (switch heartBar); sent before the line is redrawn
	"Residents", -- (list: { { cat: string, bow: string? } })  the display window's cats, in order (switch strays)
	"WindowTips", -- (coins: number, total: number)  window cats tipped; total is the save's coins (switch strays)
	"CatIndex", -- (index: { [cat]: { washed: boolean, resident: boolean } })  the stamped cats (switch catIndex)
	"Builds", -- (builds: { [slot]: { item, endsAt } }, built: { string }, serverNow: number, credits: { [tier]: count })  for the
	-- board and countdowns; credits are the Finish now credits by tier "1" to "5" (empty while finishNow is off)
	"BuildFinished", -- (id: string)  a build just finished, or finished while the player was away: celebrate (switch builds)
	"PhotoPaid", -- (catId: number, coins: number, total: number, recap: RecapRules.Recap?)  the photo paid; total is the save's coins; recap for a customer, or the kitten's score card (mascot), while recapCard is on
	"Quests", -- (quests: { { id, text, goal, progress, coins, weekly: boolean, done: boolean } }, weeklyCrate: boolean)  the open
	-- quests, today's daily ones first, and whether this week's crate is taken (switch quests)
	"CrateOpened", -- (kind: string, pet: { id, kind, star })  the crate the player tapped and the pet in it (switch pets)
	"HelperPaid", -- (id: one of WorkerRules.IDS, coins: number)  that helper just finished a cat and paid this many coins
	-- into the save: a popup over their stand, only for the owner (switch helperPopups, issue 743)
	"PetFused", -- (pet: { id, kind, star })  three pets fused into this one, a star higher (switch pets)
	"Pets", -- (pets: { { id, kind, star, slot? } })  every pet the player owns, after each change (switch pets)
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
