--!strict
-- StaffNameController: players name their hired helpers (issue 487, switch staffRename). It feeds the pets window the
-- helpers' shown names from the server's StaffName_<id> Player attributes (the filtered name; missing means the
-- default, WorkerRules.WORKERS[id].name) and whether a hired helper's row offers Rename. Rename opens the Rename card
-- (UI/RenameCard) with the name shown now and the default; Save sends RequestRenameStaff(id, text), "" for the
-- default. The typed name is never shown here: the row changes only when the server sends the filtered name back,
-- and a refused name comes back as the server's notice. When the card goes, the window it came from (Pets or
-- Helpers, issue 526 item 3) opens again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local StaffNameRules = require(Shared:WaitForChild("StaffNameRules"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local PETS_WINDOW = "Pets"
local HELPERS_WINDOW = "Helpers"
local RENAME_WINDOW = "Rename"

local StaffNameController = {}

local player = Players.LocalPlayer
local backTo: string? = nil -- the window the card was opened from, opened again as the card goes

local function on(): boolean
	return LiveFlags.isOn(StaffNameRules.FLAG)
end

local function defaultName(id: string): string
	local info = WorkerRules.WORKERS[id]
	return if info then info.name else id
end

local function shownName(id: string): string?
	local raw = player:GetAttribute(StaffNameRules.NAME_PREFIX .. id)
	return if type(raw) == "string" and raw ~= "" then raw else nil
end

local function hired(id: string): boolean
	return player:GetAttribute(`WorkerLevel_{id}`) ~= nil
end

local function refresh()
	local names: { [string]: string } = {}
	if on() then
		for _, id in WorkerRules.IDS do
			local name = shownName(id)
			if name then
				names[id] = name
			end
		end
	end
	UI.setStaffNames(names, on())
end

function StaffNameController.Init(_controllers: { [string]: any }) end

function StaffNameController.Start()
	local function pick(id: string, from: string)
		if not on() or not table.find(WorkerRules.IDS, id) or not hired(id) then
			return
		end
		local default = defaultName(id)
		backTo = from
		UI.showRename(id, shownName(id) or default, default)
	end
	UI.onRenamePick(function(id: string)
		pick(id, PETS_WINDOW)
	end)
	UI.onHelperRename(function(id: string)
		pick(id, HELPERS_WINDOW)
	end)
	UI.onRenameSave(function(id: string, text: string)
		if on() and table.find(WorkerRules.IDS, id) and hired(id) then
			Remotes.event("RequestRenameStaff"):FireServer(id, text)
		end
	end)
	UI.onWindowsChanged(function(open: boolean)
		local window = backTo
		if open or window == nil then
			return
		end
		backTo = nil
		if on() and not UI.isOpen(RENAME_WINDOW) then
			UI.open(window)
		end
	end)
	for _, id in WorkerRules.IDS do
		player:GetAttributeChangedSignal(StaffNameRules.NAME_PREFIX .. id):Connect(refresh)
		player:GetAttributeChangedSignal(`WorkerLevel_{id}`):Connect(refresh)
	end
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. StaffNameRules.FLAG)
		:Connect(refresh)
	refresh()
end

return StaffNameController
