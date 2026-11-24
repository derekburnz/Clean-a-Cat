# Game HUD captures, 2026-11-24

What: the game HUD from #221 (coin counter, wash step bar, tool tray) at two moments of the first wash, on four simulated devices. There is also a second Xbox One set with `comfortSettings` on.

Build: main at 5989408, which includes #221 and #222. The spa room rework in #227 merged afterwards, so the room in these shots is the earlier one.

How:
- A fresh place built with `rojo build` and opened in Studio. It was never saved or published.
- Switches `spaPlot`, `customers`, `scrubPrototype` and `gameHud` were set as LiveFlag attributes from the server during Play. The flags workflow was not used.
- Devices came from the Studio Device Simulator at actual resolution.
- The camera was held over the player's shoulder at the tub, so every shot frames the same scene.
- Moments:
  - Step 1 mid-wash: 7 of the 20 mud patches were scrubbed.
  - Step 4: the scrub, brush and bow were all done with mouse input and the camera button was waiting.
- No account names are visible in any shot.

| File | Size | What it shows |
|---|---|---|
| step1-iphone14.jpg | 844 x 390 | "Step 1 of 4 · Scrub the mud" with the first pip lit, coins 0, sponge slot lit. The tray sits between the thumbstick and the jump button. A grey see-through band covers the lower left from Menu down to the thumbstick. It is gone in the step 4 shot, so it looks like a passing touch overlay. |
| step1-ipad10.jpg | 1180 x 820 | The same layout, roomier. The tray clears the thumbstick and the jump button. |
| step1-xboxone.jpg | 1920 x 1080 | The same layout. Menu stays 120 x 52, small for a TV. The coin count ends 23 px from the right edge, inside a 5% TV-safe margin. |
| step1-averagewindows.jpg | 1366 x 768 | The same layout with no touch controls. |
| step1-xboxone-comfort.jpg | 1920 x 1080 | comfortSettings on. Everything moves inside the 5% TV margin: steps at y 57, coins end 119 px from the right, tray ends 132 px from the bottom. Menu grows to 160 x 68 at x 112. |
| step4-iphone14.jpg | 844 x 390 | "Step 4 of 4 · Take the photo" with three ticked pips and the fourth lit. Sponge, brush and bow slots are dimmed and the camera slot is lit. The cat wears the mint bow. |
| step4-ipad10.jpg | 1180 x 820 | The same moment on the iPad. |
| step4-xboxone.jpg | 1920 x 1080 | The same moment on the Xbox, comfortSettings off. |
| step4-averagewindows.jpg | 1366 x 768 | The same moment on Windows. |
| step4-xboxone-comfort.jpg | 1920 x 1080 | The same moment with comfortSettings on, matching the step 1 comfort shot. |

Measured HUD boxes (x,y and w x h in pixels, below the 58 px top inset):

| Device | Viewport | Step bar | Step text height | Coins | Tray | Tray slot | Menu |
|---|---|---|---|---|---|---|---|
| iPhone 14 | 750 x 390 | 271,6 208 x 49 | 19 | 667,8 61 x 36 | 249,242 252 x 67 | 51 x 57 | 16,93 120 x 52 |
| iPad 10th gen | 1180 x 820 | 444,6 291 x 67 | 27 | 1080,8 77 x 44 | 420,647 339 x 92 | 70 x 79 | 16,248 120 x 52 |
| Xbox One | 1920 x 1080 | 752,6 415 x 96 | 39 | 1790,8 107 x 62 | 720,870 478 x 130 | 98 x 111 | 16,341 120 x 52 |
| Xbox One, comfort | 1920 x 1080 | 752,57 415 x 96 | 39 | 1694,59 107 x 62 | 720,818 478 x 130 | 98 x 111 | 112,348 160 x 68 |
| Average Windows | 1366 x 768 | 510,6 345 x 78 | 32 | 1255,8 89 x 51 | 486,581 392 x 106 | 81 x 91 | 16,229 120 x 52 |

The step bar is a few pixels wider at step 4 because its text is longer: 214, 302, 432 and 359 px wide.

Notes for the HUD owner:
- The iPhone 14 tray slots are 51 x 57, above the 44 px minimum touch target.
- The coin count sits flush in the top right corner when comfortSettings is off on the Xbox.

Console: no script errors. Only these lines appeared:
- the usual no-DataStore notes for a local place;
- "rbxassetid://203785492 asset type does not match", three times. That id is not in the repo.
