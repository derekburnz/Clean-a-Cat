#!/usr/bin/env python3
"""Synthesizes Clean a Cat's own short sound effects (fully original, no license questions).

Usage (from the repo root):
    python assets/clean-a-cat/audio/synth/make_sfx.py [--out assets/clean-a-cat/audio] [--seed 7]

Writes mono 48 kHz .ogg files into <out>/sfx and <out>/ui, named CleanACat_<Bus>_<Name>[_<Variant>].
Needs numpy and ffmpeg. Same seed, same files. Tune the numbers here, never by hand in an editor.
"""

from __future__ import annotations

import argparse
import shutil
import zlib
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

RATE = 48000
PEAK = 10 ** (-3 / 20)  # master to -3 dBFS so the gate's -1 dBTP ceiling has room


def t(seconds: float) -> np.ndarray:
    return np.arange(int(RATE * seconds)) / RATE


def env(n: int, attack: float, decay_rate: float) -> np.ndarray:
    x = np.arange(n) / RATE
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x * decay_rate)


def fade_out(sig: np.ndarray, seconds: float = 0.01) -> np.ndarray:
    k = min(len(sig), int(RATE * seconds))
    sig[-k:] *= np.linspace(1, 0, k)
    return sig


def lowpass(sig: np.ndarray, cutoff: float) -> np.ndarray:
    # one pole, enough to soften noise
    a = np.exp(-2 * np.pi * cutoff / RATE)
    out = np.empty_like(sig)
    y = 0.0
    for i, v in enumerate(sig):
        y = (1 - a) * v + a * y
        out[i] = y
    return out


def bandpass(sig: np.ndarray, low: float, high: float) -> np.ndarray:
    return lowpass(sig, high) - lowpass(lowpass(sig, high), low)


def bubble(f0: float, f1: float, length: float, rng: np.random.Generator) -> np.ndarray:
    # a bubble pop: a short sine whose pitch rises fast, with a soft click of noise
    x = t(length)
    freq = f0 + (f1 - f0) * (1 - np.exp(-x * 60))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    tone = np.sin(phase) * env(len(x), 0.002, 38)
    click = lowpass(rng.standard_normal(len(x)), 3500) * env(len(x), 0.0005, 400) * 0.3
    return tone + click


def bubble_pop(rng: np.random.Generator, variant: int) -> np.ndarray:
    base = [900, 1150, 1400][variant]
    return bubble(base, base * 1.8, 0.09, rng)


def mud_plop(rng: np.random.Generator) -> np.ndarray:
    # wet plop: low falling-then-rising blip plus a little filtered noise splash
    x = t(0.22)
    freq = 260 + 220 * (1 - np.exp(-x * 25)) - 80 * np.exp(-x * 80)
    tone = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * env(len(x), 0.003, 18)
    splash = bandpass(rng.standard_normal(len(x)), 600, 2500) * env(len(x), 0.004, 30) * 0.5
    return tone + splash


def chime_note(freq: float, length: float) -> np.ndarray:
    x = t(length)
    e = env(len(x), 0.004, 5.5)
    return e * (np.sin(2 * np.pi * freq * x) + 0.35 * np.sin(2 * np.pi * freq * 2 * x) + 0.12 * np.sin(2 * np.pi * freq * 3.01 * x))


def reveal_chime(rng: np.random.Generator) -> np.ndarray:
    # two soft notes, a major third up (E6 then G#6), the second starting 0.11 s later
    first = chime_note(1318.5, 0.9)
    second = chime_note(1661.2, 0.8)
    out = np.zeros(int(RATE * 0.92))
    out[: len(first)] += first
    start = int(RATE * 0.11)
    out[start : start + len(second)] += second[: len(out) - start]
    return out


def bow_pop(rng: np.random.Generator) -> np.ndarray:
    # a light cork-like pop, higher and rounder than the bubble
    return bubble(700, 1700, 0.12, rng) * 0.9


def brush_swish(rng: np.random.Generator, variant: int) -> np.ndarray:
    # filtered noise swept upward; each stroke a little higher (variant 0, 1, 2)
    x = t(0.28)
    noise = rng.standard_normal(len(x))
    shift = 1 + 0.12 * variant
    out = np.zeros_like(noise)
    # crude sweep: blend three bands with a moving weight
    bands = [bandpass(noise, 1500 * shift, 3000 * shift), bandpass(noise, 3000 * shift, 6000 * shift)]
    w = np.sin(np.pi * np.clip(x / 0.28, 0, 1)) ** 1.5
    out = bands[0] * (1 - x / 0.28) + bands[1] * (x / 0.28)
    return out * w


