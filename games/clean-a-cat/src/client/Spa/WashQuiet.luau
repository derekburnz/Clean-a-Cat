--!strict
-- WashQuiet: everything in the world that draws over or through the wash room is switched off on this device while
-- the wash screen is up (switch washScreen, issue 856). Derek in Studio, 2026-11-26 10 PM ET: "during cleaning you can
-- see the heart bars of cats in the background make it a seperate screen with nothing really shown in the background".
--
-- The room's walls hide the spa itself, but a BillboardGui or SurfaceGui with AlwaysOnTop, a Highlight and a figure's
-- name tag draw over walls, and a particle or trail on a hidden part still draws. So while the screen is up:
--   * every BillboardGui, SurfaceGui and Highlight in Workspace and in the player's PlayerGui (the heart bars, name
--     tags, worker bars, counter cards, pills, build board, crate labels, glows) goes off;
--   * every ParticleEmitter, Beam and Trail inside the room goes off (a helper's suds at a nearby stand);
--   * every Humanoid's name and health tag goes off (other players, customers, helpers);
-- except the wash's own pieces (`keeps`: ScrubController's folder with the cat and its paw marker, the effects'
-- folders, the room). Each one gets back what it had, or what its owner set on it meanwhile: an Enabled set to true
-- while the screen is up is remembered and put back. A new one that appears while it is up goes off too.
-- Client only and cosmetic: nothing is sent, and nothing is destroyed.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local WashQuiet = {}

local GUI_CLASSES = { "BillboardGui", "SurfaceGui", "Highlight" }
local ROOM_CLASSES = { "ParticleEmitter", "Beam", "Trail" }

type Keep = (Instance) -> boolean
type InRoom = (Vector3) -> boolean

local wanted: { [Instance]: boolean } = {} -- each item switched off here, with the Enabled it should get back
local tags: { [Humanoid]: Enum.HumanoidDisplayDistanceType } = {} -- each name tag switched off, with its setting
local watch: { RBXScriptConnection } = {}
local active = false
local keepFn: Keep = function(_item: Instance)
	return false
end
local roomFn: InRoom = function(_point: Vector3)
	return false
end

local function isA(item: Instance, classes: { string }): boolean
	for _, name in classes do
		if item:IsA(name) then
			return true
		end
	end
	return false
end

-- Where an effect sits: its parent part or attachment.
local function placeOf(item: Instance): Vector3?
	local parent = item.Parent
	if parent and parent:IsA("BasePart") then
		return (parent :: BasePart).Position
	elseif parent and parent:IsA("Attachment") then
		return (parent :: Attachment).WorldPosition
	end
	return nil
end

-- A gui or highlight belongs to the wash when it, or what it is drawn on, is one of the wash's own pieces.
local function owned(item: Instance): boolean
	if keepFn(item) then
		return true
	end
	local adornee = (item :: any).Adornee
	return typeof(adornee) == "Instance" and keepFn(adornee :: Instance)
end

local function quietOne(item: Instance)
	if wanted[item] ~= nil then
		return
	end
	local it: any = item
	if it.Enabled ~= true then
		return -- already off: its owner put it away, so it stays theirs
	end
	wanted[item] = true
	it.Enabled = false
	-- its owner may switch it on meanwhile: it is switched off again, and gets that back at the end
	table.insert(
		watch,
		it:GetPropertyChangedSignal("Enabled"):Connect(function()
			if active and wanted[item] ~= nil and it.Enabled == true then
				wanted[item] = true
				it.Enabled = false
			end
		end)
	)
end

local function look(item: Instance)
	if isA(item, GUI_CLASSES) then
		if not owned(item) then
			quietOne(item)
		end
	elseif isA(item, ROOM_CLASSES) then
		local at = placeOf(item)
		if at and roomFn(at) and not keepFn(item) then
			quietOne(item)
		end
	elseif item:IsA("Humanoid") then
		local humanoid = item :: Humanoid
		if
			tags[humanoid] == nil
			and humanoid.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None
		then
			tags[humanoid] = humanoid.DisplayDistanceType
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
end

-- Switches everything off but what `keep` says belongs to the wash; `inRoom` says which effects stand in the room.
function WashQuiet.start(keep: Keep, inRoom: InRoom)
	WashQuiet.stop()
	active = true
	keepFn = keep
	roomFn = inRoom
	for _, item in Workspace:GetDescendants() do
		look(item)
	end
	local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if gui then
		for _, item in gui:GetDescendants() do
			if isA(item, GUI_CLASSES) then
				look(item)
			end
		end
		table.insert(
			watch,
			gui.DescendantAdded:Connect(function(item: Instance)
				if active and isA(item, GUI_CLASSES) then
					-- a gui is filled in after it is parented: look once it has its Adornee
					task.defer(function()
						if active and item.Parent then
							look(item)
						end
					end)
				end
			end)
		)
	end
	table.insert(
		watch,
		Workspace.DescendantAdded:Connect(function(item: Instance)
			if active then
				task.defer(function()
					if active and item.Parent then
						look(item)
					end
				end)
			end
		end)
	)
end

-- The room moved with a later step's station: effects in the new room go off too.
function WashQuiet.refresh(inRoom: InRoom)
	if not active then
		return
	end
	roomFn = inRoom
	for _, item in Workspace:GetDescendants() do
		if isA(item, ROOM_CLASSES) then
			look(item)
		end
	end
end

-- Puts everything back as its owner wants it.
function WashQuiet.stop()
	active = false
	for _, connection in watch do
		connection:Disconnect()
	end
	table.clear(watch)
	for item, enabled in wanted do
		if item.Parent then
			local it: any = item
			it.Enabled = enabled
		end
	end
	table.clear(wanted)
	for humanoid, kind in tags do
		if humanoid.Parent then
			humanoid.DisplayDistanceType = kind
		end
	end
	table.clear(tags)
end

-- How many things are switched off now (for the Studio check).
function WashQuiet.count(): number
	local n = 0
	for _ in wanted do
		n += 1
	end
	for _ in tags do
		n += 1
	end
	return n
end

return WashQuiet
