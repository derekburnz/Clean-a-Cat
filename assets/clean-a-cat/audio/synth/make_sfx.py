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


# --- Opening scene (#281): a small pastel delivery truck passes, hits a bump and a cardboard box falls out. ---------


def truck_rumble(rng: np.random.Generator) -> np.ndarray:
    """A small friendly delivery truck rolling by: a soft low engine purr with a light tyre hiss on top, 2 s and
    circular so it loops with no seam. Every tone sits on a multiple of 0.5 Hz (the loop's period)."""
    length = 2.0
    n = int(RATE * length)
    x = np.arange(n) / RATE
    f = np.fft.rfftfreq(n, 1 / RATE)
    engine = sum(a * np.sin(2 * np.pi * h * 48.0 * x + h) for h, a in ((1, 1.0), (2, 0.6), (3, 0.35), (4, 0.2), (6, 0.1)))
    engine *= 1 + 0.25 * np.sin(2 * np.pi * 12.0 * x)  # cylinder chug, 12 Hz wraps cleanly in 2 s
    engine /= np.max(np.abs(engine))
    hiss = np.fft.irfft(np.fft.rfft(rng.standard_normal(n)) * (1 / (1 + ((f - 1400) / 900) ** 2)), n)
    hiss /= np.max(np.abs(hiss))
    rattle = np.fft.irfft(np.fft.rfft(rng.standard_normal(n)) * (1 / (1 + ((f - 2600) / 500) ** 2)), n)
    rattle /= np.max(np.abs(rattle))
    rattle *= np.clip(np.sin(2 * np.pi * 3.0 * x), 0, 1) ** 4  # little body rattles, three a second
    return 0.8 * engine + 0.25 * hiss + 0.12 * rattle


def truck_honk(rng: np.random.Generator) -> np.ndarray:
    """One soft friendly toot-toot: two short squeezy horn notes (a major third), round, never loud or rude."""
    out = np.zeros(int(RATE * 0.55))
    for at, f0, d in ((0.0, 466.0, 0.16), (0.21, 587.0, 0.24)):
        x = t(d)
        tone = sum(a * np.sin(2 * np.pi * h * f0 * x) for h, a in ((1, 1.0), (2, 0.5), (3, 0.3), (4, 0.12)))
        shape = np.minimum(1, x / 0.015) * np.minimum(1, (d - x) / 0.04)
        start = int(RATE * at)
        out[start : start + len(x)] += lowpass(tone * shape, 2600)
    return out


def truck_bump(rng: np.random.Generator, variant: int) -> np.ndarray:
    """The wheels go over the bump: a soft rubbery thunk with a springy boing in the suspension. Variant 1 (back
    wheels) adds a short rattle of cargo, since that is the bump that throws the box."""
    d = 0.5
    x = t(d)
    thump = np.sin(2 * np.pi * (90 + 60 * np.exp(-x / 0.03)) * x) * env(len(x), 0.004, 14)
    knock = bandpass(rng.standard_normal(len(x)), 300, 1800) * env(len(x), 0.002, 45) * 0.5
    spring = np.sin(2 * np.pi * 210 * x * (1 + 0.15 * np.exp(-x / 0.1))) * np.exp(-x / 0.12) * 0.18
    out = thump + knock + spring
    if variant == 1:
        for _ in range(7):
            at = rng.uniform(0.04, 0.3)
            m = int(RATE * 0.03)
            tick = bandpass(rng.standard_normal(m), 900, 4000) * env(m, 0.001, 120) * rng.uniform(0.15, 0.3)
            start = int(RATE * at)
            out[start : start + m] += tick
    return out


def truck_door(rng: np.random.Generator) -> np.ndarray:
    """The rear door swings up: a short latch clack and a light metal flap that wobbles once."""
    d = 0.45
    x = t(d)
    clack = bandpass(rng.standard_normal(len(x)), 1200, 5000) * env(len(x), 0.001, 90)
    flap = np.sin(2 * np.pi * 340 * x) * np.sin(2 * np.pi * 7 * x) * np.exp(-x / 0.12) * 0.35
    return clack + flap


