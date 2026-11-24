--!strict
-- Motion: how a window arrives and how a button answers a press. A trial (#183) behind the live switch springUi,
-- off by default: while it is off nothing moves, exactly as before. While it is on:
--
--   Motion.popIn(window)   the window grows from 60% to full size on a spring with a small overshoot
--   Motion.press(button)   the button squashes to 92% while held and springs back on release
--
-- Springs come from spr (shared/Vendor/spr.luau, MIT), required only when the switch is on. They animate a UIScale
-- child, so layout and the UI gate's sizes are untouched. Reduced Motion (GuiService.ReducedMotionEnabled) skips
-- all of it. If the owner keeps the trial, the house numbers go into the animation-vfx skill; if he drops it, this
-- file, the switch and the vendored spr are removed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Comfort = require(script.Parent:WaitForChild("Comfort"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local Motion = {}

local FLAG = "springUi"
local POP_FROM = 0.6
local POP_DAMPING, POP_FREQUENCY = 0.55, 3.2 -- a little overshoot, settled in about half a second
local PRESS_SCALE = 0.92
local PRESS_DAMPING, PRESS_FREQUENCY = 0.5, 6
local RELEASE_DAMPING, RELEASE_FREQUENCY = 0.45, 5

type Spr = {
	target: (Instance, number, number, { [string]: any }) -> (),
	stop: (Instance, string?) -> (),
}

local sprModule: Spr? = nil
local function springs(): Spr
	local loaded = sprModule
	if loaded == nil then
		loaded = require(Shared:WaitForChild("Vendor"):WaitForChild("spr")) :: any
		sprModule = loaded
	end
	return loaded :: Spr
end

local function active(): boolean
	return LiveFlags.isOn(FLAG) and not Comfort.reducedMotion()
end

local function existingScale(gui: GuiObject): UIScale?
	local found = gui:FindFirstChild("MotionScale")
	if found ~= nil and found:IsA("UIScale") then
		return found :: UIScale
	end
	return nil
end

local function scaleOf(gui: GuiObject): UIScale
	local existing = existingScale(gui)
	if existing ~= nil then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = "MotionScale"
	scale.Parent = gui
	return scale
end

function Motion.popIn(gui: GuiObject)
	if not active() then
		local existing = existingScale(gui)
		if existing ~= nil then
			existing.Scale = 1
		end
		return
	end
	local scale = scaleOf(gui)
	local spr = springs()
	spr.stop(scale)
	scale.Scale = POP_FROM
	spr.target(scale, POP_DAMPING, POP_FREQUENCY, { Scale = 1 })
end

local PRESS_INPUTS = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.Touch] = true,
}

local function isPress(input: InputObject): boolean
	return PRESS_INPUTS[input.UserInputType] == true or input.KeyCode == Enum.KeyCode.ButtonA
end

function Motion.press(button: GuiButton)
	button.InputBegan:Connect(function(input: InputObject)
		if isPress(input) and active() then
			springs().target(
				scaleOf(button),
				PRESS_DAMPING,
				PRESS_FREQUENCY,
				{ Scale = PRESS_SCALE }
			)
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if not isPress(input) then
			return
		end
		local existing = existingScale(button)
		if existing ~= nil and sprModule ~= nil then
			springs().target(existing, RELEASE_DAMPING, RELEASE_FREQUENCY, { Scale = 1 })
		end
	end)
end

return Motion
