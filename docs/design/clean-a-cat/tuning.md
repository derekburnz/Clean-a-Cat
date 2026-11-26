# Clean a Cat tuning (Design-Agent, 2026-11-25, starting values)

Every number in the agreed design (`gdd.md`) lives here. The game reads each one from a single shared config, so a change happens in one place. Derek said "do whatever prices for mono for now can tweak later", so all of these are starting values to test, never promises. Change a row by editing its value, its why and its date. Old values are kept in git history and in `docs/decisions.md` when the change matters.

Coins are the only soft currency. "Cats" in the pace column means customer cats washed by a new player on a phone at a normal pace (Suds is not counted).

How to read a row: **key** is the config name the engineer uses, **value** is the starting value, **why** says what it is tuned for, **changed** is the date of the last change.

## 1. Dirt levels and steps

| key | value | why | changed |
|---|---|---|---|
| `dirt.steps.1` | 3 | Derek's "3-10" steps; level 1 is the tutorial size | 2026-11-25 |
| `dirt.steps.2` | 4 or 5 (even roll) | | 2026-11-25 |
| `dirt.steps.3` | 6 or 7 (even roll) | | 2026-11-25 |
| `dirt.steps.4` | 8, 9 or 10 (even roll) | Top end of his range; about 50 s at 5 s a step | 2026-11-25 |
| `dirt.stepSeconds` | 8 (target) | Sync-Agent's Studio run (b504978) took about 22 s for the first mud step with real touch drags, a first try that includes learning; 8 s is the target once known. Re-time on the iPhone 12 | 2026-11-25 |
| `dirt.chance.Common` | L1 55, L2 30, L3 12, L4 3 | Most early cats are quick, so the first minutes keep moving | 2026-11-25 |
| `dirt.chance.Uncommon` | L1 40, L2 35, L3 18, L4 7 | | 2026-11-25 |
| `dirt.chance.Rare` | L1 25, L2 35, L3 28, L4 12 | "Rarer cats are more often dirty" | 2026-11-25 |
| `dirt.chance.Epic` | L1 10, L2 30, L3 35, L4 25 | | 2026-11-25 |
| `dirt.chance.Legendary` | L1 0, L2 15, L3 35, L4 50 | The rarest are a real job | 2026-11-25 |
| `dirt.chance.Special` | L4 100 | Special visitors are always very dirty | 2026-11-25 |
| `dirt.tutorial` | Suds L1 (3 steps), first customer L1 Common (3 steps), second customer L2 (4 steps) | The tutorial uses only the simple 3 or 4 | 2026-11-25 |

Each row of chances adds up to 100.

## 2. Customers, rarity and the bench

| key | value | why | changed |
|---|---|---|---|
| `rarity.chance` | Common 60, Uncommon 25, Rare 11, Epic 3.5, Legendary 0.5 | Unchanged from the current `CatRules.CHANCES`; the star tiers stay as they are | 2026-11-25 |
| `bench.size` | 3 at the start, plus one per built tub (`build.tub.effect`), at most 6 | "Three or four cats wait" | 2026-11-25 |
| `bench.refillSeconds` | 6 | A new customer walks in about 6 s after one is taken | 2026-11-25 |
| `bench.tutorialSize` | 1, then 2 at 2:00 | Matches the first session timeline | 2026-11-25 |

## 3. Pay for one cat

Pay = base × stars × early pick × dirt, rounded, then + bow + tip. Friends then add their bonus on the total.