def box_thud(rng: np.random.Generator) -> np.ndarray:
    """A cardboard box lands on the pavement: a hollow papery thud, a soft slap of the flaps and a tiny scuff."""
    d = 0.4
    x = t(d)
    body = np.sin(2 * np.pi * (140 + 90 * np.exp(-x / 0.02)) * x) * env(len(x), 0.003, 22)
    paper = bandpass(rng.standard_normal(len(x)), 400, 2600) * env(len(x), 0.002, 35) * 0.6
    scuff = bandpass(rng.standard_normal(len(x)), 2000, 6000) * np.exp(-((x - 0.06) / 0.03) ** 2) * 0.15
    return body + paper + scuff


def box_rustle(rng: np.random.Generator) -> np.ndarray:
    """Something small wriggles in a cardboard box: two quick papery scrapes and a little bump against the side."""
    out = np.zeros(int(RATE * 0.5))
    for at, gain in ((0.0, 1.0), (0.16, 0.8)):
        m = int(RATE * 0.12)
        scrape = bandpass(rng.standard_normal(m), 1500, 5500) * np.sin(np.pi * np.arange(m) / m) * gain * 0.6
        start = int(RATE * at)
        out[start : start + m] += scrape
    m = int(RATE * 0.12)
    tt = np.arange(m) / RATE
    bump = np.sin(2 * np.pi * 180 * tt) * np.exp(-tt / 0.02) * 0.5
    start = int(RATE * 0.3)
    out[start : start + m] += bump
    return out


def collar_jingle(rng: np.random.Generator) -> np.ndarray:
    """Suds gets his collar: a small gold bell shaken three times, a bright jingle with a warm ring under it.
    A tiny bell's partials are inharmonic, so each strike rings at 1, 2.4 and 3.9 times its base, decaying fast."""
    out = np.zeros(int(RATE * 0.9))
    for at, gain, base in ((0.0, 1.0, 2350.0), (0.09, 0.8, 2420.0), (0.17, 0.65, 2300.0), (0.3, 0.45, 2380.0)):
        d = 0.55
        x = t(d)
        strike = sum(a * np.sin(2 * np.pi * base * m * x) * np.exp(-x * k) for m, a, k in ((1, 1.0, 7), (2.4, 0.45, 14), (3.9, 0.2, 22)))
        click = bandpass(rng.standard_normal(len(x)), 3000, 8000) * env(len(x), 0.0005, 300) * 0.3
        start = int(RATE * at)
        out[start : start + len(x)] += (strike + click) * gain
    return out


def ui_click(rng: np.random.Generator) -> np.ndarray:
    x = t(0.05)
    return np.sin(2 * np.pi * 1800 * x) * env(len(x), 0.0008, 120)


# --- The wash bar batch (2026-11-25, after Derek picked the game: soft and cosy, pastel bubbles, gentle sounds,
# small sparkles; never splashy or cartoony). -----------------------------------------------------------------


def place(out: np.ndarray, sig: np.ndarray, at: float, gain: float = 1.0) -> None:
    start = int(RATE * at)
    end = min(len(out), start + len(sig))
    if start < end:
        out[start:end] += sig[: end - start] * gain


def foam_swell(rng: np.random.Generator) -> np.ndarray:
    """"So foamy": the cat is covered. A soft cluster of rising bubbles, quieter as they climb, over a faint airy
    shimmer, about 0.8 s."""
    out = np.zeros(int(RATE * 0.85))
    for i in range(7):
        base = 700 + i * 110 + rng.uniform(-30, 30)
        place(out, bubble(base, base * 1.7, 0.09, rng), i * 0.075, 0.75 - i * 0.07)
    x = t(0.85)
    air = bandpass(rng.standard_normal(len(x)), 2500, 7000) * np.sin(np.pi * np.clip(x / 0.85, 0, 1)) ** 2 * 0.12
    return out + air


