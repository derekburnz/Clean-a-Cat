# Builds sheet.html for the icon source trial (issue 185): six HUD icons from each source side by side, in our
# palette, on a cream window and over the world, at phone size. Run: python3 build.py, then open sheet.html.
import pathlib, re

HERE = pathlib.Path(__file__).parent
INK = '#45226b'
ICONS = [  # label, our kit icon, Phosphor name, Lucide name, palette colour, Derek's library picture
    ('Coins', 'coin', 'coins', 'coins', '#ffc94d', 'library/CatCafe_Icon_Coins.png'),
    ('Cat Index', 'book', 'book-open', 'book-open', '#a8e6cf', 'library/CatCafe_Icon_Hud_Index.png'),
    ('Tools', 'tools', 'toolbox', 'toolbox', '#8fd3fe', None),
    ('Settings', 'gear', 'gear-six', 'settings', '#d9c7f5', None),
    ('Helper', 'helper', 'hand-heart', 'hand-heart', '#ffb3c7', None),
    ('Build', 'hammer', 'hammer', 'hammer', '#ffd84d', None),
]


def svg(path):
    s = (HERE / path).read_text()
    return re.sub(r'\s+', ' ', s).replace(' width="24" height="24"', '')


def phosphor_fill(name, colour):
    s = svg(f'phosphor/{name}-fill.svg')
    return s.replace('fill="currentColor"', f'fill="{colour}" stroke="{INK}" stroke-width="14" paint-order="stroke" stroke-linejoin="round"')


def phosphor_duo(name, colour):
    s = svg(f'phosphor/{name}-duotone.svg')
    s = s.replace('opacity="0.2"', f'fill="{colour}" stroke="{INK}" stroke-width="10" stroke-linejoin="round"')
    return s.replace('fill="currentColor"', f'fill="{INK}"')


def lucide(name):
    return svg(f'lucide/{name}.svg').replace('stroke="currentColor"', f'stroke="{INK}"').replace('stroke-width="2"', 'stroke-width="2.4"')


rows = [
    ('Ours today', 'drawn in kit.js', lambda i: f'<i data-ic="{i[1]}"></i>'),
    ("Derek's library", 'Cat Cafe renders, only two fit', lambda i: f'<img src="{i[5]}" alt="">' if i[5] else '<span class="none">none</span>'),
    ('Phosphor, filled', 'MIT, recoloured, ink outline added', lambda i: phosphor_fill(i[2], i[4])),
    ('Phosphor, two tone', 'MIT, recoloured', lambda i: phosphor_duo(i[2], i[4])),
    ('Lucide', 'ISC, thin line set', lambda i: lucide(i[3])),
]

head = ''.join(f'<th>{i[0]}</th>' for i in ICONS)
body = ''
for name, note, cell in rows:
    tds = ''.join(f'<td><span class="ic-box">{cell(i)}</span></td>' for i in ICONS)
    body += f'<tr><th class="src"><b>{name}</b><small>{note}</small></th>{tds}</tr>\n'

world = ''
for name, note, cell in rows:
    world += f'<div class="hudrow"><span class="lbl outlined thin">{name}</span>' + ''.join(
        f'<span class="hudbtn"><span class="ic-box">{cell(i)}</span><span class="cap outlined thin">{i[0].split()[-1]}</span></span>' for i in ICONS) + '</div>\n'

