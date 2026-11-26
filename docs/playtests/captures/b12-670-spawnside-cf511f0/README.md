# #670 retest with spawnSide and spawnView on main cf511f0

- Fresh rojo build, unsaved local place, one client, never saved or published.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on, including spawnSide and spawnView, except cameraClear (off for this retest), toolCursor, streetLoadTest, exampleFeature, openingReplay and benchGrow.
- Seeded save: play 11:40, Jo and Sam hired.
- Camera position, yaw, the part in the middle of the view and any part the camera sits in were logged every frame for 6 s after each spawn. Checked: the first frame and 2.0, 2.5, 5.0 and 6.0 s.

| Case | Result |
|---|---|
| R15 phone joins | PASS 6 of 6. Yaw 90 from the first frame, camera at (7.1, 8.2, -7.0) looking down the room, no yaw change in 6 s (picture 00) |
| R6 phone joins | PASS 6 of 6, the same |
| Desktop joins | PASS R15 1 of 1 and R6 1 of 1, the same |
| Respawns (LoadCharacter, phone) | FAIL. 8 of 8 put the character at (-5, 3.5, -7.3) facing -x (spawnSide), but the camera stays at yaw 0 against the back wall at (-5.0, 6.8, -0.1) for the whole 6 s. On 6 of 8 the middle of the view is the room (Tools board 12 studs away) with the back wall's plate at the camera; on 2 of 8 the wall picture is 0.1 stud in front (at 2.0 to 6.0 s on one, the first frame on another). Picture 01: a respawn with the camera on the back wall |
| Respawn by health 0 | The first frame is inside the back wall's band at (1.6, 3.2, 0.1) and (-0.4, 3.2, 0.1); the camera resets about 0.06 s later |
| Turning at 1 s and 3 s | PASS. No jump at the first touch; the drag turns the yaw smoothly (to -118 and -127) and it stays |
| Fresh opening | PASS, the same truck shot |
| Wall pieces | No climbing: three jumps against each of the 18 WallArt parts (the 8 pieces, some listed twice) all land at y 3.5. In the fresh session the character did not walk back into them, so the camera from inside a piece was not checked again |
| Console | PASS |
