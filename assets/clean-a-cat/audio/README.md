# Clean a Cat audio: files and license log

Upload-ready files live in `sfx/`, `ui/`, `music/` and `ambience/`, named `CleanACat_<Bus>_<Name>[_<Variant>]`. The cue list is `docs/audio/clean-a-cat/sound-list.md`. `gates.md` is written by the audio gate (`python .claude/skills/audio-pipeline/scripts/audio_gate.py assets/clean-a-cat/audio`), never by hand.

## Making the synth sounds
`python assets/clean-a-cat/audio/synth/make_sfx.py` rebuilds every synth file (needs numpy and ffmpeg; same seed gives byte-identical files). Change numbers in the script, then rerun the gate.

## License log
One row per file or Creator Store id, added the moment it is picked. The asset id column fills in after upload (under the Creampuff Games group) or from the Creator Store page; never invent one.

| File or sound | Source | License | Credit needed | Asset id | Added |
|---|---|---|---|---|---|
| sfx/CleanACat_Sfx_BubblePop_1..3.ogg | synth/make_sfx.py (ours) | Original | No | 130114968601790, 110755365796073, 116414110656793 (Creampuff Games) | 2026-11-23 |
| sfx/CleanACat_Sfx_MudPlop.ogg | synth/make_sfx.py (ours) | Original | No | 107329071536560 (Creampuff Games) | 2026-11-23 |
| sfx/CleanACat_Sfx_RevealChime.ogg | synth/make_sfx.py (ours) | Original | No | 84312583849520 (Creampuff Games) | 2026-11-23 |
| sfx/CleanACat_Sfx_BowPop.ogg | synth/make_sfx.py (ours) | Original | No | 136883364011549 (Creampuff Games) | 2026-11-23 |
| sfx/CleanACat_Sfx_BrushSwish_1..3.ogg | synth/make_sfx.py (ours) | Original | No | 134072180392503, 121263183608677, 99870851025492 (Creampuff Games) | 2026-11-23 |
| ui/CleanACat_Ui_Camera.ogg | synth/make_sfx.py (ours) | Original | No | 138137408834946 (Creampuff Games) | 2026-11-23 |
| ui/CleanACat_Ui_Click.ogg | synth/make_sfx.py (ours) | Original | No | 133323658066149 (Creampuff Games) | 2026-11-23 |
| sfx/CleanACat_Sfx_Purr_1..2.ogg | synth/make_sfx.py, purr code ported from the owner's derekburnz/Roblox-Asset-Library | Original (owner's own) | No | 112652819529138, 93890384660354 (Creampuff Games) | 2026-11-23 |
| sfx/CleanACat_Sfx_Meow_1..3.ogg | synth/make_sfx.py, cat voice code ported from the owner's derekburnz/Roblox-Asset-Library | Original (owner's own) | No | 100957394631396, 89957276276636, 70877155078126 (Creampuff Games) | 2026-11-23 |
| music/CleanACat_Music_SpaA.ogg, music/CleanACat_Music_SpaB.ogg | synth/music.py (new songs; instruments ported from the owner's derekburnz/Roblox-Asset-Library) | Original (owner's own) | No | not uploaded | 2026-11-23 |
| sfx/CleanACat_Sfx_SpongeLoop.ogg | synth/make_sfx.py (ours) | Original | No | 125803317425310 (Creampuff Games) | 2026-11-23 |
| sfx/CleanACat_Sfx_FurShake.ogg | synth/make_sfx.py (ours) | Original | No | 128546270034088 (Creampuff Games) | 2026-11-23 |
| sfx/CleanACat_Sfx_DryerHum.ogg | synth/make_sfx.py (ours) | Original | No | 105566818572862 (Creampuff Games) | 2026-11-23 |
| sfx/CleanACat_Sfx_TruckRumble.ogg | synth/make_sfx.py (ours) | Original | No | 128974104818127 (Creampuff Games) | 2026-11-24 |
| sfx/CleanACat_Sfx_TruckHonk.ogg | synth/make_sfx.py (ours) | Original | No | 76728960044070 (Creampuff Games) | 2026-11-24 |
| sfx/CleanACat_Sfx_TruckBump_1..2.ogg | synth/make_sfx.py (ours) | Original | No | 83549622802247 (1), 131991798209030 (2) (Creampuff Games) | 2026-11-24 |
| sfx/CleanACat_Sfx_TruckDoor.ogg | synth/make_sfx.py (ours) | Original | No | 106598333989684 (Creampuff Games) | 2026-11-24 |
| sfx/CleanACat_Sfx_BoxThud.ogg | synth/make_sfx.py (ours) | Original | No | 113317721257314 (Creampuff Games) | 2026-11-24 |
| sfx/CleanACat_Sfx_BoxRustle.ogg | synth/make_sfx.py (ours) | Original | No | 112949884290830 (Creampuff Games) | 2026-11-24 |
| sfx/CleanACat_Sfx_CollarJingle.ogg | synth/make_sfx.py (ours) | Original | No | 132945251317866 (Creampuff Games) | 2026-11-24 |
| sfx/CleanACat_Sfx_CarryPurr.ogg | Derek's Roblox-Asset-Library audio/sfx/CatCafe_Sfx_CarryPurr.ogg (synth.py, his own earlier game) | Original (Derek's) | No | not uploaded | 2026-11-24 |
