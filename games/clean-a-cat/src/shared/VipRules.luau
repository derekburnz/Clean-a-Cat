--!strict
-- VipRules: who sits in the finished VIP Room (issue 515, tuning build.VipRoom.effect, switch tubBuilds). Once the
-- room is built, the special visitors' cats the player has washed live there as residents, one on each of
-- Model-Agent's seats (CleanACat_Area_VipRoom: Attachments SpotResident1 to SpotResident<ResidentSeats>, filled in
-- number order, so the room fills from the floor up). With more washed special cats than seats, the first ones in
-- CatRules.SPECIAL_CATS order sit (the save keeps no wash times, so "newest" cannot be told; with six special cats
-- and eight seats it does not come up yet). Pure, so tests/specs/VipRules.spec.luau covers it.
local CatRules = require(script.Parent:WaitForChild("CatRules"))

local VipRules = {}

VipRules.AREA_ASSET = "CleanACat_Area_VipRoom" -- placed at SpaLayout.VIP_SPOT once the room is built
VipRules.AREA_NAME = "VipRoomArea" -- its name in the plot's stations folder
VipRules.SEAT_PREFIX = "SpotResident"
VipRules.SEATS_ATTRIBUTE = "ResidentSeats" -- on the area's root: how many seats it has
VipRules.SCALE_ATTRIBUTE = "ResidentScale" -- on the area's root: the residents' ScaleTo
VipRules.DEFAULT_SEATS = 8
VipRules.DEFAULT_SCALE = 1.2
VipRules.RESIDENT_ATTRIBUTE = "VipResident" -- on each resident cat model: its seat number

export type IndexEntry = { washed: boolean }

-- The special cats to seat, in seat order: those `index` has washed, at most `seats` of them.
function VipRules.residents(index: { [string]: IndexEntry }, seats: number): { string }
	local out: { string } = {}
	for _, kind in CatRules.SPECIAL_CATS do
		if #out >= seats then
			break
		end
		local entry = index[kind]
		if entry ~= nil and entry.washed == true then
			table.insert(out, kind)
		end
	end
	return out
end

-- The area's seat count from its attribute, or the default when it is missing or not a sane whole number.
function VipRules.seatCount(raw: unknown): number
	if type(raw) == "number" and raw >= 0 and raw <= 32 and raw == math.floor(raw) then
		return raw
	end
	return VipRules.DEFAULT_SEATS
end

-- The residents' scale from the area's attribute, or the default.
function VipRules.scale(raw: unknown): number
	if type(raw) == "number" and raw > 0 and raw <= 4 then
		return raw
	end
	return VipRules.DEFAULT_SCALE
end

return table.freeze(VipRules)
