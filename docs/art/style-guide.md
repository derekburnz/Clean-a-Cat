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

Also in row 16: `mud_wet` #735A43 (the lighter wet edge of a blob), `foam` #FDFEFF, `spa_tile` #EEF4F6.

### Coats (rows 17 and 18) and details (row 19)
Each Cat Index cat has its own coat swatches (`coat_*`) so no coat repeats a Cat Cafe coat. Eyes (`eye_mint`, `eye_sky`, `eye_gold`), nose (`nose_bubblegum`), bows (`bow_pink`, `bow_mint`, `bow_sky`) and `wood_light` are in row 19. Rarity colours for frames and badges are the studio's row 2 (`rarity_common`, `rarity_rare`, `rarity_epic`, `rarity_legend`).

**Mud rule:** every coat must stay readable against `mud`. Inky (black) is the one dark coat; its mud uses `mud_wet` edges and the blobs sit proud of the coat so the shape still reads.

## 3. Shape language

Blocks with small chamfers in the FBX (the Part models drop bevels). Big heads, short legs, chunky props. Nothing thinner than 0.1 studs that a player is meant to see. Rounded things (tub, cushions, bubbles) use balls and cylinders.

## 4. Scale

A Roblox R15 avatar is about 5 studs tall. A door is 7 studs, a counter 3.

| Thing | Size (studs) |
|---|---|
| Cat, walking | about 1 wide, 2 long, 1.9 tall |
| Cat, sitting | about 1.25 wide, 1.25 deep, 1.85 tall |
| Tub (planned) | about 4 across, 2.5 tall, so the whole cat shows from the player's spot |
| Room gaps | 6 studs or wider everywhere a player or camera goes |

If phone playtests show the cat too small at the tub, the game scales the Model (`Model:ScaleTo`) and every joint and attachment follows; the files stay the same.

## 5. Budgets (triangles in the FBX, parts in the Part model)
| Asset | Triangles | Parts |
|---|---|---|
| Cat (any coat) | up to 1,500 (today 670 to 1,040) | up to 50 (today 34 to 50) |
| A dirty cat (cat plus mud, tangles) | up to 2,500 | up to 85 |
| Station or furniture | 300 to 1,200 | up to 60 |
| Small prop or tool | 50 to 400 | up to 20 |
| One spa plot, full | under 25,000 | about 250 instances |
| The whole street | under 150,000 | under 1,500 instances |

## 6. Naming
`CleanACat_<Category>_<Name>`, categories `Cat`, `NPC`, `Station`, `Tool`, `Prop`, `Bow`, `Mud`, `Area`, `Street`, `Decor` (checked by `gates.py`). A sitting cat ends `_Sit`. Object names inside an asset start with the asset name; the piece name follows (`_Head`, `_Tail`, `_Screen`).

## 7. Pivots and orientation
Pivot at the base centre on the floor. The front faces -Y in Blender, which is -Z in Roblox (the Model's LookVector). Cats: every hinged piece is its own object pivoted at its joint (Head at the neck, Tail at its root, legs at hip or shoulder, Eye1 and Eye2 at the eye centre, EarL and EarR at the ear base). In the Part model the eyes and ears are nested in the Head Model, so turning the Head carries them. Motion-FX animates these by name: tell it before renaming a piece or moving a pivot.

## 8. Materials
`SmoothPlastic` with the swatch colour. Water is `Glass` at 0.3 transparency, see-through panes `SmoothPlastic` at 0.6 (Roblox's Glass bends the view behind it). Parts ending `_Glow` are `Neon`. No textures on models.

## 9. Export, import and checks
- `python3 assets/clean-a-cat/blender/build_all.py` builds everything (needs `bpy`, see that folder's README). It writes the FBX to `exports/`, the Part models to `rbx/`, `exports/manifest.json` and `exports/gates.md`, and exits 1 on any gate FAIL.
- **Part models are what the game uses.** Rojo syncs `assets/clean-a-cat/rbx/` into `ReplicatedStorage.Assets`, so code clones `Assets.CleanACat_Cat_Smudge_Sit` by name. No upload, so nothing waits on the group owning an asset id.
- The FBX copies stay as the detailed source if a MeshPart version is ever wanted (3D Importer, Scale Unit Studs, Anchored, saved as `<Name>.rbxm` in `rbx/` in place of the JSON).
- Every model: `gates.py` PASS, `rbx_zfight.py` 0 pairs, and the `blender-asset-qa` roblox profile with `uv=False` (faces sit on swatch centres on purpose, so zero-area UVs are expected). Known accepted finding: one hidden coplanar triangle where each eye meets the chamfered head in the FBX; the Part models have no bevels and report 0.
- No model file holds a script. Reviewers grep `rbx/` for `Script`.

## 10. Previews
`build_all.py --render` renders a three-quarter preview of every asset to `docs/concepts/clean-a-cat/previews/` and the sheets (`sheet_cats.png` and others). Every picture shown to the owner or players shows scale with one of the game's own characters, and is checked at 150 px wide. Captions go in `docs/concepts/clean-a-cat/README.md`.

## 11. Rules
- Original IP only: no Cat Cafe character, name or coat is reused, and nothing from other games.
- Pictures promise only what the first minutes show.
- Models are solid from every side a player can reach.
- Rooms are roomy: 6 stud gaps at least.