def camera_shutter(rng: np.random.Generator) -> np.ndarray:
    # two short soft clicks 60 ms apart
    out = np.zeros(int(RATE * 0.16))
    for start, gain in ((0, 1.0), (int(RATE * 0.06), 0.7)):
        n = int(RATE * 0.03)
        click = bandpass(rng.standard_normal(n), 1200, 5000) * env(n, 0.0005, 160) * gain
        out[start : start + n] += click
    return out


def sponge_loop(rng: np.random.Generator) -> np.ndarray:
    """A wet sponge rubbing fur: soft squishy noise that swells with each back and forth stroke (4 strokes in 2 s),
    with tiny bubbly squeaks. Built circular (strokes and noise wrap around) so the loop has no seam."""
    length = 2.0
    n = int(RATE * length)
    x = np.arange(n) / RATE
    noise = rng.standard_normal(n)
    # circular band-pass in the frequency domain so the start and end join cleanly
    f = np.fft.rfftfreq(n, 1 / RATE)
    wet = np.fft.irfft(np.fft.rfft(noise) * (1 / (1 + ((f - 1400) / 700) ** 2)), n)
    hiss = np.fft.irfft(np.fft.rfft(rng.standard_normal(n)) * (1 / (1 + ((f - 4200) / 1500) ** 2)), n)
    strokes = 0.35 + 0.65 * np.sin(np.pi * ((x * 2.0) % 1.0)) ** 1.5  # four strokes, a period of 0.5 s
    out = (wet / np.max(np.abs(wet)) + 0.25 * hiss / np.max(np.abs(hiss))) * strokes
    for k in range(6):  # small squeaks, wrapped around the loop
        start = int(rng.uniform(0, n))
        m = int(0.05 * RATE)
        tt = np.arange(m) / RATE
        squeak = np.sin(2 * np.pi * (1800 + 900 * tt / 0.05) * tt) * np.exp(-tt / 0.015) * 0.25
        idx = (np.arange(m) + start) % n
        out[idx] += squeak
    return out


def dryer_hum(rng: np.random.Generator) -> np.ndarray:
    """A small hood dryer: soft rushing air over a low fan hum, 2 s and circular so it loops with no seam.
    Every tone sits on a multiple of 0.5 Hz (the loop's period), and the air is filtered in the frequency domain."""
    length = 2.0
    n = int(RATE * length)
    x = np.arange(n) / RATE
    f = np.fft.rfftfreq(n, 1 / RATE)
    air = np.fft.irfft(np.fft.rfft(rng.standard_normal(n)) * (1 / (1 + ((f - 900) / 1100) ** 2)), n)
    air /= np.max(np.abs(air))
    hum = sum(a * np.sin(2 * np.pi * h * 110.0 * x) for h, a in ((1, 1.0), (2, 0.45), (3, 0.2), (5, 0.08)))
    hum /= np.max(np.abs(hum))
    flutter = 1 + 0.08 * np.sin(2 * np.pi * 3.0 * x)  # fan blades, 3 Hz wraps cleanly in 2 s
    return (0.75 * air + 0.3 * hum) * flutter


def fur_shake(rng: np.random.Generator) -> np.ndarray:
    """A cat shakes off water: four quick fur flaps that get smaller, with a scatter of tiny droplet ticks."""
    out = np.zeros(int(RATE * 0.75))
    for i, (at, gain) in enumerate(((0.0, 1.0), (0.11, 0.85), (0.21, 0.65), (0.3, 0.45))):
        n = int(RATE * 0.12)
        flap = bandpass(rng.standard_normal(n), 500, 3500) * env(n, 0.012, 28) * gain
        start = int(RATE * at)
        out[start : start + n] += flap
    for _ in range(14):
        at = rng.uniform(0.04, 0.6)
        n = int(RATE * 0.02)
        tt = np.arange(n) / RATE
        f0 = rng.uniform(2200, 3800)
        tick = np.sin(2 * np.pi * f0 * tt * (1 + 2 * tt)) * np.exp(-tt / 0.004) * rng.uniform(0.15, 0.35)
        start = int(RATE * at)
        out[start : start + n] += tick
    return out


