--!strict
-- ControlHold: one place that pauses and frees the player's walking controls (Roblox's PlayerModule), so two parts of
-- the game that each pause them cannot free them for the other. Each caller holds under its own reason; walking comes
-- back only when no reason still holds. Before this, a scrub stroke ending (ScrubController) freed walking in the
-- middle of the close-up wash view (OpeningController), so the player could walk away from the tub.
local Players = game:GetService("Players")

local ControlHold = {}

local held: { [string]: boolean } = {}
local controls: any = nil
local disabled = false

local function findControls(): any
	if controls ~= nil then
		return controls
	end
	local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local module = if scripts then scripts:FindFirstChild("PlayerModule") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, found = pcall(function(): any
		return (require(module :: ModuleScript) :: any):GetControls()
	end)
	if ok and found ~= nil then
		controls = found
	end
	return controls
end

local function apply()
	local want = next(held) ~= nil
	if want == disabled then
		return
	end
	local walk = findControls()
	if walk == nil then
		return
	end
	disabled = want
	if want then
		walk:Disable()
	else
		walk:Enable()
	end
end

-- Pauses (true) or frees (false) walking for `reason`.
function ControlHold.set(reason: string, hold: boolean)
	if hold then
		held[reason] = true
	else
		held[reason] = nil
	end
	apply()
end

-- Is walking held for `reason`?
function ControlHold.holds(reason: string): boolean
	return held[reason] == true
end

-- Drops every reason and frees walking (a new character after a reset).
function ControlHold.clear()
	table.clear(held)
	-- Roblox keeps the controls' enabled state across a respawn, so free them even if this module thinks they are.
	local walk = findControls()
	if walk ~= nil then
		walk:Enable()
	end
	disabled = false
end

return ControlHold
