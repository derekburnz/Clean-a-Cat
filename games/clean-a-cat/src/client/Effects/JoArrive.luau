--!strict
-- JoArrive: Jo walks in to his hire pad when the "Hire your first helper" card starts its trail (issue 913, switch
-- joArrive, off by default; Design-Agent's Moments.JoArrives(pad), fired by BubbleController under contextAsks).
--
--   walk     a local copy of Jo (Assets.CleanACat_NPC_Staff_Jo) steps in at the spa's front door (the plot's
--            SpotQueue1) and walks to his pad, round the Tools board by the gap between it and station 2, at his own
--            WalkSpeed; CustomerMotion sees a CleanACat_NPC_Staff_ model and swings his legs and arms as he goes
--   camera   for SHOT seconds the camera eases over to follow him from the player's side, then eases back to where
--            it was and is the player's again (Custom), the way RespawnCameraController hands it back
--   arrive   a little sparkle and the soft visitor chime as he stops, facing the room
--   wait     he stays standing by his pad (local only) until the server draws the hired Jo (plot.Workers.Jo with
--            Hired true) or the switch goes off
--   comfort  Reduced Motion: no walk and no camera move; he is simply standing by his pad, with the chime
--
-- Plays once per visit. Client only and cosmetic; nothing here replicates or takes a tap.
--
--   JoArrive.along(points, distance) -> (Vector3, Vector3)   pure: the point `distance` studs along the path and
--                                                           the flat way it faces there
--   JoArrive.length(points) -> number                       pure: the path's length in studs
--   JoArrive.blend(t, total) -> number                      pure: how far the camera is over to the shot (0 to 1)
--   JoArrive.start(isOn)                                    listens for the moment
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local JoArrive = {}

JoArrive.ASSET = "CleanACat_NPC_Staff_Jo"
JoArrive.NAME = "CleanACat_NPC_Staff_JoArrive" -- keeps the staff prefix so CustomerMotion walks him
JoArrive.WORKER = "Jo"
JoArrive.FROM_SPOT = "SpotQueue1" -- inside the front door
JoArrive.GAP_SPOTS = { "SpotStation2", "Tools" } -- he walks through the middle of these two
JoArrive.TO_SPOT = "SpotWorkerJo"
JoArrive.BESIDE = Vector3.new(-2.6, 0, 0.4) -- in the pad's space: where he stands by the pad (WorkerService's STAFF_OFFSET place)
JoArrive.SPEED = 6.5 -- studs a second when the model has no WalkSpeed
JoArrive.MAX_WALK = 2.6 -- seconds: a longer path is walked faster so the shot stays short
JoArrive.EASE = 0.45 -- seconds of camera blend at each end
JoArrive.HOLD = 0.5 -- seconds on him after he stops
JoArrive.BACK = 13 -- studs from him to the camera
JoArrive.UP = 7 -- studs over his feet
JoArrive.CHECK = 0.5 -- seconds between checks for the hired Jo

function JoArrive.length(points: { Vector3 }): number
	local total = 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
	end
	return total
end

