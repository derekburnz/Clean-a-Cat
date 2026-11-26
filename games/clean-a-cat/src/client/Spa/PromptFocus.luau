--!strict
-- PromptFocus: one prompt that must win (switch promptFocus, issue 540). Roblox shows one prompt per button and picks
-- the one that best faces the camera, not the nearest, so at the tub the Tools board's "Buy Bubble Soap" could take the
-- single pill from "Wash him" or "Put in tub" (Review-QA's bug hunt pass A). While a claimed prompt is in the world,
-- every other prompt in Workspace is put out of reach on this device (MaxActivationDistance 0) and given its reach
-- back when the last claimed one goes, or the switch goes off. Enabled is left to the owners entirely, so a tool bought
-- or a build started meanwhile shows as its owner set it (Review-QA on #550); owners set the reach only when they make
-- a prompt, and one whose reach is no longer 0 at the restore was set again by its owner and is left as it is.
-- Client only, nothing replicates.
--
-- The bookkeeping is PromptFocus.Ledger, pure so tests/specs/PromptFocus.spec.luau covers it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local PromptFocus = {}

PromptFocus.FLAG = "promptFocus"

-- Each held prompt's own reach, keyed by anything (a ProximityPrompt in the game).
export type Ledger<K> = { reach: { [K]: number } }

PromptFocus.Ledger = {}

function PromptFocus.Ledger.new<K>(): Ledger<K>
	return { reach = {} }
end

-- Starts holding `key`, whose reach is `reach` now. False (nothing to do) when it is held already or has no reach.
function PromptFocus.Ledger.mute<K>(ledger: Ledger<K>, key: K, reach: number): boolean
	if ledger.reach[key] ~= nil or reach <= 0 then
		return false
	end
	ledger.reach[key] = reach
	return true
end

-- The reach to put back on a held prompt whose reach is `now`: its own, unless its owner set a new one meanwhile.
function PromptFocus.Ledger.restoreTo(saved: number, now: number): number
	return if now == 0 then saved else now
end

-- Every held prompt with its own reach, and the ledger cleared.
function PromptFocus.Ledger.release<K>(ledger: Ledger<K>): { [K]: number }
	local out = ledger.reach
	ledger.reach = {}
	return out
end

local claimed: { [ProximityPrompt]: boolean } = {}
local ledger = PromptFocus.Ledger.new() :: Ledger<ProximityPrompt>
local added: RBXScriptConnection? = nil
local flagWatch: RBXScriptConnection? = nil

local function mute(prompt: ProximityPrompt)
	if
		claimed[prompt] or not PromptFocus.Ledger.mute(ledger, prompt, prompt.MaxActivationDistance)
	then
		return
	end
	prompt.MaxActivationDistance = 0
end

local function restore()
	local connection = added
	added = nil
	if connection then
		connection:Disconnect()
	end
	for prompt, reach in PromptFocus.Ledger.release(ledger) do
		if prompt.Parent then
			prompt.MaxActivationDistance =
				PromptFocus.Ledger.restoreTo(reach, prompt.MaxActivationDistance)
		end
	end
end

-- `prompt` stays the only prompt in reach on this device until it leaves the world or is released. Does nothing while
-- the switch is off.
function PromptFocus.claim(prompt: ProximityPrompt)
	if not LiveFlags.isOn(PromptFocus.FLAG) or claimed[prompt] then
		return
	end
	claimed[prompt] = true
	if flagWatch == nil then
		-- the switch going off is an instant rollback: every claim ends and every prompt comes back as its owner wants
		flagWatch = ReplicatedStorage
			:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. PromptFocus.FLAG)
			:Connect(function()
				if not LiveFlags.isOn(PromptFocus.FLAG) and next(claimed) ~= nil then
					table.clear(claimed)
					restore()
				end
			end)
	end
	for _, other in Workspace:GetDescendants() do
		if other:IsA("ProximityPrompt") then
			mute(other :: ProximityPrompt)
		end
	end
	if added == nil then
		added = Workspace.DescendantAdded:Connect(function(other: Instance)
			if other:IsA("ProximityPrompt") then
				task.defer(function()
					-- once its owner has set it up, and only while something is still claimed
					if next(claimed) ~= nil and other.Parent then
						mute(other :: ProximityPrompt)
					end
				end)
			end
		end)
	end
	prompt.AncestryChanged:Connect(function()
		if not prompt:IsDescendantOf(Workspace) then
			PromptFocus.release(prompt)
		end
	end)
end

function PromptFocus.release(prompt: ProximityPrompt)
	if not claimed[prompt] then
		return
	end
	claimed[prompt] = nil
	if next(claimed) == nil then
		restore()
	end
end

return PromptFocus
