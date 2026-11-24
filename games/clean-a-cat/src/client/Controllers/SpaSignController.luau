--!strict
-- SpaSignController: writes each spa's name on the face of its window sign (#379). Model-Agent's
-- CleanACat_Prop_WindowSign stands in every plot's Props folder (PlotService, SpaLayout.PROPS) with a blank cream
-- face, the part named Screen. This client draws a SurfaceGui on it: "<owner's display name>'s Spa" in navy, or
-- "Clean a Cat Spa" while nobody has the plot. Each client draws every plot's sign itself, so nothing new goes over
-- the network: the owner of a plot is the player whose attribute SpaLayout.SLOT_ATTRIBUTE holds that slot. Display
-- names are Roblox's own and already moderated, so they need no text filter; a name a player types (a later spa
-- name) must go through TextService on the server before it is shown here. Behind the LiveFlags switch `spaSign`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local FLAG = "spaSign"
local SIGN_NAME = "WindowSign" -- its entry name in SpaLayout.PROPS
local SCREEN_NAME = "Screen" -- the cream face inside the sign model
local GUI_NAME = "CleanACat_SpaSign"
local EMPTY_TEXT = "Clean a Cat Spa"
local INK = Color3.fromHex("2F3E5C") -- pants_navy: about 10 to 1 on the cream face
local PIXELS_PER_STUD = 60 -- the 5.5 by 1.9 stud face is a 330 by 114 canvas
local MAX_TEXT = 64 -- short names stop growing here, so "Jo's Spa" does not fill the whole board

local SpaSignController = {}

local watched: { [Player]: RBXScriptConnection } = {}
local leaving: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- still listed while they leave

local function ownerOf(slot: number): Player?
	for _, player in Players:GetPlayers() do
		if not leaving[player] and SpaLayout.slotOf(player) == slot then
			return player
		end
	end
	return nil
end

local function signText(owner: Player?): string
	if owner == nil then
		return EMPTY_TEXT
	end
	local name = owner.DisplayName
	if name == "" then
		name = owner.Name
	end
	return `{name}'s Spa`
end

local function screenOf(plot: Model): BasePart?
	local props = plot:FindFirstChild(SpaLayout.PROPS_FOLDER)
	local sign = if props then props:FindFirstChild(SIGN_NAME) else nil
	local screen = if sign then sign:FindFirstChild(SCREEN_NAME, true) else nil
	return if screen and screen:IsA("BasePart") then screen :: BasePart else nil
end

local function draw(screen: BasePart, text: string)
	local existing = screen:FindFirstChild(GUI_NAME)
	local found = if existing then existing:FindFirstChild("Name") else nil
	local label: TextLabel
	if found and found:IsA("TextLabel") then
		label = found :: TextLabel
	else
		if existing then
			existing:Destroy()
		end
		local gui = Instance.new("SurfaceGui")
		gui.Name = GUI_NAME
		gui.Face = Enum.NormalId.Front -- the sign's front faces the street
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = PIXELS_PER_STUD
		gui.LightInfluence = 0 -- reads the same at dusk and in shade
		gui.Brightness = 1
		label = Instance.new("TextLabel")
		label.Name = "Name"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = INK
		label.TextScaled = true
		label.TextWrapped = true
		label.Parent = gui
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.06, 0)
		padding.PaddingRight = UDim.new(0.06, 0)
		padding.PaddingTop = UDim.new(0.12, 0)
		padding.PaddingBottom = UDim.new(0.12, 0)
		padding.Parent = label
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = MAX_TEXT
		limit.Parent = label
		gui.Parent = screen
	end
	if label.Text ~= text then
		label.Text = text
	end
end

local function clear(screen: BasePart)
	local existing = screen:FindFirstChild(GUI_NAME)
	if existing then
		existing:Destroy()
	end
end

local function refresh()
	local on = LiveFlags.isOn(FLAG)
	for slot = 1, SpaLayout.PLOT_COUNT do
		local plot = SpaLayout.plotModel(slot)
		local screen = if plot then screenOf(plot) else nil
		if screen then
			if on then
				draw(screen, signText(ownerOf(slot)))
			else
				clear(screen)
			end
		end
	end
end

local function watch(player: Player)
	local existing: RBXScriptConnection? = watched[player]
	if existing == nil then
		watched[player] =
			player:GetAttributeChangedSignal(SpaLayout.SLOT_ATTRIBUTE):Connect(refresh)
	end
	refresh()
end

function SpaSignController.Init(_controllers: { [string]: any }) end

function SpaSignController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal(SpaLayout.PLACED_ATTRIBUTE):Connect(refresh)
	-- The street can reach this client a moment after the attribute that says it is placed.
	Workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == SpaLayout.PLOTS_FOLDER then
			task.defer(refresh)
		end
	end)
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		leaving[player] = true
		local connection: RBXScriptConnection? = watched[player]
		watched[player] = nil
		if connection then
			connection:Disconnect()
		end
		refresh() -- the leaver's sign goes back to the empty text
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return SpaSignController
