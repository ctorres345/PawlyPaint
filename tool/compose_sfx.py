"""Synthesizes PawlyPaint's short sound effects (no samples, no third-party
audio). Writes 16-bit mono WAV files.
Run: python3 tool/compose_sfx.py assets/sfx
"""
import math
import random
import struct
import sys
import wave

SR = 22050
rng = random.Random(3)


def write(path, samples, peak=0.8):
    m = max(abs(s) for s in samples) or 1
    k = peak / m
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(s * k * 32767)) for s in samples))


def bell(f, dur, decay=6.0):
    out = []
    for i in range(int(dur * SR)):
        t = i / SR
        s = (math.sin(2 * math.pi * f * t) + 0.4 * math.sin(2 * math.pi * f * 2.76 * t) * math.exp(-8 * t)
             + 0.2 * math.sin(2 * math.pi * f * 5.4 * t) * math.exp(-14 * t))
        out.append(s * math.exp(-decay * t) * min(1, t / 0.003))
    return out


def mix(*parts):
    n = max(off + len(p) for off, p in parts)
    out = [0.0] * n
    for off, p in parts:
        for i, s in enumerate(p):
            out[off + i] += s
    return out


def at(seconds):
    return int(seconds * SR)


def place():
    # A soft glassy tick, like a drill clicking onto the canvas.
    tick = bell(2200, 0.07, decay=60)
    click = [rng.uniform(-1, 1) * math.exp(-400 * i / SR) * 0.4 for i in range(at(0.01))]
    return mix((0, tick), (0, click))


def land():
    # A gentle "plip" for a bead flying into its spot.
    out = []
    for i in range(at(0.09)):
        t = i / SR
        f = 900 + 900 * t / 0.09
        out.append(math.sin(2 * math.pi * f * t) * math.exp(-35 * t) * min(1, t / 0.002))
    return out


def color_done():
    return mix((0, bell(1318.5, 0.6, 5)), (at(0.09), bell(1975.5, 0.6, 5)))


def complete():
    notes = [1046.5, 1318.5, 1568.0, 2093.0]
    parts = [(at(i * 0.11), bell(f, 1.1, 3.5)) for i, f in enumerate(notes)]
    sparkle = [(at(0.5 + i * 0.05), bell(3136 + i * 400, 0.25, 12)) for i in range(4)]
    return mix(*parts, *sparkle)


def wrong():
    out = []
    for i in range(at(0.16)):
        t = i / SR
        f = 220 - 60 * t / 0.16
        out.append(math.sin(2 * math.pi * f * t) * math.exp(-18 * t) * min(1, t / 0.004))
    return out


def shake():
    out = []
    for i in range(at(0.35)):
        t = i / SR
        burst = 0.5 + 0.5 * math.sin(2 * math.pi * 22 * t)
        out.append(rng.uniform(-1, 1) * burst * math.exp(-5 * t) * 0.6)
    # Soften the hiss with a one-pole low-pass.
    y, smooth = 0.0, []
    for s in out:
        y += 0.25 * (s - y)
        smooth.append(y)
    return smooth


if __name__ == '__main__':
    d = sys.argv[1]
    for name, fn in [('place', place), ('land', land), ('color', color_done), ('complete', complete),
                     ('wrong', wrong), ('shake', shake)]:
        write(f'{d}/{name}.wav', fn())
        print(name)
