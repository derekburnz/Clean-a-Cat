# Camera at the VIP Room and Garden doors, before and after PR 728 (#725)

- BEFORE: main 12cf771. AFTER: main 064885b (PR 728 merged).
- Both are the same unsaved local place, one client, never saved or published. For AFTER I loaded the six area models from 064885b (CleanACat_Area_VipRoom, VipLocked, VipBuilding, Garden, GardenLocked and GardenBuilding) into ReplicatedStorage.Assets. PR 728 changes nothing else in the game.
- iPhone 13 frame: 844x390, a 749x388 view inside the notch.
- Seeded save, edited in the local place only: VIP Room and Garden built, 50,000 coins, 5 stars, Jo and Sam hired.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay, benchGrow and cameraClear.
- Each view sets the character at the same spot and facing, aims the camera at the same yaw and pitch at the default zoom, and hands it back to the normal camera. The normal camera then settles where its occlusion puts it.
- Measuring:
  - Picture: my estimate of the screen share covered by flat fill.
  - Rays: 3,200 rays (80 by 40) across the view; the share that hits one single flat face within 6 studs of the camera.
  - A second ray checks whether the character is hidden.

## Views (same spot and angle before and after)
| Picture | View | Before | After |
|---|---|---|---|
| 01 | Inside the VIP Room, 5.5 studs in and 2.7 to the right of the door's middle, looking further in (yaw 139), level (pitch -4) | About 55% flat fill: the lilac back of the lining, the gold top and a cream strip. Rays: one pink face 32% at 1.3 studs, character hidden. The camera rests at (-6.9, 5.3, 1.0), in the door's edge | About 15%: a pink strip on the left. Rays: 15% at 0.3 studs, character in view. The camera pulls in to (-8.0, 5.2, 2.3), close behind the head, so the head fills the middle |
| 02 | Same spot, yaw 110, tilted down (pitch -35) | About 60%: a flat cream fill on the right third and a door leaf over the middle. Rays: one cream face 31% at 1.9 studs, character hidden. The camera sits at (-4.0, 9.0, 1.9), outside the room | 0%. Rays: 2% at most, character in view. The camera is at (-8.0, 6.1, 3.3) behind the head |
| 03 | Spa side of the VIP door, 2.5 studs out and 2.5 to the right of the middle, yaw -60, level | About 65%: pink and cream panels, character hidden. The camera ends inside the room's corner at (-20.0, 5.8, 3.6) | 0%. The camera stops at (-16.0, 5.5, 1.3), inside the door, and shows the character and the spa |
| 04 | Same spot, yaw 60, level | About 28%: a gold and cream wedge on the left (the wall art at 0.1 studs and the frame) | About 28%, unchanged. Rays: wall art 14% at 0.1 studs, frame 9% |
| 05 | Spa side of the Garden door, 2.5 studs out and 2.5 left of the middle, yaw -30, level | About 31%: a flat cream fill on the right. Rays: the door frame face 29% at 0.4 studs | About 35%, not fixed. Rays: the frame face 35% at 0.4 studs. The frame is solid now, and the camera rests against its side |

Wider sweep (rays only), yaw 40 to 200 and pitch -4 and -35:
- Inside the VIP Room, the character was hidden in 7 of 12 views before and 1 of 12 after. The one left is yaw 170, where the camera goes out through the open doorway.
- On the spa side of the VIP door: 1 of 10 hidden before, 0 of 10 after.
- On the spa side of the Garden door: the views are about the same before and after. The worst is 33 to 35% of the frame face at yaw -30, at both pitches.

## Walking through after PR 728 (Humanoid walks, 4 s each)
| Walk | Result |
|---|---|
| VIP door in and out through the middle | PASS, through both ways |
| VIP door frames, left and right, walking straight at them | PASS, solid: stopped at z -0.9 |
| VIP open leaves (the pink panels inside, 3.9 studs deep), walking along the room into them | PASS, solid: stopped at x -8.5 and -15.5 |
| Garden gate in and out through the middle | PASS |
| Garden frames, left and right | PASS, solid: stopped at z -0.9 |
| Garden open gate leaves (the white pickets turned 100 degrees) | FAIL: not solid. Walking sideways at z 3 went through the left gate leaf (x about 3.9) and on to x 2.27, and through the right one to x 11.73. The pickets have CanCollide false. Only the two posts at z 1.45 are solid |

## Console
Only the known lines.
