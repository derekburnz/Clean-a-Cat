--!strict
-- IndexController: holds the player's Cat Index as the server last sent it (CatIndex), for the index screen
-- (#9) to read. It never decides a stamp. Behind the LiveFlags switch `catIndex`.
--
--   IndexController.entries[cat]        { washed, resident } for each stamped cat
--   IndexController.changed:Connect(fn)  fn() after each update
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CatRules = require(Shared:WaitForChild("CatRules"))
local IndexRules = require(Shared:WaitForChild("IndexRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(Shared:WaitForChild("Signal"))

local IndexController = {}

IndexController.entries = {} :: { [string]: IndexRules.Entry }
IndexController.changed = Signal.new() :: Signal.Signal<>

local function isCat(name: string): boolean
	return CatRules.rarityOf(name) ~= nil
end

function IndexController.Init(_controllers: { [string]: any }) end

function IndexController.Start()
	Remotes.event("CatIndex").OnClientEvent:Connect(function(raw: unknown)
		IndexController.entries = IndexRules.clean(raw, isCat)
		IndexController.changed:Fire()
	end)
end

return IndexController
