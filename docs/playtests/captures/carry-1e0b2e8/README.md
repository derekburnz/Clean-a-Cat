# Carry on 1e0b2e8 (R6 loafOut6 0.3)

Local unsaved build of 25eb648, which includes 1e0b2e8, on the iPhone 13 device frame (750x390).
- R6: a local R6 rig as StarterCharacter, recoloured yellow and blue so the arms read in the pictures.
- R15: the default Studio avatar.

Suds was picked up from the box, and every rendered frame was sampled:
- standing: 4 s still after the pick up;
- walking: 12 to 13 s of continuous walking along the street, at a speed over 10.

Overlaps are the deepest point of the kitten's head or body inside either forearm box (Left/Right Arm on R6, Lower Arm on R15), in studs; a positive value is inside. Tail: the depth inside the right forearm box, where negative means clear.

| | R6 standing | R6 walking | R15 standing | R15 walking |
|---|---|---|---|---|
| frames | 237 | 661 | 240 | 715 |
| head vs arms, median / max | 0.310 / 0.329 | 0.313 / 0.401 | 0.234 / 0.253 | 0.315 / 0.365 |
| body vs arms, median / max | 0.239 / 0.239 | 0.304 / 0.363 | 0.170 / 0.170 | 0.229 / 0.252 |
| tail vs right forearm, max | -0.441 | -0.386 | -0.539 | -0.410 |
| carrier face covered by kitten (front frames) | 0% | 0% | not sampled | 0% |
| kitten face crossed by an arm (play camera) | not sampled | median 0%, max 13% | 68% | median 40%, max 58% |

- Soft ceiling 0.35: R6 walking goes over it, with head max 0.401 and body max 0.363. R15 stays under.
- The tail clears the right forearm on every frame in all four cases.
- R15 against the last run (head walking median about 0.31, max about 0.38; body 0.17 standing and 0.25 walking; tail clear): it matches.
- Ray grid from the play camera: the camera sits behind the carrier, so the kitten faces away from it. A "crossed" ray means the arm is between the camera and the back of his head, not over his face. On R15 the lower arm and hand sit in that line (68% standing). On R6 they don't (median 0%).
- Front: the carrier's face is never covered (0% in every front frame, picture 2).
- Missing pictures: the left sides, the R15 front, and an R6 standing sample from behind. Those captures timed out, and Studio's 3D view went black twice.

## Does he look held at the fingertips? (pictures 1, 3, 4, 5)
From the play camera, R6 (picture 1): he sits at the right shoulder, on the right forearm, in front of the chest. He reads as carried on the arm, not on the fingertips. R15 (pictures 4 and 5): he sits in front of the chest on both hands with the forearms out. The side view shows a small gap between him and the torso, so he looks held out in the hands rather than hugged. He is still not at the fingertips.
