# Speed budget (test phone: iPhone 12)

Owner: Review-QA. Issue #182. Every playtest report checks a build against this page. If a check fails, file a ticket with the numbers. Do not quietly change the budget.

## The test phone and what it cannot prove
The owner's weakest device is an **iPhone 12** (2020, 4 GB of memory). The owner said so on 2026-11-24. An older iPad from about 2020 is the second device. Both are mid-range phones, not low-end ones, so a pass on them does not prove the game runs on a cheap Android phone. Studio's device preview shows sizes only, not phone speed or memory. Four checks cover that gap:

1. **Layout:** Studio device presets (`rbx-device-simulator-lua`, see `playtest-report`). These prove sizes and safe areas only.
2. **Speed:** the iPhone 12 at Roblox's **lowest and highest** graphics quality. The game must hold 60 fps at both settings, with room to spare.
3. **Memory as a trend:** client memory in the Developer Console (F9 > Memory) at the start and after 20 minutes of play. It must stay flat. Growth is a leak and fails, whatever the number.
4. **Real players later:** after launch, the Creator Hub performance dashboard shows the client crash rate. Look closer above 2 to 3 percent. Until someone has a cheap Android phone, this is the only true read on one.

If a weaker phone ever turns up, it becomes the test phone. Change only the line above.

## The budget
These numbers come from Roblox's performance pages (read 2026-11-24). Roblox calls them examples, not hard limits. We keep ours lower, because the iPhone 12 is not low-end.

| What | Budget | How to read it |
|---|---|---|
| Frame time | 16.67 ms (60 fps). Our target: 95th percentile 14 ms or less on the iPhone 12 | MicroProfiler (Ctrl+F6, or Ctrl+Alt+F6 on the phone), or `rbx-perf-profiling` in Studio |
| Draw calls, worst view | Roblox example: under 1,000. Ours: 150, and flag a rise of 25 percent between milestones | `rbx-scene-analysis` on a full street (`streetLoadTest`) |
| Triangles, worst view | Roblox example: under 1,000,000. Ours: 200,000, and flag a rise of 25 percent | same |
| One mesh | 20,000 triangles at most (Roblox's import limit). Props are far less, per `asset-pipeline` | Blender QA sheet |
| Images | 512 by 512 or smaller unless one is a hero picture. A 1024 image costs four times the memory | Model and UI handoff |
| Effects | the phone column of `animation-vfx` section 7 (particles, beams, trails, Highlights, tweens) | Effects handoff numbers |
| Client memory | flat over 20 minutes. Our own rule of thumb, not Roblox's: flag over 900 MB on the iPhone 12 | Developer Console > Memory |

Reference points, 2026-11-24, PC numbers: the street's worst view was about 186,000 triangles and 106 draw calls. The draft backdrop (`worldBackdrop`) adds up to 71,900 triangles on its own, so it stays off live until it passes the iPhone 12 run.

## Five causes of most phone lag, and the check for each
| Cause | Check on review or playtest |
|---|---|
| 1. Memory that grows through a session | Memory at 0 and 20 minutes stays flat. In code review: every `Connect` has a matching disconnect or a trove, and every clone is destroyed or reused |
| 2. Large or too many images | No new image over 512 by 512 without a reason in the PR. Count new image ids per screen |
| 3. See-through layers and heavy particles | Stacked transparent parts and full-screen effects are rare. Particle properties are written only when they change (#198). Depth of field and blur get a phone frame-time number before going live |
| 4. Every-frame scripts and connections that are never disconnected | A `RenderStepped`, `Heartbeat` or `BindToRenderStep` disconnects when its job ends. No work per move that creates instances. Flag our scripts in the profiler's top items |
| 5. Leftovers from players who left, and everything loaded from ReplicatedStorage | `PlayerRemoving` clears every per-player table. Client copies of Assets are cached or destroyed, never left unparented in a table |

## In each playtest report
Add a "Speed" line with:
- the build sha;
- the device (iPhone 12, or the PC with Studio, clearly labelled);
- graphics quality;
- frame time (average, 95th percentile, worst);
- worst-view triangles and draw calls;
- memory at 0 and 20 minutes;
- pass or fail against this page.

PC numbers are labelled as PC numbers. The owner's iPhone 12 run is the final gate before anything new goes live.
