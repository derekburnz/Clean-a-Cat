--!strict
-- HelperPopupController: the HelperPaid remote (WorkerService, issue 743) to UI/HelperPopup, behind the switch
-- helperPopups. The server sends (id, coins) to the owner only when one of their helpers finishes a cat; this shows
-- "+coins" over that helper's stand in the player's own spa (SpaLayout's spot for the helper, a little over a
-- standing helper's head). Bad arguments are dropped.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))

local HelperPopup = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HelperPopup"))

local HelperPopupController = {}

local OVER = 7 -- studs over the stand's floor spot: just over a standing helper's head

function HelperPopupController.Init(_controllers: { [string]: any }) end

function HelperPopupController.Start()
	Remotes.event("HelperPaid").OnClientEvent:Connect(function(rawId: unknown, rawCoins: unknown)
		if not LiveFlags.isOn(WorkerRules.POPUP_FLAG) then
			return
		end
		if type(rawId) ~= "string" or type(rawCoins) ~= "number" or rawCoins ~= rawCoins then
			return
		end
		local info = WorkerRules.WORKERS[rawId]
		if info == nil or rawCoins <= 0 then
			return
		end
		local ok, spot = pcall(SpaLayout.spot, info.spot, nil)
		if not ok then
			return
		end
		HelperPopup.show((spot :: CFrame).Position + Vector3.new(0, OVER, 0), math.floor(rawCoins))
	end)
end

return HelperPopupController
