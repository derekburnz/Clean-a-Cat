# Garden gate barrier (PR 734) on main bccd28f

## Setup
- The same unsaved local place as b16, one client, never saved or published.
- Brought up to bccd28f:
  - the Garden model from bccd28f, which adds two CleanACat_Area_Garden_Gate_Barrier slabs;
  - the client and shared files that changed since 064885b (CelebrateController, LeaveLinesController, UI/LeaveLines, UI init, LeaveLineRules, Moments, QuestRules);
  - the new leaveLines switch added to LiveFlags.
- Each barrier slab: 2.75 x 3.28 x 0.34 studs, turned 100 degrees along the open gate leaf, Transparency 1, CanCollide true, CanQuery false, CanTouch false. The top is at y 3.77, about 3.3 studs above the floor.
- iPhone 13 frame (touch, so Humanoid.AutoJumpEnabled is true).
- Seeded save with the Garden and VIP Room built.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay, benchGrow and cameraClear.
- Walks are Humanoid MoveTo walks, 2.5 to 4 s each.

| Check | Result |
|---|---|
| 1. Sideways into each open gate leaf, z 1.9, 2.4, 3.0, 3.6 and 4.1, from inside and from outside | FAIL on the phone. With auto-jump on (the phone default), walking into the slab makes the character jump (Jumping state, peak y 10.8, jump height 7.2) and clear it: from x 6 it lands at x 2.3 to 2.9 behind the left leaf, and from x 8 at x 11.3 to 11.7 behind the right one. That happened at z 3.0, 3.6 and 4.1. At z 1.9 and 2.4 it stopped at x 4.7 and 9.3. With auto-jump turned off, the slab stops every walk: inside it stops at x 4.7 to 4.8 and 9.2 to 9.3, and from outside at x 3.25 and 10.69. So the slab blocks walking, but at 3.3 studs any jump clears it (picture 01 mid-hop, picture 02 behind the left leaf afterwards) |
| 2. Gate in and out through the middle and at x 5.6 and 8.4, plus two diagonal walks | PASS. All through, about 0.5 s each. One diagonal walk out brushed the right side and jumped once, then went through |
| 2. The same while carrying a customer's cat (Take cat with the E key, CarryCat = arms) | PASS. In and out of the gate twice, still carrying. The carried copy has no solid parts |
| 3. Pet past the gate | PASS. The pet beside me (Pickle, no solid parts) stayed 2.7 studs away while I walked in and out and along both leaves. It was never held back by the slab |
| 3. Workers | Jo and Sam stayed at their pads by the tubs (z -4) for 40 s, and their washes never take them near the gate. The garden pet Scrubby sits still at (9.3, 4.8), about 0.7 studs past the end of the right slab, and does not move |
| 4. Camera by the gate frame (spa side, 2.5 studs out, yaw -30) | 35% one flat face (the frame side at 0.4 studs), the same as after PR 728 (picture 03). 33% tilted down. The mirror spot by the right frame is also 35%. The slab never stops the camera (CanQuery false) |
| Console | Only the known lines |

## Recheck on e3ed268 (PR 737, slabs 8.5 studs tall)
- The same place, with the Garden model from e3ed268. Each slab is now 2.75 x 8.5 x 0.34, with its top at y 8.99 (the floor is at 0.57). Phone frame, auto-jump on (the phone default), R15.

| Check | Result |
|---|---|
| Walking sideways into each leaf at z 1.9, 2.4, 3.0, 3.6 and 4.1, from inside and from outside, 3 tries each (60 walks) | PASS for walking. No auto-jump went over: every walk from inside stopped at x 4.6 to 4.9 and 9.1 to 9.4, and from outside at x 3.1 to 3.4 and 10.6 to 10.95. One case: at z 4.1, from behind the leaf (x 1.5 and 12.5), the walk slides round the leaf's free end with no jump and comes out at x 5.5 and 8.5, 3 of 3 each side. That is the open end of the leaf, not through it |
| Jump on the spot beside a slab (Space, standing still), 2 tries | PASS. Up and down on the spot |
| Jump while moving into a slab (A or D held with Space), 12 tries: 6 across the 4-stud gateway into the far slab, 6 from 1 stud away into the near slab | FAIL, 12 of 12 went over. The jump lands on top of the invisible slab (Landed at root y 10.2, then Running at y 11 on top) and walks off the far side. The landings were x -3 (left) and x 22 to 25 (right). The reason: an R15 jump lifts the HumanoidRootPart's bottom to about y 9.8, and R15 legs do not collide, so the root clears a top at 8.99 and stands on it. A character set on top stands there (picture 04, root at y 12). To stop a moving jump the slab needs to reach above about y 10.5, so 11 studs or more tall, or it could meet the gate's arch |
| Gate in and out (x 5.6, 7 and 8.4), and carrying a customer's cat twice in and out | PASS |
| Camera by the frame | 35% (33% tilted), the same at the right frame. Unchanged |
| Pet and workers | Unchanged by a height change. The pet beside the player has no solid parts, and the workers never come near the gate (checked on bccd28f) |
| Console | Only the known lines |

## Recheck on ebf6489 (PR 742, slabs 12 studs tall, top y 12.5)
- The same place with the Garden model from ebf6489. The gift changes in PRs 732 and 733 are not loaded; they don't touch the gate. Phone frame.
- Jumps were scripted, not pressed as keys: the player controls were turned off, then Humanoid:MoveTo toward a point past the slab, with Humanoid.Jump set 0.1 to 0.25 s in.
- The tries:
  - into each slab from 1 stud away and across the 4-stud gateway, at z 2, 3 and 4;
  - from behind each leaf back toward the gateway;
  - double jumps from beside each post, whose 0.7 x 0.7 caps at y 4.94 are the highest place a player can stand near the gate.
- Walks used the qaWalk helper.

| Check | Result |
|---|---|
| Moving jumps, R15, 20 tries (14 left the ground) | PASS. None got onto or over a slab. The highest root reached y 12.1, below the slab top at 12.5. One try from behind the right leaf at z 3.5 came out into the gateway, but it went round the leaf's free end (the slab ends at z 4.3) and not over it |
| Moving jumps, R6, 20 tries (17 left the ground) | PASS. None got onto or over a slab; the highest root reached y 11.0. A jump can land on a post cap (root about y 8), but a second jump from there does not reach the slab top |
| Gate in and out with qaWalk, 3 times | PASS: 9 of 9 walks reached by path, 0.1 to 1.1 s |
| Carrying a customer's cat (Take with E), in and out twice | PASS: 6 of 6 walks reached by path, still carrying |
| Camera by the frames | 35% left, 33% tilted, 35% right. Unchanged |
| Console | Only the known lines |
