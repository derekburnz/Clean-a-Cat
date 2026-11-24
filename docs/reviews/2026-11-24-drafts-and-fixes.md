# Reviews 2026-11-24: draft models, UI screens and stink wisps

Review-QA log for the day. Each verdict was sent to the author thread at the head named. Visual items were judged by the section 8 rubric in the QA plan: phone-size renders, one verdict per item (KEEP, FIX or DROP).

| PR | Head | Verdict | Restart | Notes |
|---|---|---|---|---|
| #114 mud coat built into the fur | aed988f | PASS | no | Visual FIX at phone size (coat read as a fur pattern) became #117 |
| #115 sponge rubs the blob it hits | 4d9e95e | PASS | no | Nit: stale comment (fixed in #147) |
| #118 store thumbnail redo | 71f5f5f | PASS | no | Thumbnail KEEP; icon FIX (cat too small at 100 px) became #119 |
| #120 store icon close shot | f6dadc2 | PASS | no | KEEP at 100 and 48 px |
| #121 14 UI screen drafts | da7398c, then 47f1db1 | CHANGES NEEDED, then PASS | no | Must: the under-13 gate on the Notify me bell was not written down. Also fixed: locked odds toggle, colour-only rarity tiles, welcome X wording, toast over sponge |
| #128 dirt cue on the mud coat | 2703fe0, then 3bb6e7a | PASS, SAME_CODE | no | Grey clay on dark fur fixed the tortoiseshell read |
| #129 stink wisps (stinkEffects, off) | e0d8b2d | PASS | no | Nits: unordered slot budget (became #152), cleaned cats keep Dirty |
| #130 seven hand tools | 04d73c3 | PASS | no | Comb, clipper and tweezers FIX (grey bodies vanish), done in #133 |
| #133 tool fixes | 248b1f6 | PASS | no | All KEEP; rule added: no tool body mostly grey |
| #134 mud tone tie fix | ed4b4e6 | PASS | no | Build no longer depends on the hash seed |
| #135 coin, star, coin stack | 766c99a | PASS | no | Nits: four-toed paw, star back face (done in #137) |
| #136 UI portraits swap | e683622 | PASS | no | Mockups only |
| #137 burr, leaf, twig | 98011f0, then 35b1e8d | PASS, SAME_CODE | no | Leaf placement rule: debris stays off eyes and face |
| #138 bench, desk, helper, visitor props | 274098e | PASS | no | Helper FIX (read as a loose customer cat), done in #139 |
| #139 helper smock and icon renders | 2e0b75f | PASS | no | Icon FIXes (shower stand, coin glint, burr core) done in #141 |
| #141 two helper looks and icon fixes | 2705796 | PASS | no | All KEEP; dryer stand not for 32 px |
| #143 UI helper faces | 91e1d30 | PASS | no | Nit: welcome badge crop (done in #158) |
| #144 tool tiers and keepsake | f6de33c, then dea6108 | PASS | no | Fluffy brush and rain shower FIX first; rule added: every tier changes shape or size, not only colour |
| #147 line endings and check.ps1 | beebc44 | PASS | no | No CRLF in the index, so no mass renormalize |
| #150 bigger stink puffs on phones | 65dfcbf | PASS | no | From #148 phone captures |
| #153 wisp slots nearest first | d4cd925 | PASS | no | Re-shoot showed the tub cat could still lose before the first scrub (#154) |
| #156 tub cat holds the first wisp slot | 624e1b0 | PASS | no | Re-shoot passed on three runs |
| #158 recap New! tag and welcome badge | 9a52e4d | PASS | no | Mockups only |
| #159 drab mud on pale fur | 9b05f93, then 2311864 | CHANGES NEEDED, then PASS | no | Cut the ragged edge to one box a piece; dirty cats 134 to 154 parts, limit 155 |

## QoL lines (UI and gameplay PRs)
- #121, #136, #143, #158 (screen drafts): all five QoL checks held at 667 x 375. Menus scroll, nothing unaffordable is lit, no new pop-up types and nothing opens by itself. The wording was fixed where it was unclear.
- #129, #150, #153, #156 (stink wisps): no UI. Client only, behind stinkEffects, which stays off until Derek decides the game.

## Issues filed from device checks
- #148: wisps too faint at the default phone camera (fixed by #150)
- #149: a scrub in the thumbstick zone walks the player, and one drag clears 14 of 20 mud (open, Gameplay-Engineer)
- #152 and #154: the tub cat lost its wisp slot to door cats (fixed by #153 and #156)
- #155: mud on white cats read as the Patches coat (fixed by #159)

## Still open for QA
- The low-end phone frame check on a full street (6 plots with door cats). It matters more now that dirty cats are up to 154 parts.
- The first human playtest asks a new player "what is wrong with this cat?" with no prompt (see the QA plan).
