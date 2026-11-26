--!strict
-- CrateController: a crate the player holds, on their own plot (CrateRules, issues 511 and 512). While the save holds a
-- crate (the server's Crates_<kind> Player attributes), Model-Agent's CleanACat_Prop_PetCrate stands on the Crate spot
-- with its chance list over it: every pet with its percent and boost, adding to 100, from CrateRules.odds (the list the
-- server rolls from), and the line that doubles are kept and three fuse into a star up. The list shows the whole time
-- the crate is there, before any open. The player opens it with their own tap on the prompt; the server rolls the pet
-- (CrateOpened), the lid opens the same every time and the pet appears on the crate's PetSeat, then joins the player.
-- With the switch crateWindow on, the chance list moves into Design-Agent's crate window (UI/CrateWindow): the tap
-- reads "Look inside" and fires CrateController.lookInside(kind) for CrateWindowController, and the window's Open crate
-- sends the open. With it off, the placeholder list stands over the crate and the tap opens it, as before.
-- Fires Moments CrateDropped, CrateOpened and PetRevealed for the motion and sound lanes.
-- Behind the LiveFlags switch `pets`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrateRules = require(Shared:WaitForChild("CrateRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(Shared:WaitForChild("Moments"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local WINDOW_FLAG = "crateWindow"
local CRATE_ASSET = "CleanACat_Prop_PetCrate"
local NAME = "CleanACat_HeldCrate"
local REVEAL_SECONDS = 3 -- the pet stays on the crate this long before it goes to the player
local PROMPT_REACH = 10

local CrateController = {}

-- (kind) when the player taps the crate while the crate window is on (CrateWindowController opens the window).
CrateController.lookInside = Signal.new() :: Signal.Signal<string>

local crate: Model? = nil
local shownKind: string? = nil
local lastCount = 0
local busy = false

local function held(): (string?, number)
	local total = 0
	local first: string? = nil
	-- the day 2 crate first: it is the better one
	for index = #CrateRules.KINDS, 1, -1 do
		local kind = CrateRules.KINDS[index]
		local count = Players.LocalPlayer:GetAttribute(CrateRules.CRATE_ATTRIBUTE_PREFIX .. kind)
		if type(count) == "number" and count > 0 then
			total += count
			first = first or kind
		end
	end
	return first, total
end

local function percentText(percent: number): string
	if percent >= 1 and percent % 1 == 0 then
		return `{percent}%`
	end
	return `{math.floor(percent * 10 + 0.5) / 10}%`
end

-- The placeholder chance list over the crate (Design's crate window replaces it).
local function oddsBoard(parent: BasePart, kind: string, count: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "PH_CrateOdds"
	gui.Size = UDim2.fromOffset(220, 230)
	gui.StudsOffset = Vector3.new(0, 4.2, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 40
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.Parent = frame
	local lines = { `{if kind == "good" then "Good crate" else "Crate"} x{count}: what's inside` }
	for _, entry in CrateRules.odds(kind) do
		table.insert(
			lines,
			`{entry.pet} ({entry.rarity})  {percentText(entry.percent)}  +{math.floor(
				entry.boost * 100 + 0.5
			)}%`
		)
	end
	table.insert(lines, CrateRules.ODDS_NOTE)
	for index, line in lines do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -12, 0, if index == #lines then 34 else 20)
		label.BackgroundTransparency = 1
		label.Font = if index == 1 then Enum.Font.FredokaOne else Enum.Font.Gotham
		label.TextScaled = true
		label.TextWrapped = true
		label.TextColor3 = Color3.fromRGB(69, 34, 107)
		label.Text = line
		label.LayoutOrder = index
		label.Parent = frame
	end
	gui.Parent = parent
end

local function clear()
	local old = crate
	crate = nil
	shownKind = nil
	if old then
		old:Destroy()
	end
end

local function draw()
	local kind, count = held()
	if busy then
		return
	end
	if not LiveFlags.isOn(CrateRules.FLAG) or kind == nil or SpaLayout.slotOf() == nil then
		clear()
		lastCount = count
		return
	end
	local rose = count > lastCount
	lastCount = count
	local windowed = LiveFlags.isOn(WINDOW_FLAG)
	if crate and shownKind == kind and not rose and crate:GetAttribute("Windowed") == windowed then
		return
	end
	clear()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local asset = if assets then assets:FindFirstChild(CRATE_ASSET) else nil
	local model: Model
	if asset and asset:IsA("Model") then
		model = (asset :: Model):Clone() :: Model
	else
		model = Instance.new("Model")
		local box = Instance.new("Part")
		box.Name = "PH_Crate"
		box.Size = Vector3.new(2, 2, 2)
		box.Color = Color3.fromRGB(255, 205, 120)
		box.Parent = model
		model.PrimaryPart = box
	end
	model.Name = NAME
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			(part :: BasePart).Anchored = true
		end
	end
	model:PivotTo(SpaLayout.spot("Crate") * CFrame.new(0, if asset then 0 else 1, 0))
	local base = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if base then
		if not windowed then
			oddsBoard(base :: BasePart, kind, count)
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = if windowed then "Look inside" else "Open crate"
		prompt.ObjectText = if kind == "good" then "Good crate" else "Crate"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = PROMPT_REACH
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function()
			if busy then
				return
			end
			if LiveFlags.isOn(WINDOW_FLAG) then
				CrateController.lookInside:Fire(kind)
			else
				Remotes.event("RequestOpenCrate"):FireServer(kind)
			end
		end)
		prompt.Parent = base
	end
	model:SetAttribute("Windowed", windowed)
	model.Parent = Workspace
	crate = model
	shownKind = kind
	if rose then
		Moments.CrateDropped:Fire(model)
	end
end

local function petModel(kind: string, star: number): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local asset = if assets then assets:FindFirstChild(`CleanACat_Pet_{kind}`) else nil
	if not (asset and asset:IsA("Model")) then
		return nil
	end
	local pet = (asset :: Model):Clone() :: Model
	for _, piece in pet:GetDescendants() do
		local level = piece:GetAttribute("StarLevel")
		if piece:IsA("Model") and type(level) == "number" and level > star then
			piece:Destroy()
		elseif piece:IsA("BasePart") then
			local part = piece :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
		end
	end
	return pet
end

local function onOpened(_rawKind: unknown, rawPet: unknown)
	local open = crate
	if type(rawPet) ~= "table" or open == nil then
		draw()
		return
	end
	local kind = (rawPet :: any).kind
	local star = (rawPet :: any).star
	if type(kind) ~= "string" or CrateRules.rarityOf(kind) == nil or type(star) ~= "number" then
		draw()
		return
	end
	busy = true
	Moments.CrateOpened:Fire(open)
	local seat = open:FindFirstChild("PetSeat", true)
	local pet = petModel(kind, star)
	if pet then
		local scale = pet:GetAttribute("PetScale")
		pet:ScaleTo(if type(scale) == "number" and scale > 0 then scale else 0.7)
		pet:PivotTo(
			if seat and seat:IsA("Attachment")
				then (seat :: Attachment).WorldCFrame
				else open:GetPivot()
		)
		pet.Parent = Workspace
		Moments.PetRevealed:Fire(pet)
	end
	task.delay(REVEAL_SECONDS, function()
		if pet then
			pet:Destroy()
		end
		busy = false
		clear()
		draw()
	end)
end

function CrateController.Init(_controllers: { [string]: any }) end

function CrateController.Start()
	for _, kind in CrateRules.KINDS do
		Players.LocalPlayer
			:GetAttributeChangedSignal(CrateRules.CRATE_ATTRIBUTE_PREFIX .. kind)
			:Connect(draw)
	end
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. CrateRules.FLAG)
		:Connect(draw)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. WINDOW_FLAG)
		:Connect(draw)
	Remotes.event("CrateOpened").OnClientEvent:Connect(onOpened)
	SpaLayout.changed(function()
		clear()
		draw()
	end)
	-- the count held when the game starts is not a new crate: it shows without the drop
	local _, count = held()
	lastCount = count
	draw()
end

return CrateController
