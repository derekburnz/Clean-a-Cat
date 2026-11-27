--!strict
-- GiftRules: the gift stand (issue 521, switch giftStand). A stand in every spa holds one free pet, Starcoat, from the
-- start. It lights at LIGHT_AT of play (the first five minutes timeline: 7:00), and its card asks for three things:
-- like the game, favourite it and join the game's Roblox group. Roblox lets a game check two of them: the favourite
-- (the result of the player's own favourite prompt, told by their device, which the server trusts for this one free
-- pet) and the group (checked on the server). The like cannot be read by a game, so it is asked and never shown as
-- checked, and never needed. With both checks the pet is given, once per save.
-- With the switch giftGroupOnly (GROUP_ONLY_FLAG, issue 1068, Derek 2026-11-27: "Yes, group join only") the group
-- join alone gives the gift: the favourite is still asked on the card, with no reward tied to it, as the like is.
-- Pure, so tests/specs/GiftRules.spec.luau covers it; GiftService and GiftController use it.

local GiftRules = {}

GiftRules.FLAG = "giftStand"
GiftRules.PET = "Starcoat" -- CrateRules.GIFT_PETS: Model-Agent's CleanACat_Pet_Starcoat
GiftRules.STAND_ASSET = "CleanACat_Prop_GiftStand" -- with parts PetSeat, Prompt, Glow and Lamp (Model-Agent, #502)
GiftRules.STAND_NAME = "GiftStand" -- the stand's name in the plot's Props folder
GiftRules.STAND_SPOT = "SpotGift" -- Model-Agent's plot Attachment, SpaLayout.PLOT_SPOTS
GiftRules.LIGHT_AT = 420 -- seconds of play before the stand lights (7:00)
-- The game's Roblox group, whose members get the pet. Group ids are public on Roblox.
GiftRules.GROUP_ID = 107520049

-- Player attributes the server keeps for the card.
GiftRules.LIT_ATTRIBUTE = "GiftLit" -- true once the stand is lit for this player
GiftRules.FAVOURITE_ATTRIBUTE = "GiftFavourite" -- true once the player's favourite prompt said it was favourited
GiftRules.GROUP_ATTRIBUTE = "GiftGroup" -- true while the last group check found the player in the group
GiftRules.CLAIMED_ATTRIBUTE = "GiftClaimed" -- true once the pet is the player's

GiftRules.GROUP_ONLY_FLAG = "giftGroupOnly"

-- (switch groupVerify, issue 1111, Derek 2026-11-27: "another possible way to do the rewards for likes then only check
-- for group") One free reward board: Join the group, then tap Verify. The server reads the group itself on each tap
-- (VERIFY_REMOTE, one per VERIFY_COOLDOWN seconds) and, on a verified join only, gives the stand's gift and the 150
-- coins (FreeRewardRules.LIKE_COINS) that the like row paid before, each once per save. The like stays a friendly
-- ask with nothing tied to it: with the switch on the like row pays nothing. A player who can't join groups loses
-- nothing else. The board's line reads VERIFY_ATTRIBUTE: the last tap's answer, one of VERIFY_ANSWERS.
GiftRules.VERIFY_FLAG = "groupVerify"
GiftRules.VERIFY_REMOTE = "VerifyGroup"
GiftRules.VERIFY_ATTRIBUTE = "GroupVerify"
GiftRules.VERIFY_COOLDOWN = 10
GiftRules.VERIFY_ANSWERS = table.freeze({ "joined", "notYet", "wait" })
GiftRules.NOT_YET_TEXT = "Join the group, then tap Verify" -- the group only (Growth-Agent on #1111)

-- Whether a Verify tap at `now` is answered, after the last answered one at `lastAt` (nil: none this visit).
function GiftRules.verifyReady(lastAt: number?, now: number): boolean
	return lastAt == nil or now - lastAt >= GiftRules.VERIFY_COOLDOWN
end

-- What a Verify tap gives: the gift (`pet`, not given before) and the coins (not paid before), both only when the
-- server found the player in the group.
function GiftRules.verifyGrant(
	member: boolean,
	giftClaimed: boolean,
	coinsPaid: boolean
): { pet: boolean, coins: boolean }
	return { pet = member and not giftClaimed, coins = member and not coinsPaid }
end

export type State = { favourite: boolean, group: boolean, claimed: boolean }

-- Whether the stand is lit at `played` seconds of play.
function GiftRules.lit(played: number): boolean
	return played >= GiftRules.LIGHT_AT
end

-- Whether the pet can be given now: both checks passed (the group alone under giftGroupOnly, with `isOn`) and not
-- given before. The like is never asked for here.
function GiftRules.canClaim(state: State, isOn: ((flag: string) -> boolean)?): boolean
	local groupOnly = isOn ~= nil and isOn(GiftRules.GROUP_ONLY_FLAG)
	return (state.favourite or groupOnly) and state.group and not state.claimed
end

type Pet = { id: number, kind: string, star: number, slot: string? }
type Save = { pets: { Pet }, nextPetId: number, giftClaimed: boolean }

-- Gives the gift pet into `save` once: into the player's slot when it is empty. Nil when it was given already.
function GiftRules.give(save: Save, playerSlot: string): Pet?
	if save.giftClaimed then
		return nil
	end
	save.giftClaimed = true
	local pet: Pet = { id = save.nextPetId, kind = GiftRules.PET, star = 1, slot = nil }
	save.nextPetId += 1
	local taken = false
	for _, other in save.pets do
		if other.slot == playerSlot then
			taken = true
		end
	end
	if not taken then
		pet.slot = playerSlot
	end
	table.insert(save.pets, pet)
	return pet
end

-- (switch giftCrate, issue 859) Gives the gift crate (CrateRules.GIFT_KIND) into `save` once instead of the pet: the
-- player opens it with their own tap, its chances shown first. False when the gift was given already.
function GiftRules.giveCrate(
	save: { crates: { [string]: number }, giftClaimed: boolean },
	kind: string
): boolean
	if save.giftClaimed then
		return false
	end
	save.giftClaimed = true
	save.crates[kind] = (save.crates[kind] or 0) + 1
	return true
end

return table.freeze(GiftRules)