| key | value | why | changed |
|---|---|---|---|
| `pay.base.Common` | 10 | Unchanged from today's `CatRules.PAY` | 2026-11-25 |
| `pay.base.Uncommon` | 15 | | 2026-11-25 |
| `pay.base.Rare` | 25 | | 2026-11-25 |
| `pay.base.Epic` | 40 | | 2026-11-25 |
| `pay.base.Legendary` | 80 | | 2026-11-25 |
| `pay.base.Special` | 120 | "Pay the most" | 2026-11-25 |
| `pay.tip` | Common 2, Uncommon 3, Rare 5, Epic 8, Legendary 15, Special 20 | Unchanged where it exists | 2026-11-25 |
| `pay.stars` | 1 star ×1.0, 2 stars ×1.1, 3 stars ×1.2 | Speed is a bonus, never a cut: a slow young player still gets full base pay | 2026-11-25 |
| `pay.starTimes` | 3 stars at 12 s or less per step on average, 2 stars at 20 s or less, else 1 | Per step so a 10 step cat is not harder to star. The clock runs only while a hand step (scrub, brush, lather, rinse, dry, claws) is on screen; the cat landing, the bow, the photo and any tip or card are not counted (Review-QA on PR 545) | 2026-11-25 |
| `pay.starsTutorial` | Suds and the first two customers always get 3 stars | The tutorial teaches, it never grades | 2026-11-25 |
| `pay.early` | ×1.25 when taken in the first 10% of its heart bar | Derek: a big bonus for an early pick; a normal wait costs nothing | 2026-11-25 |
| `pay.dirt` | L1 ×1.0, L2 ×1.25, L3 ×1.6, L4 ×2.0 | More steps pay more per cat and about the same per second | 2026-11-25 |
| `pay.bow` | plain ribbon +2 | Every hand washed cat gets a bow | 2026-11-25 |
| `pay.friend` | +10% per friend in the server, at most +30% | "About 10% for each friend" | 2026-11-25 |

Worked example (the recap mockup): an Uncommon at level 3, 3 stars, picked early: 15 × 1.2 × 1.25 × 1.6 = 36, + bow 2, + tip 3 = 41 coins.

## 4. Heart bar (how long a cat waits)

| key | value | why | changed |
|---|---|---|---|
| `heart.seconds.first10min` | 240 for every cat | Long early bars so a new player on a phone does not lose cats | 2026-11-25 |
| `heart.noLeaveBefore` | 10 min of play in the first session | Before then a bar stops at its last sliver and the cat stays grumpy but never leaves (Review-QA, issue 531) | 2026-11-25 |
| `heart.releaseStagger` | +15 s of grace per place in the line (first in line 0, second +15 s, third +30 s, fourth +45 s) | When the first 10 minutes end, cats held on their last sliver get their grumpy share back; without a stagger they would all leave on the same tick (Review-QA on PR 543). One cat at a time reads kinder | 2026-11-25 |
| `heart.seconds` | Common 150, Uncommon 140, Rare 120, Epic 100, Legendary 90 | Rarer cats are more tempting and a bit more urgent | 2026-11-25 |
| `heart.seconds.firstSpecial` | 600 | "Long heart bar so nobody rushes" | 2026-11-25 |
| `heart.seconds.special` | 240 | | 2026-11-25 |
| `heart.grumpyAt` | 30% left | The cat's face turns grumpy | 2026-11-25 |
| `heart.pauseDuringTutorial` | yes | Nothing drains while a tutorial step is up | 2026-11-25 |

## 5. Bows

| key | value | why | changed |
|---|---|---|---|
| `bow.Ribbon` | free, +2 | Everyone has it from the start | 2026-11-25 |
| `bow.Silk` | 150 coins, +4 | About 6 cats of income at that stage; pays back in under 75 cats | 2026-11-25 |
| `bow.Satin` | 600 coins, +7 | | 2026-11-25 |
| `bow.Golden` | 2,000 coins, +12 | | 2026-11-25 |
| `bow.workers` | Workers tie no bow | Keeps washing by hand worth it (open question 3) | 2026-11-25 |

## 6. Tools (coins, kept forever)

One hand tool per kind of step, as in the Tools window mock (`tools.html`). Each starts at level 1 and has two upgrades; a level makes that step about 15% quicker (fewer strokes or a wider scrub), which helps stars. The old Bubble Soap and Pro Brush become Sponge level 2 and Brush level 2.