def rinse_loop(rng: np.random.Generator) -> np.ndarray:
    """The Shower tool's spray on fur: a soft, even water hiss with a gentle flutter and a scatter of tiny droplet
    ticks. 2 s and circular so it loops with no seam. Kept low and warm, never a blasting hose."""
    length = 2.0
    n = int(RATE * length)
    x = np.arange(n) / RATE
    # circular noise: filter a tripled copy and keep the middle, so both ends match
    raw = rng.standard_normal(n)
    hiss = bandpass(np.concatenate([raw, raw, raw]), 900, 5000)[n : 2 * n]
    flutter = 0.85 + 0.15 * np.sin(2 * np.pi * 4 * x) * np.sin(2 * np.pi * 0.5 * x)
    out = hiss * flutter * 0.6
    for _ in range(26):
        at = rng.uniform(0, length)
        m = int(RATE * 0.02)
        tt = np.arange(m) / RATE
        f0 = rng.uniform(1800, 3200)
        tick = np.sin(2 * np.pi * f0 * tt * (1 + 1.5 * tt)) * np.exp(-tt / 0.004) * rng.uniform(0.1, 0.25)
        idx = (int(RATE * at) + np.arange(m)) % n
        out[idx] += tick
    return out


def foam_drop(rng: np.random.Generator) -> np.ndarray:
    """The last foam slides off at the rinse's end and lands round the feet: four soft muted plops, each a little
    lower, about 0.7 s."""
    out = np.zeros(int(RATE * 0.7))
    for i, at in enumerate((0.0, 0.11, 0.2, 0.31)):
        x = t(0.16)
        freq = 420 - i * 45 + 140 * np.exp(-x * 50)
        tone = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * env(len(x), 0.004, 30)
        puff = lowpass(rng.standard_normal(len(x)), 1800) * env(len(x), 0.003, 45) * 0.35
        place(out, lowpass(tone + puff, 3000), at, 0.9 - i * 0.12)
    return out


def step_chime(rng: np.random.Generator) -> np.ndarray:
    """A wash bar fills: three small soft notes stepping up (G6, B6, D7) and a faint sparkle, short and warm, a
    smaller cousin of the reveal chime so the last step's chime still feels bigger."""
    out = np.zeros(int(RATE * 0.7))
    for at, freq, gain in ((0.0, 1568.0, 0.55), (0.06, 1975.5, 0.5), (0.12, 2349.3, 0.45)):
        place(out, chime_note(freq, 0.55) * np.exp(-t(0.55) * 2), at, gain)
    x = t(0.4)
    sparkle = bandpass(rng.standard_normal(len(x)), 6000, 11000) * env(len(x), 0.01, 9) * 0.05
    place(out, sparkle, 0.1)
    return out


def claw_snip(rng: np.random.Generator) -> np.ndarray:
    """A pet nail clipper: one small soft snip, a tiny click with a short bright tick, never a crunch."""
    out = np.zeros(int(RATE * 0.09))
    n = int(RATE * 0.025)
    click = bandpass(rng.standard_normal(n), 1500, 6000) * env(n, 0.0004, 220)
    place(out, click, 0.0, 0.8)
    x = t(0.05)
    tick = np.sin(2 * np.pi * 3100 * x) * env(len(x), 0.0005, 140) * 0.35
    place(out, tick, 0.012)
    return out


def visitor_chime(rng: np.random.Generator) -> np.ndarray:
    """A special customer arrives: a soft harp-like rising run on a major pentatonic (C6 D6 E6 G6 A6 C7) with a
    light shimmer on top, about 1.3 s. Inviting, never a fanfare."""
    out = np.zeros(int(RATE * 1.3))
    notes = (1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0)
    for i, freq in enumerate(notes):
        x = t(0.9)
        pluck = env(len(x), 0.002, 4.5) * (np.sin(2 * np.pi * freq * x) + 0.3 * np.sin(2 * np.pi * freq * 2 * x) + 0.08 * np.sin(2 * np.pi * freq * 3 * x))
        place(out, pluck, i * 0.065, 0.5 + 0.05 * i)
    x = t(1.0)
    shimmer = bandpass(rng.standard_normal(len(x)), 6500, 12000) * np.sin(np.pi * np.clip(x / 1.0, 0, 1)) ** 2 * 0.06
    place(out, shimmer, 0.2)
    return out


