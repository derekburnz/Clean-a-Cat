#!/usr/bin/env python3
"""Synthesizes Clean a Cat's two spa music beds. They alternate in game (Audio/init.luau, spaMusicA and spaMusicB).

Run from the repo root:  python assets/clean-a-cat/audio/synth/music.py [--only SpaA] [--preview DIR]

  SpaA  "Warm Bubbles"   C major, 92 BPM: marimba tune over plucked chords, soft bass, shaker and rim
  SpaB  "Fluff and Fold" F major, 80 BPM: electric piano, flute tune, upright bass and brushes

The instruments, room and mixing are ported from the owner's own music code in derekburnz/Roblox-Asset-Library
(audio/synth/music.py), so everything is original and ours; the songs themselves are new for Clean a Cat, so
the game does not share Cat Cafe's music. Each song is 32 bars and every note, tail and echo wraps around the end,
so the loop is seamless. Outputs (overwritten): assets/clean-a-cat/audio/music/CleanACat_Music_<Name>.ogg
(stereo, 48 kHz, about -18 LUFS). Fixed seeds and a bitexact encode give byte-identical files on every run.
Needs numpy and ffmpeg. Check with .claude/skills/audio-pipeline/scripts/audio_gate.py.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 48000
ROOT = Path(__file__).resolve().parents[1]  # assets/clean-a-cat/audio
TARGET_LUFS = -18.0
CEILING_DB = -2.0  # sample peak; the gate's limit is -1 dBTP
BARS = 32

VIBES = ((1.0, 1.0, 0.9), (4.0, 0.18, 0.22), (10.0, 0.04, 0.05))
CELESTA = ((1.0, 1.0, 0.5), (2.0, 0.2, 0.2), (4.0, 0.12, 0.08))
MARIMBA = ((1.0, 1.0, 0.42), (3.93, 0.22, 0.06), (9.3, 0.05, 0.025))


def note(name: str) -> float:
    """Frequency of a note like C6 or F#4 (A4 = 440 Hz)."""
    steps = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}[name[0]]
    steps += name.count("#") - name.count("b")
    return 440.0 * 2 ** ((steps + 12 * (int(name[-1]) - 4)) / 12)


def envelope(duration: float, attack: float, tau: float, start: float = 0.0) -> np.ndarray:
    """Linear attack then exponential decay with time constant tau; zero before start."""
    t = seconds(duration) - start
    env = np.where(t < attack, t / max(attack, 1e-6), np.exp(-(t - attack) / tau))
    return np.where(t < 0, 0.0, env)


def bell(duration: float, f0: float, partials, start: float = 0.0, attack: float = 0.001) -> np.ndarray:
    """Sum of decaying sine partials: (ratio to f0, amplitude, decay seconds)."""
    t = seconds(duration) - start
    out = np.zeros_like(t)
    for ratio, amp, tau in partials:
        out += amp * np.sin(2 * np.pi * f0 * ratio * t) * envelope(duration, attack, tau, start)
    return np.where(t < 0, 0.0, out)



# --- building blocks ---------------------------------------------------------------------------


def seconds(d: float) -> np.ndarray:
    return np.arange(int(d * SR)) / SR


def lowpass(x: np.ndarray, hi: float, order: int = 2) -> np.ndarray:
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(np.fft.rfft(x) / np.sqrt(1 + (f / hi) ** (2 * order)), len(x))


def bandpass(x: np.ndarray, lo: float, hi: float) -> np.ndarray:
    f = np.maximum(np.fft.rfftfreq(len(x), 1 / SR), 1e-3)
    gain = 1 / np.sqrt(1 + (lo / f) ** 4) / np.sqrt(1 + (f / hi) ** 4)
    return np.fft.irfft(np.fft.rfft(x) * gain, len(x))


def release(x: np.ndarray, hold: float, tail: float) -> np.ndarray:
    """Let a note ring for `hold` seconds, then fade it out over `tail` seconds (a key or string let go)."""
    t = np.arange(len(x)) / SR
    return x * np.clip(1 - (t - hold) / tail, 0, 1)


