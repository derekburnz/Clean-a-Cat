--!strict
-- Effects: client-only, cosmetic. One pooled ParticleEmitter per preset, moved to where the effect plays.
-- Effects only listen (see Controllers/EffectsController): they never fire remotes, change gameplay state or
-- move a part the server moves. See the animation-vfx skill and docs/vfx/clean-a-cat/effects-list.md.
--
-- API
--   Effects.start()                                 picks the device tier once
--   Effects.stream(preset, position, dragSpeed)     a steady stream at a point, rate from drag speed
--   Effects.stopStream(preset)
--   Effects.burst(preset, position)                 one burst at a point
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local PresetData = require(script:WaitForChild("Presets"))
local Tier = require(script:WaitForChild("Tier"))

type Emitter = PresetData.Emitter

local FAST_DRAG = 30 -- studs per second, matches Audio's CueRules.FAST_DRAG

local Effects = {}

local tier: PresetData.Tier = "high"
local started = false
local pool: { [string]: { attachment: Attachment, emitter: ParticleEmitter } } = {}

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

function Effects.burst(name: string, position: Vector3)
	if not started then
		return
	end
	local entry, preset = get(name)
	if entry == nil or preset == nil or preset.burst <= 0 then
		return
	end
	entry.attachment.WorldPosition = position
	entry.emitter:Emit(Tier.burst(preset.burst, reducedMotion()))
end

return Effects
