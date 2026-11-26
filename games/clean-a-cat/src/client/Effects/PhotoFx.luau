--!strict
-- PhotoFx: the photo moment made cinematic (issue 862, switch photoFx, off by default; Derek, 2026-11-26: "have an led
-- flash red a couple times speeding up then flash go off and print a picture out the back after").
--
-- When the player taps Model-Agent's photo camera (switch photoCamera), ScrubController takes the camera away at once
-- while the server pays. This module keeps a look-alike copy standing in its place for the beat, then lets it go:
--
--   0.00 to 0.62 s  a small red light on the camera's top blinks three times, each gap shorter, a soft tick each
--   0.70 s          the flash: a soft white light at the lens and a mild brighten of the screen (never full white),
--                   with the camera's shutter sound
--   0.80 to 1.30 s  a photo card slides out of the back of the camera, then tips and drops, fading by DONE
--
-- Comfort: Reduced Motion or Less sparkle (UI/Comfort) skip the screen brighten; the light at the lens stays soft.
-- It only listens: the copy is made when the camera model leaves within PRESS_WINDOW of a tap, and is dropped at once
-- if the real camera comes back (the server could not pay). AudioController skips the PhotoTaken shutter while a beat
-- plays (PhotoFx.playing), so the shutter sounds once, at the flash.
--
--   PhotoFx.at(t) -> Beat         pure: the beat's state at t seconds
--   PhotoFx.playing() -> boolean  a beat is running now
--   PhotoFx.start(isOn)           binds once; isOn() is read at each tap
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PhotoFx = {}

PhotoFx.CAMERA_NAME = "PhotoCamera" -- ScrubController's copy of CleanACat_Prop_PhotoCamera
PhotoFx.PRESS_WINDOW = 0.4 -- seconds: the camera leaving this soon after a tap is the photo being taken
PhotoFx.BLINKS = { 0, 0.28, 0.48 } :: { number } -- blink starts: each gap shorter (0.28, then 0.2)
PhotoFx.BLINK_ON = 0.12
PhotoFx.FLASH_AT = 0.7
PhotoFx.FLASH_SECONDS = 0.25
PhotoFx.FLASH_LIGHT = 4 -- PointLight brightness at the peak
PhotoFx.SCREEN_PEAK = 0.3 -- the screen brighten at its peak: 1 minus this is the white frame's transparency
PhotoFx.PRINT_AT = 0.8
PhotoFx.PRINT_SECONDS = 0.5
PhotoFx.DROP_SECONDS = 0.35
PhotoFx.DONE = PhotoFx.PRINT_AT + PhotoFx.PRINT_SECONDS + PhotoFx.DROP_SECONDS
PhotoFx.LED = Color3.fromHex("FF3B4E")
PhotoFx.CARD = Vector3.new(1.3, 0.04, 1.5) -- the photo card: width, thickness, length (studs)

export type Beat = {
	led: boolean, -- the red light is lit
	flash: number, -- 0 to 1, the flash's strength
	slide: number, -- 0 to 1, how far the card is out of the back
	drop: number, -- 0 to 1, how far the card has tipped, fallen and faded
}

function PhotoFx.at(t: number): Beat
	local led = false
	for _, start in PhotoFx.BLINKS do
		if t >= start and t < start + PhotoFx.BLINK_ON then
			led = true
		end
	end
	local f = (t - PhotoFx.FLASH_AT) / PhotoFx.FLASH_SECONDS
	local flash = if f < 0 or f >= 1 then 0 else (1 - f) * (1 - f) -- sharp on, soft off
	local s = math.clamp((t - PhotoFx.PRINT_AT) / PhotoFx.PRINT_SECONDS, 0, 1)
	local slide = 1 - (1 - s) * (1 - s) * (1 - s) -- ease out: it whirs out and slows
	local d =
		math.clamp((t - PhotoFx.PRINT_AT - PhotoFx.PRINT_SECONDS) / PhotoFx.DROP_SECONDS, 0, 1)
	return { led = led, flash = flash, slide = slide, drop = d * d }
end

local running = 0

function PhotoFx.playing(): boolean
	return running > 0
end

local function quiet(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function play(source: Model, still: boolean, sameBack: () -> boolean)
	local Client = script.Parent.Parent
	local Audio = require(Client:WaitForChild("Audio")) :: any

	local copy = source:Clone()
	copy.Name = "CleanACat_Fx_PhotoCamera"
	local pivot = copy:GetPivot()
	local box, size = copy:GetBoundingBox()
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			quiet(d :: BasePart)
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	-- the camera's own frame: its front (-Z) is the lens, +Z the back; heights from the bounding box
	local look = pivot.Rotation
	local front = look.LookVector -- ScrubController turns the camera's front (-Z) to the tub: the lens side
	local top = box.Position + Vector3.yAxis * (size.Y / 2)
	local folder = Instance.new("Folder")
	folder.Name = "CleanACat_Fx_Photo"

	local led = Instance.new("Part")
	led.Name = "Led"
	led.Shape = Enum.PartType.Ball
	led.Size = Vector3.new(0.28, 0.28, 0.28)
	led.Material = Enum.Material.Neon
	led.Color = PhotoFx.LED
	led.Transparency = 1
	quiet(led)
	-- Model-Agent's attachments when the model has them (Led on the top, PrintSlot at the back facing out)
	local ledMark = copy:FindFirstChild("Led", true)
	local slotMark = copy:FindFirstChild("PrintSlot", true)
	led.CFrame = if ledMark and ledMark:IsA("Attachment")
		then CFrame.new((ledMark :: Attachment).WorldPosition)
		else CFrame.new(top + front * (size.Z * 0.3) + look.RightVector * (size.X * 0.3))
	led.Parent = folder

	local lensAt = box.Position + front * (size.Z / 2 + 0.1)
	local lens = Instance.new("Part")
	lens.Name = "FlashLight"
	lens.Size = Vector3.new(0.2, 0.2, 0.2)
	lens.Transparency = 1
	quiet(lens)
	lens.CFrame = CFrame.new(lensAt)
	local light = Instance.new("PointLight")
	light.Color = Color3.new(1, 1, 1)
	light.Range = 14
	light.Brightness = 0
	light.Shadows = false
	light.Parent = lens
	lens.Parent = folder

	local card = Instance.new("Part")
	card.Name = "PhotoCard"
	card.Size = PhotoFx.CARD
	card.Color = Color3.fromHex("FFFDF7")
	card.Material = Enum.Material.SmoothPlastic
	card.Transparency = 1
	quiet(card)
	card.Parent = folder
	-- the slot: just under the top at the back, the card lying flat along -front (out of the back)
	local slot = top - Vector3.yAxis * 0.35 - front * (size.Z / 2 - PhotoFx.CARD.Z / 2)
	local outward = -front
	if slotMark and slotMark:IsA("Attachment") then
		local mark = (slotMark :: Attachment).WorldCFrame
		outward = Vector3.new(mark.LookVector.X, 0, mark.LookVector.Z).Unit
		slot = mark.Position - outward * (PhotoFx.CARD.Z / 2)
	end

	local gui: ScreenGui? = nil
	local white: Frame? = nil
	if not still then
		local g = Instance.new("ScreenGui")
		g.Name = "CleanACat_Fx_PhotoFlash"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.DisplayOrder = 40
		local w = Instance.new("Frame")
		w.BorderSizePixel = 0
		w.BackgroundColor3 = Color3.new(1, 1, 1)
		w.BackgroundTransparency = 1
		w.Size = UDim2.fromScale(1, 1)
		w.Active = false
		w.Parent = g
		g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		gui, white = g, w
	end

	copy.Parent = folder
	folder.Parent = Workspace

	running += 1
	local began = os.clock()
	local ticked = 0
	local flashed = false
	local printed = false
	local connection: RBXScriptConnection? = nil
	local function finish()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		folder:Destroy()
		if gui then
			gui:Destroy()
		end
		running -= 1
	end
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - began
		if t >= PhotoFx.DONE or sameBack() then
			finish()
			return
		end
		local frame = PhotoFx.at(t)
		led.Transparency = if frame.led then 0 else 1
		while ticked < #PhotoFx.BLINKS and t >= PhotoFx.BLINKS[ticked + 1] do
			ticked += 1
			Audio.play("uiClick", { pitch = 1.25 + 0.1 * ticked, at = led })
		end
		if not flashed and t >= PhotoFx.FLASH_AT then
			flashed = true
			Audio.play("camera")
		end
		light.Brightness = PhotoFx.FLASH_LIGHT * frame.flash
		if white then
			white.BackgroundTransparency = 1 - PhotoFx.SCREEN_PEAK * frame.flash
		end
		if not printed and t >= PhotoFx.PRINT_AT then
			printed = true
			Audio.play("boxRustle", { pitch = 1.5, at = card })
		end
		if t >= PhotoFx.PRINT_AT then
			local out = PhotoFx.CARD.Z * 0.9 * frame.slide
			local at = slot + outward * out - Vector3.yAxis * (1.6 * frame.drop)
			card.CFrame = CFrame.lookAt(at, at + outward)
				* CFrame.Angles(math.rad(-50 * frame.drop), 0, 0)
			card.Transparency = frame.drop
		end
	end)
end

local started = false

function PhotoFx.start(isOn: () -> boolean)
	if started then
		return
	end
	started = true
	local Comfort = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Comfort")) :: any
	local pressedAt = -math.huge
	UserInputService.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if
			kind == Enum.UserInputType.MouseButton1
			or kind == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			pressedAt = os.clock()
		end
	end)

	local watched: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- a gone visit's camera drops out
	local function watch(d: Instance)
		if d.Name ~= PhotoFx.CAMERA_NAME or not d:IsA("Model") or watched[d :: Model] then
			return
		end
		local model = d :: Model
		watched[model] = true
		local lastParent: Instance? = model.Parent
		local lastPivot = model:GetPivot()
		model.AncestryChanged:Connect(function()
			local parent = model.Parent
			if parent ~= nil then
				lastParent, lastPivot = parent, model:GetPivot()
				return
			end
			if
				lastParent == nil
				or os.clock() - pressedAt > PhotoFx.PRESS_WINDOW
				or not isOn()
				or PhotoFx.playing()
			then
				return
			end
			-- a stand-in where the camera stood; it goes at once if the real one is handed back
			local stand = model:Clone() :: Model
			stand:PivotTo(lastPivot)
			local still = Comfort.reducedMotion() or Comfort.lessSparkle()
			play(stand, still, function()
				return model.Parent ~= nil
			end)
			stand:Destroy()
		end)
	end
	Workspace.DescendantAdded:Connect(watch)
	for _, d in Workspace:GetDescendants() do
		watch(d)
	end
end

return PhotoFx
