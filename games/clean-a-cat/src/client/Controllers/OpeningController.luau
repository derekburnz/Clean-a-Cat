--!strict
-- OpeningController: the opening (claim #285, switches openingBox and sudsWash, off by default). A truck hits a bump,
-- a plain brown box falls in front of the player (Effects/OpeningScene, Motion-FX), the camera comes back, and the
-- player taps the box to find the muddy kitten who becomes Suds.
--
-- The server decides when it plays: it sets the Player attribute SudsBox (SudsRules.BOX_ATTRIBUTE) to true while it
-- holds the kitten back for the box, which is only before a brand new save ever opened it. So the scene plays once
-- per save, again on a rejoin before the tap, and never for an older save. The tap is the player's own: the box opens
-- only after the server accepts RequestOpenBox (it sets SudsBox to false), then the kitten peeks and shakes.
--
-- The carry (Derek 2026-11-24: "we should pick him up out of crate"): the tip line says "Pick him up" and the player
-- taps him (a prompt on the kitten). He goes into their folded arms with a purr (Effects/Carry), and the floor trail
-- and "Wash him" lead to the tub, where a prompt sets him down. RequestPlaceKitten asks the server to hand him to the
-- tub (it checks the player stands by it); his hop in plays at once, and the camera eases into the close-up wash
-- view (Effects/WashCamera, Derek: "after you place him in the tub it should switch to the minigame view") with the
-- player's movement held while it is up. "Open the spa!" on his naming card eases it back out (RecapController calls
-- leaveWash). No window or menu opens by itself, and nothing is done for the player.
--
-- It starts the instant it can (Derek: hook them instantly, no standing still): the server marks the box as the save
-- loads, and on a plot the box's spot is known without the character, so the shot starts without waiting for it.
-- The console says how long after the join the truck started, to measure on a phone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SudsRules = require(Shared:WaitForChild("SudsRules"))

local Client = script.Parent.Parent
local Carry = require(Client:WaitForChild("Effects"):WaitForChild("Carry"))
local FloorTrail = require(Client:WaitForChild("Spa"):WaitForChild("FloorTrail"))
local OpeningScene = require(Client:WaitForChild("Effects"):WaitForChild("OpeningScene"))
local UI = require(Client:WaitForChild("UI"))
local WashCamera = require(Client:WaitForChild("Effects"):WaitForChild("WashCamera"))

local AHEAD = 6 -- studs in front of the player where the box lands without a SpotBox
local RETAP_SECONDS = 2 -- a tap the server did not answer can be tried again after this
local RESEND_SECONDS = 2 -- a placement the server has not taken yet is asked again this often
local RESENDS = 3
local CHARACTER_WAIT = 10
local PICK_REACH = 14 -- studs: the kitten's prompt
local PLACE_REACH = 10 -- studs: the tub's prompt, well inside the server's SudsRules.PLACE_REACH
local CLICK_REACH = { pick = 40, place = 12 } -- studs: a click or tap on the kitten or the tub
local SUDS = SudsRules.NAME
local RECAP_FLAG = "recapCard"
local TIP_PICK = { step = 1, total = 3, icon = "Paw", say = "Pick him up" }
local TIP_WASH = { step = 2, total = 3, icon = "Sponge", say = "Wash him" }

local OpeningController = {}

local player = Players.LocalPlayer
local scriptsStarted = os.clock() -- the client's scripts began (this module loads with Main)
local handle: OpeningScene.Handle? = nil
local tappedAt = -math.huge
local leading = false -- the trail and tip point at the tub until he is set down there
local picker: Instance? = nil -- the prompt and click on the kitten in the box
local placer: BasePart? = nil -- the tub's prompt while he is carried
local placing = false -- he is being set down: his hop plays while the server hands him out
local wash: WashCamera.Handle? = nil
local controlsHeld = false
local scrub: any = nil

local function boxState(): unknown
	return player:GetAttribute(SudsRules.BOX_ATTRIBUTE)
end

-- The character's walking controls (Roblox's PlayerModule), or nil.
local function controls(): any
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = if scripts then scripts:FindFirstChild("PlayerModule") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, found = pcall(function(): any
		return (require(module :: ModuleScript) :: any):GetControls()
	end)
	return if ok then found else nil
end

