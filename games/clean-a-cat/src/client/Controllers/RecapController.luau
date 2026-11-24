--!strict
-- RecapController: shows the recap card (UI/Recap, switch recapCard, #224) after a customer's cat goes home.
-- ScrubController holds the next cat until the card closes, so the card is a natural place to stop: the player
-- taps Next cat (or the X) and only then does the next customer's cat come. It fires no remotes itself; closing
-- the card runs ScrubController's nextCat, which asks the server. Suds's help bubbles that are due show first, with
-- the tub still empty (BubbleController.afterRecap, switch sudsBubble), and the next cat comes once they go. Closing
-- Suds's naming card also takes the opening's close-up wash view back to the player (OpeningController.leaveWash).
local UI = require(script.Parent.Parent:WaitForChild("UI"))

local RecapController = {}

local scrub: any = nil
local bubbles: any = nil
local opening: any = nil

function RecapController.Init(controllers: { [string]: any })
	scrub = controllers.ScrubController
	bubbles = controllers.BubbleController
	opening = controllers.OpeningController
end

function RecapController.Start()
	if scrub then
		scrub.setRecapHandler(function(recap, nextCat: () -> ())
			UI.showRecap(recap, function()
				-- "Open the spa!" on Suds's naming card: the close-up wash view eases back to the player
				if recap.mascot and opening then
					opening.leaveWash()
				end
				if bubbles then
					bubbles.afterRecap(nextCat)
				else
					nextCat()
				end
			end)
		end)
	end
end

return RecapController
