--!strict
-- Effects: client-only, cosmetic. One pooled ParticleEmitter per preset, moved to where the effect plays.
-- Effects only listen (see Controllers/EffectsController): they never fire remotes, change gameplay state or
-- move a part the server moves. See the animation-vfx skill and docs/vfx/clean-a-cat/effects-list.md.
--
-- API
--   Effects.start()                                 picks the device tier once
--   Effects.stream(preset, position, dragSpeed)     a steady stream at a point, rate from drag speed
--   Effects.stopStream(preset)
--   Effects.burst(preset, position, color?)         one burst at a point, optionally tinted
--   Effects.glow(model, seconds)                    a soft outline glow that fades out, then is destroyed
--   Effects.popIn(model, anchor, seconds)           grows a small client-only model from nothing (Back Out), holding
--                                                   `anchor` (an Attachment in it) still, e.g. a bow on its BowSlot
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local PresetData = require(script:WaitForChild("Presets"))
local Tier = require(script:WaitForChild("Tier"))

type Emitter = PresetData.Emitter

local FAST_DRAG = 30 -- studs per second, matches Audio's CueRules.FAST_DRAG

local Effects = {}

local tier: PresetData.Tier = "high"
local started = false
local pool: { [string]: { attachment: Attachment, emitter: ParticleEmitter } } = {}
local activeHighlights = 0

local function reducedMotion(): boolean
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and value == true
end

local function qualityLevel(): number
	local ok, value = pcall(function()
		return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value
	end)
	return if ok and type(value) == "number" then value else 0
end

local function sequenceColor(colors: { Color3 }): ColorSequence
	if #colors >= 2 then
		return ColorSequence.new(colors[1], colors[2])
	end
	return ColorSequence.new(colors[1])
end

local function build(
	name: string,
	preset: Emitter
): { attachment: Attachment, emitter: ParticleEmitter }
	local attachment = Instance.new("Attachment")
	attachment.Name = `CleanACat_Fx_{name}`
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	if preset.texture ~= "" then
		emitter.Texture = preset.texture
	end
	emitter.Color = sequenceColor(preset.color)
	emitter.Size = NumberSequence.new(preset.size[1], preset.size[2])
	emitter.Transparency = NumberSequence.new(preset.transparency[1], preset.transparency[2])
	emitter.Lifetime = NumberRange.new(preset.lifetime[1], preset.lifetime[2])
	emitter.Speed = NumberRange.new(preset.speed[1], preset.speed[2])
	emitter.SpreadAngle = Vector2.new(preset.spread, preset.spread)
	emitter.Acceleration = preset.acceleration
	emitter.Drag = preset.drag
	emitter.LightEmission = preset.lightEmission
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Parent = attachment
	attachment.Parent = workspace.Terrain
	return { attachment = attachment, emitter = emitter }
end

local function get(name: string): ({ attachment: Attachment, emitter: ParticleEmitter }?, Emitter?)
	local preset = PresetData.emitters[tier][name]
	if preset == nil then
		return nil, nil
	end
	local entry = pool[name]
	if entry == nil or entry.attachment.Parent == nil then
		entry = build(name, preset)
		pool[name] = entry
	end
	return entry, preset
end

function Effects.start()
	if started then
		return
	end
	started = true
	tier =
		Tier.pick(UserInputService.TouchEnabled, UserInputService.KeyboardEnabled, qualityLevel())
end

function Effects.tier(): PresetData.Tier
	return tier
end

function Effects.stream(name: string, position: Vector3, dragSpeed: number)
	if not started then
		return
	end
	local entry, preset = get(name)
	if entry == nil or preset == nil then
		return
	end
	entry.attachment.WorldPosition = position
	local rate = Tier.foamRate(preset.maxRate, dragSpeed, FAST_DRAG, reducedMotion())
	entry.emitter.Rate = rate
	entry.emitter.Enabled = rate > 0
end

function Effects.stopStream(name: string)
	local entry = pool[name]
	if entry then
		entry.emitter.Enabled = false
	end
end

function Effects.burst(name: string, position: Vector3, color: Color3?)
	if not started then
		return
	end
	local entry, preset = get(name)
	if entry == nil or preset == nil or preset.burst <= 0 then
		return
	end
	entry.emitter.Color = if color then ColorSequence.new(color) else sequenceColor(preset.color)
	entry.attachment.WorldPosition = position
	entry.emitter:Emit(Tier.burst(preset.burst, reducedMotion()))
end

function Effects.glow(model: Model, seconds: number)
	if not started or not model:IsDescendantOf(workspace) then
		return
	end
	if activeHighlights >= PresetData.budgets[tier].maxHighlights then
		return
	end
	activeHighlights += 1
	local highlight = Instance.new("Highlight")
	highlight.Name = "CleanACat_Fx_Glow"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 250, 235)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.75
	highlight.OutlineTransparency = 0.3
	highlight.Adornee = model
	highlight.Parent = model
	local released = false
	local function release()
		if not released then
			released = true
			activeHighlights -= 1
		end
	end
	highlight.Destroying:Once(release)
	if reducedMotion() then
		task.delay(seconds, function()
			highlight:Destroy()
		end)
		return
	end
	local fade = TweenService:Create(
		highlight,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = 1, OutlineTransparency = 1 }
	)
	fade.Completed:Once(function()
		highlight:Destroy()
	end)
	fade:Play()
end

local POP_START = 0.05 -- ScaleTo needs a scale above zero

function Effects.popIn(model: Model, anchor: Attachment, seconds: number)
	if not started or reducedMotion() or not model:IsDescendantOf(workspace) then
		return
	end
	local final = model:GetScale()
	local function scaleKeepingAnchor(scale: number)
		local before = anchor.WorldPosition
		model:ScaleTo(final * scale)
		model:PivotTo(model:GetPivot() + (before - anchor.WorldPosition))
	end
	scaleKeepingAnchor(POP_START)
	local began = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if model.Parent == nil or anchor.Parent == nil then
			connection:Disconnect()
			return
		end
		local u = math.clamp((os.clock() - began) / seconds, 0, 1)
		local eased = TweenService:GetValue(u, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		scaleKeepingAnchor(math.max(POP_START, eased))
		if u >= 1 then
			connection:Disconnect()
		end
	end)
end

return Effects
