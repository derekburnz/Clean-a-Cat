--!strict
-- PetController: every player's pets on this device (CrateRules, issues 511 and 512). The server shows the pet in each
-- slot as the Player attribute Pet_<slot> = "<kind>:<star>": the player's own pet walks beside them, a worker's sits
-- beside that worker's station in its owner's plot. Model-Agent's CleanACat_Pet_<kind> at its PetScale, with the
-- star pieces above its star taken off. Cosmetic only; nothing here changes the game. Fires Moments.PetStarUp on the
-- owner's device when a fuse lands (PetFused).
-- Behind the LiveFlags switch `pets`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(Shared:WaitForChild("Moments"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local FOLDER_NAME = "CleanACat_Pets"
local BESIDE = CFrame.new(2.4, 0, 1.2) -- from the player's feet: a little behind and to the right
local BESIDE_STATION = CFrame.new(2.4, 0, -1.6) -- from a worker's station spot, in front to the right
-- A second slot's pet (the Second pet slot pass, issue 518) stands on the other side.
local BESIDE_SECOND = CFrame.new(-2.4, 0, 1.2)
local BESIDE_STATION_SECOND = CFrame.new(-2.4, 0, -1.6)
local FOLLOW_RATE = 8 -- how fast a pet catches up, per second
local FAR = 90 -- studs: a follower past this from the camera is not moved
local HIP = 3 -- studs from a character's root down to its feet

local PetController = {}

type Shown = { model: Model, look: string, owner: Player, slot: string }

local folder: Folder? = nil
local shown: { [string]: Shown } = {} -- by "<userId>:<slot>"
local stepping: RBXScriptConnection? = nil

local function cleanLook(raw: unknown): (string?, number)
	if type(raw) ~= "string" then
		return nil, 1
	end
	local kind, star = string.match(raw, "^(%a+):(%d)$")
	if kind == nil or CrateRules.rarityOf(kind) == nil then
		return nil, 1
	end
	return kind, math.clamp(tonumber(star) or 1, 1, CrateRules.MAX_STAR)
end

local function make(kind: string, star: number): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local asset = if assets then assets:FindFirstChild(`CleanACat_Pet_{kind}`) else nil
	if not (asset and asset:IsA("Model")) then
		return nil
	end
	local pet = (asset :: Model):Clone() :: Model
	for _, piece in pet:GetDescendants() do
		local level = piece:GetAttribute("StarLevel")
		local aboveStar = piece:IsA("Model") and type(level) == "number" and level > star
		if aboveStar or piece:IsA("Script") or piece:IsA("LocalScript") then
			piece:Destroy()
		elseif piece:IsA("BasePart") then
			local part = piece :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	local scale = pet:GetAttribute("PetScale")
	pet:ScaleTo(if type(scale) == "number" and scale > 0 then scale else 0.7)
	return pet
end

-- Where the pet in `slot` of `owner` should stand now, or nil when there is nowhere.
local function target(owner: Player, slot: string): CFrame?
	if slot == CrateRules.PLAYER_SLOT or slot == CrateRules.PLAYER_SLOT .. "2" then
		local character = owner.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			local at = (root :: BasePart).CFrame
			local beside = if slot == CrateRules.PLAYER_SLOT then BESIDE else BESIDE_SECOND
			return CFrame.new(at.Position - Vector3.new(0, HIP, 0)) * at.Rotation * beside
		end
		return nil
	end
	local id, number = string.match(slot, "^(%a+)(%d)$")
	local info = if id then WorkerRules.WORKERS[id] else nil
	local plot = SpaLayout.slotOf(owner)
	if info == nil or plot == nil then
		return nil
	end
	return SpaLayout.slotSpot(info.spot, plot)
		* (if number == "2" then BESIDE_STATION_SECOND else BESIDE_STATION)
end

local function drop(key: string)
	local entry = shown[key]
	shown[key] = nil
	if entry then
		entry.model:Destroy()
	end
end

local function refresh(owner: Player)
	local prefix = `{owner.UserId}:`
	local wanted: { [string]: boolean } = {}
	if LiveFlags.isOn(CrateRules.FLAG) and folder then
		for name, value in owner:GetAttributes() do
			if
				string.sub(name, 1, #CrateRules.PET_ATTRIBUTE_PREFIX)
				~= CrateRules.PET_ATTRIBUTE_PREFIX
			then
				continue
			end
			local slot = string.sub(name, #CrateRules.PET_ATTRIBUTE_PREFIX + 1)
			local kind, star = cleanLook(value)
			if kind == nil then
				continue
			end
			local key = prefix .. slot
			wanted[key] = true
			local look = `{kind}:{star}`
			local entry = shown[key]
			if entry and entry.look == look then
				continue
			end
			drop(key)
			local model = make(kind, star)
			if model then
				-- kept even with nowhere to stand yet (no character or plot on a join): `step` puts it out once there is
				-- (issue 634: a pet already in the save never showed until its attribute changed)
				shown[key] = { model = model, look = look, owner = owner, slot = slot }
				local at = target(owner, slot)
				if at then
					model:PivotTo(at)
					model.Parent = folder
				end
			end
		end
	end
	for key in table.clone(shown) do
		if string.sub(key, 1, #prefix) == prefix and not wanted[key] then
			drop(key)
		end
	end
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local blend = 1 - math.exp(-FOLLOW_RATE * dt)
	for _, entry in shown do
		local at = target(entry.owner, entry.slot)
		if at == nil then
			continue
		end
		if entry.model.Parent ~= folder then
			entry.model:PivotTo(at) -- its first place to stand
			entry.model.Parent = folder
			continue
		end
		local now = entry.model:GetPivot()
		if (now.Position - eye).Magnitude > FAR then
			continue
		end
		entry.model:PivotTo(now:Lerp(at, blend))
	end
end

local function watch(owner: Player)
	owner.AttributeChanged:Connect(function(name: string)
		if
			string.sub(name, 1, #CrateRules.PET_ATTRIBUTE_PREFIX) == CrateRules.PET_ATTRIBUTE_PREFIX
		then
			refresh(owner)
		end
	end)
	refresh(owner)
end

local function setOn()
	local on = LiveFlags.isOn(CrateRules.FLAG)
	if on and folder == nil then
		local made = Instance.new("Folder")
		made.Name = FOLDER_NAME
		made.Parent = Workspace
		folder = made
		stepping = RunService.Heartbeat:Connect(step)
	elseif not on and folder then
		for key in table.clone(shown) do
			drop(key)
		end
		if stepping then
			stepping:Disconnect()
			stepping = nil
		end
		(folder :: Folder):Destroy()
		folder = nil
	end
	for _, owner in Players:GetPlayers() do
		refresh(owner)
	end
end

local function onFused(rawPet: unknown)
	if type(rawPet) ~= "table" then
		return
	end
	-- the redraw for the new star comes with the attribute; the moment goes on the pet as it is drawn
	task.defer(function()
		for _, entry in shown do
			if
				entry.owner == Players.LocalPlayer
				and entry.look == `{(rawPet :: any).kind}:{(rawPet :: any).star}`
			then
				Moments.PetStarUp:Fire(entry.model)
				return
			end
		end
	end)
end

function PetController.Init(_controllers: { [string]: any }) end

function PetController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CrateRules.FLAG)
		:Connect(setOn)
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(owner: Player)
		local prefix = `{owner.UserId}:`
		for key in table.clone(shown) do
			if string.sub(key, 1, #prefix) == prefix then
				drop(key)
			end
		end
	end)
	for _, owner in Players:GetPlayers() do
		watch(owner)
	end
	Remotes.event("PetFused").OnClientEvent:Connect(onFused)
	setOn()
end

return PetController
