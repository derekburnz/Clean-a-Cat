--!strict
-- StaffNameService: names players give their spa staff (StaffNameRules, issue 487), behind the switch staffRename.
-- RequestRenameStaff(id, text) renames a worker the player has hired; the cleaned name is saved raw (save.workers[id]
-- .name; "" goes back to the default) and filtered by Roblox before anyone sees it. The broadcast filtered name, the
-- strictest one, goes on the owner's Player attribute StaffName_<id>, which every client reads for that spa's tags and
-- prompts, so no unfiltered name is ever shown or replicated. Saved names are filtered again on every join.
--
--   StaffNameService.nameOf(player, id)   the name to show for the player's worker: the filtered one or the default
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Guard = require(Shared:WaitForChild("Guard"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))
local StaffNameRules = require(Shared:WaitForChild("StaffNameRules"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))

local StaffNameService = {}

local function on(): boolean
	return LiveFlags.isOn(StaffNameRules.FLAG)
end

local function attributeOf(id: string): string
	return StaffNameRules.NAME_PREFIX .. id
end

function StaffNameService.nameOf(player: Player, id: string): string
	local default = WorkerRules.WORKERS[id].name
	local shown = if on() then player:GetAttribute(attributeOf(id)) else nil
	return if type(shown) == "string" and shown ~= "" then shown else default
end

-- Roblox's filter of `name` typed by `player`, for everyone to see; nil when the filter could not be asked. Yields.
local function filter(player: Player, name: string): string?
	local ok, result = pcall(function()
		local filtered =
			TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	return if ok and type(result) == "string" then result else nil
end

-- Filters worker `id`'s saved name and puts what may be shown on the player (nil for the default). Yields.
local function show(player: Player, id: string)
	local save = DataService.get(player)
	local worker = if save then save.workers[id] else nil
	local name = if worker and type(worker.name) == "string" then worker.name :: string else ""
	local value: string? = nil
	if on() and name ~= "" then
		local default = WorkerRules.WORKERS[id].name
		local shown = StaffNameRules.shown(name, filter(player, name), default)
		value = if shown ~= default then shown else nil
		-- the filter yields: a newer rename may have come in meanwhile, and its own show sets the name (Review-QA on #641)
		local now = DataService.get(player)
		local current = if now then now.workers[id] else nil
		if current == nil or current.name ~= name then
			return
		end
	end
	if player.Parent == Players and player:GetAttribute(attributeOf(id)) ~= value then
		player:SetAttribute(attributeOf(id), value)
	end
end

local function showAll(player: Player)
	for _, id in WorkerRules.IDS do
		task.spawn(show, player, id)
	end
end

local function onRename(player: Player, rawId: unknown, rawText: unknown)
	if not on() then
		return
	end
	local id = Guard.oneOf(rawId, WorkerRules.IDS)
	local name = StaffNameRules.clean(rawText)
	local save = DataService.get(player)
	local worker = if id and save then save.workers[id] else nil
	if id == nil or name == nil or worker == nil then
		return
	end
	worker.name = if name == "" then nil else name
	show(player, id)
	local shown = StaffNameService.nameOf(player, id)
	if name ~= "" and shown == WorkerRules.WORKERS[id].name then
		NetService.notice(player, "That name can't be used. Try another one", "warning")
	end
end

function StaffNameService.Init(_services: { [string]: any }) end

function StaffNameService.Start()
	NetService.on("RequestRenameStaff", { perSecond = 1, burst = 3 }, onRename)
	DataService.onLoaded:Connect(function(player: Player, _save: SaveSchema.Save)
		showAll(player)
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. StaffNameRules.FLAG)
		:Connect(function()
			for _, player in Players:GetPlayers() do
				showAll(player)
			end
		end)
end

return StaffNameService
