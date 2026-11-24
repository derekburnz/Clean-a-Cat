--!strict
-- HudController: feeds the game HUD (UI/HUD, switch gameHud, #210) from the state other code owns. The coins come
-- from the Player attribute the server mirrors (Wallet.ATTRIBUTE, Services/WalletService), and the wash step from
-- ScrubController.stageChanged. It only shows things; it fires no remotes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.Parent:WaitForChild("UI"))
local Wallet = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Wallet"))

local HudController = {}

local scrub: any = nil

function HudController.Init(controllers: { [string]: any })
	scrub = controllers.ScrubController
end

function HudController.Start()
	local player = Players.LocalPlayer
	local function showCoins()
		UI.setCoins(player:GetAttribute(Wallet.ATTRIBUTE))
	end
	player:GetAttributeChangedSignal(Wallet.ATTRIBUTE):Connect(showCoins)
	showCoins()

	if scrub then
		scrub.stageChanged:Connect(function(stage: string?)
			UI.setWashStage(stage)
		end)
		scrub.planChanged:Connect(function(later: { string })
			UI.setWashPlan(later)
		end)
		UI.setWashPlan(scrub.plan())
		UI.setWashStage(scrub.stage())
		-- the Walk button out of the close-up wash view (switch washView)
		scrub.walkChanged:Connect(function(shown: boolean)
			UI.setWalk(shown)
		end)
		UI.onWalk(function()
			scrub.stepOut()
		end)
	end
end

return HudController