local function holdControls(hold: boolean)
	if hold == controlsHeld then
		return
	end
	local walk = controls()
	if walk == nil then
		return
	end
	controlsHeld = hold
	if hold then
		walk:Disable()
	else
		walk:Enable()
	end
end

-- The close-up wash view goes back to the player's camera, and they can walk again.
function OpeningController.leaveWash()
	local view = wash
	wash = nil
	if view then
		view.exit()
	end
	holdControls(false)
end

local function enterWash()
	if wash ~= nil then
		return
	end
	holdControls(true)
	wash = WashCamera.enter(WashCamera.shot(SpaLayout.tubSpot()))
end

local function clearPicker()
	local found = picker
	picker = nil
	if found then
		found:Destroy()
	end
end

local function clearPlacer()
	local found = placer
	placer = nil
	if found then
		found:Destroy()
	end
end

local function stopLeading()
	clearPlacer()
	if leading then
		leading = false
		FloorTrail.hide()
		UI.setTip(nil)
	end
end

local function clearScene()
	local scene = handle
	handle = nil
	placing = false
	clearPicker()
	stopLeading()
	if scene then
		scene.destroy()
	end
end

-- A prompt and a click on `part` that call `fn`, kept in one folder so they go together.
local function tapTarget(
	part: BasePart,
	action: string,
	reach: number,
	click: number,
	fn: () -> ()
): Instance
	local holder = Instance.new("Folder")
	holder.Name = "CleanACat_OpeningTap"
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = SUDS
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = reach
	prompt.Triggered:Connect(function(_who: Player)
		fn()
	end)
	prompt.Parent = part
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = click
	detector.MouseClick:Connect(function(_who: Player)
		fn()
	end)
	detector.Parent = part
	-- both go when the holder goes
	holder.Destroying:Connect(function()
		prompt:Destroy()
		detector:Destroy()
	end)
	holder.Parent = part
	return holder
end

-- Asks the server to hand him to the tub, again a few times while it has not (a lost message).
local function askToPlace()
	Remotes.event("RequestPlaceKitten"):FireServer()
	task.spawn(function()
		for _ = 1, RESENDS do
			task.wait(RESEND_SECONDS)
			if not placing or boxState() ~= false then
				return
			end
			Remotes.event("RequestPlaceKitten"):FireServer()
		end
		task.wait(RESEND_SECONDS)
		if placing and boxState() == false then
			-- The server never took it (it should not happen): the player gets their camera and walking back, and
			-- the server's own CARRY_SECONDS still puts him in the tub, so nobody is left frozen in the close view.
			OpeningController.leaveWash()
		end
	end)
end

-- "Wash him": the arms open, he hops into the tub and the camera eases into the wash view.
local function setDown()
	local scene = handle
	if scene == nil or placing or boxState() ~= false then
		return
	end
	placing = true
	stopLeading()
	askToPlace()
	enterWash()
	scene.placeIn(if scrub then scrub.seatSpot().Position else SpaLayout.tubSpot().Position)
end

-- He is in the player's arms: the trail and the tip lead to the tub, where a prompt sets him down.
local function leadToTub()
	leading = true
	local tub = SpaLayout.tubSpot()
	FloorTrail.show(tub.Position)
	UI.setTip(TIP_WASH)
	clearPlacer()
	local spot = Instance.new("Part")
	spot.Name = "CleanACat_OpeningTub"
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanTouch = false
	spot.Transparency = 1
	spot.Size = Vector3.new(4, 3, 4)
	spot.CFrame = if scrub then scrub.seatSpot() else tub
	tapTarget(spot, "Wash him", PLACE_REACH, CLICK_REACH.place, setDown)
	spot.Parent = Workspace
	placer = spot
end

-- The kitten peeked out of the open box: "Pick him up", and a tap on him lifts him into the player's arms.
local function offerPickUp(scene: OpeningScene.Handle)
	if handle ~= scene or boxState() ~= false then
		return
	end
	local function pickUp()
		local character = player.Character
		if handle ~= scene or character == nil or picker == nil then
			return
		end
		clearPicker()
		UI.setTip(nil)
		scene.pickUp(character, function()
			if handle == scene and boxState() == false then
				leadToTub()
			end
		end)
	end
	local kitten = scene.kitten
	local body = if kitten
		then kitten.PrimaryPart or kitten:FindFirstChildWhichIsA("BasePart", true)
		else nil
	if body == nil then
		-- no kitten to lift (should not happen): lead to the tub, where the prompt still sets him down
		leadToTub()
		return
	end
	clearPicker()
	picker = tapTarget(body :: BasePart, "Pick up", PICK_REACH, CLICK_REACH.pick, pickUp)
	UI.setTip(TIP_PICK)
