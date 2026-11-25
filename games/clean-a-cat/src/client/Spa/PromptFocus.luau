--!strict
-- PromptFocus: one prompt that must win (switch promptFocus, issue 540). Roblox shows one prompt per button and picks
-- the one that best faces the camera, not the nearest, so at the tub the Tools board's "Buy Bubble Soap" could take the
-- single pill from "Wash him" or "Put in tub" (Review-QA's bug hunt pass A). While a claimed prompt is in the world,
-- every other enabled prompt in Workspace is switched off on this device, and switched back on when the last claimed
-- one goes. A prompt whose owner turns it on meanwhile is switched off again until then. Client only, nothing replicates.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))

local PromptFocus = {}

PromptFocus.FLAG = "promptFocus"

local claimed: { [ProximityPrompt]: boolean } = {}
local muted: { [ProximityPrompt]: RBXScriptConnection } = {}
local added: RBXScriptConnection? = nil

local function mute(prompt: ProximityPrompt)
	if claimed[prompt] or muted[prompt] or not prompt.Enabled then
		return
	end
	prompt.Enabled = false
	muted[prompt] = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if prompt.Enabled and next(claimed) ~= nil then
			prompt.Enabled = false
		end
	end)
end

local function restore()
	local connection = added
	added = nil
	if connection then
		connection:Disconnect()
	end
	for prompt, watch in muted do
		watch:Disconnect()
		if prompt.Parent then
			prompt.Enabled = true
		end
	end
	table.clear(muted)
end

-- `prompt` stays the only enabled prompt on this device until it leaves the world or is released. Does nothing while
-- the switch is off.
function PromptFocus.claim(prompt: ProximityPrompt)
	if not LiveFlags.isOn(PromptFocus.FLAG) or claimed[prompt] then
		return
	end
	claimed[prompt] = true
	prompt.Enabled = true
	for _, other in Workspace:GetDescendants() do
		if other:IsA("ProximityPrompt") then
			mute(other :: ProximityPrompt)
		end
	end
	if added == nil then
		added = Workspace.DescendantAdded:Connect(function(other: Instance)
			if other:IsA("ProximityPrompt") then
				task.defer(mute, other :: ProximityPrompt) -- once its owner has set it up
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
