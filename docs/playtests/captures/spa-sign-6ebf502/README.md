# Spa sign on 6ebf502

Local unsaved build of 24e9389, which includes 6ebf502. The iPhone 13 device frame (750x390) was used, with the camera's field of view at 70. Nothing was forced on the client: the labels are as the game drew them. Test names only. The pavement camera was 8.7 studs from the sign, and the road camera 19.9 studs.

## Both lines scale
Read from the labels during Play. TextScaled is true and TextWrapped is true on both labels, on the owned plot and on the empty plot. Setting TextScaled turns wrapping back on, but a single line wins at these sizes. The TextSize property reads 8 even while scaling. The rendered size is the one the bounds give:

| Sign | Name line | Rendered size | Bounds | Caps pavement / road (px) | Reads from the road |
|---|---|---|---|---|---|
| 20 W letters | WWWWWWWWW...'s | 33 | 289x33 | 12 / 5 | only just, letters run together |
| Tester Mia | Tester Mia's | 56 | 271x56 | 21 / 9 | yes |
| Empty plot | Clean a Cat | 56 | 263x56 | 21 / 9 | yes |
| Second line | Spa | 34 | 51x34 | 13 / 6 | small but readable |

- 20 W letters are cut to 9 plus "..." and stay on one line.
- Contrast: the ink on the face colour is 10:1. As rendered, the text pixels against the lit face measure 7.3:1 (picture 2a).
