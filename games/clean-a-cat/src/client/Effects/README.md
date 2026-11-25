# Effects

Client-only, cosmetic effects. Owner: Motion-FX-Agent (vfx-animator). What each effect is: `docs/vfx/clean-a-cat/effects-list.md`.

| File | What |
|---|---|
| `init.luau` | Device tier, pooled emitters (one per preset, on an Attachment in Terrain), `stream`, `stopStream`, `burst` |
| `Presets.luau` | Every effect as data per tier (low, high) and the budget caps |
| `Tier.luau` | Pure rules with specs: tier pick, foam rate from drag speed, Reduce Motion halving |
| `CatPose.luau` | Pure motion curves with specs: idle, blink, ear twitch, shake-off, happy wiggle, update rate by distance |
| `CatMotion.luau` | One PreSimulation loop that pivots the rig joints (Head, Tail, EarL, EarR, eye squash) from CatPose. Body never moves |
| `CustomerPose.luau`, `CustomerMotion.luau` | The customers' walk and idle (Model-Agent's townsfolk): legs and free arm swing at a cadence matched to LegLength while the body moves, the carrying arm barely sways, a look round and nod when standing. Behind `customerWalk` |
| `TrailLine.luau` | The tutorial guide line (#451): a see-through green floor band from the feet to the spot with an arrowhead and a running dash. Flat pooled parts, no particles. FloorTrail calls it behind `trailLine` |
| `FoamDrop.luau` | The rinse's end (ShakeOff "rinse", `washMeter`): 4 to 6 foam blobs slide off the lower coat, land round the feet, flatten and fade in 1.4 s. Pooled per drop, destroyed after |
| `Attention.luau` | A HUD button that asks to be pressed (the starter pack, PR 493 spec): a 1.00 to 1.08 bob over 1.6 s and three sparkle stars popping in turn. Still with reduced motion or less sparkle. `Attention.start(button)` returns `{ stop }` |

`Controllers/EffectsController.luau` binds Moments. Live switches: `scrubEffects`, `revealEffects`, `fluffEffects`, `catMotion`, `dryEffects` and `openingBox`, all off by default.

Cat motion finds cats by the `Cat` attribute on the cat Model, so the placeholder `PH_Cat` never moves. Phones move at most 4 cats at 30 updates a second, PC 10 at 60; past 30 studs half that, past 60 studs none.

Comfort: every effect asks `UI/Comfort` rather than `GuiService`. Particle counts (foam, bursts, dryer air) halve with `Comfort.lessSparkle()` (Roblox's Reduced Motion or the Settings card's Less sparkle). The bow pop, the glow fade and all cat motion except the blink stop with `Comfort.reducedMotion()` (Reduced Motion, Less screen shake or Less sparkle).

Opening scene (#281): `TruckDrop` holds every beat and curve (pure, with specs); `OpeningScene.play(origin, { shot, onTap })` plays the truck, the bump, the box drop and the wiggle on this client only, and `handle.open()` pops the flaps and lifts the kitten out. Props come from `ReplicatedStorage.Assets` by name (`CleanACat_Prop_DeliveryTruck`, `CleanACat_Prop_DeliveryBox`, `CleanACat_Cat_Suds_Dirty_Sit`; the speed bump is the plot's own, on SpotBump), with PH_ stand-ins of the same sizes until they land. EffectsController has a stand-in trigger (once per session, 6 studs in front of the player) so it can be watched in Studio (it never runs outside Studio): set `LiveFlag_openingBox` true on ReplicatedStorage in the client command bar. Gameplay owns the real trigger.
