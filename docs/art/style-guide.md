# Clean a Cat art style guide

Owner: asset-artist (Model-Agent). Every model, Studio placeholder and UI colour comes from this file. Change this file first, then the generators in `assets/clean-a-cat/blender/`, then rebuild.

Direction: **Bubble Pastel** (decided 2026-11-23, see `docs/decisions.md`). Alternates if the owner swaps: **Cozy Storybook** (warm wood, terracotta tiles, soft painted textures on one small atlas; warmer, but needs textures and loses contrast with brown mud) and **Bright Toy** (saturated primaries, glossy plastic; loud, but looks like many simulators on the charts).

## 1. Mood in one paragraph

A bright little spa on a sunny street. Cream walls, mint tiles, bubblegum towels and sky blue water, with white foam everywhere. Shapes are soft blocks: chunky, toy-like, never thin or spiky. The cats are the colour in the room, and the one dark colour in the whole game is mud, so a dirty cat reads as dirty from across the street and the reveal is the brightest moment on screen.

## 2. Palette

All colours live in `assets/clean-a-cat/blender/palette.py` (the source of truth; this table mirrors it). The texture `CleanACat_Palette.png` is 8 swatches wide and 32 rows tall (256 x 1024). Every mesh face is UV-mapped to the centre of one swatch, so one material covers every model and a recolour is a swatch change. Rows 0 to 15 are the studio swatches from Derek's asset library, kept as they are so the library's builders still find every name. New swatches only ever go at the end so every index keeps its place.

### The five style colours (row 16)
| swatch | hex | use |
|---|---|---|
| spa_cream | #FFF6EC | walls, counters, the base of the room |
| spa_mint | #A8E6CF | tiles, station bodies, accents |
| spa_bubblegum | #FFB3C7 | towels, cushions, signs |
| spa_sky | #8FD3FE | water, tub insides, the dryer hood |
| mud | #5A4632 | mud blobs on a dirty cat, and nothing else |

Also in row 16: `mud_wet` #735A43 (the lighter wet mud; on pale fur the mud is `mud_drab` #6B6252 with `mud_drab_wet` #7E735F, see the mud rule), `foam` #FDFEFF, `spa_tile` #EEF4F6. In row 20: `water` #3FAEF2 (bath water: deeper than `spa_sky`, so it shows against the mint and cream of a bath) and `bubble` #BFE6FF (a soap bubble, drawn see-through at Transparency 0.4) (#111).

### Coats (rows 17 and 18) and details (row 19)
Each Cat Index cat has its own coat swatches (`coat_*`) so no coat repeats a Cat Cafe coat. Eyes (`eye_mint`, `eye_sky`, `eye_gold`), nose (`nose_bubblegum`), bows (`bow_pink`, `bow_mint`, `bow_sky`) and `wood_light` are in row 19. Rarity colours for frames and badges are the studio's row 2 (`rarity_common`, `rarity_rare`, `rarity_epic`, `rarity_legend`) plus `rarity_uncommon` #5FC98B in row 20.

**Mud rule:** every coat must stay readable against its mud. Brown `mud` vanishes on dark fur (Inky, Tux and the dark stripes, points and patches), so each blob takes whichever mud stands out more from the fur under it: `mud` or `mud_dust` #A39683, a grey dried clay, with `mud_dust_wet` #877B6A as its wet edge (#22; greyer since #117, because a warm tan on black fur read as a tortoiseshell coat at phone size). On pale fur (brighter than 0.5: Cotton, Toffee, Marble, LilacCloud, Starcoat and the white of Patches and Tux) the brown read as a brown patched coat at phone size, a dirty Cotton looking like Patches, so pale fur gets `mud_drab` #6B6252, a dull grey brown that no coat uses, with `mud_drab_wet` #7E735F (#155). Ginger and grey fur keep the brown `mud`. The mud also sits proud of the coat, so its shape reads.

