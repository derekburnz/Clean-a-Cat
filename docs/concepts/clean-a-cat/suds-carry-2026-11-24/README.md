# Suds carry, R6, after #331 (2026-11-24)

Built from main at ee025c2, the merge of #331, as a local `rojo build`. The place was never saved or published.

## Setup
- These switches were on in the local place only: sudsWash, openingBox, sudsMascot, tutorialTrail, tutorialTip, spaPlot, scrubPrototype, customers, gameHud, recapCard and carryHold.
- The save was fresh.
- The avatar was R6. It was a default R6 rig made with `Players:CreateHumanoidModelFromDescription(HumanoidDescription.new(), Enum.HumanoidRigType.R6)` and placed as `StarterPlayer.StarterCharacter`.
  - The usual Game Settings avatar switch cannot be set from a script.
  - The rig was recoloured (skin, blue shirt) so the black kitten stands out.
- The opening played. I opened the box and used the "Pick up" prompt, then took both shots while Suds was held. Graphics quality was 21.

## Shots
1. `1-carry-default-camera-behind.jpg`: the default camera, 11.9 studs behind the player and 5.2 up. His face is hidden. Only his ear tips show, above the avatar's left shoulder.
2. `2-carry-front.jpg`: a camera 8 studs straight in front of the player, 1.5 up, looking at the chest. He lies across the forearms with his head at the avatar's left side and his face toward the camera, below the avatar's face.

## Measurements while held
All values are relative to the Torso: right, up, forward.

| What | Right | Up | Forward |
|---|---|---|---|
| Loaf pivot | -0.45 | -0.37 | +1.08 |
| Bounding-box centre (size 1.40 x 1.59 x 1.89) | -0.49 | +0.42 | +1.25 |
| His head (relative to the HumanoidRootPart) | -0.73 | +0.68 | +1.26 |

- His head sits 0.80 below the centre of the avatar's head.
- Orientation relative to the torso: yaw 90 degrees and roll 8 degrees, so his front faces the avatar's left, with the head end rolled up.
- From behind, his head is inside the torso's outline (the R6 torso is 2 studs wide, so its edge is at 1.0), so the body hides it.
