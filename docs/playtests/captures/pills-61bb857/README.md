# Prompt pills on 61bb857

Measured in a local unsaved build of 507cdce (61bb857 plus the spa sign only), iPhone 13 device frame (750x390).

No pictures: the pills are BillboardGuis in PlayerGui.CleanACat_Prompt and Studio's screen capture and video capture do not draw them. The numbers below are read from the live GUI objects during Play instead.

| Prompt | Pill size (px) | Key chip | Word |
|---|---|---|---|
| Box | 73x44 | none | Open! |
| Suds | 118x44 | E | Pick up |
| Tub with Suds | 139x44 | E | Wash him |
| Wash marker | 45x44 | none | Wash |

- All are AlwaysOnTop with ExtentsOffset (1,0,0) and SizeOffset 0.6, so they sit beside the box or the cat, not over it.
- Every prompt has HoldDuration 0, so there are no hold prompts to time.
- The largest pill is 139x44 on a 750x390 frame, so none covers the view.
- Desktop E and a touch tap both trigger them.