html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Icon source trial</title>
<link href="https://fonts.googleapis.com/css2?family=Fredoka+One&family=Nunito:wght@700;800;900&display=block" rel="stylesheet">
<link rel="stylesheet" href="../screens/kit.css">
<style>
html, body {{ overflow: visible !important; height: auto !important; background: #f3e6d6; }}
#screen {{ display: none !important; }}
.sheet {{ width: 1240px; margin: 20px auto; font-family: var(--font-body); color: var(--ink); }}
h1 {{ font-family: var(--font-head); font-weight: 400; font-size: 34px; margin: 0 0 4px; }}
.sub {{ font-weight: 800; font-size: 17px; margin: 0 0 16px; color: #6b5a80; }}
.panel {{ background: var(--cream); border: 4px solid var(--ink); border-radius: 22px; padding: 14px 18px; box-shadow: 0 6px 0 var(--ink); margin-bottom: 22px; }}
h2 {{ font-family: var(--font-head); font-weight: 400; font-size: 24px; margin: 0 0 10px; }}
table {{ border-collapse: collapse; width: 100%; }}
th, td {{ text-align: center; padding: 8px 6px; }}
thead th {{ font-family: var(--font-head); font-weight: 400; font-size: 18px; }}
tbody tr {{ border-top: 3px solid #eadcc8; }}
th.src {{ text-align: left; width: 230px; }}
th.src b {{ display: block; font-family: var(--font-head); font-weight: 400; font-size: 19px; }}
th.src small {{ font-weight: 800; font-size: 14px; color: #6b5a80; }}
.ic-box {{ display: inline-grid; place-items: center; width: 48px; height: 48px; font-size: 48px; }}
.ic-box svg, .ic-box img {{ width: 48px; height: 48px; }}
.none {{ font-weight: 800; font-size: 14px; color: #a99bb8; }}
.world {{ position: relative; padding: 6px 0; border-radius: 22px; overflow: hidden; border: 4px solid var(--ink); background: url(../screens/img/world-spa.jpg) center/cover; margin-bottom: 22px; }}
.hudrow {{ display: flex; align-items: center; gap: 14px; padding: 10px 18px; }}
.hudrow .lbl {{ width: 210px; font-family: var(--font-head); font-size: 19px; }}
.hudbtn {{ display: flex; flex-direction: column; align-items: center; width: 64px; padding-top: 8px; border-radius: 16px; background: rgba(255,246,236,.85); border: 3px solid var(--ink); box-shadow: 0 4px 0 var(--ink); }}
.hudbtn .cap {{ font-family: var(--font-head); font-size: 14px; margin: 2px 0 4px; }}
.ui {{ display: grid; grid-template-columns: 1fr 1fr; gap: 22px; }}
.cell h3 {{ font-family: var(--font-head); font-weight: 400; font-size: 19px; margin: 0 0 8px; }}
.kbtn {{ position: relative; isolation: isolate; width: 210px; height: 64px; display: grid; place-items: center; font-family: var(--font-head); font-size: 24px; color: #fff; text-shadow: 0 2px 0 #1e7a3a; }}
.kbtn::before {{ content: ''; position: absolute; inset: 0; z-index: -1; background: url(kenney/button_green.png) center/100% 100% no-repeat; image-rendering: pixelated; filter: var(--inked); }}
.kpanel {{ position: relative; isolation: isolate; width: 300px; height: 150px; display: grid; place-items: center; font-weight: 800; font-size: 16px; }}
.kpanel::before {{ content: ''; position: absolute; inset: 0; z-index: -1; border: 18px solid transparent; border-image: url(kenney/panel_cream.png) 12 fill round; filter: var(--inked); }}
.sheet {{ --inked: drop-shadow(3px 0 0 var(--ink)) drop-shadow(-3px 0 0 var(--ink)) drop-shadow(0 3px 0 var(--ink)) drop-shadow(0 -3px 0 var(--ink)) drop-shadow(0 6px 0 var(--ink)); }}
.opanel {{ width: 300px; height: 150px; box-sizing: border-box; background: var(--cream); border: 4px solid var(--ink); border-radius: 22px; box-shadow: 0 6px 0 var(--ink); display: grid; place-items: center; font-weight: 800; font-size: 16px; }}
.row {{ display: flex; gap: 22px; align-items: center; }}
.note {{ font-weight: 800; font-size: 15px; color: #6b5a80; margin-top: 8px; }}
</style></head>
<body><div id="screen"><div id="stage"></div></div>
<div class="sheet">
<h1>Icon source trial (issue 185)</h1>
<p class="sub">Six HUD icons from each source at phone size (48 px), recoloured to Bubble Pastel. Nothing is uploaded. Licences: Phosphor MIT, Lucide ISC, Kenney CC0, so no credit line is shown to players.</p>
<div class="panel"><h2>On a cream window</h2><table><thead><tr><th></th>{head}</tr></thead><tbody>{body}</tbody></table></div>
<div class="world">{world}</div>
<div class="panel"><h2>Buttons and panels: Kenney UI Pack (CC0) beside ours</h2>
<div class="ui">
<div class="cell"><h3>Ours</h3><div class="row"><button class="btn green"><span class="lbl">Wash</span></button><div class="opanel">Our window body</div></div></div>
<div class="cell"><h3>Kenney, recoloured, our ink outline and lip added</h3><div class="row"><div class="kbtn">Wash</div><div class="kpanel">Kenney panel, 9-slice</div></div></div>
</div>
<p class="note"><b>My pick:</b> keep our own icons and Model-Agent renders as the main set, and use Phosphor two tone, recoloured, only for icons we have not drawn yet. Phosphor filled reads well except the coins, which blur at 48 px, Lucide is too thin over the world and Kenney, even with our outline and lip added, keeps its pale flat shading and small, pixel-edged corners, so it reads more generic than ours. The Kenney files here come from a GitHub mirror of the older 148 file pack, because kenney.nl is blocked from this machine.</p>
</div>
</div>
<script src="../screens/kit.js"></script>
</body></html>
'''
(HERE / 'sheet.html').write_text(html)
print('wrote sheet.html')
