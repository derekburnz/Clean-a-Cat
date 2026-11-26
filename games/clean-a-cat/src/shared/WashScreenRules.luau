--!strict
-- WashScreenRules: the wash minigame on its own screen (switch washScreen, issue 856). Derek on dev, 2026-11-26:
-- "dont show walk, and dont show buy either of these during minigame", and "make the cat washing minigame a whole
-- different screen ... don't make it still show stuff in background that way they can focus and don't have any of
-- the regular hud on the screen during washing minigame".
--
-- While the close-up wash view is up (Spa/WashView), WashScreenController draws a clean room around the shot (Model-
-- Agent's CleanACat_Area_WashRoom, or a plain pastel box until it exists) and hides on this device every other part
-- inside it, keeping only what sits close to the cat (the tub or station, the cat, its bubbles). The prompt pills,
-- the Walk button, Roblox's player list and the regular HUD hide too; the minigame's own step counter, progress bar
-- and tool tray stay. Nothing here is sent to the server, so the wash's server checks do not change.
--
-- Pure and shared, so the specs can check the room's sums.

local WashScreenRules = {}

WashScreenRules.FLAG = "washScreen"
WashScreenRules.ROOM_ASSET = "CleanACat_Area_WashRoom"
WashScreenRules.ROOM_NAME = "CleanACat_WashRoom" -- the drawn room, in Workspace, on this device only

-- The room around the shot's spot, in studs: HALF wide each way from the spot along the floor, from the floor up to
-- HEIGHT. The wash camera sits about 6 studs out and 4.5 up from the cat (Effects/WashCamera's scene), so 10 keeps it
-- inside with room to spare at every station.
WashScreenRules.HALF = 10
WashScreenRules.HEIGHT = 12
WashScreenRules.WALL = 1 -- the placeholder walls' thickness
WashScreenRules.FLOOR_LIFT = 0.05 -- the placeholder floor sits this far over the spot, clear of the plot's floor
-- Parts whose middle is within KEEP studs of the spot along the floor stay: the tub or station, the cat in it and its
-- bubbles. The Tools board and the next tub stand further out than that.
WashScreenRules.KEEP = 3.5
WashScreenRules.REFRESH = 0.5 -- seconds between looks for new parts in the room (a passer by, a new prop)

-- The placeholder's look: Bubble Pastel teal walls, a lighter floor.
WashScreenRules.WALL_COLOR = Color3.fromRGB(168, 224, 226)
WashScreenRules.FLOOR_COLOR = Color3.fromRGB(226, 246, 244)

-- Is `point` inside the room around `spot` (only its position counts; the room is flat and square)?
function WashScreenRules.inRoom(point: Vector3, spot: Vector3): boolean
	local h = WashScreenRules.HALF
	local d = point - spot
	return math.abs(d.X) <= h and math.abs(d.Z) <= h and d.Y >= -1 and d.Y <= WashScreenRules.HEIGHT
end

-- Does a part whose middle is at `point` stay shown in the room around `spot`?
function WashScreenRules.keeps(point: Vector3, spot: Vector3): boolean
	local d = point - spot
	return Vector2.new(d.X, d.Z).Magnitude <= WashScreenRules.KEEP
end

-- The front view (Derek on dev, 2026-11-26: "try to face the cat from the front for most minigames possible not
-- looking sideways", then "for the cleaning minigames give a more front view of the cat not from above"). On the wash
-- screen the camera stands on the side the cat's face is on (his pivot's LookVector, Model-Agent) at about his eye
-- level, EYE_ABOVE over his eyes, looking at his middle; with no eyes to read it looks FRONT_PITCH degrees down.
WashScreenRules.FRONT_PITCH = 10
WashScreenRules.EYE_ABOVE = 0.3
WashScreenRules.MAX_PITCH = 20 -- never steeper than this, even for a cat whose eyes sit far over his middle

-- Where the camera stands for a front view that looks at `look`: `distance` studs out along `facing` (flattened), at
-- height `eyeY` + EYE_ABOVE when given, else FRONT_PITCH degrees above `look`; the slope is held to MAX_PITCH. Spa/
-- WashView looks from there at `look`.
function WashScreenRules.frontFrom(
	look: Vector3,
	facing: Vector3,
	distance: number,
	eyeY: number?
): Vector3
	local flat = Vector3.new(facing.X, 0, facing.Z)
	local ahead = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local pitch = math.rad(WashScreenRules.FRONT_PITCH)
	if eyeY ~= nil then
		local rise = math.clamp(eyeY + WashScreenRules.EYE_ABOVE - look.Y, -distance, distance)
		pitch = math.asin(rise / distance)
	end
	local most = math.rad(WashScreenRules.MAX_PITCH)
	pitch = math.clamp(pitch, -most, most)
	return look
		+ ahead * (distance * math.cos(pitch))
		+ Vector3.yAxis * (distance * math.sin(pitch))
end

-- Is the wash screen on, given the switch reader?
function WashScreenRules.on(isOn: (string) -> boolean): boolean
	return isOn(WashScreenRules.FLAG)
end

return table.freeze(WashScreenRules)
