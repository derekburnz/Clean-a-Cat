--!strict
-- EffectsController: plays effects on the game's moments (Shared.Moments). It only listens.
-- Scrub effects sit behind the LiveFlags switch `scrubEffects`, reveal effects behind `revealEffects` and brush and bow
-- effects behind `fluffEffects`, and the cats' procedural motion (Effects/CatMotion) behind `catMotion`, all off by
-- default, because they change the first session. Dryer air is behind `dryEffects`, stink wisps
-- over dirty cats behind `stinkEffects`, the opening truck and box scene (Effects/OpeningScene) behind `openingBox`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CatMotion = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("CatMotion"))
local CatPose = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("CatPose"))
local Effects = require(script.Parent.Parent:WaitForChild("Effects"))
local OpeningScene =
	require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("OpeningScene"))
local Stink = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Stink"))

local SCRUB_FLAG = "scrubEffects"
local REVEAL_FLAG = "revealEffects"
local FLUFF_FLAG = "fluffEffects"
local MOTION_FLAG = "catMotion"
local DRY_FLAG = "dryEffects"
local STINK_FLAG = "stinkEffects"
local OPENING_FLAG = "openingBox"
local OPENING_AHEAD = 6 -- studs in front of the player where the box lands
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

-- The coat colour for fur puffs: the cat's Body part when it has one ("Body" on placeholders, "<asset>_Body" on
-- the generated cats).
local function coatColor(cat: Model): Color3?
	for _, child in cat:GetChildren() do
		if child:IsA("BasePart") and CatPose.jointKey(child.Name) == "Body" then
			return child.Color
		end
	end
	return nil
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

	CatMotion.start(Effects.tier(), function(): boolean
		return LiveFlags.isOn(MOTION_FLAG)
	end)
	Stink.start(function(): boolean
		return LiveFlags.isOn(STINK_FLAG)
	end)

	local function scrubOn(): boolean
		return LiveFlags.isOn(SCRUB_FLAG)
	end

	Moments.ScrubStart:Connect(function(cat: Model)
		Stink.focus(cat)
	end)
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
		Stink.setLeft(cat, 0)
		if not LiveFlags.isOn(REVEAL_FLAG) or not cat:IsDescendantOf(workspace) then
			return
		end
		local center = coatPoint(cat)
		Effects.stopStream(foamPreset)
		Effects.burst("revealSparkle", center)
		Effects.burst("shakeDroplets", center)
	end)
	Moments.BrushSwipe:Connect(function(cat: Model, _stroke: number)
		if LiveFlags.isOn(FLUFF_FLAG) and cat:IsDescendantOf(workspace) then
			Effects.burst("furPuff", coatPoint(cat), coatColor(cat))
		end
	end)
	Moments.CatFluffed:Connect(function(cat: Model)
		CatMotion.wiggle(cat)
		if LiveFlags.isOn(FLUFF_FLAG) then
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

	-- The opening scene (#281), once per session while `openingBox` is on, in Studio only. A stand-in trigger so the
	-- scene can be watched there: the box lands OPENING_AHEAD studs in front of the player and opens on a tap. Gameplay
	-- replaces this with the real start (once per save, the spawn spot, the server's box_opened step).
	-- Studio only: a live flip of `openingBox` must never drop a truck on every player mid-session (Review-QA, #284).
	local openingPlayed = not RunService:IsStudio()
	local function playOpening()
		if openingPlayed or not LiveFlags.isOn(OPENING_FLAG) then
			return
		end
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root == nil or not root:IsA("BasePart") then
			return
		end
		openingPlayed = true
		local rootPart = root :: BasePart
		local facing = rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		facing = if facing.Magnitude > 0.01 then facing.Unit else Vector3.new(0, 0, -1)
		local above = rootPart.Position + facing * OPENING_AHEAD
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { character :: Model }
		params.FilterType = Enum.RaycastFilterType.Exclude
		local hit = workspace:Raycast(above, Vector3.new(0, -30, 0), params)
		local ground = if hit then hit.Position else above - Vector3.new(0, 3, 0)
		local handle: OpeningScene.Handle
		handle = OpeningScene.play(CFrame.lookAt(ground, ground + facing), {
			shot = true,
			onTap = function()
				handle.open()
			end,
		})
	end
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.wait(1)
		playOpening()
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. OPENING_FLAG)
		:Connect(playOpening)
	task.delay(1, playOpening)

	Moments.MudPatchCleared:Connect(
		function(cat: Model, patchPosition: Vector3, patchesLeft: number)
			Stink.focus(cat)
			Stink.setLeft(cat, patchesLeft)
			if scrubOn() then
				Effects.burst("mudChunks", patchPosition)
			end
		end
	)
end

return EffectsController
