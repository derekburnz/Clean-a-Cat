--!strict
-- StandRules: how high above the floor a character's HumanoidRootPart sits when it stands, so code that places a
-- character on a spot (PlotService.standAt, FigureService) puts its feet on the floor for either body type.
-- An R15 body stands HipHeight below the bottom of its root part. An R6 body stands on two-stud legs, and its
-- HipHeight (0 by default) is an extra lift on top of them. Sync-Agent's Studio run on 0f020c9 found an R6 avatar
-- placed 2 studs into the street at the opening, because only HipHeight was counted.
local StandRules = {}

StandRules.R6_LEGS = 2 -- studs from the bottom of an R6 root part to the floor

-- The height of the root part's centre above the floor: `isR15` from Humanoid.RigType, `hipHeight` from
-- Humanoid.HipHeight, `rootHeight` the root part's Size.Y.
function StandRules.rootHeight(isR15: boolean, hipHeight: number, rootHeight: number): number
	local legs = if isR15 then hipHeight else StandRules.R6_LEGS + hipHeight
	return legs + rootHeight / 2
end

return StandRules
