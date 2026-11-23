--!strict
-- DoorController: the customers waiting at the door, as placeholder figures (a block holding the customer's
-- dirty cat) in a line, front first. It only shows what the server says (CustomerQueue); SpaService owns the
-- queue and the rolls. Behind the LiveFlags switch `customers`. With `customerFigures` on and the plot placed,
-- the server draws real customers with carriers in the plot instead (FigureService), and this draws nothing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local FLAG = "customers"
local FIGURES_FLAG = "customerFigures"
local FIGURE_SIZE = Vector3.new(1.6, 3.6, 1)
local CAT_SCALE = 0.8
local MAX_SHOWN = 5
local ASSET_WAIT_SECONDS = 5

local DoorController = {}

local folder: Folder? = nil
local connection: RBXScriptConnection? = nil
local shownSeq = 0 -- the newest queue drawn, so an older answer that finished waiting late does not win
local lastQueue: unknown = nil -- the newest queue the server sent, to redraw when the plot comes or goes

local function catAsset(kind: string): Model?
	local assets = ReplicatedStorage:WaitForChild("Assets", ASSET_WAIT_SECONDS)
	local asset = if assets then assets:FindFirstChild(`CleanACat_Cat_{kind}_Dirty_Sit`) else nil
	return if asset and asset:IsA("Model") then asset :: Model else nil
end

local function figure(kind: string, index: number, parent: Instance)
	local spot = SpaLayout.lineSpot("SpotQueue", index) -- the front of the line is SpotQueue1
	local model = Instance.new("Model")
	model.Name = `PH_Customer{index}`
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = FIGURE_SIZE
	body.Color = Color3.fromRGB(150, 170, 200)
	body.Anchored = true
	body.CanQuery = false
	body.CFrame = spot * CFrame.new(0, FIGURE_SIZE.Y / 2, 0)
	body.Parent = model
	local asset = catAsset(kind)
	if asset then
		local cat = asset:Clone() :: Model
		cat:ScaleTo(CAT_SCALE)
		-- Held in front of the figure at chest height.
		cat:PivotTo(spot * CFrame.new(0, FIGURE_SIZE.Y * 0.55, -(FIGURE_SIZE.Z / 2 + 0.5)))
		for _, part in cat:GetDescendants() do
			if part:IsA("BasePart") then
				local p = part :: BasePart
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
			end
		end
		cat:SetAttribute("Customer", true)
		cat.Parent = model
	end
	model:SetAttribute("CatKind", kind)
	model.Parent = parent
end

local function onQueue(rawKinds: unknown)
	local current = folder
	if current == nil or type(rawKinds) ~= "table" then
		return
	end
	lastQueue = rawKinds
	shownSeq += 1
	local seq = shownSeq
	local kinds: { string } = {}
	for _, kind in rawKinds :: { unknown } do
		if type(kind) == "string" and CatRules.rarityOf(kind) and #kinds < MAX_SHOWN then
			table.insert(kinds, kind)
		end
	end
	if LiveFlags.isOn(FIGURES_FLAG) and SpaLayout.onPlot() then
		table.clear(kinds) -- the server's figures stand in the plot
	end
	local line = Instance.new("Folder")
	line.Name = "Line"
	for index, kind in kinds do
		figure(kind, index, line)
	end
	-- catAsset may have waited; draw only if this is still the newest queue and the switch is still on.
	if seq ~= shownSeq or folder ~= current then
		line:Destroy()
		return
	end
	current:ClearAllChildren()
	line.Parent = current
end

local function enable()
	if folder then
		return
	end
	local made = Instance.new("Folder")
	made.Name = "PH_Door"
	made.Parent = Workspace
	folder = made
	connection = Remotes.event("CustomerQueue").OnClientEvent:Connect(onQueue)
end

local function disable()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	lastQueue = nil
end

local function refresh()
	if LiveFlags.isOn(FLAG) then
		enable()
	else
		disable()
	end
end

function DoorController.Init(_controllers: { [string]: any }) end

function DoorController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FIGURES_FLAG)
		:Connect(function()
			if lastQueue ~= nil then
				task.spawn(onQueue, lastQueue)
			end
		end)
	-- The plot placed or taken away: the line is drawn again at its new spots.
	SpaLayout.changed(function()
		if lastQueue ~= nil then
			task.spawn(onQueue, lastQueue)
		end
	end)
	refresh()
end

return DoorController
