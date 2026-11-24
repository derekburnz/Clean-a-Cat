--!strict
-- LiveFlagService: reads the live switches from their DataStore every LiveFlags.CHECK_SECONDS and copies each
-- to a ReplicatedStorage attribute. A failed read keeps what the server had. Studio uses its own store name,
-- so a test in Studio can never flip a switch for live players.
-- Budget note: this costs one DataStore read per switch per minute per server. That is fine for a few dozen
-- switches. Retire a switch once its feature has been on for good, so the list stays short.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local LiveFlagService = {}

local function publish(key: string, stored: unknown)
	ReplicatedStorage:SetAttribute(
		LiveFlags.ATTRIBUTE_PREFIX .. key,
		LiveFlags.resolve(key, stored)
	)
end

local function readOne(store: DataStore, key: string)
	local ok, value = pcall(function()
		return store:GetAsync(key)
	end)
	if ok then
		publish(key, value)
	end
end

local function refresh(store: DataStore)
	for _, key in LiveFlags.KEYS do
		readOne(store, key)
	end
end

-- The first read asks for every switch at once, so it takes one store round trip instead of one per switch (about
-- 45 in a row took 6 to 7 s, and the first player in a new server missed the opening, 2026-11-24). It is marked
-- done when every answer is in, or after READ_WAIT_SECONDS; a switch still unanswered then keeps its default until
-- the next minute's read.
local function firstRead(store: DataStore)
	local left = #LiveFlags.KEYS
	for _, key in LiveFlags.KEYS do
		task.spawn(function()
			readOne(store, key)
			left -= 1
		end)
	end
	local deadline = os.clock() + LiveFlags.READ_WAIT_SECONDS
	while left > 0 and os.clock() < deadline do
		task.wait(0.05)
	end
	ReplicatedStorage:SetAttribute(LiveFlags.READ_ATTRIBUTE, true)
end

function LiveFlagService.Init(_services: { [string]: any })
	-- Every switch starts at its default, so code can read the attributes before the first store read.
	for _, key in LiveFlags.KEYS do
		publish(key, nil)
	end
end

function LiveFlagService.Start()
	local name = LiveFlags.STORE
	if RunService:IsStudio() then
		name ..= "_dev"
	end
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if not ok then
		warn(`LiveFlagService: no DataStore ({store}); every switch stays at its default`)
		ReplicatedStorage:SetAttribute(LiveFlags.READ_ATTRIBUTE, true)
		return
	end
	firstRead(store)
	while true do
		task.wait(LiveFlags.CHECK_SECONDS)
		refresh(store)
	end
end

return LiveFlagService
