--!strict
-- SpaLayout: where each gameplay spot is (the tub, the spawn, the customer line, the window, the boards), on the
-- server and the client. While the street is placed (PlotService, behind the LiveFlags switch `spaPlot`), every
-- player has their own spa plot (#88): PLOT_COUNT plots side by side, the player's slot in the Player attribute
-- SLOT_ATTRIBUTE. A spot is then Model-Agent's Attachment of the same name in that player's plot, read as its
-- WorldCFrame. Otherwise it is the old placeholder room's spot, so turning the switch off gives back exactly the
-- world before the plot. On the client a spot is the local player's; the server passes the player it acts for.
--
-- Every spot faces the way the thing there faces: a model's front (-Z, its LookVector) points along the spot's
-- LookVector. Each spot is where the base of the thing there sits.
--
--   SpaLayout.spot(name, player?): CFrame        the spot in the world right now
--   SpaLayout.lineSpot(prefix, index, player?)   SpotQueue<index> or SpotWindow<index>; past the last one, the
--                                                line goes on
--   SpaLayout.onPlot(player?): boolean           is the player's plot placed?
--   SpaLayout.changed(fn)                        fn() when the local player's plot comes or goes (redraw)
--   SpaLayout.prop(name, player?): Model?        a fixed prop PlotService placed with the plot (PROPS), or nil
--   SpaLayout.station(id, player?): Model?       a built station in the player's plot (STATIONS), or nil
--   SpaLayout.slotSpot(name, slot): CFrame       a spot in plot `slot`, whoever has it (the server places with it)
--   SpaLayout.tubSpot(player?), slotTubSpot(slot) where the wash tub stands; with `spawnView` on it is turned to
--                                                face into the spa, where the player spawns (#169)
--   SpaLayout.spawnSpot(slot): CFrame            where a character in plot `slot` spawns (feet, facing)
--   SpaLayout.place(name, onPlot, slot?)         the pure part: (position, yaw) from the tables below; specs
--   SpaLayout.slotPivot(slot)                    where plot `slot`'s pivot goes; specs
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlags = require(script.Parent.LiveFlags)

local SpaLayout = {}

SpaLayout.FLAG = "spaPlot"
SpaLayout.ASSET = "CleanACat_Area_SpaPlot" -- ReplicatedStorage.Assets.<ASSET>, placed in Workspace under this name
SpaLayout.PLACED_ATTRIBUTE = "SpaPlotPlaced" -- ReplicatedStorage attribute: true while the plot is in Workspace
-- Where the plot's pivot (the plot centre on the ground, street side -Z) goes. This keeps the tub where the
-- placeholder room had it, (0, 0, -12) on the ground.
SpaLayout.PIVOT_POSITION = Vector3.new(-5, 0, -10)
-- The street (#88): PLOT_COUNT plots in a row along X, PLOT_SPACING studs from pivot to pivot. Slot 1 is at
-- PIVOT_POSITION; the others go out on both sides (2 right, 3 left, 4 further right...). Placeholder values until
-- design sets the server size (it must match the experience's max players) and Model-Agent the spacing.
SpaLayout.PLOT_COUNT = 6
SpaLayout.PLOT_SPACING = 44
SpaLayout.PLOTS_FOLDER = "SpaPlots" -- Workspace.SpaPlots.Plot<slot>
SpaLayout.SLOT_ATTRIBUTE = "SpaPlot" -- Player attribute: the player's slot, 1 to PLOT_COUNT
SpaLayout.STREET_ASSET = "CleanACat_Area_Street" -- the street under the plots; its pivot is slot 1's pivot
-- (switch bigSpa, issue 746) Model-Agent's bigger spa: a roomier building with the counter window, on a wider street.
-- PlotService reads the switch when it places the street and says which it placed with BIG_ATTRIBUTE, which everything
-- here follows, so server and clients agree even if the switch moves later (it takes effect on the next placement,
-- such as a server restart). A missing big asset keeps the small spa.
SpaLayout.BIG_FLAG = "bigSpa"
SpaLayout.BIG_ATTRIBUTE = "SpaBig" -- ReplicatedStorage attribute: true while the big plots are the placed ones
SpaLayout.BIG_ASSET = "CleanACat_Area_SpaPlotBig"
SpaLayout.BIG_STREET_ASSET = "CleanACat_Area_StreetBig"
SpaLayout.BIG_BACKDROP_ASSET = "CleanACat_Area_BackdropBig"
SpaLayout.BIG_PLOT_SPACING = 56
-- The small spa's props the big one does without: its counter mats are part of the plot, so no mats in the street
SpaLayout.BIG_SKIPS_PROPS =
	table.freeze({ QueueMat1 = true, QueueMat2 = true, QueueMat3 = true }) :: { [string]: boolean }

export type Spot = { position: Vector3, yaw: number }

local function at(x: number, y: number, z: number, yaw: number): Spot
	local spot: Spot = { position = Vector3.new(x, y, z), yaw = yaw }
	return spot
end

local TURNED = math.pi -- a half turn: faces +Z

-- The plot's spots relative to its pivot, matching the Attachments in CleanACat_Area_SpaPlot (y is the height
-- above the pivot: the floor top is 0.5). Used when an Attachment is missing, and before the plot replicates.
-- Keep these in step with the model.
SpaLayout.PLOT_SPOTS = table.freeze({
	SpotTub = at(5, 0.5, -2, 0),
	SpotSpawn = at(5, 0.5, -8.5, TURNED),
	SpotQueue1 = at(-5, 0.5, -13, TURNED),
	SpotQueue2 = at(-5, 0.5, -17.5, TURNED),
	SpotQueue3 = at(-5, 0.5, -21.5, TURNED),
	SpotStray = at(16.4, 0.5, 7.6, math.pi / 2), -- by the side wall, facing the room (PR 684)
	SpotWindow1 = at(14, 3.03, -14.2, 0), -- each window spot is a cushion's base on the window seat
	SpotWindow2 = at(11, 3.03, -14.2, 0),
	SpotWindow3 = at(8, 3.03, -14.2, 0),
	SpotWindow4 = at(5, 3.03, -14.2, 0),
	SpotTipJar = at(2.4, 3.03, -14.2, 0),
	SpotSign = at(-13.5, 6.5, -17, 0), -- the spa sign on the front wall, its back on the wall
	SpotBuilder = at(-13, 0.5, 6, 0),
	SpotStation2 = at(-7, 0.5, -1, 0),
	SpotStation3 = at(-13.5, 0.5, -1, 0),
	SpotStation4 = at(15.2, 0.5, 1, 0), -- the Bubble Bath, against the wall on the tub's side (#267, #276)
	SpotStation5 = at(15.2, 0.5, -6.6, 0), -- the Pawdicure, in front of it
	SpotVipDoor = at(-7, 0.5, 10.5, 0),
	SpotGardenDoor = at(12, 0.5, 10.5, 0), -- the back door to the Garden (GardenRules, Model-Agent's #579)
	SpotBoard = at(-13.5, 0.5, -14.6, TURNED),
	-- The opening (#285, Model-Agent): the player stands mid-entrance facing the street, the box lands in front on the
	-- near pavement, and the truck hits the bump across the near lane.
	SpotOpening = at(-5, 0.5, -27, 0),
	-- Derek 2026-11-24 3:34 PM ET: a pothole "closer to being right infront of you" and the box tumbling in front of
	-- the player. The truck drops into the pothole 2.5 studs up the road from the player; the box falls out, rolls a
	-- whole turn (about 8 studs) past in front of them and stops 5 studs to their right (TruckDrop.BUMP_X = -7.5,
	-- Motion-FX and Model-Agent). A quarter turn lies the pothole across the lane.
	SpotBox = at(0, 0.5, -30.6, 0),
	SpotBump = at(-7.5, 0.22, -37.6, math.pi / 2),
	SpotMascot = at(-10.25, 0.5, -14.3, math.rad(230)), -- Suds's bed right of the door, looking at the tub (#285, Model-Agent)
	-- Not in the model: the Tools board stands on the floor left of the tub, facing the spawn.
	Tools = at(-1, 0.5, -2, 0),
	-- The workers' wash stands along the back wall, 4 studs apart (WorkerRules, issue 509; Model-Agent's plot
	-- Attachments SpotWorkerJo, Sam and Lou).
	SpotWorkerJo = at(-1, 0.5, 6.5, 0),
	SpotWorkerSam = at(3, 0.5, 6.5, 0),
	SpotWorkerLou = at(7, 0.5, 6.5, 0),
	-- The gift stand (GiftService, issue 521): Model-Agent's plot Attachment SpotGift, against the right wall near
	-- the door, facing into the room.
	SpotGift = at(-16.4, 0.5, -11.8, -math.pi / 2),
	-- Not in the model: where a crate the player holds waits, on the floor right of the spawn, well away from the
	-- Tools board and the door so its prompt never sits on theirs (bug hunt B7, #648).
	Crate = at(10, 0.5, -8.5, 0),
	-- Not in the model: the bench's places 4 to 6 once tubs are built (switch benchGrow, issue 515), along the pavement
	-- beside the line's last mat. Model-Agent may move them when the extra mats are modelled.
	SpotBench4 = at(-1, 0.5, -21.5, TURNED),
	SpotBench5 = at(3, 0.5, -21.5, TURNED),
	SpotBench6 = at(7, 0.5, -21.5, TURNED),
}) :: { [string]: Spot }

-- Model-Agent's fixed props, placed with the plot (PlotService) into its PROPS_FOLDER, each with its pivot (its
-- base, or for the sign its back) on its spot.
export type Prop = { name: string, asset: string, spot: string }
SpaLayout.PROPS_FOLDER = "Props"
SpaLayout.PROPS = table.freeze({
	{ name = "QueueMat1", asset = "CleanACat_Prop_QueueMat", spot = "SpotQueue1" },
	{ name = "QueueMat2", asset = "CleanACat_Prop_QueueMat", spot = "SpotQueue2" },
	{ name = "QueueMat3", asset = "CleanACat_Prop_QueueMat", spot = "SpotQueue3" },
	{ name = "StrayBox", asset = "CleanACat_Prop_StrayBox", spot = "SpotStray" },
	{ name = "Cushion1", asset = "CleanACat_Prop_Cushion", spot = "SpotWindow1" },
	{ name = "Cushion2", asset = "CleanACat_Prop_Cushion", spot = "SpotWindow2" },
	{ name = "Cushion3", asset = "CleanACat_Prop_Cushion", spot = "SpotWindow3" },
	{ name = "Cushion4", asset = "CleanACat_Prop_Cushion", spot = "SpotWindow4" },
	{ name = "TipJar", asset = "CleanACat_Prop_TipJar", spot = "SpotTipJar" },
	{ name = "WindowSign", asset = "CleanACat_Prop_WindowSign", spot = "SpotSign" },
}) :: { Prop }

-- Stations a player builds (BuildRules ids), each on its spot in the owner's plot, in the plot's
-- STATIONS_FOLDER (StationService). Before it is built the spot holds PAD_ASSET with its name and price.
export type Station = { id: string, asset: string, spot: string }
SpaLayout.STATIONS_FOLDER = "Stations"
SpaLayout.PAD_ASSET = "CleanACat_Prop_BuildPad"
SpaLayout.STATIONS = table.freeze({
	{ id = "BrushTable", asset = "CleanACat_Station_BrushTable", spot = "SpotStation2" },
	{ id = "Dryer", asset = "CleanACat_Station_Dryer", spot = "SpotStation3" },
	-- #267: drawn only while their BuildRules switch (bubbleBath, pawdicure) is on
	{ id = "BubbleBath", asset = "CleanACat_Station_BubbleBath", spot = "SpotStation4" },
	{ id = "Pawdicure", asset = "CleanACat_Station_Pawdicure", spot = "SpotStation5" },
	-- issue 515 (switch tubBuilds, with dirtLevels): the tubs stand where the old stations did, which are gone then
	{ id = "SecondTub", asset = "CleanACat_Station_Tub", spot = "SpotStation2" },
	{ id = "ThirdTub", asset = "CleanACat_Station_Tub", spot = "SpotStation3" },
	{ id = "FourthTub", asset = "CleanACat_Station_Tub", spot = "SpotStation4" },
}) :: { Station }
-- The VIP Room's door at SpotVipDoor until the room is built: VIP_LOCKED_ASSET before its build starts,
-- VIP_BUILDING_ASSET while it runs, nothing once it is done (StationService).
SpaLayout.VIP_ID = "VipRoom"
SpaLayout.VIP_SPOT = "SpotVipDoor"
SpaLayout.VIP_LOCKED_ASSET = "CleanACat_Area_VipLocked"
SpaLayout.VIP_BUILDING_ASSET = "CleanACat_Area_VipBuilding"
-- The builder kitten (#20) stands beside the builder board at SpotBuilder, the toolbox beside it.
SpaLayout.BUILDER_SPOT = "SpotBuilder"
SpaLayout.KITTEN_OFFSET = Vector3.new(4, 0, 0) -- in the spot's frame
SpaLayout.TOOLBOX_OFFSET = Vector3.new(5.6, 0, 0.4)

-- The placeholder room before the plot, in world space: the spawn at the origin and everything facing it (+Z).
SpaLayout.ROOM_SPOTS = table.freeze({
	SpotTub = at(0, 0, -12, TURNED),
	SpotSpawn = at(0, 0.5, 0, 0),
	SpotQueue1 = at(8, 0, -8, TURNED),
	SpotQueue2 = at(11, 0, -8, TURNED),
	SpotQueue3 = at(14, 0, -8, TURNED),
	SpotWindow1 = at(-9, 0, -3, TURNED),
	SpotWindow2 = at(-6.6, 0, -3, TURNED),
	SpotWindow3 = at(-4.2, 0, -3, TURNED),
	SpotWindow4 = at(-1.8, 0, -3, TURNED),
	SpotBuilder = at(-11, 0, -12, TURNED),
	SpotBoard = at(5, 1, -6, TURNED),
	Tools = at(-6, 0, -12, TURNED),
}) :: { [string]: Spot }

-- (switch bigSpa) The big plot's spots that differ from PLOT_SPOTS, from Model-Agent's CleanACat_Area_SpaPlotBig
-- (PR 753; same pivot as the small plot). Every other spot is where the small plot has it. SpotBench4 to 6 are not in
-- the model: with counterLine the counter's six places hold the whole bench.
SpaLayout.BIG_SPOTS = table.freeze({
	SpotStray = at(22.4, 0.5, 13.6, math.pi / 2),
	SpotStation4 = at(21.2, 0.5, 1, 0),
	SpotStation5 = at(21.2, 0.5, -6.6, 0),
	SpotBuilder = at(-13, 0.5, 12, 0),
	SpotVipDoor = at(-7, 0.5, 16.5, 0),
	SpotGardenDoor = at(12, 0.5, 16.5, 0),
	SpotWorkerJo = at(-1, 0.5, 12.5, 0),
	SpotWorkerSam = at(3, 0.5, 12.5, 0),
	SpotWorkerLou = at(7, 0.5, 12.5, 0),
	SpotWindow1 = at(-21.7, 3.03, -14.2, 0), -- the residents' seat moved to the window left of the entrance
	SpotWindow2 = at(-19.1, 3.03, -14.2, 0),
	SpotWindow3 = at(-16.5, 3.03, -14.2, 0),
	SpotWindow4 = at(-13.9, 3.03, -14.2, 0),
	SpotTipJar = at(1.5, 3.3, -15.0, 0), -- the counter's entrance end
	SpotSign = at(-17.7, 8.7, -17, 0),
	SpotGift = at(-22.4, 0.5, -9.5, -math.pi / 2),
	SpotBoard = at(-23.1, 0.5, -3.5, -math.pi / 2), -- against the side wall, facing across the room
	Tools = at(-1, 0.5, -1, 0), -- left of the tub, 14.6 studs from the counter's first cat (Model-Agent, issue 908)
	-- the counter window (CounterRules, switch counterLine): customers outside facing in, their cats on the counter
	SpotCounter1 = at(3.4, 0.5, -19.4, TURNED),
	SpotCounter2 = at(6.6, 0.5, -19.4, TURNED),
	SpotCounter3 = at(9.8, 0.5, -19.4, TURNED),
	SpotCounter4 = at(13, 0.5, -19.4, TURNED),
	SpotCounter5 = at(16.2, 0.5, -19.4, TURNED),
	SpotCounter6 = at(19.4, 0.5, -19.4, TURNED),
	SpotCounterCat1 = at(3.4, 3.38, -14.9, TURNED),
	SpotCounterCat2 = at(6.6, 3.38, -14.9, TURNED),
	SpotCounterCat3 = at(9.8, 3.38, -14.9, TURNED),
	SpotCounterCat4 = at(13, 3.38, -14.9, TURNED),
	SpotCounterCat5 = at(16.2, 3.38, -14.9, TURNED),
	SpotCounterCat6 = at(19.4, 3.38, -14.9, TURNED),
	SpotCounterCrate1 = at(3.4, 3.3, -16.62, TURNED), -- (counterCrate) where the set-down carrier's pivot goes
	SpotCounterCrate2 = at(6.6, 3.3, -16.62, TURNED),
	SpotCounterCrate3 = at(9.8, 3.3, -16.62, TURNED),
	SpotCounterCrate4 = at(13, 3.3, -16.62, TURNED),
	SpotCounterCrate5 = at(16.2, 3.3, -16.62, TURNED),
	SpotCounterCrate6 = at(19.4, 3.3, -16.62, TURNED),
}) :: { [string]: Spot }

-- Are the big plots the placed ones (switch bigSpa, as PlotService placed them)?
function SpaLayout.big(): boolean
	return ReplicatedStorage:GetAttribute(SpaLayout.BIG_ATTRIBUTE) == true
end

-- The plot's own spot `name` from the tables, for the big plot when `big`: the big plot's where it differs, else the
-- small plot's. Nil for a name neither has (the big plot has no SpotBench4 to 6).
function SpaLayout.plotSpotFor(name: string, big: boolean): Spot?
	if big then
		local moved = SpaLayout.BIG_SPOTS[name]
		if moved then
			return moved
		end
		if string.sub(name, 1, 9) == "SpotBench" then
			return nil
		end
	end
	return SpaLayout.PLOT_SPOTS[name]
end

-- The plot's own spot `name` from the tables, for the street placed now.
function SpaLayout.plotSpot(name: string): Spot?
	return SpaLayout.plotSpotFor(name, SpaLayout.big())
end

-- The pivot-to-pivot step between plots, on the big street when `big`.
function SpaLayout.spacingFor(big: boolean): number
	return if big then SpaLayout.BIG_PLOT_SPACING else SpaLayout.PLOT_SPACING
end

-- The pivot-to-pivot step between plots on the street placed now.
function SpaLayout.spacing(): number
	return SpaLayout.spacingFor(SpaLayout.big())
end

-- Where plot `slot`'s pivot goes: slot 1 at PIVOT_POSITION, then one step right, one left, two right...
function SpaLayout.slotPivot(slot: number): Vector3
	local steps = slot // 2
	local side = if slot % 2 == 0 then 1 else -1
	return SpaLayout.PIVOT_POSITION + Vector3.new(side * steps * SpaLayout.spacing(), 0, 0)
end

-- A spot's world position and yaw from the tables: plot `slot`'s (default 1) while it is placed, else the
-- room's. A spot the room never had uses the plot's. Nil for an unknown name.
function SpaLayout.place(name: string, onPlot: boolean, slot: number?): (Vector3?, number)
	local room = SpaLayout.ROOM_SPOTS[name]
	if not onPlot and room then
		return room.position, room.yaw
	end
	local plot = SpaLayout.plotSpot(name)
	if plot then
		return SpaLayout.slotPivot(slot or 1) + plot.position, plot.yaw
	end
	return nil, 0
end

-- The name of the `index`th spot of a line ("SpotQueue", "SpotWindow"). Past the last listed spot it is the last
-- one, with how many steps further on (0 when listed) and the spot before it, whose gap is one step.
function SpaLayout.lineName(
	prefix: string,
	index: number,
	onPlot: boolean
): (string, number, string)
	local function has(name: string): boolean
		return if onPlot then SpaLayout.plotSpot(name) ~= nil else SpaLayout.ROOM_SPOTS[name] ~= nil
	end
	local last = 0
	while has(prefix .. (last + 1)) do
		last += 1
	end
	if index <= last or last < 2 then
		local name = prefix .. math.max(1, math.min(index, last))
		return name, 0, name
	end
	return prefix .. last, index - last, prefix .. (last - 1)
end

-- The player's slot (the local player on the client), or nil before PlotService gave one.
function SpaLayout.slotOf(player: Player?): number?
	local who = player or Players.LocalPlayer
	local slot = if who then who:GetAttribute(SpaLayout.SLOT_ATTRIBUTE) else nil
	return if type(slot) == "number" then slot else nil
end

local function placed(): boolean
	return ReplicatedStorage:GetAttribute(SpaLayout.PLACED_ATTRIBUTE) == true
end

function SpaLayout.onPlot(player: Player?): boolean
	return placed() and SpaLayout.slotOf(player) ~= nil
end

-- Plot `slot` in Workspace, or nil.
function SpaLayout.plotModel(slot: number): Model?
	local folder = game:GetService("Workspace"):FindFirstChild(SpaLayout.PLOTS_FOLDER)
	local found = if folder then folder:FindFirstChild(`Plot{slot}`) else nil
	return if found and found:IsA("Model") then found :: Model else nil
end

local function placedAttachment(name: string, slot: number): Attachment?
	local plot = SpaLayout.plotModel(slot)
	local found = if plot then plot:FindFirstChild(name, true) else nil
	return if found and found:IsA("Attachment") then found :: Attachment else nil
end

function SpaLayout.prop(name: string, player: Player?): Model?
	local slot = SpaLayout.slotOf(player)
	if slot == nil or not placed() then
		return nil
	end
	local plot = SpaLayout.plotModel(slot)
	local props = if plot then plot:FindFirstChild(SpaLayout.PROPS_FOLDER) else nil
	local found = if props then props:FindFirstChild(name) else nil
	return if found and found:IsA("Model") then found :: Model else nil
end

-- A built station's model in the player's plot (the local player on the client), or nil.
function SpaLayout.station(id: string, player: Player?): Model?
	local slot = SpaLayout.slotOf(player)
	if slot == nil or not placed() then
		return nil
	end
	local plot = SpaLayout.plotModel(slot)
	local folder = if plot then plot:FindFirstChild(SpaLayout.STATIONS_FOLDER) else nil
	local found = if folder then folder:FindFirstChild(id) else nil
	return if found
			and found:IsA("Model")
			and found:GetAttribute("Built") == true
		then found :: Model
		else nil
end

local function spotIn(name: string, slot: number?): CFrame
	local onPlot = slot ~= nil and placed()
	if onPlot then
		local attachment = placedAttachment(name, slot :: number)
		if attachment then
			return attachment.WorldCFrame
		end
	end
	local position, yaw = SpaLayout.place(name, onPlot, slot)
	return CFrame.new(position or Vector3.zero) * CFrame.Angles(0, yaw, 0)
end

function SpaLayout.slotSpot(name: string, slot: number): CFrame
	return spotIn(name, slot)
end

function SpaLayout.spot(name: string, player: Player?): CFrame
	return spotIn(name, SpaLayout.slotOf(player))
end

-- The switch that moves the spawn behind the tub (PlotService) and turns the tub to face it, so the first frame
-- shows the cat's face with the window and the door line beyond (#169).
SpaLayout.VIEW_FLAG = "spawnView"

local function turnedTub(spot: CFrame): CFrame
	if LiveFlags.isOn(SpaLayout.VIEW_FLAG) then
		return spot * CFrame.Angles(0, math.pi, 0)
	end
	return spot
end

-- Where the wash tub stands in plot `slot`: SpotTub, facing the street, or with `spawnView` on facing into the spa.
function SpaLayout.slotTubSpot(slot: number): CFrame
	return turnedTub(spotIn("SpotTub", slot))
end

-- Where the wash tub stands for the player (the local player on the client).
function SpaLayout.tubSpot(player: Player?): CFrame
	return turnedTub(spotIn("SpotTub", SpaLayout.slotOf(player)))
end

-- With `spawnView` on, the player spawns SPAWN_FROM_TUB studs in front of the turned tub and SPAWN_SIDE studs to its
-- side (toward the door line), facing the street. SpotSpawn sits 8 studs inside the front window facing in, so the
-- camera (about 12.5 studs behind) starts outside the window and the first frame is a blur of glass and wall
-- (#169). Here the camera rests inside the spa against the solid back wall, with the window and the door line
-- ahead and the cat's face beside the avatar's shoulder. Facing the street (not the tub) keeps the avatar off the
-- line from the camera to the cat.
SpaLayout.SPAWN_FROM_TUB = 5
SpaLayout.SPAWN_SIDE = 5 -- 4 left the avatar over exactly a quarter of the tub on an iPhone 14 (#169)
-- (switch spawnSide, #670) Facing the street, the camera 12.5 studs behind lands on the back wall only 7 studs back,
-- where the wall art sits at camera height: a returning join or a respawn could start with a picture filling the
-- screen. Turned a quarter to face the door line's side (-X in the plot), the camera rests in open room on the tub's
-- side, more than 12.5 studs from the side wall, with the tub beside the avatar and the door line ahead and left.
SpaLayout.SIDE_FLAG = "spawnSide"

-- Where a character in plot `slot` spawns: the base of its feet and the way it faces. PlotService moves characters
-- here; the client points the camera from it (#188).
function SpaLayout.spawnSpot(slot: number): CFrame
	if LiveFlags.isOn(SpaLayout.VIEW_FLAG) then
		-- The turned tub's front (-Z) faces into the spa: stand in front of it and to its right (+X, the door
		-- line's side of the plot), turned back to face the street.
		-- (switch spawnSide, #670) on the same spot, a quarter turn to face the door line's side of the room instead
		local turn = if LiveFlags.isOn(SpaLayout.SIDE_FLAG) then -math.pi / 2 else math.pi
		return SpaLayout.slotTubSpot(slot)
			* CFrame.new(SpaLayout.SPAWN_SIDE, 0, -SpaLayout.SPAWN_FROM_TUB)
			* CFrame.Angles(0, turn, 0)
	end
	return spotIn("SpotSpawn", slot)
end

-- Where the line's place `index` stands (switch benchGrow): places 4 to 6 on SpotBench<index>, the rest as lineSpot.
function SpaLayout.benchSpot(index: number, player: Player?): CFrame
	local name = `SpotBench{index}`
	if SpaLayout.plotSpot(name) and SpaLayout.onPlot(player) then
		return SpaLayout.spot(name, player)
	end
	return SpaLayout.lineSpot("SpotQueue", index, player)
end

-- The `index`th spot of a line. Past the last listed spot the line goes on, one step (the gap between the last
-- two spots) at a time.
function SpaLayout.lineSpot(prefix: string, index: number, player: Player?): CFrame
	local name, past, before = SpaLayout.lineName(prefix, index, SpaLayout.onPlot(player))
	local cframe = SpaLayout.spot(name, player)
	if past <= 0 then
		return cframe
	end
	return cframe + (cframe.Position - SpaLayout.spot(before, player).Position) * past
end

-- (switch counterLine, issue 746) The plot's Attachment `<prefix><index>` (CounterRules: SpotCounter, SpotCounterCat)
-- in plot `slot`, while the street is placed; nil when the plot has none.
function SpaLayout.counterSpot(prefix: string, index: number, slot: number): CFrame?
	if not placed() then
		return nil
	end
	local attachment = placedAttachment(`{prefix}{index}`, slot)
	if attachment then
		return attachment.WorldCFrame
	end
	-- the big plot's table (its Attachments may not have replicated yet); the small plot has no counter
	local spot = if SpaLayout.big() then SpaLayout.BIG_SPOTS[`{prefix}{index}`] else nil
	if spot then
		return CFrame.new(SpaLayout.slotPivot(slot) + spot.position) * CFrame.Angles(0, spot.yaw, 0)
	end
	return nil
end

-- fn() when the street is placed or taken away, or the local player gets their slot.
function SpaLayout.changed(fn: () -> ())
	ReplicatedStorage:GetAttributeChangedSignal(SpaLayout.PLACED_ATTRIBUTE):Connect(fn)
	local player = Players.LocalPlayer
	if player then
		player:GetAttributeChangedSignal(SpaLayout.SLOT_ATTRIBUTE):Connect(fn)
	end
end

return SpaLayout