**Mud shape (#107, #111, #113):** mud is a coat on the cat, built into its fur, never a ball, a raised block or a smear stuck on a face. Every piece is a slice of one of the cat's own blocks (the head, the chest, the haunches, a leg, a paw, the tail), a hair bigger than the block, so it wraps the block's edges and corners and lies flush, 0.02 studs off the fur, the way the coat's own stripes and patches do. A piece is one to four boxes: a wrap and the drips running from it, all on one grid of mud pixels (0.09 studs before the cat's scale) and all square to the cat's own lines. Together the 20 pieces read as a cat coated in mud: socks up the legs, caked haunches and flanks, a muddy back and chest, splats on the brow, the cheeks and the crown, the walking cat's tail tip dipped. A drip may hang one or two mud pixels past the bottom edge of the head or the walking cat's body (off the jaw, the chest and the belly, #117): fur never does that, so it is the cue that this is dirt. The eyes and the drawing of the face stay clear. Where a piece lies over a stripe, a patch or a fringe it stands 0.02 off the highest thing under it, so nothing of the coat pokes through. No part of a piece is further than 0.6 studs from its middle (the sponge's reach at the station's 1.5 times), and every piece of a sitting cat shows above the tub's water. Every third piece is the wet shade.

**Ragged edge (#155):** a coat's own patches are clean blocks, so clean blocks of mud read as a coat. Every piece also gets one thin box, one mud pixel wide and in the piece's own shade: the longest drip running down from its lower edge on a side of the cat, or the longest tooth out of it on a top. It lies flush like the piece, belongs to the same `_MudNN` Model and goes when it goes. It is placed by `dirt.py` from the piece's own boxes, never by hand, only where the face can be seen, and never on the face drawing or near an eye. One and not more (Review-QA): the edge reads from about twice phone size, where the colour does the work at phone size, and every box is a part on a phone.

## 3. Shape language

Blocks with small chamfers in the FBX (the Part models drop bevels). Big heads, short legs, chunky props. Nothing thinner than 0.1 studs that a player is meant to see. Rounded things (tub, cushions, bubbles) use balls and cylinders.

## 4. Scale

A Roblox R15 avatar is about 5 studs tall. A door is 7 studs, a counter 3.

| Thing | Size (studs) |
|---|---|
| Cat, walking | about 1 wide, 2 long, 1.9 tall |
| Cat, sitting | about 1.25 wide, 1.25 deep, 1.85 tall |
| Wash tub | 4.6 wide, 3.8 deep, rim at 1.7 (tap to 2.3); the cat sits on the inner floor at 1.2, so a sitting cat shows from the chest up |
| Sponge (in hand) | about 1 long, 0.7 wide, 0.5 tall; Bubble Soap and Golden are 1.2 times that |
| Brush (in hand) | about 1.3 long, 0.56 wide, 0.3 tall |
| Bow (on a cat) | about 0.75 wide, 0.25 tall |
| Window cushion | 2.3 across, 0.38 tall; its cat at 1.3 times |
| Tip jar | 1 wide, 1.5 tall |
| Spa sign | 6 wide, 2.4 tall, 6 studs up the front wall |
| Room gaps | 6 studs or wider everywhere a player or camera goes |
| Spa plot | 44 wide, 48 deep; the room inside 36 wide, 26 deep, walls 12 tall; entrance 8 wide and 9 tall with no door; back door 6 wide; VIP Room door 8 wide |

If phone playtests show the cat too small at the tub, the game scales the Model (`Model:ScaleTo`) and every joint and attachment follows; the files stay the same.

## 5. Budgets (triangles in the FBX, parts in the Part model)
| Asset | Triangles | Parts |
|---|---|---|
| Cat (any coat) | up to 1,500 (today 670 to 1,040) | up to 50 (today 34 to 50) |
| A dirty cat (cat plus mud, tangles, hidden fluff and claws) | up to 3,200 (today 2,700 to 3,110; raised from 3,000 for the claws, #23) | up to 155 (today 134 to 154; raised from 120 because a piece of the mud coat is up to four boxes where a blob was one, #107, #111 and #113, and from 150 for the one box of ragged edge a piece, #155) |
| Station or furniture | 300 to 1,500 (the tub 1,040 without its foam); later stations up to 1,200 (brush tables 440 and 1,152, dryer 968, bubble bath 676 without its foam, pawdicure 528). The two baths get up to 2,500 with lather and bubbles (tub 2,472, bubble bath 2,032): each ball of lather and each soap bubble is a Ball part that Roblox draws itself, so its triangles are only the preview mesh (#107, #111) | up to 75 for the two baths (the tub 71, the bubble bath 68: a soap bubble is two parts, the ball and its glint, #111), up to 60 for the rest (the upgraded table 40) |
| Small prop or tool | 50 to 400 (sponges 134 to 390; hard hat, hammer and toolbox 388 together; the #123 wash tools 156 to 392) | up to 20 (sponges 6 to 10; the #123 wash tools 5 to 12) |
| Brush, bow | up to 200 (brush 108, bows 164) | up to 10 |
| VIP Room locked or building (#21) | up to 2,000 | up to 80 |
| One spa plot, full | under 25,000 | about 250 instances |
| The whole street | under 150,000 | under 1,500 instances |

## 6. Naming
`CleanACat_<Category>_<Name>`, categories `Cat`, `NPC`, `Station`, `Tool`, `Prop`, `Bow`, `Mud`, `Area`, `Street`, `Decor` (checked by `gates.py`). A sitting cat ends `_Sit`. Object names inside an asset start with the asset name; the piece name follows (`_Head`, `_Tail`, `_Screen`).

## 7. Pivots and orientation
Pivot at the base centre on the floor. The front faces -Y in Blender, which is -Z in Roblox (the Model's LookVector). Cats: every hinged piece is its own object pivoted at its joint (Head at the neck, Tail at its root, legs at hip or shoulder, Eye1 and Eye2 at the eye centre, EarL and EarR at the ear base). In the Part model the eyes and ears are nested in the Head Model, so turning the Head carries them. The Head part holds two Attachments: `Carry` (over the middle at ear-tip height, for a name tag or a carried thing) and `BowSlot` (on the crown at the front edge, for a bow). Motion-FX animates these by name: tell it before renaming a piece or moving a pivot.

## 8. Materials
`SmoothPlastic` with the swatch colour. A bath's water (`_Water`) is solid `SmoothPlastic` in the `water` blue and running water (`_Stream`) is `SmoothPlastic` at 0.3 transparency. See-through panes are `SmoothPlastic` at 0.6. Roblox's `Glass` material is used nowhere: it bends the view behind it, changes its look between quality levels, and overlapping see-through water pieces showed a seam and a darker wedge from above in Studio (#176). Parts ending `_Glow` are `Neon`. No textures on models.

## 9. Export, import and checks
- `python3 assets/clean-a-cat/blender/build_all.py` builds everything (needs `bpy`, see that folder's README). It writes the FBX to `exports/`, the Part models to `rbx/`, `exports/manifest.json` and `exports/gates.md`, and exits 1 on any gate FAIL.
- **Part models are what the game uses.** Rojo syncs `assets/clean-a-cat/rbx/` into `ReplicatedStorage.Assets`, so code clones `Assets.CleanACat_Cat_Smudge_Sit` by name. No upload, so nothing waits on the group owning an asset id.
- The FBX copies stay as the detailed source if a MeshPart version is ever wanted (3D Importer, Scale Unit Studs, Anchored, saved as `<Name>.rbxm` in `rbx/` in place of the JSON).
- Every model: `gates.py` PASS and `rbx_zfight.py` 0 pairs. Since #160 `gates.py` also runs the `blender-asset-qa` skill's `qa_check.py` (roblox profile, `uv=False`: faces sit on swatch centres on purpose, so zero-area UVs are expected) on every asset inside `build_all.py`, and any error it gives fails the build: n-gons, flipped faces, open geometry, floating parts and two faces that look the same way within a millimetre of one plane. No error is accepted. The warnings we accept, each with its reason, are listed at the top of `exports/gates.md`. Before #160 the skill's check was a step to remember, and the 2026-11-24 batches went out without it; the sweep that followed found 59 of 100 assets with findings.
- What the sweep taught, so a new generator starts clean: `Builder.finalize` cuts n-gons into triangles and welds each box on its own (welding the whole mesh joined boxes that touch and flipped faces); two boxes never end in one plane, not even on a hidden underside or inside a wall, so stagger them by 2 mm or more; a piece that sits on the floor of another starts a hair inside it. Mud does this by itself (`dirt.py`: each box a step prouder than the last, cut sides a hair off the coat's grid, undersides stopped inside the block, then a settle pass that moves any side still in a taken plane).
- No model file holds a script. Reviewers grep `rbx/` for `Script`.

## 10. Previews
`build_all.py --render` renders a three-quarter preview of every asset to `docs/concepts/clean-a-cat/previews/` and the sheets (`sheet_cats.png` and others). Every picture shown to the owner or players shows scale with one of the game's own characters, and is checked at 150 px wide. Captions go in `docs/concepts/clean-a-cat/README.md`.

## 11. Dirty cats
`dirt.py` builds `CleanACat_Cat_<Name>_Dirty` (walking, in a carrier) and `CleanACat_Cat_<Name>_Dirty_Sit` (in the tub or the stray box) for every roster cat: the clean cat plus the 20 pieces of its mud coat (`_Mud01` to `_Mud20`, each a child Model of one to four boxes plus one of ragged edge, see the mud shape and ragged edge rules) and 6 tangles (`_Tangle01` to `_Tangle06`), each its own child Model. Blobs on the head, tail or a leg ride that piece's Model. Mud is `mud` (`mud_dust` on dark fur and `mud_drab` on pale fur, see the mud rule) with every third piece the wet shade, wrapped flush round the fur, never near an eye. The wet coat is a colour shift the game applies (root attribute `WetDarken` = 0.3), not extra parts. With every blob and tangle removed the model is the clean cat plus its hidden fluff.

**Fluffed look (#14).** Every dirty model also carries `_Fluff01` to `_Fluff10` (root attribute `FluffCount`): coat-coloured cloud puffs on the cheeks, crown, chest, flanks, back and tail, each its own child Model riding its piece. Each puff takes the swatch of the fur under it, so a white chest gets a white ruff. They ship see-through (Transparency 1, CanQuery off, no shadow); after the third brush swipe the game shows them (Transparency 0, CastShadow on) with a small pop. About 720 triangles and 20 parts.

## 12. Wash tub and sponges
`stations.py` builds `CleanACat_Station_Tub`: the claw-foot bath of the store picture, brought into the game by #157 after Derek said the first tub "could be a bit better and water a little higher up". A sky blue pill-shaped body (two round ends) that flares out, a gold band at the flare, a rolled white rim, four gold claw feet, four white bubbles painted on the front and two on the back (#172: with the spawn view a player may first see the tub from behind), a brass gooseneck tap with a pink and a sky knob on the back rim, left of centre so its stream shows past the cat, and a striped mint towel hung over the front rim. 4.6 wide, 3.5 deep and 1.83 to the rim; 91 Parts. Four child Models make it read as a bath (#111), none of which collide: `_Water` (deep blue `water` to 0.06 under the rim with white shine marks; solid in game since #176, and three pieces fill the pill, the middle block's top being the surface with the round ends 0.02 and 0.04 under it: overlapping tops stay at least 0.02 apart, Review-QA's rule, so they cannot flicker at street distance on a phone), `_Stream` (the water running from the tap, which the game can hide to turn the tap off), `_Foam` (low white mounds of lather round the right end with white balls on them, the front by the tap left as open water) and `_Bubbles` (clear soap bubbles with a white square glint: on the lather, one on the rim and three drifting above). Attachment `CatSeat` (root attribute `SeatHeight` 1.5; it was 1.2 before #157): put the sitting cat's pivot there, facing the player. The water stands 0.27 over the seat, which is `dirt.TUB_WATER` at the tub's 1.5 scale, so no mud piece sits under it. The solid body ends 0.12 over the seat: the cat's lowest part is inside it, under the water, where nothing shows. The body and the four paws collide; the rim, water, foam, towel and tap do not. The tub is smaller than the placeholder (6 by 5) so the cat fills more of a phone screen; at the tub the game shows the cat at `Model:ScaleTo(1.5)` and it still sits inside the rim. The old cream and mint tub is gone; the bubble bath stays the upgrade.

`tools.py` builds the three sponges: `CleanACat_Tool_Sponge` (butter yellow, mint scrub top), `CleanACat_Tool_SpongeBubble` (Bubble Soap: bigger, a foam cluster on top) and `CleanACat_Tool_SpongeGolden` (the Golden Sponge pass: gold). Each Part model's biggest part is `Handle`, so the game moves the parts into a Roblox Tool and welds them to it. Pivot at the grip centre. Nothing collides.

Pieces of one model never share a plane: neighbours are staggered by 0.012 studs so nothing flickers and the QA gate passes with no accepted findings.

## 13. Brush and bows (#14)
`tools.py` builds `CleanACat_Tool_Brush`: a light wood handle and a bubblegum back with three rows of foam and cream bristles. Pivot at the middle of the handle, the head pointing forward (-Z in Roblox), bristles down; the head is `Handle`.

`props.py` builds `CleanACat_Bow_Pink`, `CleanACat_Bow_Mint` and `CleanACat_Bow_Sky` (`bow_pink`, `bow_mint`, `bow_sky`): two puffed loops, a knot and two tails lying back over the crown. Pivot at the base of the knot, with an Attachment `BowSlot` there. To put one on, line the bow's `BowSlot` up with the cat Head's `BowSlot`, weld it to the Head, and `ScaleTo` it by the cat's `Scale` attribute.

### Draft tools for the other wash steps (#123)
Drafts, not wired into the game. Each follows the sponge's rules: one Model of Parts whose biggest part is `Handle`, pivot at the grip, front -Z in Roblox, nothing collides, about twice real size so it reads in a hand on a phone. Colour says what a tool is for at a glance: water tools are sky and white, drying is bubblegum, combing and clipping are mint, picking is pink. **No tool body is mostly grey (#132):** grey is only for metal tips (a jaw, a pin, a bead), because the spa floor and the grey coats eat it and a grey tool is a grey smudge at 32 px.
- `CleanACat_Tool_Shower` (rinse): a white grip with a sky collar and a hose stub, a sky head tipped forward and 25 degrees down, a white face plate with five water holes. Attachment `Nozzle` on the face plate, its +Y along the spray.
- `CleanACat_Tool_Comb` (pick out burrs): a mint handle and spine with five wide white teeth pointing down, the gaps as wide as a tooth.
- `CleanACat_Tool_Tweezers` (lift a burr or a leaf): two pink arms open wide toward the front with cream grip pads and a round metal bead on each tip, the part that picks.
- `CleanACat_Tool_Towel` (towel dry): a bubblegum towel folded in three with two cream stripes.
- `CleanACat_Tool_Clipper` (trim a claw): two mint blades open at the front, each ending in a metal jaw, a pale mint lever on a pin with a sky thumb pad.
- `CleanACat_Tool_Dryer` (blow dry): a bubblegum barrel, a cream nozzle, a darker pink grip with a cream switch. Attachment `Air` at the nozzle's mouth, its +Y along the air.
- `CleanACat_Tool_Shampoo` (lather): a lilac pump bottle, a cream label with a pink paw, a white pump with its spout to the front.

### Draft upgrade tiers for the brush and the shower (#142)
Upgrades follow the sponge's pattern: tier 2 is a step up in shape and colour that reads at phone size, tier 3 is tier 2 in gold. A tier keeps its tool's grip, `Handle` and attachments, so the game swaps the model without moving the hand. Drafts, not wired.

| Tool | Tier 1 | Tier 2 | Tier 3 |
|---|---|---|---|
| Sponge | `CleanACat_Tool_Sponge` | `CleanACat_Tool_SpongeBubble` | `CleanACat_Tool_SpongeGolden` |
| Brush | `CleanACat_Tool_Brush`: pink back, wood handle, three rows | `CleanACat_Tool_BrushFluffy`: a quarter bigger, lilac back, mint handle, six tall round tufts in white and pink that show past the edge of the back | `CleanACat_Tool_BrushGolden`: the fluffy brush in gold with a star on its back |
| Shower | `CleanACat_Tool_Shower`: sky head, five holes | `CleanACat_Tool_ShowerRain`: a wide rain head with a broad lilac rim, seven holes | `CleanACat_Tool_ShowerGolden`: the rain head in gold with a pale gold plate |

Every tier changes shape or size as well as colour (Review-QA, #142): a player who does not see the colour change must still see a different tool. No two tiers of one tool share a body colour, tier 2 is lilac and gold is kept for tier 3 of each tool and the reward props. The rain head was pale mint at first and nearly vanished on the mint HUD panel at 64 and 32 px, so look at a new tool's icon on mint before it ships.

## 14. Spa plot and the street (#15)
`plot.py` builds `CleanACat_Area_SpaPlot`. It began as a graybox and is now the real build on the same layout, so every spot, wall and opening is where the graybox had it. The front apron sits on the pavement; the room has an open front (an entrance with no door, and the display window with a window seat and four cushions behind 0.6 see-through glass); a back door leads to the stray box; an opening in the back wall is the VIP Room door, with the back yard behind it for the VIP Room build. No room, tub or space is made for avatars: only cats bathe.

Gameplay spots are Attachments in the floor slab, named `SpotTub`, `SpotSpawn`, `SpotQueue1` to `SpotQueue3`, `SpotStray`, `SpotWindow1` to `SpotWindow4` (each cushion's base), `SpotTipJar`, `SpotSign`, `SpotBuilder`, `SpotStation2`, `SpotStation3`, `SpotVipDoor` and `SpotBoard`. Each faces the way the player, customer, cat or station there faces. Root attribute `FloorHeight` (0.5, the top of the floor slab). The real build has these parts:
- A bubblegum shop front under a mint and white striped awning. The side and back walls are cream, with a bubblegum band outside and a mint band inside.
- A checked offwhite tile floor, with a round bubblegum rug under the tub.
- A mint roof with a cream parapet.
- Inside: three pendant lamps with warm bulbs (`_Glow`, Neon), a towel shelf, a clock, a paw poster and two plants.
- Over the back door: a cardboard strays sign.
- Outside: a flower box under the window, two potted plants at the entrance and two lamp posts on the apron.
- A grassy back yard with a low white fence, set 0.5 studs inside the plot edge so neighbours never overlap.

Floors, walls, the roof and the window seat collide. Decor (`_Decor`, `_Glow`, `_Flowers`, `_Trim`, `_Bands`, `_Tiles`) does not. The plot is 3,540 triangles and 161 parts.

`street.py` builds `CleanACat_Area_Street`, which holds everything round the six plots:
- Grass ground and a pavement in front of the plots, level with their floor (0.5).
- Cream curbs and a two lane road with white dashes.
- A far pavement, with pastel town houses across the road as a backdrop.
- A hedge and round trees behind the plots, and hedges at both ends.
- An invisible solid `_Barrier` round the edge, with CanQuery off.

Its pivot is slot 1's plot pivot, so it goes at `SpaLayout.PIVOT_POSITION`. Attachments `PlotSlot1` to `PlotSlot6` mark each plot's pivot in `SpaLayout.slotPivot` order, 44 studs apart. The root attributes are `PlotSpacing` 44 and `PlotCount` 6. The game places the plots; they are not built into the street. The street is 2,624 triangles and 105 parts.

## 15. Customers and spa props (#16)
`spa_props.py` builds:
- `CleanACat_Prop_Carrier`: bubblegum tray, cream shell with mint vents and handle, and a metal grille door (`..._Door_Swing`, a child Model pivoted at its hinge on the cat's left; turn it up to `DoorOpenDegrees`, 110). `CatSeat` on the tray for a walking cat at `ScaleTo(CatScale)` (0.8) so it shows through the grille; `Grip` at the handle.
- `CleanACat_Prop_StrayBox`: cardboard box with its flaps folded out and a bubblegum blanket; `CatSeat` on the blanket.
- `CleanACat_Prop_ChanceBoard`: a standing bubblegum board on two wooden legs; its face part is `Screen` (front, -Z) for the chances SurfaceGui. Tagged `ChanceBoard`, streams in whole. It stands at the plot's `SpotBoard`.
- `CleanACat_Prop_QueueMat`: a welcome mat with two paw prints, one at each `SpotQueue`.

`customers.py` builds three accessories for Roblox's own R15 customer rig: `CleanACat_NPC_SunHat` (`HatAttachment`), `CleanACat_NPC_Scarf` (`NeckAttachment`) and `CleanACat_NPC_ToteBag` (`LeftShoulderAttachment`). Each Model's biggest part is `Handle` and holds that Attachment; move the parts into an Accessory, weld them to Handle and `Humanoid:AddAccessory` it. The customer itself is `Players:CreateHumanoidModelFromDescription` with body colours only, so nothing waits on an upload:

| Customer | Head and arms | Torso | Legs | Accessory |
|---|---|---|---|---|
| Sunny | skin_light #F3C9A2 | spa_mint #A8E6CF | pants_navy #2F3E5C | SunHat |
| Mo | skin_deep #7A4B32 | pastel_butter #F6DFA0 | shirt_blue #3C7DD9 | Scarf |
| Pip | skin_tan #C98E6A | spa_sky #8FD3FE | wood_light #E3C49C | ToteBag |
| Rae | skin_tan #C98E6A | spa_bubblegum #FFB3C7 | pants_navy #2F3E5C | SunHat |

## 16. Display window (#17)
`spa_props.py` builds the window set (four cushions, the jar and the sign: 1,236 triangles, under the 1,500 budget):
- `CleanACat_Prop_Cushion`: a round bubblegum cushion with a puffed top, a cream button and four tassels. Pivot on its base at each `SpotWindow`; `CatSeat` on top. Window cats sit at `ScaleTo(CatScale)` (root attribute, 1.3) so they read from the street and the next plot.
- `CleanACat_Prop_TipJar`: a square glass jar (`..._Glass`, 0.6 see-through) on a mint base with a lid, a gold coin `Fill` part and a cream `Screen` label at the front for the count. To fill it, keep Fill's bottom at the root attribute `FillBottom` and set its height from 0 to `FillHeight` (hide it when empty). At `SpotTipJar`.
- `CleanACat_Prop_WindowSign`: a mint-framed sign with a cream `Screen` face for the spa's name, flat on the front wall at `SpotSign`, facing the street.

The plot draws a mint frame round the window and the entrance (`_Trim`, no collision).

## 17. Stations and the build pad (#18)
`stations.py` builds the next two stations. Each fits the plot's 5 by 5 stud station pad (`SpotStation2`, `SpotStation3`), faces the player at -Z in Roblox like the tub, and seats the cat at `ScaleTo(CatScale)` (root attribute, 1.5, as at the tub) on its `CatSeat` attachment. Their legs and boards are too thin to collide, so each has an invisible solid `_Barrier` box under its top that keeps players out. It stays under the cat and has CanQuery off, so taps, clicks and the camera pass through it.
- `CleanACat_Station_BrushTable`: the grooming table. Since #193 it stands on a solid cabinet, not four thin legs, so it reads at phone size beside the baths: a wooden foot, a cream body that flares out over it with a brass band at the flare, a mint drawer with a brass knob and a sky towel on a brass bar at the front. The wooden top carries a mint rubber mat, a shampoo bottle at the back left corner and a brass post at the back right corner with one brush hanging from its arm, which says what the table is for. `CatSeat` on the mat at 1.8 studs (`SeatHeight`), hip high on an avatar.
- `CleanACat_Station_BrushTableUp`: the upgrade, same footprint, pivot and `CatSeat`, so the game swaps one for the other in place. The same cabinet in bubblegum on a cream foot with a gold band and gold knob, a cream top with a gold edge and a puffy bubblegum cushion, two towels on a gold bar, and a mint brush rack at the back with three brushes on a gold rail and a pink bow on the header. The upgrade changes shape (the rack more than doubles its height) as well as colour.
- `CleanACat_Station_Dryer`: a hood dryer. Since #193 the cat sits on a butter pouf with a gold band and a bubblegum cushion (`CatSeat` at 1.2), and the pouf and the pole stand on one cream plinth. The pole is cream with brass collars and a mint control box with two dials; an arm holds the hood over the cat: a cream dome with a butter rim, sky vents and a brass knuckle on top. Under the hood hangs a part named `Nozzle` with an Attachment `Air` whose +Y points straight down at the cat: a ParticleEmitter in `Air` with EmissionDirection Top blows onto the cat. The hood's rim is at 4.45 studs, about 0.4 over a 1.5 scale cat's ears.
- The station family (#193): every station has a solid body, one metal trim (brass on a first station, gold on an upgrade or a later station), one detail that says what it is for (the tub's tap, the brush on its post, the dryer's hood, the pawdicure's lamp and bottles) and its own colour (tub sky, brush table cream and mint, dryer butter, bubble bath bubblegum, pawdicure lilac).

`spa_props.py` builds `CleanACat_Prop_BuildPad`, shown where a locked station will go: a cream 4.8 stud square inside a dashed bubblegum and butter tape border, two bubblegum cones at the front corners, a stack of planks and a mint sign at the back whose cream face is a `Screen` part for the station's name and price. Walk-through; remove it when the station is built.

## 18. Builder kitten (#20)
`build_props.py` builds the kitten that hammers at a locked station while the build countdown runs:
- `CleanACat_NPC_BuilderKitten`: the standing cat body with arms from `cats.py`, about 1.8 studs tall, in a hazel coat with an oat chest and socks. No index cat has that coat, so it never reads as collectible. It has the same child Models as every cat (Head with eyes and ears, Tail, the arms LegF1 and LegF2 pivoted at the shoulders, LegB1, LegB2). It has an Attachment `HatSlot` on top of the head, an Attachment `HammerGrip` in its right paw (LegF2), and the root attributes `Scale` 1 and `Role` Builder.
- `CleanACat_Prop_HardHat`: a butter hard hat with a ridge, a front peak and a mint sticker. Line its `HatSlot` up with the kitten's and weld it to the Head part.
- `CleanACat_Prop_Hammer`: pivot and Attachment `Grip` at the grip. Line `Grip` up with the kitten's `HammerGrip`. The handle points to the front (-Z) and the striking face down, so turning the hammer about its pivot's X axis lifts the head and brings it down.
- `CleanACat_Prop_Toolbox`: a sky toolbox with a handle and a wrench on the lid. Its Attachment `CountdownAnchor`, 2.4 studs up, holds the build countdown BillboardGui.

The hat, hammer and toolbox together are 388 triangles (the budget is 400). None of them collides.

## 19. VIP Room before it is built (#21)
`vip.py` builds the VIP Room's two looks before the room exists, both at the plot's `SpotVipDoor` (pivot at the middle of the door opening on the floor, front -Z into the spa, the back yard behind):
- `CleanACat_Area_VipLocked`: a closed bubblegum double door fills the 8 by 9 stud opening and blocks it. It has cream panels, round sky windows, gold handles, a butter frame and a crown above. A mint sign on the door has a cream `Screen` part for the room's name and the timer. Behind the wall a sky tarp with white straps covers scaffold poles. Its roof peaks at about 15.7 studs, so the room's size shows over the 12 stud wall from inside the spa.
- `CleanACat_Area_VipBuilding`: the same door, sign and scaffold while the 8 hour build runs. The tarp stays on the back and the right side only, and the builder kitten's work shows: a wooden frame rising over the wall, bubblegum lower walls half up, rafters and planks.

Both are under 2,000 triangles. An invisible solid `_Barrier` with CanQuery off keeps players out of the site. The finished room is a later issue.

## 20. Coat table and the Cat Index (#22)
`coat_table.py` writes `assets/clean-a-cat/rbx/CleanACat_CoatTable.json` on every full build. Rojo turns it into a ModuleScript, `ReplicatedStorage.Assets.CleanACat_CoatTable`, that returns the table, so the server sends only a coat id (the cat's name). It holds:
- `Order`: the Cat Index order, Commons first.
- `RarityColors`: the badge and frame colour of each rarity.
- `MudColors`: the six mud colours (`Mud`, `MudWet`, `MudDust`, `MudDustWet`, `MudDrab`, `MudDrabWet`).
- `Coats[name]`: for each cat, `Rarity`, `IndexOrder`, `Pattern`, `Extras` (ear tufts, ruff, fluffy, sparkle, tuxedo), `Colors` (fur, second, eyes, nose and the rest, as hex) and `Models` (the Walk, Sit, Dirty and DirtySit model names).

Every pattern part sits proud of the body, and nothing is a texture. Extras cost at most 276 triangles (Lilac Cloud's fluffy coat while sitting), under the 300 each that the issue allows. The index sheet shows each cat clean on its rarity tile with its dirty look behind. Each column is about 160 px wide, an index card's size on a phone.

## 21. Bubble bath, pawdicure and long claws (#23)
`stations.py` builds two later stations on the same 5 by 5 stud pad, facing -Z, with the cat at `ScaleTo(CatScale)` 1.5 on its `CatSeat` and an invisible `_Barrier` (CanQuery off) as at the #18 stations:
- `CleanACat_Station_BubbleBath`: the wash tub's upgrade, reworked by #172 so it reads as the better bath beside the claw-foot tub (an upgrade changes shape and size, not only colour). A round bubblegum slipper bath: the wall and its cream rolled rim sweep up from the front rim (1.83, as the tub) to a back 1.3 higher behind the cat. It stands on a cream plinth 4.6 across with a gold step, has a gold band at the flare and a white paw print painted on the front and on the back. A gold bubble fountain stands on the back wall to the right of the cat (not behind its head) and arches in; its mint mouth is the part `Spout`, with an Attachment `Bubbles` whose +Y points up: a ParticleEmitter there sends bubbles rising. A rubber duck sits on the rim. Deep blue water stands 0.06 under the front rim with white shine marks. The lather is heaped higher than the tub's: seven low mounds round the cat with white balls on them, a tidy pile at each side of the cat, and at the front left it spills over the rim and down the side to a puddle on the plinth. Clear soap bubbles sit on the lather and the rim and drift up from the fountain (#111). `CatSeat` at 1.5 (`SeatHeight` 1.5; it was 1.32 before #172), the same as the tub, so one camera and one reach serve both baths. The water, the lather and the soap bubbles are child Models (`CleanACat_Station_BubbleBath_Water`, `_Foam` and `_Bubbles`) that do not collide, so the game can tint, hide or move them. 4.6 across, 5.2 tall to the top of the fountain; 113 Parts (68 before), 51 of them the lather and the soap bubbles. The body and the six tall blocks of the slipper back collide, and the `_Barrier` fills the middle; the plinth, the low front rim, the water, the lather and the fountain do not.
- `CleanACat_Station_Pawdicure`: since #193 a lilac cabinet on a cream foot with a gold band and a white paw print painted on the front. The cream top carries a bubblegum cushion and a mint paw rest at the front (`CatSeat` on the cushion at 1.6), a gold tray with three polish bottles and a nail file at the cat's left, and a brass lamp with a butter shade at the back corner, shining down on the paws.

**Long claws.** Every dirty cat (walk and sit) now carries `_Claw01` to `_Claw08`, four pearl claws on each front paw, each its own child Model riding LegF1 or LegF2 (root attribute `ClawCount` 8). They ship hidden like the fluff (Transparency 1, CanQuery off). A cat that comes in with long claws shows them; the pawdicure removes them.

## 21b. Reward props (#125)
`rewards.py` builds what a wash pays, for the world and as the source of the recap card's icons. Drafts, not wired. Nothing collides.
- `CleanACat_Prop_Coin`: a chunky gold coin standing on edge, 1 stud across, a paw print (a pad and four toes) on both faces. Pivot at its middle so the game can spin it and pop it out of a customer. The golds are the palette's metal swatches, so it shines in Roblox.
- `CleanACat_Prop_Star`: a fat five point star standing up, 1.1 studs across, a paler star set into its front face. Pivot at its middle. It is flat `rarity_legend`, the UI's gold, so a star in the world and a star on a card are one colour. 20 parts (a star is ten wedges), so spawn few at once: a burst of many stars is a particle picture, not this model.
- `CleanACat_Prop_CoinStack`: stacks of five, three and two coins. Pivot at the base centre. For the recap card and a full tip jar.

## 21c. Things stuck in the fur (#126)
`burrs.py` builds what a player picks out of a coat with the tweezers or the comb. Drafts: no dirty cat carries them yet and the scrub contract is untouched. Nothing collides.
- `CleanACat_Prop_Burr`: a round seed head 0.4 studs across, a dark green core with pale moss spikes on every side. Dark where the leaf is bright, so the two stay apart at 32 px.
- `CleanACat_Prop_Leaf`: a small leaf lying flat, 0.7 studs long: a tapered blade, a darker rib and a short stalk.
- `CleanACat_Prop_Twig`: a forked brown twig 0.9 studs long with a small leaf at the end of each arm.

All three are green or wear green, the one colour family no coat and no mud uses, so on any cat they read as a plant thing that does not belong. Each is drawn for a scale 1 cat: `ScaleTo` it by the cat's `Scale` and the station's `CatScale`. The pivot is the middle of the underside with Roblox +Y out of the fur, so the game sets the pivot on the fur and turns its up along the surface. Placement follows the mud rule: nothing over the eyes or the face drawing. A leaf goes on a cheek, a shoulder or the back, a twig sticks up out of the head or the back, a burr sits anywhere in the fur. Three to five on a cat is plenty: at phone size a burr is about 8 px, so the pick step should also mark each one (a ring or a bounce) while the tweezers are out.

## 21d. A busy spa (#124)
`busy_spa.py` builds the pieces a spa with a queue, a helper and a rare visitor needs. Drafts, nothing wired.
- `CleanACat_Station_WaitBench`: where waiting cats sit in their carriers, three side by side, so a player sees who is waiting and picks who is next. 7.2 studs wide, 3 deep, the top 1.3 up: a cream top on mint legs (too slim to collide, so an invisible `_Barrier` sits under the top as at the other stations), a mat for each carrier in its own pastel (pink, butter, sky), a white plate under each mat with one, two or three pink dots, and towels and a basket on the shelf below. Attachments `Spot1` to `Spot3` on the mats (set a carrier's pivot there) and `Tag1` to `Tag3` 3.3 studs above the top for a bubble. Attribute `Spots` 3. The carrier's door is barred, so the cat's face goes in the bubble on its `Tag`: a waiting cat is told apart by its portrait, not through the bars.
- `CleanACat_Station_FrontDesk`: where a customer checks in. 5 studs wide, 2.3 deep, the top 2.6 up: a cream body on a mint toe kick, a bubblegum front with the spa's cream paw (a pad and four toes, like the coin), a mint top, a gold bell (Attachment `Bell` above it), an appointment book with a pencil, and a standing card whose face is the child Model `CleanACat_Station_FrontDesk_Screen` for a SurfaceGui. Attachment `TipJarSpot` on the top for `CleanACat_Prop_TipJar`.
- `CleanACat_NPC_Helper`, `CleanACat_NPC_Helper2`, `CleanACat_NPC_Helper3`: three hired helpers, one body in three looks, so three helper spots show three different helpers that share one motion. Each is the standing kitten body of the builder kitten in a smock that wraps its whole chest, with a cream hem and pocket. No customer's cat wears a smock: a kitten with only a small apron read as a customer's cat that got loose (Review-QA). Attachments `HatSlot` on the head and `ToolGrip` in its right paw (a sponge's or a brush's `Handle` goes there). Attributes `Role` Helper, `Look` 1 to 3 and `Cap`, the name of its cap.

| Model | Coat | Smock | Cap |
|---|---|---|---|
| `CleanACat_NPC_Helper` | peach, vanilla muzzle and paws, mint eyes | mint | `CleanACat_Prop_HelperCap`, bubblegum with a mint paw |
| `CleanACat_NPC_Helper2` | ink, white muzzle and paws, sky eyes | bubblegum | `CleanACat_Prop_HelperCap2`, mint with a bubblegum paw |
| `CleanACat_NPC_Helper3` | custard, white muzzle, latte paws, violet eyes | sky | `CleanACat_Prop_HelperCap3`, butter with a sky paw |

- The caps are bath caps: a puffy cap with a cream frill, an ear shape over each ear (the cap covers the ears, so without them the helper stops reading as a cat) and a paw on the front. A cap's pivot goes on `HatSlot`, like the hard hat. Coat, smock and cap all differ between looks because those three are what still reads at phone size.
- `CleanACat_NPC_StarBeret` and `CleanACat_NPC_StarShades`: what the rare visitor wears, a lilac beret with a gold star pin (R15 `HatAttachment`) and gold rimmed violet shades (`FaceFrontAttachment`). The visitor is a customer like the others (Roblox's own R15 rig with body colours); `busy_spa.VISITORS` has the look: Vivi, skin `#C98E6A`, a lilac top `#9479BE` and pearl trousers `#F4EEF6`, wearing both. An original character: no real person, brand or other game's character.
- `CleanACat_Prop_StarPhoto`: the keepsake the rare visitor leaves, a permanent reward a player sees in their spa. A gold framed photo 1.7 studs wide and 2.1 tall for a wall, a cream mat with a lilac paw print and signature line, and a lilac rosette with a gold star on the top corner. The picture is the child Model `CleanACat_Prop_StarPhoto_Screen` (part `Screen`) for a SurfaceGui or a Decal, pale lilac until the game sets it. Pivot at the middle of its back, which goes on the wall. Does not collide.

The bench and the desk are named `Station` so they collide like the other furniture a player walks round. The helper is the builder kitten's size (1.9 studs), far smaller than a player, so it stands at a station and is hidden behind the desk: do not put it there.

## 21e. Pictures of the models for the screens (#127)
Portraits and icons are rendered from the real models, never drawn apart from them, so a screen and the world always show the same thing.
- `ui_renders.py <raw folder> [--only word,word]` (Blender's Python) renders each picture on a see-through background with a camera that has no perspective: `portrait_<Cat>.png` and `portrait_<Cat>_Dirty.png` for every roster cat (sitting, head and shoulders), `portrait_Helper.png`, `icon_<Model without CleanACat_>.png` for each model in its `ICONS` table, and `icon_Customer_<Name>.png` and `icon_Visitor_<Name>.png` on the stand-in block figure with a plain face.
- `ui_compose.py <raw folder> <out folder> [sheet.png]` (plain Python with Pillow) writes each final twice: alone, and `_ink` with an outline in the UI's ink `#3B2D45`, 3% of the picture wide. Icons are 256 px, trimmed and centred with an 8% margin. Portraits are 512 px and keep their framing: the chest runs off the bottom edge for a round frame, and that edge has no outline.
- One camera rule for the icons (from the front right, a little above) with a per model angle only where that view hides what the thing is. A station's invisible `_Barrier` is never drawn. The per model angles so far: the coin stack from the left (from the right its top glints like a flame at 64 px), the dryer from the side so hood, pole and stool sit side by side, and the bench from above so its three mats show.
- A new model gets its icon by adding one line to `ICONS`. An icon is done when it reads on the sheet's 32 px row. The stations are the exception: `icon_Station_Tub` and `icon_Station_BubbleBath` are a blob at 32 px and the other station icons are little better, so no `icon_Station_*` is used below 48 px (Review-QA, #157, #172 and #193). White cats and white bristles vanish on cream without the ink version. The comb and the brush both have white teeth, so their buttons need different backing colours.
- Nothing is uploaded by these scripts. The ui-designer picks what goes into `assets/clean-a-cat/ui/` and uploads are group owned.

## 21f. HUD button pictures (#185)
Six pictures for the HUD's buttons, drawn apart from the game models because a button names an idea (settings, build mode), not a thing in the world. The owner compared two blends on 2026-11-24 and picked this one "for now": our look mixed with his library's HUD icons.
- `hud_icons.py <out folder> [--only Index,Tools]` (Blender's Python) writes five of them as `CleanACat_Icon_Hud_<Name>.png`: 512 px, see-through, with a 13 px outline in `#45226B`, the ink the ui-designer asked for on these (the `_ink` model icons above use `#3B2D45`; one of the two has to win before any upload). The camera, the two lights and the outline pass are ported from the library's `icons.py`; the colours are ours.
- One bold object per picture that can be named at 48 px, built fat with rounded edges, tilted a little and filling the square about as much as the gear does. No small parts.
- `Coins` is not rendered. The owner chose his library's own coin picture as it is (`CatCafe_Icon_Coins.png`: a gold stack with a $ and a brown outline) over the paw coin first drafted here, so `CleanACat_Icon_Hud_Coins.png` is a copy of that file and the generator has no coin.
- `Settings`: a gear with eight teeth in soft blue grey. `Index`: a purple book with a cream cat's face on the cover and a pink bookmark. `Tools`: the game's pink scrub brush made fat, with soap bubbles (Review-QA: the bubbles get busy at 48 px, the first thing to thin if it is reworked). `Helper`: the first helper kitten's real head in its bath cap. `Build`: a blue hammer with a wooden handle and a white paw.
- `Helper` is the one picture made from a game model, and its cap is one step deeper pink (`nose_bubblegum`) than the model's so cap and face part at 48 px. The model's cap is unchanged.
- Nothing is uploaded by this script. The ui-designer keeps the six in `assets/clean-a-cat/ui/` and uploads are group owned.

## 22. Rules
- Original IP only: no Cat Cafe character, name or coat is reused, and nothing from other games.
- Pictures promise only what the first minutes show.
- Models are solid from every side a player can reach.
- Rooms are roomy: 6 stud gaps at least.
