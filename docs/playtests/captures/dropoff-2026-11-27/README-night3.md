# Night checks 2026-11-27: 991, 884, 871 (counter and leave), 948

Unsaved local Studio places built with rojo from origin/main. Every off-by-default switch was on except toolCursor, streetLoadTest, exampleFeature and openingReplay. I used a seeded save with Jo and Sam hired, in the iphone_13 frame. I never touched dev or live.

## 991 recap, main 844315b: PASS
recap-991-nine-rows-iphone13-844315b.jpg shows 9 coin rows, two to a line. Next cat is 109 x 45 px, centre y 282.0, bottom 304.5. The total's centre is at y 282.0. The GUI area is 330 tall. The rows came from a PhotoPaid sent from the server with the uigate RecapRows values, after a real hand wash up to the photo step.

## 884 helpers fetch
- main 844315b: FAIL. helpers-884-fetch-lines-through-front-wall-844315b.jpg: every walk went to the server pivot of the CounterCat by the door, (-10, -35). Jo's straight line crossed ThirdTub.
- main 49f4f89 (PR 1009): helpers-884-route-49f4f89-lane-through-tools-board.jpg. Each stop is at its own place, 2.00 studs behind the cat, and the held cat stays on its mat (0.00 off it). The lane at x -6.0 crosses the CanCollide tools board (x -7.85 to -4.15, z -10.9, y 1.4 to 5.1). PR 1011 addresses this.

## 871 counter cats, main 208dc9d (PR 1008): PASS
counter-208dc9d-six-whole-cats.jpg shows every place at N of N parts on its mat. Newcomers showed 0 cat parts while walking in.

## 871 leave, main 7e033d1 (PR 1010): PASS
leave-7e033d1-kit-packed-cat-in-carrier.jpg: the PackedCat stays in the carrier, 1.47 studs from the leaving figure at every sample (Theo and Kit). On 208dc9d it was 16.4.

## 948 Stardust bows, main 208dc9d: PASS
Across 12 bow looks on Stardust_Sit and Stardust_Dirty_Sit, 0 bow parts overlap Prop or Prop2 (the wand).

## 884 close-out, main c2eeb78 (PR 1011): PASS
helpers-884-route-c2eeb78-clear.jpg: a top view with Jo in red and Sam in yellow. Both routes are (stand) > (x, -4.8) > (8.1, -4.8) > (8.1, -22.3) > (1.6, -22.3), with the lane between the player's tub and station 4. Each stop is at place 2's own spot: dX 0.00, dZ 2.60 behind the cat, 1.30 studs from the counter edge (z -23.60). Sweeping a 2 x 3.2 x 2 body box along every segment crossed nothing solid: no tools board, tub, stand or counter.

## 869 like how-to, main c2eeb78
like-howto-869-c2eeb78-desktop.jpg: after Like on the gift card, the how-to shows HeartOutline 98146759736466 (Thumb), TapDot 112847264343092 and the ring puff 113448726935917. All three report IsLoaded true and draw. A fresh PreloadAsync returns Failure while the account is suspended (403), so that result is NOT CONCLUSIVE. No hand images. The heart showed pink in every sample; I saw no grey phase.

## 883 Clover and Glitch portraits, main c2eeb78: PASS
portraits-883-pets-menu-c2eeb78.jpg and portraits-883-good-crate-c2eeb78.jpg: Clover 77963078642728 and Glitch 80341127367421 report IsLoaded true and FetchStatus Success in the Pets menu (73 px) and in the Good crate chances (62 px). Both draw in full colour. The save was seeded with one of each.

## 869 rerun, main fb23dab (PR 1013): PASS
HowTo.Art holds the frames Outline, Filled, Ring and Tap. No frame is named Hand, and all four images report IsLoaded true. Sampling every 0.1 s over 4.1 s gave grey 0.0 to 0.2, pink 0.3 to 1.4, grey 1.5 to 2.3, pink 2.4 to 3.5, grey 3.6 to 4.1. That is one loop of about 2.1 s with grey about 0.9 s and pink about 1.2 s, and exactly one heart showing at every sample (like-howto-869-fb23dab-loop.jpg). With the game's Less screen shake set On before tapping Like, all 31 samples were pink, and the tap dot and ring never moved (like-howto-869-fb23dab-reduced-motion.jpg).