def crate_drop(rng: np.random.Generator) -> np.ndarray:
    """A gift crate lands by the door: a soft hollow wooden bonk, a little bounce, then a small bright twinkle so it
    reads as a present, about 0.8 s."""
    out = np.zeros(int(RATE * 0.8))
    for at, gain, f0 in ((0.0, 1.0, 190.0), (0.16, 0.4, 230.0)):
        x = t(0.22)
        freq = f0 + 60 * np.exp(-x * 40)
        body = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * env(len(x), 0.002, 22)
        knock = bandpass(rng.standard_normal(len(x)), 500, 2200) * env(len(x), 0.001, 70) * 0.5
        place(out, lowpass(body + knock, 2500), at, gain)
    for at, freq in ((0.26, 2637.0), (0.33, 3136.0)):
        place(out, chime_note(freq, 0.4) * np.exp(-t(0.4) * 3), at, 0.25)
    return out


def bow_tie(rng: np.random.Generator) -> np.ndarray:
    """The bow is tied: a quick soft ribbon swish and a tiny two-note sparkle, about 0.45 s."""
    out = np.zeros(int(RATE * 0.45))
    x = t(0.16)
    swish = bandpass(rng.standard_normal(len(x)), 2500, 7000) * np.sin(np.pi * np.clip(x / 0.16, 0, 1)) ** 2 * 0.5
    place(out, swish, 0.0)
    for at, freq in ((0.12, 2349.3), (0.18, 2793.8)):
        place(out, chime_note(freq, 0.3) * np.exp(-t(0.3) * 4), at, 0.3)
    return out


def soft_pluck(freq: float, length: float, decay: float = 4.5) -> np.ndarray:
    x = t(length)
    return env(len(x), 0.002, decay) * (np.sin(2 * np.pi * freq * x) + 0.3 * np.sin(2 * np.pi * freq * 2 * x) + 0.08 * np.sin(2 * np.pi * freq * 3 * x))


def shimmer(rng: np.random.Generator, length: float, gain: float) -> np.ndarray:
    x = t(length)
    return bandpass(rng.standard_normal(len(x)), 6500, 12000) * np.sin(np.pi * np.clip(x / length, 0, 1)) ** 2 * gain


def heart_low(rng: np.random.Generator) -> np.ndarray:
    """A waiting cat's heart bar is getting low: a soft two-note nudge stepping down (A5 then F5), round and quiet,
    about 0.6 s. A reminder, never an alarm."""
    out = np.zeros(int(RATE * 0.6))
    for at, freq, gain in ((0.0, 880.0, 0.7), (0.16, 698.5, 0.6)):
        x = t(0.42)
        tone = env(len(x), 0.012, 7) * (np.sin(2 * np.pi * freq * x) + 0.2 * np.sin(2 * np.pi * freq * 2 * x))
        place(out, tone, at, gain)
    return out


def cat_leave(rng: np.random.Generator) -> np.ndarray:
    """A cat gives up and leaves: three gentle notes falling (E6 C6 A5) over a soft airy whoosh going away, about
    1 s. A little sad, kind to young players."""
    out = np.zeros(int(RATE * 1.0))
    for i, freq in enumerate((1318.5, 1046.5, 880.0)):
        place(out, soft_pluck(freq, 0.6, 5.5), i * 0.12, 0.5 - i * 0.06)
    x = t(0.7)
    whoosh = bandpass(rng.standard_normal(len(x)), 1200, 4000) * np.sin(np.pi * np.clip(x / 0.7, 0, 1)) ** 2 * np.exp(-x * 2) * 0.12
    place(out, whoosh, 0.05)
    return out


