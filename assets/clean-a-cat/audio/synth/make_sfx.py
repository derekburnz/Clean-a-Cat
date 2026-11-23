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
    ("ui", "CleanACat_Ui_Camera", camera_shutter),
    ("ui", "CleanACat_Ui_Click", ui_click),
]


def write_ogg(sig: np.ndarray, path: Path) -> None:
    sig = fade_out(sig.astype(np.float64))
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
            ["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "6", str(path)],
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
        write_ogg(make(rng), out / folder / f"{name}.ogg")
        print(f"wrote {folder}/{name}.ogg")


if __name__ == "__main__":
    main()
