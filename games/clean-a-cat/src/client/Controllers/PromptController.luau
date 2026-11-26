--!strict
-- PromptController: small prompts (switch smallPrompts, off by default). Derek 2026-11-24, on a rival salon game and
-- on ours: "the big black buttons on mobile take up a lot of the screen and block view sometimes (also happens for us
-- in the picking up cat out of box)". With the switch on, every ProximityPrompt in the world is drawn here instead of
-- by Roblox: a small cream pill with an ink edge, the key to press (E on a keyboard, the button on a gamepad, none on
-- a touch screen) and the action ("Pick him up"), standing just to the right of the thing it is for, never over it.
-- A tap on the pill does what the prompt does; keys work as before. Switch off: Roblox's own prompts come back.
--
-- While any window is open (the crate window, the shop, a board's card...), every prompt in the world is off on this
-- device: no pill, no key, no tap goes through the window to a board or a prompt behind it (issue 623, Sync's B5: a
-- tap on the crate window bought the Pro Brush behind it). They come back as the last window closes. This holds with
-- smallPrompts on or off.
--
-- It sets the style on this device only, for every prompt in Workspace (the game's own: the opening, the spa and the
-- boards make theirs there; Roblox's core prompts live elsewhere and are left alone) and every one added later.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))
local LiveFlags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LiveFlags"))
local UI = require(script.Parent.Parent:WaitForChild("UI"))

local FLAG = "smallPrompts"
local HEIGHT = 44 -- real px: a thumb's reach, and no bigger
local TEXT = 20 -- real px
local KEY = 28 -- real px: the key chip
local PAD = 12 -- real px inside the pill, each side
local GAP = 8 -- real px between the key chip and the words
local SIDE = 0.6 -- the pill's own widths right of the thing's edge, so it never covers it
local GAMEPAD_NAMES: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.ButtonA] = "A",
	[Enum.KeyCode.ButtonB] = "B",
	[Enum.KeyCode.ButtonX] = "X",
	[Enum.KeyCode.ButtonY] = "Y",
	[Enum.KeyCode.ButtonL1] = "LB",
	[Enum.KeyCode.ButtonR1] = "RB",
	[Enum.KeyCode.ButtonL2] = "LT",
	[Enum.KeyCode.DPadUp] = "Up",
}

local PromptController = {}

local player = Players.LocalPlayer
local drawn: { [ProximityPrompt]: BillboardGui } = {}

local function style(prompt: ProximityPrompt)
	prompt.Style = if LiveFlags.isOn(FLAG)
		then Enum.ProximityPromptStyle.Custom
		else Enum.ProximityPromptStyle.Default
end

local function restyleAll()
	for _, item in Workspace:GetDescendants() do
		if item:IsA("ProximityPrompt") then
			style(item :: ProximityPrompt)
		end
	end
end

-- The key shown on the pill for how the player is playing, or nil on a touch screen (the pill itself is tapped).
local function keyText(prompt: ProximityPrompt, input: Enum.ProximityPromptInputType): string?
	if input == Enum.ProximityPromptInputType.Touch then
		return nil
	elseif input == Enum.ProximityPromptInputType.Gamepad then
		local code = prompt.GamepadKeyCode
		return GAMEPAD_NAMES[code] or UserInputService:GetStringForKeyCode(code)
	end
	return prompt.KeyboardKeyCode.Name
end

-- What the pill stands beside: the prompt's part or attachment, or a model's main part.
local function adorneeOf(prompt: ProximityPrompt): Instance?
	local parent = prompt.Parent
	if parent == nil then
		return nil
	end
	if parent:IsA("BasePart") or parent:IsA("Attachment") then
		return parent
	end
	if parent:IsA("Model") then
		return (parent :: Model).PrimaryPart or parent:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function hide(prompt: ProximityPrompt)
	local gui = drawn[prompt]
	drawn[prompt] = nil
	if gui then
		gui:Destroy()
	end
end