# --- Cat voices. Ported from the owner's own asset library (derekburnz/Roblox-Asset-Library, audio/synth/synth.py,
# purr_loop and cat_voice), so these are original sounds we own; re-rendered here under Clean a Cat names. ---------


def purr_body(seed: int, rate: float, out_s: float, in_s: float) -> np.ndarray:
    """A purr over one breath out and one breath in: a fast train of tiny clicks (about 25 a second) through
    mouth and nose formants, louder breathing out, softer and quicker breathing in, with soft air under it."""
    gap = 0.12
    length = out_s + in_s + 2 * gap
    n = int(length * RATE)
    rng = np.random.default_rng(seed)
    x_t = np.arange(n) / RATE
    clicks = np.zeros(n)
    for start, d, hz, loud in ((0.0, out_s, rate, 1.0), (out_s + gap, in_s, rate * 1.08, 0.65)):
        at = start + rng.uniform(0, 0.01)
        while at < start + d:
            k = int(at * RATE) % n
            into = (at - start) / d
            clicks[k] += loud * np.sin(np.pi * into) ** 0.5 * rng.uniform(0.75, 1.0)
            at += (1 / hz) * (1 + 0.06 * np.sin(2 * np.pi * 1.3 * at) + rng.normal(0, 0.03))
    kernel_t = np.arange(int(0.012 * RATE)) / RATE
    kernel = np.random.default_rng(7).standard_normal(len(kernel_t)) * np.exp(-kernel_t / 0.0018)
    kernel += 0.3 * np.sin(2 * np.pi * 220 * kernel_t) * np.exp(-kernel_t / 0.004)
    padded = np.zeros(n)
    padded[: len(kernel)] = kernel
    voice = np.fft.irfft(np.fft.rfft(clicks) * np.fft.rfft(padded), n)
    f = np.fft.rfftfreq(n, 1 / RATE)
    nose = sum(
        a / (1 + ((f - c) / w) ** 2) for c, a, w in ((350, 0.8, 150), (900, 1.0, 300), (1800, 0.5, 400), (3000, 0.15, 600))
    )
    highpass = 1 / np.sqrt(1 + (90 / np.maximum(f, 1)) ** 4)
    voice = np.fft.irfft(np.fft.rfft(voice) * nose * highpass, n)
    turns = np.clip(np.minimum(x_t, np.abs(x_t - (out_s + gap))) / 0.05, 0, 1)
    breathing = np.where(
        x_t < out_s + gap,
        np.sin(np.pi * np.clip(x_t / out_s, 0, 1)),
        0.6 * np.sin(np.pi * np.clip((x_t - out_s - gap) / in_s, 0, 1)),
    )
    air = np.fft.irfft(np.fft.rfft(rng.standard_normal(n)) * (1 / (1 + ((f - 1800) / 900) ** 2)), n)
    x = voice / np.max(np.abs(voice)) + 0.08 * air / np.max(np.abs(air)) * breathing
    x *= 0.15 + 0.85 * np.maximum(breathing, 0) ** 0.6 * turns
    return x


def purr(rng: np.random.Generator, variant: int) -> np.ndarray:
    # one breath out and in, about 1.6 s, with a soft end so it works as a one shot
    sig = purr_body(70 + variant, [25.0, 23.5][variant], [0.8, 0.9][variant], 0.6)
    return fade_out(sig, 0.08)


def cat_voice(length: float, f0: float, f_peak: float, f_end: float, trill: float, seed: int) -> np.ndarray:
    """A small cat voice: a buzzy tone that rises to f_peak and falls to f_end through mouth formants.
    trill (0 to 1) is how much rolled "rr" there is; 0 is a plain "mew"."""
    x = t(length)
    k = x / length
    pitch = np.where(k < 0.4, f0 * (f_peak / f0) ** (k / 0.4), f_peak * (f_end / f_peak) ** ((k - 0.4) / 0.6))
    pitch = pitch * (1 + 0.01 * np.random.default_rng(seed).standard_normal(len(x)).cumsum() / np.sqrt(len(x)))
    phase = np.cumsum(pitch) / RATE
    buzz = (2 * (phase % 1.0) - 1) * (1 - trill * 0.4 + trill * 0.4 * np.sin(2 * np.pi * 28 * x))
    buzz *= np.sin(np.pi * np.clip(k, 0, 1)) ** 0.6
    spectrum = np.fft.rfft(buzz, 2 * len(buzz))
    f = np.fft.rfftfreq(2 * len(buzz), 1 / RATE)
    mouth = sum(a / (1 + ((f - c) / w) ** 2) for c, a, w in ((900, 1.0, 130), (1900, 0.6, 170), (3100, 0.25, 220)))
    out = np.fft.irfft(spectrum * mouth, 2 * len(buzz))[: len(buzz)]
    return out / np.max(np.abs(out))