def crate_open(rng: np.random.Generator) -> np.ndarray:
    """A crate is tapped open: a soft wooden knock, a puff of air as the lid lifts and a short rising sparkle run
    (G6 B6 D7), about 0.9 s. The same every time, whatever is inside: no near-miss build-up."""
    out = np.zeros(int(RATE * 0.9))
    x = t(0.15)
    freq = 330 + 80 * np.exp(-x * 50)
    knock = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * env(len(x), 0.002, 30)
    knock += bandpass(rng.standard_normal(len(x)), 700, 2600) * env(len(x), 0.001, 80) * 0.4
    place(out, lowpass(knock, 3000), 0.0, 0.8)
    x = t(0.25)
    puff = bandpass(rng.standard_normal(len(x)), 1500, 6000) * np.sin(np.pi * np.clip(x / 0.25, 0, 1)) ** 2 * 0.25
    place(out, puff, 0.06)
    for i, f0 in enumerate((1568.0, 1975.5, 2349.3)):
        place(out, soft_pluck(f0, 0.5, 6), 0.14 + i * 0.05, 0.35)
    place(out, shimmer(rng, 0.5, 0.05), 0.18)
    return out


def pet_reveal(rng: np.random.Generator) -> np.ndarray:
    """The pet is shown: a warm major chord blooming upward (C6 E6 G6 C7), held softly, with a light shimmer, about
    1.5 s. One sound for every pet, so rarity is shown by the card and its chance, not by a bigger fanfare."""
    out = np.zeros(int(RATE * 1.5))
    for i, freq in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):
        x = t(1.3)
        bloom = env(len(x), 0.02, 2.6) * (np.sin(2 * np.pi * freq * x) + 0.25 * np.sin(2 * np.pi * freq * 2 * x))
        place(out, bloom, i * 0.05, 0.4)
    place(out, shimmer(rng, 1.0, 0.07), 0.1)
    return out


def star_up(rng: np.random.Generator) -> np.ndarray:
    """Three pets fuse into a star up: a soft swirl rising, a quick climb of four notes (C6 E6 G6 C7) and one bright
    held bell (E7), about 1.3 s. A little brighter than the pet reveal."""
    out = np.zeros(int(RATE * 1.3))
    x = t(0.45)
    sweep = bandpass(rng.standard_normal(len(x)), 1500, 7000) * (0.25 + 0.75 * (x / 0.45) ** 2) * 0.2
    place(out, sweep, 0.0)
    for i, freq in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):
        place(out, soft_pluck(freq, 0.5, 6), 0.2 + i * 0.06, 0.4)
    place(out, chime_note(2637.0, 0.85) * np.exp(-t(0.85) * 1.2), 0.45, 0.45)
    place(out, shimmer(rng, 0.8, 0.07), 0.45)
    return out


def quest_done(rng: np.random.Generator) -> np.ndarray:
    """A quest is ticked off: a small happy two-note "ta-da" (G6 then C7) with a tick of sparkle, about 0.7 s."""
    out = np.zeros(int(RATE * 0.7))
    place(out, chime_note(1568.0, 0.3) * np.exp(-t(0.3) * 5), 0.0, 0.5)
    place(out, chime_note(2093.0, 0.6) * np.exp(-t(0.6) * 2.5), 0.1, 0.55)
    place(out, shimmer(rng, 0.35, 0.05), 0.12)
    return out


def check_in(rng: np.random.Generator) -> np.ndarray:
    """The check in card's reward is taken: three light bell taps like coins in a jar (E7 G7 E7), each softer,
    about 0.8 s."""
    out = np.zeros(int(RATE * 0.8))
    for i, freq in enumerate((2637.0, 3136.0, 2637.0)):
        place(out, chime_note(freq, 0.4) * np.exp(-t(0.4) * 4), i * 0.09, 0.45 - i * 0.08)
    x = t(0.04)
    tick = bandpass(rng.standard_normal(len(x)), 3000, 8000) * env(len(x), 0.0005, 120) * 0.3
    for i in range(3):
        place(out, tick, i * 0.09)
    return out


