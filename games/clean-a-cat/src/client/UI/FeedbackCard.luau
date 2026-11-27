--!strict
-- FeedbackCard: "Send feedback" from Settings (issue 1081, switch feedback; Derek 2026-11-27: "add a feedback option in
-- settings"). Opened only from its Settings button, never by itself.
--
--   FeedbackCard.build(root)   makes the window once and returns its layer ("Feedback")
--   FeedbackCard.reset()       clears the pick and the note (each time Settings opens it)
--   FeedbackCard.onSend(fn)    fn(choice, note) when Send is pressed: choice one of FeedbackRules.CHOICES, note "" or text
--
-- Four big tap choices in two rows (WORDS), an optional note of at most FeedbackRules.NOTE_MAX characters, and Send,
-- which lights up once a choice is picked. Send closes the window; the server filters the note and shows the thank
-- you itself (FeedbackRules.THANKS), so nothing here says thanks twice. UI never fires remotes: FeedbackController
-- asks the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeedbackRules = require(Shared:WaitForChild("FeedbackRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local Kit = require(script.Parent:WaitForChild("Kit"))
local Window = require(script.Parent:WaitForChild("Window"))

local FeedbackCard = {}

FeedbackCard.WINDOW = "Feedback"
FeedbackCard.TITLE = "Send feedback"
FeedbackCard.HINT = "Tell us more (optional)"
-- Design-Agent's words for FeedbackRules.CHOICES, in that order.
FeedbackCard.WORDS = table.freeze({
	love = "I love it",
	hard = "Something is hard",
	bug = "I found a bug",
	idea = "I have an idea",
}) :: { [string]: string }

local GREEN_TOP, GREEN_BOTTOM = Color3.fromHex("7BE85A"), Color3.fromHex("3DBF3F")
local GREY_TOP, GREY_BOTTOM = Color3.fromHex("D9D2E3"), Color3.fromHex("BEB4CC")
local PICKED = Color3.fromHex("FFE98F")
local SCREEN_MARGIN = 64
local SHORT_SHIFT = -40 -- design px above the middle on a short screen: the phone's keyboard comes up from below
local MIN_TAP = 44 -- real px

local SIZES = {
	full = {
		width = 600,
		band = 72,
		title = 34,
		badge = 96,
		pad = 20,
		choice = 64,
		choiceText = 24,
		box = 88,
		boxText = 22,
		button = 60,
		text = 24,
	},
	short = {
		width = 560,
		band = 56,
		title = 28,
		badge = 80,
		pad = 12,
		choice = 58,
		choiceText = 21,
		box = 64,
		boxText = 20,
		button = 54,
		text = 21,
	},
}
type Sizes = typeof(SIZES.full)

type Parts = {
	window: Window.Window,
	pad: UIPadding,
	grid: Frame,
	choices: { [string]: TextButton },
	box: TextBox,
	send: TextButton,
}

local parts: Parts? = nil
local picked: string? = nil
local sendListeners: { (choice: string, note: string) -> () } = {}

local function screenWidth(scale: number): number
	local camera = Workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	return width / scale
end

local function redraw()
	local p = parts
	if p == nil then
		return
	end
	local scale, short = Kit.screenScale()
	local s: Sizes = if short then SIZES.short else SIZES.full
	local width = math.min(s.width, screenWidth(scale) - SCREEN_MARGIN)
	Window.fit(p.window, width, s.band, s.title, s.badge, if short then SHORT_SHIFT else nil)
	local pad = UDim.new(0, s.pad)
	p.pad.PaddingLeft, p.pad.PaddingRight, p.pad.PaddingTop, p.pad.PaddingBottom =
		pad, pad, UDim.new(0, s.pad + 2), pad
	local tap = math.ceil(MIN_TAP / scale)
	local rowHeight = math.max(s.choice, tap)
	p.grid.Size = UDim2.new(1, 0, 0, rowHeight * 2 + 10)
	for index, id in FeedbackRules.CHOICES do
		local button = p.choices[id]
		if button then
			local column = (index - 1) % 2
			local row = (index - 1) // 2
			button.Size = UDim2.new(0.5, -5, 0, rowHeight)
			button.Position = UDim2.new(column * 0.5, column * 5, 0, row * (rowHeight + 10))
			button.TextSize = s.choiceText
			button.BackgroundColor3 = if picked == id then PICKED else Kit.WHITE
			local edge = button:FindFirstChildOfClass("UIStroke") :: UIStroke?
			if edge then
				edge.Thickness = if picked == id then 4 else 3
				edge.Color = if picked == id then Kit.GOLD_INK else Kit.INK
			end
		end
	end
	p.box.Size = UDim2.new(1, 0, 0, math.max(s.box, tap))
	p.box.TextSize = s.boxText
	p.send.Size = UDim2.new(1, 0, 0, math.max(s.button, tap))
	p.send.TextSize = s.text
	local gradient = p.send:FindFirstChildOfClass("UIGradient") :: UIGradient?
	if gradient then
		gradient.Color = if picked
			then ColorSequence.new(GREEN_TOP, GREEN_BOTTOM)
			else ColorSequence.new(GREY_TOP, GREY_BOTTOM)
	end
	p.send.Active = picked ~= nil
	p.send.AutoButtonColor = picked ~= nil
end

-- Keeps the note to NOTE_MAX characters (bytes, as the server counts) without splitting a letter.
local function tidy(box: TextBox)
	local text = box.Text
	if #text <= FeedbackRules.NOTE_MAX then
		return
	end
	local cut = string.sub(text, 1, FeedbackRules.NOTE_MAX)
	while #cut > 0 and utf8.len(cut) == nil do
		cut = string.sub(cut, 1, #cut - 1)
	end
	box.Text = cut
end

function FeedbackCard.reset()
	picked = nil
	local p = parts
	if p then
		p.box.Text = ""
	end
	redraw()
end

function FeedbackCard.picked(): string?
	return picked
end

function FeedbackCard.pick(id: string)
	if FeedbackCard.WORDS[id] then
		picked = id
		redraw()
	end
end

function FeedbackCard.onSend(fn: (choice: string, note: string) -> ())
	table.insert(sendListeners, fn)
end

local function send()
	local p = parts
	local choice = picked
	if p == nil or choice == nil then
		return
	end
	local note = p.box.Text
	p.window.layer.Visible = false
	for _, listener in sendListeners do
		task.spawn(listener, choice, note)
	end
	FeedbackCard.reset()
end

function FeedbackCard.build(root: Instance): Frame
	local window = Window.new(FeedbackCard.WINDOW, FeedbackCard.TITLE, "Heart", root)
	window.close.Activated:Connect(function()
		window.layer.Visible = false
	end)

	local pad = Instance.new("UIPadding")
	pad.Name = "Pad"
	pad.Parent = window.body
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, 12)
	stack.Parent = window.body

	local grid = Instance.new("Frame")
	grid.Name = "Choices"
	grid.LayoutOrder = 1
	grid.BackgroundTransparency = 1
	grid.Parent = window.body
	local choices: { [string]: TextButton } = {}
	for _, id in FeedbackRules.CHOICES do
		local button = Instance.new("TextButton")
		button.Name = `Choice_{id}`
		button.AutoButtonColor = true
		button.BackgroundColor3 = Kit.WHITE
		button.Font = Kit.FONT
		button.TextColor3 = Kit.INK
		button.Text = FeedbackCard.WORDS[id] or id
		button.TextWrapped = true
		Kit.minText(button)
		Kit.corner(button, UDim.new(0, 16))
		local edge = Kit.stroke(button, 3)
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		button.Parent = grid
		button.Activated:Connect(function()
			FeedbackCard.pick(id)
		end)
		choices[id] = button
	end

	local box = Instance.new("TextBox")
	box.Name = "Note"
	box.LayoutOrder = 2
	box.ClearTextOnFocus = false
	box.MultiLine = true
	box.TextWrapped = true
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.FontFace = Kit.BODY_FACE
	box.TextColor3 = Kit.INK
	box.PlaceholderText = FeedbackCard.HINT
	box.PlaceholderColor3 = Kit.INK_SOFT
	box.BackgroundColor3 = Kit.WHITE
	box.Text = ""
	Kit.corner(box, UDim.new(0, 14))
	local boxEdge = Kit.stroke(box, 3)
	boxEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local boxPad = Instance.new("UIPadding")
	boxPad.PaddingLeft, boxPad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	boxPad.PaddingTop, boxPad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	boxPad.Parent = box
	box.Parent = window.body
	box:GetPropertyChangedSignal("Text"):Connect(function()
		tidy(box)
	end)

	local sendButton = Window.button("Send", "Send", window.body, GREY_TOP, GREY_BOTTOM)
	sendButton.LayoutOrder = 3
	sendButton.Activated:Connect(function()
		send()
	end)

	parts = {
		window = window,
		pad = pad,
		grid = grid,
		choices = choices,
		box = box,
		send = sendButton,
	}
	window.layer:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.layer.Visible then
			redraw()
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FeedbackRules.FLAG)
		:Connect(function()
			if not LiveFlags.isOn(FeedbackRules.FLAG) then
				window.layer.Visible = false
			end
		end)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(redraw)
	end
	redraw()
	return window.layer
end

return FeedbackCard
