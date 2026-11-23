--!strict
-- AudioController: starts Audio and plays cues on the game's moments. It only listens: no remotes, no state.
-- Moments come from ReplicatedStorage.Shared.Moments (issue #3) once it exists; until then nothing is bound.
-- Settings: sound and music default to on until a settings screen exists, then it calls Audio.applySettings.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require(script.Parent.Parent:WaitForChild("Audio"))
local CueRules = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("CueRules"))

local AudioController = {}

local scrub: Audio.LoopHandle? = nil

-- Moment name -> handler. Payload shapes follow issue #3; anything unexpected is ignored.
local HANDLERS: { [string]: (...any) -> () } = {
	ScrubStart = function(cat: any)
		if scrub then
			scrub.stop()
		end
		scrub = Audio.loop("scrubLoop", if typeof(cat) == "Instance" then cat else nil)
	end,
	ScrubMove = function(_hitPoint: any, _normal: any, dragSpeed: any)
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
	MudPatchCleared = function(_cat: any, _position: any, cleared: any)
		Audio.play(
			"mudPlop",
			{ pitch = CueRules.mudPlopPitch(if type(cleared) == "number" then cleared else 0) }
		)
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
	Audio.applySettings({ music = true, sound = true })
	local shared = ReplicatedStorage:WaitForChild("Shared")
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