| key | value | why | changed |
|---|---|---|---|
| `tool.Sponge` | L2 45, L3 250 | Sponge L2 is the first purchase, after about 3 cats (pace) | 2026-11-25 |
| `tool.Brush` | L2 120, L3 600 | | 2026-11-25 |
| `tool.Tweezers` | L2 120, L3 600 | | 2026-11-25 |
| `tool.Shower` | L2 250, L3 1,200 | | 2026-11-25 |
| `tool.Dryer` | L2 600, L3 2,000 | | 2026-11-25 |
| `tool.NailClipper` | L2 400, L3 1,500, shown from 15 spa stars | Claws are the rarest step | 2026-11-25 |
| `tool.levelSpeed` | −15% step time per level | | 2026-11-25 |
| `tool.GoldenSponge` | game pass 99 Robux, the Sponge at its best plus gold bubbles, +20% on cats washed by hand | Pass, never sold for coins | 2026-11-25 |

The Bows card in the Tools window sells the next bow tier from section 5 (the mock's "300, +3" becomes Silk, 150, +4).

## 7. Workers

| key | value | why | changed |
|---|---|---|---|
| `worker.Jo.price` | 150 coins, station included | First worker after about 15 cats | 2026-11-25 |
| `worker.Sam.price` | 1,200 coins, station included | | 2026-11-25 |
| `worker.Lou` | game pass 249 Robux, station included | Works exactly like Jo and Sam | 2026-11-25 |
| `worker.washSeconds` | L1 50, L2 75, L3 110, L4 150 | About twice the player's time at the 8 s step target | 2026-11-25 |
| `worker.share` | 25% of base × dirt at level 1, +3% each level | No stars, early pick, bow or tip for workers | 2026-11-25 |
| `worker.levelCost` | L2 200, L3 500, L4 1,200, L5 3,000 | | 2026-11-25 |
| `worker.levelSpeed` | −5% wash time each level (L5 = ×0.8) | | 2026-11-25 |
| `worker.maxLevel` | 5 | | 2026-11-25 |
| `worker.modes` | about to leave, rarest, dirtiest, first in line (default first in line) | | 2026-11-25 |
| `worker.nameLength` | 3 to 16 letters, filtered | | 2026-11-25 |
| `worker.reserve` | a customer the player picked (Who's next? or Wash next) is kept for the player for 15 s or until it reaches the player's tub; workers take the next one by their mode | A worker never takes the cat the player is walking to (Review-QA on PR 562) | 2026-11-26 |
| `worker.windowFromHud` | the Helpers window opens from its HUD button anywhere in the spa; Picks and Level up work from there with no distance check (the server still checks ownership, coins and the rate limit) | A menu choice is not a world interaction; a greyed button that asks the player to walk to a station would read as broken | 2026-11-26 |
| `worker.count` | 3 at most (Jo, Sam and Lou) | | 2026-11-25 |
| `worker.petCap` | a worker's pet boosts add together and are capped at +30% | Two pets with the second slot pass, star ups included, never pass the cap | 2026-11-25 |
| `worker.doubleCoins` | 2x Coins and the Golden Sponge apply only to cats washed by hand, never to worker pay or the tip jar | Keeps the guard rail true for pass owners | 2026-11-25 |

Guard rail check (must stay true, with margin): a player washing Common level 2 cats by hand, with no passes, at the 8 s step target (4.5 steps, about 36 s a cat) at 2 stars makes about 0.49 coins a second ((10 × 1.25 × 1.1 + 4) / 36 s). Three level 5 workers at the pet cap take 75 × 0.8 = 60 s a cat and make 3 × (12.5 × 0.37 × 1.3 / 60 s) ≈ 0.30 coins a second, about 61% of the player. Any change to `worker.*`, `pet.*`, `pay.*` or `dirt.stepSeconds` re-runs this sum.

## 8. Builds and Finish now

| key | value | why | changed |
|---|---|---|---|
| `build.SecondTub` | 90 coins, 15 s | The first short station build, after about 8 cats. Must stay 15 s or less: Finish now hides under 15 s left, so no Robux price shows in the first minutes (Review-QA, issue 531); a longer time goes to Derek first | 2026-11-25 |
| `build.ThirdTub` | 1,000 coins, 30 min | The first long build, offered about minute 15 | 2026-11-25 |
| `build.FourthTub` | 5,000 coins, 4 h | "Up to four tubs" | 2026-11-25 |
| `build.VipRoom` | 15,000 coins, 12 h | | 2026-11-25 |
| `build.Garden` | 25,000 coins, 24 h | Never more than 24 h | 2026-11-25 |
| `build.slots` | 1 builder; 2 with the Second Builder pass | | 2026-11-25 |
| `finishNow.price` | ≤5 min 5, ≤30 min 15, ≤2 h 35, ≤8 h 75, more 99 Robux | From the design; waiting is always free | 2026-11-25 |

What each build does once finished (answers Gameplay-Engineer on issue 515, 2026-11-26):

| key | value | why | changed |
|---|---|---|---|
| `build.tub.effect` | each built tub adds one bench place (3 at the start, then 4, 5, 6), takes 1 s off `bench.refillSeconds` (6, 5, 4, 3) and adds +2 coins to every customer's pay | More cats to choose from and a busier spa as the player and workers wash more; the bench never goes past 6 | 2026-11-26 |
| `build.VipRoom.effect` | special visitors come every 5 to 10 min of play instead of 8 to 15, and the room shows the player's washed special cats as residents | The rare visitors are the best part, so the big build brings more of them | 2026-11-26 |
| `build.Garden.effect` | the tip jar holds 12 hours instead of 8 and fills 25% faster; the player's and workers' pets play there | The longest build pays off the next morning, the day 2 reason | 2026-11-26 |
| `build.oldStations` | Brush Table, Dryer, Bubble Bath and Pawdicure leave the Build board while `dirtLevels` is on (every step is in from the start); with it off they stay as they are | No build that is only a hidden pay bonus | 2026-11-26 |

`bench.size` above becomes 3 plus one per built tub. The guard rail in section 7 holds: tubs add bench places, not washers.

## 9. Special visitors

| key | value | why | changed |
|---|---|---|---|
| `special.first` | 4:00 of the first session, scripted | Inside the first five minutes | 2026-11-25 |
| `special.firstCrate` | 100% (the first one only) | Derek: "script the first one to drop a crate" | 2026-11-25 |
| `special.every` | a random 8 to 15 min of play after the first | Now and then | 2026-11-25 |
| `special.atOnce` | 1 per spa | | 2026-11-25 |
| `special.crateChance` | 5% | "A crate from a visitor is rare" | 2026-11-25 |

## 10. Crates and pets

| key | value | why | changed |
|---|---|---|---|
| `crate.price` | 49 Robux, or 5 for 199 | From the design; hidden where paid random items are restricted | 2026-11-25 |
| `crate.chance` | Common 50 (two pets, 25 each), Uncommon 26 (two, 13 each), Rare 16 (two, 8 each), Epic 6 (one), Legendary 2 (one) | Adds to 100; shown as percentages before any buy or open | 2026-11-25 |
| `crate.good` | the day 2 crate: Common 30, Uncommon 30, Rare 24, Epic 12, Legendary 4 | Earned only, never sold; its own chance list shows | 2026-11-25 |
| `pet.boost` | Common +5%, Uncommon +8%, Rare +12%, Epic +16%, Legendary +20% | Every pet's boost is its rarity's, so the crate's chance list shows each pet with its chance and its boost. With a worker, on that worker's pay (capped, section 7); with the player, on tips. Boosts add, never multiply | 2026-11-25 |
| `pet.starUp` | 3 of the same pet fuse into star 2 (boost ×1.5), 3 star 2 into star 3 (boost ×2) | Fusing is free and fixed | 2026-11-25 |
| `pet.slots` | 1 for the player, 1 per worker; 2 each with the pass | | 2026-11-25 |

Pet names and looks come from Model-Agent. The rarity split above fixes the chances whatever the names are.

## 11. Quests

| key | value | why | changed |
|---|---|---|---|
| `quest.daily` | 2 a day from the pool, reset at midnight in the player's time zone: the server saves the offset once at first join (from the client clock, clamped to whole hours from −12 to +14) and never takes a new one, so changing a clock cannot reset quests early | "A couple of daily quests" | 2026-11-25 |
| `quest.dailyPool` | Wash 5 customer cats 50, Put a bow on 3 cats 40, Wash 2 cats at dirt level 3 or 4 60, Get 3 stars 4 times 50, Take 2 cats early 40 | All doable in one 20 min session | 2026-11-25 |
| `quest.weekly` | Get 3 stars on 20 cats 300, Wash 2 special visitors' cats 300, Wash 10 cats at dirt level 4 300 | Reset Monday 00:00 UTC | 2026-11-25 |
| `quest.weeklyCrate` | a normal crate when all three weekly quests are done | Earned, never sold for Robux | 2026-11-25 |

## 12. Check in card

Days played, not days in a row. Missing a day loses nothing.

| key | value | why | changed |
|---|---|---|---|
| `checkin.1` | 50 coins | | 2026-11-25 |
| `checkin.2` | the good crate | "Day 2 the good crate" | 2026-11-25 |
| `checkin.3` | 100 coins | | 2026-11-25 |
| `checkin.4` | Silk bow | Worth 150 | 2026-11-25 |
| `checkin.5` | 200 coins | | 2026-11-25 |
| `checkin.6` | 300 coins | | 2026-11-25 |
| `checkin.7` | a normal crate | Then the card starts again | 2026-11-25 |

## 13. Tip jar, notifications

| key | value | why | changed |
|---|---|---|---|
| `jar.rate` | 30 coins an hour per hired worker while away | | 2026-11-25 |
| `jar.cap` | 8 hours of fill | A night's sleep | 2026-11-25 |
| `jar.notify` | when full, 13 and over who said yes, at most once a day | | 2026-11-25 |

## 14. Shop prices (Robux)

| key | value | changed |
|---|---|---|
| `pass.DoubleCoins` | 199 | 2026-11-25 |
| `pass.SecondBuilder` | 299 | 2026-11-25 |
| `pass.GoldenSponge` | 99 | 2026-11-25 |
| `pass.Lou` | 249 | 2026-11-25 |
| `pass.SecondPetSlot` | 249 | 2026-11-25 |
| `starterPack` | 299 for Golden Sponge, Second pet slot and 2x Coins (worth 547, saves 45%), 72 hours from first join on the server clock, then gone | 2026-11-25 |

## 15. The pace number

Cats washed to afford the next purchase. Re-time on the iPhone 12 once dirt levels are in.

| Purchase | Target | Expected with these values |
|---|---|---|
| Sponge level 2 (45) | after 3 cats | The three tutorial cats pay about 16 each, so 48 after cat 3 |
| Second Tub (90) | after about 8 cats | Cats 4 to 8 pay about 22 each, so about 113 spare after cat 8 |
| Jo (150) | after about 15 cats | Cats 9 to 15 pay about 23 each, so about 160 after cat 15 |
| Third Tub (1,000) | offered about minute 15, bought in the second session | |

Average early cat (no friends, plain ribbon): base 14.3 across rarities × dirt 1.18 × stars 1.1 (1 to 1.2) + tip 3 + bow 2 ≈ 23.6 coins.