def worker_done(rng: np.random.Generator) -> np.ndarray:
    """A worker finishes a cat: one small soft ding (D6) with a single bubble, quieter than the player's own reveal,
    about 0.5 s, since it can come often."""
    out = np.zeros(int(RATE * 0.5))
    place(out, chime_note(1174.7, 0.45) * np.exp(-t(0.45) * 4), 0.0, 0.5)
    place(out, bubble(1100, 1900, 0.08, rng), 0.03, 0.35)
    return out


def build_done(rng: np.random.Generator) -> np.ndarray:
    """A build is finished: two soft wooden taps like a little mallet, then a warm major chord (D6 F#6 A6 D7) rising,
    with a shimmer, about 1.4 s."""
    out = np.zeros(int(RATE * 1.4))
    for at, f0 in ((0.0, 420.0), (0.14, 470.0)):
        x = t(0.12)
        freq = f0 + 90 * np.exp(-x * 60)
        tap = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * env(len(x), 0.001, 40)
        tap += bandpass(rng.standard_normal(len(x)), 900, 3000) * env(len(x), 0.0008, 110) * 0.4
        place(out, lowpass(tap, 3500), at, 0.7)
    for i, freq in enumerate((1174.7, 1480.0, 1760.0, 2349.3)):
        place(out, soft_pluck(freq, 1.0, 3), 0.3 + i * 0.05, 0.4)
    place(out, shimmer(rng, 0.9, 0.06), 0.35)
    return out


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
    ("sfx", "CleanACat_Sfx_TruckRumble", truck_rumble),
    ("sfx", "CleanACat_Sfx_TruckHonk", truck_honk),
    ("sfx", "CleanACat_Sfx_TruckBump_1", lambda r: truck_bump(r, 0)),
    ("sfx", "CleanACat_Sfx_TruckBump_2", lambda r: truck_bump(r, 1)),
    ("sfx", "CleanACat_Sfx_TruckDoor", truck_door),
    ("sfx", "CleanACat_Sfx_BoxThud", box_thud),
    ("sfx", "CleanACat_Sfx_BoxRustle", box_rustle),
    ("sfx", "CleanACat_Sfx_CollarJingle", collar_jingle),
    ("sfx", "CleanACat_Sfx_FoamSwell", foam_swell),
    ("sfx", "CleanACat_Sfx_RinseLoop", rinse_loop),
    ("sfx", "CleanACat_Sfx_FoamDrop", foam_drop),
    ("sfx", "CleanACat_Sfx_StepChime", step_chime),
    ("sfx", "CleanACat_Sfx_ClawSnip", claw_snip),
    ("sfx", "CleanACat_Sfx_VisitorChime", visitor_chime),
    ("sfx", "CleanACat_Sfx_CrateDrop", crate_drop),
    ("sfx", "CleanACat_Sfx_BowTie", bow_tie),
    ("sfx", "CleanACat_Sfx_HeartLow", heart_low),
    ("sfx", "CleanACat_Sfx_CatLeave", cat_leave),
    ("sfx", "CleanACat_Sfx_CrateOpen", crate_open),
    ("sfx", "CleanACat_Sfx_PetReveal", pet_reveal),
    ("sfx", "CleanACat_Sfx_StarUp", star_up),
    ("sfx", "CleanACat_Sfx_WorkerDone", worker_done),
    ("sfx", "CleanACat_Sfx_BuildDone", build_done),
    ("ui", "CleanACat_Ui_QuestDone", quest_done),
    ("ui", "CleanACat_Ui_CheckIn", check_in),
    ("ui", "CleanACat_Ui_Camera", camera_shutter),
    ("ui", "CleanACat_Ui_Click", ui_click),
]


LOOPS = {"CleanACat_Sfx_SpongeLoop", "CleanACat_Sfx_DryerHum", "CleanACat_Sfx_TruckRumble", "CleanACat_Sfx_RinseLoop"}  # seamless loops: no end fade


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
