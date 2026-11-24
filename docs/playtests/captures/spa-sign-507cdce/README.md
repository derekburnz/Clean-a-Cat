# Spa sign on 507cdce

Local unsaved build of 507cdce in Studio, iPhone 13 device frame (750x390), seeded save. Names are test names only.

| Picture | Camera | Name on the sign |
|---|---|---|
| 1-pavement-tester-mia.jpg | pavement, 8.6 studs in front of the sign | Tester Mia (text set on the client for the picture) |
| 2-road-tester-mia.jpg | road, about 20 studs away | Tester Mia |
| 3-pavement-20-letter-name.jpg | pavement, 8.6 studs | 20 W letters (widest 20 character name) |
| 4-road-20-letter-name.jpg | road, about 20 studs away | 20 W letters |

Results
- The owner's name is on the street side of the window sign (Front face, facing the road).
- A 20 character name fits the panel: text scaled, bounds 289x32 inside 330x114. It wraps "Spa" to a second line and becomes small.
- Tester Mia's Spa: bounds 287x44, easy to read from the pavement and readable from the road.
- From the road the 20 W name is a thin unreadable line.
- Empty plots 2 to 6 show "Clean a Cat Spa".
- Text 47,62,92 on face 255,246,236 is 10.0:1 contrast.
- The leave test (sign goes back to "Clean a Cat Spa" when the owner leaves) needs two clients and was not run.
