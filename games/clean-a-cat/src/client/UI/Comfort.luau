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
--
-- Text size needs no helper: Roblox draws fixed-size text bigger itself when the player picks Large, Larger or
-- Largest. A screen only has to leave room for it: AutomaticSize or TextWrapped on labels, no TextScaled on body text,
-- and no MaxTextSize below the words' normal size. The UI gate's phonecomfort run checks that at Largest.
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Comfort = {}

-- pure: the transparency to show for a design value, given the player's preference (kept in 0..1)
function Comfort.backdropValue(base: number, preferred: number?): number
	local p = math.clamp(if preferred == nil then 1 else preferred, 0, 1)
	return math.clamp(base, 0, 1) * p
end

local function preferredTransparency(): number?
	local ok, value = pcall(function()
		return GuiService.PreferredTransparency
	end)
	return if ok and type(value) == "number" then value else nil
end

local backdrops: { [GuiObject]: number } = setmetatable({}, { __mode = "k" }) :: any
local watching = false

local function reapply()
	local preferred = preferredTransparency()
	for object, base in backdrops do
		object.BackgroundTransparency = Comfort.backdropValue(base, preferred)
	end
end

function Comfort.backdrop(object: GuiObject, base: number)
	backdrops[object] = base
	object.BackgroundTransparency = Comfort.backdropValue(base, preferredTransparency())
	if not watching then
		watching = true
		GuiService:GetPropertyChangedSignal("PreferredTransparency"):Connect(reapply)
	end
end

function Comfort.reducedMotion(): boolean
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and value == true
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
