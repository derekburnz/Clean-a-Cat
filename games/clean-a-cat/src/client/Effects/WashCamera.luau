--!strict
-- WashCamera: the close-up wash view (Derek 2026-11-24: "after you place him in the tub it should switch to the
-- minigame view ... thats how we introduce the cleaning mechanics"). The camera eases from the player's view into a
-- framed shot of the tub over SECONDS, holds there while the wash is taught, then eases back to the player's view
-- and hands the camera back. Reduced Motion (or Less screen shake) cuts instead of easing.
--
-- Client only. When to go in and out is Gameplay's (after the kitten is in the tub, and on "Open the spa!"); this
-- module only moves the camera. ScrubController holds the camera still while a finger is on the cat; it saves and
-- restores the camera type, so that keeps working inside this shot.
--
-- API
--   WashCamera.shot(tub) -> CFrame        the framed shot for a tub spot (in front of it, above, looking down at it)
--   WashCamera.enter(shot, onDone?) -> Handle
--       eases into `shot` (a camera CFrame, usually WashCamera.shot(SpaLayout.tubSpot())); onDone when it is there
--   handle.exit(onDone?)   eases back to where the player's camera was and gives it back; onDone when it is back
--   handle.destroy()       gives the camera back at once
--   Each onDone fires exactly once, deferred, also when exit is called twice or the handle is destroyed first.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent)

local WashCamera = {}

WashCamera.SECONDS = 0.6 -- each ease, in and out (Derek's ask, about 0.6 s)
-- The shot, in the tub spot's space: in front of the tub (its LookVector), above it, looking at a point a little
-- above its seat so the whole cat and the tub's rim are in frame on a phone.
WashCamera.SHOT = table.freeze({ ahead = 6.5, up = 5, lookUp = 1.2 })

local BIND_NAME = "CleanACat_WashCamera"

export type Handle = {
	exit: (onDone: (() -> ())?) -> (),
	destroy: () -> (),
}

-- Ease in and out (a sine curve), so the move starts and ends softly. 0 to 1.
function WashCamera.ease(u: number): number
	local k = math.clamp(u, 0, 1)
	return (1 - math.cos(math.pi * k)) / 2
end

-- How far along an ease is `elapsed` seconds in: a cut (1 at once) under Reduced Motion.
function WashCamera.progress(elapsed: number, reduced: boolean): number
	if reduced then
		return 1
	end
	return WashCamera.ease(elapsed / WashCamera.SECONDS)
end

function WashCamera.shot(tub: CFrame): CFrame
	local s = WashCamera.SHOT
	local look = tub.Position + Vector3.yAxis * s.lookUp
	local from = tub.Position + tub.LookVector * s.ahead + Vector3.yAxis * s.up
	return CFrame.lookAt(from, look)
end

local count = 0

function WashCamera.enter(shot: CFrame, onDone: (() -> ())?): Handle
	local camera = Workspace.CurrentCamera
	local reduced = Effects.reducedMotion()
	local done = false
	local pending: (() -> ())? = onDone
	local function answer()
		local fn = pending
		pending = nil
		if fn then
			task.defer(fn)
		end
	end

	if camera == nil then
		answer()
		return {
			exit = function(exitDone: (() -> ())?)
				if exitDone then
					task.defer(exitDone)
				end
			end,
			destroy = function() end,
		}
	end
	local cam = camera :: Camera
	count += 1
	local name = `{BIND_NAME}_{count}`
	local savedType = cam.CameraType
	local home = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable

	-- the current move: from, to, when it started, and what to do at its end
	local move = { from = home, to = shot, start = os.clock(), leaving = false }
	local bound = true

	local function unbind()
		if bound then
			bound = false
			RunService:UnbindFromRenderStep(name)
		end
	end

	local function giveBack()
		unbind()
		if cam.CameraType == Enum.CameraType.Scriptable then
			cam.CameraType = savedType
		end
	end

	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local k = WashCamera.progress(os.clock() - move.start, reduced)
		cam.CFrame = move.from:Lerp(move.to, k)
		if k >= 1 then
			if move.leaving then
				giveBack()
				done = true
			end
			answer()
		end
	end)

	return {
		exit = function(exitDone: (() -> ())?)
			if done or move.leaving then
				if exitDone then
					task.defer(exitDone)
				end
				return
			end
			answer() -- still easing in: the enter's onDone hears back now
			pending = exitDone
			move = { from = cam.CFrame, to = home, start = os.clock(), leaving = true }
		end,
		destroy = function()
			if done then
				return
			end
			done = true
			giveBack()
			answer()
		end,
	}
end

return WashCamera
