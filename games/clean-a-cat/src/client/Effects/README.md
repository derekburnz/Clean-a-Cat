# Effects

Client-only, cosmetic effects. Owner: Motion-FX-Agent (vfx-animator). What each effect is: `docs/vfx/clean-a-cat/effects-list.md`.

| File | What |
|---|---|
| `init.luau` | Device tier, pooled emitters (one per preset, on an Attachment in Terrain), `stream`, `stopStream`, `burst` |
| `Presets.luau` | Every effect as data per tier (low, high) and the budget caps |
| `Tier.luau` | Pure rules with specs: tier pick, foam rate from drag speed, Reduce Motion halving |
| `CatPose.luau` | Pure motion curves with specs: idle, blink, ear twitch, shake-off, happy wiggle, update rate by distance |
| `CatMotion.luau` | One PreSimulation loop that pivots the rig joints (Head, Tail, EarL, EarR, eye squash) from CatPose. Body never moves |

`Controllers/EffectsController.luau` binds Moments. Live switches: `scrubEffects`, `revealEffects`, `fluffEffects` and `catMotion`, all off by default.

Cat motion finds cats by the `Cat` attribute on the cat Model, so the placeholder `PH_Cat` never moves. Phones move at most 4 cats at 30 updates a second, PC 10 at 60; past 30 studs half that, past 60 studs none.
