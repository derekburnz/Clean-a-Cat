// Renders the recap card's pop in and the Next cat press, frame by frame, with today's tween and with spr's spring.
const { chromium } = require('playwright');
const path = require('path');
const FPS = 30, SECONDS = 2.2, POP_AT = 0.15, PRESS_AT = 1.25;
const quadOut = (t) => 1 - (1 - t) * (1 - t);
// spr: undamped frequency f (Hz), damping ratio d, from x0 to 1 with no starting speed
function spring(d, f, t) {
  const w = 2 * Math.PI * f;
  if (d >= 1) return 1 - Math.exp(-w * t) * (1 + w * t);
  const wd = w * Math.sqrt(1 - d * d);
  return 1 - Math.exp(-d * w * t) * (Math.cos(wd * t) + (d * w / wd) * Math.sin(wd * t));
}
function card(mode, t) {
  const u = t - POP_AT;
  if (u < 0) return { s: 0.6, o: 0 };
  if (mode === 'tween') { const k = Math.min(1, u / 0.15); const e = quadOut(k); return { s: 0.6 + 0.4 * e, o: e }; }
  const e = spring(0.55, 3.2, u); return { s: 0.6 + 0.4 * e, o: Math.min(1, u / 0.08) };
}
function press(mode, t) {
  const u = t - PRESS_AT;
  if (u < 0) return 1;
  // down for 0.1 s, then released
  if (mode === 'tween') {
    if (u < 0.1) return 1 - 0.08 * quadOut(Math.min(1, u / 0.06));
    return 0.92 + 0.08 * quadOut(Math.min(1, (u - 0.1) / 0.1));
  }
  if (u < 0.1) return 1 - 0.08 * spring(0.5, 6, u);
  const from = 1 - 0.08 * spring(0.5, 6, 0.1);
  return from + (1 - from) * spring(0.45, 5, u - 0.1);
}
(async () => {
  const [, , page, out] = process.argv;
  const b = await chromium.launch();
  for (const mode of ['tween', 'spring']) {
    const p = await b.newPage({ viewport: { width: 844, height: 390 }, deviceScaleFactor: 1 });
    await p.addInitScript(() => document.addEventListener('DOMContentLoaded', () => { document.body.dataset.state = 'full'; }));
    await p.goto('file://' + page); await p.waitForTimeout(1200);
    await p.addStyleTag({ content: '.win.recap{transform-origin:50% 50%} .win.recap .btn.green{transform-origin:50% 50%}' });
    const base = await p.evaluate(() => getComputedStyle(document.querySelector('.win.recap')).transform);
    for (let i = 0; i < FPS * SECONDS; i++) {
      const t = i / FPS, c = card(mode, t), bs = press(mode, t);
      await p.evaluate(([s, o, bs, base]) => {
        const w = document.querySelector('.win.recap');
        w.style.transform = (base === 'none' ? '' : base + ' ') + `scale(${s})`;
        w.style.opacity = o;
        document.querySelector('.backdrop').style.opacity = o;
        const btn = document.querySelector('.win.recap .btn.green'); btn.style.transform = `scale(${bs})`;
      }, [c.s, c.o, bs, base]);
      await p.screenshot({ path: path.join(out, `${mode}-${String(i).padStart(3, '0')}.png`) });
    }
    await p.close();
  }
  await b.close();
})();
