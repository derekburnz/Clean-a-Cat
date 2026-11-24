# Remote threat table

This table has one row per client-to-server remote in `games/clean-a-cat/src/shared/Remotes.luau`. It follows the `remote-security-checklist` skill.

When a pull request adds or changes a remote, it updates this table in the same PR. The reviewer checks the handler against its row.

Every remote goes through `NetService.on`, so every remote gets four things for free:

- **Rate limit:** a per-player token bucket (the rates are in the table). Calls over the limit are dropped silently.
- **Name check:** the remote's name must be in `Remotes.ClientToServer`, or the server fails at start.
- **pcall:** each handler runs inside a pcall. A bad call logs a warning and cannot break the listener.
- **Cleanup:** per-player state is cleared on `PlayerRemoving`.

Arguments arrive as `unknown`. They are read only through `Shared.Guard`: `Guard.int` for whole numbers in a range (it refuses NaN and huge values), and `Guard.oneOf` for ids from a fixed list. Anything else is dropped with no reply.

## Spa loop (SpaService, switch `scrubPrototype`)

The server keeps one cat per player in its own table, with a stage: dirty, clean, fluffed, styled, done. Every spa report names the cat by `catId`. The server moves the cat only one stage forward, in order. After every report it sends back `CatStage`, so a refused step never leaves the client stuck.

| Remote | Rate | What an exploiter tries | Server rule |
|---|---|---|---|
| `RequestCat()` | 1/s, burst 2 | Reroll cats until a rare one comes up | A dirty cat is resent, not rerolled. A done cat is replaced. An unfinished cat is replaced only once `MIN_VISIT_SECONDS` have passed since it arrived (`SpaRules.canReplace`). Before that it goes back to dirty and is resent, with the same id, kind and arrival time (`SpaRules.restart`). A skip costs as long as a paid visit and earns nothing (#164). The kind is rolled on the server. |
| `ReportScrubbed(catId, seq)` | 2/s | Skip the scrub, or report it for a cat that isn't theirs | `catId` and `seq` pass `Guard.int`. The cat must be the player's current cat. `SpaRules.scrubbed` moves only dirty to clean. |
| `ReportBrushStroke(catId, seq)` | 8/s | Fire every stroke at once to fluff instantly | Same cat check. The cat must be clean. `BRUSH_STROKES` (3) strokes fluff it. The rate limit caps how fast that happens. The pay does not depend on speed, because the photo gate below holds it. |
| `RequestPickBow(catId, seq, bowId)` | 2/s | Pick a bow that doesn't exist, or skip the brush | `bowId` passes `Guard.oneOf(SpaRules.BOWS)`. The cat must be fluffed. |
| `RequestPhoto(catId, seq)` | 2/s | Get paid twice, get paid early, or get paid for a cat that isn't theirs | The cat must be styled, and only one photo can be waiting (`photoTaken`). The pay comes no sooner than `MIN_VISIT_SECONDS` (15 s) after the cat arrived, and only once (the stage becomes done). Nothing is paid without a loaded save. Coins, tips and stars come from `CatRules` and `BuildRules` on the server. The client never sends an amount. |

**Pay cap:** a script earns no more than one cat's pay per `MIN_VISIT_SECONDS`, and it cannot pick which cats it serves, because skipping costs a full visit's time (#164).

**Accepted for now:** the spa remotes have no distance check to the tub, so a script can play the loop without walking there. It still earns no more than an honest fast player. Revisit before a stage pays much more than a common cat, with a reach check from `SpaLayout.spot("Tub", player)` or a longer visit for higher pay.

## Economy

| Remote | Rate | What an exploiter tries | Server rule |
|---|---|---|---|
| `RequestBuyTool(toolId)` | 1/s, burst 2 | Buy with a fake id, buy without enough coins, buy twice, or buy from across the map | `Guard.oneOf(ToolRules.IDS)`. The switch must be on and the save loaded. The player's root must be within `ToolRules.SERVER_REACH` (16 studs) of the Tools spot in their own plot. `ToolRules.canBuy` checks the price on the server, enough coins and not already owned. `ToolRules.buy` checks and spends in one step with no yield. |
| `RequestBuild(id)` | 1/s, burst 2 | Build with a fake id, skip the order, start two builds in one slot, build for free, or finish early | `Guard.oneOf(BuildRules.IDS)`. The switch must be on and the save loaded. The player must be within `BuildRules.SERVER_REACH` (16 studs) of the builder spot (`SpotBuilder`) in their own plot. `BuildRules.canStart` checks the order, a free slot and the coins. `start` spends coins and sets `endsAt` from the server's `os.time()`. Finishing is driven only by the server's clock, and the client sends no time. |

## Telemetry (no game state changes)

| Remote | Rate | What an exploiter tries | Server rule |
|---|---|---|---|
| `ReportStep(step)` | 1/s, burst 2 | Spoil the funnel with fake or repeated steps | `Guard.oneOf(TelemetryRules.CLIENT_STEPS)`. Each step is logged once per save. Before the save loads, steps wait in a small per-player list with no repeats, which is cleared on leave. Nothing else changes. |
| `ReportOptIn(result)` | 1/s, burst 2 | Spoil the opt-in numbers | `Guard.oneOf(NotifyRules.RESULTS)` and the `longBuildOffer` switch must be on. It only logs `notify_opt_in`. Whether the notification is sent is decided by the server from the save, never from this remote. |

## Other

| Remote | Rate | What an exploiter tries | Server rule |
|---|---|---|---|
| `Ping()` | 2/s | Flood | It takes no arguments and does nothing. It stays as the template to copy. |
| Any | per remote | Flood remotes to lag the server | Each remote has its own limiter. Calls over the limit are dropped silently. No kick rule yet. Add one only if logs show clear abuse. |

## Server-to-client remotes

The client only displays what these carry (see `Remotes.ServerToClient`). No server state depends on a reply to them, so they need no rows. They carry no other player's name or id.
