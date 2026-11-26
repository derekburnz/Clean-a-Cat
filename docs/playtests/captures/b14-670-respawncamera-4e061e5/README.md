# #670 second respawn camera retest (PR 709, switch respawnCamera) on main 4e061e5

- Fresh rojo build, unsaved local place, one client, never saved or published.
- Switches: every key in LiveFlags.OFF_BY_DEFAULT on, including spawnSide, spawnView and respawnCamera, except cameraClear (off), toolCursor, streetLoadTest, exampleFeature, openingReplay and benchGrow.
- Seeded save: play 11:40, Jo and Sam hired. iPhone 13 frame unless noted.
- Camera and character yaw were logged every frame for 6 s per spawn. PASS meant: the camera within 20 degrees of the character's facing by 2.0 s and through 6.0 s, and the spa showing at 2.0, 2.5, 5.0 and 6.0 s.

| Case | Result |
|---|---|
| 8 respawns, LoadCharacter | FAIL, 8 of 8. The character respawns turned (yaw 90); the camera stays at yaw -3 to 3 on the back wall at about (-5, 6.9, -0.1), 87 to 93 degrees off, for the whole 6 s. 2 of 8 had the wall picture 0.1 stud in front (one from 2.0 s to 6.0 s, one on the first frame). Picture 01 |
| 2 respawns by health 0 | FAIL. The camera ends at yaw 49, 40 to 41 degrees off. The first frames sat at (5.4, 3.8, 1.2) and (5.7, 4.2, 2.7) |
| Respawn spam, 5 in 10 s | No stuck or spinning camera: it stays Custom on the new character, steady at yaw 3. But it is not behind the character (89 to 93 degrees off) |
| Why | With a print added in the local copy only, RespawnCameraController's check fires and asks to turn the camera 6 times per respawn, but activeCamera() returns nil (the PlayerModule's GetCameras() gives no activeCameraController here). So it takes the fallback, which sets Camera.CFrame at RenderPriority.Camera - 1, and Roblox's camera module overwrites it in the same frame |
| 6 R15 phone joins | PASS 6 of 6. Behind the character from the first frame (0.05 to 0.28 s), 0 degrees off through 6 s |
| 6 R6 phone joins | PASS 6 of 6 (first frame 0.85 to 1.39 s, the same) |
| Desktop joins | PASS R15 1 of 1 and R6 1 of 1 |
| Turning at 1 s and 3 s after a respawn | PASS. No jump at the first touch; the drag turns the camera smoothly and it stays |
| Fresh opening | PASS, the same truck shot |
| Console | PASS, nothing new (the prints were my own, local only) |
