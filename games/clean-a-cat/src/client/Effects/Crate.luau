--!strict
-- Crate: the gift crate and the pet inside it (issue #528), on Model-Agent's CleanACat_Prop_PetCrate (child
-- ..._Lid_Swing pivoted on the hinge, opened by +LidOpenDegrees about the pivot's X; Attachments PetSeat and Burst)
-- and the CleanACat_Pet_* pets (the cat body, pivot at the base, a Burst attachment over the head).
--
--   drop     CrateDropped: the crate falls in from DROP_HEIGHT, lands with one small bounce and a puff of gold
--            sparkles, and ends exactly where the game put it
--   open     CrateOpened: on the tap, the lid swings open at once with a small overshoot and a burst of sparkles
--            from the open top. THE SAME EVERY TIME, whatever is inside: no shaking, no wait, no build-up, nothing
--            that spins past rarer pets or teases a near miss (monetization-policy; Planning-Agent's rule in #528)
--   reveal   PetRevealed: the pet pops up from its seat with a soft overshoot, a sparkle burst and a happy wiggle
--            (a side to side turn of the whole pet, Crate.wiggleAt).
--            One reveal for every rarity; the card and its chance show the rarity, not a bigger show
--   starUp   PetStarUp: three of the same pet fused, the result turns once on the spot with a little hop, a gold
--            glow and a burst
--   comfort  Reduced Motion: no fall, bounce, swing or spin; the lid is simply open, the pet simply there, the
--            sparkles still play (halved with Less sparkle, as every burst)
--
-- Client only and cosmetic. Works the same on a crate in the world or in a ViewportFrame's WorldModel. Every move is
-- worked out from where the model was when it started, and put back exactly at the end. Sparkles and the glow play
-- only in the world.
--
-- API
--   Crate.drop(crate) / Crate.open(crate) / Crate.reveal(pet) / Crate.starUp(pet)
--   Crate.fallAt(t) -> number    pure: studs over the landing spot at `t` seconds of the drop
--   Crate.lidAt(t) -> number     pure: share of the lid's open angle at `t` seconds of the open (1 open)
--   Crate.popAt(t) -> number     pure: the pet's scale share at `t` seconds of the reveal (1 full size)
--   Crate.spinAt(t) -> (number, number)   pure: turn (0 to 1 of a full turn) and hop (studs) of the star up
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent)

local Crate = {}

Crate.DROP_HEIGHT = 4 -- studs
Crate.FALL_SECONDS = 0.32
Crate.BOUNCE = 0.35 -- studs
Crate.BOUNCE_SECONDS = 0.22
Crate.LID_SECONDS = 0.32
Crate.LID_OVER = 0.08 -- share of the open angle it swings past before settling
Crate.LID_SETTLE = 0.18
Crate.POP_SECONDS = 0.4
Crate.SPIN_SECONDS = 0.6
Crate.WIGGLE_SECONDS = 0.6
Crate.WIGGLE = math.rad(9) -- each way, a happy side to side turn after the pop
Crate.HOP = 0.5 -- studs
Crate.LID_DEGREES = 110 -- when the crate has no LidOpenDegrees attribute
local GOLD = Color3.fromRGB(255, 214, 120)

function Crate.fallAt(t: number): number
	if t <= 0 then
		return Crate.DROP_HEIGHT
	end
	if t < Crate.FALL_SECONDS then
		local u = t / Crate.FALL_SECONDS
		return Crate.DROP_HEIGHT * (1 - u * u)
	end
	local b = t - Crate.FALL_SECONDS
	if b < Crate.BOUNCE_SECONDS then
		local u = b / Crate.BOUNCE_SECONDS
		return Crate.BOUNCE * 4 * u * (1 - u)
	end
	return 0
end

function Crate.lidAt(t: number): number
	if t <= 0 then
		return 0
	end
	local over = 1 + Crate.LID_OVER
	if t < Crate.LID_SECONDS then
		local u = t / Crate.LID_SECONDS
		return over * (1 - (1 - u) * (1 - u) * (1 - u))
	end
	local s = t - Crate.LID_SECONDS
	if s < Crate.LID_SETTLE then
		local u = s / Crate.LID_SETTLE
		local e = u * u * (3 - 2 * u)
		return over + (1 - over) * e
	end
	return 1
end

function Crate.popAt(t: number): number
	if t <= 0 then
		return 0
	end
	if t >= Crate.POP_SECONDS then
		return 1
	end
	local u = t / Crate.POP_SECONDS
	local c = 1.8
	local v = u - 1
	return math.max(0, 1 + (c + 1) * v * v * v + c * v * v)
end

function Crate.spinAt(t: number): (number, number)
	if t <= 0 or t >= Crate.SPIN_SECONDS then
		return if t >= Crate.SPIN_SECONDS then 1 else 0, 0
	end
	local u = t / Crate.SPIN_SECONDS
	local turn = u * u * (3 - 2 * u)
	return turn, Crate.HOP * 4 * u * (1 - u)
end

-- The pet's happy wiggle after the pop: a side to side turn that dies away (Sync's pass on dc51ecb: the cats'
-- own wiggle never reaches a pet, which has no cat rig).
function Crate.wiggleAt(t: number): number
	if t <= 0 or t >= Crate.WIGGLE_SECONDS then
		return 0
	end
	local u = t / Crate.WIGGLE_SECONDS
	return Crate.WIGGLE * math.sin(3 * 2 * math.pi * u * 0.5) * (1 - u)
