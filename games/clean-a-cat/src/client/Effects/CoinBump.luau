--!strict
-- CoinBump: the HUD coin pill answers a gain (issue 826, switch coinBump, off by default; a first-session change, so
-- the switch is its own). When the Wallet attribute goes up the pill bumps once (Effects/Pop from 1 to PEAK and back
-- within 0.2 s, no overshoot), the number counts up over COUNT seconds and one quiet coinPop plays.
--
-- Design-Agent's limits (issue 826):
--   - the first value at join and any drop (spending) get no bump, no count and no sound
--   - a gain during a bump or count-up continues from the number shown, never jumps back
--   - never two bumps within BUMP_GAP seconds; the pill sound at most once every SOUND_GAP seconds
--   - no pill sound for helper pay (HelperPaid within HELPER_WINDOW of the gain): its popup already chimed
--   - only the pill moves; the friend tag under it stays still (UI.setCoinBump scales the pill's own UIScale)
--   - Reduced Motion: the number changes at once with no bump; the sound still plays
--
--   CoinBump.new() -> State                          pure
--   CoinBump.shown(state, now) -> number             pure: the number the pill shows at `now`
--   CoinBump.gain(state, now, value, still) -> bump  pure: takes a new Wallet value; true when the pill should bump
--   CoinBump.wantsSound(state, gainAt, helperAt)     pure: true (and remembered) when this gain gets the sound
--   CoinBump.scale(state, now) -> number             pure: the pill's bump at `now`, 1 when still
--   CoinBump.busy(state, now) -> boolean             pure: still bumping or counting
--   CoinBump.start(ui, isOn)                         binds once; isOn() is read at each gain
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Pop = require(script.Parent:WaitForChild("Pop"))

local CoinBump = {}

CoinBump.PEAK = 1.12
CoinBump.COUNT = 0.4 -- seconds of count-up
CoinBump.BUMP_GAP = 0.5
CoinBump.SOUND_GAP = 2
CoinBump.HELPER_WINDOW = 0.5
CoinBump.SOUND_WAIT = 0.1 -- the HelperPaid remote lands just after the attribute it paid into

export type State = {
	value: number?, -- the last Wallet value taken; nil before the first
	from: number,
	to: number,
	countAt: number,
	bumpAt: number,
	soundAt: number,
}

function CoinBump.new(): State
	return {
		value = nil,
		from = 0,
		to = 0,
		countAt = -math.huge,
		bumpAt = -math.huge,
		soundAt = -math.huge,
	}
end

function CoinBump.shown(state: State, now: number): number
	local u = (now - state.countAt) / CoinBump.COUNT
	if u >= 1 or state.from == state.to then
		return state.to
	end
	local k = math.clamp(u, 0, 1)
	local eased = 1 - (1 - k) * (1 - k)
	return math.floor(state.from + (state.to - state.from) * eased + 0.5)
end

function CoinBump.gain(state: State, now: number, value: number, still: boolean): boolean
	local last = state.value
	state.value = value
	if last == nil or value <= last or still then
		state.from, state.to, state.countAt = value, value, -math.huge
		return false
	end
	state.from = CoinBump.shown(state, now)
	state.to = value
	state.countAt = now
	if now - state.bumpAt < CoinBump.BUMP_GAP then
		return false
	end
	state.bumpAt = now
	return true
end

function CoinBump.wantsSound(state: State, gainAt: number, helperAt: number): boolean
	if math.abs(gainAt - helperAt) <= CoinBump.HELPER_WINDOW then
		return false
	end
	if gainAt - state.soundAt < CoinBump.SOUND_GAP then
		return false
	end
	state.soundAt = gainAt
	return true
end

function CoinBump.scale(state: State, now: number): number
	return Pop.scale(now - state.bumpAt, 1, CoinBump.PEAK)
end

function CoinBump.busy(state: State, now: number): boolean
	return not Pop.done(now - state.bumpAt) or now - state.countAt < CoinBump.COUNT
end

local started = false

function CoinBump.start(ui: any, isOn: () -> boolean)
	if started then
		return
	end
	started = true
	local Client = script.Parent.Parent
	local Audio = require(Client:WaitForChild("Audio")) :: any
	local Comfort = require(Client:WaitForChild("UI"):WaitForChild("Comfort")) :: any
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Remotes = require(Shared:WaitForChild("Remotes")) :: any
	local Wallet = require(Shared:WaitForChild("Wallet")) :: any

	local player = Players.LocalPlayer
	local state = CoinBump.new()
	local helperAt = -math.huge
	local stepping: RBXScriptConnection? = nil

	Remotes.event("HelperPaid").OnClientEvent:Connect(function()
		helperAt = os.clock()
	end)

	local function stop()
		if stepping then
			stepping:Disconnect()
			stepping = nil
		end
		ui.setCoinBump(1, nil)
	end

	local function step()
		local now = os.clock()
		if not CoinBump.busy(state, now) then
			stop()
			return
		end
		ui.setCoinBump(CoinBump.scale(state, now), CoinBump.shown(state, now))
	end

	local function take()
		local raw = player:GetAttribute(Wallet.ATTRIBUTE)
		local value = if type(raw) == "number" and raw == raw then raw else 0
		local now = os.clock()
		local last = state.value
		local on = isOn()
		local still = not on or Comfort.reducedMotion()
		-- a gain inside BUMP_GAP or a drop lets a running bump finish; it never starts a second one
		CoinBump.gain(state, now, value, still)
		if on and last ~= nil and value > last then
			task.delay(CoinBump.SOUND_WAIT, function()
				if CoinBump.wantsSound(state, now, helperAt) then
					Audio.play("coinPop")
				end
			end)
		end
		if CoinBump.busy(state, now) then
			if stepping == nil then
				stepping = RunService.RenderStepped:Connect(step)
			end
			step()
		elseif stepping then
			stop()
		end
	end

	player:GetAttributeChangedSignal(Wallet.ATTRIBUTE):Connect(take)
	take()
end

return CoinBump
