--!strict
-- ChanceBoardController: the chance board by the door, as a placeholder sign listing each rarity, its chance
-- and its cats, read from CatRules.boardLines (the same tables the server rolls from). It lights up from the
-- second customer: the server sets the Player attribute ChanceBoardLit once a customer has been served, so the
-- first customer, who is always common, never contradicts it. The chances are those of the player's star tier
-- (Player attribute CatRules.TIER_ATTRIBUTE, set by the server from the same table its rolls use); the board is
-- drawn again when the tier goes up. Behind the LiveFlags switch `customers`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local FLAG = "customers"
local LIT = "ChanceBoardLit"
local BOARD_SIZE = Vector3.new(4, 4, 0.3)

local ChanceBoardController = {}

local board: Part? = nil
local shownTier = 0 -- the tier the board was drawn for

-- Standing at SpotBoard, its front facing the way the spot faces.
local function boardCFrame(): CFrame
	return SpaLayout.spot("SpotBoard") * CFrame.new(0, BOARD_SIZE.Y / 2, 0)
end

local function build(tier: number): Part
	local part = Instance.new("Part")
	part.Name = "PH_ChanceBoard"
	part.Size = BOARD_SIZE
	part.Color = Color3.fromRGB(250, 245, 235)
	part.Anchored = true
	part.CanQuery = false
	part.CFrame = boardCFrame()
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- the front (-Z) faces the way the spot faces
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = part
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 0.16)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Font = Enum.Font.FredokaOne
	title.Text = "Who might visit"
	title.LayoutOrder = 0
	title.Parent = gui
	for index, line in CatRules.boardLines(tier) do
		local label = Instance.new("TextLabel")
		label.Name = line.rarity
		label.Size = UDim2.fromScale(1, 0.14)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.Text =
			`{line.rarity} {CatRules.percentText(line.percent)}: {table.concat(line.cats, ", ")}`
		label.LayoutOrder = index
		label.Parent = gui
	end
	local nextStars = CatRules.nextTierStars(tier)
	local footer = Instance.new("TextLabel")
	footer.Name = "NextTier"
	footer.Size = UDim2.fromScale(1, 0.14)
	footer.BackgroundTransparency = 1
	footer.TextScaled = true
	footer.Font = Enum.Font.FredokaOne
	footer.Text = if nextStars
		then `Rarer cats at {nextStars} stars`
		else "Your spa gets the rarest cats"
	footer.LayoutOrder = #CatRules.RARITIES + 1
	footer.Parent = gui
	return part
end

local function refresh()
	local show = LiveFlags.isOn(FLAG) and Players.LocalPlayer:GetAttribute(LIT) == true
	local tier = CatRules.cleanTier(Players.LocalPlayer:GetAttribute(CatRules.TIER_ATTRIBUTE))
	if board and (not show or tier ~= shownTier) then
		board:Destroy()
		board = nil
	end
	if show and not board then
		local part = build(tier)
		part.Parent = Workspace
		board = part
		shownTier = tier
	end
end

function ChanceBoardController.Init(_controllers: { [string]: any }) end

function ChanceBoardController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(refresh)
	Players.LocalPlayer:GetAttributeChangedSignal(LIT):Connect(refresh)
	Players.LocalPlayer:GetAttributeChangedSignal(CatRules.TIER_ATTRIBUTE):Connect(refresh)
	-- The plot placed or taken away: the board moves to its spot.
	SpaLayout.changed(function()
		local part = board
		if part then
			part.CFrame = boardCFrame()
		end
	end)
	refresh()
end

return ChanceBoardController
