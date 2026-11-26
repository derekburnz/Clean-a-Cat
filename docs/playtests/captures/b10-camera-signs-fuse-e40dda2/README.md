# Camera (#670), build signs (PR 683), Fuse (PR 682) and the stray box, up to e40dda2

- Builds, each made with rojo and opened as an unsaved local place, one client, never saved or published:
  - d6fdf1b (PR 681 wall plates);
  - ee696a9 (adds PRs 682 and 683);
  - e40dda2 (adds PRs 684 and 685, the moved stray box).
- The camera code is the same on all three; only the stray box spot changed after ee696a9.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay and benchGrow. That includes cameraClear, tubBuilds, pets, petsWindow, crateWindow, workers and giftStand.
- Seeds, edited in the local place only: play 11:40, 5 stars, 50,000 coins, crates, Jo and Sam hired. For the sign checks also a running room build.
- iPhone 13 frame unless noted. Camera logged every frame for 3 s after each spawn.

## Camera
| Check | Result |
|---|---|
| R15 phone joins | PASS 11 of 11 (5 on d6fdf1b, 5 on ee696a9, 1 on e40dda2). The camera is already turned on the first logged frame (yaw 50) and the yaw never changes after that. At 2.0 s and 2.5 s it is at (3.3, 7.9, -0.1), facing the spa. No spin |
| R6 phone joins | PASS 2 of 2 (ee696a9) |
| Desktop joins | PASS, R15 1 of 1 and R6 1 of 1 (ee696a9) |
| cameraClear off | The plate stops the camera at (-5, 6.8, -0.1), but the picture sits 0.1 stud in front of it, so a grey wedge of the picture covers part of the view (picture 04). The spa shows around it |
| Respawns | FAIL, 1 or 2 in 5. On d6fdf1b 1 of 3 logged respawns ended with the picture in front at 2.0 and 2.5 s (picture 01). On ee696a9, 4 of 5 were fine and 1 ended with the picture in front (picture 03). The camera resets at about 0.33 s after a respawn |
| Backing into wall pieces | No climbing at any of the 8: every jump against them lands back at y 3.5. Camera, with the yaw facing the back wall: at the big picture (-5, -0.1) the camera pulls in to 1.8 studs and the spa shows. At (-19.5, -0.1) the camera sits inside the non-colliding picture and the view is a grey haze (picture 02). The side-wall pieces could not be put behind the camera reliably over MCP |
| Fresh opening | PASS, the same truck shot |
| Turning in the first 2 s | PASS, no snap back. On a respawn the drag began at 0.67 s and the yaw went smoothly to -152 |
| Console | PASS |

## Build signs (PR 683)
| Check | Result |
|---|---|
| Tapped build | PASS. A real tap on Build Garden gave "Garden / 24h 0m left", with the board at 23:59:58. 75 s later it read "23h 59m left" |
| Last minute and finish | FAIL. A seeded VIP Room build with 95 s left read "2m left" and stayed at "2m left" down to 2 s, while the board counted 1:35 to 0:02. At 0 the finished VIP Room replaced the site |
| After a rejoin | FAIL. A real rejoin is not possible on a local place, so I restarted with the same EndsAt. The Garden sign showed the right time ("23h 59m left"), but it did not count: still "23h 59m left" 65 s later, when it should read "23h 58m left" (picture 05). Signs drawn at the join never count down |

## Fuse (PR 682, real taps, phone)
| Check | Result |
|---|---|
| Fuse with three of a kind | PASS. Scrubby x4: a tap on Fuse made a star-2 Scrubby and left one Scrubby. The pet beside me (Bamboo) stayed |
| Picture and name taps | PASS. A tap on Scrubby's picture put it on me, and a tap on its name took it off |
| Long pen | PASS. With 6 cards a drag scrolls the list 71.5 px and the last row ends at the list's bottom edge (322 of 322) |
| Desktop | Not run |
| Console | PASS |

## Stray box (e40dda2)
| Check | Result |
|---|---|
| Place | PASS. The box is at (11.4, -2.4), plot spot (16.4, 7.6), 0.1 stud from the side wall and 0.9 from the back wall, 5.2 studs from the Garden gate (picture 06) |
| Path | PASS. A walk from the spawn to the Garden gate went straight through, and the path service finds a path |
| +10 reward | PASS. The first stray's wash took coins from 0 to 11 (+10 and +1 from the window) |
| Prompt | Not seen. After "Open the spa!" the stray went straight to the tub, and no prompt showed on the box in this flow |
