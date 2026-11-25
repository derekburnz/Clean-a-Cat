# Audio gate

Written by `.claude/skills/audio-pipeline/scripts/audio_gate.py` for `assets/clean-a-cat/audio`. Do not edit by hand; rerun the script. Budgets: audio-pipeline section 5. PASS means measured clean, not that it sounds right: a person still listens.

47 files: 46 PASS, 1 WARN, 0 FAIL.

| file | kind | s | ch | Hz | KB | LUFS | peak dBTP | lead ms | seam | verdict | notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `music/CleanACat_Music_SpaA.ogg` | music | 83.48 | 2 | 48000 | 1615 | -18.0 | -3.2 | - | listen | WARN | level changes -16 -> -29 dB across the seam (fade or gap) |
| `music/CleanACat_Music_SpaB.ogg` | music | 96.00 | 2 | 48000 | 1577 | -18.0 | -5.2 | - | ok | PASS |  |
| `sfx/CleanACat_Sfx_BowPop.ogg` | sfx | 0.12 | 1 | 48000 | 5 | - | -3.0 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_BowTie.ogg` | sfx | 0.45 | 1 | 48000 | 8 | -15.3 | -3.2 | 3 | - | PASS |  |
| `sfx/CleanACat_Sfx_BoxRustle.ogg` | sfx | 0.50 | 1 | 48000 | 8 | -15.9 | -2.3 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_BoxThud.ogg` | sfx | 0.40 | 1 | 48000 | 7 | -21.5 | -2.6 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_BrushSwish_1.ogg` | sfx | 0.28 | 1 | 48000 | 7 | - | -2.8 | 2 | - | PASS |  |
| `sfx/CleanACat_Sfx_BrushSwish_2.ogg` | sfx | 0.28 | 1 | 48000 | 7 | - | -1.8 | 2 | - | PASS |  |
| `sfx/CleanACat_Sfx_BrushSwish_3.ogg` | sfx | 0.28 | 1 | 48000 | 7 | - | -2.3 | 2 | - | PASS |  |
| `sfx/CleanACat_Sfx_BubblePop_1.ogg` | sfx | 0.09 | 1 | 48000 | 4 | - | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_BubblePop_2.ogg` | sfx | 0.09 | 1 | 48000 | 4 | - | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_BubblePop_3.ogg` | sfx | 0.09 | 1 | 48000 | 4 | - | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_BuildDone.ogg` | sfx | 1.40 | 1 | 48000 | 20 | -16.4 | -3.0 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_CarryPurr.ogg` | sfx | 2.64 | 1 | 48000 | 37 | -29.7 | -5.9 | 3 | - | PASS |  |
| `sfx/CleanACat_Sfx_CatLeave.ogg` | sfx | 1.00 | 1 | 48000 | 13 | -15.0 | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_ClawSnip.ogg` | sfx | 0.09 | 1 | 48000 | 4 | - | -1.0 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_CollarJingle.ogg` | sfx | 0.90 | 1 | 48000 | 10 | -14.2 | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_CrateDrop.ogg` | sfx | 0.80 | 1 | 48000 | 10 | -20.3 | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_CrateOpen.ogg` | sfx | 0.90 | 1 | 48000 | 13 | -14.9 | -2.4 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_DryerHum.ogg` | sfx | 2.00 | 1 | 48000 | 24 | -14.6 | -3.2 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_FoamDrop.ogg` | sfx | 0.70 | 1 | 48000 | 9 | -18.8 | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_FoamSwell.ogg` | sfx | 0.85 | 1 | 48000 | 14 | -16.8 | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_FurShake.ogg` | sfx | 0.75 | 1 | 48000 | 12 | -21.8 | -3.1 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_HeartLow.ogg` | sfx | 0.60 | 1 | 48000 | 6 | -13.7 | -3.0 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_Meow_1.ogg` | sfx | 0.32 | 1 | 48000 | 7 | - | -2.8 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_Meow_2.ogg` | sfx | 0.30 | 1 | 48000 | 7 | - | -3.0 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_Meow_3.ogg` | sfx | 0.22 | 1 | 48000 | 6 | - | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_MudPlop.ogg` | sfx | 0.22 | 1 | 48000 | 6 | - | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_PetReveal.ogg` | sfx | 1.50 | 1 | 48000 | 20 | -16.0 | -2.8 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_Purr_1.ogg` | sfx | 1.64 | 1 | 48000 | 23 | -26.9 | -2.9 | 2 | - | PASS |  |
| `sfx/CleanACat_Sfx_Purr_2.ogg` | sfx | 1.74 | 1 | 48000 | 25 | -26.9 | -3.0 | 3 | - | PASS |  |
| `sfx/CleanACat_Sfx_RevealChime.ogg` | sfx | 0.92 | 1 | 48000 | 10 | -15.5 | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_RinseLoop.ogg` | sfx | 2.00 | 1 | 48000 | 28 | -13.5 | -2.6 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_SpongeLoop.ogg` | sfx | 2.00 | 1 | 48000 | 25 | -15.9 | -3.4 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_StarUp.ogg` | sfx | 1.30 | 1 | 48000 | 20 | -15.0 | -3.2 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_StepChime.ogg` | sfx | 0.70 | 1 | 48000 | 11 | -15.6 | -2.7 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_TruckBump_1.ogg` | sfx | 0.50 | 1 | 48000 | 8 | -19.7 | -3.2 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_TruckBump_2.ogg` | sfx | 0.50 | 1 | 48000 | 10 | -20.2 | -3.1 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_TruckDoor.ogg` | sfx | 0.45 | 1 | 48000 | 7 | -25.0 | -3.1 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_TruckHonk.ogg` | sfx | 0.55 | 1 | 48000 | 6 | -9.7 | -2.8 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_TruckRumble.ogg` | sfx | 2.00 | 1 | 48000 | 23 | -14.8 | -3.1 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_VisitorChime.ogg` | sfx | 1.30 | 1 | 48000 | 18 | -14.4 | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_WorkerDone.ogg` | sfx | 0.50 | 1 | 48000 | 7 | -16.6 | -2.9 | 0 | - | PASS |  |
| `ui/CleanACat_Ui_Camera.ogg` | ui | 0.16 | 1 | 48000 | 5 | - | -3.0 | 0 | - | PASS |  |
| `ui/CleanACat_Ui_CheckIn.ogg` | ui | 0.80 | 1 | 48000 | 9 | -15.6 | -2.7 | 0 | - | PASS |  |
| `ui/CleanACat_Ui_Click.ogg` | ui | 0.05 | 1 | 48000 | 4 | - | -3.0 | 0 | - | PASS |  |
| `ui/CleanACat_Ui_QuestDone.ogg` | ui | 0.70 | 1 | 48000 | 10 | -14.4 | -2.7 | 0 | - | PASS |  |
