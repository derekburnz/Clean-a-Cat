--!strict
-- Hop: a cat's happy little hop (issue #7: a stray going to the window seat hops, with a small dust puff). The cat
-- leaves the ground in a soft arc of HEIGHT studs over SECONDS, tips nose up a touch on the way up and nose down on
-- the way down, and lands where it started with a puff at its feet. The rest of its motion (CatMotion) carries on.
--
-- Client only and cosmetic; the cat is put back exactly where it was. Reduced Motion: no hop, only the puff.
--
-- API
--   Hop.hop(cat)                     plays it; a second call while one plays does nothing
--   Hop.at(t) -> (lift, pitch)       pure: studs up and nose-up radians at `t` seconds
local RunService = game:GetService("RunService")

local Effects = require(script.Parent)

local Hop = {}

Hop.HEIGHT = 0.6
Hop.SECONDS = 0.42
Hop.TIP = math.rad(8)

function Hop.at(t: number): (number, number)
	if t <= 0 or t >= Hop.SECONDS then
		return 0, 0
	end
	local u = t / Hop.SECONDS
	return Hop.HEIGHT * 4 * u * (1 - u), Hop.TIP * math.cos(math.pi * u) * math.sin(math.pi * u)
end

local hopping: { [Model]: boolean } = {}

local function puff(cat: Model)
	local box, size = cat:GetBoundingBox()
	Effects.burst("roadDust", box.Position - Vector3.new(0, size.Y / 2 - 0.1, 0))
end

function Hop.hop(cat: Model)
	if hopping[cat] then
		return
	end
	if Effects.reducedMotion() then
		puff(cat)
		return
	end
	hopping[cat] = true
	local rest = cat:GetPivot()
	local start = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t >= Hop.SECONDS or cat.Parent == nil then
			if connection then
				connection:Disconnect()
			end
			hopping[cat] = nil
			if cat.Parent then
				cat:PivotTo(rest)
				puff(cat)
			end
			return
		end
		local lift, pitch = Hop.at(t)
		cat:PivotTo(rest * CFrame.new(0, lift, 0) * CFrame.Angles(pitch, 0, 0))
	end)
end

return Hop
