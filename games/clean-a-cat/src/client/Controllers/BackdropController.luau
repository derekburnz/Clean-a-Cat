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
	local asset = if assets then assets:FindFirstChild(ASSET) else nil
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
	refresh()
end

return BackdropController
