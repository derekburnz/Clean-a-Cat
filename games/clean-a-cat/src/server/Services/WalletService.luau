--!strict
-- WalletService: mirrors the save's coins onto the Player attribute Wallet.ATTRIBUTE, so the HUD's coin counter
-- (UI/HUD, switch gameHud) shows the server's number (#210). Display only: nothing on the server reads the
-- attribute back. Every place that changes save.coins calls WalletService.show(player) right after.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Wallet = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Wallet"))

local DataService = require(script.Parent:WaitForChild("DataService"))

local WalletService = {}

function WalletService.show(player: Player)
	local save = DataService.get(player)
	if save ~= nil and player.Parent ~= nil then
		player:SetAttribute(Wallet.ATTRIBUTE, save.coins)
	end
end

function WalletService.Init(_services: { [string]: any }) end

function WalletService.Start()
	DataService.onLoaded:Connect(function(player: Player)
		WalletService.show(player)
	end)
end

return WalletService
