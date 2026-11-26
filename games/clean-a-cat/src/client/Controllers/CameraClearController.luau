--!strict
-- CameraClearController: the camera never starts a visit inside a wall picture (issue 670, switch cameraClear).
-- Roblox's own camera stops in front of parts players collide with, but not in front of ones they walk through
-- (CanCollide off). On a returning join the camera rests on the spa's back wall right behind the spawn, where the
-- framed picture (part of CleanACat_Area_SpaPlot_Decor, which players walk through) hangs, so the first frame was the
-- picture's light blue face. For SETTLE_SECONDS after each spawn, after the camera has moved in a frame, this checks
-- the line from the camera's focus to the camera: if it passes into a part the camera ignores, the camera turns
-- around its focus by the smallest of TURNS that gives a clear line. Only the turn is set; the camera keeps its own
-- distance and tilt and the player can turn it freely after. With the line clear nothing changes, so the opening's
-- shots and any good first frame stay exactly as they were. The moment the player turns or zooms the camera
-- themselves (a drag on the screen, the right mouse button, the wheel, the right stick or the arrow keys), the check
-- stops for that spawn, so it never fights them.
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
local TURNS = { 20, -20, 35, -35, 50, -50, 70, -70, 90, -90 } -- degrees around the focus, smallest first

local CameraClearController = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

-- Distance along `direction` (a unit vector) from `from` to the first part the camera would show from inside: one
-- players walk through, not see through. Nil when the first thing in the way is solid (the camera stops in front of
-- it by itself) or nothing is within `length`.
local function blockedAt(
	from: Vector3,
	direction: Vector3,
	length: number,
	skip: { Instance }
): number?
	local ignore = table.clone(skip)
	for _ = 1, 6 do
		params.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(from, direction * length, params)
		if hit == nil then
			return nil
		end
		local part = hit.Instance
		if part.Transparency >= SEE_THROUGH then
			table.insert(ignore, part)
			continue
		end
		if part.CanCollide then
			return nil
		end
		return hit.Distance
	end
	return nil
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
	if blockedAt(focus, offset.Unit, distance + NEAR, skip) == nil then
		return
	end
	for _, degrees in TURNS do
		local turned = CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(offset.Unit)
		if blockedAt(focus, turned, math.max(distance, REACH) + NEAR, skip) == nil then
			-- this frame shows the turned view; from the next one the camera keeps the turn and finds its own distance
			camera.CFrame = CFrame.lookAt(focus + turned * distance, focus)
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
	RunService:UnbindFromRenderStep(BIND_NAME)
	local started = os.clock()
	playerTurned = false
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		if os.clock() - started > SETTLE_SECONDS or character.Parent == nil or playerTurned then
			RunService:UnbindFromRenderStep(BIND_NAME)
			return
		end
		check(character)
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
