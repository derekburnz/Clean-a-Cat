--!strict
-- GiftRules: the gift stand (issue 521, switch giftStand). A stand in every spa holds one free pet, Starcoat, from the
-- start. It lights at LIGHT_AT of play (the first five minutes timeline: 7:00), and its card asks for three things:
-- like the game, favourite it and join the game's Roblox group. Roblox lets a game check two of them: the favourite
-- (the result of the player's own favourite prompt, told by their device, which the server trusts for this one free
-- pet) and the group (checked on the server). The like cannot be read by a game, so it is asked and never shown as
-- checked, and never needed. With both checks the pet is given, once per save.
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

export type State = { favourite: boolean, group: boolean, claimed: boolean }

-- Whether the stand is lit at `played` seconds of play.
function GiftRules.lit(played: number): boolean
	return played >= GiftRules.LIGHT_AT
end

-- Whether the pet can be given now: both checks passed and not given before. The like is never asked for here.
function GiftRules.canClaim(state: State): boolean
	return state.favourite and state.group and not state.claimed
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

return table.freeze(GiftRules)
