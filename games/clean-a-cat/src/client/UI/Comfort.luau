--!strict
-- Comfort: the player's own Roblox settings that every screen honours (#181), read in one place so a screen gets them
-- by calling these helpers instead of reading GuiService itself.
--
--   Comfort.backdrop(frame, 0.2)  sets a see-through panel background that turns solid for players who ask for less
--                                 see-through UI (GuiService.PreferredTransparency, 1 = Roblox default, 0 = solid).
--                                 Only for backgrounds meant to show: an invisible layout frame (1) would turn solid.
--   Comfort.reducedMotion()       true when the player turned on Reduced Motion in Roblox, or Less screen shake or
--                                 Less sparkle on our Settings card: skip shakes, bobs and long tweens
--   Comfort.lessSparkle()         true with Roblox's Reduced Motion or our Less sparkle: fewer flashes and particles
--   Comfort.setChoices(shake, sparkle)  the Settings card's two toggles (#230); kept for this session only
--   Comfort.input()               the input the player is using now (Touch, KeyboardAndMouse or Gamepad)
--   Comfort.onInputChanged(fn)    calls fn(input) when that changes, for swapping button prompts
--   Comfort.autoHeight(label)     lets a label grow taller when larger text wraps to more lines
--   Comfort.tenFoot()             true on a TV-sized screen (GuiService.ViewportDisplaySize Large, most consoles):
--                                 keep the HUD TV_INSET in from every edge, since TVs often crop it, and draw text and
--                                 buttons bigger for a player 8 to 10 feet away (#209)
--   Comfort.onTenFootChanged(fn)  calls fn(tenFoot) when that changes (the screen, or the switch)
--
-- backdrop, autoHeight and tenFoot follow the live switch comfortSettings (off by default, LiveFlags). While it is
-- off they leave the design values as they were, and they re-apply within a minute when it is flipped either way.
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

-- Strong tables, each entry let go when its object is destroyed: a weak key on an Instance can drop out while the
-- object still exists, and the update would then skip it (Review-QA on #679).
local backdrops: { [GuiObject]: number } = {}
local growers: { [GuiObject]: boolean } = {}
local tracked: { [GuiObject]: boolean } = {}

local function forgetOnDestroy(object: GuiObject)
	if tracked[object] then
		return
	end
	tracked[object] = true
	object.Destroying:Connect(function()
		backdrops[object] = nil
		growers[object] = nil
		tracked[object] = nil
	end)
end
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
	forgetOnDestroy(object)
	object.BackgroundTransparency = Comfort.backdropValue(base, preferredTransparency())
	watch()
end

function Comfort.autoHeight(object: GuiObject)
	growers[object] = true
	forgetOnDestroy(object)
	object.AutomaticSize = if enabled() then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
	watch()
end

local lessShakeChosen = false
local lessSparkleChosen = false

local function robloxReducedMotion(): boolean
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and value == true
end

function Comfort.setChoices(lessShake: boolean, lessSparkle: boolean)
	lessShakeChosen = lessShake
	lessSparkleChosen = lessSparkle
end

function Comfort.reducedMotion(): boolean
	return robloxReducedMotion() or lessShakeChosen or lessSparkleChosen
end

function Comfort.lessSparkle(): boolean
	return robloxReducedMotion() or lessSparkleChosen
end

Comfort.TV_INSET = 0.05 -- share of the screen kept clear on every edge of a TV

function Comfort.tenFoot(): boolean
	if not enabled() then
		return false
	end
	local ok, value = pcall(function()
		return GuiService.ViewportDisplaySize
	end)
	return ok and value == Enum.DisplaySize.Large
end

function Comfort.onTenFootChanged(fn: (boolean) -> ())
	local function changed()
		fn(Comfort.tenFoot())
	end
	GuiService:GetPropertyChangedSignal("ViewportDisplaySize"):Connect(changed)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(changed)
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
