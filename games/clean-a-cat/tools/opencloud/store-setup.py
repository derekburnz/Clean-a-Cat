#!/usr/bin/env python3
"""Makes the game's passes and developer products, sets the server size and puts the store art on the game page,
with the keys already saved as GitHub secrets (Derek, 2026-11-26 plan page: "You can do gamepasses I have seen it
done with keys", the same for dev products, "6 is fine" for server size, and on the store art "You should be able to
do this with keys"). Issues 850 and 851.

A pass cannot be deleted once made, so every making action first lists what the experience already has and skips
any name that is there, and nothing is made unless CONFIRM is "yes"; without it the run only prints the plan.
No key is ever printed.

  KEY_GROUP, KEY_OWNER   the keys (the group key is tried first; either may be empty)
  UNIVERSE_ID, PLACE_ID  the experience and its start place (not secret)
  TARGET                 dev or live (live only on the owner's own word, as publishes and switches)
  ACTION                 list | passes | products | icons | server-size | store-art
  CONFIRM                "yes" to make or change anything
  ART_DIR                store-art: the folder with icon-main-512.png and thumbnail-order-1..4-*.png
  GROUP_ID               store-art: the group that owns the uploaded images
  ONLY                   icons: comma list of ICONS keys, 1 to ICONS_PER_RUN with CONFIRM yes (empty plan: all)

Open Cloud endpoints (create.roblox.com/docs/cloud/reference/features/game-passes, developer-products, and the
guide cloud/guides/experience-icons-and-thumbnails, read 2026-11-26): passes and products are Beta.
"""
import glob
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

API = "https://apis.roblox.com"

# Our keys (Passes.KEYS and Products.IDS_BY_GAME) with the name, price and words shown on Roblox, and for a pass whose
# name changed, the old names it may still have there: that pass is renamed, never made again (a copy cannot be deleted).
# The price is the REGULAR one, the same list as SaleRules.REGULAR_PASSES and REGULAR_PRODUCTS in the game (change both
# together); sale-prices sets half of it (SaleRules.salePrice), regular-prices sets it back (issue 1032).
PASSES = [
    # Derek 2026-11-27 (issue 1031): a cheap ladder, 2x then 3x, 25 and 50 Robux on the launch sale
    ("DoubleCoins", "2x Coins", 50, "Every cat you wash by hand pays double."),
    ("TripleCoins", "3x Coins", 100, "Every cat you wash by hand pays triple, in place of double."),
    ("SecondBuilder", "Second Builder", 299, "Build a tub or station and a room at the same time."),
    ("GoldenSponge", "Golden Sponge", 99, "The best sponge with gold bubbles, and +20% on every cat you wash by hand."),
    # Derek 2026-11-27: the pass is "Extra Worker", not the helper's name; the dev pass made as "Lou" is renamed
    ("Lou", "Extra Worker", 249, "A third helper, with his own wash stand.", ("Lou",)),
    ("SecondPetSlot", "Second pet slot", 249, "A second pet for you and every helper."),
]
PRODUCTS = [
    ("FinishTier1", "Finish now (5 minutes)", 5, "Finishes a build with 5 minutes or less left."),
    ("FinishTier2", "Finish now (30 minutes)", 15, "Finishes a build with 30 minutes or less left."),
    ("FinishTier3", "Finish now (2 hours)", 35, "Finishes a build with 2 hours or less left."),
    ("FinishTier4", "Finish now (8 hours)", 75, "Finishes a build with 8 hours or less left."),
    ("FinishTier5", "Finish now (over 8 hours)", 99, "Finishes a build with more than 8 hours left."),
    ("CrateOne", "Crate", 49, "One crate with a random pet. The odds are shown in the game before you buy."),
    ("CrateFive", "5 Crates", 199, "Five crates with a random pet each. The odds are shown in the game before you buy."),
    # the words are set only when the product is made; with starterBuilder and starterPet on (issue 1097, 1090)
    ("StarterPack", "Spa Starter Pack", 199, "Midas the golden pet, Second pet slot, 2x Coins and Second Builder."),
]
# The picture Roblox shows in the buy prompt for each pass and product (issue 1122, Model-Agent's PR 1126): 512 px PNGs
# in ICON_DIR, set by the icons action after main's upload approval list has them (approved()).
ICON_DIR = "assets/clean-a-cat/ui/icons/shop"
ICONS = {
    "DoubleCoins": "CleanACat_UI_Shop_Coins2x.png",
    "TripleCoins": "CleanACat_UI_Shop_Coins3x.png",
    "SecondBuilder": "CleanACat_UI_Shop_Builder2.png",
    "GoldenSponge": "CleanACat_UI_Shop_GoldenSponge.png",
    "Lou": "CleanACat_UI_Shop_ExtraWorker.png",
    "SecondPetSlot": "CleanACat_UI_Shop_PetSlot2.png",
    "FinishTier1": "CleanACat_UI_Shop_Finish1.png",
    "FinishTier2": "CleanACat_UI_Shop_Finish2.png",
    "FinishTier3": "CleanACat_UI_Shop_Finish3.png",
    "FinishTier4": "CleanACat_UI_Shop_Finish4.png",
    "FinishTier5": "CleanACat_UI_Shop_Finish5.png",
    "CrateOne": "CleanACat_UI_Shop_Crate1.png",
    "CrateFive": "CleanACat_UI_Shop_Crate5.png",
    "StarterPack": "CleanACat_UI_Shop_StarterPet.png",
}
# The image gate's run rule (Review-QA on #1128): at most ICONS_PER_RUN pictures per run, named in ONLY, and the
# run stops at the first answer that is not 2xx.
ICONS_PER_RUN = 4
SERVER_SIZE = 6
MAX_PAGES = 20


