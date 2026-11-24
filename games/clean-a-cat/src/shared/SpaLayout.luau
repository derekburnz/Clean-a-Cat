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
	SpotStray = at(12, 0.5, 7, 0),
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
	SpotBoard = at(-13.5, 0.5, -14.6, TURNED),
	-- The opening (#285, Model-Agent): the player stands mid-entrance facing the street, the box lands in front on the
	-- near pavement, and the truck hits the bump across the near lane.
	SpotOpening = at(-5, 0.5, -27, 0),
	SpotBox = at(-5, 0.5, -30.6, 0),
	SpotBump = at(-1, 0.22, -37.6, math.pi / 2), -- a quarter turn: the bump lies across the lane
	SpotMascot = at(0.2, 0.5, -13.4, math.rad(135)), -- Suds's bed on its low stand beside the door (#285, Model-Agent)
	-- Not in the model: the Tools board stands on the floor left of the tub, facing the spawn.
	Tools = at(-1, 0.5, -2, 0),
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

-- Where plot `slot`'s pivot goes: slot 1 at PIVOT_POSITION, then one step right, one left, two right...
function SpaLayout.slotPivot(slot: number): Vector3
	local steps = slot // 2
	local side = if slot % 2 == 0 then 1 else -1
	return SpaLayout.PIVOT_POSITION + Vector3.new(side * steps * SpaLayout.PLOT_SPACING, 0, 0)
end

-- A spot's world position and yaw from the tables: plot `slot`'s (default 1) while it is placed, else the
-- room's. A spot the room never had uses the plot's. Nil for an unknown name.
function SpaLayout.place(name: string, onPlot: boolean, slot: number?): (Vector3?, number)
	local room = SpaLayout.ROOM_SPOTS[name]
	if not onPlot and room then
		return room.position, room.yaw
	end
	local plot = SpaLayout.PLOT_SPOTS[name]
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
	local tables = if onPlot then SpaLayout.PLOT_SPOTS else SpaLayout.ROOM_SPOTS
	local last = 0
	while tables[prefix .. (last + 1)] do
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

-- Where a character in plot `slot` spawns: the base of its feet and the way it faces. PlotService moves characters
-- here; the client points the camera from it (#188).
function SpaLayout.spawnSpot(slot: number): CFrame
	if LiveFlags.isOn(SpaLayout.VIEW_FLAG) then
		-- The turned tub's front (-Z) faces into the spa: stand in front of it and to its right (+X, the door
		-- line's side of the plot), turned back to face the street.
		return SpaLayout.slotTubSpot(slot)
			* CFrame.new(SpaLayout.SPAWN_SIDE, 0, -SpaLayout.SPAWN_FROM_TUB)
			* CFrame.Angles(0, math.pi, 0)
	end
	return spotIn("SpotSpawn", slot)
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

-- fn() when the street is placed or taken away, or the local player gets their slot.
function SpaLayout.changed(fn: () -> ())
	ReplicatedStorage:GetAttributeChangedSignal(SpaLayout.PLACED_ATTRIBUTE):Connect(fn)
	local player = Players.LocalPlayer
	if player then
		player:GetAttributeChangedSignal(SpaLayout.SLOT_ATTRIBUTE):Connect(fn)
	end
end

return SpaLayout
