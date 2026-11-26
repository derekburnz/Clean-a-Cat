# PR 690 on 92baa32; PRs 691 and 693 and #649 on b91bc6d

- Fresh rojo builds, unsaved local places, one client, never saved or published.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay and benchGrow. That includes cameraClear, helpersWindow, workers, staffRename, passes and washMeter.
- Seeds, edited in the local place only: play 11:40, coins, helpers.
- iPhone 13 frame unless noted. Also the iPad 10th generation preset (1179x819 view) and desktop.

## PR 690 (92baa32)
| Check | Result |
|---|---|
| Build sign | PASS. "3m left", then "2m left" at 118 s. After a restart with the same EndsAt it kept counting: 1m at 59 s, then 56s, 52s ... 3s. At 0 the finished VIP Room replaced the site |
| 8 respawns, 6 s each | FAIL, 3 of 8. The turn is held for 5 s. At 5.0 s the camera goes back to yaw about 0. On 3 of 8 it ends at (-5.0, 6.8, -0.1) with the picture 0.1 stud in front (picture 01, taken at (-4.86, 6.61, -0.11) 6.2 s after a respawn) |
| Turning at 1 s and 3 s | FAIL at the touch. When the finger goes down, the held turn drops back toward the picture (18 to -2 at 0.90 s; -38 to -3 at 2.96 s). Then the camera follows the drag smoothly and stays where it was turned |
| Seeded join | PASS. Yaw 50 from the first frame, the spa at 2.0, 2.5 and 6 s |
| Fresh opening | PASS, the same truck shot |
| Heart-bar leave | PASS. Bea's walk-off copy (CleanACat_Fx_Leaving) walked from (-10, -28) to (-17, -28) in 2.7 s. Leaves wait while a window is open: none for about 8 minutes under the check-in card, one 16 s after it closed |
| Console | PASS |

## PR 691 wash cheers (b91bc6d)
| Check | Result |
|---|---|
| Phone, Suds | PASS for the bar. Track 254-516 x 72-94, badge right edge 277. The largest pop, "Squeaky clean!" 124x20, at 335-459 x 74-94: 58 px clear of the badge, 57 px from the right end, 2 px top, 0 px bottom. "So fluffy!" 77x20 at 358-435. The cat's ears are about 13 px below the bar |
| Phone, step change | FAIL (small). For about 0.7 s between steps the side buttons show and the meter sits at y 25, so the buttons cover the badge and the left of the bar (picture 02) |
| iPad, normal cat | PASS. Track 442-764 x 54-82, badge 414-469. The largest pop, "Squeaky clean!" 149x24, at 543-692 x 56-80: 74 px clear of the badge, 72 px from the right end, 2 px top and bottom. The ears are well below |
| Gold text | PASS. #ffe98f with a 3 px #45226b outline reads on the pink (#ffb3d9), green (#7ee0b5) and lilac (#c9b6ff) fills |
| Percent comes back | PASS. About 1.3 s after each cheer, also with Reduced Motion on ("Less screen shake"), where the cheer shows at full size without the pop |
| Special cat | Not run. No special visitor came in these runs |

## #649 Show me bubbles, fresh first session (b91bc6d)
| Time | Bubble | Stayed |
|---|---|---|
| 121.1 | "Let's open the spa!" (OK!) | 6.0 s |
| 181.2 | "First customer!" (Show me) | 34.9 s, until the cat went in the tub |
| 254.5 | "New soap!" (Show me) | 6.1 s |
| 421.2 | "A gift for you!" (Show me) | 20.0 s |
| 501.5 | "Let's build!" (Show me) | 20.1 s |

- No other bubbles appeared up to 9:20. "Quests!" did not show after 6:00 in this run.

## PR 693 Helpers window (b91bc6d)
| Check | Result |
|---|---|
| Button before hiring | PASS. No Helpers button on a save with no helpers |
| Button after hiring | FAIL. Hiring Jo at the pad by tap (1,500 to 1,350 coins, Jo at the stand) set no WorkerLevel_Jo or WorkerMode_Jo, so no Helpers button appeared (picture 03). WorkerService's onHire does not call showWorkers; only a join or a pass does. On a seeded save with helpers the button shows |
| Takes | PASS. A tap cycles First in line to About to leave, and the stand prompt says the same. FAIL (small) on the phone: "Takes: About to leave" is cut to "About to leav" (picture 04). It fits on desktop |
| Level up | PASS. 200 coins, level 2, then 500, level 3. With 800 coins against 1,200 the server's notice "400 more coins" shows |
| Pencil and Rename | FAIL. The pencil opens Rename behind the Helpers window, on the phone and on desktop. Helpers' backdrop takes the taps on Rename's X (picture 05) |
| Unhired helper | PASS. "Hire at their pad · 1200 coins" for Sam |
| Lou | PASS. "See the pass" opens the Shop. With passes off the button is gone |
| Fit and text | PASS. Phone: card 645x246 at 52,48 in 749x330, text 14 px or more. Desktop: card 941x431, text 19 px or more |
| Console | PASS |
