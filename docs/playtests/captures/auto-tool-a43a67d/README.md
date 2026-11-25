# autoTool and toolCursor on f15cca2

Local unsaved build of f15cca2, which includes a43a67d. The switches were set only in this local copy: autoTool and toolCursor on, and washChecklist on in one run and off in the other. Views:
- iPhone 13 (750x390) stands in for the iPhone 12, which has no Studio preset.
- iPad 10th generation (1178x819) is the iPad view.

Suds was washed with a fresh save; the customer was the next cat.

## autoTool (pictures 01 to 07)
| Run | View | Wash | Tool tray | Step pips | Top line | Objects in the old tray area |
|---|---|---|---|---|---|---|
| checklist on | iPhone 13 | Suds | none | shown (no room for the list) | Step 1 of 3 · Scrub the mud | 0 |
| checklist on | iPhone 13 | customer | none | shown | Step 1 of 4 · Scrub the mud | 0 |
| checklist on | iPad 10 | customer | none | the tick list takes their place | Step 1 of 4 · Scrub the mud | 0 |
| checklist off | iPhone 13 | Suds | none | shown | Step 1 of 3 · Scrub the mud | 0 |
| checklist off | iPad 10 | Suds | none | shown | Step 1 of 3 · Scrub the mud | 0 |
| checklist off | iPhone 13 | customer | none | shown | Step 1 of 4 · Scrub the mud | 0 |
| checklist off | iPad 10 | customer | none | shown | Step 1 of 4 · Scrub the mud | 0 |

The top line named each step as the steps went by: Scrub the mud, Brush the fur, Pick a bow, Take the photo. The old tray area checked is the bottom 120 px of the middle third of the screen, and it was empty in every case. I missed Suds's wash on the iPad with the checklist on: the device switch came after his photo.

## toolCursor (pictures 10 to 15)
Real drags work in the device simulator. The tool's position is logged every frame against the touch.
- The sponge (mud) and then the brush follow the finger: passes.
- Phone, touch on the right half below the head (touch 383,120): the tool goes up and to the right (tool 387..451, 51..115) next to the head. It touches the edge of the head box (338..406, 28..79).
- Phone, touch on the left half (touch 359 to 367, about 123): the tool goes up and to the right and covers the face (picture 11). At touch x 351 to 355 it goes to the left instead, so a small stroke across x 355 to 359 flips it from side to side every frame.
- iPad, touch on the right half below the face (touch 610,320): the tool goes up and to the left (527..604, 237..314) and covers the chin (head box y 128..258; picture 13). The head check uses the head's centre (y 191), which is more than 1.25 tool sizes above the touch, so no flip happens.
- Bow tap and photo tap: nothing shows. Passes.
- Lift: the tool shrinks from 1.0 to 0.6 over 0.1 s, then hides. Passes.
- Top edge: dragging from the cat up to touch y 4 puts the tool at y -63 to 0 in GUI space. It sits in the top bar strip and its top 5 px is cut off the screen (picture 14). It also covers the step line and the Walk button.
- Left edge: dragging to touch x 3 sends the tool to the right, and it is not cut off (picture 15).
- The tool only shows when a drag starts on the cat. A touch that starts elsewhere shows nothing.