class Song:
    """A stereo loop of a whole number of bars. Everything placed on it wraps around the end."""

    def __init__(self, bpm: float, meter: int, seed: int, swing: float = 0.0, bars: int = BARS):
        self.beat = 60.0 / bpm
        self.meter = meter
        self.swing = swing  # how late an off-beat eighth lands, in beats
        self.n = round(bars * meter * self.beat * SR)
        self.rng = np.random.default_rng(seed)

    def time(self, bar: int, beat: float) -> float:
        if self.swing and abs(beat % 1 - 0.5) < 1e-6:
            beat += self.swing
        return (bar * self.meter + beat) * self.beat

    def stem(self) -> np.ndarray:
        return np.zeros((self.n, 2))

    def put(self, stem: np.ndarray, x: np.ndarray, bar: int, beat: float, pan: float = 0.0, gain: float = 1.0,
            loose: float = 0.006) -> None:
        start = self.time(bar, beat) + (self.rng.normal(0, loose) if loose else 0.0)
        index = (np.arange(len(x)) + int(round(start * SR))) % self.n
        angle = (pan + 1) * np.pi / 4
        stem[index, 0] += x * gain * np.cos(angle)
        stem[index, 1] += x * gain * np.sin(angle)


def reverb(x: np.ndarray, seconds_: float, seed: int, hi: float = 6000.0) -> np.ndarray:
    """A small warm room, circular over the loop so the echo of the last bar lands on the first."""
    n = len(x)
    length = int(seconds_ * SR)
    t = np.arange(length) / SR
    out = np.empty_like(x)
    for channel in (0, 1):
        ir = np.random.default_rng(seed + channel).standard_normal(length) * np.exp(-6.9 * t / seconds_)
        ir = lowpass(ir, hi)
        ir[: int(0.015 * SR)] = 0
        full = np.zeros(n)
        full[:length] = ir / np.sqrt(np.sum(ir**2))
        out[:, channel] = np.fft.irfft(np.fft.rfft(x[:, channel]) * np.fft.rfft(full), n)
    return out


# --- instruments -------------------------------------------------------------------------------


def epiano(hold: float, f: float, velocity: float) -> np.ndarray:
    """A soft electric piano: a sine tine with a little FM bark that fades, and a slow tremolo."""
    t = seconds(hold + 0.5)
    index = 0.25 + 1.1 * velocity * np.exp(-t / 0.3)
    tone = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * t))
    tine = 0.12 * np.sin(2 * np.pi * 7 * f * t) * np.exp(-t / 0.05)
    env = np.clip(t / 0.004, 0, 1) * np.exp(-t / 1.8)
    trem = 1 - 0.07 * (0.5 + 0.5 * np.sin(2 * np.pi * 4.2 * t))
    return release((tone + tine) * env * trem * velocity, hold, 0.35)


def pluck(hold: float, f: float, seed: int, bright: float = 0.5, ring: float = 2.5) -> np.ndarray:
    """A nylon string (Karplus-Strong): a burst of noise circulating in a delay line one period long."""
    period = max(2, int(round(SR / f - 0.5)))
    n = int((hold + 0.3) * SR)
    burst = np.random.default_rng(seed).uniform(-1, 1, period)
    burst = lowpass(np.tile(burst, 4), 1500 + 6000 * bright)[:period]
    burst -= burst.mean()
    loss = 10 ** (-3 * period / (SR * ring))
    y = np.zeros(n + period + 1)
    y[1 : period + 1] = burst
    for start in range(period + 1, len(y), period):
        end = min(start + period, len(y))
        y[start:end] = loss * 0.5 * (y[start - period : end - period] + y[start - period - 1 : end - period - 1])
    # The loop sounds at SR / (period + 0.5); resample so the note lands exactly on f.
    played = SR / (period + 0.5)
    x = np.interp(np.arange(n) * f / played, np.arange(len(y) - 1), y[1:])
    return release(x / (np.max(np.abs(x)) + 1e-9), hold, 0.25)


