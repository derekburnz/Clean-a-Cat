--!strict
-- RespawnCameraController: after a respawn the camera starts behind the new character, as it does on a join
-- (issue 670, switch respawnCamera). Roblox's camera module (PlayerModule's ClassicCamera, serving the classic and
-- follow modes) loses its own respawn turn: CharacterAdded sets its resetCameraAngle flag, but its next Update clears
-- the flag before the new character has a subject position, so the camera keeps its old yaw, and with spawnSide the
-- character now faces open room while the camera stays on the back wall art. The module cannot be reached to fix
-- this: CameraModule returns an empty table, so PlayerModule:GetCameras() has no activeCameraController (Sync, on
-- 4e061e5, which is why PR 709's ask fell back every time). Setting Camera.CFrame alone does not hold either: in
-- follow mode (the touch default) each Update turns the camera back toward the module's own lastCameraTransform.
-- What does hold is the module's own reset path: with the camera Scriptable the module disables its controller,
-- which clears lastCameraTransform (BaseCamera:Cleanup), and once the camera is Custom again it starts from
-- Camera.CFrame. So for WINDOW_SECONDS after a respawn (not the first character of the visit, whose camera is
-- already right), while the camera is the plain follow camera on this humanoid, the character stands still and the
-- camera looks more than OFF away from the character's facing, this makes the camera Scriptable for one frame
-- placed behind the character at its own distance and the module's 15 degree tilt, then Custom again, and looks a
-- few frames later, at most MAX_ASKS times. It runs after the module's step. A scripted shot such as the opening or
-- the wash view is never touched, and the moment the player turns or zooms the camera, it is theirs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local FLAG = "respawnCamera"
local BIND_NAME = "CleanACatRespawnCamera"
local WINDOW_SECONDS = 2 -- how long after a respawn the camera is checked
local OFF = math.rad(30) -- a camera looking this far from the character's facing is turned behind it
local MAX_ASKS = 3 -- how many times one respawn turns the camera
local ASK_GAP = 3 -- frames after a turn before the camera is looked at again
local TILT = math.rad(15) -- the module's own downward tilt behind a new character (ClassicCamera INITIAL_CAMERA_ANGLE)
local MIN_DISTANCE = 4
local MAX_DISTANCE = 40
local STILL = 0.1 -- a MoveDirection shorter than this is a character standing still

local RespawnCameraController = {}

-- Where the camera goes behind a character facing `facing` (flat): at the camera's own distance from its focus, tilted
-- down like the module's own reset.
local function behind(camera: Camera, facing: Vector3): CFrame
	local focus = camera.Focus.Position
	local distance =
		math.clamp((camera.CFrame.Position - focus).Magnitude, MIN_DISTANCE, MAX_DISTANCE)
	local look = (facing * math.cos(TILT) - Vector3.new(0, math.sin(TILT), 0)).Unit
	return CFrame.lookAt(focus - look * distance, focus)
end

-- Is the camera the plain follow camera on this character's humanoid?
local function following(camera: Camera, character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil
		and camera.CameraType == Enum.CameraType.Custom
		and camera.CameraSubject == humanoid
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

local function flat(look: Vector3): Vector3?
	local level = Vector3.new(look.X, 0, look.Z)
	return if level.Magnitude > 1e-3 then level.Unit else nil
end

-- The camera turned Scriptable here and not yet given back to the module, with where it was placed.
local placed: CFrame? = nil

-- Gives the camera back to the module, placed, when this controller left it Scriptable.
local function release()
	local target = placed
	placed = nil
	local camera = Workspace.CurrentCamera
	if target and camera and camera.CameraType == Enum.CameraType.Scriptable then
		camera.CFrame = target
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function watch(character: Model)
	local player = Players.LocalPlayer
	RunService:UnbindFromRenderStep(BIND_NAME)
	release()
	if not LiveFlags.isOn(FLAG) then
		return
	end
	local started = os.clock()
	playerTurned = false
	local asks = 0
	local pause = 0
	-- after the camera module's own step, so the placed camera is what this frame shows
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		if placed then
			-- the module has seen Scriptable and dropped its last transform: hand the camera back where it was put
			release()
			pause = ASK_GAP
			return
		end
		if
			os.clock() - started > WINDOW_SECONDS
			or playerTurned
			or asks >= MAX_ASKS
			or player.Character ~= character
		then
			RunService:UnbindFromRenderStep(BIND_NAME)
			return
		end
		if pause > 0 then
			pause -= 1
			return
		end
		local camera = Workspace.CurrentCamera
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = if humanoid then humanoid.RootPart else nil
		if
			camera == nil
			or humanoid == nil
			or root == nil
			or not character:IsDescendantOf(Workspace)
			or not following(camera, character)
			or humanoid.MoveDirection.Magnitude > STILL
		then
			return
		end
		local facing = flat(root.CFrame.LookVector)
		local looking = flat(camera.CFrame.LookVector)
		if facing == nil or looking == nil then
			return
		end
		if math.acos(math.clamp(facing:Dot(looking), -1, 1)) <= OFF then
			return
		end
		local target = behind(camera, facing)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = target
		placed = target
		asks += 1
	end)
end

function RespawnCameraController.Init(_controllers: { [string]: any }) end

function RespawnCameraController.Start()
	local player = Players.LocalPlayer
	UserInputService.InputBegan:Connect(onInput)
	UserInputService.InputChanged:Connect(onInput)
	-- the first character of the visit (already there, or the first one added) keeps the join camera, which is right
	local first = player.Character == nil
	player.CharacterAdded:Connect(function(character: Model)
		if first then
			first = false
			return
		end
		watch(character)
	end)
end

return RespawnCameraController
