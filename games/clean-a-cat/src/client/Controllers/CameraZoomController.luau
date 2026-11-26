--!strict
-- CameraZoomController: caps how far the player can zoom the camera out (Derek's playtest, 2026-11-26: "lock zooming
-- out to not be too far so people can't zoom out and see map ends", issue 895). Behind the switch zoomCap, off by
-- default.
--
-- Roblox's own camera reads Player.CameraMaxZoomDistance: the furthest the scroll wheel, a pinch or the zoom keys can
-- take the camera from the character. While the switch is on this sets it to MAX_ZOOM (on join, on every respawn and
-- whenever the switch moves); a camera already further out comes in to the cap on its next step. Switching it off
-- puts back the value the player had before. A scripted shot (the opening, the wash view) sets its own camera and is
-- not touched. The spas are about to move further apart: MAX_ZOOM is the one number to tune.
--
--   CameraZoomController.cap(on, before) -> number   pure: the max zoom distance to set
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local CameraZoomController = {}

CameraZoomController.FLAG = "zoomCap"
-- Studs from the character. At 40 the whole spa fits on a phone screen with room around it, and the street's far
-- end and the map edge stay out of view. Keep it at or above MIN_ZOOM.
CameraZoomController.MAX_ZOOM = 40
CameraZoomController.MIN_ZOOM = 12 -- never cap tighter than this, so a bad tune can't glue the camera to the head

function CameraZoomController.cap(on: boolean, before: number): number
	if not on then
		return before
	end
	return math.min(before, math.max(CameraZoomController.MAX_ZOOM, CameraZoomController.MIN_ZOOM))
end

function CameraZoomController.Init(_controllers: { [string]: any }) end

function CameraZoomController.Start()
	local player = Players.LocalPlayer
	local before = player.CameraMaxZoomDistance
	local function apply()
		player.CameraMaxZoomDistance =
			CameraZoomController.cap(LiveFlags.isOn(CameraZoomController.FLAG), before)
	end
	apply()
	player.CharacterAdded:Connect(apply)
	ReplicatedStorage
		:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CameraZoomController.FLAG)
		:Connect(apply)
end

return CameraZoomController