def upright(hold: float, f: float, velocity: float) -> np.ndarray:
    """A plucked upright bass: round low partials, a soft thump at the start."""
    t = seconds(hold + 0.3)
    tone = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(4 * np.pi * f * t) + 0.22 * np.sin(6 * np.pi * f * t)
    env = np.clip(t / 0.008, 0, 1) * np.exp(-t / 0.9)
    thump = lowpass(np.random.default_rng(int(f)).standard_normal(len(t)), 400) * np.exp(-t / 0.02) * 0.4
    return release(tone * env + thump, hold, 0.12) * velocity


def flute(hold: float, f: float, seed: int) -> np.ndarray:
    """A breathy flute: a near sine with a touch of second harmonic, breath noise and a late vibrato."""
    t = seconds(hold + 0.12)
    vib = 1 + 0.005 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.25) / 0.3, 0, 1)
    phase = 2 * np.pi * np.cumsum(f * vib) / SR
    tone = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.05 * np.sin(3 * phase)
    breath = bandpass(np.random.default_rng(seed).standard_normal(len(t)), f * 1.5, f * 4) * 0.12
    env = np.clip(t / 0.06, 0, 1) * np.clip((hold + 0.1 - t) / 0.1, 0, 1)
    return (tone + breath) * env


def vibraphone(hold: float, f: float) -> np.ndarray:
    t = seconds(hold + 1.0)
    x = bell(hold + 1.0, f, VIBES, attack=0.002) * (1 - 0.2 * (0.5 + 0.5 * np.sin(2 * np.pi * 5.0 * t)))
    return release(x, hold + 0.4, 0.6)


def music_box(f: float) -> np.ndarray:
    return bell(1.6, f, CELESTA, attack=0.0015)


def strings(hold: float, freqs, seed: int) -> np.ndarray:
    """A soft string pad: gently detuned saws through a low lowpass, slow to swell and to let go."""
    t = seconds(hold + 0.9)
    r = np.random.default_rng(seed)
    x = np.zeros_like(t)
    for f in freqs:
        for detune in (-0.0025, 0.0025):
            vib = 1 + 0.002 * np.sin(2 * np.pi * r.uniform(4.5, 5.5) * t + r.uniform(0, 6.3))
            phase = (np.cumsum(f * (1 + detune) * vib) / SR + r.random()) % 1.0
            x += 2 * phase - 1
    x = lowpass(x, 950)
    env = np.clip(t / 0.6, 0, 1) * np.clip((hold + 0.8 - t) / 0.8, 0, 1)
    return x / (np.max(np.abs(x)) + 1e-9) * env


def noise_hit(seed: int, d: float, lo: float, hi: float, attack: float, tau: float) -> np.ndarray:
    t = seconds(d)
    x = bandpass(np.random.default_rng(seed).standard_normal(len(t)), lo, hi)
    return x / (np.max(np.abs(x)) + 1e-9) * np.clip(t / attack, 0, 1) * np.exp(-t / tau)


def kick() -> np.ndarray:
    t = seconds(0.4)
    f = 48 + 40 * np.exp(-t / 0.03)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.12)


def rim(seed: int) -> np.ndarray:
    return noise_hit(seed, 0.08, 1400, 2600, 0.0008, 0.012)


def glock(f: float) -> np.ndarray:
    return bell(1.2, f, ((1.0, 1.0, 0.4), (2.76, 0.3, 0.12), (5.4, 0.1, 0.05)), attack=0.001)


def chord(names: str) -> list[float]:
    return [note(n) for n in names.split()]


def melody(text: str) -> list[tuple[int, float, float, float]]:
    """'bar beat length note; ...' (bar within the 8-bar phrase, beats from 0) -> (bar, beat, beats, hz)."""
    out = []
    for item in text.split(";"):
        bar, beat, length, name = item.split()
        out.append((int(bar), float(beat), float(length), note(name)))
    return out


