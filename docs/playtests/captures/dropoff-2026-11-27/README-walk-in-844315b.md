# Walk-in recheck for 871 on main 844315b (has PRs 992, 993 and 995): FAIL

This was an unsaved local Studio place built with rojo from origin/main 844315b2. Every off-by-default switch was on except toolCursor, streetLoadTest, exampleFeature and openingReplay, so bigSpa, wideStreet, counterLine and counterCrate were all on. I used a seeded save with BenchSize 6 and Jo and Sam hired, in the iphone_13 frame. I never touched dev or live.

Method: on the client, every 0.1 s, each customer's CounterCat was sampled. A part counts as showing when Transparency < 1 and LocalTransparencyModifier < 1. A customer counts as walking when their pivot is more than 0.25 studs (flat) from WalkTo. In about 60 s, the helpers took cats, which brought 2 newcomers (Mo, Rex) and several step-ups.

## What works
- Newcomer Mo walked in for 3.7 s (36 samples), and no CounterCat part showed while he walked. The hide added by 992 and 993 works for a plain walk-in.

## FAIL: every cat except place 1 is split in two
- Server: every CounterCat pivot is (-10.0, 3.4, -35.0), and all its parts are anchored (147 to 210 parts).
- Client: only the place 1 cat (Sunny) sits whole on its mat (149 of 149 parts on the spot). For places 2 to 6, only 1 to 38 parts sit on the mat. The other 125 to 172 parts of each cat (head, ears, eyes, legs, tail, mud, tangles) stay at about (-13.4, 4.1, -35.2). That is at counter height, out on the pavement in front of the spa door, beside the line.

| place | customer | parts on the spot | parts at about (-13.4, 4.1, -35.2) |
|---|---|---|---|
| 1 | Sunny | 149 | 0 |
| 2 | Bea | 1 | 148 |
| 3 | Theo | 6 | 143 |
| 4 | Kit | 16 | 125 |
| 5 | Rex (new) | 38 | 172 |
| 6 | Mo (new) | 5 | 142 |

- It shows for customers already there at join, for newcomers once they arrive, and after step-ups. While stepping up, Theo, Kit, Bea and Juno each showed for 15 to 32 samples, 13 to 22 studs from their mat. Newcomer Rex showed for 16 samples during his step-up.
- Pictures:
  - walk-in-844315b-mats-2-to-6-body-only.jpg: place 1 has a whole cat. Places 2 to 6 show small grey and blue body blocks, and the dark cat pieces sit out on the pavement behind the line.
  - walk-in-844315b-cat-parts-left-on-pavement-close.jpg and walk-in-844315b-cat-parts-pile-and-line.jpg: the pile of cat pieces floating by the door.
  - walk-in-844315b-six-at-window.jpg: the six customers at the window.
- Likely cause, for Gameplay to confirm: CustomerWalkController.seatCounterCat does a PivotTo to CounterSpotAt on the client, but most of the cat's parts end up back at the server's pivot. Something seems to move only part of the model, or the server's anchored part CFrames win.

Crate set-down and the walk-out at the mat: not judged, because the cats are split.
