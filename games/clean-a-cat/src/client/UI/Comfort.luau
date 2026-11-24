--!strict
-- Comfort: the player's own Roblox settings that every screen honours (#181), read in one place so a screen gets them
-- by calling these helpers instead of reading GuiService itself.
--
--   Comfort.backdrop(frame, 0.2)  sets a see-through panel background that turns solid for players who ask for less
--                                 see-through UI (GuiService.PreferredTransparency, 1 = Roblox default, 0 = solid).
--                                 Only for backgrounds meant to show: an invisible layout frame (1) would turn solid.
--   Comfort.reducedMotion()       true when the player turned on Reduced Motion: skip shakes, bobs and long tweens
--   Comfort.input()               the input the player is using now (Touch, KeyboardAndMouse or Gamepad)
--   Comfort.onInputChanged(fn)    calls fn(input) when that changes, for swapping button prompts
--   Comfort.autoHeight(label)     lets a label grow taller when larger text wraps to more lines
--   Comfort.tenFoot()             true on a TV-sized screen (GuiService.ViewportDisplaySize Large, most consoles):
--                                 keep the HUD TV_INSET in from every edge, since TVs often crop it, and draw text and
--                                 buttons bigger for a player 8 to 10 feet away (#209). Not behind a switch: it is a fix
--   Comfort.onTenFootChanged(fn)  calls fn(tenFoot) when that changes
--
-- backdrop and autoHeight follow the live switch comfortSettings (off by default, LiveFlags). While it is off they
-- leave the design values as they were, and they re-apply within a minute when it is flipped either way.
--
-- Text size needs no helper: Roblox draws fixed-size text bigger itself when the player picks Large, Larger or
-- Largest. A screen only has to leave room for it: AutomaticSize or TextWrapped on labels, no TextScaled on body text,
-- and no MaxTextSize below the words' normal size. The UI gate's phonecomfort run checks that at Largest.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local FLAG = "comfortSettings"

local Comfort = {}

-- pure: the transparency to show for a design value, given the player's preference (kept in 0..1)
function Comfort.backdropValue(base: number, preferred: number?): number
	local p = math.clamp(if preferred == nil then 1 else preferred, 0, 1)
	return math.clamp(base, 0, 1) * p
end

local function enabled(): boolean
	return LiveFlags.isOn(FLAG)
end

local function preferredTransparency(): number?
	if not enabled() then
		return nil
	end
	local ok, value = pcall(function()
		return GuiService.PreferredTransparency
	end)
	return if ok and type(value) == "number" then value else nil
end

local backdrops: { [GuiObject]: number } = setmetatable({}, { __mode = "k" }) :: any
local growers: { [GuiObject]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local watching = false

local function reapply()
	local preferred = preferredTransparency()
	for object, base in backdrops do
		object.BackgroundTransparency = Comfort.backdropValue(base, preferred)
	end
	local grow = if enabled() then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
	for object in growers do
		object.AutomaticSize = grow
	end
end

local function watch()
	if watching then
		return
	end
	watching = true
	GuiService:GetPropertyChangedSignal("PreferredTransparency"):Connect(reapply)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(reapply)
end

function Comfort.backdrop(object: GuiObject, base: number)
	backdrops[object] = base
	object.BackgroundTransparency = Comfort.backdropValue(base, preferredTransparency())
	watch()
end

function Comfort.autoHeight(object: GuiObject)
	growers[object] = true
	object.AutomaticSize = if enabled() then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
	watch()
end

function Comfort.reducedMotion(): boolean
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and value == true
end

Comfort.TV_INSET = 0.05 -- share of the screen kept clear on every edge of a TV

function Comfort.tenFoot(): boolean
	local ok, value = pcall(function()
		return GuiService.ViewportDisplaySize
	end)
	return ok and value == Enum.DisplaySize.Large
end

function Comfort.onTenFootChanged(fn: (boolean) -> ()): RBXScriptConnection
	return GuiService:GetPropertyChangedSignal("ViewportDisplaySize"):Connect(function()
		fn(Comfort.tenFoot())
	end)
end

function Comfort.input(): Enum.PreferredInput
	return UserInputService.PreferredInput
end

function Comfort.onInputChanged(fn: (Enum.PreferredInput) -> ()): RBXScriptConnection
	return UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		fn(UserInputService.PreferredInput)
	end)
end

return Comfort
