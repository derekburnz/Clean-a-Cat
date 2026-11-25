--!strict
-- LiveFlagService: reads the live switches from their DataStore every LiveFlags.CHECK_SECONDS and copies each
-- to a ReplicatedStorage attribute. A failed read keeps what the server had. Studio uses its own store name,
-- so a test in Studio can never flip a switch for live players.
-- Budget: one DataStore read a minute per server for every switch, from the entry LiveFlags.ALL_ENTRY (#325; one
-- read per switch hit 58 a minute, near the 60 plus 10 per player budget the saves share). A store that has no
-- such entry yet (flags.sh writes it on its first set) is read the older way, one entry per switch, until it has.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local LiveFlagService = {}

local FIRST_RETRY_SECONDS = 1 -- between tries of a failed first read, inside LiveFlags.READ_WAIT_SECONDS

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

-- Reads the entry that holds every switch and publishes them all. Returns "done" when it did, "missing" when the
-- store has no such entry yet (or it is not a table), and "failed" when the read failed (nothing changes).
local function readAll(store: DataStore): "done" | "missing" | "failed"
	local ok, value = pcall(function()
		return store:GetAsync(LiveFlags.ALL_ENTRY)
	end)
	if not ok then
		return "failed"
	end
	if type(value) ~= "table" then
		return "missing"
	end
	for _, key in LiveFlags.KEYS do
		publish(key, LiveFlags.storedIn(value, key))
	end
	return "done"
end

local function refresh(store: DataStore)
	if readAll(store) ~= "missing" then
		return
	end
	for _, key in LiveFlags.KEYS do
		readOne(store, key)
	end
end

-- The first read is marked done when every answer is in, or after READ_WAIT_SECONDS; a switch still unanswered then
-- keeps its default until the next minute's read. In the older layout it asks for every switch at once, so it takes
-- one store round trip instead of one per switch (about 45 in a row took 6 to 7 s, and the first player in a new
-- server missed the opening, 2026-11-24).
local function firstRead(store: DataStore)
	local deadline = os.clock() + LiveFlags.READ_WAIT_SECONDS
	local all = readAll(store)
	-- one failed read would leave every switch at its default for a minute (and the first player without the
	-- opening), so a blip is tried again while there is time (Review-QA's nit on #427)
	while all == "failed" and os.clock() + FIRST_RETRY_SECONDS < deadline do
		task.wait(FIRST_RETRY_SECONDS)
		all = readAll(store)
	end
	if all == "missing" then
		local left = #LiveFlags.KEYS
		for _, key in LiveFlags.KEYS do
			task.spawn(function()
				readOne(store, key)
				left -= 1
			end)
		end
		while left > 0 and os.clock() < deadline do
			task.wait(0.05)
		end
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
