# Spa sign long names on 02b38ae

Local unsaved build of 02b38ae (after PR 390) in Studio, iPhone 13 device frame (750x390). Test names only.

| Picture | Camera | Sign text |
|---|---|---|
| 1-road-20-letter-name.jpg | road, about 20 studs away | 20 W letters, shown as WWWWWWWWWWW...'s Spa (from the game code) |
| 1b-road-20-letter-name-sign-3x.png | crop of picture 1, enlarged 3 times | same |
| 2-pavement-20-letter-name.jpg | pavement, 8.6 studs | same |
| 3-road-bartholomew-smithers.jpg | road, about 20 studs away | Bartholomew...'s Spa (text set on the client to what the code gives for "Bartholomew Smithers") |

Results
- The cut works: 11 characters plus "..." (WWWWWWWWWWW...'s Spa), text bounds 280x54 inside 330x114.
- "...'s Spa" still does not fit on one line, so "Spa" wraps to a second line and the text scales down.
- From the road the 20 W name is still a dense line about 5 px tall: the dots and "'s" can't be read, "Spa" only just.
- A mixed name of the same length (Bartholomew...'s Spa, bounds 284x86) is readable from the road.
