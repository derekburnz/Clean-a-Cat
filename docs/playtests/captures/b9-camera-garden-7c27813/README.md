# #571, camera (PR 673) and Garden (PR 675) on 7c27813

- Builds: #571 on 6b09fd6 (PR 672); camera and Garden on 7c27813 (PRs 671 to 675). Each was built with rojo and opened as an unsaved local place, one client. Never saved or published. iPhone 13 frame unless noted, real taps unless noted.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay and benchGrow. That includes cameraClear, tubBuilds, pets, petsWindow, crateWindow, workers, lineReuse, giftStand and askQueue.
- Seeds, edited in the local place only: play 11:40, 5 stars, coins, crates, Jo and Sam hired. For the built Garden also stations Garden and VipRoom, and all six special cats washed.

## #571 (6b09fd6)
- Heart bars cut to a quarter. Line figures logged on every rendered frame for about 9.5 minutes (33,762 frames).
- The line was never below 3 or above 4.
- 12 worker takes: on 10, 4 figures for 1 frame (13 to 17 ms), with the newcomer at the back before the taken figure goes; on 2, a same-frame swap. LineLeaving was never set on a taken figure.
- 13 heart-bar leaves: LineLeaving true on the leaver, 4 figures for 1 frame (10 of them) or 2 frames (3 of them).

## Camera (PR 673)
| Check | Result |
|---|---|
| Seeded join, first frame | FAIL, intermittent. 7 of 9 joins fine (cameraClear turns 50 degrees from frame 1; the camera settles at 3.3, 7.9, -0.1). 2 of 6 R15 phone joins: the camera stayed at 4.2, 8.2, 0.8, inside the solid back wall (1 stud thick, z 0 to 1), for the whole 4 s (picture 01; a good join is picture 00) |
| Beacon from the spawn | 37 px at 33.7 studs on the phone, 30 px on desktop, nothing in front, when the view is clear |
| Truck shot | PASS, same framing as on 25 Nov |
| Turning in the first 2 s | PASS, no snap back while turning. On a respawn the camera went back to the blue picture at 0.33 s before I turned it |
| Console | PASS |

## Garden (PR 675)
| Check | Result |
|---|---|
| Gate | PASS. "Garden / 25000 coins" on the gate's screen. The barrier stops the player in the doorway |
| Building site | FAIL. It shows "Garden / Building" with no time left. EndsAt is set, and only the board prompt's hidden text carries 23:59:44 (picture 02) |
| Finished Garden | PASS. GardenArea with 8 spots, 195 parts |
| Pen pets at 0.7 | PASS. The pet beside the player is never in the garden. All garden pets are at scale 0.70. Two sit cleanly; Cozy on play spot 3 sits in the tunnel's mouth, half hidden (picture 04) |
| Crate and fuse | PASS. The garden redraws in the same frame as the crate count changes, and after a fuse (3 Cozy into one star-2 Cozy) |
| Fuse button | FAIL (Pets window). The card's Tap button lies over the Fuse button, so a tap on Fuse puts the pet on or off you instead of fusing (picture 03). I fused through RequestFusePets, which the button sends |
| Pets off | PASS. With pets turned off live, the garden stays and is empty; on again, its 3 pets return |
| Speed (PC, Studio, quality 21, capped at 240 fps) | Plot1 3,144 parts (stations 1,429: VIP Room 886 with 6 residents, Garden 195). 240 fps, mean 4.17 ms, worst 8.35 ms, 0 frames over 14 ms in three 3 s samples. Draw calls 151 and 148,733 triangles at the spawn view (the interim flags are 150 and 200,000), 120 and 127 at the Garden and VIP doors |
| Console | PASS |

## Camera recheck on 259c086 (PR 676)
- The 7c27813 place with CameraClearController from 259c086 (the only file PR 676 changes). Per-frame camera log for 3 s after each spawn.
- 6 seeded R15 phone joins: PASS 6 of 6. The camera is already turned on the first logged frame (yaw 50, or 70 once), and the yaw never changes again. At 2.0 s and 2.5 s it is at (3.3, 7.9, -0.1), or (6.3, 8.2, -2.9) on the yaw-70 join, facing the spa. No spin.
- 5 respawns (LoadCharacter): FAIL. On each, the camera is held clear for the 2 s window. It goes back to yaw about 0 inside the blue decor picture at 2.0 s and stays there, at (-5, 6.7, 0.1) (picture 05).
- R6 and desktop: not run on 259c086, left for the PR 681 rerun.
