# Wash framing at every station on 5781142 (includes #416)

Local unsaved build of 5781142 on the iPhone 13 frame (750x390), which stands in for the iPhone 12. Switches as in the ec29d4f pass. washScene was on for the first run and off for the second.
- Fill: the cat's bounding box on screen, as a share of the screen height (the same measure as earlier runs).
- Angle: between the cat's facing and the line from the cat to the camera, flat on the floor; 0 means face on.
- Rays: cast from the camera to the cat's head, body and front leg; each entry is what the ray hits first.

## washScene on (field of view 50)
| Station | Angle | Fill | Rays: head / body / paw | Step dots vs ears | Within 0.5 studs of camera |
|---|---|---|---|---|---|
| Pawdicure | 0 | 0.59 | cat / cat / cat | clear, 4 px | none (camera y 7.43) |
| Bubble Bath | 2 | 0.63 | cat / cat / cat | clear, 0 px (touching) | none (camera y 7.31) |
| Tub, Suds | 2 | 0.58 | cat / cat / cat | clear, 5 px | none (camera y 7.31) |
| Tub, customer | 2 | 0.57 | cat / cat / cat | clear, 6 px | none |
| Tub, Pick a bow | 2 | 0.59 | cat / cat / cat | clear, 4 px | none |

- Every station is now face on (pictures 1 to 4).
- The tub moved a little from ec29d4f: fill 0.57 to 0.58 (it was 0.54), and the dot gap is 5 to 6 px (it was 14).
- Bubble Bath at 0.63: the suds parts and fluff make the box bigger. It is 2.64 x 2.80 x 2.63 studs there against 2.27 x 2.82 x 1.90 in the tub. Parts at the box edge: PH_Suds1, PH_Suds4, Fluff09.
- Bow: the worn bow changes the box by 0.02 studs (2.81 to 2.83), so it makes no real difference. The bows at Pick a bow are at GUI 133,186 / 163,247 / 187,294, all on screen.

## washScene off (field of view 70, the old close-up)
| Station | Angle | Fill | Rays | Step dots vs ears |
|---|---|---|---|---|
| Pawdicure | 0 | 0.37 | cat / cat / cat | overlap 54x11 px |
| Bubble Bath | 0 | 0.38 | cat / cat / cat | overlap 54x10 px |
| Tub | 0 | 0.36 | cat / cat / cat | overlap 54x9 px |

## Phone blur 0.3 (#416)
- With washScene on, the iPhone frame now gets the blur on the low tier ("blur on" logged through the wash).
- Frame time over 10 s of wash on this PC:
  - blur on: average 239.8 fps, 1% low 143.3 fps, worst 10.0 ms;
  - washScene off, no blur: average 239.8 fps, 1% low 143.1 fps, worst 13.0 ms.
- Studio here caps at 240 fps, so the blur's cost doesn't show on this PC.

## Carry
- Reset while carrying: the cat is back in the arms 5.6 s after the reset, which includes the respawn.
- "Wash next" between customers: shown for 13.9 s, from just after the photo until "Take cat" appears.
