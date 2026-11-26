--!strict
-- HelpersController: the Helpers window (UI/HelpersWindow, issue 526 item 3), behind the switch helpersWindow with
-- workers. It draws one row per helper from the server's Player attributes WorkerLevel_<id>, WorkerMode_<id> and,
-- with staffRename on, StaffName_<id> (HelperViewRules.rows), and asks the server: Takes sends
-- RequestWorkerMode(id, the next mode), Level up RequestWorkerLevel(id). The server checks the helper is hired, the
-- level and the coins, and says why when it refuses; the row changes only when its attributes come back. Hiring
-- stays at the helper's pad. Rename opens the Rename card through StaffNameController.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HelperViewRules = require(Shared:WaitForChild("HelperViewRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Passes = require(Shared:WaitForChild("Passes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local StaffNameRules = require(Shared:WaitForChild("StaffNameRules"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local UI = require(script.Parent.Parent:WaitForChild("UI"))

local HelpersController = {}

local player = Players.LocalPlayer

local function on(): boolean
	return LiveFlags.isOn(HelperViewRules.FLAG) and LiveFlags.isOn(WorkerRules.FLAG)
end

local function attribute(name: string): unknown
	return player:GetAttribute(name)
end

local function hired(id: string): boolean
	return table.find(WorkerRules.IDS, id) ~= nil
		and attribute(HelperViewRules.LEVEL_PREFIX .. id) ~= nil
end

local function refresh()
	local renaming = LiveFlags.isOn(StaffNameRules.FLAG)
	local names: { [string]: string } = {}
	if renaming then
		for _, id in WorkerRules.IDS do
			local raw = attribute(StaffNameRules.NAME_PREFIX .. id)
			if type(raw) == "string" and raw ~= "" then
				names[id] = raw
			end
		end
	end
	-- Lou's row points to the Shop only while his card shows there: the shop is on and his real price is known
	local price = ReplicatedStorage:GetAttribute(Passes.PRICE_PREFIX .. "Lou")
	local shop = LiveFlags.isOn(Passes.FLAG) and type(price) == "number" and price > 0
	UI.setHelpers(HelperViewRules.rows(attribute, names, LiveFlags.isOn), renaming, shop)
end

function HelpersController.Init(_controllers: { [string]: any }) end

function HelpersController.Start()
	UI.onHelperMode(function(id: string)
		if on() and hired(id) then
			local mode =
				WorkerRules.nextMode(attribute(HelperViewRules.MODE_PREFIX .. id) :: string?)
			Remotes.event("RequestWorkerMode"):FireServer(id, mode)
		end
	end)
	UI.onHelperLevel(function(id: string)
		if on() and hired(id) then
			Remotes.event("RequestWorkerLevel"):FireServer(id)
		end
	end)
	for _, id in WorkerRules.IDS do
		for _, prefix in
			{
				HelperViewRules.LEVEL_PREFIX,
				HelperViewRules.MODE_PREFIX,
				StaffNameRules.NAME_PREFIX,
			}
		do
			player:GetAttributeChangedSignal(prefix .. id):Connect(refresh)
		end
	end
	for _, flag in { HelperViewRules.FLAG, WorkerRules.FLAG, StaffNameRules.FLAG, Passes.FLAG } do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(refresh)
	end
	ReplicatedStorage:GetAttributeChangedSignal(Passes.PRICE_PREFIX .. "Lou"):Connect(refresh)
	refresh()
end

return HelpersController
