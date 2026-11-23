# Audio gate

Written by `.claude/skills/audio-pipeline/scripts/audio_gate.py` for `assets/clean-a-cat/audio`. Do not edit by hand; rerun the script. Budgets: audio-pipeline section 5. PASS means measured clean, not that it sounds right: a person still listens.

21 files: 20 PASS, 1 WARN, 0 FAIL.

| file | kind | s | ch | Hz | KB | LUFS | peak dBTP | lead ms | seam | verdict | notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `music/CleanACat_Music_SpaA.ogg` | music | 83.48 | 2 | 48000 | 1615 | -18.0 | -3.2 | - | listen | WARN | level changes -16 -> -29 dB across the seam (fade or gap) |
| `music/CleanACat_Music_SpaB.ogg` | music | 96.00 | 2 | 48000 | 1577 | -18.0 | -5.2 | - | ok | PASS |  |
| `sfx/CleanACat_Sfx_BowPop.ogg` | sfx | 0.12 | 1 | 48000 | 5 | - | -3.0 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_BrushSwish_1.ogg` | sfx | 0.28 | 1 | 48000 | 7 | - | -2.8 | 2 | - | PASS |  |
| `sfx/CleanACat_Sfx_BrushSwish_2.ogg` | sfx | 0.28 | 1 | 48000 | 7 | - | -1.8 | 2 | - | PASS |  |
| `sfx/CleanACat_Sfx_BrushSwish_3.ogg` | sfx | 0.28 | 1 | 48000 | 7 | - | -2.3 | 2 | - | PASS |  |
| `sfx/CleanACat_Sfx_BubblePop_1.ogg` | sfx | 0.09 | 1 | 48000 | 4 | - | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_BubblePop_2.ogg` | sfx | 0.09 | 1 | 48000 | 4 | - | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_BubblePop_3.ogg` | sfx | 0.09 | 1 | 48000 | 4 | - | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_DryerHum.ogg` | sfx | 2.00 | 1 | 48000 | 24 | -14.6 | -3.2 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_FurShake.ogg` | sfx | 0.75 | 1 | 48000 | 12 | -21.8 | -3.1 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_Meow_1.ogg` | sfx | 0.32 | 1 | 48000 | 7 | - | -2.8 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_Meow_2.ogg` | sfx | 0.30 | 1 | 48000 | 7 | - | -3.0 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_Meow_3.ogg` | sfx | 0.22 | 1 | 48000 | 6 | - | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_MudPlop.ogg` | sfx | 0.22 | 1 | 48000 | 6 | - | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_Purr_1.ogg` | sfx | 1.64 | 1 | 48000 | 23 | -26.9 | -2.9 | 2 | - | PASS |  |
| `sfx/CleanACat_Sfx_Purr_2.ogg` | sfx | 1.74 | 1 | 48000 | 25 | -26.9 | -3.0 | 3 | - | PASS |  |
| `sfx/CleanACat_Sfx_RevealChime.ogg` | sfx | 0.92 | 1 | 48000 | 10 | -15.5 | -2.9 | 0 | - | PASS |  |
| `sfx/CleanACat_Sfx_SpongeLoop.ogg` | sfx | 2.00 | 1 | 48000 | 25 | -15.9 | -3.4 | 0 | - | PASS |  |
| `ui/CleanACat_Ui_Camera.ogg` | ui | 0.16 | 1 | 48000 | 5 | - | -3.0 | 0 | - | PASS |  |
| `ui/CleanACat_Ui_Click.ogg` | ui | 0.05 | 1 | 48000 | 4 | - | -3.0 | 0 | - | PASS |  |
