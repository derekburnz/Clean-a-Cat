--!strict
-- EffectsController: plays effects on the game's moments (Shared.Moments). It only listens.
-- Scrub effects sit behind the LiveFlags switch `scrubEffects`, reveal effects behind `revealEffects` and brush and bow
-- effects behind `fluffEffects`, and the cats' procedural motion (Effects/CatMotion) behind `catMotion`, all off by
-- default, because they change the first session. Dryer air is behind `dryEffects`. There is no stink smoke
-- (Derek, 2026-11-25: mud on the coat shows a dirty cat). The opening truck and box scene (Effects/OpeningScene) is
-- started by Controllers/OpeningController.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BrushShine = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("BrushShine"))
local CarryShared =
	require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("CarryShared"))
local CatMotion = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("CatMotion"))
local CatWalkOut = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("CatWalkOut"))
local CounterCrate =
	require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("CounterCrate"))
local Crate = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Crate"))
local CustomerLeave =
	require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("CustomerLeave"))
local CustomerMotion =
	require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("CustomerMotion"))
local Effects = require(script.Parent.Parent:WaitForChild("Effects"))
local FoamDrop = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("FoamDrop"))
local GardenAmbience =
	require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("GardenAmbience"))
local GiftStand = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("GiftStand"))
local Hop = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Hop"))
local Sky = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Sky"))
local VisitorArrival =
	require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("VisitorArrival"))
local WorkerBar = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("WorkerBar"))

local SCRUB_FLAG = "scrubEffects"
local REVEAL_FLAG = "revealEffects"
local FLUFF_FLAG = "fluffEffects"
local WALK_OUT_FLAG = "catWalkOut"
local CLAIM_FLAG = "claimFx" -- issue 802: claim sound and sparkles
local MOTION_FLAG = "catMotion"
local DRY_FLAG = "dryEffects"
local SHARED_CARRY_FLAG = "carryShared"
local CUSTOMER_WALK_FLAG = "customerWalk"
local WASH_METER_FLAG = "washMeter"
local SHAKE_BEATS = { 0, 0.18, 0.36 } -- seconds: flecks fly with each swing of the shake
local SPRAY_HOLD = 0.15 -- seconds the spray keeps going after the last RinseSpray
local SUDS_FLAG = "sudsWash"
local SUDS_HOP_HEIGHT = 0.7 -- studs
local SUDS_HOP_SECONDS = 0.32
local BOW_DROP = 0.3 -- studs below the top of the cat, about where a bow sits
local GLOW_SECONDS = 0.6
local BOW_POP_SECONDS = 0.25

-- The middle of the cat and the top of the cat, from its bounding box. Works for any pivot (the generated cats pivot
-- at the base centre, the placeholder at the middle of its ball) and any scale.
local function coatPoint(cat: Model): Vector3
	return (cat:GetBoundingBox()).Position
end

local function topPoint(cat: Model): Vector3
	local box, size = cat:GetBoundingBox()
	return box.Position + Vector3.new(0, size.Y / 2 - BOW_DROP, 0)
end

local EffectsController = {}

local foamPreset = "foamTrail" -- later: foamTrailWide with Bubble Soap, foamTrailGold with the Golden Sponge pass

function EffectsController.Init(_controllers: { [string]: any })
	Effects.start()
end

