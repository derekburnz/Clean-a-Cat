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
				local function onward()
					if bubbles then
						bubbles.afterRecap(nextCat)
					else
						nextCat()
					end
				end
				-- "Open the spa!" on Suds's naming card: the close-up wash view eases back to the player, and Suds's
				-- bubbles and the first customer wait for the ease (Sync-Agent's run on 507cdce: the next cat's view
				-- cut in 20 ms after the ease began)
				if recap.mascot and opening then
					opening.leaveWash(onward)
				else
					onward()
				end
			end)
		end)
	end
end

return RecapController
