--!strict
-- HelperPopup: "+N" with a coin over a helper's stand when they finish a cat (issue 743, Derek 2026-11-26: "a cool
-- little popup above either the workers head or station ... with how much he got"), in place of the "+N coins: NAME
-- washed CAT" toast. Behind the switch helperPopups. Only the owner sees it (the server sends HelperPaid to them
-- alone), nothing is pressable, and two helpers finishing together each get their own over their own stand.
--
--   HelperPopup.show(at, coins, pop?)   at: the world spot over the stand; rises RISE studs and fades over SECONDS.
--                                       pop (switch helperPopFx, issue 801): it first grows from 0.6 to 1.08 and
--                                       settles at 1 within 0.2 s (Effects/Pop), on one UIScale (agreed with
--                                       Design-Agent)
--
-- Reduced Motion (UI/Comfort): it does not rise, it only fades. Phone budget: one BillboardGui of three pieces for
-- SECONDS, then it is destroyed.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Comfort = require(script.Parent:WaitForChild("Comfort"))
local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Pop = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Pop"))

local HelperPopup = {}

HelperPopup.SECONDS = 1.4
HelperPopup.RISE = 1.6 -- studs
HelperPopup.HOLD = 0.45 -- share of SECONDS it stays solid before fading
HelperPopup.FAR = 70 -- studs: not drawn past this
local SIZE = Vector2.new(150, 56) -- px: a fixed screen size, so it reads the same near and far

-- Pure: (rise in studs, transparency) at `t` seconds.
function HelperPopup.at(t: number, reduced: boolean): (number, number)
	local k = math.clamp(t / HelperPopup.SECONDS, 0, 1)
	local eased = 1 - (1 - k) * (1 - k)
	local rise = if reduced then 0 else HelperPopup.RISE * eased
	local fade = if k <= HelperPopup.HOLD
		then 0
		else (k - HelperPopup.HOLD) / (1 - HelperPopup.HOLD)
	return rise, fade
end

function HelperPopup.show(at: Vector3, coins: number, pop: boolean?)
	local anchor = Instance.new("Part")
	anchor.Name = "HelperPopupAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = at

	local gui = Instance.new("BillboardGui")
	gui.Name = "HelperPaid"
	gui.Size = UDim2.fromOffset(SIZE.X, SIZE.Y)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = HelperPopup.FAR
	gui.Adornee = anchor
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.BackgroundTransparency = 1
	coin.Size = UDim2.fromOffset(48, 48) -- model icons never under 48 px
	coin.LayoutOrder = 1
	coin.Parent = row
	Icons.draw("Coins", coin)
	local text = Instance.new("TextLabel")
	text.Name = "Amount"
	text.BackgroundTransparency = 1
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromOffset(0, 44)
	text.LayoutOrder = 2
	text.Font = Kit.FONT
	text.TextSize = 36
	text.TextColor3 = Kit.GOLD_TEXT
	text.Text = `+{coins}`
	local edge = Kit.stroke(text, 3)
	row.Parent = gui
	text.Parent = row
	gui.Parent = anchor
	anchor.Parent = Workspace

	local reduced = Comfort.reducedMotion()
	local scale: UIScale? = nil
	if pop == true and not reduced then
		local made = Instance.new("UIScale")
		made.Scale = Pop.FROM
		made.Parent = row
		scale = made
	end
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t >= HelperPopup.SECONDS or anchor.Parent == nil then
			if connection then
				connection:Disconnect()
			end
			anchor:Destroy()
			return
		end
		local grow = scale
		if grow then
			grow.Scale = Pop.scale(t)
		end
		local rise, fade = HelperPopup.at(t, reduced)
		gui.StudsOffsetWorldSpace = Vector3.new(0, rise, 0)
		text.TextTransparency = fade
		edge.Transparency = fade
		for _, child in coin:GetDescendants() do
			if child:IsA("ImageLabel") then
				(child :: ImageLabel).ImageTransparency = fade
			elseif child:IsA("TextLabel") then
				(child :: TextLabel).TextTransparency = fade
			end
		end
	end)
end

return HelperPopup