def request(method, url, key, body=None, content_type="application/json", retry=True):
    """retry False: one try only, for a call that makes something (a retry after a lost answer would make a copy)."""
    headers = {"x-api-key": key}
    data = None
    if body is not None:
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        headers["Content-Type"] = content_type
    for wait in (5, 10, 20, 0) if retry else (0,):
        req = urllib.request.Request(url, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=60) as res:
                text = res.read().decode() or "{}"
                try:
                    return res.status, json.loads(text)
                except ValueError:
                    return res.status, {"raw": text[:500]}
        except urllib.error.HTTPError as err:
            text = err.read().decode()
            if err.code in (429, 500, 502, 503, 504) and wait:
                time.sleep(wait)
                continue
            try:
                return err.code, json.loads(text or "{}")
            except ValueError:
                return err.code, {"raw": text[:500]}
        except urllib.error.URLError as err:
            if wait:
                time.sleep(wait)
                continue
            return 0, {"raw": str(err.reason)}
    return 0, {}


def multipart(fields, files=()):
    """fields: [(name, text)], files: [(name, filename, content_type, bytes)] -> (body, content type)."""
    boundary = "----cleanacat" + uuid.uuid4().hex
    out = []
    for name, value in fields:
        out.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}\r\n".encode())
    for name, filename, ctype, blob in files:
        out.append(
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"; filename=\"{filename}\"\r\n"
            f"Content-Type: {ctype}\r\n\r\n".encode()
            + blob
            + b"\r\n"
        )
    out.append(f"--{boundary}--\r\n".encode())
    return b"".join(out), f"multipart/form-data; boundary={boundary}"


def short(obj):
    return json.dumps(obj)[:600]


def named(obj, found):
    """Every dict in obj that has a name: (name, id, price)."""
    if isinstance(obj, dict):
        if isinstance(obj.get("name"), str):
            ident = next(
                (obj[k] for k in ("gamePassId", "productId", "developerProductId", "id") if k in obj), None
            )
            price = obj.get("price")
            if isinstance(obj.get("priceInformation"), dict):
                price = obj["priceInformation"].get("defaultPriceInRobux", price)
            found.append((obj["name"], ident, price))
        for value in obj.values():
            named(value, found)
    elif isinstance(obj, list):
        for value in obj:
            named(value, found)