function EffectsController.Start()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local LiveFlags = require(shared:WaitForChild("LiveFlags")) :: any
	local Moments = require(shared:WaitForChild("Moments")) :: any

	-- the draft sky and light, while its switch is on (instant rollback when it goes off)
	Sky.watch(LiveFlags.ATTRIBUTE_PREFIX .. "skyDraft")
	-- the tub's water, foam and bubbles come alive (Effects/TubLife, switch tubLife, issue 879)
	local TubLife =
		require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("TubLife")) :: any
	TubLife.start(function(): boolean
		return LiveFlags.isOn("tubLife")
	end)
	-- Jo walks in to his hire pad when the first helper card starts its trail (Effects/JoArrive, issue 913)
	local JoArrive =
		require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("JoArrive")) :: any
	JoArrive.start(function(): boolean
		return LiveFlags.isOn("joArrive")
	end)

	CatMotion.start(Effects.tier(), function(): boolean
		return LiveFlags.isOn(MOTION_FLAG)
	end)
	-- other players' carried cats; the switch counts only once LiveFlags lists it as off by default (an unlisted key
	-- reads as on)
	CarryShared.start(function(): boolean
		return LiveFlags.OFF_BY_DEFAULT[SHARED_CARRY_FLAG] == true
			and LiveFlags.isOn(SHARED_CARRY_FLAG)
	end)
	-- the customers' walk in and idle (Model-Agent's townsfolk), the same off-by-default guard
	CustomerMotion.start(function(): boolean
		return LiveFlags.OFF_BY_DEFAULT[CUSTOMER_WALK_FLAG] == true
			and LiveFlags.isOn(CUSTOMER_WALK_FLAG)
	end)

	-- The wash bar (switch washMeter, Derek's salon video 2026-11-25): when a step's bar fills the cat shakes off the
	-- rest with flecks flying; the rinse sprays water off the fur and ends with the last foam dropping round the feet.
	-- The Moments arrive with Gameplay's wash bar PR, so each is hooked only when it exists.
	local function meterOn(): boolean
		return LiveFlags.OFF_BY_DEFAULT[WASH_METER_FLAG] == true and LiveFlags.isOn(WASH_METER_FLAG)
	end
	if Moments.ShakeOff then
		Moments.ShakeOff:Connect(function(cat: Model, step: string)
			if not meterOn() or not cat:IsDescendantOf(workspace) then
				return
			end
			CatMotion.shake(cat)
			Effects.stopStream(foamPreset)
			Effects.stopStream("rinseSpray")
			Effects.stopStream("showerStream")
			local preset = if step == "scrub"
				then "shakeFlecks"
				elseif step == "rinse" then "shakeDroplets"
				else "revealSparkle"
			-- flecks and drops fly with each swing; sparkles burst once, so with the brush's own sparkle there are
			-- never more than 3 flashes a second (#6; Sync's pass on dc51ecb counted 4 in 0.36 s at the fluff)
			local beats: { number } = if preset == "revealSparkle" then { 0 } else SHAKE_BEATS
			for _, at in beats do
				task.delay(at, function()
					if cat:IsDescendantOf(workspace) then
						Effects.burst(preset, coatPoint(cat))
					end
				end)
			end
			if step == "rinse" then
				FoamDrop.drop(cat)
			end
		end)
	end
	-- Gameplay-Engineer's switch showerAim and ToolOnCat.nozzle() (issue 899): the shower held off the fur, aimed in
	local ShowerStream =
		require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("ShowerStream")) :: any
	local function aimOn(): boolean
		return LiveFlags.OFF_BY_DEFAULT["showerAim"] == true and LiveFlags.isOn("showerAim")
	end
	local function showerNozzle(): CFrame?
		local ok, at = pcall(function()
			local ToolOnCat =
				require(script.Parent.Parent:WaitForChild("Spa"):WaitForChild("ToolOnCat")) :: any
			local nozzle = (ToolOnCat :: any).nozzle :: (() -> any)?
			if nozzle == nil then
				return nil
			end
			return (nozzle :: () -> any)()
		end)
		return if ok and typeof(at) == "CFrame" then at :: CFrame else nil
	end
	if Moments.RinseSpray then
		local sprayAt = 0
		Moments.RinseSpray:Connect(function(_cat: Model, point: Vector3, normal: Vector3)
			if not meterOn() then
				return
			end
			-- the emitter sprays along its +Y, so turn the look-along-normal frame to point +Y out of the fur
			local aim = CFrame.lookAt(point, point + normal) * CFrame.Angles(-math.pi / 2, 0, 0)
			-- (showerAim, issue 899) the water comes from the shower's nozzle into the fur: a thin line and fast drops
			-- along it, and only a small splash where it lands
			local nozzle = if aimOn() then showerNozzle() else nil
			if nozzle then
				ShowerStream.show(nozzle.Position, point)
				Effects.streamFrom("showerStream", nozzle, 1)
				Effects.streamFrom("rinseSpray", aim, 0.4)
			else
				Effects.streamFrom("rinseSpray", aim, 1)
			end
			local now = os.clock()
			sprayAt = now
			task.delay(SPRAY_HOLD, function()
				if sprayAt == now then
					Effects.stopStream("rinseSpray")
					Effects.stopStream("showerStream")
				end
			end)
		end)
	end

	local function scrubOn(): boolean
		return LiveFlags.isOn(SCRUB_FLAG)
	end

	Moments.ScrubMove:Connect(
		function(_cat: Model, hitPoint: Vector3, _normal: Vector3, dragSpeed: number)
			if scrubOn() then
				Effects.stream(foamPreset, hitPoint, dragSpeed)
			end
		end
	)
	-- A stray going to the window seat (#7): a happy little hop where it sits, with a soft puff as it lands.
	if Moments.CatToWindow then
		Moments.CatToWindow:Connect(function(cat: Model)
			if LiveFlags.isOn(FLUFF_FLAG) and cat:IsDescendantOf(workspace) then
				Hop.hop(cat)
			end
		end)
	end
	-- A customer's washed cat goes home: it hops out of the tub and trots to the front of the line, fading as it
	-- goes out (switch catWalkOut; Sync's issue 773 run found nothing carried it out).
	if Moments.CatReturned then
		local SpaLayout = require(shared:WaitForChild("SpaLayout")) :: any
		Moments.CatReturned:Connect(function(cat: Model)
			if
				LiveFlags.OFF_BY_DEFAULT[WALK_OUT_FLAG] == true
				and LiveFlags.isOn(WALK_OUT_FLAG)
				and cat:IsDescendantOf(workspace)
			then
				local ok, way = pcall(SpaLayout.spot, "SpotQueue1", Players.LocalPlayer)
				if ok and typeof(way) == "CFrame" then
					CatWalkOut.play(cat, way)
				end
			end
		end)
	end
	-- A Free Reward or the gift pet claimed: one sound and three sparkles where the player tapped (switch claimFx)
	do
		local ClaimFx =
			require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("ClaimFx")) :: any
		local UI = require(script.Parent.Parent:WaitForChild("UI")) :: any
		ClaimFx.start(UI, function(): boolean
			return LiveFlags.isOn(CLAIM_FLAG)
		end)
	end
	Moments.ScrubStop:Connect(function()
		Effects.stopStream(foamPreset)
	end)
	Moments.CatClean:Connect(function(cat: Model)
		CatMotion.shake(cat)
		if not LiveFlags.isOn(REVEAL_FLAG) or not cat:IsDescendantOf(workspace) then
			return
		end
		local center = coatPoint(cat)
		Effects.stopStream(foamPreset)
		Effects.burst("revealSparkle", center)
		Effects.burst("shakeDroplets", center)
	end)
	-- Each brush stroke sends a shine down the coat, and the last one ends in a sparkle (Derek's dev test: no fur
	-- puffs, "just have it shine top to bottom then sparkle when done"). The coat's colour change is BrushShine's too.
	Moments.BrushSwipe:Connect(function(cat: Model, _stroke: number)
		if LiveFlags.isOn(FLUFF_FLAG) and cat:IsDescendantOf(workspace) then
			BrushShine.sweep(cat)
		end
	end)
	Moments.CatFluffed:Connect(function(cat: Model)
		CatMotion.wiggle(cat)
		if LiveFlags.isOn(FLUFF_FLAG) then
			BrushShine.done(cat)
			Effects.glow(cat, GLOW_SECONDS)
		end
	end)
	Moments.BowChosen:Connect(function(cat: Model, _bowId: string)
		if LiveFlags.isOn(FLUFF_FLAG) and cat:IsDescendantOf(workspace) then
			-- The bow BowFit put on the cat pops in on its BowSlot; the hearts start where it sits.
			local bow = cat:FindFirstChild("WornBow", true)
			local slot = if bow then bow:FindFirstChild("BowSlot", true) else nil
			if bow and bow:IsA("Model") and slot and slot:IsA("Attachment") then
				Effects.popIn(bow :: Model, slot :: Attachment, BOW_POP_SECONDS)
				Effects.burst("bowHearts", (slot :: Attachment).WorldPosition)
			else
				Effects.burst("bowHearts", topPoint(cat))
			end
		end
	end)
	-- Dryer air: follows the nozzle's Air attachment (its +Y points down at the cat) each frame while a cat dries.
	-- DryStart and DryStop arrive with the dry step; until Shared.Moments has them nothing is bound.
	local drying: RBXScriptConnection? = nil
	local function stopDrying()
		if drying then
			drying:Disconnect()
			drying = nil
		end
		Effects.stopStream("dryerAir")
	end
	if Moments.DryStart and Moments.DryStop then
		Moments.DryStart:Connect(function(_cat: Model, station: Model)
			stopDrying()
			local airAttachment = if typeof(station) == "Instance"
				then station:FindFirstChild("Air", true)
				else nil
			if
				not LiveFlags.isOn(DRY_FLAG)
				or not airAttachment
				or not airAttachment:IsA("Attachment")
			then
				return
			end
			local nozzle = airAttachment :: Attachment
			drying = RunService.Heartbeat:Connect(function()
				if nozzle.Parent == nil then
					stopDrying()
					return
				end
				Effects.streamFrom("dryerAir", nozzle.WorldCFrame, 1)
			end)
		end)
		Moments.DryStop:Connect(stopDrying)
	end

	-- Suds (#285): a sparkle at his new collar when he is named, and a small hop when a player taps him on his bed.
	-- SudsNamed only fires with sudsWash on; SudsTapped arrives with sudsMascot and only fires with it on.
	Moments.SudsNamed:Connect(function(cat: Model)
		if not LiveFlags.isOn(SUDS_FLAG) or not cat:IsDescendantOf(workspace) then
			return
		end
		local at = topPoint(cat)
		for _, d in cat:GetDescendants() do
			-- the naming clones the clean model's collar as it is, so match by suffix (CleanACat_Cat_Suds_Sit_Collar)
			if string.sub(d.Name, -7) == "_Collar" and d:IsA("PVInstance") then
				at = (d :: PVInstance):GetPivot().Position
				break
			end
		end
		Effects.burst("revealSparkle", at)
		CatMotion.wiggle(cat)
	end)
	if Moments.SudsTapped then
		local hopping: { [Model]: boolean } = {}
		Moments.SudsTapped:Connect(function(suds: Model)
			if
				typeof(suds) ~= "Instance"
				or not suds:IsA("Model")
				or hopping[suds]
				or not suds:IsDescendantOf(workspace)
			then
				return
			end
			CatMotion.wiggle(suds)
			if Effects.reducedMotion() then
				return
			end
			-- A local hop: the server placed him and never moves him per frame, so this client may lift him
			-- and must put him back exactly where he was.
			hopping[suds] = true
			local base = suds:GetPivot()
			local started = os.clock()
			local hop: RBXScriptConnection
			hop = RunService.PreRender:Connect(function()
				local u = (os.clock() - started) / SUDS_HOP_SECONDS
				if u >= 1 or suds.Parent == nil then
					hop:Disconnect()
					hopping[suds] = nil
					if suds.Parent then
						suds:PivotTo(base)
					end
					return
				end
				suds:PivotTo(base * CFrame.new(0, SUDS_HOP_HEIGHT * 4 * u * (1 - u), 0))
			end)
		end)
	end

	-- A special visitor walks in (issue #528): glow, gold sparkles at the feet and a star over their head while they
	-- are in the spa. The Moment comes with Gameplay's special visitors (#510), behind its own switch.
	if Moments.VisitorArrived then
		-- `again`: the line was redrawn and this is a new figure for a visitor already seen (Gameplay, #566)
		Moments.VisitorArrived:Connect(function(visitor: any, again: any)
			if typeof(visitor) == "Instance" and visitor:IsA("Model") then
				VisitorArrival.arrive(visitor, again == true)
			end
		end)
	end

	-- Crates and pets (issue #528): Gameplay fires these with special visitors (#510) and crates and pets (#511,
	-- #512), behind those features' switches. The open and the reveal are the same for every pet.
	local function onModel(name: string, play: (Model) -> ())
		if Moments[name] then
			Moments[name]:Connect(function(model: any)
				if typeof(model) == "Instance" and model:IsA("Model") then
					play(model)
				end
			end)
		end
	end
	onModel("CrateDropped", Crate.drop)
	onModel("CrateOpened", Crate.open)
	-- the pet is a cat body: the cats' motion lets go of it while it is resized, then it wiggles
	local petMotion =
		{ hold = CatMotion.hold, release = CatMotion.release, wiggle = CatMotion.wiggle }
	onModel("PetRevealed", function(pet: Model)
		Crate.reveal(pet, petMotion)
	end)
	onModel("PetStarUp", Crate.starUp)

	-- The bar over a cat a worker is washing (issue #528): drawn from the cat's WorkerProgress attribute, which
	-- Gameplay sets with workers (#509), behind that feature's switch. Nothing shows until it is set.
	WorkerBar.start()

	-- The gift stand's light (issue #528): from the stand's Lit attribute, which GiftService sets at 7:00 of the
	-- owner's play (giftStand, #521). Nothing shows until a stand is lit.
	GiftStand.start()

	-- The built Garden (#515): petals drift from the blossom tree and its clouds breathe, only near the camera.
	GardenAmbience.start()
	-- a customer's cat comes to the counter in its crate, steps out and sits, then the crate fades (#757)
	CounterCrate.start()

	-- A cat's heart bar ran out (issue #528): the customer turns and walks off with it, head low, and fades. The
	-- Moment comes with Gameplay's heart bar (#543, townsfolk on) and passes the customer's figure.
	if Moments.CatLeft then
		Moments.CatLeft:Connect(function(figure: any)
			if typeof(figure) == "Instance" and figure:IsA("Model") then
				CustomerLeave.leave(figure)
			end
		end)
	end

	Moments.MudPatchCleared:Connect(
		function(_cat: Model, patchPosition: Vector3, _patchesLeft: number)
			if scrubOn() then
				Effects.burst("mudChunks", patchPosition)
			end
		end
	)
end

return EffectsController
