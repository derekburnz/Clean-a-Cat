# Spring trial preview (issue 183)

`spring-trial.mp4` plays the recap card from `../screens/recap.html` on a phone (844 x 390) twice, side by side. It
shows the card popping in, then the Next cat button being pressed, first at normal speed and then at half speed.

- **Left, today:** the quick tween our `ui-review` rules call for: scale 60% to 100% in 0.15 s, Quad out. A press squashes the button to 92% and back.
- **Right, trial:** the same moves on spr's spring. The pop in uses damping 0.55 at 3.2 Hz, the press 0.5 at 6 Hz and the release 0.45 at 5 Hz. These are the numbers in `games/clean-a-cat/src/client/UI/Motion.luau`.

This is a web preview. `frames.cjs` computes spr's damped spring formula and the tween curve, renders frames with Playwright and joins them. The in-game version sits behind the `springUi` switch (off), and a Studio clip of it can follow. Rebuild with:

    node frames.cjs <path to ../screens/recap.html> <frames folder>

then put the two sizes side by side and join the frames with ffmpeg straight from the PNGs. Use one palette for the
whole clip (`palettegen=stats_mode=full`, then `paletteuse=dither=none`). Never build a GIF frame by frame with a
fresh palette each time: the first version of this clip did, and still things such as the New! tag, the X and the
cat flickered as their colours moved between palettes. That flicker was in the video file only. The game draws
the real screen, and the UI gate's `jitter` check fails anything that keeps changing once a screen is settled.
