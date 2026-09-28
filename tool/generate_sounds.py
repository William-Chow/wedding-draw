#!/usr/bin/env python3
"""Synthesizes the app's sound effects into assets/sounds/.

Uses only the Python standard library, and a fixed random seed so the output
is reproducible. Run it from anywhere:

    python3 tool/generate_sounds.py
"""

import math
import os
import random
import sys
import wave
from array import array

RATE = 22050  # Samples per second; plenty for these short effects.
OUT_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds")
)


def write_wav(name, samples, peak):
    """Normalizes samples to the given peak level and writes 16-bit mono WAV."""
    loudest = max(abs(s) for s in samples) or 1.0
    scale = peak * 32767 / loudest
    data = array("h", (int(round(s * scale)) for s in samples))
    if sys.byteorder == "big":
        data.byteswap()  # WAV data is little-endian.
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data.tobytes())
    print(f"{path}: {len(samples) / RATE:.2f} s, {os.path.getsize(path) / 1024:.1f} KiB")


def fade_out(samples, seconds):
    """Ramps the last few samples down to silence to avoid a click."""
    count = int(seconds * RATE)
    for i in range(count):
        samples[len(samples) - 1 - i] *= i / count


def snare_hit(rng, length=0.12):
    """One snare stroke: band-passed noise plus a short drum-head tone."""
    low_pass = math.exp(-2 * math.pi * 6000 / RATE)
    high_pass = math.exp(-2 * math.pi * 900 / RATE)
    lp = hp = previous = 0.0
    samples = []
    for i in range(int(RATE * length)):
        t = i / RATE
        lp = (1 - low_pass) * rng.uniform(-1, 1) + low_pass * lp
        hp = high_pass * (hp + lp - previous)
        previous = lp
        attack = min(1.0, t / 0.0015)
        noise = hp * math.exp(-t / 0.035)
        tone = math.sin(2 * math.pi * 185 * t) * math.exp(-t / 0.018)
        samples.append(attack * (0.9 * noise + 0.35 * tone))
    return samples


def drum_roll(duration=1.2, strokes_per_second=20):
    """A snare roll that loops seamlessly: stroke tails wrap around the end."""
    rng = random.Random(7)
    length = int(RATE * duration)
    samples = [0.0] * length
    strokes = int(duration * strokes_per_second)
    for k in range(strokes):
        start = int(k * length / strokes + rng.uniform(-0.003, 0.003) * RATE)
        accent = 1.0 if k % 2 == 0 else 0.8  # Alternating sticks.
        level = accent * rng.uniform(0.85, 1.0)
        for i, value in enumerate(snare_hit(rng)):
            samples[(start + i) % length] += level * value
    return samples


def reel_stop(duration=0.16):
    """A short wooden clack with a low thump, for a reel locking in place."""
    rng = random.Random(11)
    samples = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        thump = math.sin(2 * math.pi * 95 * t) * math.exp(-t / 0.05)
        wood = (
            math.sin(2 * math.pi * 820 * t)
            + 0.5 * math.sin(2 * math.pi * 1640 * t + 0.3)
            + 0.25 * math.sin(2 * math.pi * 2460 * t)
        ) * math.exp(-t / 0.022)
        click = rng.uniform(-1, 1) * math.exp(-t / 0.002)
        attack = min(1.0, t / 0.0008)
        samples.append(attack * (0.8 * thump + 0.6 * wood + 0.5 * click))
    fade_out(samples, 0.01)
    return samples


def chime(duration=2.4):
    """A bright C-major arpeggio of bell-like tones for the reveal."""
    notes = [(1046.50, 0.00), (1318.51, 0.10), (1567.98, 0.20), (2093.00, 0.30)]
    # (frequency ratio, level, decay time in seconds) of each overtone.
    partials = [(1.0, 1.0, 1.4), (2.0, 0.45, 0.7), (3.0, 0.2, 0.45), (4.16, 0.1, 0.3)]
    length = int(RATE * duration)
    samples = [0.0] * length
    for frequency, start in notes:
        first = int(start * RATE)
        for i in range(first, length):
            t = (i - first) / RATE
            value = 0.0
            for ratio, level, decay in partials:
                if frequency * ratio < 0.45 * RATE:  # Stay below Nyquist.
                    value += level * math.sin(2 * math.pi * frequency * ratio * t) * math.exp(-t / decay)
            samples[i] += min(1.0, t / 0.004) * value
    fade_out(samples, 0.08)
    return samples


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    write_wav("drum_roll.wav", drum_roll(), peak=0.6)
    write_wav("reel_stop.wav", reel_stop(), peak=0.8)
    write_wav("chime.wav", chime(), peak=0.85)


if __name__ == "__main__":
    main()
