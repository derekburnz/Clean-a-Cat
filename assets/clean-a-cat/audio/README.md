# Clean a Cat audio: files and license log

Upload-ready files live in `sfx/`, `ui/`, `music/` and `ambience/`, named `CleanACat_<Bus>_<Name>[_<Variant>]`. The cue list is `docs/audio/clean-a-cat/sound-list.md`. `gates.md` is written by the audio gate (`python .claude/skills/audio-pipeline/scripts/audio_gate.py assets/clean-a-cat/audio`), never by hand.

## Making the synth sounds
`python assets/clean-a-cat/audio/synth/make_sfx.py` rebuilds every synth file (needs numpy and ffmpeg; same seed gives byte-identical files). Change numbers in the script, then rerun the gate.

## License log
One row per file or Creator Store id, added the moment it is picked. The asset id column fills in after upload (under the Creampuff Games group) or from the Creator Store page; never invent one.

| File or sound | Source | License | Credit needed | Asset id | Added |
|---|---|---|---|---|---|
| sfx/CleanACat_Sfx_BubblePop_1..3.ogg | synth/make_sfx.py (ours) | Original | No | not uploaded | 2026-11-23 |
| sfx/CleanACat_Sfx_MudPlop.ogg | synth/make_sfx.py (ours) | Original | No | not uploaded | 2026-11-23 |
| sfx/CleanACat_Sfx_RevealChime.ogg | synth/make_sfx.py (ours) | Original | No | not uploaded | 2026-11-23 |
| sfx/CleanACat_Sfx_BowPop.ogg | synth/make_sfx.py (ours) | Original | No | not uploaded | 2026-11-23 |
| sfx/CleanACat_Sfx_BrushSwish_1..3.ogg | synth/make_sfx.py (ours) | Original | No | not uploaded | 2026-11-23 |
| ui/CleanACat_Ui_Camera.ogg | synth/make_sfx.py (ours) | Original | No | not uploaded | 2026-11-23 |
| ui/CleanACat_Ui_Click.ogg | synth/make_sfx.py (ours) | Original | No | not uploaded | 2026-11-23 |
| sfx/CleanACat_Sfx_Purr_1..2.ogg | synth/make_sfx.py, purr code ported from the owner's derekburnz/Roblox-Asset-Library | Original (owner's own) | No | not uploaded | 2026-11-23 |
| sfx/CleanACat_Sfx_Meow_1..3.ogg | synth/make_sfx.py, cat voice code ported from the owner's derekburnz/Roblox-Asset-Library | Original (owner's own) | No | not uploaded | 2026-11-23 |
| music/CleanACat_Music_SpaA.ogg, music/CleanACat_Music_SpaB.ogg | synth/music.py (new songs; instruments ported from the owner's derekburnz/Roblox-Asset-Library) | Original (owner's own) | No | not uploaded | 2026-11-23 |
