# src/shared

Visible to both server and client (it becomes `ReplicatedStorage.Shared`). Nothing secret goes here.

- `LiveFlags.luau`: the live on/off switches. Read a switch with `LiveFlags.isOn("name")`.
- `Remotes.luau`: the one list of remotes, each with its arguments and what the server checks.
- `SaveSchema.luau`: what a save holds, its `VERSION` and the migrations. Read its header before adding a field.
- `TelemetryRules.luau`, `RestartNotice.luau`: the pure rules behind `Telemetry` and the restart countdown.
- `Guard.luau`: argument checks for remotes (`Guard.id`, `Guard.int`, `Guard.oneOf`, `Guard.text`...), each returning the cleaned value or nil.
- `Signal.luau`: a small typed signal (`DataService.onLoaded` uses it).
- `Wallet.luau`: the Player attribute the server mirrors the save's coins onto (display only) and how the coin counter writes a number (`1,240`, `1.2M`).
- `RecapRules.luau`: what the recap card after a customer shows (the server builds it from what it paid, the client cleans it), and the two values that pick the full card or the strip.
- `SettingsRules.luau`: the player's own settings on the Settings card (sound levels, less shake, less sparkle) and how a slider turns a pointer into a level.
- `IndexViewRules.luau`: what the Cat Index window shows for each cat (seen, washed, resident, new), the Wash all progress and the chance line from the board odds.
- `QueueViewRules.luau`: what "Who's next?" and the HUD's waiting faces show for each customer at the door (needs, locks, pay, New!, VIP), the line under the title from the board odds, and when a Wash next button shows.
- `Vendor/`: third-party single-file modules. Never edit or reformat them (StyLua and Selene skip this folder); replace the whole file to update. `Trove.luau` is [Sleitnick/RbxUtil](https://github.com/Sleitnick/RbxUtil) `modules/trove` v1.8.0 at commit 5437776 (2026-11-20), MIT, licence in `Trove.LICENSE.md` (#184). Clean up a screen or a visit with it: see `luau-conventions`. `spr.luau` is [Fraktality/spr](https://github.com/Fraktality/spr) `spr.lua` at commit 665be17 (2024-07-30), MIT, licence in `spr.LICENSE.md`: spring motion for UI, a trial behind the `springUi` switch (#183); client only, required lazily by `client/UI/Motion.luau`.
- Add as the game grows: `Config.luau` (tuning numbers), `Catalog.luau` (items with stable ids) and `Types.luau`. Templates are in the `luau-conventions` and `remote-security-checklist` skills.

Keep game rules here (or in `server/Util/`) as pure modules with no Roblox services at load time, so `tests/specs` can cover them.
