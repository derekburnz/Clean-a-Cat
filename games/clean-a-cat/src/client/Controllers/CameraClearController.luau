--!strict
-- CameraClearController: the camera never starts a visit inside a wall picture (issue 670, switch cameraClear).
-- Roblox's own camera stops in front of parts players collide with, but not in front of ones they walk through
-- (CanCollide off). On a returning join the camera rests on the spa's back wall right behind the spawn, where the
-- framed picture (part of CleanACat_Area_SpaPlot_Decor, which players walk through) hangs, so the first frame was the
-- picture's light blue face. For SETTLE_SECONDS after each spawn, every frame after the camera has moved, this checks
-- the line from the camera's focus to the camera: if it passes into a part the camera ignores, or the camera sits
-- behind or inside a solid wall, the camera turns around its focus by the smallest of TURNS that gives a clear line,
-- in front of the first wall on it. It keeps its tilt and finds its own distance again from the next frame, and the
-- check goes on for the whole window, since the camera can reset itself after a turn. With the line clear nothing
-- changes, so the opening's shots and any good first frame stay exactly as they were. The moment the player turns or
-- zooms the camera themselves (a drag on the screen, the right mouse button, the wheel, the right stick or the arrow
-- keys), the check stops for that spawn, so it never fights them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local FLAG = "cameraClear"
local BIND_NAME = "CleanACatCameraClear"
local SETTLE_SECONDS = 2 -- how long after a spawn the camera is checked
local NEAR = 0.3 -- past the camera along the line: the near plane draws this close
local REACH = 12.5 -- the camera's default distance, used when testing a turn
local SEE_THROUGH = 0.95 -- a part at least this transparent does not count
local WALL_GAP = 0.25 -- a solid hit this much short of the camera means the camera is behind or inside it
local WALL_MARGIN = 0.5 -- a turned camera stops this far in front of a wall
local MIN_DISTANCE = 1.5 -- a turn that leaves the camera nearer the player than this is not used
local TURNS = { 20, -20, 35, -35, 50, -50, 70, -70, 90, -90 } -- degrees around the focus, smallest first

local CameraClearController = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

-- What the line from `from` along `direction` (a unit vector) meets within `length`, skipping see-through parts: the
-- distance to a part players walk through that the camera would show from inside (the first thing it meets), or else
-- the distance to the first solid part, where the camera's own pull-in stops it. Both nil when nothing is in the way.
local function scan(
	from: Vector3,
	direction: Vector3,
	length: number,
	skip: { Instance }
): (number?, number?)
	local ignore = table.clone(skip)
	for _ = 1, 6 do
		params.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(from, direction * length, params)
		if hit == nil then
			return nil, nil
		end
		local part = hit.Instance
		if part.Transparency >= SEE_THROUGH then
			table.insert(ignore, part)
			continue
		end
		if part.CanCollide then
			return nil, hit.Distance
		end
		return hit.Distance, nil
	end
	return nil, nil
end

local function check(character: Model)
	if not LiveFlags.isOn(FLAG) then
		return
	end
	local camera = Workspace.CurrentCamera
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if camera == nil or humanoid == nil or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	if camera.CameraSubject ~= humanoid then
		return
	end
	local focus = camera.Focus.Position
	local offset = camera.CFrame.Position - focus
	local distance = offset.Magnitude
	if distance < 1 then
		return -- first person: nothing to clear
	end
	local skip: { Instance } = { character }
	local through, solid = scan(focus, offset.Unit, distance + NEAR, skip)
	-- in the clear: nothing walk-through in front of the camera, and not behind or inside a solid wall
	if through == nil and (solid == nil or (solid :: number) >= distance - WALL_GAP) then
		return
	end
	for _, degrees in TURNS do
		local turned = CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(offset.Unit)
		local turnedThrough, wall = scan(focus, turned, math.max(distance, REACH) + NEAR, skip)
		if turnedThrough ~= nil then
			continue
		end
		-- the camera goes in front of the first wall itself, so this frame never shows the inside of one
		local at = if wall then math.min(distance, (wall :: number) - WALL_MARGIN) else distance
		if at >= MIN_DISTANCE then
			camera.CFrame = CFrame.lookAt(focus + turned * at, focus)
			return
		end
	end
end

-- Input that turns or zooms the camera: once the player does it, the camera is theirs.
local TURN_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.Left] = true,
	[Enum.KeyCode.Right] = true,
	[Enum.KeyCode.Thumbstick2] = true,
}
local function turnsCamera(input: InputObject): boolean
	local kind = input.UserInputType
	return kind == Enum.UserInputType.Touch
		or kind == Enum.UserInputType.MouseButton2
		or kind == Enum.UserInputType.MouseWheel
		or TURN_KEYS[input.KeyCode] == true
end

local playerTurned = false
local function onInput(input: InputObject, processed: boolean)
	if not processed and turnsCamera(input) then
		playerTurned = true
	end
end

local function watch(character: Model)
	local player = Players.LocalPlayer
	RunService:UnbindFromRenderStep(BIND_NAME)
	local started = os.clock()
	playerTurned = false
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		-- checked every frame for the whole window: the camera can reset itself after a turn (a respawn does at
		-- about 0.33 s), and a character not yet in the world is waited for, not given up on
		if
			os.clock() - started > SETTLE_SECONDS
			or playerTurned
			or player.Character ~= character
		then
			RunService:UnbindFromRenderStep(BIND_NAME)
			return
		end
		if character:IsDescendantOf(Workspace) then
			check(character)
		end
	end)
end

function CameraClearController.Init(_controllers: { [string]: any }) end

function CameraClearController.Start()
	local player = Players.LocalPlayer
	UserInputService.InputBegan:Connect(onInput)
	UserInputService.InputChanged:Connect(onInput)
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
end

return CameraClearController
