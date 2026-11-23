--!strict
-- WindowController: the display window. The player's window cats (their clean sitting models) sit on the plot's
-- window seat at SpotWindow1 to 4, or on four placeholder cushions in the placeholder room. It only draws what the server sends (Residents);
-- WindowService owns the residents and the tips. The real window comes with Model-Agent's #17. Behind the
-- LiveFlags switch `strays`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BowFit = require(script.Parent.Parent:WaitForChild("Spa"):WaitForChild("BowFit"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SpaRules = require(Shared:WaitForChild("SpaRules"))
local WindowRules = require(Shared:WaitForChild("WindowRules"))

local FLAG = "strays"
local CUSHION_SIZE = Vector3.new(2, 0.5, 2)
local CAT_SCALE = 1
local ASSET_WAIT_SECONDS = 5

local WindowController = {}

local folder: Folder? = nil
local cats: Folder? = nil
local connection: RBXScriptConnection? = nil
local drawnSeq = 0
local lastResidents: unknown = nil -- the newest list the server sent, to redraw when the plot comes or goes

-- The `index`th window spot: on the plot, its window seat cushion; in the placeholder room, the floor under a
-- placeholder cushion.
local function cushionCFrame(index: number): CFrame
	return SpaLayout.lineSpot("SpotWindow", index)
end

-- Where a window cat sits: on the plot's cushion, or on top of the placeholder cushion.
local function seatCFrame(index: number): CFrame
	return cushionCFrame(index) * CFrame.new(0, if SpaLayout.onPlot() then 0 else CUSHION_SIZE.Y, 0)
end

-- The placeholder cushions, only in the placeholder room: the plot has its own window seat.
local function drawCushions(parent: Instance)
	for _, child in parent:GetChildren() do
		if string.match(child.Name, "^Cushion%d+$") then
			child:Destroy()
		end
	end
	if SpaLayout.onPlot() then
		return
	end
	for index = 1, WindowRules.CUSHIONS do
		local cushion = Instance.new("Part")
		cushion.Name = `Cushion{index}`
		cushion.Size = CUSHION_SIZE
		cushion.Color = Color3.fromRGB(240, 190, 210)
		cushion.Anchored = true
		cushion.CanQuery = false
		cushion.CFrame = cushionCFrame(index) * CFrame.new(0, CUSHION_SIZE.Y / 2, 0)
		cushion.Parent = parent
	end
end

local function catAsset(kind: string): Model?
	local assets = ReplicatedStorage:WaitForChild("Assets", ASSET_WAIT_SECONDS)
	local asset = if assets then assets:FindFirstChild(`CleanACat_Cat_{kind}_Sit`) else nil
	return if asset and asset:IsA("Model") then asset :: Model else nil
end

local function onResidents(rawList: unknown)
	local current = cats
	if current == nil or type(rawList) ~= "table" then
		return
	end
	lastResidents = rawList
	drawnSeq += 1
	local seq = drawnSeq
	local line = Instance.new("Folder")
	line.Name = "Cats"
	local index = 0
	for _, entry in rawList :: { unknown } do
		local fields: { [string]: unknown } = if type(entry) == "table"
			then entry :: { [string]: unknown }
			else {}
		local kind = fields.cat
		local bowId = fields.bow
		if index < WindowRules.CUSHIONS and type(kind) == "string" and CatRules.rarityOf(kind) then
			index += 1
			local asset = catAsset(kind)
			if asset then
				local cat = asset:Clone() :: Model
				cat:ScaleTo(CAT_SCALE)
				cat:PivotTo(seatCFrame(index))
				for _, part in cat:GetDescendants() do
					if part:IsA("BasePart") then
						local p = part :: BasePart
						p.Anchored = true
						p.CanCollide = false
						p.CanQuery = false
					end
				end
				cat:SetAttribute("Resident", true)
				if type(bowId) == "string" and table.find(SpaRules.BOWS, bowId) then
					BowFit.wear(cat, bowId, CAT_SCALE)
				end
				cat.Parent = line
			end
		end
	end
	-- catAsset may have waited: draw only the newest list, and only while the switch is still on.
	if seq ~= drawnSeq or cats ~= current then
		line:Destroy()
		return
	end
	current:ClearAllChildren()
	for _, child in line:GetChildren() do
		child.Parent = current
	end
	line:Destroy()
end

local function enable()
	if folder then
		return
	end
	local made = Instance.new("Folder")
	made.Name = "PH_Window"
	drawCushions(made)
	local catFolder = Instance.new("Folder")
	catFolder.Name = "Cats"
	catFolder.Parent = made
	made.Parent = Workspace
	folder = made
	cats = catFolder
	connection = Remotes.event("Residents").OnClientEvent:Connect(onResidents)
end

local function disable()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if folder then
		folder:Destroy()
		folder = nil
		cats = nil
	end
	lastResidents = nil
end

local function refresh()
	if LiveFlags.isOn(FLAG) then
		enable()
	else
		disable()
	end
end

function WindowController.Init(_controllers: { [string]: any }) end

function WindowController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(refresh)
	-- The plot placed or taken away: cushions and cats are drawn again at the new spots.
	SpaLayout.changed(function()
		local made = folder
		if made == nil then
			return
		end
		drawCushions(made)
		if lastResidents ~= nil then
			task.spawn(onResidents, lastResidents)
		end
	end)
	refresh()
end

return WindowController
