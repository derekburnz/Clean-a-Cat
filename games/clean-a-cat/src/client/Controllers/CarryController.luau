--!strict
-- CarryController: carrying a customer's cat from the door to the tub (switch customerCarry, claim #406). The owner's
-- dev note of 2026-11-25: "take it from customer and walk it over to the bathtub and when you put it in tub thats when
-- it puts you into the minigame scene". It works like the opening's carry of Suds (OpeningController), with the same
-- arms (Effects/Carry), floor trail and tub prompt.
--
-- The server says where the cat is with the Player attribute CarryRules.ATTRIBUTE, and this only draws it and asks:
--   "door"  the front customer holds it: a "Take" prompt on them. A tap walks the player up and asks RequestTakeCat.
--   "arms"  it is the player's: a client-only copy of the cat is lifted into their arms, and the trail and a
--           "Put in tub" prompt lead to the tub. A tap there hops it into the tub and asks RequestPlaceCat; the close-up
--           wash view starts at once (WashView, reason "carry") and the wash takes over when CatReady comes.
--   nil     in the tub (or no carry): the copy goes; ScrubController's own cat is in the tub by then.
-- A copy that hopped in but was never taken (the server refused or never heard) is lifted back up after a few tries,
-- so the player is never left with a cat stuck in the tub and no wash. Nothing here decides anything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarryRules = require(Shared:WaitForChild("CarryRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))

local Client = script.Parent.Parent
local Carry = require(Client:WaitForChild("Effects"):WaitForChild("Carry"))
local ControlHold = require(Client:WaitForChild("Spa"):WaitForChild("ControlHold"))
local FloorTrail = require(Client:WaitForChild("Spa"):WaitForChild("FloorTrail"))
local WashView = require(Client:WaitForChild("Spa"):WaitForChild("WashView"))

local CarryController = {}

local PROMPT_REACH = 10 -- studs; well inside the server's CarryRules reaches
local PROMPT_HEIGHT = 3 -- studs above the front customer's spot, about their chest
local CAT_HEIGHT = 2 -- studs above the front spot where the cat sits in the carrier, where the lift starts
local STAND = 2.6 -- studs from the customer where the player stops to take the cat (as the opening's PICK_STAND)
local WALK_SECONDS = 4 -- the walk up gives up after this and the take is asked where they are
local RESEND_SECONDS = 2 -- an ask the server has not answered is sent again this often
local RESENDS = 3
local ASSET_WAIT_SECONDS = 5
local HOLD_REASON = "carry" -- ControlHold, while walking up to the customer
local VIEW_REASON = "carry" -- WashView, from the hop into the tub until the wash holds it
local WASH_FLAG = "washView"
local BODY_WAIT_SECONDS = 5 -- a new character's root and humanoid, after a reset while carrying
local BODY_SETTLE_SECONDS = 0.3

local player = Players.LocalPlayer
local scrub: any = nil -- ScrubController: where the tub's seat is and the size a cat sits at there

local prompt: BasePart? = nil -- the anchor of the current prompt ("Take" at the door or "Put in tub")
local carried: Model? = nil -- the client-only copy of the cat
local held: Carry.Handle? = nil
local trailShown = false -- the floor trail is this controller's (the opening uses it too)
local walking = false
local placing = false -- the copy is hopping in or in the tub, waiting for the server
local turn = 0 -- bumped on every change of where the cat is, so a stale walk or resend stops

local function where(): string?
	local value = player:GetAttribute(CarryRules.ATTRIBUTE)
	return if type(value) == "string" then value else nil
end

local function clearPrompt()
	local anchor = prompt
	prompt = nil
	if anchor then
		anchor:Destroy()
	end
end

local function hideTrail()
	if trailShown then
		trailShown = false
		FloorTrail.hide()
	end
end

local function letGo()
	local handle = held
	held = nil
	if handle then
		handle.destroy()
	end
	local copy = carried
	carried = nil
	if copy then
		copy:Destroy()
	end
	placing = false
	WashView.set(VIEW_REASON, false)
end

-- A tap target at `cframe`: an invisible part with a prompt.
local function promptAt(cframe: CFrame, size: Vector3, action: string, fn: () -> ())
	clearPrompt()
	local anchor = Instance.new("Part")
	anchor.Name = "CleanACat_CarryPrompt"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = size
	anchor.CFrame = cframe
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.HoldDuration = 0
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = PROMPT_REACH
	p.Triggered:Connect(function(_who: Player)
		fn()
	end)
	p.Parent = anchor
	anchor.Parent = Workspace
	prompt = anchor
end

-- Sends `name` now and again every RESEND_SECONDS while the cat is still `from` in this turn; `onGiveUp` when the
-- server never moved it.
local function ask(name: string, from: string, onGiveUp: (() -> ())?)
	local mine = turn
	Remotes.event(name):FireServer()
	task.spawn(function()
		for _ = 1, RESENDS do
			task.wait(RESEND_SECONDS)
			if turn ~= mine or where() ~= from then
				return
			end
			Remotes.event(name):FireServer()
		end
		task.wait(RESEND_SECONDS)
		if turn == mine and where() == from and onGiveUp then
			onGiveUp()
		end
	end)
end

-- The player walks up to `target`, stopping STAND short of it, and turns to face it; then `onArrive`. Their own
-- walking is held on the way. Gives up after WALK_SECONDS.
local function walkUpTo(target: Vector3, onArrive: () -> ())
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		onArrive()
		return
	end
	local body = root :: BasePart
	local flat = Vector3.new(target.X, body.Position.Y, target.Z)
	local away = body.Position - flat
	local function face()
		if (flat - body.Position).Magnitude > 0.1 then
			body.CFrame = CFrame.lookAt(body.Position, flat)
		end
	end
	if away.Magnitude <= STAND + 0.5 then
		face()
		onArrive()
		return
	end
	walking = true
	ControlHold.set(HOLD_REASON, true)
	local done = false
	local connection: RBXScriptConnection? = nil
	local function finish()
		if done then
			return
		end
		done = true
		walking = false
		if connection then
			connection:Disconnect()
		end
		ControlHold.set(HOLD_REASON, false)
		if player.Character == character then
			face()
		end
		onArrive()
	end
	connection = (humanoid :: Humanoid).MoveToFinished:Connect(finish);
	(humanoid :: Humanoid):MoveTo(flat + away.Unit * STAND)
	task.delay(WALK_SECONDS, finish)
end

local function frontSpot(): CFrame
	return SpaLayout.lineSpot("SpotQueue", 1)
end

-- "door": the front customer holds the cat; "Take" walks the player up and asks for it.
local function offerTake()
	letGo()
	hideTrail()
	local front = frontSpot()
	promptAt(front * CFrame.new(0, PROMPT_HEIGHT, 0), Vector3.new(2, 2, 2), "Take cat", function()
		if walking or where() ~= CarryRules.DOOR then
			return
		end
		local mine = turn
		walkUpTo(front.Position, function()
			if turn == mine and where() == CarryRules.DOOR then
				ask("RequestTakeCat", CarryRules.DOOR, nil)
			end
		end)
	end)
end

-- A client-only copy of the cat of `kind`, posed to sit, that never collides, catches a ray or touches anything.
local function copyOf(kind: string): Model?
	local assets = ReplicatedStorage:WaitForChild("Assets", ASSET_WAIT_SECONDS)
	local found = assets :: Instance
	local asset = if assets
		then found:FindFirstChild(CarryRules.modelName(kind, function(name: string): boolean
			return found:FindFirstChild(name) ~= nil
		end))
		else nil
	if not (asset and asset:IsA("Model")) then
		warn(`CarryController: ReplicatedStorage.Assets has no dirty model for {kind}`)
		return nil
	end
	local model = asset:Clone() :: Model
	model.Name = "CleanACat_CarriedCat"
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local part = item :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		elseif item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		end
	end
	return model
end

local leadToTub: () -> ()

-- Lifts the copy into the player's arms from `from` (the carrier, or the tub after a refused place); `reach` bends
-- down for it first.
local function lift(kind: string, from: CFrame?, reach: boolean)
	local character = player.Character
	if character == nil then
		return
	end
	local copy = carried
	if copy == nil then
		copy = copyOf(kind)
		if copy == nil or where() ~= CarryRules.ARMS then
			if copy then
				copy:Destroy()
			end
			return
		end
		carried = copy
	end
	local model = copy :: Model
	local root = character:FindFirstChild("HumanoidRootPart")
	if from then
		model:PivotTo(from)
	elseif model.Parent == nil and root and root:IsA("BasePart") then
		model:PivotTo((root :: BasePart).CFrame) -- a new copy with no spot (after a reset): it starts at the player
	end
	model.Parent = Workspace
	local before = held
	if before then
		before.destroy()
	end
	held = Carry.hold(character, model, "sit", reach)
	placing = false
	leadToTub()
end

-- "Put in tub": the arms open, the cat hops onto the seat, the wash view starts, and the server is asked to take it.
-- If it never does, the cat is lifted back up and the prompt comes again.
local function putIn()
	local handle = held
	if handle == nil or placing or where() ~= CarryRules.ARMS then
		return
	end
	placing = true
	clearPrompt()
	hideTrail()
	if LiveFlags.isOn(WASH_FLAG) then
		WashView.set(VIEW_REASON, true)
	end
	local seat: CFrame = if scrub then scrub.seatSpot() else SpaLayout.tubSpot()
	local mine = turn
	handle.placeIn(seat.Position, function()
		if turn ~= mine or where() ~= CarryRules.ARMS then
			return
		end
		ask("RequestPlaceCat", CarryRules.ARMS, function()
			-- refused or lost: back into the arms, the view back to the player's
			WashView.set(VIEW_REASON, false)
			local kind = player:GetAttribute(CarryRules.KIND_ATTRIBUTE)
			if type(kind) == "string" then
				lift(kind, nil, false)
			end
		end)
	end, if scrub then scrub.seatScale() else nil)
end

function leadToTub()
	local seat: CFrame = if scrub then scrub.seatSpot() else SpaLayout.tubSpot()
	if not trailShown then
		trailShown = true
		FloorTrail.show(SpaLayout.tubSpot().Position)
	end
	promptAt(seat, Vector3.new(4, 3, 4), "Put in tub", putIn)
end

-- The cat is in the tub (the attribute cleared): the copy goes, and ScrubController's cat takes its place. The wash
-- holds the view from CatReady; this lets go of its own hold a moment later, inside WashView's grace.
local function inTub()
	clearPrompt()
	hideTrail()
	local copy = carried
	carried = nil
	local handle = held
	held = nil
	placing = false
	if handle then
		handle.destroy()
	end
	if copy then
		copy:Destroy()
	end
	task.delay(0.1, function()
		if where() == nil then
			WashView.set(VIEW_REASON, false)
		end
	end)
end

local function update()
	turn += 1
	local now = where()
	if now == CarryRules.DOOR then
		offerTake()
	elseif now == CarryRules.ARMS then
		if held == nil then
			clearPrompt()
			local kind = player:GetAttribute(CarryRules.KIND_ATTRIBUTE)
			if type(kind) == "string" then
				local front = frontSpot()
				lift(kind, front * CFrame.new(0, CAT_HEIGHT, 0), true)
			end
		end
	else
		inTub()
	end
end

function CarryController.Init(controllers: { [string]: any })
	scrub = controllers.ScrubController
end

function CarryController.Start()
	player:GetAttributeChangedSignal(CarryRules.ATTRIBUTE):Connect(update)
	player:GetAttributeChangedSignal(CarryRules.KIND_ATTRIBUTE):Connect(function()
		-- a new cat while one is carried (it should not happen): start over with the right one
		if where() == CarryRules.ARMS and carried ~= nil and not placing then
			letGo()
			update()
		end
	end)
	-- A reset while carrying: the new character picks the cat up where it stands, with no reach.
	-- It waits for the new body to be built (its root and arms), or the copy would sit where the asset was made
	-- with no arms to follow (Sync-Agent's run on 542efbc: the cat at the world's origin).
	player.CharacterAdded:Connect(function(character: Model)
		walking = false
		if where() ~= CarryRules.ARMS then
			return
		end
		local kind = player:GetAttribute(CarryRules.KIND_ATTRIBUTE)
		letGo()
		if type(kind) ~= "string" then
			return
		end
		local mine = turn
		task.spawn(function()
			local root = character:WaitForChild("HumanoidRootPart", BODY_WAIT_SECONDS)
			character:WaitForChild("Humanoid", BODY_WAIT_SECONDS)
			task.wait(BODY_SETTLE_SECONDS) -- the arms' joints are made a moment after the root
			if
				root ~= nil
				and turn == mine
				and player.Character == character
				and where() == CarryRules.ARMS
				and held == nil
			then
				lift(kind, nil, false)
			end
		end)
	end)
	-- The plot came or went: the line's and the tub's spots moved.
	SpaLayout.changed(function()
		task.delay(1, function()
			if where() == CarryRules.DOOR then
				offerTake()
			elseif where() == CarryRules.ARMS and not placing and held ~= nil then
				leadToTub()
			end
		end)
	end)
	update()
end

return CarryController
