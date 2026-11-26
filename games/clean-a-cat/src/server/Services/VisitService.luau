--!strict
-- VisitService: visiting and the friend bonus (VisitRules, issue 520).
--   - Visiting (switch visiting): each owner's setting is save.visiting (on for a new save), shown on the Player
--     attribute VisitorsAllowed for the Settings card, and changed with RequestVisiting(on). While a spa is closed to
--     visitors, any other player found inside it is moved out to the pavement in front, a few times a second, with a
--     notice once a minute. Every spa action already acts only on the player's own spa, so a visitor can never wash,
--     pick, take or block anything.
--   - The friend bonus (switch friendBonus): who in the server is a Roblox friend of whom is asked once per pair
--     (Player:IsFriendsWithAsync, cached for the session); each player's count shows on FriendsHere for the HUD, and
--     VisitService.friends(player) gives it to SpaService's pay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local SaveSchema = require(Shared:WaitForChild("SaveSchema"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local VisitRules = require(Shared:WaitForChild("VisitRules"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local NetService = require(script.Parent:WaitForChild("NetService"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))

local KEEP_OUT_SECONDS = 0.25
local NOTICE_SECONDS = 60 -- a visitor moved out hears why at most this often

local VisitService = {}

-- friendsWith[a][b]: whether a and b are Roblox friends, as Roblox said this session.
local friendsWith: { [Player]: { [Player]: boolean } } = {}
local noticed: { [Player]: number } = {}

local function visitingOn(): boolean
	return LiveFlags.isOn(VisitRules.FLAG)
end

local function friendsOn(): boolean
	return LiveFlags.isOn(VisitRules.FRIEND_FLAG)
end

-- Friends of `player` in the server now; 0 while friendBonus is off.
function VisitService.friends(player: Player): number
	if not friendsOn() then
		return 0
	end
	local count = 0
	local mine: { [Player]: boolean } = friendsWith[player] or {}
	for other, yes in mine do
		if yes and other.Parent == Players then
			count += 1
		end
	end
	return count
end

local function showFriends(player: Player)
	local value = if friendsOn() then VisitService.friends(player) else nil
	if player:GetAttribute(VisitRules.FRIENDS_ATTRIBUTE) ~= value then
		player:SetAttribute(VisitRules.FRIENDS_ATTRIBUTE, value)
	end
end

local function showSetting(player: Player)
	local save = DataService.get(player)
	local value = if visitingOn() and save then save.visiting else nil
	if player:GetAttribute(VisitRules.ALLOWED_ATTRIBUTE) ~= value then
		player:SetAttribute(VisitRules.ALLOWED_ATTRIBUTE, value)
	end
end

-- Asks Roblox about `player` and every other player in the server it has not asked about yet. Yields.
local function meet(player: Player)
	friendsWith[player] = friendsWith[player] or {}
	for _, other in Players:GetPlayers() do
		if other == player or (friendsWith[player] :: any)[other] ~= nil then
			continue
		end
		local ok, yes = pcall(function()
			return player:IsFriendsWithAsync(other.UserId)
		end)
		if player.Parent ~= Players then
			return
		end
		local friend = ok and yes == true
		local mine = friendsWith[player]
		if mine then
			mine[other] = friend
		end
		local theirs = friendsWith[other]
		if theirs then
			theirs[player] = friend
		end
		showFriends(other)
	end
	showFriends(player)
end

local function onSetting(player: Player, raw: unknown)
	if not visitingOn() then
		return
	end
	local value = VisitRules.cleanSetting(raw)
	local save = DataService.get(player)
	if value == nil or save == nil or save.visiting == value then
		return
	end
	save.visiting = value
	Telemetry.event(player, "visiting_set", if value then 1 else 0)
	showSetting(player)
end

-- Moves every other player out of each spa that is closed to visitors.
local function keepOut()
	if not visitingOn() then
		return
	end
	for _, owner in Players:GetPlayers() do
		local save = DataService.get(owner)
		local slot = SpaLayout.slotOf(owner)
		if save == nil or save.visiting or slot == nil then
			continue
		end
		local pivot = CFrame.new(SpaLayout.slotPivot(slot))
		for _, visitor in Players:GetPlayers() do
			if visitor == owner then
				continue
			end
			local character = visitor.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if not (root and root:IsA("BasePart")) then
				continue
			end
			local at = pivot:PointToObjectSpace((root :: BasePart).Position)
			if not VisitRules.inside(at) then
				continue
			end
			local out = pivot * CFrame.new(VisitRules.OUTSIDE); -- facing the street, away from the closed door
			(character :: Model):PivotTo(
				CFrame.lookAt(out.Position, out.Position + Vector3.new(0, 0, -1))
			)
			local now = os.clock()
			if now - (noticed[visitor] or -math.huge) >= NOTICE_SECONDS then
				noticed[visitor] = now
				NetService.notice(
					visitor,
					`{owner.DisplayName}'s spa is closed to visitors right now`
				)
			end
		end
	end
end

function VisitService.Init(_services: { [string]: any }) end

function VisitService.Start()
	NetService.on("RequestVisiting", { perSecond = 1, burst = 3 }, onSetting)
	DataService.onLoaded:Connect(function(player: Player, _save: SaveSchema.Save)
		showSetting(player)
	end)
	Players.PlayerAdded:Connect(meet)
	for _, player in Players:GetPlayers() do
		task.spawn(meet, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		friendsWith[player] = nil
		noticed[player] = nil
		for other, mine in friendsWith do
			mine[player] = nil
			if other ~= player then
				task.defer(showFriends, other)
			end
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. VisitRules.FLAG)
		:Connect(function()
			for _, player in Players:GetPlayers() do
				showSetting(player)
			end
		end)
	ReplicatedStorage
		:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. VisitRules.FRIEND_FLAG)
		:Connect(function()
			for _, player in Players:GetPlayers() do
				showFriends(player)
			end
		end)
	task.spawn(function()
		while true do
			task.wait(KEEP_OUT_SECONDS)
			keepOut()
		end
	end)
end

return VisitService
