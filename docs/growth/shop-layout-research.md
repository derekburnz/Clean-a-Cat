# How good Roblox shops lay out and sell (Growth-Agent, 2026-11-27; issue 1070)

For Design-Agent's shop layout (issue 1030). Labels: OFFICIAL = on a Roblox page, SEEN = Derek's rival screenshots (ideas only, nothing copied), JUDGMENT = our call. No prices or sales numbers here (public repo). Roblox gives no price points or card order rules, so those parts are JUDGMENT.

## What Roblox itself says
- OFFICIAL, shop: a shop should be integrated (easy to find, same look as our UI, quick to open and leave), contextual (a name and price alone do not show value; say why the item matters) and inviting (a place to browse). Describe items accurately so players know what they get.
- OFFICIAL, new Roblox Shop (developer announcement, 2026, not a docs page): Roblox builds a storefront of passes, developer products and Robux packages, personalized per player, with a Top Picks section. Items are grouped by category, and the global Shop button is off by default. There is no manual card order yet. Our own shop still works; we choose later whether to turn the Roblox one on.
- OFFICIAL, products: icon 512 by 512 at most, keep the important part inside the circle; a product's category feeds the in game Shop; listed products can appear on Roblox surfaces, so each needs its own icon and an honest description.
- OFFICIAL, sales: a discount must be genuine and fair; an always on "sale" at the same price is not, and a very short discount that creates pressure is not fair. Do not use a countdown that is wrong or restarts by itself. Do not claim an item is almost gone unless it is true.
- OFFICIAL, young players: keep promotions suitable for all ages. Roblox's swaps: "GET IT NOW" becomes "View Item", "LAST CHANCE, ACT NOW" becomes "See Price", "BUY BEFORE IT'S GONE!" becomes "Open Shop".
- OFFICIAL, random items bought with Robux: show every outcome and its odds as percentages that add to 100 before purchase, with a word and not a lone (i) icon; check PolicyService per player and give restricted players another path. A key or ticket that leads to a random reward counts too.
- OFFICIAL, starter pack: an initial offer shown within the first few minutes. Roblox gives no price or content guidance for it.

## What rival games do (SEEN, 2026-11-24 screenshots)
- Tabs along the top or side: Deals or Featured first, then Boosts, Pets or Packs, Passes, Cash. One screen shows about three to four large cards, never a long grid.
- First card is the best offer, bigger than the rest, with a short bullet list of what is inside and one big green buy button with the price on it.
- The starter bundle appears once as a pop up after the first session, shows contents with icons, a struck through regular price and a percent off, and a close button in the top right.
- Gift button beside the price on cards; a tag such as Limited or One time on the card corner; Hired 0 of 5 style counters on helpers.
- Seen and not wanted by us: red "only N left" counters and "best deal" ribbons stacked on several cards (pressure, and a young audience), and a rainbow header that competes with the cards.

## Recommendations for our shop (JUDGMENT, fits our rules)
1. Three tabs at most: Boosts and Passes, Crates, New player offer (while it lasts). Skips stay on the build panel.
2. Three to four cards visible at once on a phone, each at least a finger wide, one clear button per card with the price on it. Icon on the left or top, one line saying what it does, no more than three bullets.
3. Put the starter offer first while it is available, then passes ordered by what a new player needs first. Cheapest useful purchase near the top, not hidden.
4. Strike through the regular price only for a real sale with a planned end (see `launchSale` in the go live checklist). No "best value" ribbon, no stock counters, no restarting clocks.
5. Crates: odds one tap away and in words ("Chances"), shown before the buy button; Robux crate hidden where PolicyService restricts.
6. Button words: "View Item", "See Price", "Open Shop" style, never "BUY NOW" urgency lines.
7. Every card gets its own icon that passes the image gate (no hand gestures, nothing a filter could misread), 512 by 512 with the picture inside the circle.
8. A gift button beside the price is fine if it uses the same purchase flow; it adds a second path, so keep it off the first card.
9. A Featured or Deals tab only if it holds real, current items; an empty tab teaches players to skip it.

## Open for Derek
Whether to turn on Roblox's own global Shop button as well as ours (JUDGMENT: not at launch; one shop, ours, so the starter offer and crate rules stay in our hands).
