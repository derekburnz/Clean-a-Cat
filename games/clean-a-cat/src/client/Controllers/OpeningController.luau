--!strict
-- OpeningController: the opening (claim #285, switches openingBox and sudsWash, off by default). A truck hits a bump,
-- a plain brown box falls in front of the player (Effects/OpeningScene, Motion-FX), the camera comes back, and the
-- player taps the box to find the muddy kitten who becomes Suds.
--
-- The server decides when it plays: it sets the Player attribute SudsBox (SudsRules.BOX_ATTRIBUTE) to true while it
-- holds the kitten back for the box, which is only before a brand new save ever opened it. So the scene plays once
-- per save, again on a rejoin before the tap, and never for an older save. The tap is the player's own: the box opens
-- only after the server accepts RequestOpenBox (it sets SudsBox to false), then the kitten peeks, shakes and hops
-- out, and the server's kitten sits in the tub. The floor trail and the tip line (their own switches) lead the
-- player there until the first scrub. No window or menu opens by itself.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(Shared:WaitForChild("Moments"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SudsRules = require(Shared:WaitForChild("SudsRules"))

local Client = script.Parent.Parent
local FloorTrail = require(Client:WaitForChild("Spa"):WaitForChild("FloorTrail"))
local OpeningScene = require(Client:WaitForChild("Effects"):WaitForChild("OpeningScene"))
local UI = require(Client:WaitForChild("UI"))

local AHEAD = 6 -- studs in front of the player where the box lands without a SpotBox
local RETAP_SECONDS = 2 -- a tap the server did not answer can be tried again after this
local CHARACTER_WAIT = 10
local TIP = { step = 1, total = 3, icon = "Sponge", say = "Wash him" }

local OpeningController = {}

local player = Players.LocalPlayer
local handle: OpeningScene.Handle? = nil
local tappedAt = -math.huge
local leading = false -- the trail and tip point at the tub until the first scrub

local function boxState(): unknown
	return player:GetAttribute(SudsRules.BOX_ATTRIBUTE)
end

local function stopLeading()
	if leading then
		leading = false
		FloorTrail.hide()
		UI.setTip(nil)
	end
end

local function leadToTub()
	leading = true
	FloorTrail.show(SpaLayout.tubSpot().Position)
	UI.setTip(TIP)
end

-- The box's landing: the plot's SpotBox, else AHEAD studs in front of the player, on the ground, facing the way
-- the player faces.
local function landing(root: BasePart, character: Model): CFrame
	if SpaLayout.onPlot() and SpaLayout.PLOT_SPOTS[SudsRules.BOX_SPOT] then
		return SpaLayout.spot(SudsRules.BOX_SPOT)
	end
	local facing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	facing = if facing.Magnitude > 0.01 then facing.Unit else Vector3.new(0, 0, -1)
	local above = root.Position + facing * AHEAD
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = Workspace:Raycast(above, Vector3.new(0, -30, 0), params)
	local ground = if hit then hit.Position else above - Vector3.new(0, 3, 0)
	return CFrame.lookAt(ground, ground + facing)
end

local function onTap()
	if boxState() ~= true or os.clock() - tappedAt < RETAP_SECONDS then
		return
	end
	tappedAt = os.clock()
	Remotes.event("RequestOpenBox"):FireServer()
end

local function play()
	if handle ~= nil or boxState() ~= true or not LiveFlags.isOn(SudsRules.BOX_FLAG) then
		return
	end
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", CHARACTER_WAIT)
	if handle ~= nil or root == nil or not root:IsA("BasePart") or boxState() ~= true then
		return
	end
	handle = OpeningScene.play(landing(root :: BasePart, character), { shot = true, onTap = onTap })
end

-- The server took the tap (SudsBox false): the flaps pop, the kitten peeks and hops out toward the spa, then the
-- box goes and the server's kitten is in the tub. Any other end (the switch off) just clears the scene.
local function onBoxChanged()
	local state = boxState()
	if state == true then
		task.spawn(play)
		return
	end
	local scene = handle
	if scene == nil then
		return
	end
	if state ~= false then
		handle = nil
		scene.destroy()
		return
	end
	scene.open(function()
		scene.hopOut(SpaLayout.tubSpot().Position, function()
			if handle == scene then
				handle = nil
			end
			scene.destroy()
			leadToTub()
		end)
	end)
end

function OpeningController.Init(_controllers: { [string]: any }) end

function OpeningController.Start()
	player:GetAttributeChangedSignal(SudsRules.BOX_ATTRIBUTE):Connect(onBoxChanged)
	Moments.ScrubStart:Connect(stopLeading)
	onBoxChanged()
end

return OpeningController
