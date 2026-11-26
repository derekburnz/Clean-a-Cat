--!strict
-- ClaimFx: a Free Reward or the gift stand's pet is claimed (issue 802, switch claimFx, off by default). One quiet
-- giftClaim sound and three small Sparkle icons that pop once where the player tapped.
--
-- It waits for the server: it plays when one of the player's claimed attributes turns true (GiftClaimed,
-- FreeLikeClaimed, FreePlayClaimed), and only if the player tapped a step or Get Starcoat on the gift card within
-- PRESS_WINDOW seconds. So a save loading at join never celebrates, and a failed claim stays quiet.
--
--   pop     each star grows from 0.3 to 1.1 with a small turn while it fades in, then shrinks and fades out, over
--           SECONDS, one GAP after the other
--   comfort Reduced Motion or Less sparkle (UI/Comfort): the sound only
--
--   ClaimFx.at(t, i) -> (scale, seen, degrees)   pure: star i (1 to 3) at t seconds; seen 0 is hidden, 1 fully shown
--   ClaimFx.start(ui, isOn)                       binds once; isOn() is read at claim time
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local Audio = require(Client:WaitForChild("Audio"))
local Comfort = require(Client:WaitForChild("UI"):WaitForChild("Comfort"))
local Icons = require(Client:WaitForChild("UI"):WaitForChild("HUD"):WaitForChild("Icons"))

local ClaimFx = {}

ClaimFx.ATTRIBUTES = { "GiftClaimed", "FreeLikeClaimed", "FreePlayClaimed" }
ClaimFx.PRESS_WINDOW = 6
ClaimFx.SECONDS = 0.5
ClaimFx.GAP = 0.08
ClaimFx.SIZE = 28 -- px at full size
ClaimFx.SPOTS = { Vector2.new(-34, -18), Vector2.new(36, -10), Vector2.new(-6, 26) } :: { Vector2 }

function ClaimFx.at(t: number, i: number): (number, number, number)
	local u = (t - (i - 1) * ClaimFx.GAP) / ClaimFx.SECONDS
	if u <= 0 or u >= 1 then
		return 0, 0, 0
	end
	if u < 0.4 then
		local k = u / 0.4
		return 0.3 + 0.8 * k, k, 20 * k
	end
	local k = (u - 0.4) / 0.6
	return 1.1 - 0.5 * k, 1 - k, 20
end

function ClaimFx.total(): number
	return ClaimFx.SECONDS + (#ClaimFx.SPOTS - 1) * ClaimFx.GAP
end

local function sparkle(at: Vector2)
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "CleanACat_Fx_ClaimSparkle"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = false -- InputObject positions are below the top bar inset
	local stars: { ImageLabel } = {}
	for i, offset in ClaimFx.SPOTS do
		local star = Instance.new("ImageLabel")
		star.Name = "Sparkle" .. i
		star.BackgroundTransparency = 1
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromOffset(at.X + offset.X, at.Y + offset.Y)
		star.Size = UDim2.fromOffset(0, 0)
		star.ScaleType = Enum.ScaleType.Fit
		star.Image = Icons.IMAGES.Sparkle
		star.ImageTransparency = 1
		star.Parent = gui
		stars[i] = star
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	local began = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if t >= ClaimFx.total() or gui.Parent == nil then
			if connection then
				connection:Disconnect()
				connection = nil
			end
			gui:Destroy()
			return
		end
		for i, star in stars do
			local scale, seen, degrees = ClaimFx.at(t, i)
			local px = math.floor(ClaimFx.SIZE * scale + 0.5)
			star.Size = UDim2.fromOffset(px, px)
			star.ImageTransparency = 1 - seen
			star.Rotation = degrees
		end
	end)
end

local started = false

function ClaimFx.start(ui: any, isOn: () -> boolean)
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local pressedAt = -math.huge
	local pressSpot: Vector2? = nil
	local pointer: Vector2? = nil
	UserInputService.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			pointer = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	local function pressed()
		pressedAt = os.clock()
		pressSpot = pointer
	end
	ui.onGiftStep(pressed)
	ui.onGiftClaim(pressed)

	for _, name in ClaimFx.ATTRIBUTES do
		local was = player:GetAttribute(name) == true
		player:GetAttributeChangedSignal(name):Connect(function()
			local now = player:GetAttribute(name) == true
			local turnedOn = now and not was
			was = now
			if not turnedOn or not isOn() or os.clock() - pressedAt > ClaimFx.PRESS_WINDOW then
				return
			end
			pressedAt = -math.huge
			Audio.play("giftClaim")
			local spot = pressSpot
			if spot and not Comfort.reducedMotion() and not Comfort.lessSparkle() then
				sparkle(spot)
			end
		end)
	end
end

return ClaimFx