# --- mixing ------------------------------------------------------------------------------------


def write_wav(path: Path, x: np.ndarray) -> None:
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(x.shape[1] if x.ndim == 2 else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def lufs(x: np.ndarray, tmp: Path) -> float:
    probe = tmp / "probe.wav"
    write_wav(probe, x / (np.max(np.abs(x)) + 1e-12) * 0.5)
    out = subprocess.run(["ffmpeg", "-nostats", "-i", str(probe), "-af", "ebur128", "-f", "null", "-"],
                         capture_output=True, text=True, check=True).stderr
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", out)[-1]) - 20 * np.log10(0.5 / (np.max(np.abs(x)) + 1e-12))


def blend(stems: dict[str, tuple[np.ndarray, float, float]], seed: int, tmp: Path) -> np.ndarray:
    """Set each stem to its loudness (LU against the tune), add its share of one room, master to TARGET_LUFS."""
    dry = None
    send = None
    for name, (x, loudness, wet) in stems.items():
        x = x * 10 ** ((loudness - lufs(x, tmp)) / 20)
        dry = x if dry is None else dry + x
        send = x * wet if send is None else send + x * wet
    mix = dry + reverb(send, 2.2, seed)
    mix = mix * 10 ** ((TARGET_LUFS - lufs(mix, tmp)) / 20)
    ceiling = 10 ** (CEILING_DB / 20)
    knee = ceiling * 0.7
    over = np.abs(mix) > knee
    mix[over] = np.sign(mix[over]) * (knee + (ceiling - knee) * np.tanh((np.abs(mix[over]) - knee) / (ceiling - knee)))
    return mix


# --- the songs ---------------------------------------------------------------------------------


def marimba(f: float, velocity: float = 1.0) -> np.ndarray:
    """A wooden bar: a round fundamental and a quick bright overtone, plus a soft mallet tick."""
    t = seconds(1.0)
    tick = lowpass(np.random.default_rng(int(f * 7)).standard_normal(len(t)), 2500) * np.exp(-t / 0.004) * 0.15
    return (bell(1.0, f, MARIMBA, attack=0.0015) + tick) * velocity


# --- the songs (new for Clean a Cat) ------------------------------------------------------------


def spa_a(tmp: Path) -> np.ndarray:
    """Warm Bubbles: a sunny spa morning. The marimba tune softly over plucked chords and bass; the tune full; a
    music box takes it up an octave; the marimba again with a glockenspiel on top."""
    s = Song(92, 4, seed=201)
    bars = [  # bass root, bass fifth, the chord the guitar picks
        ("C2", "G2", "E4 G4 C5"), ("A1", "E2", "E4 A4 C5"), ("F1", "C2", "F4 A4 C5"), ("G1", "D2", "D4 G4 B4"),
        ("C2", "G2", "E4 G4 C5"), ("E2", "B2", "E4 G#4 B4"), ("F1", "C2", "F4 A4 C5"), ("G1", "D2", "D4 F4 B4"),
    ]
    tune = melody("0 0 1 E5; 0 1 0.5 D5; 0 1.5 0.5 C5; 0 2 2 G4;"
                  "1 0 1 A4; 1 1 1 C5; 1 2 1.5 E5; 1 3.5 0.5 D5;"
                  "2 0 1.5 C5; 2 1.5 0.5 A4; 2 2 1 F4; 2 3 1 A4;"
                  "3 0 3 G4; 3 3 0.5 A4; 3 3.5 0.5 B4;"
                  "4 0 1 C5; 4 1 0.5 E5; 4 1.5 0.5 G5; 4 2 2 E5;"
                  "5 0 1 G#4; 5 1 1 B4; 5 2 1.5 E5; 5 3.5 0.5 D5;"
                  "6 0 1 C5; 6 1 1 A4; 6 2 1 C5; 6 3 1 F5;"
                  "7 0 1.5 D5; 7 1.5 0.5 B4; 7 2 2 G4")
    picks, bass, lead, kit = s.stem(), s.stem(), s.stem(), s.stem()
    for bar in range(BARS):
        root, fifth, voicing = bars[bar % 8]
        section = bar // 8
        notes = chord(voicing)
        for k, i in enumerate((0, 1, 2, 1, 2, 1, 0, 1)):
            s.put(picks, pluck(0.6, notes[i], bar * 16 + k, bright=0.4, ring=1.2) * (0.75 if k % 2 == 0 else 0.5),
                  bar, k * 0.5, pan=-0.35 + 0.1 * i, loose=0.004)
        s.put(bass, upright(1.4, note(root), 0.9), bar, 0.0)
        s.put(bass, upright(1.35, note(fifth), 0.7), bar, 2.0)  # held to the bar line, so the seam stays level
        for k in range(8):
            s.put(kit, noise_hit(bar * 8 + k, 0.09, 5000, 11000, 0.01, 0.025), bar, k * 0.5, pan=0.35,
                  gain=0.45 if k % 2 == 1 else 0.3)
        for beat in (1, 3):
            s.put(kit, rim(bar * 4 + beat + 900), bar, beat, pan=-0.25, gain=0.4)
        for b, beat, length, f in tune:  # section 0 plays the tune softly, so the loop's seam stays level
            if b == bar % 8:
                if section == 2:
                    s.put(lead, music_box(f * 2) * 0.8, bar, beat, pan=0.15)
                else:
                    s.put(lead, marimba(f, 0.5 if section == 0 else 0.9), bar, beat, pan=0.1)
                    if section == 3:
                        s.put(lead, glock(f * 2) * 0.22, bar, beat, pan=0.3)
        if bar % 8 == 7:  # a few bubbles rise into the next phrase
            for k, name in enumerate(("G5", "C6", "E6")):
                s.put(lead, glock(note(name)) * 0.3, bar, 2.5 + 0.5 * k, pan=0.35)
    return blend({"lead": (lead, -20, 0.3), "picks": (picks, -23, 0.25), "bass": (bass, -25, 0.05),
                  "kit": (kit, -34, 0.1)}, 211, tmp)


def spa_b(tmp: Path) -> np.ndarray:
    """Fluff and Fold: a slow, warm afternoon. Piano and bass with brushes; the flute tune; the vibraphone answers;
    the flute again with the guitar picking under it."""
    s = Song(80, 4, seed=301, swing=0.06)
    bars = [  # bass root, bass fifth, piano voicing
        ("F2", "C3", "A3 C4 E4 G4"), ("D2", "A2", "A3 C4 F4 A4"), ("Bb2", "F2", "A3 D4 F4 A4"), ("C3", "G2", "Bb3 E4 G4"),
        ("A2", "E3", "G3 C4 E4"), ("D2", "A2", "A3 C4 F4"), ("G2", "D3", "F3 Bb3 D4"), ("C3", "G2", "E3 G3 Bb3 C4"),
    ]
    tune = melody("0 0 1.5 C5; 0 1.5 0.5 A4; 0 2 2 F4;"
                  "1 0 1 A4; 1 1 1 C5; 1 2 2 F5;"
                  "2 0 1.5 D5; 2 1.5 0.5 C5; 2 2 1 Bb4; 2 3 1 A4;"
                  "3 0 3 G4; 3 3 1 C5;"
                  "4 0 1.5 E5; 4 1.5 0.5 D5; 4 2 2 C5;"
                  "5 0 1 A4; 5 1 1 C5; 5 2 1.5 F5; 5 3.5 0.5 E5;"
                  "6 0 1 D5; 6 1 1 Bb4; 6 2 2 G4;"
                  "7 0 2 C5; 7 2 1 Bb4; 7 3 1 G4")
    keys, bass, lead, guitar, kit = s.stem(), s.stem(), s.stem(), s.stem(), s.stem()
    for bar in range(BARS):
        root, fifth, voicing = bars[bar % 8]
        section = bar // 8
        notes = chord(voicing)
        for i, f in enumerate(notes):
            s.put(keys, epiano(1.8, f, 0.65), bar, 0.0, pan=-0.3 + 0.15 * i, loose=0.004)
        for i, f in enumerate(notes):
            s.put(keys, epiano(1.0, f, 0.4), bar, 2.5, pan=-0.3 + 0.15 * i, loose=0.004)
        s.put(bass, upright(1.6, note(root), 1.0), bar, 0.0)
        s.put(bass, upright(1.2, note(fifth), 0.75), bar, 2.0)
        for beat in range(4):
            s.put(kit, noise_hit(bar * 8 + beat + 500, 0.4, 2500, 9000, 0.04, 0.1), bar, beat, pan=0.2, gain=0.45)
            if beat in (1, 3):
                s.put(kit, noise_hit(bar * 8 + beat + 600, 0.2, 1200, 5000, 0.002, 0.05), bar, beat, pan=-0.1,
                      gain=0.7)
        if section == 3:
            for k, i in enumerate((0, 1, 2, 1, 0, 1, 2, 1)):
                f = notes[min(i, len(notes) - 1)] * 2
                s.put(guitar, pluck(0.5, f, bar * 8 + k + 700, bright=0.3), bar, k * 0.5, pan=0.4)
        if section in (1, 2, 3):
            for b, beat, length, f in tune:
                if b == bar % 8:
                    if section == 2:
                        s.put(lead, vibraphone(length * s.beat, f), bar, beat, pan=0.1)
                    else:
                        s.put(lead, flute(length * s.beat * 0.9, f, bar * 10 + int(beat * 2) + 800), bar, beat,
                              pan=0.1)
    return blend({"lead": (lead, -20, 0.3), "keys": (keys, -23, 0.25), "bass": (bass, -24, 0.05),
                  "guitar": (guitar, -24, 0.25), "kit": (kit, -32, 0.15)}, 311, tmp)


SONGS = {"SpaA": spa_a, "SpaB": spa_b}


def encode(wav: Path, out: Path, codec: list[str]) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-ar", str(SR), *codec,
                    "-fflags", "+bitexact", "-flags:a", "+bitexact", "-serial_offset", "0", str(out)], check=True)


