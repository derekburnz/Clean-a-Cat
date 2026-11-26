# #670 respawn camera retest (PR 704, switch respawnCamera) on main fe114a4

- Fresh rojo build, unsaved local place, one client, never saved or published.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on, including spawnSide, spawnView and the new respawnCamera, except cameraClear (off), toolCursor, streetLoadTest, exampleFeature, openingReplay and benchGrow.
- Seeded save: play 11:40, Jo and Sam hired. iPhone 13 frame unless noted.
- Camera position and yaw, the character's yaw and the part in the middle of the view were logged every frame for 6 s per spawn. Checked: the first frame and 2.0, 2.5, 5.0 and 6.0 s.

| Case | Result |
|---|---|
| 8 respawns, LoadCharacter, switch on | FAIL, 8 of 8. The character respawns turned (yaw 90), but the camera stays at yaw -22 to 1 on the back wall at about (-5, 6.8, -0.1), 89 to 108 degrees off the character, for the whole 6 s. 7 of 8 still show the room past the wall; 1 starts with the camera on the wall art (first frame at (-5.0, 6.9, 0.1)). Picture 01 |
| 2 respawns by health 0, switch on | FAIL. The camera keeps its old yaw (-53 and -59), 143 and 149 degrees off the character. The room shows |
| 3 respawns, switch off (baseline) | The camera keeps whatever yaw it had (130, 95 and 156), 41, 5 and 67 degrees off the character |
| 6 R15 phone joins | PASS 6 of 6. Yaw 90 with the character from the first frame, at (7.1, 8.2, -7.0), no change in 6 s |
| 6 R6 phone joins | PASS 6 of 6, the same |
| Desktop joins | PASS R15 1 of 1 and R6 1 of 1 |
| Turning at 1 s and 3 s | PASS. No jump at the first touch; the drag turns the camera smoothly and it stays |
| Fresh opening | PASS, the same truck shot |
| Console | PASS |
