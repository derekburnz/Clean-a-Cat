--!strict
-- GiftStand: the gift stand's light (issue #528: "gift stand glow from about minute 7"). Model-Agent's
-- CleanACat_Prop_GiftStand (PR 645) sits in each plot's Props as "GiftStand"; GiftService (#521) sets the stand's
-- Lit attribute at 7:00 of the owner's play. While Lit is true this makes it read as something waiting for you,
-- warm and calm, never flashing:
--
--   lamp      the small gold ball on top (part Lamp) turns Neon in its own deep gold (the style guide's Neon rule:
--             saturated colour only, a pale Neon clips to white), and a soft warm PointLight on it breathes slowly
--   sparkle   now and then (SPARKLE_EVERY) a small gold sparkle at the pet on the cushion (attachment Glow)
--   lights    when Lit turns true while you watch, the light swells brighter for a moment with one sparkle burst
--   balloon   if the stand has a child Model ending _Balloon (pivoted at the knot), it sways gently
--   beacon    on your own stand only, until its pet is yours (Player attribute GiftClaimed): the HUD's Sparkle icon
--             in gold floats over the balloon at a fixed BEACON_PX on screen, breathing with the light and turning
--             a little, so the lit stand reads from the spawn and the tub on a phone (#659: the lamp alone is 3 px)
--   comfort   Reduced Motion: the light holds steady and the balloon stays still. Less sparkle: half as many sparkles
--
-- Client only and cosmetic. Phone budget: one PointLight per lit stand, a frame loop only while a lit stand is
-- within FAR studs of the camera. When Lit goes false the lamp is put back exactly as the model had it.
--
-- API
--   GiftStand.start()                      watches the stands in Workspace
--   GiftStand.pulseAt(t) -> number         pure: the lamp's warmth (0 to 1) at `t` seconds
--   GiftStand.flashAt(t) -> number         pure: the extra glow (0 to 1) `t` seconds after it lit
--   GiftStand.swayAt(t, seed) -> (number, number)   pure: the balloon's lean (radians about X and Z)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Effects = require(script.Parent)
local Icons =
	require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HUD"):WaitForChild("Icons"))

local GiftStand = {}

-- GiftRules.STAND_NAME and STAND_ASSET (copied, so the specs load this without the shared rules)
local NAMES: { [string]: boolean } = { GiftStand = true, CleanACat_Prop_GiftStand = true }
GiftStand.NAMES = table.freeze(NAMES)
GiftStand.PULSE_SECONDS = 2.8 -- one slow breath
GiftStand.FLASH_SECONDS = 0.9
GiftStand.SPARKLE_EVERY = 4.5
GiftStand.SWAY = math.rad(4)
GiftStand.SWAY_SECONDS = 3.4
GiftStand.FAR = 60
GiftStand.LIGHT_RANGE = 9
GiftStand.LIGHT_BRIGHTNESS = 1.1
GiftStand.BEACON_PX = 34 -- the beacon's size on screen, whatever the distance
GiftStand.BEACON_OVER = 0.8 -- studs over the top of the balloon (or the stand)
GiftStand.BEACON_FAR = 90
GiftStand.BEACON_TURN = 8 -- degrees each way
-- GiftRules.CLAIMED_ATTRIBUTE and SpaLayout's plots folder and slot attribute (copied, as NAMES)
local CLAIMED = "GiftClaimed"
local PLOTS = "SpaPlots"
local SLOT = "SpaPlot"
local WARM = Color3.fromRGB(255, 214, 150) -- the light's colour; the lamp keeps its own deep gold
local GOLD = Color3.fromRGB(255, 214, 120)

function GiftStand.pulseAt(t: number): number
	return 0.5 - 0.5 * math.cos(2 * math.pi * t / GiftStand.PULSE_SECONDS)
end

function GiftStand.flashAt(t: number): number
	if t <= 0 or t >= GiftStand.FLASH_SECONDS then
		return 0
	end
	local u = t / GiftStand.FLASH_SECONDS
	return math.sin(math.pi * u) * (1 - u * 0.5)
end

-- The beacon's scale and turn (degrees) at `t` seconds: it breathes with the light. Still under Reduced Motion.
function GiftStand.beaconAt(t: number, still: boolean): (number, number)
	if still then
		return 1, 0
	end
	local warm = GiftStand.pulseAt(t)
	return 0.9 + 0.2 * warm,
		GiftStand.BEACON_TURN * math.sin(2 * math.pi * t / (GiftStand.PULSE_SECONDS * 2))
end

function GiftStand.swayAt(t: number, seed: number): (number, number)
	local w = 2 * math.pi / GiftStand.SWAY_SECONDS
	return GiftStand.SWAY * math.sin(w * t + seed * 6.283),
		GiftStand.SWAY * 0.6 * math.sin(w * 0.73 * t + seed * 2.1)
end

type Stand = {
	model: Model,
	lamp: BasePart?,
	material: Enum.Material?,
	color: Color3?,
	light: PointLight?,
	glow: Attachment?,
	balloon: Model?,
	balloonRest: CFrame?,
	beacon: BillboardGui?,
	beaconIcon: ImageLabel?,
	litAt: number,
	flashFrom: number?,
	nextSparkle: number,
	seed: number,
}

local stands: { [Model]: Stand } = {}
local lit: { [Model]: Stand } = {}
local stepping: RBXScriptConnection? = nil
local seedCount = 0

local function find(model: Model, name: string, class: string): Instance?
	local found = model:FindFirstChild(name, true)
	return if found and found:IsA(class) then found else nil
end

local function balloonOf(model: Model): Model?
	for _, child in model:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, -#"_Balloon") == "_Balloon" then
			return child :: Model
		end
	end
	return nil
end

local function putBack(stand: Stand)
	local lamp = stand.lamp
	if lamp and stand.material and stand.color then
		lamp.Material = stand.material :: Enum.Material
		lamp.Color = stand.color :: Color3
	end
	if stand.light then
		stand.light:Destroy()
		stand.light = nil
	end
	if stand.beacon then
		stand.beacon:Destroy()
		stand.beacon = nil
		stand.beaconIcon = nil
	end
	local balloon, rest = stand.balloon, stand.balloonRest
	if balloon and rest and balloon.Parent then
		balloon:PivotTo(stand.model:GetPivot() * rest)
	end
end

local function step()
	local camera = Workspace.CurrentCamera
	local from = if camera then camera.CFrame.Position else nil
	local now = os.clock()
	local still = Effects.reducedMotion()
	local every = if Effects.lessSparkle()
		then GiftStand.SPARKLE_EVERY * 2
		else GiftStand.SPARKLE_EVERY
	for model, stand in lit do
		if model.Parent == nil then
			lit[model] = nil
			continue
		end
		local lamp = stand.lamp
		local where = if lamp then lamp.Position else model:GetPivot().Position
		local near = from == nil or (where - from).Magnitude <= GiftStand.FAR
		if stand.light then
			stand.light.Enabled = near
		end
		if not near then
			continue
		end
		local flashFrom = stand.flashFrom
		local flash = if flashFrom then GiftStand.flashAt(now - flashFrom) else 0
		if stand.light then
			local warm = if still then 0.6 else GiftStand.pulseAt(now - stand.litAt)
			stand.light.Brightness = GiftStand.LIGHT_BRIGHTNESS * (0.75 + 0.25 * warm + 1.2 * flash)
		end
		if now >= stand.nextSparkle then
			stand.nextSparkle = now + every
			local glow = stand.glow
			if glow then
				Effects.burst("revealSparkle", glow.WorldPosition, GOLD)
			end
		end
		local icon = stand.beaconIcon
		if icon then
			local scale, turn = GiftStand.beaconAt(now - stand.litAt, still)
			local px = GiftStand.BEACON_PX * (scale + 0.4 * flash)
			icon.Size = UDim2.fromOffset(px, px)
			icon.Rotation = turn
		end
		local balloon, rest = stand.balloon, stand.balloonRest
		if balloon and rest and balloon.Parent and not still then
			local x, z = GiftStand.swayAt(now, stand.seed)
			balloon:PivotTo(model:GetPivot() * rest * CFrame.Angles(x, 0, z))
		end
	end
	if next(lit) == nil and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

-- Whether `model` stands in the local player's own plot.
local function mine(model: Model): boolean
	local player = Players.LocalPlayer
	local slot = if player then player:GetAttribute(SLOT) else nil
	local plots = Workspace:FindFirstChild(PLOTS)
	local plot = if plots and slot ~= nil
		then plots:FindFirstChild("Plot" .. tostring(slot))
		else nil
	return plot ~= nil and model:IsDescendantOf(plot)
end

local function claimed(): boolean
	local player = Players.LocalPlayer
	return player ~= nil and player:GetAttribute(CLAIMED) == true
end

local function makeBeacon(stand: Stand)
	if claimed() then
		return
	end
	local model = stand.model
	local top = stand.balloon or model
	local box, size = top:GetBoundingBox()
	local adornee = stand.lamp
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
	if adornee == nil then
		return
	end
	local part = adornee :: BasePart
	local gui = Instance.new("BillboardGui")
	gui.Name = "CleanACat_Fx_GiftBeacon"
	-- offset pixels, so it is the same size on screen from the spawn, the tub or across the room
	gui.Size = UDim2.fromOffset(GiftStand.BEACON_PX * 1.6, GiftStand.BEACON_PX * 1.6)
	gui.StudsOffsetWorldSpace =
		Vector3.new(0, (box.Position.Y + size.Y / 2) - part.Position.Y + GiftStand.BEACON_OVER, 0)
	gui.MaxDistance = GiftStand.BEACON_FAR
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.Adornee = part
	local icon = Instance.new("ImageLabel")
	icon.Name = "Sparkle"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(GiftStand.BEACON_PX, GiftStand.BEACON_PX)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = Icons.IMAGES.Sparkle -- the HUD's own Sparkle (never crossed bars: Review-QA on #553)
	icon.ImageColor3 = GOLD
	icon.Parent = gui
	gui.Parent = part
	stand.beacon = gui
	stand.beaconIcon = icon
end

local function setLit(stand: Stand, on: boolean, live: boolean)
	local model = stand.model
	if not on then
		if lit[model] then
			lit[model] = nil
			putBack(stand)
		end
		return
	end
	if lit[model] then
		return
	end
	local lamp = find(model, "Lamp", "BasePart") :: BasePart?
	stand.lamp = lamp
	if lamp then
		stand.material = lamp.Material
		stand.color = lamp.Color
		lamp.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Name = "CleanACat_Fx_GiftLight"
		light.Color = WARM
		light.Range = GiftStand.LIGHT_RANGE
		light.Brightness = GiftStand.LIGHT_BRIGHTNESS
		light.Shadows = false
		light.Parent = lamp
		stand.light = light
	end
	stand.glow = find(model, "Glow", "Attachment") :: Attachment?
	local balloon = balloonOf(model)
	stand.balloon = balloon
	stand.balloonRest = if balloon then model:GetPivot():ToObjectSpace(balloon:GetPivot()) else nil
	stand.beacon, stand.beaconIcon = nil, nil
	if mine(model) then
		makeBeacon(stand)
	end
	local now = os.clock()
	stand.litAt = now
	stand.flashFrom = if live then now else nil
	-- the first sparkle comes with the light when it lights while you watch, otherwise a moment later
	stand.nextSparkle = if live then now else now + GiftStand.SPARKLE_EVERY * stand.seed
	lit[model] = stand
	if stepping == nil then
		stepping = RunService.RenderStepped:Connect(step)
	end
end

local function watch(instance: Instance)
	if not instance:IsA("Model") or not NAMES[instance.Name] or stands[instance :: Model] then
		return
	end
	local model = instance :: Model
	seedCount += 1
	local stand: Stand = {
		model = model,
		lamp = nil,
		material = nil,
		color = nil,
		light = nil,
		glow = nil,
		balloon = nil,
		balloonRest = nil,
		beacon = nil,
		beaconIcon = nil,
		litAt = 0,
		flashFrom = nil,
		nextSparkle = 0,
		seed = (seedCount * 0.618) % 1,
	}
	stands[model] = stand
	model:GetAttributeChangedSignal("Lit"):Connect(function()
		setLit(stand, model:GetAttribute("Lit") == true, true)
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			setLit(stand, false, false)
			stands[model] = nil
		end
	end)
	-- already lit when first seen (a join after 7:00, or streaming in): no swell, just lit
	setLit(stand, model:GetAttribute("Lit") == true, false)
end

local started = false
function GiftStand.start()
	if started then
		return
	end
	started = true
	for _, d in Workspace:GetDescendants() do
		watch(d)
	end
	Workspace.DescendantAdded:Connect(watch)
	-- the beacon goes once the pet is yours, and follows you to your plot
	local player = Players.LocalPlayer
	if player then
		local function refresh()
			for _, stand in lit do
				local want = mine(stand.model) and not claimed()
				if want and stand.beacon == nil then
					makeBeacon(stand)
				elseif not want and stand.beacon then
					stand.beacon:Destroy()
					stand.beacon, stand.beaconIcon = nil, nil
				end
			end
		end
		player:GetAttributeChangedSignal(CLAIMED):Connect(refresh)
		player:GetAttributeChangedSignal(SLOT):Connect(refresh)
	end
end

return GiftStand
