--!strict
-- RecapController: shows the recap card (UI/Recap, switch recapCard, #224) after a customer's cat goes home.
-- ScrubController holds the next cat until the card closes, so the card is a natural place to stop: the player
-- taps Next cat (or the X) and only then does the next customer's cat come. It fires no remotes itself; closing
-- the card runs ScrubController's nextCat, which asks the server.
local UI = require(script.Parent.Parent:WaitForChild("UI"))

local RecapController = {}

local scrub: any = nil

function RecapController.Init(controllers: { [string]: any })
	scrub = controllers.ScrubController
end

function RecapController.Start()
	if scrub then
		scrub.setRecapHandler(function(recap, nextCat: () -> ())
			UI.showRecap(recap, nextCat)
		end)
	end
end

return RecapController
