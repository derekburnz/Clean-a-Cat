--!strict
-- OutdoorWalkController: the faster walk outside the spa after the tutorial (OutdoorWalkRules, switch outdoorWalk,
-- issue 886). Every CHECK_SECONDS it sets the player's own Humanoid.WalkSpeed: OUTDOOR_SPEED once the server has
-- marked the tutorial done (Player attribute TutorialDone) and no spa roof or ceiling stands over their head, else
-- Roblox's default. The character's movement runs on the player's device, so the speed is set here; nothing is sent.
-- With the switch off it leaves WalkSpeed alone, after putting back the default once if it had changed it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local OutdoorWalkRules = require(Shared:WaitForChild("OutdoorWalkRules"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local OutdoorWalkController = {}

local player = Players.LocalPlayer
local changed: Humanoid? = nil -- the humanoid whose WalkSpeed this set away from the default

-- A spa roof or ceiling over `at` (any plot's part, straight up within ROOF_REACH).
local function underRoof(at: Vector3): boolean
	local plots = Workspace:FindFirstChild(SpaLayout.PLOTS_FOLDER)
	if plots == nil then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { plots }
	return Workspace:Raycast(at, Vector3.yAxis * OutdoorWalkRules.ROOF_REACH, params) ~= nil
end

local function update()
	local character = player.Character
	local found = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local humanoid: Humanoid? = if found then found :: Humanoid else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not LiveFlags.isOn(OutdoorWalkRules.FLAG) then
		local was = changed
		changed = nil
		if was and was.Parent then
			was.WalkSpeed = OutdoorWalkRules.INDOOR_SPEED
		end
		return
	end
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	local done = player:GetAttribute(OutdoorWalkRules.ATTRIBUTE) == true
	-- from just over the head, so the floor of an upper room or a step never counts as a roof
	local head = (root :: BasePart).Position + Vector3.yAxis * 3
	local speed = OutdoorWalkRules.speedFor(done, done and underRoof(head))
	if humanoid.WalkSpeed ~= speed then
		humanoid.WalkSpeed = speed
	end
	changed = if speed ~= OutdoorWalkRules.INDOOR_SPEED then humanoid else nil
end

function OutdoorWalkController.Init(_controllers: { [string]: any }) end

function OutdoorWalkController.Start()
	task.spawn(function()
		while true do
			update()
			task.wait(OutdoorWalkRules.CHECK_SECONDS)
		end
	end)
end

return OutdoorWalkController
