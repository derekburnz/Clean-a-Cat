# Audio

Client-only sound. Cue ids, never asset ids, outside `Cues.luau`. Owner: Motion-FX-Agent (sound-designer).

| File | What |
|---|---|
| `init.luau` | SoundGroups (Music, Ambience, Sfx, Ui), pooled voices, play, loop, settings, music that alternates two tracks |
| `Cues.luau` | Every cue: ids, group, volume, pitch range, minGap, voices, preload. Mirrors `docs/audio/clean-a-cat/sound-list.md` |
| `CueRules.luau` | Pure rules with specs (`tests/specs/CueRules.spec.luau`) |

`Controllers/AudioController.luau` plays cues on the moments from `Shared.Moments` (issue #3) and only listens.
Empty `ids` play nothing, so the game runs silent until files are uploaded under the game's owner.