def list_all(key, base):
    """(status, [(name, id, price)], first page) for a creator list endpoint, following pageToken."""
    items, token, first = [], "", None
    for _ in range(MAX_PAGES):
        url = base + ("?pageSize=50" + (f"&pageToken={urllib.parse.quote(token)}" if token else ""))
        status, page = request("GET", url, key)
        if first is None:
            first = page
        if status != 200:
            return status, items, page
        named(page, items)
        token = page.get("nextPageToken") or ""
        if not token:
            break
    return 200, items, first


def pick_key(keys, test):
    """The first key whose test call answers 200, as (label, key, status, body) of that call or of the last try."""
    last = None
    for label, key in keys:
        status, body = test(key)
        if status == 200:
            return label, key, status, body
        last = (label, None, status, body)
    return last or (None, None, 0, {})


def make(kind, wanted, keys, universe, confirm, summary):
    path = "game-passes/v1" if kind == "passes" else "developer-products/v2"
    noun = "game-passes" if kind == "passes" else "developer-products"
    base = f"{API}/{path}/universes/{universe}/{noun}"
    label, key, status, first = pick_key(keys, lambda k: list_all(k, base + "/creator")[0:3:2])
    if key is None:
        summary.append(f"Cannot list {kind}: HTTP {status}: {short(first)}")
        return False
    _, have, _ = list_all(key, base + "/creator")
    summary.append(f"Using {label}. {kind} already on the experience: {len(have)}")
    names = {}
    for name, ident, price in have:
        names.setdefault(name.strip().lower(), (name, ident, price))
        summary.append(f"- {name}: id {ident}, price {price}")
    ids = {}
    ok = True
    for entry in wanted:
        our_key, name, price, text = entry[:4]
        old_names = entry[4] if len(entry) > 4 else ()
        there = names.get(name.lower())
        if there:
            ids[our_key] = there[1]
            summary.append(f"skip {name}: already there (id {there[1]}, price {there[2]})")
            continue
        was = next((names[o.lower()] for o in old_names if o.lower() in names), None)
        if was is not None:
            ids[our_key] = was[1]
            if kind != "passes":
                summary.append(f"FAILED {name}: only passes can be renamed here; {was[0]} (id {was[1]}) left as it is")
                ok = False
                break
            if confirm != "yes":
                summary.append(f"would rename {was[0]} (id {was[1]}) to {name}")
                continue
            body, ctype = multipart([("name", name), ("description", text)])
            status, answer = request("PATCH", f"{base}/{was[1]}", key, body, ctype)
            time.sleep(2)
            _, again, _ = list_all(key, base + "/creator")
            now = next((item for item in again if str(item[1]) == str(was[1])), None)
            if now and now[0].strip().lower() == name.lower():
                summary.append(f"renamed {was[0]} to {name}: id {was[1]} (HTTP {status})")
                continue
            summary.append(f"FAILED to rename {was[0]} (id {was[1]}) to {name}: HTTP {status}: {short(answer)}")
            ok = False
            break
        if confirm != "yes":
            summary.append(f"would make {name} for {price} Robux")
            continue
        fields = [("name", name), ("description", text), ("price", str(price)), ("isForSale", "true")]
        body, ctype = multipart(fields)
        # never retried (Review-QA on #852): an error after Roblox made it would make a copy that cannot be deleted,
        # so an unclear answer is checked by listing again
        status, made = request("POST", base, key, body, ctype, retry=False)
        if status not in (200, 201):
            time.sleep(5)
            _, again, _ = list_all(key, base + "/creator")
            there = next((item for item in again if item[0].strip().lower() == name.lower()), None)
            if there:
                ids[our_key] = there[1]
                summary.append(f"made {name} (the answer was HTTP {status}, but the list has it): id {there[1]}")
                continue
            summary.append(f"FAILED {name}: HTTP {status}: {short(made)}")
            ok = False
            break  # stop at the first refusal: the next ones would fail the same way
        found = []
        named(made, found)
        ident = next(
            (made[k] for k in ("gamePassId", "productId", "developerProductId", "id") if k in made),
            found[0][1] if found else None,
        )
        ids[our_key] = ident
        summary.append(f"made {name} for {price} Robux: id {ident} ({short(made)[:200]})")
        time.sleep(1)
    if ids:
        summary.append("Ids for the code (key = id):")
        for our_key, *_ in wanted:
            if our_key in ids:
                summary.append(f"    {our_key} = {ids[our_key]},")
    return ok


