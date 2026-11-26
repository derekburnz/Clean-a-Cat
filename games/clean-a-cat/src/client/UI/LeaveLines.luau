--!strict
-- LeaveLines: two big friendly lines above and below Roblox's own leave screen ("Are you sure you want to leave the
-- game?") while its menu is open (issue 726, Derek's ask of 2026-11-26), behind the switch leaveLines, off by
-- default. Roblox's prompt sits in the middle of the screen, so the lines go in the strips it leaves clear: one along
-- the top edge and one along the bottom. LeaveLineRules picks the words: each is true for this player right now, or
-- left out.
--
--   LeaveLines.build(playerGui, hud)  makes its own ScreenGui once, hidden; `hud` (the game's own ScreenGui) steps
--                                 aside while the lines show, so the top line never sits over the coin counter
--   LeaveLines.set(top, bottom)   the two lines (nil leaves one out)
--   LeaveLines.setShown(on)       shows them while Roblox's menu is open
--
-- It only shows; nothing here is pressable, and it never opens anything by itself.
local Kit = require(script.Parent:WaitForChild("Kit"))

local LeaveLines = {}

local BAND = 0.11 -- of the screen's height for each line
local WIDTH = 0.94 -- of the screen's width
local MAX_TEXT = 72 -- real px
local EDGE = 0.01 -- of the screen's height kept clear above the top line and below the bottom one
-- Bubble Pastel, left to right: pink, lilac, sky, mint, sunny (style guide)
local COLOURS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("FF8FC2")),
	ColorSequenceKeypoint.new(0.25, Color3.fromHex("C39BFF")),
	ColorSequenceKeypoint.new(0.5, Color3.fromHex("7FD0FF")),
	ColorSequenceKeypoint.new(0.75, Color3.fromHex("6FE3B0")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("FFD45C")),
})

type Parts = { gui: ScreenGui, top: TextLabel, bottom: TextLabel, hud: ScreenGui? }

local parts: Parts? = nil
local shown = false
local topText: string? = nil
local bottomText: string? = nil

local function line(name: string, parent: Instance, anchorY: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, anchorY)
	label.Position = UDim2.fromScale(0.5, if anchorY > 0 then 1 - EDGE else EDGE)
	label.Size = UDim2.fromScale(WIDTH, BAND)
	label.Font = Kit.FONT
	label.TextColor3 = Kit.WHITE
	label.TextScaled = true
	label.TextWrapped = false
	label.Text = ""
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 14
	limit.MaxTextSize = MAX_TEXT
	limit.Parent = label
	local tint = Instance.new("UIGradient")
	tint.Color = COLOURS
	tint.Parent = label
	local edge = Instance.new("UIStroke")
	edge.Color = Kit.INK
	edge.Thickness = 4
	edge.LineJoinMode = Enum.LineJoinMode.Round
	edge.Parent = label
	label.Parent = parent
	return label
end

local function redraw()
	local p = parts
	if p == nil then
		return
	end
	p.top.Text = topText or ""
	p.top.Visible = topText ~= nil
	p.bottom.Text = bottomText or ""
	p.bottom.Visible = bottomText ~= nil
	local on = shown and (topText ~= nil or bottomText ~= nil)
	p.gui.Enabled = on
	local hud = p.hud
	if hud then
		hud.Enabled = not on
	end
end

function LeaveLines.set(top: string?, bottom: string?)
	topText, bottomText = top, bottom
	redraw()
end

function LeaveLines.setShown(on: boolean)
	shown = on
	redraw()
end

function LeaveLines.build(playerGui: Instance, hud: ScreenGui?)
	local gui = Instance.new("ScreenGui")
	gui.Name = "LeaveLines"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false -- under Roblox's top bar, whose menu buttons stay pressable
	gui.DisplayOrder = 50 -- over everything of ours
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	local top = line("Top", gui, 0)
	local bottom = line("Bottom", gui, 1)
	gui.Parent = playerGui
	parts = { gui = gui, top = top, bottom = bottom, hud = hud }
	redraw()
end

return LeaveLines
