--!strict
-- Arrive: a menu button that has just unlocked arrives with a small motion (issue #528: "menu buttons get a small
-- arrive motion when each unlocks"), so the player sees something new is there without anything stopping play.
--
--   pop      the button grows from 0 to POP_OVER and settles at its own size over POP_SECONDS (a soft back-out)
--   tilt     a small wobble of TILT degrees that dies away with the pop
--   shine    one small gold twinkle at its top right corner pops in and out (the same star as Attention)
--   comfort  Reduced Motion or Less sparkle (UI/Comfort): the button simply shows; nothing moves
--
-- It plays once per call; the caller (the HUD's side buttons) calls it the first time each button unlocks, never on
-- every visit. Client only and cosmetic; it lets go of the frame loop when done or when the button goes.
--
-- API
--   Arrive.play(button)                 plays it; a second call while one plays restarts it
--   Arrive.at(t) -> (scale, degrees, shine)   pure: the button's scale, its tilt and the twinkle's size (0 to 1) at
--                                       `t` seconds
--   Arrive.LENGTH                       seconds until it is all over
local RunService = game:GetService("RunService")

local Comfort = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Comfort"))

local Arrive = {}

Arrive.POP_SECONDS = 0.45
Arrive.POP_OVER = 1.12
Arrive.TILT = 6
Arrive.SHINE_FROM = 0.25
Arrive.SHINE_SECONDS = 0.5
Arrive.LENGTH = math.max(Arrive.POP_SECONDS, Arrive.SHINE_FROM + Arrive.SHINE_SECONDS)
local GOLD = Color3.fromRGB(255, 226, 120)

-- A back-out ease that peaks near POP_OVER and settles at 1.
local function backOut(u: number): number
	local c = 2.2
	local v = u - 1
	return 1 + (c + 1) * v * v * v + c * v * v
end

function Arrive.at(t: number): (number, number, number)
	local scale = 1
	local degrees = 0
	if t < 0 then
		return 0, 0, 0
	end
	if t < Arrive.POP_SECONDS then
		local u = t / Arrive.POP_SECONDS
		scale = math.min(backOut(u), Arrive.POP_OVER)
		degrees = Arrive.TILT * math.sin(u * 3 * math.pi) * (1 - u)
	end
	local shine = 0
	local s = (t - Arrive.SHINE_FROM) / Arrive.SHINE_SECONDS
	if s > 0 and s < 1 then
		shine = math.sin(math.pi * s)
	end
	return scale, degrees, shine
end

local playing: { [GuiObject]: () -> () } = {}

local function makeShine(button: GuiObject): Frame
	local holder = Instance.new("Frame")
	holder.Name = "ArriveShine"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.92, 0.1)
	holder.Size = UDim2.fromScale(0, 0)
	holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	holder.ZIndex = button.ZIndex + 2
	holder.Rotation = 45 -- turned so it reads as a twinkle, not a plus
	for b = 1, 2 do
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = GOLD
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = if b == 1 then UDim2.fromScale(0.2, 1) else UDim2.fromScale(1, 0.2)
		bar.ZIndex = holder.ZIndex
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = bar
		bar.Parent = holder
	end
	holder.Parent = button
	return holder
end

function Arrive.play(button: GuiObject)
	local previous = playing[button]
	if previous then
		previous()
	end
	if Comfort.reducedMotion() or Comfort.lessSparkle() then
		return
	end
	local made = false
	local found = button:FindFirstChildOfClass("UIScale")
	local uiScale: UIScale
	if found then
		uiScale = found :: UIScale
	else
		uiScale = Instance.new("UIScale")
		uiScale.Name = "ArriveScale"
		uiScale.Parent = button
		made = true
	end
	local base = uiScale.Scale
	local baseRotation = button.Rotation
	local shine = makeShine(button)
	local start = os.clock()
	local connection: RBXScriptConnection? = nil
	local function finish()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		playing[button] = nil
		shine:Destroy()
		if button.Parent then
			button.Rotation = baseRotation
			if made then
				uiScale:Destroy()
			else
				uiScale.Scale = base
			end
		end
	end
	playing[button] = finish
	local function frame()
		local t = os.clock() - start
		if t >= Arrive.LENGTH or button.Parent == nil then
			finish()
			return
		end
		local scale, degrees, size = Arrive.at(t)
		uiScale.Scale = base * math.max(scale, 0.01)
		button.Rotation = baseRotation + degrees
		shine.Size = UDim2.fromScale(0.36 * size, 0.36 * size)
	end
	connection = RunService.RenderStepped:Connect(frame)
	frame()
end

return Arrive
