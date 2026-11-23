--!strict
-- BowFit: puts one of Model-Agent's bows (ReplicatedStorage.Assets.CleanACat_Bow_<Name>) on a cat's head, on
-- the client only. The bow's BowSlot attachment (in its biggest part) meets the head's BowSlot attachment, the
-- bow is scaled like the cat (its Scale attribute times `scale`), and it never catches a ray.
-- Used by the tub (ScrubController) and the display window (WindowController).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BowFit = {}

local NAME = "WornBow"

-- The asset name for a bow id from SpaRules.BOWS: "BowPink" -> "CleanACat_Bow_Pink".
function BowFit.assetName(bowId: string): string
	return "CleanACat_Bow_" .. (string.match(bowId, "^Bow(.+)$") or bowId)
end

local function findSlot(root: Instance): Attachment?
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Attachment") and descendant.Name == "BowSlot" then
			return descendant :: Attachment
		end
	end
	return nil
end

-- The head's BowSlot: the first BowSlot under the cat's ..._Head Model.
local function headSlot(cat: Model): Attachment?
	for _, descendant in cat:GetDescendants() do
		if descendant:IsA("Model") and string.match(descendant.Name, "_Head$") then
			return findSlot(descendant)
		end
	end
	return nil
end

-- Takes off the bow the cat wears, if any.
function BowFit.remove(cat: Model)
	local old = cat:FindFirstChild(NAME)
	if old then
		old:Destroy()
	end
end

-- Puts bow `bowId` on `cat` (replacing one it wears). Returns the bow model, or nil when the bow asset or a
-- BowSlot is missing.
function BowFit.wear(cat: Model, bowId: string, scale: number): Model?
	BowFit.remove(cat)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local asset = if assets then assets:FindFirstChild(BowFit.assetName(bowId)) else nil
	local target = headSlot(cat)
	if not asset or not asset:IsA("Model") or not target then
		return nil
	end
	local bow = (asset :: Model):Clone() :: Model
	local rawScale = cat:GetAttribute("Scale")
	bow:ScaleTo((if type(rawScale) == "number" then rawScale else 1) * scale)
	local slot = findSlot(bow)
	local holder = if slot then slot.Parent else nil
	if not slot or not holder or not holder:IsA("BasePart") then
		bow:Destroy()
		return nil
	end
	-- Where the slot's part must be so the two slots meet, then the whole bow moved by the same amount.
	local part = holder :: BasePart
	local partGoal = (target :: Attachment).WorldCFrame * slot.CFrame:Inverse()
	bow:PivotTo(partGoal * part.CFrame:ToObjectSpace(bow:GetPivot()))
	for _, descendant in bow:GetDescendants() do
		if descendant:IsA("BasePart") then
			local p = descendant :: BasePart
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	bow.Name = NAME
	bow:SetAttribute("BowId", bowId)
	bow.Parent = cat
	return bow
end

return BowFit
