--!strict
-- WorkerService: the spa's helpers Jo and Sam (WorkerRules, issue 509), and Lou, who comes with his game pass
-- (PassService.changed, issue 518) and then works exactly like them. One
-- purchase hires a worker with their own station on the back wall of the player's plot. Every few seconds an idle
-- worker takes a waiting customer's cat from the line by the mode the player set, sits it in their tub, and washes it
-- for WorkerRules.washSeconds (longer the dirtier). The cat carries the attribute WorkerProgress, 0 to 1, which
-- Motion-FX's WorkerBar draws over it; at 1 the clean cat shows for a moment, goes home, and the worker pays their
-- share into the player's coins. Everything is drawn by the server in the owner's plot, so the whole street sees it.
-- Before a worker is hired their spot holds the build pad with their name and price; the client puts the prompts on
-- it (WorkerController). The server checks the switch, the save, the coins and the distance; the client only asks.
-- Behind the LiveFlags switch `workers` (and `scrubPrototype` and `customers`), off by default.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DirtRules = require(Shared:WaitForChild("DirtRules"))
local Guard = require(Shared:WaitForChild("Guard"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local IndexService = require(script.Parent:WaitForChild("IndexService"))
local LikeAskService = require(script.Parent:WaitForChild("LikeAskService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local PassService = require(script.Parent:WaitForChild("PassService"))
local PetService = require(script.Parent:WaitForChild("PetService"))
local SpaService = require(script.Parent:WaitForChild("SpaService"))
local StaffNameService = require(script.Parent:WaitForChild("StaffNameService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local WalletService = require(script.Parent:WaitForChild("WalletService"))

local FLAG = WorkerRules.FLAG
local NEEDS = { "scrubPrototype", "customers" } -- the line workers take from
local STATION_ASSET = "CleanACat_Station_Tub"
local CAT_SCALE = 1.5 -- as the player's tub (ScrubController)
local STAFF_OFFSET = CFrame.new(-2.6, 0, 0.4) * CFrame.Angles(0, math.rad(-70), 0) -- beside the tub, facing it
local LABEL_COLOR = Color3.fromRGB(90, 70, 110)
local TICK_SECONDS = 1
local REST_SECONDS = 3 -- between one cat and the next, so a worker does not snatch the line's new customer at once

local WorkerService = {}

type Job = {
	kind: string,
	dirt: number,
	level: number,
	started: number, -- os.clock()
	seconds: number,
	cat: Model?,
	done: boolean,
}

local jobs: { [Player]: { [string]: Job } } = {}
local restUntil: { [Player]: { [string]: number } } = {}
local warned: { [string]: boolean } = {}

local function isOn(): boolean
	if not LiveFlags.isOn(FLAG) then
		return false
	end
	for _, flag in NEEDS do
		if not LiveFlags.isOn(flag) then
			return false
		end
	end
	return true
end

local function asset(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local found = if assets then assets:FindFirstChild(name) else nil
	if found and found:IsA("Model") then
		return found :: Model
	end
	if not warned[name] then
		warned[name] = true
		warn(`[WorkerService] {name} is missing from ReplicatedStorage.Assets`)
	end
	return nil
end

local function anchorAll(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local p = part :: BasePart
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
		elseif part:IsA("Script") or part:IsA("LocalScript") then
			part:Destroy()
		end
	end
end

local function folderOf(player: Player, make: boolean): Folder?
	local slot = SpaLayout.slotOf(player)
	local plot = if slot then SpaLayout.plotModel(slot) else nil
	if plot == nil then
		return nil
	end
	local found = plot:FindFirstChild(WorkerRules.FOLDER)
	if found and found:IsA("Folder") then
		return found :: Folder
	end
	if not make then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = WorkerRules.FOLDER
	folder.Parent = plot
	return folder
end

-- A name and a second line on the pad's Screen part's front, as StationService labels its pads.
local function label(pad: Model, title: string, line: string)
	local screen = pad:FindFirstChild("Screen", true)
	if screen == nil or not screen:IsA("BasePart") then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = LABEL_COLOR
	text.Text = `{title}\n{line}`
	text.Parent = gui
	gui.Parent = screen
end

local function clearCat(job: Job)
	local cat = job.cat
	job.cat = nil
	if cat then
		local id = cat:GetAttribute(WorkerRules.WORKER_ATTRIBUTE)
		local staff = if cat.Parent and type(id) == "string"
			then cat.Parent:FindFirstChild(`CleanACat_NPC_Staff_{id}`)
			else nil
		if staff then
			staff:SetAttribute(WorkerRules.WASHING_ATTRIBUTE, false)
		end
		cat:Destroy()
	end
end

-- The cat model in the worker's tub: the dirty one (trimmed to its level) while washing, the clean one when done.
local function seatCat(player: Player, id: string, job: Job, clean: boolean)
	clearCat(job)
	local folder = folderOf(player, false)
	local station = if folder then folder:FindFirstChild(id) else nil
	if station == nil or not station:IsA("Model") then
		return
	end
	local name = if clean
		then `CleanACat_Cat_{job.kind}_Sit`
		else `CleanACat_Cat_{job.kind}_Dirty_Sit`
	local template = asset(name)
	if template == nil then
		return
	end
	local cat = template:Clone() :: Model
	cat.Name = `WorkerCat_{id}`
	if not clean then
		for _, piece in cat:GetDescendants() do
			if
				piece:IsA("Model")
				and not DirtRules.keeps(piece:GetAttribute(DirtRules.ATTRIBUTE), job.dirt)
			then
				piece:Destroy()
			end
		end
	end
	anchorAll(cat)
	local scale = station:GetAttribute("CatScale")
	cat:ScaleTo(if type(scale) == "number" and scale > 0 then scale else CAT_SCALE)
	local seat = station:FindFirstChild("CatSeat", true)
	local at = if seat and seat:IsA("Attachment")
		then (seat :: Attachment).WorldCFrame
		else (station :: Model):GetPivot() * CFrame.new(0, 1.5, 0)
	cat:PivotTo(at)
	-- set before it is parented: WorkerBar looks for the Cat attribute when the model is added (Review-QA)
	cat:SetAttribute("Cat", job.kind)
	cat:SetAttribute(DirtRules.ATTRIBUTE, job.dirt)
	cat:SetAttribute(WorkerRules.WORKER_ATTRIBUTE, id)
	cat:SetAttribute(WorkerRules.PROGRESS_ATTRIBUTE, if clean then 1 else 0)
	cat.Parent = station
	job.cat = cat
	-- the worker reaches and scrubs while this is true (Motion-FX's staff motion, PR 563)
	local staff = station:FindFirstChild(`CleanACat_NPC_Staff_{id}`)
	if staff then
		staff:SetAttribute(WorkerRules.WASHING_ATTRIBUTE, not clean)
	end
end

-- Where the worker stands at their station: the wash stand's WorkerSpot on the floor, upright and facing the cat's
-- seat; beside the plain tub when the stand has no WorkerSpot.
local function staffSpot(station: Model, spot: CFrame): CFrame
	local at = station:FindFirstChild("WorkerSpot", true)
	local seat = station:FindFirstChild("CatSeat", true)
	if at and at:IsA("Attachment") then
		local from = (at :: Attachment).WorldPosition
		local to = if seat and seat:IsA("Attachment")
			then (seat :: Attachment).WorldPosition
			else spot.Position
		local flat = Vector3.new(to.X, from.Y, to.Z)
		if (flat - from).Magnitude < 0.01 then
			return CFrame.new(from) * spot.Rotation
		end
		return CFrame.lookAt(from, flat)
	end
	return spot * STAFF_OFFSET
end

-- Draws the player's worker stations and pads. A job in progress keeps going; its cat is seated again.
function WorkerService.refresh(player: Player)
	local old = folderOf(player, false)
	if old then
		old:Destroy()
	end
	local save = DataService.get(player)
	local slot = SpaLayout.slotOf(player)
	if not isOn() or save == nil or slot == nil then
		return
	end
	local folder = folderOf(player, true)
	if folder == nil then
		return
	end
	for _, id in WorkerRules.IDS do
		local info = WorkerRules.WORKERS[id]
		local hired = save.workers[id] ~= nil
		if not hired and info.pass then
			continue -- Lou comes with his pass, never as a pad
		end
		local spot = SpaLayout.slotSpot(info.spot, slot)
		-- a hired worker's own wash stand (Model-Agent's), or the plain tub until it is in the game
		local template = if hired
			then (asset(info.stand) or asset(STATION_ASSET))
			else asset(SpaLayout.PAD_ASSET)
		if template == nil then
			continue
		end
		local station = template:Clone() :: Model
		station.Name = id
		station:SetAttribute(WorkerRules.WORKER_ATTRIBUTE, id)
		station:SetAttribute("Hired", hired)
		station:PivotTo(spot)
		anchorAll(station)
		if hired then
			local staff = asset(`CleanACat_NPC_Staff_{id}`)
			if staff then
				local copy = staff:Clone() :: Model
				anchorAll(copy)
				copy:PivotTo(staffSpot(station, spot))
				copy:SetAttribute(WorkerRules.WASHING_ATTRIBUTE, false)
				copy.Parent = station
			end
		else
			label(station, `Hire {info.name}`, `{WorkerRules.priceOf(id, LiveFlags.isOn)} coins`)
		end
		station.Parent = folder
	end
	local running: { [string]: Job } = jobs[player] or {}
	for id, job in running do
		seatCat(player, id, job, job.done)
	end
end

local function stands(player: Player, id: string): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local spot = SpaLayout.spot(WorkerRules.WORKERS[id].spot, player)
	return ((root :: BasePart).Position - spot.Position).Magnitude <= WorkerRules.SERVER_REACH
end

-- The worker id and the save for a request, or nil. Hiring needs the player at the pad; the mode and the level come
-- from the Helpers window on the HUD as well (tuning worker.windowFromHud), so they skip the distance check.
local function forRequest(player: Player, rawId: unknown, atStation: boolean): (string?, any)
	if not isOn() then
		return nil, nil
	end
	local id = Guard.oneOf(rawId, WorkerRules.IDS)
	local save = DataService.get(player)
	if id == nil or save == nil or (atStation and not stands(player, id)) then
		return nil, nil
	end
	return id, save
end

-- The player's workers on Player attributes, for the station prompts and the Helpers window (WorkerRules.shown).
local function showWorkers(player: Player, save: any)
	for _, attribute in WorkerRules.shown(save) do
		player:SetAttribute(attribute.name, attribute.value)
	end
end

local function onHire(player: Player, rawId: unknown)
	local id, save = forRequest(player, rawId, true)
	if id == nil then
		return
	end
	local ok, reason = WorkerRules.canHire(save, id, LiveFlags.isOn)
	if not ok then
		NetService.notice(player, reason or "Can't hire yet", "warning")
		return
	end
	local spent = WorkerRules.hire(save, id, os.time(), LiveFlags.isOn)
	if spent <= 0 then
		return
	end
	WalletService.show(player)
	showWorkers(player, save) -- the stand's prompts and the Helpers button need the new worker at once (issue 696)
	WorkerService.refresh(player)
	PetService.show(player) -- the worker brings a pet slot
	NetService.notice(player, `{StaffNameService.nameOf(player, id)} works here now`)
	Telemetry.economy(player, "coins", "sink", spent, save.coins, "Shop", `Worker{id}`)
	Telemetry.event(
		player,
		"worker_hired",
		Telemetry.sessionSeconds(player) // 60,
		{ string.lower(id) }
	)
	LikeAskService.moment(player, "helper")
end

local function onMode(player: Player, rawId: unknown, rawMode: unknown)
	local id, save = forRequest(player, rawId, false)
	local mode = WorkerRules.cleanMode(rawMode)
	local worker: any = if id then save.workers[id] else nil
	if id == nil or mode == nil or worker == nil then
		return
	end
	worker.mode = mode
	player:SetAttribute(`WorkerMode_{id}`, mode)
end

local function onLevel(player: Player, rawId: unknown)
	local id, save = forRequest(player, rawId, false)
	if id == nil or save.workers[id] == nil then
		return
	end
	local spent, reason = WorkerRules.levelUp(save, id)
	if spent <= 0 then
		NetService.notice(player, reason or "Can't level up yet", "warning")
		return
	end
	WalletService.show(player)
	player:SetAttribute(`WorkerLevel_{id}`, save.workers[id].level)
	NetService.notice(
		player,
		`{StaffNameService.nameOf(player, id)} is level {save.workers[id].level}`
	)
	Telemetry.economy(player, "coins", "sink", spent, save.coins, "Shop", `WorkerLevel{id}`)
end

local function finish(player: Player, id: string, job: Job)
	local own = jobs[player]
	if own == nil or own[id] ~= job then
		return
	end
	own[id] = nil
	clearCat(job)
	local save = DataService.get(player)
	if save == nil or player.Parent ~= Players then
		return
	end
	-- the worker's pets add to their pay, all together at most +30% (switch pets, tuning worker.petCap)
	local boost = PetService.workerBoost(player, id)
	local coins = math.floor(WorkerRules.pay(job.kind, job.dirt, job.level) * (1 + boost) + 0.5)
	save.coins += coins
	WalletService.show(player)
	IndexService.stamp(player, job.kind, "washed")
	if LiveFlags.isOn(WorkerRules.POPUP_FLAG) then
		-- the owner's client shows the pay over this helper's stand (issue 743): no toast for every cat
		NetService.fire(player, "HelperPaid", id, coins)
	else
		NetService.notice(
			player,
			`+{coins} coins: {StaffNameService.nameOf(player, id)} washed {job.kind}`
		)
	end
	Telemetry.economy(player, "coins", "source", coins, save.coins, "Gameplay", `Worker{id}`)
	restUntil[player] = restUntil[player] or {}
	restUntil[player][id] = os.clock() + REST_SECONDS
end

local function tickPlayer(player: Player)
	local save = DataService.get(player)
	if save == nil or player.Parent ~= Players or SpaLayout.slotOf(player) == nil then
		return
	end
	local own = jobs[player]
	if own == nil then
		own = {}
		jobs[player] = own
	end
	local mine = own :: { [string]: Job }
	local rests = restUntil[player] or {}
	local now = os.clock()
	for _, id in WorkerRules.IDS do
		local worker = save.workers[id]
		if worker == nil then
			continue
		end
		local job = mine[id]
		if job then
			if job.done then
				continue
			end
			local fraction = math.clamp((now - job.started) / job.seconds, 0, 1)
			if fraction >= 1 then
				job.done = true
				seatCat(player, id, job, true)
				task.delay(WorkerRules.SHOW_DONE_SECONDS, finish, player, id, job)
			elseif job.cat then
				job.cat:SetAttribute(WorkerRules.PROGRESS_ATTRIBUTE, math.floor(fraction * 50) / 50)
			end
		elseif now >= (rests[id] or 0) then
			local line = SpaService.lineForWorkers(player)
			local place = WorkerRules.pick(worker.mode, line)
			local entry = if place then line[place] else nil
			if place and entry then
				local kind, dirt = SpaService.takeForWorker(player, place, entry.kind)
				if kind and dirt then
					local level = WorkerRules.cleanLevel(worker.level)
					local fresh: Job = {
						kind = kind,
						dirt = dirt,
						level = level,
						started = now,
						seconds = WorkerRules.washSeconds(dirt, level),
						cat = nil,
						done = false,
					}
					mine[id] = fresh
					seatCat(player, id, fresh, false)
				end
			end
			-- one take a tick per spa, so two idle workers never empty the line at once
			if mine[id] then
				break
			end
		end
	end
end

local function dropPlayer(player: Player)
	local running: { [string]: Job } = jobs[player] or {}
	for _, job in running do
		clearCat(job)
	end
	jobs[player] = nil
	restUntil[player] = nil
end

local function refreshAll()
	for _, player in Players:GetPlayers() do
		if not isOn() then
			dropPlayer(player)
		end
		WorkerService.refresh(player)
	end
end

-- Lou comes with his pass (issue 518): bought, found on join or the passes switch turned on, he is hired with his
-- station the same moment, once, and then works exactly like Jo and Sam. He stays in the save as any hire.
local function onPass(player: Player, key: string)
	local save = DataService.get(player)
	local info = WorkerRules.WORKERS[key]
	if save == nil or info == nil or not info.pass then
		return
	end
	if not WorkerRules.hirePass(save, key, os.time()) then
		return
	end
	showWorkers(player, save)
	WorkerService.refresh(player)
	PetService.show(player)
	if isOn() then
		NetService.notice(player, `{info.name} works here now, with his own wash stand`)
	end
	Telemetry.event(
		player,
		"worker_hired",
		Telemetry.sessionSeconds(player) // 60,
		{ string.lower(key) }
	)
end

function WorkerService.Init(_services: { [string]: any }) end

function WorkerService.Start()
	NetService.on("RequestHireWorker", { perSecond = 1, burst = 2 }, onHire)
	NetService.on("RequestWorkerMode", { perSecond = 2, burst = 4 }, onMode)
	NetService.on("RequestWorkerLevel", { perSecond = 1, burst = 2 }, onLevel)
	PassService.changed:Connect(onPass)
	DataService.onLoaded:Connect(function(player: Player, save)
		showWorkers(player, save)
		WorkerService.refresh(player)
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		player:GetAttributeChangedSignal(SpaLayout.SLOT_ATTRIBUTE):Connect(function()
			WorkerService.refresh(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		local save = DataService.get(player)
		if save then
			showWorkers(player, save)
		end
		player:GetAttributeChangedSignal(SpaLayout.SLOT_ATTRIBUTE):Connect(function()
			WorkerService.refresh(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		local folder = folderOf(player, false)
		if folder then
			folder:Destroy()
		end
		dropPlayer(player)
	end)
	ReplicatedStorage:GetAttributeChangedSignal(SpaLayout.PLACED_ATTRIBUTE):Connect(refreshAll)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG)
		:Connect(refreshAll)
	for _, flag in NEEDS do
		ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. flag)
			:Connect(refreshAll)
	end
	-- Jo's pad label shows his price (switch joPrice, issue 841)
	ReplicatedStorage
		:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. WorkerRules.PRICE_FLAG)
		:Connect(refreshAll)
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			if isOn() then
				for _, player in Players:GetPlayers() do
					local ok, err = pcall(function()
						tickPlayer(player)
						return nil :: any
					end)
					if not ok then
						warn("WorkerService:", err)
					end
				end
			end
		end
	end)
	refreshAll()
end

return WorkerService
