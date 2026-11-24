--!strict
-- MascotService: Suds, the spa's mascot, in the player's own plot once he is washed and named (claim #285, switch
-- sudsMascot, off by default). He curls up on his bed by the door (Model-Agent's CleanACat_Prop_SudsBed on the plot
-- spot SpotMascot), placed by the server so friends visiting the spa see him too. Tapping him is only a look: the
-- client fires Moments.SudsTapped for the purr and the hop (MascotController); nothing on the server changes.
-- He never washes, earns nothing and is not in the Cat Index (Derek).
--
-- Redrawn when the save loads, when his wash ends (SpaService calls refresh once the next cat comes, so he never
-- shows twice while the tub still holds him), when the street is placed again and when the switch changes. Cleared
-- when the owner leaves, so the next player in that slot starts without him.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SudsRules = require(Shared:WaitForChild("SudsRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local FOLDER = "Mascot" -- inside the plot model
local BED_ASSET = "CleanACat_Prop_SudsBed"
local SEAT = "CatSeat" -- the bed's Attachment where he lies
local TAP_REACH = 24 -- studs; a tap from further away does nothing

local MascotService = {}

local warned: { [string]: boolean } = {}
-- SpaService's answer to "is Suds still in this player's tub?" (MascotService.whileInTub); he is never drawn twice.
local inTub: (Player) -> boolean = function(_player: Player): boolean
	return false
end

-- SpaService tells us how to ask whether the tub still holds Suds, so a switch flip or a street placed again between
-- his naming and the next cat never draws him on his bed while he still sits in the tub (Review-QA on #295).
function MascotService.whileInTub(fn: (Player) -> boolean)
	inTub = fn
end

local function asset(assets: Instance, name: string): Model?
	local found = assets:FindFirstChild(name)
	if found and found:IsA("Model") then
		return found :: Model
	end
	if not warned[name] then
		warned[name] = true
		warn(`[MascotService] {name} is missing from ReplicatedStorage.Assets`)
	end
	return nil
end

-- Anchored, and out of the way of walking, rays and touches; a mascot is only to look at and tap.
local function settle(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
		end
	end
end

local function clear(plot: Model)
	local old = plot:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
end

local function draw(plot: Model, slot: number, assets: Instance)
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	local spot = SpaLayout.slotSpot(SudsRules.MASCOT_SPOT, slot)
	local seat = spot
	local scale = 1
	local bedAsset = asset(assets, BED_ASSET)
	if bedAsset then
		local bed = bedAsset:Clone() :: Model
		bed.Name = "SudsBed"
		bed:PivotTo(spot)
		settle(bed)
		local point = bed:FindFirstChild(SEAT, true)
		if point and point:IsA("Attachment") then
			seat = (point :: Attachment).WorldCFrame
		end
		local raw = bed:GetAttribute("CatScale")
		scale = if type(raw) == "number" and raw > 0 then raw else 1
		bed.Parent = folder
	end
	local catAsset = asset(
		assets,
		SudsRules.asset("_Sit", function(name: string): boolean
			return assets:FindFirstChild(name) ~= nil
		end)
	)
	if catAsset then
		local cat = catAsset:Clone() :: Model
		cat.Name = SudsRules.NAME
		cat:ScaleTo(scale)
		cat:PivotTo(seat)
		settle(cat)
		cat:SetAttribute("Mascot", true)
		local tap = Instance.new("ClickDetector")
		tap.Name = "Pet"
		tap.MaxActivationDistance = TAP_REACH
		tap.Parent = cat
		cat.Parent = folder
	end
	folder.Parent = plot
end

-- Draws Suds in the player's plot, or clears him: shown while the switch is on and his save has him named.
function MascotService.refresh(player: Player)
	local slot = SpaLayout.slotOf(player)
	local plot = if slot then SpaLayout.plotModel(slot) else nil
	if slot == nil or plot == nil then
		return
	end
	clear(plot)
	local save = DataService.get(player)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if
		not LiveFlags.isOn(SudsRules.MASCOT_FLAG)
		or save == nil
		or assets == nil
		or SudsRules.cleanStage(save.suds) < SudsRules.DONE
		or inTub(player)
	then
		return
	end
	draw(plot, slot, assets :: Instance)
end

local function refreshAll()
	for _, player in Players:GetPlayers() do
		MascotService.refresh(player)
	end
end

function MascotService.Init(_services: { [string]: any }) end

function MascotService.Start()
	DataService.onLoaded:Connect(function(player: Player)
		MascotService.refresh(player)
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		player:GetAttributeChangedSignal(SpaLayout.SLOT_ATTRIBUTE):Connect(function()
			MascotService.refresh(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local slot = SpaLayout.slotOf(player)
		local plot = if slot then SpaLayout.plotModel(slot) else nil
		if plot then
			clear(plot)
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(SpaLayout.PLACED_ATTRIBUTE):Connect(refreshAll)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. SudsRules.MASCOT_FLAG)
		:Connect(refreshAll)
end

return MascotService
