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
