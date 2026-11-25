--!strict
-- PromptFocus: one prompt that must win (switch promptFocus, issue 540). Roblox shows one prompt per button and picks
-- the one that best faces the camera, not the nearest, so at the tub the Tools board's "Buy Bubble Soap" could take the
-- single pill from "Wash him" or "Put in tub" (Review-QA's bug hunt pass A). While a claimed prompt is in the world,
-- every other prompt in Workspace is switched off on this device. When the last claimed one goes, or the switch goes
-- off, each comes back as its owner last wanted it: a prompt its owner switched off meanwhile (a tool bought, a build
-- started) stays off, and one its owner switched on comes on (Review-QA on #550). Client only, nothing replicates.
--
-- The bookkeeping is PromptFocus.Ledger, pure so tests/specs/PromptFocus.spec.luau covers it: it holds what each
-- owner wants, and tells our own writes apart from the owner's.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local PromptFocus = {}

PromptFocus.FLAG = "promptFocus"

-- What the owners of the muted prompts want, keyed by anything (a ProximityPrompt in the game).
export type Ledger<K> = {
	wanted: { [K]: boolean }, -- the owner's own last Enabled for each muted prompt
	writing: { [K]: boolean }, -- set while we write Enabled ourselves, so that change is not taken as the owner's
}

PromptFocus.Ledger = {}

function PromptFocus.Ledger.new<K>(): Ledger<K>
	return { wanted = {}, writing = {} }
end

-- Starts holding `key` off; `enabled` is what its owner has it at now. False if it was held already.
function PromptFocus.Ledger.mute<K>(ledger: Ledger<K>, key: K, enabled: boolean): boolean
	if ledger.wanted[key] ~= nil then
		return false
	end
	ledger.wanted[key] = enabled
	return true
end

-- Enabled changed on a held prompt to `enabled`. True when it was the owner (not one of our writes), whose wish is
-- kept for the restore; the prompt is then held off again.
function PromptFocus.Ledger.changed<K>(ledger: Ledger<K>, key: K, enabled: boolean): boolean
	if ledger.writing[key] or ledger.wanted[key] == nil then
		return false
	end
	ledger.wanted[key] = enabled
	return true
end

-- Every held prompt with what its owner wants, and the ledger cleared.
function PromptFocus.Ledger.release<K>(ledger: Ledger<K>): { [K]: boolean }
	local out = ledger.wanted
	ledger.wanted = {}
	ledger.writing = {}
	return out
end

local claimed: { [ProximityPrompt]: boolean } = {}
local ledger = PromptFocus.Ledger.new() :: Ledger<ProximityPrompt>
local watches: { [ProximityPrompt]: RBXScriptConnection } = {}
local added: RBXScriptConnection? = nil
local flagWatch: RBXScriptConnection? = nil

-- Sets Enabled on `prompt` without the change counting as its owner's.
local function write(prompt: ProximityPrompt, enabled: boolean)
	if prompt.Enabled == enabled then
		return
	end
	ledger.writing[prompt] = true
	prompt.Enabled = enabled
	ledger.writing[prompt] = nil
end

local function mute(prompt: ProximityPrompt)
	if claimed[prompt] or not PromptFocus.Ledger.mute(ledger, prompt, prompt.Enabled) then
		return
	end
	write(prompt, false)
	watches[prompt] = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if PromptFocus.Ledger.changed(ledger, prompt, prompt.Enabled) and next(claimed) ~= nil then
			write(prompt, false)
		end
	end)
end

local function restore()
	local connection = added
	added = nil
	if connection then
		connection:Disconnect()
	end
	for _, watch in watches do
		watch:Disconnect()
	end
	table.clear(watches)
	for prompt, wanted in PromptFocus.Ledger.release(ledger) do
		if prompt.Parent then
			prompt.Enabled = wanted
		end
	end
end

-- `prompt` stays the only enabled prompt on this device until it leaves the world or is released. Does nothing while
-- the switch is off.
function PromptFocus.claim(prompt: ProximityPrompt)
	if not LiveFlags.isOn(PromptFocus.FLAG) or claimed[prompt] then
		return
	end
	claimed[prompt] = true
	prompt.Enabled = true
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
