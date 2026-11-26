--!strict
-- SpaSignController: writes each spa's name on the face of its window sign (#379). Model-Agent's
-- CleanACat_Prop_WindowSign stands in every plot's Props folder (PlotService, SpaLayout.PROPS) with a blank cream
-- face, the part named Screen. This client draws a SurfaceGui on it in navy: "<owner's display name>'s" over
-- "Spa", or "Clean a Cat" over "Spa" while nobody has the plot. Each client draws every plot's sign itself, so
-- nothing new goes over the network: the owner of a plot is the player whose attribute SpaLayout.SLOT_ATTRIBUTE holds that slot. Display
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
local EMPTY_TEXT = "Clean a Cat" -- the top line of a free plot's sign; the bottom line is always SPA_TEXT
local SPA_TEXT = "Spa"
local INK = Color3.fromHex("2F3E5C") -- pants_navy: about 10 to 1 on the cream face
local PIXELS_PER_STUD = 60 -- the 5.5 by 1.9 stud face is a 330 by 114 canvas
local MAX_NAME = 10 -- longer display names end in "..." on the sign (shortName)
local MAX_TEXT = 56 -- short names stop growing here, so "Jo's" does not fill the whole board
local SPA_TEXT_SIZE = 34 -- "Spa" has a line of its own at one size, so it reads whatever the name above does

local SpaSignController = {}

local watched: { [Player]: RBXScriptConnection } = {}
-- still listed while they leave; a strong table (a weak one on Instances can drop a player who still exists), each
-- entry cleared once the leaver has gone
local leaving: { [Player]: boolean } = {}
local LEAVING_KEEP = 10 -- seconds a leaver stays marked: long after they are out of the player list

local function ownerOf(slot: number): Player?
	for _, player in Players:GetPlayers() do
		if not leaving[player] and SpaLayout.slotOf(player) == slot then
			return player
		end
	end
	return nil
end

-- A long display name would shrink the whole sign to a thin line nobody reads from the road (Sync-Agent's run
-- on 507cdce), so the sign keeps the first MAX_NAME - 1 characters and adds "..." (plain dots, which every font
-- has). Counted in UTF-8 characters, so a name is never cut in the middle of one.
local function shortName(name: string): string
	local length = utf8.len(name)
	if length == nil or length <= MAX_NAME then
		return name
	end
	local cut = utf8.offset(name, MAX_NAME) -- the byte where character MAX_NAME starts
	if cut == nil then
		return name
	end
	return string.sub(name, 1, cut - 1) .. "..."
end

local function signText(owner: Player?): string
	if owner == nil then
		return EMPTY_TEXT
	end
	local name = owner.DisplayName
	if name == "" then
		name = owner.Name
	end
	return `{shortName(name)}'s`
end

local function screenOf(plot: Model): BasePart?
	local props = plot:FindFirstChild(SpaLayout.PROPS_FOLDER)
	local sign = if props then props:FindFirstChild(SIGN_NAME) else nil
	local screen = if sign then sign:FindFirstChild(SCREEN_NAME, true) else nil
	return if screen and screen:IsA("BasePart") then screen :: BasePart else nil
end

-- Two lines: the name on top, one line scaled to fit the width (Sync-Agent's run on 02b38ae: one wrapped line
-- let "Spa" fall to a second line and shrank everything), and "Spa" below at a fixed size.
local function line(
	gui: SurfaceGui,
	name: string,
	top: number,
	height: number,
	maxSize: number
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.fromScale(0.06, top)
	label.Size = UDim2.fromScale(0.88, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = INK
	-- TextWrapped first: in Roblox, turning TextWrapped off also turns TextScaled off (Sync-Agent's run on
	-- ff0803d drew both lines at size 8), so scaling goes on after it.
	label.TextWrapped = false
	label.TextScaled = true
	label.Parent = gui
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.Parent = label
	return label
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
		label = line(gui, "Name", 0.08, 0.5, MAX_TEXT)
		local spa = line(gui, "Spa", 0.6, 0.32, SPA_TEXT_SIZE)
		spa.Text = SPA_TEXT
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
	-- The street can reach this client a moment after the attribute that says it is placed, and a plot rebuilt or
	-- streamed in late brings its sign face after that: redraw once a sign's Screen shows up.
	local pending = false
	local function refreshSoon()
		if not pending then
			pending = true
			task.defer(function()
				pending = false
				refresh()
			end)
		end
	end
	local function watchPlots(folder: Instance)
		folder.DescendantAdded:Connect(function(descendant: Instance)
			if descendant.Name == SCREEN_NAME and descendant:FindFirstAncestor(SIGN_NAME) then
				refreshSoon()
			end
		end)
		refreshSoon()
	end
	Workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == SpaLayout.PLOTS_FOLDER then
			watchPlots(child)
		end
	end)
	local plots = Workspace:FindFirstChild(SpaLayout.PLOTS_FOLDER)
	if plots then
		watchPlots(plots)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		leaving[player] = true
		local connection: RBXScriptConnection? = watched[player]
		watched[player] = nil
		if connection then
			connection:Disconnect()
		end
		refresh() -- the leaver's sign goes back to the empty text
		task.delay(LEAVING_KEEP, function()
			leaving[player] = nil
		end)
	end)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return SpaSignController
