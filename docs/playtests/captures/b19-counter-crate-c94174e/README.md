# Counter crate (PR 762), counter cards and counterLine on main c94174e

## Setup
- Build: main at c94174e, built with rojo and opened as an unsaved local place, one client. Never saved or published.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on except toolCursor, streetLoadTest, exampleFeature, openingReplay, benchGrow and cameraClear. That includes counterLine, counterCrate, counterCards, heartBar and bigSpa.
- Seeds, edited in the local place only: play 11:40, 5 stars, 5,000 coins, Jo and Sam hired, the Garden and VIP Room built.
- Frames:
  - iPhone 13 (844 x 390) with R15;
  - iPad 10th generation (1179 x 819 view) with R6, the rig swapped mid-play.
- Walks used the qaWalk helper. Takes and Put in tub used the E key, the steps the Studio test step, and the bow, photo, Settings and Close were real taps.
- A client logger recorded each customer's counter-cat attributes, the counter cat's and carrier's visible parts, the Take prompt and the local crate copies, by server time.

## Timings (seconds from CounterSetAt)
| Customer | Walk-up from appearing on the street | Carrier hidden, crate copy out | Cat copy out | Real cat sits | Crate gone | ReadyAt | Take cat shown |
|---|---|---|---|---|---|---|---|
| Sunny (phone) | 3.94 | +0.01 | | +1.60 | | +2.40 | +3.40 |
| Mo (phone) | 3.72 | +0.01 | | +1.60 | | +2.40 | +2.62 |
| Pip (phone) | 4.14 | +0.00 | +0.80 | +1.60 | +2.40 | +2.40 | (I was carrying) |
| Theo (iPad, R6) | 3.72 | +0.02 | +0.81 | +1.61 | +2.41 | +2.40 | +2.48 |
| Kit (iPad, R6) | 3.92 | +1.20 (a second crate) | +0.81 after its own | +2.79 | +3.59 | +2.40 | +2.81 after its own |

The Take cat prompt shows 0.1 to 1.0 s after ReadyAt, because the client scans every second.

## The seven QA steps
| Step | Result |
|---|---|
| 1. A newcomer walks up with the crate; it arcs onto the counter, the door opens, the cat walks out and sits, and the crate fades by ReadyAt | PASS for the sequence and the timings above (picture 01 on the iPad mid-sequence). FAIL for the place: every customer's CounterCrateSpot is the same CFrame, (4.8, 3.3, -26.62), behind place 3. So for a place 1 or place 2 customer the crate lands and the cat walks out behind place 3, then the real cat appears at its own place (-1.6 or 1.6) at +1.6 s. Theo (place 2) and Kit (place 3) both landed at x 4.8, 1.2 s apart (picture 01). It's a Gameplay fix (the spot it sets) |
| Take cat only after the cat sits; a tap before does nothing | PASS on the client: no Take prompt exists before ReadyAt. The server also refuses an early take (FigureService.counterSettled, checked by SpaService line 784). My own early RequestTakeCat at set +0.5 s was refused, but so was the same ask after ReadyAt (my argument list may not match the client's ask), so that live test proves nothing either way |
| 2. Rejoin during and after the sequence | NOT RUN. A local place can't rejoin |
| 3. A leaver walks off with the cat in the crate | PASS. The walk-off copy (CleanACat_Fx_Leaving) has the carrier showing (258 of 314 parts) with PackedCat inside (107 of 135 parts showing), still the same 1.3 s later |
| 4. A served customer's crate doesn't reappear | PASS. When Jo or Sam take a customer, the carrier shows for one frame (about 0.04 s) and then the figure is removed. No crate copy is left behind |
| 5. Reduced Motion (Settings, Less screen shake on, picture 03): fade only | PASS. The crate copy appears straight on the counter at +0.00, with no arc and no cat walk. It fades from +1.76 to +2.24 and is gone at +2.40 |
| 6. Console | PASS. Only the known lines |
| 7. 20 minutes with helpers, client memory flat | PASS. Over 20 minutes, sampled once a minute: total 3,424 to 3,450 MB (Studio's process), LuaHeap 813 to 841 MB, Instances 114.6 to 115.3 MB, workspace 8,058 to 8,765 instances, no growth. Crate copies were 0 between sequences |

## Counter cards (counterCards)
| Check | Result |
|---|---|
| A card over each counter cat | FAIL. Newcomers get no card. CounterCardController.add runs when the CounterCat is parented to the figure, but CounterPlace is set after that, so onCounter is false and nothing checks again. Cards showed only after I turned counterCards off and on (rebuild), and newcomers after that got none: phone, 1 card for 3 cats (picture 02); iPad, 1 card for 3 cats. Fix: also listen for CounterPlace being set, or re-check in add a frame later |
| Text 14 px or more | There is no text on the card, only the owner chip and the heart bar. The card draws at 42 x 12 to 44 x 13 px on the phone from the player's spot (6 studs) and 77 x 23 px on the iPad |
| Nothing overlaps the HUD | PASS for the cards. On both frames the Starter Pack offer panel on the right covers part of the counter's right end (picture 01). That panel is the HUD's own |
