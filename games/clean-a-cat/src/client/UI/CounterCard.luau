--!strict
-- CounterCard: the small card over a cat waiting on the counter (issue 745 part 2, switch counterCards; the rules and
-- why are in shared/CounterCardRules). A round chip in the owner's shirt colour, then the heart bar with a heart at
-- its start. A fixed screen size (CounterCardRules.SIZE), so it reads on a phone, with every second place's card a row
-- up so neighbours never cover each other; drawn on top, but only within CounterCardRules.FAR. Nothing on it is pressable: the Take prompt on the cat is the tap.
--
--   local card = CounterCard.new(adornee, parent, motion?)
--     motion (switch counterCardFx, issue 803, agreed with Design-Agent): "grow" for a cat's first card (it grows
--     from 0.7 to 1 and fades in over 0.2 s), "ease" for a redrawn card (it shows at once); with either, the heart bar eases
--     to each new fill over EASE seconds and destroy() fades out over FADE seconds. Reduced Motion: no grow and no
--     easing, only the fades. nil is the old card, exactly as before.
--   card.set(fill, shirt)   fill 0 to 1 (nil hides the bar), shirt the owner's colour (nil leaves the chip cream)
--   card.place(place)      its counter place, for its row
--   card.destroy()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CounterCardRules =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CounterCardRules"))

local Comfort = require(script.Parent:WaitForChild("Comfort"))
local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))
local Pop = require(script.Parent.Parent:WaitForChild("Effects"):WaitForChild("Pop"))

local CounterCard = {}

CounterCard.GROW_FROM = 0.7
CounterCard.FADE = 0.2 -- seconds, in and out
CounterCard.EASE = 0.25 -- seconds for the heart bar to reach a new fill

export type Motion = "grow" | "ease"

-- Every transparency on the card, with its own value, so a fade multiplies towards it and puts it back exactly.
type Seen = { object: Instance, property: string, base: number }

local function seenList(gui: Instance): { Seen }
	local list: { Seen } = {}
	for _, d in gui:GetDescendants() do
		if d:IsA("GuiObject") then
			table.insert(list, {
				object = d :: Instance,
				property = "BackgroundTransparency",
				base = d.BackgroundTransparency,
			})
			if d:IsA("ImageLabel") then
				table.insert(list, {
					object = d :: Instance,
					property = "ImageTransparency",
					base = d.ImageTransparency,
				})
			elseif d:IsA("TextLabel") then
				table.insert(list, {
					object = d :: Instance,
					property = "TextTransparency",
					base = d.TextTransparency,
				})
			end
		elseif d:IsA("UIStroke") then
			table.insert(
				list,
				{ object = d :: Instance, property = "Transparency", base = d.Transparency }
			)
		end
	end
	return list
end

-- seen 0 is hidden, 1 is the card's own look.
local function applySeen(list: { Seen }, seen: number)
	for _, entry in list do
		(entry.object :: any)[entry.property] = 1 - (1 - entry.base) * seen
	end
end

-- Steps `fn(t)` each frame for `seconds`, then calls `done`; never runs once settled.
local function run(seconds: number, fn: (number) -> (), done: (() -> ())?)
	local began = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		fn(math.min(t, seconds))
		if t >= seconds then
			if connection then
				connection:Disconnect()
				connection = nil
			end
			if done then
				done()
			end
		end
	end)
end

export type Card = {
	set: (fill: number?, shirt: Color3?) -> (),
	place: (place: unknown) -> (), -- its counter place: every second card sits a row up
	destroy: () -> (),
}

