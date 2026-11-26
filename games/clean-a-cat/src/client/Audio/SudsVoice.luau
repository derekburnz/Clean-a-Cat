--!strict
-- SudsVoice: Suds gives one soft meow when his speech bubble appears (issue 827, switch sudsVoice, off by default), so
-- the mascot's lines in the first minutes ("I'm Suds!", the tutorial pointers, his asks) are not silent. It only
-- listens: the SudsBubble frame's Visible going on. Nothing plays while it stays up or when it hides, and the
-- sudsMeow cue's minGap (60 s, Design-Agent) keeps it rare: never twice in a minute.
--
--   SudsVoice.start(isOn)   binds once; isOn() is read each time the bubble shows
local Players = game:GetService("Players")

local Audio = require(script.Parent)

local SudsVoice = {}

SudsVoice.FRAME = "SudsBubble"
SudsVoice.CUE = "sudsMeow"

local started = false

function SudsVoice.start(isOn: () -> boolean)
	if started then
		return
	end
	started = true
	local function watch(frame: Instance)
		if frame.Name ~= SudsVoice.FRAME or not frame:IsA("GuiObject") then
			return
		end
		local card = frame :: GuiObject
		card:GetPropertyChangedSignal("Visible"):Connect(function()
			if card.Visible and isOn() then
				Audio.play(SudsVoice.CUE)
			end
		end)
	end
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui.DescendantAdded:Connect(watch)
	for _, d in gui:GetDescendants() do
		watch(d)
	end
end

return SudsVoice
