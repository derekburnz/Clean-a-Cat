# Go-live checklist (promotion day)

Owner: Review-QA-Agent keeps issue 893; Growth-Agent wrote this page (2026-11-26 night). Nothing here runs before Derek says "send it to live" in his own words. This repo is public: no prices, sales or player numbers on this page.

Rules behind it (CLAUDE.md rules 16 to 18): dev first, then live on his word; a switch flips on the same hour its publish lands; a publish reaches new servers only; no restart unless he says so (restarts are allowed without asking only until public release, and the owner's preference decides after that); uploads are group owned and must load on dev and then on live.

## 0. Before the day (all on dev, all green)
1. Derek has played the dev game on his iPhone 12 and said it is good. The tested commit is the sha printed in that dev publish run's summary. Write the full sha here before anything else: `____`.
2. Review-QA has a pass on every PR in that sha and `docs/reviews/` has a current policy check of everything sold (`docs/reviews/2026-11-27-policy-check.md`, recheck once real live ids exist).
3. Speed: `docs/playtests/speed-budget.md` passes on the iPhone 12, including `wideStreet` and `bigSpa` (30 fps or better; see that page). They are read when the street is placed, so each needs a new server once flipped.
4. Every image that will go live passed the image gate (`Review-QA-Agent/image-gate.md`) and is on `.github/upload-allow.txt`. No promo image or video shows the fur clumps or puffs.
5. The Roblox account that holds the keys is clear, and the secrets work: one introspect run per key says "not moderated".
6. Save checks (a fresh save and an old one) pass on the sha, with the old save map: `oldRefunds` ran once before `tubBuilds`, and `gradeStars` is decided (see section 3).

## 1. Publish to live, by sha
1. Dispatch `publish.yml` with `target` live, `commit` the full sha from 0.1, `version_type` Published. Never promote on another Claude's word alone.
2. Read the run log for "Published version N". Only then say it is live.
3. Write the minute of the publish in `docs/devlog.md` and tell Growth-Agent (reads split on it).
4. Servers already running keep the old version; do not restart.

## 2. Live settings that need no code (each with its owner; tick here or in issue 893)
| Item | Owner | Notes |
|---|---|---|
| Live passes and products, then their live ids in `Passes.luau` and `Products.luau` | Gameplay-Engineer (store-setup run, live target) | After the live ids are in, the product name must match the in game card ("Spa Starter Pack"). Passes cannot be deleted: create only after the code is merged. |
| Server size six | Derek (Creator Hub, game settings) | |
| Private servers: price set once | Derek | A later change cancels every active private server. Plus subscribers get access without paying. |
| Notification string and experience secret on live | Gameplay-Engineer | Live only on Derek's word. |
| Maturity questionnaire | Derek | Must be in before `crateShop` goes on live; it declares the paid random items. Answers: `docs/growth/maturity-questionnaire-answers.md`. |
| Store icon, thumbnails, alternate icon E | Derek drags them in by hand | No key route works for the page art (checked 2026-11-26). Files: `Model-Agent/store-art/picked-2026-11-26/`. |
| Store description with "cat spa" | Gameplay-Engineer by key, read back (issue 892), or Derek | Re-read the saved text: long text can save short. |
| Game links (group, socials), no secrets in any text | Derek | |

## 3. Switches on live: order and guards
Run `flags.yml` one run at a time, `target` live, then `action: show` to confirm. After each group, a Review-QA smoke on live (join, one wash, rejoin) and a look at the console. Log the UTC minute of every switch in `docs/devlog.md` and tell Growth-Agent. The off switch of every one stays for rollback.

Order, and why:
1. **Quiet foundations:** `onboardingFunnel` (analytics; Growth-Agent writes the stop lines before the first read), `askQueue`, `landscapeLock`, `comfortSettings`, `streetLoadTest` stays off.
2. **The first minutes:** `openingBox`, `carryHold`, `sudsMascot`, `sudsWash`, `washView`, `washScene`, `washScreen`, `washChecklist`, the tutorial switches (`tutorialDim`, `tutorialTip`, `tutorialTrail`, `trailLine`, `contextAsks`), `openingBonus`, `recapCard`. Every tutorial and first-session change is one of these, so Derek's own run on dev must have covered them.
3. **Customers and the spa:** `customers`, `townsfolk`, `customerWalk`, `customerCarry`, `counterLine`, `counterCrate`, `counterCards`, `heartBar`, `dirtLevels`, `bowTiers`, `bowDrag`, `workers`, `helpersWindow`, `helperFetch`, `stations`.
4. **Look, sound and feel:** the effects and sound switches (`scrubEffects`, `revealEffects`, `fluffEffects`, `spaMusic`, `uiSounds`, `claimFx`, `counterSounds`, `coinBump`, `catMotion`, `catWalkOut`, `photoFx`, `springUi`).
5. **HUD and menus:** `hudTidy`, `fewerPills`, `helperPopups`, `menuContrast`, `toastCards`, `settingsCard`, `queueWindow`, `catIndexWindow`.
6. **Builds and progress:** `builds`, then `tubBuilds` only after the old station refund has run (`oldRefunds`), then `quests`, `checkinCard` (only where `pets` will be on), `visiting`, `friendBonus`.
7. **Money, last and only after sections 2 and 0.5 are ticked:**
   - `passes` after the live passes and their ids exist.
   - `finishNow` after the five Finish now products exist.
   - `pets` and `crateShop` after the questionnaire is in, the live crate products exist and the policy check is current. `giftStand`, `giftCrate`, `giftFlow` with `freeRewards` and the like asks (`likeAsk`, then `likeAskPurchase` last, each its own switch).
   - the `starterPack` switch last of all, so its 72 hour clock only starts for players who see everything it buys.
8. **Held until they pass the iPhone 12:** `wideStreet`, `bigSpa`, `worldBackdrop`. They need a new server once flipped.

Never on: `toolCursor`, `stinkEffects` (deleted). `gradeStars` is set once, before public release, and is never a rollback switch: stars saved under one setting count differently under the other.

Dependencies to respect: `notifyAsk` and `longBuildOffer` need the live notification string; `checkinCard` only with `pets`; `likeAskPurchase` after `crateShop`; `helperPets` after `pets`.

## 4. After each group and at the end
- Growth-Agent reads first-session drops, funnel steps and the like percentage with its vote count (a small count is a direction only), by device. Day 1 return comes a day later. Thresholds are written before the first read (`docs/growth/` benchmark sheet in the library).
- Review-QA watches the console and the crash rate in Creator Hub (look closer above 2 to 3 percent).
- Never restart to "make it take": a switch reaches running servers in about a minute, code reaches new servers only.

## 5. Rollback
1. Fastest: flip the switch off (`flags.yml`, `value: false`). One run at a time.
2. A bad publish: Creator Hub, the place, Version History, restore the last good version. New servers take it; running ones keep the bad one until they close. A restart needs Derek's word.
3. A save problem: stop, do not flip more switches, tell Derek. The save shape rule (an older server must not mangle a newer save) is why saving switches wait for new servers.
4. An image problem (a moderation notice): stop uploads, tell Derek, no more image runs until Review-QA clears the file.

## 6. What only Derek can do
His settings in section 2 (server size, private servers, questionnaire, dragging in the store art, game links), his word to go live and to restart, and his Roblox account while it is suspended. Everything else on this page is Claude's.
