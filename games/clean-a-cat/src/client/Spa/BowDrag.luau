--!strict
-- BowDrag: the bow step as a drag (switch bowDrag, issue 889). Derek on dev, 2026-11-26: "make them drag a bow onto
-- the cat and only show their most upgraded bow like should be tiers of it starts simple and upgrading adds more
-- money and looks different each tier".
--
-- With the switch on, ScrubController's three bow buttons (one per colour, SpaRules.BOWS) show the bow itself in the
-- player's best tier (the server's BowTier, BowRules.lookId; Model-Agent's CleanACat_Bow_<Colour><Tier> models, each
-- tier a different shape), not the plain button. A finger or the mouse picks one up, it follows the pointer at its
-- own depth, and let go over the cat it is chosen (the same RequestPickBow as a tap was; the server decides the
-- tier and the pay, BowRules). Let go anywhere else, it flies back. A gamepad keeps the tap. Client only.
--
--   BowDrag.on() -> boolean
--   BowDrag.lookName(colourId, tier) -> string   the bow model a button shows: the tier's look while bowTiers is on
--   BowDrag.dress(button, colourId)             swaps the button's look for that bow model (keeps it when missing)
--   BowDrag.begin(button, bowId, ray, place)    picks the bow up; place(button, cframe) moves it (ScrubController's)
--   BowDrag.move(ray)                           follows the pointer
--   BowDrag.finish(onCat) -> string?            lets go: the bow id when onCat(lastRay) says it is over the cat,
--                                               else nil and the button goes home
--   BowDrag.cancel()                            puts a held bow back (a lost touch, the step ending)
--   BowDrag.active() -> boolean
--   BowDrag.alongRay(origin, direction, depth) -> Vector3   pure: the point `depth` studs along the ray
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BowRules = require(Shared:WaitForChild("BowRules"))
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))

local BowFit = require(script.Parent:WaitForChild("BowFit"))

local BowDrag = {}

BowDrag.FLAG = "bowDrag"
BowDrag.LOOK_NAME = "Look" -- ScrubController's BOW_LOOK.name: the model a bow button shows
BowDrag.SAY = "Drag a bow onto the cat" -- the step's words while the switch is on (UI/HUD)
BowDrag.BUTTON_SCALE = 1.5 -- the bow shown on a button, about its size on the cat in the tub (CAT_SCALE)

type Held = {
	button: BasePart,
	bowId: string,
	home: CFrame,
	depth: number,
	ray: Ray,
	place: (BasePart, CFrame) -> (),
}
local held: Held? = nil

function BowDrag.on(): boolean
	return LiveFlags.isOn(BowDrag.FLAG)
end

function BowDrag.active(): boolean
	return held ~= nil
end

function BowDrag.alongRay(origin: Vector3, direction: Vector3, depth: number): Vector3
	if direction.Magnitude < 1e-6 then
		return origin
	end
	return origin + direction.Unit * depth
end

function BowDrag.lookName(colourId: string, tier: string?): string
	if LiveFlags.isOn(BowRules.FLAG) then
		return BowFit.assetName(BowRules.lookId(colourId, BowRules.clean(tier)))
	end
	return BowFit.assetName(colourId)
end

function BowDrag.dress(button: BasePart, colourId: string)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local name =
		BowDrag.lookName(colourId, Players.LocalPlayer:GetAttribute(BowRules.ATTRIBUTE) :: string?)
	local old = button:FindFirstChild(BowDrag.LOOK_NAME)
	if old and old:GetAttribute("BowDragLook") == name then
		return
	end
	local asset = if assets then assets:FindFirstChild(name) else nil
	if asset == nil then
		asset = if assets then assets:FindFirstChild(BowFit.assetName(colourId)) else nil
	end
	if not (asset and asset:IsA("Model")) then
		return
	end
	local look = (asset :: Model):Clone() :: Model
	look.Name = BowDrag.LOOK_NAME
	look:SetAttribute("BowDragLook", name)
	look:ScaleTo(BowDrag.BUTTON_SCALE)
	for _, piece in look:GetDescendants() do
		if piece:IsA("BasePart") then
			local part = piece :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false -- the slab takes the touch
			part.CanTouch = false
			part.CastShadow = false
		elseif piece:IsA("Script") or piece:IsA("LocalScript") then
			piece:Destroy()
		end
	end
	if old then
		old:Destroy()
	end
	look:PivotTo(button.CFrame)
	look.Parent = button
end

function BowDrag.begin(button: BasePart, bowId: string, ray: Ray, place: (BasePart, CFrame) -> ())
	BowDrag.cancel()
	local home = button.CFrame
	held = {
		button = button,
		bowId = bowId,
		home = home,
		depth = (home.Position - ray.Origin).Magnitude,
		ray = ray,
		place = place,
	}
end

function BowDrag.move(ray: Ray?)
	local h = held
	if h == nil or ray == nil then
		return
	end
	h.ray = ray
	local at = BowDrag.alongRay(ray.Origin, ray.Direction, h.depth)
	h.place(h.button, CFrame.new(at) * h.home.Rotation)
end

function BowDrag.cancel()
	local h = held
	held = nil
	if h and h.button.Parent then
		h.place(h.button, h.home)
	end
end

function BowDrag.finish(onCat: (Ray) -> boolean): string?
	local h = held
	if h == nil then
		return nil
	end
	local over = onCat(h.ray)
	held = nil
	if h.button.Parent then
		h.place(h.button, h.home) -- chosen: ScrubController hides the buttons; missed: it flies home
	end
	return if over then h.bowId else nil
end

return BowDrag
