--!strict
-- WashPopsController: feeds Effects/WashPops from the wash's own signals (Derek's playtest, 2026-11-26, issue 902).
-- Behind the switch washPops, off by default (rule 16: the wash is the first session). It only listens: it changes
-- nothing in ScrubController or the HUD.
--
--   ScrubController.meterChanged(fill, step)  a step's bar passing a third or two thirds pops "Nice!" or "Nearly
--                                             there!" over the cat, with a soft starUp (needs washMeter on)
--   Moments.ShakeOff(cat, step)               the step's done word ("Squeaky clean!", "So fresh!", ...), once per step
--   Moments.BowChosen(cat, bowId)             "Too cute!"
--   MudPatchCleared, SudsPopped, ClawSnipped, quick hits less than WashPops.CHAIN apart count a combo; from 3 an
--   BrushSwipe                                "x N" pops where the hit landed (a brush stroke at the last scrub
--                                             point), and every COMBO_CHIME hits a revealChime a little higher
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(Shared:WaitForChild("Moments"))

local WashPopsController = {}

WashPopsController.FLAG = "washPops"
WashPopsController.COMBO_CHIME = 10 -- every this many hits in one combo, a chime
WashPopsController.COMBO_FROM = 3 -- the "x N" shows from this count (Design: a quieter combo)
WashPopsController.LATHER_WORD = "So bubbly!" -- the lather bar has no shake off of its own; rinse follows it

-- The chime's pitch for a combo of `count`: a little higher each COMBO_CHIME, up to 1.5.
function WashPopsController.chimePitch(count: number): number
	local tier = math.floor(count / WashPopsController.COMBO_CHIME)
	return math.min(1.15 + 0.08 * tier, 1.5)
end

local scrub: any = nil

function WashPopsController.Init(controllers: { [string]: any })
	scrub = controllers.ScrubController
end

-- Beside the cat's head on the screen's right (the side away from the tools), so a word sits on open space and
-- not on the cat's face or the step title above it.
local function headOf(cat: Model): Vector3
	local box, size = cat:GetBoundingBox()
	local camera = workspace.CurrentCamera
	local right = if camera then camera.CFrame.RightVector else box.RightVector
	local reach = math.max(size.X, size.Z) * 0.75
	return box.Position + Vector3.new(0, size.Y * 0.3, 0) + right * reach
end

function WashPopsController.Start()
	local WashPops =
		require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("WashPops")) :: any
	local Audio = require(script.Parent.Parent:WaitForChild("Audio")) :: any
	local function on(): boolean
		return LiveFlags.isOn(WashPopsController.FLAG)
	end

	local lastCat: Model? = nil
	local said: { [string]: boolean } = {}
	local chain = WashPops.newChain()
	local lastPoint: Vector3? = nil
	local function forCat(cat: Model)
		if cat ~= lastCat then
			lastCat = cat
			said = {}
			chain = WashPops.newChain()
			lastPoint = nil
		end
	end

	-- progress words
	local meterStep: string? = nil
	local meterFill = 0
	if scrub and scrub.meterChanged then
		scrub.meterChanged:Connect(function(fill: number?, step: string?)
			if step ~= meterStep then
				meterStep, meterFill = step, 0
			end
			if step == nil or fill == nil then
				return
			end
			local passed = WashPops.marksPassed(meterFill, fill)
			meterFill = fill
			local cat = lastCat
			if #passed == 0 or not on() or cat == nil or cat.Parent == nil then
				return
			end
			local mark = passed[#passed]
			local key = step .. "#" .. mark
			if said[key] then
				return
			end
			said[key] = true
			WashPops.cheer(WashPops.MARK_WORDS[mark], headOf(cat), "cheer")
			Audio.play("starUp", { pitch = 1.3 })
		end)
	end

	local function done(cat: Model, step: string)
		forCat(cat)
		local text = WashPops.DONE_WORDS[step]
			or (if step == "lather" then WashPopsController.LATHER_WORD else nil)
		if text == nil or said[step] or not on() then
			return
		end
		said[step] = true
		WashPops.cheer(text, headOf(cat), "done")
	end
	Moments.ShakeOff:Connect(done)
	Moments.BowChosen:Connect(function(cat: Model, _bowId: string)
		done(cat, "bow")
	end)

	local function hit(cat: Model, at: Vector3?)
		forCat(cat)
		local count = WashPops.chain(chain, os.clock())
		if count < WashPopsController.COMBO_FROM or not on() then
			return
		end
		WashPops.combo(count, at or lastPoint or headOf(cat))
		if count % WashPopsController.COMBO_CHIME == 0 then
			Audio.play("revealChime", { pitch = WashPopsController.chimePitch(count) })
		end
	end
	Moments.ScrubStart:Connect(function(cat: Model, _at: Vector3)
		forCat(cat)
	end)
	Moments.BathStart:Connect(forCat)
	Moments.ClawsStart:Connect(forCat)
	Moments.ScrubMove:Connect(function(cat: Model, point: Vector3, _normal: Vector3, _speed: number)
		forCat(cat)
		lastPoint = point
	end)
	Moments.MudPatchCleared:Connect(function(cat: Model, at: Vector3, _left: number)
		hit(cat, at)
	end)
	Moments.SudsPopped:Connect(function(cat: Model, at: Vector3, _left: number)
		hit(cat, at)
	end)
	Moments.ClawSnipped:Connect(function(cat: Model, at: Vector3)
		hit(cat, at)
	end)
	Moments.BrushSwipe:Connect(function(cat: Model, _strokes: number)
		hit(cat, nil)
	end)
end

return WashPopsController