def preview(rendered: dict[str, np.ndarray], folder: Path, tmp: Path) -> Path:
    length, fade = int(40 * SR), int(2 * SR)
    track = np.zeros((0, 2))
    for x in rendered.values():
        part = x[:length].copy()
        part[-fade:] *= np.linspace(1, 0, fade)[:, None]
        track = np.concatenate([track, part, np.zeros((SR, 2))])
    wav = tmp / "preview.wav"
    write_wav(wav, track)
    out = folder / "clean-a-cat-music-preview.mp3"
    encode(wav, out, ["-c:a", "libmp3lame", "-q:a", "2"])
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", help="comma list of names, e.g. SpaA")
    parser.add_argument("--preview", help="folder for a listening preview mp3")
    args = parser.parse_args()
    names = list(SONGS) if not args.only else [n.strip() for n in args.only.split(",")]
    unknown = [n for n in names if n not in SONGS]
    if unknown:
        print(f"music: unknown song(s) {', '.join(unknown)}; known: {', '.join(SONGS)}", file=sys.stderr)
        return 2
    rendered: dict[str, np.ndarray] = {}
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        for name in names:
            x = SONGS[name](tmp)
            rendered[name] = x
            wav = tmp / f"{name}.wav"
            write_wav(wav, x)
            out = ROOT / "music" / f"CleanACat_Music_{name}.ogg"
            encode(wav, out, ["-c:a", "libvorbis", "-q:a", "5"])
            print(f"music: {out.relative_to(ROOT.parents[2]).as_posix()}  {len(x) / SR:.1f} s")
        if args.preview:
            folder = Path(args.preview)
            folder.mkdir(parents=True, exist_ok=True)
            print(f"music: preview {preview(rendered, folder, tmp).as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
