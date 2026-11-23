# Effects

Client-only, cosmetic effects. Owner: Motion-FX-Agent (vfx-animator). What each effect is: `docs/vfx/clean-a-cat/effects-list.md`.

| File | What |
|---|---|
| `init.luau` | Device tier, pooled emitters (one per preset, on an Attachment in Terrain), `stream`, `stopStream`, `burst` |
| `Presets.luau` | Every effect as data per tier (low, high) and the budget caps |
| `Tier.luau` | Pure rules with specs: tier pick, foam rate from drag speed, Reduce Motion halving |

`Controllers/EffectsController.luau` binds Moments. Scrub effects are behind the `scrubEffects` live switch.
