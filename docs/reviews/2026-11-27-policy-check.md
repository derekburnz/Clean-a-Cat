# Policy check of everything sold, 2026-11-27

Issue 531, policy part. This review was done by Motion-FX-Agent at Review-QA-Agent's request, so the author of none of these features signs them off. The code was read on main 788b6628, against the `monetization-policy` and `roblox-policy-compliance` skills and CLAUDE.md rules 9 and 10. The review was code only: nothing was bought, and no live setting was read.

**Verdict: no violation found in code.** Two owner decisions carry policy risk and are listed so they stay visible: the like and favourite rewards, and the starter pack countdown. Three small notes need no change now. Nothing here blocks dev. The live items still wait on the owner as before.

## What is sold

| Item | Type | Key / file | Random? | Price shown before confirm | Verdict |
|---|---|---|---|---|---|
| 2x Coins, Second Builder, Golden Sponge, Lou, 2nd pet slot | game passes | `shared/Passes.luau`, `PassService` | no | yes: the shop card reads `PassPrice_<key>`, which `GetProductInfo` sets from Roblox's own price | OK |
| Finish now, five tiers | developer products | `Products` FinishTier1 to 5, `BuildService`, `BuildBoardController` | no | yes: "Finish now for N Robux" from the live price; no button while the price is unknown | OK |
| 1 crate, 5 crates | developer products | `CrateRules.SHOP`, `CrateShopService`, `UI/CrateWindow` | **yes, a paid random item** | yes, with the full chance list on the same window | OK, see below |
| Starter pack (Golden Sponge + 2nd pet slot + 2x Coins) | developer product | `StarterRules`, `StarterService`, `UI/StarterWindow` | no, fixed contents | yes; the struck total and saving come from live prices and are hidden if any price is missing | OK, see decision 2 |
| Private servers | Roblox setting | not in code | no | Roblox's own page | owner's setting |

No product gives coins, and coins never buy a crate (`CrateRules`, `PetService`). So rule 9's "currency that Robux can buy" case does not arise: coins are earn-only.

## Paid random items (the Robux crate)
- **Odds before purchase:** `CrateRules.odds` is the same list the roll uses. The normal crate is Common 50, Uncommon 26, Rare 16, Epic 6, Legendary 2, which sums to 100. Each rarity is split evenly per pet. The window shows the list beside the buy rows (`CrateViewRules.shopRows`), so it is seen before any buy. The bought crate is the earned normal crate with the same odds. There are no luck boosts, pity systems or rate-ups, so no extra disclosure is needed.
- **PolicyService:** `CrateShopService.readPolicy` reads `GetPolicyInfoForPlayerAsync` on join with three tries. Only a clear `ArePaidRandomItemsRestricted == false` turns on the `CrateShop` attribute. A failed read counts as restricted. The server checks the policy again on every `RequestBuyCrate` before it prompts. Restricted players keep the earned crates.
- **No near miss or build-up:** the crate opens the same way every time, whatever is inside (`Effects/Crate.luau`).
- **Trading:** there is no trading, so `IsPaidItemTradingAllowed` is not needed.

## Receipts and grants
- `PurchaseService` is the only owner of `ProcessReceipt`. Each receipt's PurchaseId is saved with its grant, and `PurchaseGranted` is returned only after `DataService.saveAndConfirm` sees it stored. A repeat receipt is not granted twice. A player who is missing or still loading gets `NotProcessedYet`. **OK.**
- Passes are kept from `UserOwnsGamePassAsync` on join and from the server's `PromptGamePassPurchaseFinished`, so there is no rejoin needed. **OK.**
- Every buy remote is rate limited: `RequestBuyCrate`, `RequestFinish` and `RequestPass` all allow 1 a second with a burst of 2. **OK.**

## Dark patterns (young audience)
- No "only N left", no fake scarcity, no spending streaks and no nag after a decline were found in the shop, crate or starter code. The crate window copy avoids "best value" and hurry words (`CrateViewRules`).
- Every prompt opens only from the player's own tap.

## Owner decisions that carry policy risk (no change made)
1. **Like and favourite rewards.** The gift card's like row pays 150 coins (`FreeRewardRules.LIKE_COINS`) after the like ask, and the gift crate is given once for favourite plus group join (`GiftService`).
   - The house rule in `monetization-policy` says never reward likes, favourites or follows.
   - Derek decided this on 2026-11-25 ("make it prompt them to like check and then give them it"). Growth found no Roblox rule for or against it then.
   - Mitigations already in the code: the like is never read or faked as checked, the card says "A gift either way", and the coins come whether or not the player likes.
   - Risk: Roblox may treat rewarded likes or favourites as manipulating ratings. Developer forum threads disagree, and there is no official rule page.
   - Recommendation: before live, re-check Roblox's current Experience Guidelines. If any wording appears against incentivised ratings, turn the like row's coins into a thank-you that is not tied to the ask. The group reward is the common, accepted pattern.
2. **Starter pack countdown.**
   - The 72 hours are real and per player: they start from the first join, are kept on the server (`save.starterEndsAt`), and never restart or extend.
   - At zero the pack is gone for good, and the three passes stay in the shop at their own prices.
   - The HUD shows days, hours and minutes only. Nothing changes near the end, and no "hurry" words appear.
   - This meets "no fake countdown". A countdown to a child is still time pressure, which Derek chose (2026-11-25). Keep it calm, as it is.

## Small notes (no change needed now)
- Prices are read once per server (`readPrices`). If the owner changes a price on Roblox, buttons show the old number until servers restart. Roblox's own prompt always shows the real price, so nobody is charged a hidden amount. After any price change, restart dev (and live only on Derek's word) so the cards match.
- An exploiter in a restricted region could open the crate product's prompt from their own client. The receipt is honoured, since they paid. Normal players in restricted regions never see or reach it. This is the standard limit of client prompts and needs no change.
- Live product and pass ids are all 0 in `Products` and `Passes`, so nothing can be bought on live yet. Promotion day (issue 893) fills them, and this check should be repeated for the live prices then.

## Before live (for the promotion checklist, issue 893)
- Fill the live ids, then check every live price shows on its button and the crate odds window shows before the buy rows.
- Play once as a PolicyService-restricted account (Studio: Player attribute `TestPaidRandomRestricted`). Crate rows must be hidden, and earned crates must still open.
- Re-read Roblox's paid random items page and Experience Guidelines for any change since this check: https://create.roblox.com/docs/production/monetization/paid-random-items
