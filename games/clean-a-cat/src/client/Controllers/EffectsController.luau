--!strict
-- EffectsController: plays effects on the game's moments (Shared.Moments). It only listens.
-- Scrub effects sit behind the LiveFlags switch `scrubEffects`, reveal effects behind `revealEffects` and brush and bow
-- effects behind `fluffEffects`, and the cats' procedural motion (Effects/CatMotion) behind `catMotion`, all off by
-- default, because they change the first session. Dryer air is behind `dryEffects`. There is no stink smoke
-- (Derek, 2026-11-25: mud on the coat shows a dirty cat). The opening truck and box scene (Effects/OpeningScene) is
-- started by Controllers/OpeningController.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BrushShine = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("BrushShine"))
local CarryShared =
	require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("CarryShared"))
local CatMotion = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("CatMotion"))
local CustomerMotion =
	require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("CustomerMotion"))
local Effects = require(script.Parent.Parent:WaitForChild("Effects"))
local Sky = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Sky"))

local SCRUB_FLAG = "scrubEffects"
local REVEAL_FLAG = "revealEffects"
local FLUFF_FLAG = "fluffEffects"
local MOTION_FLAG = "catMotion"
local DRY_FLAG = "dryEffects"
local SHARED_CARRY_FLAG = "carryShared"
local CUSTOMER_WALK_FLAG = "customerWalk"
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

	Moments.MudPatchCleared:Connect(
		function(_cat: Model, patchPosition: Vector3, _patchesLeft: number)
			if scrubOn() then
				Effects.burst("mudChunks", patchPosition)
			end
		end
	)
end

return EffectsController
