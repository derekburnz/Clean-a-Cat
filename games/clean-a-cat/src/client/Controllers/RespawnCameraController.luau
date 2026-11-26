--!strict
-- RespawnCameraController: after a respawn the camera starts behind the new character, as it does on a join
-- (issue 670, switch respawnCamera). Roblox's camera module (PlayerModule ClassicCamera, which serves the classic and
-- follow modes) means to turn the camera behind each new character: CharacterAdded sets its resetCameraAngle flag.
-- But its next Update clears that flag first and only uses it once the character has a subject position, so on a
-- respawn, where the first Update comes before the new character is ready, the turn is lost and the camera keeps
-- whatever yaw it had (Sync, fe114a4: 41, 5 and 67 degrees off). Spawning turned toward open room (spawnSide) then
-- leaves the camera on the back wall art. PR 704's first try set the flag once the HumanoidRootPart child was there,
-- but the module looks the root up as Humanoid.RootPart, which can still be nil then, and falls back to world -Z (a
-- yaw of about 0, 89 to 108 degrees off the character on 8 of 8 respawns).
-- So for WINDOW_SECONDS after a respawn (not the first character of the visit, whose camera is already right), while
-- the camera is the plain follow camera on this humanoid, the character stands still and the camera looks more
-- than OFF away from the character's facing, this hands the module the root (Humanoid.RootPart) and sets its flag,
-- then looks again a few frames later, at most MAX_ASKS times. The module turns the camera itself, with its own
-- state, so nothing fights the turn afterwards (where CameraClearController's held turn failed). A scripted shot
-- such as the opening or the wash view is never touched, and the moment the player turns or zooms the camera, it is
-- theirs.
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
local MAX_ASKS = 6 -- how many times one respawn asks the module to turn the camera
local ASK_GAP = 3 -- frames between asks, so the module has run before the camera is looked at again
local STILL = 0.1 -- a MoveDirection shorter than this is a character standing still
local FALLBACK_DISTANCE = 12.5 -- the camera's default distance, used only if the module cannot be reached
local FALLBACK_RISE = 0.27 -- about the module's own 15 degree tilt, used with the fallback

local RespawnCameraController = {}

-- The active camera controller in Roblox's PlayerModule (ClassicCamera serves both the classic and follow modes),
-- or nil when it cannot be reached.
local function activeCamera(): any
	local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local module = if scripts then scripts:FindFirstChild("PlayerModule") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, found = pcall(function(): any
		local cameras = (require(module :: ModuleScript) :: any):GetCameras()
		return if type(cameras) == "table" then cameras.activeCameraController else nil
	end)
	return if ok and type(found) == "table" then found else nil
end

-- Turns the camera behind `root`: through the module's own reset (handing it the root, which it would otherwise look
-- up as Humanoid.RootPart) when it has one, else by placing the camera once.
local function reset(camera: Camera, root: BasePart)
	local controller = activeCamera()
	if controller ~= nil and controller.resetCameraAngle ~= nil then
		controller.humanoidRootPart = root
		controller.resetCameraAngle = true
		return
	end
	local look = root.CFrame.LookVector
	local back = Vector3.new(-look.X, 0, -look.Z)
	if back.Magnitude < 1e-3 then
		return
	end
	local offset = (back.Unit + Vector3.new(0, FALLBACK_RISE, 0)).Unit * FALLBACK_DISTANCE
	camera.CFrame = CFrame.lookAt(camera.Focus.Position + offset, camera.Focus.Position)
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

local function watch(character: Model)
	local player = Players.LocalPlayer
	RunService:UnbindFromRenderStep(BIND_NAME)
	if not LiveFlags.isOn(FLAG) then
		return
	end
	local started = os.clock()
	playerTurned = false
	local asks = 0
	local pause = 0
	-- before the camera module's own step, so a reset asked for lands on this same frame
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value - 1, function()
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
		reset(camera, root)
		asks += 1
		pause = ASK_GAP
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
