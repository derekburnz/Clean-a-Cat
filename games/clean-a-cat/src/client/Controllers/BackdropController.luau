--!strict
-- BackdropController: the draft world behind the street (Derek 2026-11-24: "draft the world/background ... to help
-- set the atmosphere"), switch worldBackdrop, off by default. Model-Agent's CleanACat_Area_Backdrop is cloned once on
-- this device, unturned, with its pivot on the street's (slot 1's plot pivot), while the plots are placed. It only
-- looks: every part is anchored with collisions, queries, touches and shadows off, so nothing in the game reads it.
--
-- A local copy rather than the server's, so the server never sends its 505 parts to each joining player, and the
-- opening never waits on it (the truck starts as the save loads; this clones in the background, a frame later).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local FLAG = "worldBackdrop"
local ASSET = "CleanACat_Area_Backdrop"
local ASSET_WAIT_SECONDS = 10

local BackdropController = {}

local backdrop: Model? = nil
local warned = false

local function placed(): boolean
	return ReplicatedStorage:GetAttribute(SpaLayout.PLACED_ATTRIBUTE) == true
end

local function remove()
	local found = backdrop
	backdrop = nil
	if found then
		found:Destroy()
	end
end

local function place()
	if backdrop ~= nil then
		return
	end
	local assets = ReplicatedStorage:WaitForChild("Assets", ASSET_WAIT_SECONDS)
	-- (switch bigSpa) the wider street's own backdrop while the big spa is placed, else the small one's
	-- (switch wideStreet) the longer street's own backdrop while it is placed, the big one's while that is missing
	local wide = if SpaLayout.wide() and assets
		then assets:FindFirstChild(SpaLayout.WIDE_BACKDROP_ASSET)
		else nil
	local big = if wide
		then wide
		elseif SpaLayout.big() and assets then assets:FindFirstChild(
			SpaLayout.BIG_BACKDROP_ASSET
		)
		else nil
	local asset = if big then big elseif assets then assets:FindFirstChild(ASSET) else nil
	if asset == nil or not asset:IsA("Model") then
		if not warned then
			warned = true
			warn(`BackdropController: ReplicatedStorage.Assets.{ASSET} is missing`)
		end
		return
	end
	-- the switch or the plots may have changed while the assets were awaited
	if backdrop ~= nil or not LiveFlags.isOn(FLAG) or not placed() then
		return
	end
	local model = (asset :: Model):Clone() :: Model
	model.Name = "CleanACat_Backdrop"
	model:PivotTo(CFrame.new(SpaLayout.slotPivot(1)))
	model.Parent = Workspace
	backdrop = model
end

local function refresh()
	if LiveFlags.isOn(FLAG) and placed() then
		task.defer(place)
	else
		remove()
	end
end

function BackdropController.Init(_controllers: { [string]: any }) end

function BackdropController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal(SpaLayout.PLACED_ATTRIBUTE):Connect(refresh)
	-- the street placed again as the other size: the backdrop that fits it
	for _, attribute in { SpaLayout.BIG_ATTRIBUTE, SpaLayout.WIDE_ATTRIBUTE } do
		ReplicatedStorage:GetAttributeChangedSignal(attribute):Connect(function()
			remove()
			refresh()
		end)
	end
	refresh()
end

return BackdropController
