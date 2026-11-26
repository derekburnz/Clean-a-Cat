--!strict
-- PillPointerController: an arrow over the button at the end of a guided walk (Derek's playtest, 2026-11-26: "the
-- arrow is good but also have an arrow pointing towards the button at the end of destinations so they really know
-- where they are going/clicking"). Behind the switch pillPointer, off by default (rule 16: a first-session change).
--
-- While the floor trail leads somewhere (Spa/FloorTrail.target) and a prompt pill (Controllers/PromptController,
-- switch smallPrompts) stands for a thing within NEAR studs of that spot, a gold hand bobs just over that pill,
-- pointing down at it. On a phone the pill is the tap button, so the hand points at what to tap. It shows and hides
-- with the pill, and goes when the trail goes (the step is done). It only draws: it takes no tap and presses nothing.
-- Reduced Motion: the hand holds still.
--
--   PillPointerController.offsetY(step, pillHeight, arrowHeight) -> number   pure: the pointer gui's SizeOffset.Y so
--                                                                           its lower part lines up with the pill
--   PillPointerController.bob(t) -> number                                  pure: the hand's lift in px at t seconds
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local PillPointerController = {}

PillPointerController.FLAG = "pillPointer"
PillPointerController.PILL_NAME = "CleanACat_Prompt" -- PromptController's pill
PillPointerController.NEAR = 8 -- studs, flat: a pill for a thing this close to the trail's spot is the destination
PillPointerController.ARROW = 40 -- px: the hand's box
PillPointerController.BOB = 6 -- px
PillPointerController.BOB_HZ = 1.6
PillPointerController.EVERY = 0.1 -- seconds between checks of which pill is the destination

-- A BillboardGui's SizeOffset moves it by its own size (Y up). The pill is `pillHeight` tall at SizeOffset.Y `step`;
-- the pointer gui is the pill's height plus `arrowHeight`, with the hand in the top `arrowHeight`, so its bottom part
-- sits exactly on the pill: its middle is arrowHeight / 2 above the pill's middle.
function PillPointerController.offsetY(
	step: number,
	pillHeight: number,
	arrowHeight: number
): number
	return (step * pillHeight + arrowHeight / 2) / (pillHeight + arrowHeight)
end

function PillPointerController.bob(t: number): number
	return PillPointerController.BOB
		* math.abs(math.sin(t * math.pi * PillPointerController.BOB_HZ))
end

type Pointer = {
	gui: BillboardGui,
	hand: Frame,
	pill: BillboardGui,
	sync: () -> (),
	links: { RBXScriptConnection },
}

local pointers: { [BillboardGui]: Pointer } = {}

local function adorneeAt(gui: BillboardGui): Vector3?
	local adornee = gui.Adornee
	if adornee and adornee:IsA("BasePart") then
		return (adornee :: BasePart).Position
	elseif adornee and adornee:IsA("Attachment") then
		return (adornee :: Attachment).WorldPosition
	end
	return nil
end

local function drop(pill: BillboardGui)
	local p = pointers[pill]
	if p == nil then
		return
	end
	pointers[pill] = nil
	for _, link in p.links do
		link:Disconnect()
	end
	p.gui:Destroy()
end

local function make(pill: BillboardGui, parent: Instance)
	local Icons = require(
		script.Parent.Parent:WaitForChild("UI"):WaitForChild("HUD"):WaitForChild("Icons")
	) :: any
	local arrow = PillPointerController.ARROW
	local gui = Instance.new("BillboardGui")
	gui.Name = "CleanACat_Fx_PillPointer"
	gui.AlwaysOnTop = true
	gui.Active = false -- never takes a tap; the pill under it does
	gui.ResetOnSpawn = false
	gui.ClipsDescendants = false
	local hand = Instance.new("Frame")
	hand.Name = "Hand"
	hand.BackgroundTransparency = 1
	hand.AnchorPoint = Vector2.new(0.5, 0)
	hand.Size = UDim2.fromOffset(arrow, arrow)
	hand.Rotation = -90 -- the left-pointing hand turned to point down at the pill (as FloorTrail's marker)
	hand.Parent = gui
	Icons.draw("Pointer", hand)
	local function sync()
		local height = pill.Size.Y.Offset
		local step = pill.SizeOffset.Y
		gui.Adornee = pill.Adornee
		gui.ExtentsOffset = pill.ExtentsOffset
		gui.Size = UDim2.fromOffset(pill.Size.X.Offset, height + arrow)
		gui.SizeOffset =
			Vector2.new(pill.SizeOffset.X, PillPointerController.offsetY(step, height, arrow))
		gui.Enabled = pill.Enabled
	end
	sync()
	local links = {
		pill:GetPropertyChangedSignal("Enabled"):Connect(sync),
		pill:GetPropertyChangedSignal("Size"):Connect(sync),
		pill:GetPropertyChangedSignal("SizeOffset"):Connect(sync),
		pill.AncestryChanged:Connect(function()
			if pill.Parent == nil then
				drop(pill)
			end
		end),
	}
	gui.Parent = parent
	pointers[pill] = { gui = gui, hand = hand, pill = pill, sync = sync, links = links }
end

local function check(FloorTrail: any, playerGui: Instance)
	local target: Vector3? = if LiveFlags.isOn(PillPointerController.FLAG)
		then FloorTrail.target()
		else nil
	local want: { [BillboardGui]: boolean } = {}
	if target then
		for _, child in playerGui:GetChildren() do
			if child.Name == PillPointerController.PILL_NAME and child:IsA("BillboardGui") then
				local pill = child :: BillboardGui
				local at = adorneeAt(pill)
				if at then
					local apart = at - target
					if Vector3.new(apart.X, 0, apart.Z).Magnitude <= PillPointerController.NEAR then
						want[pill] = true
					end
				end
			end
		end
	end
	for pill in pointers do
		if not want[pill] then
			drop(pill)
		end
	end
	for pill in want do
		if pointers[pill] == nil then
			make(pill, playerGui)
		end
	end
end

function PillPointerController.Init(_controllers: { [string]: any }) end

function PillPointerController.Start()
	local FloorTrail =
		require(script.Parent.Parent:WaitForChild("Spa"):WaitForChild("FloorTrail")) :: any
	local Comfort = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Comfort")) :: any
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	task.spawn(function()
		while true do
			task.wait(PillPointerController.EVERY)
			check(FloorTrail, playerGui)
		end
	end)
	local began = os.clock()
	RunService.RenderStepped:Connect(function()
		if next(pointers) == nil then
			return
		end
		local lift = if Comfort.reducedMotion()
			then 0
			else PillPointerController.bob(os.clock() - began)
		for _, p in pointers do
			p.hand.Position = UDim2.new(0.5, 0, 0, -math.floor(lift + 0.5))
		end
	end)
end

return PillPointerController
