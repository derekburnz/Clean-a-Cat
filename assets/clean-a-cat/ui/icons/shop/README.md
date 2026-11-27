# Shop card pictures

Pictures for the Robux shop's cards (#1030), uploaded to the group and shown by id. Made by
`ui_renders.py --only shop_` then `ui_compose.py` (the `shop_<Item>_ink` picture, 512 px, see-through, trimmed with
the ink outline all round). Render, don't edit by hand.

| File | Card |
|---|---|
| `CleanACat_UI_Shop_Coins2x.png` | 2x coins: two stacks of gold coins with "2x" (#1122; was a heap). The coins carry a star, never a money sign (Review-QA's gate) |
| `CleanACat_UI_Shop_Coins3x.png` | 3x coins: a chest brimming with coins and "3x" (#1122; was the same heap, only bigger) |
| `CleanACat_UI_Shop_Builder2.png` | the second builder: the builder with his toolbox and "+1" |
| `CleanACat_UI_Shop_GoldenSponge.png` | the golden sponge with sparkles |
| `CleanACat_UI_Shop_ExtraWorker.png` | the Extra Worker pass: Lou with "+1" (never Jo's picture, #1036) |
| `CleanACat_UI_Shop_PetSlot2.png` | the second pet slot: two pets with "+1" |
| `CleanACat_UI_Shop_StarterPet.png` | the starter pack (#1090): Midas the golden pet, whole, wings out, with sparkles. Never a sponge (Derek) |

## One picture per thing to buy (#1122)

Derek, 2026-11-27: "I am seeing certain items to buy sharing same icon fix that". No two buyable things share a
picture, in the game or on Roblox. Made by `buy_art.py` through `ui_renders.py --only shop_Build,shop_Tool,shop_Bow,shop_Crate,shop_Finish,shop_Coins`.

| File | For |
|---|---|
| `CleanACat_UI_Shop_Build_<Id>.png` | each build of BuildRules: `BrushTable`, `Dryer`, `BubbleBath`, `Pawdicure` (the station), `SecondTub`, `ThirdTub`, `FourthTub` (that many tubs and the number), `Garden`, `CatHotel`, `HotelRoom3` (mint, Tux asleep), `HotelRoom4` (butter, Marble asleep) |
| `CleanACat_UI_Shop_Tool_<Id>.png` | each tool of ToolRules: `BubbleSoap` (the bubble sponge), `ProBrush` (the fluffy brush) |
| `CleanACat_UI_Shop_Bow_<Tier>.png` | each bow sold: `Silk` (double bow), `Satin` (royal bow), `Golden`. The Ribbon, never sold, keeps the HUD's bow |
| `CleanACat_UI_Shop_Crate1.png`, `Crate5.png` | the products CrateOne (one crate) and CrateFive (a stack of five and "x5") |
| `CleanACat_UI_Shop_Finish1.png` to `Finish5.png` | the products FinishTier1 to 5: a stopwatch in the tier's colour with its time (5m, 30m, 2h, 8h, 8h+) |

A new buyable thing gets its own picture here before it ships; a tag alone on a shared picture does not count.

Every picture goes through Review-QA's image gate and `.github/upload-allow.txt` before `upload-asset.yml`.
