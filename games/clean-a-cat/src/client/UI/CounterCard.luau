--!strict
-- CounterCard: the small card over a cat waiting on the counter (issue 745 part 2, switch counterCards; the rules and
-- why are in shared/CounterCardRules). A round chip in the owner's shirt colour, then the heart bar with a heart at
-- its start. A fixed screen size (CounterCardRules.SIZE), so it reads on a phone, with every second place's card a row
-- up so neighbours never cover each other; drawn on top, but only within CounterCardRules.FAR. Nothing on it is pressable: the Take prompt on the cat is the tap.
--
--   local card = CounterCard.new(adornee, parent)
--   card.set(fill, shirt)   fill 0 to 1 (nil hides the bar), shirt the owner's colour (nil leaves the chip cream)
--   card.place(place)      its counter place, for its row
--   card.destroy()
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CounterCardRules =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CounterCardRules"))

local Icons = require(script.Parent:WaitForChild("HUD"):WaitForChild("Icons"))
local Kit = require(script.Parent:WaitForChild("Kit"))

local CounterCard = {}

export type Card = {
	set: (fill: number?, shirt: Color3?) -> (),
	place: (place: unknown) -> (), -- its counter place: every second card sits a row up
	destroy: () -> (),
}

function CounterCard.new(adornee: BasePart, parent: Instance): Card
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

	gui.Parent = parent

	local card = {}
	function card.set(fill: number?, shirt: Color3?)
		chip.BackgroundColor3 = shirt or Kit.CREAM
		track.Visible = fill ~= nil
		if fill then
			fillFrame.Size = UDim2.fromScale(fill, 1)
			fillFrame.Visible = fill > 0
			fillFrame.BackgroundColor3 = CounterCardRules.barColor(fill)
		end
	end
	function card.place(place: unknown)
		gui.StudsOffsetWorldSpace = Vector3.new(0, CounterCardRules.up(place), 0)
	end
	function card.destroy()
		gui:Destroy()
	end
	return card
end

return CounterCard