end

-- Runs `step(t)` each frame for `seconds`, then `done()`. Stops early, still calling `done()`, when `model` leaves
-- its parent.
local function run(model: Model, seconds: number, step: (number) -> (), done: () -> ())
	local start = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if model.Parent == nil then
			if connection then
				connection:Disconnect()
			end
			done() -- still called, so whatever was taken (the cats' motion) is given back
			return
		end
		if t >= seconds then
			if connection then
				connection:Disconnect()
			end
			done()
			return
		end
		step(t)
	end)
	step(0)
end

local function attachment(model: Model, name: string): Attachment?
	local found = model:FindFirstChild(name, true)
	return if found and found:IsA("Attachment") then found :: Attachment else nil
end

-- Sparkles only for a model in the world: a crate shown in a ViewportFrame has no world position to burst at.
local function burstAt(model: Model, name: string, color: Color3?)
	if not model:IsDescendantOf(Workspace) then
		return
	end
	local a = attachment(model, name)
	local at = if a then a.WorldPosition else (model:GetBoundingBox()).Position
	Effects.burst("revealSparkle", at, color)
end

local function lidOf(crate: Model): PVInstance?
	for _, child in crate:GetChildren() do
		if child:IsA("PVInstance") and string.sub(child.Name, -#"_Lid_Swing") == "_Lid_Swing" then
			return child :: PVInstance
		end
	end
	return nil
end

function Crate.drop(crate: Model)
	local rest = crate:GetPivot()
	if Effects.reducedMotion() then
		burstAt(crate, "PetSeat", GOLD)
		return
	end
	local landed = false
	run(crate, Crate.FALL_SECONDS + Crate.BOUNCE_SECONDS, function(t)
		crate:PivotTo(rest + Vector3.new(0, Crate.fallAt(t), 0))
		if not landed and t >= Crate.FALL_SECONDS then
			landed = true
			local _, size = crate:GetBoundingBox()
			if crate:IsDescendantOf(Workspace) then
				Effects.burst(
					"revealSparkle",
					rest.Position + Vector3.new(0, size.Y * 0.1, 0),
					GOLD
				)
			end
		end
	end, function()
		crate:PivotTo(rest)
	end)
end

function Crate.open(crate: Model)
	local lid = lidOf(crate)
	local degrees = crate:GetAttribute("LidOpenDegrees")
	local angle = math.rad(if type(degrees) == "number" then degrees else Crate.LID_DEGREES)
	burstAt(crate, "Burst")
	if lid == nil then
		return
	end
	local hinge = lid :: PVInstance
	-- the lid's pivot in the crate's space, taken now, so the crate may sit anywhere
	local closed = crate:GetPivot():ToObjectSpace(hinge:GetPivot())
	local function at(share: number)
		hinge:PivotTo(crate:GetPivot() * closed * CFrame.Angles(angle * share, 0, 0))
	end
	if Effects.reducedMotion() then
		at(1)
		return
	end
	run(crate, Crate.LID_SECONDS + Crate.LID_SETTLE, function(t)
		at(Crate.lidAt(t))
	end, function()
		at(1)
	end)
end

-- The reveal's order (Review-QA on #561): the cats' motion lets go of the pet before it is resized, and takes it
-- back only at full size, so the head and tail never float round a shrunk body; the wiggle comes after.
Crate.REVEAL_ORDER = table.freeze({ "hold", "pop", "release", "wiggle" })

export type Motion = { hold: (Model) -> (), release: (Model) -> (), wiggle: (Model) -> () }

function Crate.reveal(pet: Model, motion: Motion?)
	local final = pet:GetScale()
	local function wiggle()
		if motion then
			motion.wiggle(pet) -- a cat rig, if the pet has one
		end
		if Effects.reducedMotion() or pet.Parent == nil then
			return
		end
		local rest = pet:GetPivot()
		run(pet, Crate.WIGGLE_SECONDS, function(t)
			pet:PivotTo(rest * CFrame.Angles(0, Crate.wiggleAt(t), 0))
		end, function()
			if pet.Parent then
				pet:PivotTo(rest)
			end
		end)
	end
	local function done()
		pet:ScaleTo(final)
		if motion then
			motion.release(pet)
		end
		wiggle()
		burstAt(pet, "Burst")
	end
	if Effects.reducedMotion() then
		done()
		return
	end
	if motion then
		motion.hold(pet)
	end
	run(pet, Crate.POP_SECONDS, function(t)
		pet:ScaleTo(final * math.max(0.05, Crate.popAt(t))) -- ScaleTo keeps the pivot, the pet's base
	end, done)
end

function Crate.starUp(pet: Model)
	local rest = pet:GetPivot()
	Effects.glow(pet, 1.2)
	burstAt(pet, "Burst", GOLD)
	if Effects.reducedMotion() then
		return
	end
	run(pet, Crate.SPIN_SECONDS, function(t)
		local turn, hop = Crate.spinAt(t)
		pet:PivotTo(rest * CFrame.new(0, hop, 0) * CFrame.Angles(0, 2 * math.pi * turn, 0))
	end, function()
		pet:PivotTo(rest)
		burstAt(pet, "Burst", GOLD)
	end)
end

return Crate
