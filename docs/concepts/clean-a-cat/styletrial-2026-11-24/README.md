# Style trial captures, 2026-11-24 (#186, PR #213)

The Settings trial card from PR #213 (head 7c45539), captured in Studio's device simulator in a fresh local place that was never saved or published. The game builds the card only when the `styleSheetUi` switch is on as the client starts, so for these captures I built both versions in a test session with `StyleTrial.build(gui, true)` (styled by a StyleSheet) and `StyleTrial.build(gui, false)` (plain, every look property set in code). No account names appear in any picture.

| File | What it shows |
|---|---|
| `styletrial-styled-phone.jpg` | Styled card, iPhone 14 (viewport 750 x 390) |
| `styletrial-plain-phone.jpg` | Plain card, iPhone 14 |
| `styletrial-styled-tablet.jpg` | Styled card, iPad 10th generation (1180 x 820) |
| `styletrial-plain-tablet.jpg` | Plain card, iPad 10th generation |
| `styletrial-styled-console.jpg` | Styled card, Xbox One (1920 x 1080) |
| `styletrial-plain-console.jpg` | Plain card, Xbox One |
| `styletrial-styled-pc.jpg` | Styled card, average Windows PC (1366 x 768) |
| `styletrial-plain-pc.jpg` | Plain card, average Windows PC |
| `styletrial-buttons-pc-1-normal.jpg` | Styled card on PC, no pointer over a button |
| `styletrial-buttons-pc-2-done-hover.jpg` | Pointer over the green Done button |
| `styletrial-buttons-pc-3-done-pressed.jpg` | Done held down |
| `styletrial-buttons-pc-4-x-hover.jpg` | Pointer over the red X |
| `styletrial-buttons-pc-5-x-pressed.jpg` | X held down |

The card is 340 x 256 and centred at every size. Done is 160 x 52 and X is 52 x 52, and nothing is cut off or under the top bar. In the hover frames both buttons go darker, and in the pressed frames they go paler. That is the opposite of the sheet's `:Hover` (lighter) and `:Press` (darker) colours, most likely because the buttons keep Roblox's default `AutoButtonColor = true`.
