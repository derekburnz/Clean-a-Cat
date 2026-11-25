--!strict
-- HudController: feeds the game HUD (UI/HUD, switch gameHud, #210) from the state other code owns. The coins come
-- from the Player attribute the server mirrors (Wallet.ATTRIBUTE, Services/WalletService), and the wash step and its
-- fill bar from ScrubController.stageChanged and meterChanged. It only shows things; it fires no remotes.
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
		-- the bar that fills while the player works an area step (switch washMeter; ScrubController sends nil while
		-- it is off). Guarded, so this file works before and after ScrubController grows its meter.
		if scrub.meterChanged then
			scrub.meterChanged:Connect(function(fraction: number?, step: string?)
				UI.setWashMeter(fraction, step)
			end)
			UI.setWashMeter(scrub.meter())
		end
		-- the Walk button out of the close-up wash view (switch washView)
		scrub.walkChanged:Connect(function(shown: boolean)
			UI.setWalk(shown)
		end)
		UI.onWalk(function()
			scrub.stepOut()
		end)
		-- the step's tool under the finger (switch toolCursor)
		scrub.pointerMoved:Connect(function(at: Vector2?, centre: Vector2?, head: Vector2?)
			UI.setToolPoint(at, centre, head)
		end)
	end
end

return HudController
