--!strict
-- WindowController: the display window, as four placeholder cushions near the spawn with the player's window
-- cats sitting on them (their clean sitting models). It only draws what the server sends (Residents);
-- WindowService owns the residents and the tips. The real window comes with Model-Agent's #17. Behind the
-- LiveFlags switch `strays`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local WindowRules = require(Shared:WaitForChild("WindowRules"))

local FLAG = "strays"
local WINDOW_POSITION = Vector3.new(-9, 0, -3) -- the first cushion, on the floor left of the spawn
local SPACING = Vector3.new(2.4, 0, 0)
local FACING = CFrame.Angles(0, math.pi, 0) -- models face -Z; turned to face the spawn (+Z)
local CUSHION_SIZE = Vector3.new(2, 0.5, 2)
local CAT_SCALE = 1
local ASSET_WAIT_SECONDS = 5

local WindowController = {}

local folder: Folder? = nil
local cats: Folder? = nil
local connection: RBXScriptConnection? = nil
local drawnSeq = 0

local function cushionCFrame(index: number): CFrame
	return CFrame.new(WINDOW_POSITION + SPACING * (index - 1)) * FACING
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
	drawnSeq += 1
	local seq = drawnSeq
	local line = Instance.new("Folder")
	line.Name = "Cats"
	local index = 0
	for _, entry in rawList :: { unknown } do
		local kind = if type(entry) == "table" then (entry :: { [string]: unknown }).cat else nil
		if index < WindowRules.CUSHIONS and type(kind) == "string" and CatRules.rarityOf(kind) then
			index += 1
			local asset = catAsset(kind)
			if asset then
				local cat = asset:Clone() :: Model
				cat:ScaleTo(CAT_SCALE)
				cat:PivotTo(cushionCFrame(index) * CFrame.new(0, CUSHION_SIZE.Y, 0))
				for _, part in cat:GetDescendants() do
					if part:IsA("BasePart") then
						local p = part :: BasePart
						p.Anchored = true
						p.CanCollide = false
						p.CanQuery = false
					end
				end
				cat:SetAttribute("Resident", true)
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
	for index = 1, WindowRules.CUSHIONS do
		local cushion = Instance.new("Part")
		cushion.Name = `Cushion{index}`
		cushion.Size = CUSHION_SIZE
		cushion.Color = Color3.fromRGB(240, 190, 210)
		cushion.Anchored = true
		cushion.CanQuery = false
		cushion.CFrame = cushionCFrame(index) * CFrame.new(0, CUSHION_SIZE.Y / 2, 0)
		cushion.Parent = made
	end
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
	refresh()
end

return WindowController
