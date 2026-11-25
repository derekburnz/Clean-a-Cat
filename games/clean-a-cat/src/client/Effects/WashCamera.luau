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
--   handle.moveTo(shot)    eases from where the camera is now to another shot (a later step's station), the same
--                          ease as the way in; the exit still goes back to the player's own camera. Nothing while
--                          leaving: the exit always wins
--   WashCamera.retarget(move, from, shot, now) -> Move?   the move moveTo starts, or nil while leaving; pure, for
--                          the specs
--   handle.destroy()       gives the camera back at once
--   WashCamera.sceneShot(tub) -> CFrame   the wash scene's tighter shot (switch `washScene`); shot() uses it when on
--   WashCamera.sceneDistance() -> number  how far the scene's camera sits from where it looks; pure, for the specs
--   WashCamera.sceneFill(height, distance) -> number  the share of the screen's height a `height` stud cat fills at
--                          `distance` with the scene's field of view; pure, for the specs
--
-- The wash scene (Derek's dev test 2026-11-24: "it stays zoomed out at your normal character view it should be a
-- seperate view like my pet salon"), behind `washScene`: the camera comes in close and a little high, the field of
-- view narrows from the player's to SCENE.fov so the cat fills about SCENE.fill of the screen's height, and a soft
-- depth of field blurs the room behind the tub (not on the low tier, where the blur costs too much). Both ease with
-- the camera and go back on the exit. Station steps reach it through moveTo with shot(), so they match. The switch
-- counts only once LiveFlags lists it as off by default: until then a missing key would read as on.
--   Each onDone fires exactly once, deferred, also when exit is called twice or the handle is destroyed first.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent)

local WashCamera = {}

WashCamera.SECONDS = 0.6 -- each ease, in and out (Derek's ask, about 0.6 s)
-- The shot, in the tub spot's space: in front of the tub (its LookVector), above it, looking at a point a little
-- above its seat so the whole cat and the tub's rim are in frame on a phone.
WashCamera.SHOT = table.freeze({ ahead = 6.5, up = 5, lookUp = 1.2 })

-- The wash scene. `height` is a cat in the tub: the 2 stud tall models at the tub's CAT_SCALE 1.5 (ScrubController),
-- ears included. The camera looks at `lookUp` over the tub spot (a little under the cat's middle, so the tub's rim
-- shows), from `pitch` degrees above level, at the distance that makes the cat `fill` of the screen's height with
-- `fov` (vertical degrees; the player's camera is 70). The narrower view keeps him big without the camera inside the
-- tub's rim, and flattens the room behind him.
WashCamera.SCENE = table.freeze({
	height = 3,
	fill = 0.55,
	fov = 50,
	pitch = 30,
	lookUp = 2.6,
	blur = 0.5, -- the depth of field's far intensity, everything past the tub
	focusRadius = 3, -- studs around the cat kept sharp
})
WashCamera.FLAG = "washScene"

local BIND_NAME = "CleanACat_WashCamera"
local BLUR_NAME = "CleanACat_WashSceneBlur"

local function sceneOn(): boolean
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("LiveFlags")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(function(): boolean
			local flags = require(module) :: any
			-- a key LiveFlags doesn't list as off by default reads as on, so it must be listed first
			return flags.OFF_BY_DEFAULT[WashCamera.FLAG] == true
				and flags.isOn(WashCamera.FLAG) == true
		end)
		return ok and result == true
	end
	return false
end

function WashCamera.sceneFill(height: number, distance: number): number
	return height / (2 * distance * math.tan(math.rad(WashCamera.SCENE.fov) / 2))
end

function WashCamera.sceneDistance(): number
	local s = WashCamera.SCENE
	return s.height / (s.fill * 2 * math.tan(math.rad(s.fov) / 2))
end

function WashCamera.sceneShot(tub: CFrame): CFrame
	local s = WashCamera.SCENE
	local d = WashCamera.sceneDistance()
	local look = tub.Position + Vector3.yAxis * s.lookUp
	local pitch = math.rad(s.pitch)
	local from = look
		+ tub.LookVector * (d * math.cos(pitch))
		+ Vector3.yAxis * (d * math.sin(pitch))
	return CFrame.lookAt(from, look)
end

export type Handle = {
	exit: (onDone: (() -> ())?) -> (),
	destroy: () -> (),
	moveTo: (shot: CFrame) -> (),
}

-- One ease: from, to, when it started, and whether it hands the camera back at its end.
export type Move = { from: CFrame, to: CFrame, start: number, leaving: boolean }

-- The move to `shot` from where the camera is (`from`) at `now`, or nil while `move` is leaving: the exit wins.
function WashCamera.retarget(move: Move, from: CFrame, shot: CFrame, now: number): Move?
	if move.leaving then
		return nil
	end
	return { from = from, to = shot, start = now, leaving = false }
end

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
	if sceneOn() then
		return WashCamera.sceneShot(tub)
	end
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
			moveTo = function(_shot: CFrame) end,
		}
	end
	local cam = camera :: Camera
	count += 1
	local name = `{BIND_NAME}_{count}`
	local savedType = cam.CameraType
	local home = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable

	-- the current move: from, to, when it started, and what to do at its end
	local move: Move = { from = home, to = shot, start = os.clock(), leaving = false }
	local bound = true

	-- the wash scene's field of view and blur, eased with each move (nothing when the switch is off)
	local scene = sceneOn()
	local homeFov = cam.FieldOfView
	local fovFrom, fovTo = homeFov, if scene then WashCamera.SCENE.fov else homeFov
	local blur: DepthOfFieldEffect? = nil
	local blurFrom, blurTo = 0, 0
	if scene and Effects.tier() ~= "low" then
		local made = Instance.new("DepthOfFieldEffect")
		made.Name = BLUR_NAME
		made.FarIntensity = 0
		made.NearIntensity = 0
		made.FocusDistance = WashCamera.sceneDistance()
		made.InFocusRadius = WashCamera.SCENE.focusRadius
		made.Parent = Lighting
		blur = made
		blurTo = WashCamera.SCENE.blur
	end
	local function aim(toFov: number, toBlur: number)
		fovFrom, fovTo = cam.FieldOfView, toFov
		local b = blur
		blurFrom, blurTo = if b then b.FarIntensity else 0, toBlur
	end

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
		if scene then
			cam.FieldOfView = homeFov
		end
		local b = blur
		blur = nil
		if b then
			b:Destroy()
		end
	end

	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local k = WashCamera.progress(os.clock() - move.start, reduced)
		cam.CFrame = move.from:Lerp(move.to, k)
		if scene then
			cam.FieldOfView = fovFrom + (fovTo - fovFrom) * k
			local b = blur
			if b then
				b.FarIntensity = blurFrom + (blurTo - blurFrom) * k
			end
		end
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
			aim(homeFov, 0)
		end,
		destroy = function()
			if done then
				return
			end
			done = true
			giveBack()
			answer()
		end,
		moveTo = function(newShot: CFrame)
			if done then
				return
			end
			local onward = WashCamera.retarget(move, cam.CFrame, newShot, os.clock())
			if onward then
				move = onward
				aim(fovTo, blurTo)
			end
		end,
	}
end

return WashCamera