local function show(prompt: ProximityPrompt, input: Enum.ProximityPromptInputType)
	hide(prompt)
	local adornee = adorneeOf(prompt)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if adornee == nil or playerGui == nil then
		return
	end
	local key = keyText(prompt, input)
	local words =
		TextService:GetTextSize(prompt.ActionText, TEXT, Kit.FONT, Vector2.new(1000, HEIGHT))
	local width = PAD * 2 + math.ceil(words.X) + (if key then KEY + GAP else 0)

	local gui = Instance.new("BillboardGui")
	gui.Name = "CleanACat_Prompt"
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.Active = true -- so the pill takes a tap
	gui.ResetOnSpawn = false
	gui.Size = UDim2.fromOffset(width, HEIGHT)
	gui.ExtentsOffset = Vector3.new(1, 0, 0) -- at the thing's right edge, as the camera sees it
	-- and then clear of it; a board row's pill also steps up or down by its PillStep (BoardProp, issue 574)
	local step = prompt:GetAttribute("PillStep")
	gui.SizeOffset = Vector2.new(SIDE, if type(step) == "number" and step == step then step else 0)

	local pill = Instance.new("TextButton")
	pill.Name = "Pill"
	pill.Text = ""
	pill.AutoButtonColor = true
	pill.BackgroundColor3 = Kit.WHITE
	pill.Size = UDim2.fromScale(1, 1)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Kit.WHITE, Kit.CREAM)
	gradient.Parent = pill
	Kit.corner(pill, UDim.new(0.5, 0))
	local edge = Kit.stroke(pill, 2)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, PAD)
	pad.PaddingRight = UDim.new(0, PAD)
	pad.Parent = pill
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, GAP)
	list.Parent = pill
	if key then
		local chip = Instance.new("TextLabel")
		chip.Name = "Key"
		chip.LayoutOrder = 1
		chip.Size = UDim2.fromOffset(KEY, KEY)
		chip.BackgroundColor3 = Kit.INK
		chip.Font = Kit.FONT
		chip.Text = key
		chip.TextSize = TEXT - 4
		chip.TextColor3 = Kit.WHITE
		Kit.corner(chip, UDim.new(0, 8))
		chip.Parent = pill
	end
	local label = Instance.new("TextLabel")
	label.Name = "Action"
	label.LayoutOrder = 2
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, math.ceil(words.X), 1, 0)
	label.Font = Kit.FONT
	label.Text = prompt.ActionText
	label.TextSize = TEXT
	label.TextColor3 = Kit.INK
	label.Parent = pill
	pill.Parent = gui
	pill.Activated:Connect(function()
		if not prompt.Enabled or not ProximityPromptService.Enabled or UI.anyWindowOpen() then
			return
		end
		-- a hold prompt is held for its time, as a key would be
		prompt:InputHoldBegin()
		if prompt.HoldDuration > 0 then
			task.delay(prompt.HoldDuration, function()
				if prompt.Parent ~= nil then
					prompt:InputHoldEnd()
				end
			end)
		else
			prompt:InputHoldEnd()
		end
	end)
	gui.Parent = playerGui
	drawn[prompt] = gui
	-- a prompt switched off, moved or removed takes its pill with it (Roblox also sends PromptHidden)
	local function gone()
		if drawn[prompt] == gui and (not prompt.Enabled or prompt.Parent == nil) then
			hide(prompt)
		end
	end
	local onEnabled = prompt:GetPropertyChangedSignal("Enabled"):Connect(gone)
	local onMoved = prompt.AncestryChanged:Connect(gone)
	-- each showing connects afresh, so the pill's end lets go of both
	gui.Destroying:Connect(function()
		onEnabled:Disconnect()
		onMoved:Disconnect()
		if drawn[prompt] == gui then
			drawn[prompt] = nil
		end
	end)
end

function PromptController.Start()
	UI.onWindowsChanged(function(open: boolean)
		ProximityPromptService.Enabled = not open
		if open then
			for prompt in table.clone(drawn) do
				hide(prompt)
			end
		end
	end)
	Workspace.DescendantAdded:Connect(function(item: Instance)
		if item:IsA("ProximityPrompt") then
			style(item :: ProximityPrompt)
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG)
		:Connect(function()
			restyleAll()
			if not LiveFlags.isOn(FLAG) then
				for prompt in table.clone(drawn) do
					hide(prompt)
				end
			end
		end)
	ProximityPromptService.PromptShown:Connect(
		function(prompt: ProximityPrompt, input: Enum.ProximityPromptInputType)
			if prompt.Style == Enum.ProximityPromptStyle.Custom then
				show(prompt, input)
			end
		end
	)
	ProximityPromptService.PromptHidden:Connect(hide)
	restyleAll()
end

return PromptController
