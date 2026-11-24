--!strict
-- Stink: comic green wisps rising over every dirty cat (#122), so a muddy coat reads as dirt and not as a fur
-- pattern at phone size. They thin out as mud patches clear (MudPatchCleared) and are gone when the cat is clean.
-- Client only, behind the `stinkEffects` switch. One emitter per dirty cat, on an Attachment beside the head's
-- Carry attachment, so the wisps move with the head under CatMotion.
--
-- API
--   Stink.start(isOn)                 finds dirty cats (the `Dirty` attribute) in Workspace; isOn is read once a second
--   Stink.focus(cat)                  the cat being washed takes a wisp slot first, then the nearest cats
--   Stink.setLeft(cat, left)          mud patches still on the cat; 0 removes the wisps
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent)
local Tier = require(script.Parent:WaitForChild("Tier"))

local PRESET = "stinkWisps"
local LIFT = 0.35 -- studs above the Carry attachment, so the wisps start just over the head
local RANGE = 60 -- studs: no wisps past it
local MAX_CATS = { low = 2, high = 4 } -- steady emitters are shared with foam and dryer air (animation-vfx section 7)

type Entry = {
	cat: Model,
	attachment: Attachment,
	emitter: ParticleEmitter,
	maxRate: number,
	total: number,
	left: number,
}

local Stink = {}

local entries: { [Model]: Entry } = {}
local started = false
local focus: Model? = nil -- the cat being washed
local switchOn: () -> boolean = function()
	return false
end

local function findCarry(cat: Model): Attachment?
	for _, descendant in cat:GetDescendants() do
		if descendant:IsA("Attachment") and descendant.Name == "Carry" then
			return descendant :: Attachment
		end
	end
	return nil
end

local function remove(cat: Model)
	local entry = entries[cat]
	if entry then
		entries[cat] = nil
		entry.attachment:Destroy()
	end
end

local function attach(cat: Model)
	if entries[cat] or cat:GetAttribute("Dirty") ~= true or not cat:IsDescendantOf(Workspace) then
		return
	end
	local carry = findCarry(cat)
	local holder = if carry then carry.Parent else nil
	if not carry or not holder or not holder:IsA("BasePart") then
		return
	end
	local emitter, preset = Effects.newEmitter(PRESET)
	if not emitter or not preset then
		return
	end
	local rawTotal = cat:GetAttribute("MudCount")
	local total = if type(rawTotal) == "number" and rawTotal > 0 then rawTotal else 1
	local attachment = Instance.new("Attachment")
	attachment.Name = "CleanACat_Fx_Stink"
	attachment.CFrame = carry.CFrame * CFrame.new(0, LIFT, 0)
	emitter.Parent = attachment
	attachment.Parent = holder
	entries[cat] = {
		cat = cat,
		attachment = attachment,
		emitter = emitter,
		maxRate = preset.maxRate,
		total = total,
		left = total,
	}
end

local function consider(instance: Instance)
	if instance:IsA("Model") and instance:GetAttribute("Dirty") == true then
		attach(instance :: Model)
	elseif instance:IsA("Attachment") and instance.Name == "Carry" then
		local cat: Instance? = instance:FindFirstAncestorWhichIsA("Model")
		while cat and cat:GetAttribute("Dirty") ~= true do
			cat = cat:FindFirstAncestorWhichIsA("Model")
		end
		if cat then
			attach(cat :: Model)
		end
	end
end

-- The cat being washed takes a slot first, then the nearest cats, so a street of customers at the door never
-- leaves the tub cat without wisps on a phone's two slots.
local function refresh(on: boolean)
	local camera = Workspace.CurrentCamera
	local from = if camera then camera.CFrame.Position else nil
	local reduced = Effects.reducedMotion()
	local budget = if Effects.tier() == "low" then MAX_CATS.low else MAX_CATS.high
	local order: { { entry: Entry, distance: number } } = {}
	for cat, entry in entries do
		if cat.Parent == nil or entry.attachment.Parent == nil then
			remove(cat)
			continue
		end
		local distance = if from
			then (entry.attachment.WorldPosition - from).Magnitude
			else math.huge
		table.insert(order, {
			entry = entry,
			distance = if cat == focus and distance <= RANGE then -1 else distance,
		})
	end
	table.sort(
		order,
		function(
			a: { entry: Entry, distance: number },
			b: { entry: Entry, distance: number }
		): boolean
			return a.distance < b.distance
		end
	)
	for _, item in order do
		local entry = item.entry
		local rate = if on
				and item.distance <= RANGE
				and budget > 0
			then Tier.stinkRate(entry.maxRate, entry.left, entry.total, reduced)
			else 0
		if rate > 0 then
			budget -= 1
		end
		entry.emitter.Rate = rate
		entry.emitter.Enabled = rate > 0
	end
end

function Stink.start(isOn: () -> boolean)
	if started then
		return
	end
	started = true
	switchOn = isOn
	for _, instance in Workspace:GetDescendants() do
		consider(instance)
	end
	Workspace.DescendantAdded:Connect(consider)
	local checkAt = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= checkAt then
			checkAt = now + 1
			refresh(switchOn())
		end
	end)
end

-- The cat being washed (ScrubStart): it takes a wisp slot before any other cat, at once.
function Stink.focus(cat: Model)
	if focus ~= cat then
		focus = cat
		if started then
			refresh(switchOn())
		end
	end
end

function Stink.setLeft(cat: Model, left: number)
	if entries[cat] == nil and left > 0 then
		attach(cat)
	end
	local entry = entries[cat]
	if entry == nil then
		return
	end
	if left <= 0 then
		remove(cat)
		return
	end
	entry.left = left
	local rate = Tier.stinkRate(entry.maxRate, left, entry.total, Effects.reducedMotion())
	if entry.emitter.Enabled then
		entry.emitter.Rate = rate
	end
end

return Stink