end

-- Off a plot, the box lands AHEAD studs in front of the player, on the ground, facing the way the player faces.
local function landing(root: BasePart, character: Model): CFrame
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

-- The box's spot on the player's plot, known without the character; nil off a plot.
local function plotLanding(): CFrame?
	if SpaLayout.onPlot() and SpaLayout.PLOT_SPOTS[SudsRules.BOX_SPOT] then
		return SpaLayout.spot(SudsRules.BOX_SPOT)
	end
	return nil
end

-- How long the opening took to start, for a measure on a real phone.
local function sayStarted()
	local joined = player:GetAttribute(SudsRules.JOINED_ATTRIBUTE)
	local sinceJoin = if type(joined) == "number"
		then string.format("%.2f", Workspace:GetServerTimeNow() - joined)
		else "?"
	local sinceScripts = string.format("%.2f", os.clock() - scriptsStarted)
	print(
		`[Opening] truck moving {sinceJoin} s after the join, {sinceScripts} s after the scripts started`
	)
end

local function play()
	if handle ~= nil or boxState() ~= true or not LiveFlags.isOn(SudsRules.BOX_FLAG) then
		return
	end
	local spot = plotLanding()
	if spot == nil then
		-- Off a plot the box lands in front of the player, so this one waits for the character.
		local character = player.Character or player.CharacterAdded:Wait()
		local root = character:WaitForChild("HumanoidRootPart", CHARACTER_WAIT)
		if handle ~= nil or root == nil or not root:IsA("BasePart") or boxState() ~= true then
			return
		end
		spot = landing(root :: BasePart, character)
	end
	handle = OpeningScene.play(spot :: CFrame, { shot = true, onTap = onTap })
	sayStarted()
end

-- The server took the tap (SudsBox false): the flaps pop and the kitten peeks out, then the carry. The server
-- handing him out (SudsBox gone) after he was set down ends the scene; any other end (the switch off, or the server
-- putting him in the tub by itself) clears it at once.
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
	if state == false then
		scene.open(function()
			offerPickUp(scene)
		end)
		return
	end
	if placing then
		-- his hop into the tub is still playing: the scene goes once he lands, as the tub's kitten comes
		task.delay(Carry.HOP_SECONDS, function()
			if handle == scene then
				clearScene()
			end
		end)
		return
	end
	clearScene()
end

-- A cat came to the tub. Suds before he was set down (the server's own CARRY_SECONDS): the scene goes. Any other cat
-- means his wash is over, so the wash view goes back to the player.
local function onCatReady(_id: unknown, kind: unknown)
	if kind == SUDS then
		if handle ~= nil and not placing then
			clearScene()
		end
		return
	end
	OpeningController.leaveWash()
end

-- Suds is named. With the recap card off there is no "Open the spa!", so the wash view goes back now.
local function onStage()
	local stage = SudsRules.cleanStage(player:GetAttribute(SudsRules.ATTRIBUTE))
	if stage >= SudsRules.DONE and not LiveFlags.isOn(RECAP_FLAG) then
		OpeningController.leaveWash()
	end
end

function OpeningController.Init(controllers: { [string]: any })
	scrub = controllers.ScrubController
end

function OpeningController.Start()
	player:GetAttributeChangedSignal(SudsRules.BOX_ATTRIBUTE):Connect(onBoxChanged)
	player:GetAttributeChangedSignal(SudsRules.ATTRIBUTE):Connect(onStage)
	Remotes.event("CatReady").OnClientEvent:Connect(onCatReady)
	-- a new character (a reset) is the player's own again
	-- (Roblox's controls keep their enabled state across a respawn, so leaveWash's Enable is what frees them.)
	player.CharacterAdded:Connect(function()
		OpeningController.leaveWash()
	end)
	onBoxChanged()
end

return OpeningController
