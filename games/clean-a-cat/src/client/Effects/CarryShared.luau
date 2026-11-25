--!strict
-- CarryShared: other players' carried cats, so a carrier never walks around with empty arms (Review-QA, 2026-11-25).
-- Carry draws a carry on the carrier's own client only (its arm Transforms never replicate), so this draws everyone
-- else's on each client in the same way: the server says what a character carries with two attributes on it, and
-- each client clones that model from ReplicatedStorage.Assets and runs Carry.hold on that character.
--
-- The attributes are Gameplay's (set on the character when the server moves a cat into the arms, cleared when it is
-- placed, dropped, on a new character or when the switch goes off):
--   CarryCat   the Assets model name to clone (a customer's dirty sit model, or the opening's held loaf)
--   CarryHeld  "sit" or "loaf"
-- The local player is skipped: their own carry is CarryController's (and the opening's).
--
-- Client only, behind the `carryShared` switch (the caller passes it in). Quiet: no purr from other players' cats.
-- At most MAX carriers are drawn, the nearest to the camera within RANGE, so a full server stays inside the phone
-- budget; a carrier who drops out of that set lets go and is drawn again when back in it.
--
-- API
--   CarryShared.start(isOn)                       watches every other character; isOn is read on each check
--   CarryShared.pick(distances, max, range) -> { number }   which carriers to draw (indices into `distances`,
--                                                 nearest first); pure, for the specs
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Carry = require(script.Parent:WaitForChild("Carry"))
local Effects = require(script.Parent)

local CarryShared = {}

-- Gameplay's names, read from the character only (the Player's own CarryCat attribute is the door or arms state)
local function names(): (string, string)
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("CarryRules")
	if module and module:IsA("ModuleScript") then
		local ok, rules = pcall(require, module)
		if ok and type(rules) == "table" then
			local r = rules :: any
			if type(r.CHARACTER_CAT) == "string" and type(r.CHARACTER_HELD) == "string" then
				return r.CHARACTER_CAT, r.CHARACTER_HELD
			end
		end
	end
	return "CarryCat", "CarryHeld"
end
CarryShared.CAT_ATTRIBUTE, CarryShared.HELD_ATTRIBUTE = names()
CarryShared.MAX = table.freeze({ low = 3, high = 8 })
CarryShared.RANGE = 120 -- studs from the camera
CarryShared.CHECK_SECONDS = 0.25 -- how often the attributes are read: a pickup shows within a quarter second
local COPY_NAME = "CleanACat_OtherCarriedCat"

type Entry = {
	name: string,
	held: Carry.Held,
	model: Model,
	handle: Carry.Handle,
}

type Want = { character: Model, name: string, held: Carry.Held }

local entries: { [Model]: Entry } = {}
local started = false

function CarryShared.pick(distances: { number }, max: number, range: number): { number }
	local order: { number } = {}
	for i, d in distances do
		if d <= range then
			table.insert(order, i)
		end
	end
	table.sort(order, function(a: number, b: number): boolean
		if distances[a] == distances[b] then
			return a < b
		end
		return distances[a] < distances[b]
	end)
	while #order > max do
		table.remove(order)
	end
	return order
end

-- A copy of the asset `name` that never collides, catches a ray or touches anything; nil when Assets lacks it.
local function copyOf(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local asset = if assets then assets:FindFirstChild(name) else nil
	if not (asset and asset:IsA("Model")) then
		return nil
	end
	local model = asset:Clone() :: Model
	model.Name = COPY_NAME
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local part = item :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		elseif item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		end
	end
	return model
end

local function drop(character: Model)
	local entry = entries[character]
	if entry == nil then
		return
	end
	entries[character] = nil
	entry.handle.destroy()
	entry.model:Destroy()
end

local function show(character: Model, name: string, held: Carry.Held)
	local entry = entries[character]
	if entry and entry.name == name and entry.held == held then
		return
	end
	drop(character)
	local model = copyOf(name)
	if model == nil then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		model:PivotTo((root :: BasePart).CFrame) -- the lift starts at the carrier, so it is short
	end
	model.Parent = Workspace
	entries[character] = {
		name = name,
		held = held,
		model = model,
		handle = Carry.hold(character, model, held, false, true),
	}
end

-- What `character` carries, from its attributes; nil when nothing (or something malformed).
local function carried(character: Model): (string?, Carry.Held)
	local name = character:GetAttribute(CarryShared.CAT_ATTRIBUTE)
	if type(name) ~= "string" or name == "" or #name > 100 then
		return nil, "sit"
	end
	local held: Carry.Held = "sit"
	if character:GetAttribute(CarryShared.HELD_ATTRIBUTE) == "loaf" then
		held = "loaf"
	end
	return name, held
end

local function check(on: boolean)
	local wanted: { Want } = {}
	local distances: { number } = {}
	if on then
		local camera = Workspace.CurrentCamera
		local from = if camera then camera.CFrame.Position else nil
		for _, player in Players:GetPlayers() do
			if player == Players.LocalPlayer then
				continue
			end
			local character = player.Character
			if character == nil or character.Parent == nil then
				continue
			end
			local name, held = carried(character)
			if name == nil then
				continue
			end
			local root = character:FindFirstChild("HumanoidRootPart")
			local distance = if from
					and root
					and root:IsA("BasePart")
				then ((root :: BasePart).Position - from).Magnitude
				else math.huge
			local want: Want =
				{ character = character, name = name, held = (held :: any) :: Carry.Held }
			table.insert(wanted, want)
			table.insert(distances, distance)
		end
	end
	local max = if Effects.tier() == "low" then CarryShared.MAX.low else CarryShared.MAX.high
	local keep: { [Model]: boolean } = {}
	for _, i in CarryShared.pick(distances, max, CarryShared.RANGE) do
		local w = wanted[i]
		keep[w.character] = true
		show(w.character, w.name, w.held)
	end
	for character in entries do
		if not keep[character] then
			drop(character)
		end
	end
end

function CarryShared.start(isOn: () -> boolean)
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			local ok, on = pcall(isOn)
			local failure = ""
			local fine = xpcall(check, function(err: unknown)
				failure = tostring(err)
			end, ok and on == true)
			if not fine then
				warn(`CarryShared: {failure}`)
			end
			task.wait(CarryShared.CHECK_SECONDS)
		end
	end)
end

return CarryShared
