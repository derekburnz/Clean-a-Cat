--!strict
-- BoxGuideController: the way back to the box (Derek's playtest, 2026-11-26: "if the player walks far away from box
-- during tutorial instead of opening (before opening) then show the transparent line of arrows from player towards
-- it"). Behind the switch boxGuide, off by default (rule 16: a first-session change).
--
-- While the opening's box is still closed (the Player attribute SudsBox is true) and the player is more than FAR
-- studs from it, the floor trail (Spa/FloorTrail, the same guide line as the tub's) points from their feet to the
-- box. It goes again once they are back within NEAR studs, when the box opens, or when the switch goes off. The gap
-- between FAR and NEAR keeps it from flickering at the edge. It never moves the player and only hides a trail it
-- showed itself, so the tub's trail later in the opening is untouched.
--
--   BoxGuideController.want(shown, distance) -> boolean   pure: should the guide show now
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SudsRules = require(Shared:WaitForChild("SudsRules"))

-- Spa/FloorTrail, required at Start so the pure specs can load this file without a place
local FloorTrail: any = nil

local BoxGuideController = {}

BoxGuideController.FLAG = "boxGuide"
BoxGuideController.FAR = 25 -- studs, flat: further than this from the closed box shows the way back
BoxGuideController.NEAR = 15 -- studs: back within this hides it
BoxGuideController.EVERY = 0.25 -- seconds between checks
BoxGuideController.BOX_NAME = "PH_DeliveryBox" -- Effects/OpeningScene's box

function BoxGuideController.want(shown: boolean, distance: number): boolean
	if shown then
		return distance > BoxGuideController.NEAR
	end
	return distance > BoxGuideController.FAR
end

local mine = false
local box: BasePart? = nil

local function findBox(): BasePart?
	local known = box
	if known and known:IsDescendantOf(Workspace) then
		return known
	end
	local found: Instance? = Workspace:FindFirstChild(BoxGuideController.BOX_NAME, true)
	if found and found:IsA("Model") then
		local model = found :: Model
		found = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	end
	local part: BasePart? = if found and found:IsA("BasePart") then found :: BasePart else nil
	box = part
	return part
end

local function stop()
	if mine then
		mine = false
		FloorTrail.hide()
	end
end

local function check()
	local player = Players.LocalPlayer
	if
		not LiveFlags.isOn(BoxGuideController.FLAG)
		or player:GetAttribute(SudsRules.BOX_ATTRIBUTE) ~= true
	then
		box = nil
		stop()
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local target = findBox()
	if root == nil or not root:IsA("BasePart") or target == nil then
		stop()
		return
	end
	if mine and not FloorTrail.isShown() then
		mine = false -- another step hid it; show it again below if still far
	end
	local apart = target.Position - (root :: BasePart).Position
	local distance = Vector3.new(apart.X, 0, apart.Z).Magnitude
	if BoxGuideController.want(mine, distance) then
		if not mine then
			if FloorTrail.isShown() then
				return -- another step's trail is up; leave it be
			end
			mine = true
			FloorTrail.show(target.Position) -- once: the trail follows the feet by itself, and the box stays put
		end
	else
		stop()
	end
end

function BoxGuideController.Init(_controllers: { [string]: any }) end

function BoxGuideController.Start()
	FloorTrail = require(script.Parent.Parent:WaitForChild("Spa"):WaitForChild("FloorTrail")) :: any
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal(SudsRules.BOX_ATTRIBUTE):Connect(check)
	task.spawn(function()
		while true do
			task.wait(BoxGuideController.EVERY)
			-- nothing to do once the box is opened for good; the loop stays light (one attribute read)
			if mine or player:GetAttribute(SudsRules.BOX_ATTRIBUTE) == true then
				check()
			end
		end
	end)
end

return BoxGuideController
