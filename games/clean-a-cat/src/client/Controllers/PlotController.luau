--!strict
-- PlotController: the street is look only (#88). Other players' spas get an invisible wall around them on this
-- client only, so this player can walk the street and look in through the open fronts and windows but not walk
-- in. It is a comfort rule, not security: the server already checks every action against the acting player's
-- own plot (SpaLayout.spot(name, player)). Behind the LiveFlags switch `spaVisitors`, off by default: off, the
-- walls stand; on, visitors may walk in. Has no effect while the street (`spaPlot`) is off.
-- Each wall is a hollow ring of four thin sides on the edge of the plot's box, never a solid block: a character
-- that is inside another plot when the walls go up (the shared spawn sits in plot 1, and a slot change leaves the
-- old walls up for a moment) stands on the floor until the server moves it, instead of being pushed out of a
-- solid part and through the floor (#169).
-- With `spawnView` on, it also points the camera behind the character once the server has moved it onto its own
-- spawn spot (#188). Everyone spawns at plot 1's SpawnLocation; a player in slot 2 or up is then moved about 44
-- studs, and on a phone the camera swings along the move and starts looking sideways down the street.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local FLAG = "spaVisitors"
local WALL_EXTRA_HEIGHT = 40 -- well above a jump, so nobody stands on top
local WALL_THICKNESS = 1
local FOLDER_NAME = "VisitorWalls"
-- The camera turn after a spawn (#188).
local ARRIVE_WAIT_SECONDS = 5 -- how long to wait for the server's move before giving up
local ARRIVE_DISTANCE = 4 -- studs from the spawn spot (flat) that count as arrived
local FOCUS_HEIGHT = 1.5 -- the camera looks at this height above the root, about the head
local DEFAULT_ZOOM = 12.5 -- Roblox's starting camera distance
local MIN_ZOOM = 8
local MAX_ZOOM = 20
local MIN_PITCH = -0.6 -- radians; the camera looks down at least a little and never steeply
local MAX_PITCH = -0.1

local PlotController = {}

local walls: Folder? = nil

local function clear()
	local folder = walls
	walls = nil
	if folder then
		folder:Destroy()
	end
end

local function refresh()
	clear()
	if LiveFlags.isOn(FLAG) or not SpaLayout.onPlot() then
		return
	end
	local mine = SpaLayout.slotOf()
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for slot = 1, SpaLayout.PLOT_COUNT do
		local plot = SpaLayout.plotModel(slot)
		if slot ~= mine and plot then
			local cframe, size = (plot :: Model):GetBoundingBox()
			local height = size.Y + WALL_EXTRA_HEIGHT
			local y = WALL_EXTRA_HEIGHT / 2
			local inX = size.X / 2 - WALL_THICKNESS / 2
			local inZ = size.Z / 2 - WALL_THICKNESS / 2
			-- Front and back span the full width; the two sides fit between them. All sit inside the box, so a
			-- neighbour's ring never reaches into this player's own plot.
			local sides: { { name: string, size: Vector3, offset: Vector3 } } = {
				{
					name = "Front",
					size = Vector3.new(size.X, height, WALL_THICKNESS),
					offset = Vector3.new(0, y, -inZ),
				},
				{
					name = "Back",
					size = Vector3.new(size.X, height, WALL_THICKNESS),
					offset = Vector3.new(0, y, inZ),
				},
				{
					name = "Left",
					size = Vector3.new(WALL_THICKNESS, height, size.Z - 2 * WALL_THICKNESS),
					offset = Vector3.new(-inX, y, 0),
				},
				{
					name = "Right",
					size = Vector3.new(WALL_THICKNESS, height, size.Z - 2 * WALL_THICKNESS),
					offset = Vector3.new(inX, y, 0),
				},
			}
			for _, side in sides do
				local wall = Instance.new("Part")
				wall.Name = `Wall{slot}{side.name}`
				wall.Anchored = true
				wall.CanCollide = true
				wall.CanQuery = false
				wall.CanTouch = false
				wall.CastShadow = false
				wall.Transparency = 1
				wall.Size = side.size
				wall.CFrame = cframe * CFrame.new(side.offset)
				wall.Parent = folder
			end
		end
	end
	folder.Parent = Workspace
	walls = folder
end

-- Puts the camera behind the character, looking the way `look` points, keeping the player's zoom and a sane pitch.
local function pointCamera(root: BasePart, look: Vector3)
	local camera = Workspace.CurrentCamera
	if camera == nil or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		return
	end
	local focus = root.Position + Vector3.new(0, FOCUS_HEIGHT, 0)
	local zoom = (camera.CFrame.Position - camera.Focus.Position).Magnitude
	zoom = if zoom >= 1 then math.clamp(zoom, MIN_ZOOM, MAX_ZOOM) else DEFAULT_ZOOM
	local pitch =
		math.clamp(math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1)), MIN_PITCH, MAX_PITCH)
	local direction = flat.Unit * math.cos(pitch) + Vector3.new(0, math.sin(pitch), 0)
	camera.CFrame = CFrame.lookAt(focus - direction * zoom, focus)
end

-- Waits for the server to put this character on its own spawn spot, then turns the camera behind it once.
local function faceForward(character: Model)
	if not LiveFlags.isOn(SpaLayout.VIEW_FLAG) then
		return
	end
	local found = character:WaitForChild("HumanoidRootPart", ARRIVE_WAIT_SECONDS)
	if found == nil or not found:IsA("BasePart") then
		return
	end
	local root = found :: BasePart
	local deadline = os.clock() + ARRIVE_WAIT_SECONDS
	while os.clock() < deadline and character.Parent ~= nil do
		local slot = SpaLayout.slotOf()
		if slot ~= nil and SpaLayout.onPlot() then
			local spot = SpaLayout.spawnSpot(slot)
			local offset = root.Position - spot.Position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude < ARRIVE_DISTANCE then
				-- One more frame, so the default camera has taken the new position before it is turned.
				RunService.RenderStepped:Wait()
				pointCamera(root, spot.LookVector)
				return
			end
		end
		RunService.Heartbeat:Wait()
	end
end

function PlotController.Init(_controllers: { [string]: any }) end

function PlotController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(refresh)
	SpaLayout.changed(function()
		-- The old walls may stand around this player's new plot: take them down now. The plots replicate after
		-- the attribute, so wait for them before drawing again.
		clear()
		task.delay(1, refresh)
	end)
	task.delay(1, refresh)
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(character: Model)
		task.spawn(faceForward, character)
	end)
	if player.Character then
		task.spawn(faceForward, player.Character)
	end
end

return PlotController