function CounterCard.new(adornee: BasePart, parent: Instance, motion: Motion?): Card
	local gui = Instance.new("BillboardGui")
	gui.Name = "CounterCard"
	gui.Size = UDim2.fromOffset(CounterCardRules.SIZE.X, CounterCardRules.SIZE.Y) -- px, the same near and far
	gui.StudsOffsetWorldSpace = Vector3.new(0, CounterCardRules.UP, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = CounterCardRules.FAR
	gui.ResetOnSpawn = false
	gui.Adornee = adornee

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = gui

	-- The owner's chip: a round dot in their shirt colour, as on the person standing right behind.
	local chip = Instance.new("Frame")
	chip.Name = "Owner"
	chip.AnchorPoint = Vector2.new(0, 0.5)
	chip.Position = UDim2.fromScale(0, 0.5)
	chip.Size = UDim2.fromScale(1, 1)
	chip.SizeConstraint = Enum.SizeConstraint.RelativeYY
	chip.BackgroundColor3 = Kit.CREAM
	Kit.corner(chip, UDim.new(0.5, 0))
	Kit.stroke(chip, 2)
	chip.Parent = row

	-- The heart bar: a cream track with an ink edge, the fill inside, a heart at its start.
	local track = Instance.new("Frame")
	track.Name = "Heart"
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.fromScale(1, 0.5)
	track.Size = UDim2.fromScale(0.56, 0.62) -- leaves room for the heart between the chip and the bar
	track.BackgroundColor3 = Kit.CREAM
	Kit.corner(track, UDim.new(0.5, 0))
	Kit.stroke(track, 2)
	track.Parent = row
	local fillFrame = Instance.new("Frame")
	fillFrame.Name = "Fill"
	fillFrame.BorderSizePixel = 0
	fillFrame.Size = UDim2.fromScale(1, 1)
	fillFrame.BackgroundColor3 = CounterCardRules.FULL
	Kit.corner(fillFrame, UDim.new(0.5, 0))
	fillFrame.Parent = track
	local heart = Instance.new("Frame")
	heart.Name = "HeartIcon"
	heart.BackgroundTransparency = 1
	heart.AnchorPoint = Vector2.new(0.5, 0.5)
	heart.Position = UDim2.fromScale(0, 0.5)
	heart.Size = UDim2.fromScale(1.5, 1.5)
	heart.SizeConstraint = Enum.SizeConstraint.RelativeYY
	heart.ZIndex = 2
	heart.Parent = track
	Icons.draw("Heart", heart)

	local reduced = Comfort.reducedMotion()
	local seen: { Seen }? = if motion then seenList(gui) else nil
	if seen and motion == "grow" then -- a redrawn card ("ease") shows at once: only a cat's first card arrives
		applySeen(seen, 0)
		local scale: UIScale? = nil
		if motion == "grow" and not reduced then
			local made = Instance.new("UIScale")
			made.Scale = CounterCard.GROW_FROM
			made.Parent = row
			scale = made
		end
		local list = seen
		run(CounterCard.FADE, function(t: number)
			if gui.Parent == nil then
				return
			end
			applySeen(list, t / CounterCard.FADE)
			local grow = scale
			if grow then
				-- the shared pop's curve, from 0.7 and without the overshoot: a card is not a pay moment
				grow.Scale = Pop.scale(t * Pop.SECONDS / CounterCard.FADE, CounterCard.GROW_FROM, 1)
			end
		end, function()
			local grow = scale
			if grow then
				grow:Destroy()
			end
		end)
	end
	gui.Parent = parent

	local card = {}
	local drawn = false
	local easing: Tween? = nil
	function card.set(fill: number?, shirt: Color3?)
		chip.BackgroundColor3 = shirt or Kit.CREAM
		track.Visible = fill ~= nil
		if fill then
			local size = UDim2.fromScale(fill, 1)
			local old = easing
			if old then
				old:Cancel()
				easing = nil
			end
			if motion and drawn and not reduced then
				local tween = TweenService:Create(
					fillFrame,
					TweenInfo.new(CounterCard.EASE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = size }
				)
				easing = tween
				tween:Play()
			else
				fillFrame.Size = size
			end
			fillFrame.Visible = fill > 0
			fillFrame.BackgroundColor3 = CounterCardRules.barColor(fill)
			drawn = true
		end
	end
	function card.place(place: unknown)
		gui.StudsOffsetWorldSpace = Vector3.new(0, CounterCardRules.up(place), 0)
	end
	local gone = false
	function card.destroy()
		if gone then
			return
		end
		gone = true
		local old = easing
		if old then
			old:Cancel()
			easing = nil
		end
		local list = seen
		if list == nil or gui.Parent == nil then
			gui:Destroy()
			return
		end
		run(CounterCard.FADE, function(t: number)
			if gui.Parent then
				applySeen(list, 1 - t / CounterCard.FADE)
			end
		end, function()
			gui:Destroy()
		end)
	end
	return card
end

return CounterCard
