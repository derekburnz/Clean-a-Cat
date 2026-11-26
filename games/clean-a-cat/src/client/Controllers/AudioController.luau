--!strict
-- AudioController: starts Audio and plays cues on the game's moments. It only listens: no remotes, no state.
-- Moments come from ReplicatedStorage.Shared.Moments (issue #3) once it exists; until then nothing is bound.
-- Settings: sound and music default to on until a settings screen exists, then it calls Audio.applySettings.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require(script.Parent.Parent:WaitForChild("Audio"))
local CueRules = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("CueRules"))

local AudioController = {}

local MUSIC_FLAG = "spaMusic"
local UI_SOUNDS_FLAG = "uiSounds" -- issue 800: window and More tray open and close sounds

-- The collar piece on a named Suds: any Model or part whose name ends in "_Collar" (the naming clones the clean
-- model's collar as it is, e.g. CleanACat_Cat_Suds_Sit_Collar). A BasePart to play at, or nil (plays 2D).
local function collarPart(cat: any): Instance?
	if typeof(cat) ~= "Instance" then
		return nil
	end
	for _, d in (cat :: Instance):GetDescendants() do
		if string.sub(d.Name, -7) == "_Collar" then
			if d:IsA("BasePart") then
				return d
			end
			local part = d:FindFirstChildWhichIsA("BasePart", true)
			if part then
				return part
			end
		end
	end
	return nil
end

local scrub: Audio.LoopHandle? = nil
local dryer: Audio.LoopHandle? = nil
local rinse: Audio.LoopHandle? = nil
local rinseAt = 0
local RINSE_HOLD = 0.2 -- seconds the spray sound keeps going after the last RinseSpray

local function at(instance: any): Instance?
	return if typeof(instance) == "Instance" then instance else nil
end

local function stopRinse()
	if rinse then
		rinse.stop()
		rinse = nil
	end
end

-- Moment name -> handler. Payloads follow Shared.Moments: the cat first, then the moment's values.
-- With helperPopups and helperPopFx on, the owner's own helper finishing a cat sounds once, as the popup's coinPop.
-- True when `cat` is in the local player's own plot (Workspace.SpaPlots.Plot<slot>).
local function ownCoinPop(cat: any): boolean
	if typeof(cat) ~= "Instance" then
		return false
	end
	local shared = ReplicatedStorage:WaitForChild("Shared")
	local LiveFlags = require(shared:WaitForChild("LiveFlags")) :: any
	if not (LiveFlags.isOn("helperPopups") and LiveFlags.isOn("helperPopFx")) then
		return false
	end
	local SpaLayout = require(shared:WaitForChild("SpaLayout")) :: any
	local ok, slot = pcall(SpaLayout.slotOf, Players.LocalPlayer)
	if not ok or type(slot) ~= "number" then
		return false
	end
	local plots = workspace:FindFirstChild("SpaPlots")
	local plot = plots and plots:FindFirstChild("Plot" .. slot)
	return plot ~= nil and (cat :: Instance):IsDescendantOf(plot)
end

local HANDLERS: { [string]: (...any) -> () } = {
	ScrubStart = function(cat: any)
		if scrub then
			scrub.stop()
		end
		scrub = Audio.loop("scrubLoop", if typeof(cat) == "Instance" then cat else nil)
	end,
	ScrubMove = function(_cat: any, _hitPoint: any, _normal: any, dragSpeed: any)
		if scrub and type(dragSpeed) == "number" then
			scrub.setSpeed(CueRules.scrubLoopSpeed(dragSpeed))
		end
		Audio.play("bubblePop")
	end,
	ScrubStop = function()
		if scrub then
			scrub.stop()
			scrub = nil
		end
	end,
	MudPatchCleared = function(_cat: any, _position: any, patchesLeft: any)
		local left = if type(patchesLeft) == "number" then patchesLeft else CueRules.MAX_PATCHES
		Audio.play("mudPlop", { pitch = CueRules.mudPlopPitch(left) })
	end,
	CatClean = function(cat: any)
		Audio.play("revealChime")
		Audio.play("catShake", { at = if typeof(cat) == "Instance" then cat else nil })
	end,
	BrushSwipe = function(_cat: any, stroke: any)
		Audio.play("brushSwish", { variant = if type(stroke) == "number" then stroke else nil })
	end,
	CatFluffed = function(cat: any)
		Audio.play("purr", { at = if typeof(cat) == "Instance" then cat else nil })
	end,
	BowChosen = function()
		Audio.play("bowPop")
	end,
	PhotoTaken = function()
		Audio.play("camera")
	end,
	-- The opening's kitten is named and his collar pops on: the bell jingles at the collar.
	SudsNamed = function(cat: any)
		Audio.play("collarJingle", { at = collarPart(cat) })
	end,
	-- A player taps Suds on his bed (sudsMascot): a purr; the cue's minGap keeps fast taps from stacking.
	SudsTapped = function(suds: any)
		Audio.play("purr", { at = if typeof(suds) == "Instance" then suds else nil })
	end,
	-- DryStart and DryStop arrive with the dry step (Gameplay-Engineer's stations PR); bind skips them until then.
	DryStart = function(_cat: any, station: any)
		if dryer then
			dryer.stop()
		end
		dryer = Audio.loop("dryerHum", if typeof(station) == "Instance" then station else nil)
	end,
	DryStop = function()
		if dryer then
			dryer.stop()
			dryer = nil
		end
	end,
	-- The wash bar (switch washMeter) and the later steps. Each Moment fires only with its own switch on.
	SudsPopped = function()
		Audio.play("bubblePop")
	end,
	BathFoamy = function(cat: any)
		Audio.play("foamSwell", { at = at(cat) })
	end,
	RinseSpray = function(cat: any)
		if rinse == nil then
			rinse = Audio.loop("rinseLoop", at(cat))
		end
		local now = os.clock()
		rinseAt = now
		task.delay(RINSE_HOLD, function()
			if rinseAt == now then
				stopRinse()
			end
		end)
	end,
	ShakeOff = function(cat: any, step: any)
		stopRinse()
		Audio.play("stepChime")
		Audio.play("catShake", { at = at(cat) })
		if step == "rinse" then
			Audio.play("foamDrop", { at = at(cat) })
		end
	end,
	ClawSnipped = function()
		Audio.play("clawSnip")
	end,
	-- Coming with Gameplay's special visitors, the crate and the bow step; bind skips them until they exist.
	VisitorArrived = function(visitor: any, again: any)
		if again == true then
			return -- the line was redrawn: the same visitor, already announced
		end
		Audio.play("visitorChime", { at = at(visitor) })
	end,
	CrateDropped = function(crate: any)
		Audio.play("crateDrop", { at = at(crate) })
	end,
	BowTied = function(cat: any)
		Audio.play("bowTie", { at = at(cat) })
	end,
	-- issue 529: Moments still to come from Gameplay; each binds only once it exists
	HeartLow = function(cat: any)
		Audio.play("heartLow", { at = at(cat) })
	end,
	CatLeft = function(cat: any)
		Audio.play("catLeave", { at = at(cat) })
	end,
	CrateOpened = function()
		Audio.play("crateOpen")
	end,
	PetRevealed = function()
		Audio.play("petReveal")
	end,
	PetStarUp = function()
		Audio.play("starUp")
	end,
	WorkerFinished = function(cat: any)
		if ownCoinPop(cat) then
			return -- the owner hears HelperPopupController's coinPop for their own helpers instead (issue 801)
		end
		Audio.play("workerDone", { at = at(cat) })
	end,
	BuildFinished = function(build: any)
		Audio.play("buildDone", { at = at(build) })
	end,
	QuestDone = function()
		Audio.play("questDone")
	end,
	CheckInClaimed = function()
		Audio.play("checkIn")
	end,
}

local function bind(moments: any)
	if type(moments) ~= "table" then
		return
	end
	for name, handler in HANDLERS do
		local signal = moments[name]
		if type(signal) == "table" and type(signal.Connect) == "function" then
			signal:Connect(handler)
		end
	end
end

local function tryBind(module: Instance)
	if module.Name ~= "Moments" or not module:IsA("ModuleScript") then
		return
	end
	local ok, moments = pcall(require, module)
	if ok then
		bind(moments)
	else
		warn(`[Audio] could not load Moments: {moments}`)
	end
end

function AudioController.Init(_controllers: { [string]: any })
	Audio.start()
end

function AudioController.Start()
	local shared = ReplicatedStorage:WaitForChild("Shared")
	-- the spa songs play only while the spaMusic switch is on (issue 529), with the off switch as instant rollback
	local LiveFlags = require(shared:WaitForChild("LiveFlags")) :: any
	Audio.allowMusic(LiveFlags.isOn(MUSIC_FLAG))
	Audio.applySettings({ music = true, sound = true }) -- the start-up default; SettingsController owns it after
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. MUSIC_FLAG)
		:Connect(function()
			Audio.allowMusic(LiveFlags.isOn(MUSIC_FLAG))
		end)
	-- required here, not at the top, to stay clear of the 200 local limit and of UI load order
	local UiSounds =
		require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("UiSounds")) :: any
	local UI = require(script.Parent.Parent:WaitForChild("UI")) :: any
	UiSounds.start(UI, function(): boolean
		return LiveFlags.isOn(UI_SOUNDS_FLAG)
	end)
	local existing = shared:FindFirstChild("Moments")
	if existing then
		tryBind(existing)
	else
		local connection: RBXScriptConnection
		connection = shared.ChildAdded:Connect(function(child)
			if child.Name == "Moments" then
				connection:Disconnect()
				tryBind(child)
			end
		end)
	end
end

return AudioController
