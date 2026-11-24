--!strict
-- Sky: the draft sky and light for the opening and the street (Derek 2026-11-24 3:34 PM ET: "draft the
-- world/background and sky to help set the atmosphere"). A warm, soft early afternoon in the Bubble Pastel style:
-- a pastel pink haze on the horizon fading to lavender, big soft clouds, gentle bloom and a slight warm tint.
-- Model-Agent drafts the world and background around it.
--
-- Client only, like every Effect: Lighting changes made here are this player's own and never replicate. Behind the
-- switch `skyDraft` (off by default, on in the dev experience): Sky.watch applies it while the switch is on and puts
-- every value it changed back when it goes off, so the switch is an instant rollback.
--
-- API
--   Sky.LOOK                      every value it sets, in one table, so a change of mind is a one-line edit
--   Sky.apply()                   sets the look (safe to call twice)
--   Sky.revert()                  puts back what apply changed and removes what it added
--   Sky.watch(flagAttribute)      applies or reverts as ReplicatedStorage's attribute turns true or not
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Sky = {}

local PREFIX = "CleanACat_Sky_"

Sky.LOOK = table.freeze({
	lighting = table.freeze({
		ClockTime = 14.5,
		GeographicLatitude = 35,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(110, 105, 125),
		OutdoorAmbient = Color3.fromRGB(165, 155, 175),
		ColorShift_Top = Color3.fromRGB(255, 236, 214),
		EnvironmentDiffuseScale = 0.7,
		EnvironmentSpecularScale = 0.5,
		ShadowSoftness = 0.35,
		ExposureCompensation = 0.1,
	} :: { [string]: any }),
	atmosphere = table.freeze({
		Density = 0.28,
		Offset = 0.3,
		Color = Color3.fromRGB(255, 214, 226), -- pastel pink haze
		Decay = Color3.fromRGB(186, 170, 220), -- fading to lavender
		Glare = 0.25,
		Haze = 1.4,
	} :: { [string]: any }),
	sky = table.freeze({
		SunAngularSize = 16,
		MoonAngularSize = 9,
		StarCount = 1000,
		CelestialBodiesShown = true,
	} :: { [string]: any }),
	clouds = table.freeze({
		Cover = 0.6,
		Density = 0.55,
		Color = Color3.fromRGB(255, 247, 250),
	} :: { [string]: any }),
	colorCorrection = table.freeze({
		Saturation = 0.12,
		Contrast = 0.06,
		Brightness = 0.02,
		TintColor = Color3.fromRGB(255, 250, 244),
	} :: { [string]: any }),
	bloom = table.freeze({ Intensity = 0.35, Size = 28, Threshold = 1.5 } :: { [string]: any }),
	sunRays = table.freeze({ Intensity = 0.05, Spread = 0.6 } :: { [string]: any }),
})

type Saved = { target: Instance, values: { [string]: any } }

local saved: { Saved } = {} -- properties apply changed on instances it did not make, to put back
local made: { Instance } = {} -- instances apply added
local applied = false

local function set(target: Instance, values: { [string]: any }, remember: boolean)
	local before: { [string]: any } = {}
	for name, value in values do
		local ok, old = pcall(function(): any
			return (target :: any)[name]
		end)
		if ok then
			before[name] = old
			pcall(function()
				(target :: any)[name] = value
			end)
		end
	end
	if remember then
		table.insert(saved, { target = target, values = before })
	end
end

-- The one instance of `className` under `parent`: an existing one is changed (and put back on revert), else a new
-- one is made (and removed on revert).
local function useOrMake(parent: Instance, className: string, values: { [string]: any })
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		set(existing, values, true)
		return
	end
	local created = Instance.new(className)
	created.Name = PREFIX .. className
	set(created, values, false)
	created.Parent = parent
	table.insert(made, created)
end

function Sky.apply()
	if applied then
		return
	end
	applied = true
	local look = Sky.LOOK
	set(Lighting, look.lighting, true)
	useOrMake(Lighting, "Atmosphere", look.atmosphere)
	useOrMake(Lighting, "Sky", look.sky)
	useOrMake(Lighting, "ColorCorrectionEffect", look.colorCorrection)
	useOrMake(Lighting, "BloomEffect", look.bloom)
	useOrMake(Lighting, "SunRaysEffect", look.sunRays)
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		useOrMake(terrain, "Clouds", look.clouds)
	end
end

function Sky.revert()
	if not applied then
		return
	end
	applied = false
	for i = #saved, 1, -1 do
		local entry = saved[i]
		set(entry.target, entry.values, false)
	end
	table.clear(saved)
	for _, instance in made do
		instance:Destroy()
	end
	table.clear(made)
end

function Sky.watch(flagAttribute: string)
	local function check()
		if ReplicatedStorage:GetAttribute(flagAttribute) == true then
			Sky.apply()
		else
			Sky.revert()
		end
	end
	ReplicatedStorage:GetAttributeChangedSignal(flagAttribute):Connect(check)
	check()
end

return Sky