def sale_price(regular):
    """SaleRules.salePrice: half, rounded down, at least 1 Robux."""
    return max(1, regular // 2)


def set_prices(kind, wanted, keys, universe, confirm, summary, sale):
    """Sets each made pass or product to its sale price (sale) or its regular price, then reads the list back."""
    path = "game-passes/v1" if kind == "passes" else "developer-products/v2"
    noun = "game-passes" if kind == "passes" else "developer-products"
    base = f"{API}/{path}/universes/{universe}/{noun}"
    label, key, status, first = pick_key(keys, lambda k: list_all(k, base + "/creator")[0:3:2])
    if key is None:
        summary.append(f"Cannot list {kind}: HTTP {status}: {short(first)}")
        return False
    _, have, _ = list_all(key, base + "/creator")
    names = {name.strip().lower(): (name, ident, price) for name, ident, price in have}
    summary.append(f"Using {label}. {kind}: {'sale' if sale else 'regular'} prices")
    ok = True
    for entry in wanted:
        _, name, regular = entry[:3]
        target = sale_price(regular) if sale else regular
        there = names.get(name.lower())
        if not there:
            summary.append(f"skip {name}: not made on this experience yet")
            continue
        if there[2] == target:
            summary.append(f"ok {name}: already {target} Robux")
            continue
        if confirm != "yes":
            summary.append(f"would set {name} (id {there[1]}) from {there[2]} to {target} Robux")
            continue
        body, ctype = multipart([("price", str(target)), ("isForSale", "true")])
        status, answer = request("PATCH", f"{base}/{there[1]}", key, body, ctype)
        time.sleep(2)
        _, again, _ = list_all(key, base + "/creator")
        now = next((item for item in again if str(item[1]) == str(there[1])), None)
        if now and now[2] == target:
            summary.append(f"set {name} from {there[2]} to {target} Robux: id {there[1]} (HTTP {status})")
            continue
        seen = now[2] if now else "?"
        summary.append(f"FAILED {name}: still {seen} Robux after HTTP {status}: {short(answer)}")
        ok = False
    return ok


def icon_keys(raw, confirm, summary):
    """The ONLY input as a list of ICONS keys, or None when it is refused. With confirm yes it must name 1 to
    ICONS_PER_RUN keys; a plan run may leave it empty (every key)."""
    keys = [k.strip() for k in (raw or "").split(",") if k.strip()]
    unknown = [k for k in keys if k not in ICONS]
    if unknown:
        summary.append(f"REFUSED: not in ICONS: {', '.join(unknown)}")
        return None
    if confirm == "yes" and not 1 <= len(keys) <= ICONS_PER_RUN:
        summary.append(f"REFUSED: with confirm yes, only must name 1 to {ICONS_PER_RUN} keys (the image gate's run rule)")
        return None
    return keys or list(ICONS)


def set_icons(kind, wanted, keys, universe, confirm, summary, only):
    """Sets the buy prompt picture of each made pass or product named in `only` from ICONS (issue 1122). Every file
    must pass approved() first; nothing is sent unless all of them do. A pass or product not made yet is skipped. The
    first answer that is not 2xx stops the run (False)."""
    path = "game-passes/v1" if kind == "passes" else "developer-products/v2"
    noun = "game-passes" if kind == "passes" else "developer-products"
    base = f"{API}/{path}/universes/{universe}/{noun}"
    wanted = [entry for entry in wanted if entry[0] in only]
    if not wanted:
        return True
    files = []
    for entry in wanted:
        icon = ICONS.get(entry[0])
        if icon is None:
            summary.append(f"skip {entry[1]}: no picture listed in ICONS")
            continue
        file = os.path.join(ICON_DIR, icon)
        if not os.path.isfile(file):
            summary.append(f"FAILED {entry[1]}: {file} is missing")
            return False
        files.append((entry, file))
    if not approved([file for _, file in files], summary):
        return False
    label, key, status, first = pick_key(keys, lambda k: list_all(k, base + "/creator")[0:3:2])
    if key is None:
        summary.append(f"Cannot list {kind}: HTTP {status}: {short(first)}")
        return False
    _, have, _ = list_all(key, base + "/creator")
    names = {name.strip().lower(): (name, ident, price) for name, ident, price in have}
    summary.append(f"Using {label}. {kind}: buy prompt pictures from {ICON_DIR}")
    for entry, file in files:
        name = entry[1]
        there = names.get(name.lower())
        if not there:
            summary.append(f"skip {name}: not made on this experience yet")
            continue
        if confirm != "yes":
            summary.append(f"would set the picture of {name} (id {there[1]}) to {os.path.basename(file)}")
            continue
        with open(file, "rb") as fh:
            blob = fh.read()
        body, ctype = multipart([], [("imageFile", os.path.basename(file), "image/png", blob)])
        # never retried: a retry would send the picture again, past the gate's count
        status, answer = request("PATCH", f"{base}/{there[1]}", key, body, ctype, retry=False)
        time.sleep(1)
        if 200 <= status < 300:
            summary.append(f"set the picture of {name} (id {there[1]}) to {os.path.basename(file)} (HTTP {status})")
        else:
            summary.append(f"FAILED the picture of {name} (id {there[1]}): HTTP {status}: {short(answer)}; run stopped")
            return False
    return True


def server_size(keys, universe, place, confirm, summary):
    url = f"{API}/cloud/v2/universes/{universe}/places/{place}"
    label, key, status, now = pick_key(keys, lambda k: request("GET", url, k))
    if key is None:
        summary.append(f"Cannot read the place: HTTP {status}: {short(now)}")
        return False
    summary.append(f"Using {label}. Place now: serverSize {now.get('serverSize')} ({now.get('displayName')})")
    if now.get("serverSize") == SERVER_SIZE:
        summary.append(f"Server size is already {SERVER_SIZE}.")
        return True
    if confirm != "yes":
        summary.append(f"would set serverSize {SERVER_SIZE}")
        return True
    status, after = request("PATCH", url + "?updateMask=serverSize", key, {"serverSize": SERVER_SIZE})
    if status != 200:
        summary.append(f"FAILED to set serverSize: HTTP {status}: {short(after)}")
        return False
    summary.append(f"Server size set: {after.get('serverSize')}")
    return True


def description(keys, universe, place, path, confirm, summary):
    # the game page's description is the start place's description (Growth's text, issue 892)
    if not path or not os.path.isfile(path):
        summary.append(f"No description file at {path}")
        return False
    with open(path, encoding="utf-8") as fh:
        text = fh.read().strip()
    if len(text) > 1000 or not text.isascii():
        summary.append(f"The description must be plain text under 1000 characters (it is {len(text)}, ascii {text.isascii()})")
        return False
    url = f"{API}/cloud/v2/universes/{universe}/places/{place}"
    label, key, status, now = pick_key(keys, lambda k: request("GET", url, k))
    if key is None:
        summary.append(f"Cannot read the place: HTTP {status}: {short(now)}")
        return False
    summary.append(f"Using {label}. Description now ({len(now.get('description') or '')} characters): {short(now.get('description') or '')}")
    if (now.get("description") or "").strip() == text:
        summary.append("The description already matches.")
        return True
    if confirm != "yes":
        summary.append(f"would set the description ({len(text)} characters)")
        return True
    status, after = request("PATCH", url + "?updateMask=description", key, {"description": text})
    if status != 200:
        summary.append(f"FAILED to set the description: HTTP {status}: {short(after)}")
        return False
    status, back = request("GET", url, key)
    saved = (back.get("description") or "").strip() if status == 200 else ""
    summary.append(f"Read back: {'matches' if saved == text else 'DIFFERS'} ({len(saved)} characters)")
    summary.append("Saved text:\n" + saved)
    return saved == text


def upload_image(key, group, path):
    meta = {
        "assetType": "Image",
        "displayName": os.path.splitext(os.path.basename(path))[0][:50],
        "description": "Clean a Cat store art",
        "creationContext": {"creator": {"groupId": str(group)}},
    }
    with open(path, "rb") as fh:
        blob = fh.read()
    body, ctype = multipart([("request", json.dumps(meta))], [("fileContent", os.path.basename(path), "image/png", blob)])
    status, op = request("POST", f"{API}/assets/v1/assets", key, body, ctype)
    if status != 200:
        return None, f"HTTP {status}: {short(op)}"
    name = op.get("path") or (f"operations/{op['operationId']}" if op.get("operationId") else None)
    for _ in range(30):
        if op.get("done"):
            break
        time.sleep(3)
        status, op = request("GET", f"{API}/assets/v1/{name}", key)
        if status != 200:
            return None, f"poll HTTP {status}: {short(op)}"
    asset = (op.get("response") or {}).get("assetId")
    return (asset, None) if asset else (None, f"no asset id: {short(op)}")


def read_list(path):
    lines = []
    if path and os.path.isfile(path):
        with open(path) as fh:
            lines = [ln.strip() for ln in fh if ln.strip() and not ln.startswith("#")]
    return lines


def approved(paths, summary):
    """Every image must be on main's .github/upload-allow.txt (sha256, two spaces, path) and none on
    .github/upload-blocked.txt, the same check as upload-asset.yml (Derek, 2026-11-27: "make sure that image is never
    uploaded again"). The workflow copies both lists from main into UPLOAD_ALLOW and UPLOAD_BLOCKED."""
    if os.environ.get("GITHUB_REF") != "refs/heads/main":
        summary.append("REFUSED: start this workflow on main, so main's approval lists are the ones checked")
        return False
    allow = set(read_list(os.environ.get("UPLOAD_ALLOW", "")))
    blocked = {ln.split()[0] for ln in read_list(os.environ.get("UPLOAD_BLOCKED", ""))}
    refused = 0
    for path in paths:
        with open(path, "rb") as fh:
            sum_ = hashlib.sha256(fh.read()).hexdigest()
        if sum_ in blocked:
            summary.append(f"REFUSED: {path} is BLOCKED ({sum_} is on .github/upload-blocked.txt)")
            refused += 1
        elif f"{sum_}  {path}" not in allow:
            summary.append(f"REFUSED: {path} is not approved: Review-QA adds '{sum_}  {path}' to .github/upload-allow.txt")
            refused += 1
        else:
            summary.append(f"Approved: {path}")
    if refused:
        summary.append(f"{refused} file(s) refused; nothing was uploaded")
    return refused == 0


def store_art(keys, place, group, art, confirm, summary):
    icon = os.path.join(art, "icon-main-512.png")
    thumbs = sorted(glob.glob(os.path.join(art, "thumbnail-order-*.png")))
    url = f"{API}/assets/v1/assets/{place}"
    label, key, status, now = pick_key(keys, lambda k: request("GET", url + "?readMask=previews,icon", k))
    if key is None:
        summary.append(f"Cannot read the place's page: HTTP {status}: {short(now)}")
        return False
    # the whole answer, not only icon and previews: the first runs read both as empty after a 200 PATCH (2026-11-26)
    summary.append(f"Using {label}. Page now: {short(now)}")
    if not os.path.isfile(icon) or len(thumbs) != 4:
        summary.append(f"Files missing in {art}: icon {os.path.isfile(icon)}, thumbnails {len(thumbs)} of 4")
        return False
    summary.append("Order: " + ", ".join(os.path.basename(t) for t in thumbs))
    if not approved([icon] + thumbs, summary):
        return False
    if confirm != "yes":
        summary.append("would upload the icon and 4 thumbnails, then set the icon and the thumbnails in that order")
        return True
    uploaded = []
    for path in [icon] + thumbs:
        asset, err = upload_image(key, group, path)
        if err:
            summary.append(f"FAILED upload {os.path.basename(path)}: {err}")
            return False
        uploaded.append(asset)
        summary.append(f"uploaded {os.path.basename(path)}: {asset}")
    alt = {
        1: "A half muddy cat being washed in Clean a Cat",
        2: "The Clean a Cat spa with a cat in the bath",
        3: "A busy cat spa with customers and their cats",
        4: "A stray kitten in a box outside the spa",
    }
    previews = [
        {"asset": f"assets/{asset}", "altText": alt.get(i + 1, "Clean a Cat")} for i, asset in enumerate(uploaded[1:])
    ]
    for mask, value in (("previews", previews), ("icon", f"assets/{uploaded[0]}")):
        meta = {"assetId": str(place), mask: value}
        body, ctype = multipart([("request", json.dumps(meta))])
        status, done = request("PATCH", f"{url}?updateMask={mask}", key, body, ctype)
        if status != 200:
            summary.append(f"FAILED to set {mask}: HTTP {status}: {short(done)}")
            return False
        summary.append(f"set {mask} at {time.strftime('%Y-%m-%d %H:%M:%S UTC', time.gmtime())}")
    return True


def main():
    action = os.environ.get("ACTION", "list")
    confirm = os.environ.get("CONFIRM", "").strip().lower()
    universe = os.environ["UNIVERSE_ID"]
    place = os.environ["PLACE_ID"]
    keys = [(n, os.environ.get(v, "")) for n, v in (("ROBLOX_GROUP_KEY", "KEY_GROUP"), ("OWNER_KEY", "KEY_OWNER"))]
    keys = [(n, k) for n, k in keys if k]
    summary = [f"## store-setup {action} on {os.environ.get('TARGET', '?')} (universe {universe}, place {place})"]
    if confirm != "yes":
        summary.append("Plan only: run again with confirm yes to make or change anything.")
    if not keys:
        summary.append("No key is set (ROBLOX_GROUP_KEY, OWNER_KEY).")
        ok = False
    elif action == "list":
        ok = make("passes", [], keys, universe, "no", summary) & make("products", [], keys, universe, "no", summary)
    elif action == "passes":
        ok = make("passes", PASSES, keys, universe, confirm, summary)
    elif action == "products":
        ok = make("products", PRODUCTS, keys, universe, confirm, summary)
    elif action in ("sale-prices", "regular-prices"):
        sale = action == "sale-prices"
        ok = set_prices("passes", PASSES, keys, universe, confirm, summary, sale)
        ok = set_prices("products", PRODUCTS, keys, universe, confirm, summary, sale) and ok
    elif action == "icons":
        only = icon_keys(os.environ.get("ONLY", ""), confirm, summary)
        ok = only is not None and set_icons("passes", PASSES, keys, universe, confirm, summary, only)
        # the products only after the passes went through (a failure stops the whole run)
        ok = ok and set_icons("products", PRODUCTS, keys, universe, confirm, summary, only)
    elif action == "server-size":
        ok = server_size(keys, universe, place, confirm, summary)
    elif action == "description":
        ok = description(keys, universe, place, os.environ.get("DESCRIPTION_FILE", ""), confirm, summary)
    elif action == "store-art":
        ok = store_art(keys, place, os.environ.get("GROUP_ID", ""), os.environ.get("ART_DIR", ""), confirm, summary)
    else:
        summary.append(f"Unknown action {action}")
        ok = False
    text = "\n".join(summary)
    print(text)
    out = os.environ.get("GITHUB_STEP_SUMMARY")
    if out:
        with open(out, "a") as fh:
            fh.write(text + "\n")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
