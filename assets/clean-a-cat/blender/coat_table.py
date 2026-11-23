"""The coat table (issue #22): one file the game reads, so the server sends only a coat id (the cat's name).

build_all.py writes it to assets/clean-a-cat/rbx/CleanACat_CoatTable.json. Rojo turns a .json file into a
ModuleScript that returns the table, so the game requires ReplicatedStorage.Assets.CleanACat_CoatTable. For each cat:
its rarity, its place in the Cat Index, its pattern and extras, its colours as hex (fur, second, eyes, nose and the
rest of cats.COAT_FIELDS that it uses), the mud colours its dirty models use, and the names of its four models in
ReplicatedStorage.Assets. RarityColors are the badge and frame colours for each rarity.
"""

import json
import os

import cats
import palette

RARITIES = ("Common", "Uncommon", "Rare", "Epic", "Legendary")
RARITY_SWATCH = {"Common": "rarity_common", "Uncommon": "rarity_uncommon", "Rare": "rarity_rare",
                 "Epic": "rarity_epic", "Legendary": "rarity_legend"}
EXTRAS = ("ear_tufts", "ruff", "fluffy", "sparkle", "tuxedo")


def table():
    hexes = dict(palette.SWATCHES)
    coats = {}
    order = sorted(cats.ROSTER, key=lambda n: (RARITIES.index(cats.ROSTER[n]["rarity"]), list(cats.ROSTER).index(n)))
    for i, name in enumerate(order, start=1):
        spec = cats.ROSTER[name]
        base = f"CleanACat_Cat_{name}"
        coats[name] = {
            "Rarity": spec["rarity"],
            "IndexOrder": i,
            "Pattern": spec["pattern"],
            "Extras": [e for e in EXTRAS if spec.get(e)],
            "Colors": {field: hexes[sw] for field, sw in cats.coat(spec).items()},
            "Models": {"Walk": base, "Sit": base + "_Sit", "Dirty": base + "_Dirty", "DirtySit": base + "_Dirty_Sit"},
        }
    return {"Version": 1, "Order": order,
            "RarityColors": {r: hexes[RARITY_SWATCH[r]] for r in RARITIES},
            "MudColors": {"Mud": hexes["mud"], "MudWet": hexes["mud_wet"], "MudDust": hexes["mud_dust"],
                          "MudDustWet": hexes["mud_dust_wet"]},
            "Coats": coats}


def write(rbx_dir):
    path = os.path.join(rbx_dir, "CleanACat_CoatTable.json")
    with open(path, "w") as f:
        json.dump(table(), f, indent=1, sort_keys=False)
        f.write("\n")
    return path