function JoArrive.along(points: { Vector3 }, distance: number): (Vector3, Vector3)
	local left = math.max(distance, 0)
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		local leg = (b - a).Magnitude
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local facing = if flat.Magnitude > 1e-4 then flat.Unit else Vector3.new(0, 0, -1)
		if left <= leg or i == #points then
			local u = if leg > 0 then math.min(left / leg, 1) else 1
			return a:Lerp(b, u), facing
		end
		left -= leg
	end
	return points[#points], Vector3.new(0, 0, -1)
end

local function smooth(u: number): number
	local k = math.clamp(u, 0, 1)
	return k * k * (3 - 2 * k)
end

function JoArrive.blend(t: number, total: number): number
	if t <= 0 or t >= total then
		return 0
	end
	return math.min(smooth(t / JoArrive.EASE), smooth((total - t) / JoArrive.EASE))
end

local copy: Model? = nil
local played = false

local function drop()
	local c = copy
	copy = nil
	if c then
		c:Destroy()
	end
end

local function hiredStation(): boolean
	local ok, hired = pcall(function()
		local SpaLayout =
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpaLayout")) :: any
		local slot = SpaLayout.slotOf(Players.LocalPlayer)
		local plot = if slot then SpaLayout.plotModel(slot) else nil
		local folder = plot and plot:FindFirstChild("Workers")
		local station = folder and folder:FindFirstChild(JoArrive.WORKER)
		return station ~= nil and station:GetAttribute("Hired") == true
	end)
	return ok and hired == true
end

local function spots(): ({ Vector3 }?, CFrame?)
	local ok, path, stand = pcall(function()
		local SpaLayout =
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpaLayout")) :: any
		local player = Players.LocalPlayer
		local from = (SpaLayout.spot(JoArrive.FROM_SPOT, player) :: CFrame).Position
		local a = (SpaLayout.spot(JoArrive.GAP_SPOTS[1], player) :: CFrame).Position
		local b = (SpaLayout.spot(JoArrive.GAP_SPOTS[2], player) :: CFrame).Position
		local pad = SpaLayout.spot(JoArrive.TO_SPOT, player) :: CFrame
		local standAt = pad * CFrame.new(JoArrive.BESIDE)
		local gap = a:Lerp(b, 0.5)
		local points = {
			from,
			Vector3.new(gap.X, from.Y, gap.Z),
			Vector3.new(standAt.Position.X, from.Y, standAt.Position.Z),
		}
		return points, standAt
	end)
	if not ok then
		return nil, nil
	end
	return path, stand
end

local function play(still: boolean)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local asset = assets and assets:FindFirstChild(JoArrive.ASSET)
	local points, stand = spots()
	if asset == nil or not asset:IsA("Model") or points == nil or stand == nil then
		return
	end
	local path = points :: { Vector3 }
	local model = (asset :: Model):Clone() :: Model
	model.Name = JoArrive.NAME
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d :: BasePart
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		elseif d:IsA("ProximityPrompt") or d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local back = path[#path - 1] - path[#path]
	local flatBack = Vector3.new(back.X, 0, back.Z)
	local endFacing = if flatBack.Magnitude > 1e-4
		then flatBack.Unit
		else (stand :: CFrame).LookVector
	local final = CFrame.lookAt(path[#path], path[#path] + endFacing)
	drop()
	copy = model
	local function arrived()
		local Effects = require(script.Parent) :: any
		local Audio = require(script.Parent.Parent:WaitForChild("Audio")) :: any
		pcall(Effects.burst, "revealSparkle", path[#path] + Vector3.new(0, 2.5, 0))
		pcall(Audio.play, "visitorChime")
	end
	if still then
		model:PivotTo(final)
		model.Parent = Workspace
		arrived()
		return
	end
	local speed = model:GetAttribute("WalkSpeed")
	local length = JoArrive.length(path)
	local walk = length / (if type(speed) == "number" and speed > 0 then speed else JoArrive.SPEED)
	walk = math.min(walk, JoArrive.MAX_WALK)
	local first, facing = JoArrive.along(path, 0)
	model:PivotTo(CFrame.lookAt(first, first + facing))
	model.Parent = Workspace

	local camera = Workspace.CurrentCamera
	local savedType = if camera then camera.CameraType else nil
	local savedCF = if camera then camera.CFrame else nil
	local total = JoArrive.EASE + walk + JoArrive.HOLD + JoArrive.EASE
	local began = os.clock()
	local done = false
	local link: RBXScriptConnection? = nil
	local borrow = false
	local wrote: CFrame? = nil -- the camera CFrame this last wrote
	local function stillOurs(): boolean
		return camera ~= nil
			and camera.CameraType == Enum.CameraType.Scriptable
			and wrote ~= nil
			and camera.CFrame:FuzzyEq(wrote :: CFrame, 1e-3)
	end
	local function finish()
		if done then
			return
		end
		done = true
		if link then
			link:Disconnect()
		end
		if model.Parent then
			model:PivotTo(final)
		end
		-- hand back only a camera that is still ours: if another shot (the wash view) took it meanwhile, leave it be
		if borrow and camera and savedType and savedCF and stillOurs() then
			camera.CFrame = savedCF
			camera.CameraType = savedType
		end
		borrow = false
	end
	-- only a camera that is the plain follow camera is borrowed: a scripted shot (the wash view) keeps its own
	borrow = camera ~= nil and savedType == Enum.CameraType.Custom
	if borrow and camera then
		camera.CameraType = Enum.CameraType.Scriptable
		wrote = camera.CFrame
	end
	local stopped = false
	link = RunService.RenderStepped:Connect(function()
		if model.Parent == nil then
			finish()
			return
		end
		local t = os.clock() - began
		local walked = math.clamp((t - JoArrive.EASE) / walk, 0, 1) * length
		local at, way = JoArrive.along(path, walked)
		if walked >= length then
			model:PivotTo(final)
			if not stopped then
				stopped = true
				arrived()
			end
		else
			model:PivotTo(CFrame.lookAt(at, at + way))
		end
		if borrow and not stillOurs() then
			borrow = false -- something else took the camera: stop writing it and hand nothing back
		end
		if borrow and camera and savedCF then
			local from = (savedCF :: CFrame).Position
			local away = Vector3.new(from.X - at.X, 0, from.Z - at.Z)
			local dir = if away.Magnitude > 1e-3 then away.Unit else -way
			local eye = at + dir * JoArrive.BACK + Vector3.new(0, JoArrive.UP, 0)
			local shot = CFrame.lookAt(eye, at + Vector3.new(0, 2.5, 0))
			camera.CFrame = (savedCF :: CFrame):Lerp(shot, JoArrive.blend(t, total))
			wrote = camera.CFrame
		end
		if t >= total then
			finish()
		end
	end)
end

function JoArrive.start(isOn: () -> boolean)
	local Moments = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Moments")) :: any
	local signal = Moments.JoArrives
	if signal == nil then
		return -- Design-Agent's moment is not in this build yet
	end
	signal:Connect(function(_pad: Instance?)
		if played or not isOn() or hiredStation() then
			return
		end
		played = true
		local Comfort =
			require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Comfort")) :: any
		play(Comfort.reducedMotion() == true)
	end)
	task.spawn(function()
		while true do
			task.wait(JoArrive.CHECK)
			if copy and (not isOn() or hiredStation()) then
				drop()
			end
		end
	end)
end

return JoArrive