def meow(rng: np.random.Generator, variant: int) -> np.ndarray:
    # three friendly voices: a plain mew, a rising "mew?" and a trilled "mrrp"; never a hiss
    shapes = [
        (0.32, 560, 760, 620, 0.1),
        (0.30, 600, 720, 900, 0.1),
        (0.22, 540, 700, 660, 0.7),
    ]
    length, f0, peak, end, trill = shapes[variant]
    return fade_out(cat_voice(length, f0, peak, end, trill, 4100 + variant), 0.03)


def ui_click(rng: np.random.Generator) -> np.ndarray:
    x = t(0.05)
    return np.sin(2 * np.pi * 1800 * x) * env(len(x), 0.0008, 120)


SOUNDS = [
    ("sfx", "CleanACat_Sfx_BubblePop_1", lambda r: bubble_pop(r, 0)),
    ("sfx", "CleanACat_Sfx_BubblePop_2", lambda r: bubble_pop(r, 1)),
    ("sfx", "CleanACat_Sfx_BubblePop_3", lambda r: bubble_pop(r, 2)),
    ("sfx", "CleanACat_Sfx_MudPlop", mud_plop),
    ("sfx", "CleanACat_Sfx_RevealChime", reveal_chime),
    ("sfx", "CleanACat_Sfx_BowPop", bow_pop),
    ("sfx", "CleanACat_Sfx_BrushSwish_1", lambda r: brush_swish(r, 0)),
    ("sfx", "CleanACat_Sfx_BrushSwish_2", lambda r: brush_swish(r, 1)),
    ("sfx", "CleanACat_Sfx_BrushSwish_3", lambda r: brush_swish(r, 2)),
    ("sfx", "CleanACat_Sfx_SpongeLoop", sponge_loop),
    ("sfx", "CleanACat_Sfx_FurShake", fur_shake),
    ("sfx", "CleanACat_Sfx_DryerHum", dryer_hum),
    ("sfx", "CleanACat_Sfx_Purr_1", lambda r: purr(r, 0)),
    ("sfx", "CleanACat_Sfx_Purr_2", lambda r: purr(r, 1)),
    ("sfx", "CleanACat_Sfx_Meow_1", lambda r: meow(r, 0)),
    ("sfx", "CleanACat_Sfx_Meow_2", lambda r: meow(r, 1)),
    ("sfx", "CleanACat_Sfx_Meow_3", lambda r: meow(r, 2)),
    ("ui", "CleanACat_Ui_Camera", camera_shutter),
    ("ui", "CleanACat_Ui_Click", ui_click),
]


LOOPS = {"CleanACat_Sfx_SpongeLoop", "CleanACat_Sfx_DryerHum"}  # seamless loops: no end fade


def write_ogg(sig: np.ndarray, path: Path, loop: bool = False) -> None:
    sig = sig.astype(np.float64)
    if not loop:
        sig = fade_out(sig)
    peak = np.max(np.abs(sig)) or 1.0
    pcm = (sig / peak * PEAK * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "x.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        path.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "6", "-fflags", "+bitexact", "-flags:a", "+bitexact", "-serial_offset", "0", str(path)],
            check=True,
        )


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--out", default="assets/clean-a-cat/audio")
    p.add_argument("--seed", type=int, default=7)
    args = p.parse_args()
    if not shutil.which("ffmpeg"):
        raise SystemExit("ffmpeg is not on PATH")
    out = Path(args.out)
    for folder, name, make in SOUNDS:
        rng = np.random.default_rng(args.seed + zlib.crc32(name.encode()) % 1000)
        write_ogg(make(rng), out / folder / f"{name}.ogg", loop=name in LOOPS)
        print(f"wrote {folder}/{name}.ogg")


if __name__ == "__main__":
    main()
