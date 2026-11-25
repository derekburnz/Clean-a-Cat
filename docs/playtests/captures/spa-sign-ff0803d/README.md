# Spa sign on ff0803d

Local unsaved build of ff0803d in Studio, iPhone 13 device frame (750x390), camera field of view 70. Test names only. Pavement camera 8.7 studs from the sign, road camera 19.9 studs.

## Bug: the text is not scaled
`line()` in SpaSignController sets `TextScaled = true` and then `TextWrapped = false`. In Roblox, turning TextWrapped off also turns TextScaled off (checked on a bare TextLabel: scaled true then wrapped false gives scaled false). So both lines draw at the default size 8 (a line 4 px tall on the pavement, 2 px on the road). Pictures 1a and 1b show the sign as built. Setting TextWrapped false before TextScaled true (or leaving it out) keeps the scaling.

## With TextScaled turned back on (client-only test)
For pictures 2 to 5 I set TextScaled back to true on the two labels from the client, to show the intended layout.

| Sign | Name line | Text size | Line height pavement / road (px) | Caps about (px) | Reads from the road |
|---|---|---|---|---|---|
| 20 W letters | WWWWWWWWW...'s | 33 | 17.6 / 7.7 | 12 / 5 | only just, letters run together |
| Bartholomew Montgomery | Bartholom...'s | 52 | 27.7 / 12.1 | 19 / 8 | yes |
| Tester Mia | Tester Mia's | 56 (cap) | 29.9 / 13.1 | 21 / 9 | yes |
| Empty plot | Clean a Cat | 56 (cap) | 29.9 / 13.1 | 21 / 9 | yes |
| Second line | Spa | 34 (fixed) | 18.1 / 7.9 | 13 / 6 | small but readable |

- Names over 10 characters keep 9 plus "...": yes.
- The name plus 's stays on one line in every case, and "Spa" sits below at one size.
- Contrast: ink 47,62,92 on the face colour 255,246,236 is 10:1. As rendered, the face is lit to about L 0.38, and the text pixels against the face measure about 7:1 (picture 3a).

## Suds's help bubble at "Open the spa!" (sudsBubble on)
- "Let's open the spa!" shows at the photo tap, 1.4 s before the "Meet Suds!" card, and stays under the card (picture 6).
- "First customer!" shows 19 ms after the camera is back with the player. The first customer comes 6 s later, after the bubble.
