--!strict
-- RespawnCameraController: after a respawn the camera starts behind the new character, as it does on a join
-- (issue 670, switch respawnCamera). Roblox's camera module turns the camera behind the character once each time a
-- character is added, but on a respawn it does so before the new character's root part has arrived. It then has no
-- facing to use and falls back to looking along world -Z, which in a spa plot puts the camera on the back wall, with
-- the wall picture right in front of it. Sync's retest on cf511f0 logged this on 8 of 8 respawns: the character
-- stood turned, and the camera stayed at a yaw of about 0.
-- For WINDOW_SECONDS after a respawn (not the first character of the visit, whose camera is already right), this asks
-- the camera module to turn the camera behind the character again: once the root part is there, and again if the
-- server then moves or turns the character onto its plot spot. It asks through the module's own reset flag, so the
-- module turns the camera itself and keeps that turn. Because the module's own state is used, nothing fights it
-- afterwards, which is where CameraClearController's held turn failed. Only the plain follow camera is touched:
-- never a scripted shot such as the opening or the wash view. The moment the player turns or zooms the camera, it
-- is theirs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local FLAG = "respawnCamera"
local BIND_NAME = "CleanACatRespawnCamera"
local WINDOW_SECONDS = 2 -- how long after a respawn the character's facing is followed
local JUMP = 2 -- a root that moved this far (studs, flat) in one frame was put there, not walked there
local TURN = math.rad(20) -- a root that turned this much in one frame was turned by the server
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

-- Turns the camera behind `root`: through the module's reset flag when it has one, else by placing it once.
local function reset(camera: Camera, root: BasePart)
	local controller = activeCamera()
	if controller ~= nil and controller.resetCameraAngle ~= nil then
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

local function flatLook(part: BasePart): Vector3?
	local look = part.CFrame.LookVector
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
	local lastAt: Vector3? = nil
	local lastLook: Vector3? = nil
	-- before the camera module's own step, so the reset it is asked for lands on this same frame
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value - 1, function()
		if
			os.clock() - started > WINDOW_SECONDS
			or playerTurned
			or player.Character ~= character
		then
			RunService:UnbindFromRenderStep(BIND_NAME)
			return
		end
		local camera = Workspace.CurrentCamera
		local found = character:FindFirstChild("HumanoidRootPart")
		if
			camera == nil
			or found == nil
			or not found:IsA("BasePart")
			or not character:IsDescendantOf(Workspace)
		then
			return
		end
		local root = found :: BasePart
		local at = root.Position
		local look = flatLook(root)
		local moved = lastAt == nil
		if not moved and lastAt then
			local step = at - lastAt
			moved = Vector3.new(step.X, 0, step.Z).Magnitude > JUMP
		end
		if not moved and look and lastLook then
			moved = math.acos(math.clamp(look:Dot(lastLook), -1, 1)) > TURN
		end
		lastAt, lastLook = at, look
		if moved and following(camera, character) then
			reset(camera, root)
		end
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
