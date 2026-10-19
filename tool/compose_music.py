"""Composes PawlyPaint's four music loops from scratch (no samples, no
third-party material), so they are free of copyright concerns.

Writes 16-bit mono WAV files; each track is a whole number of bars and its
release tails wrap around to the start, so it loops seamlessly.
"""
import math
import random
import struct
import sys
import wave

SR = 24000


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


class Track:
    def __init__(self, bpm, bars, beats_per_bar=4):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.length = int(round(bars * beats_per_bar * self.beat * SR))
        self.buf = [0.0] * self.length

    def add(self, start_beat, samples, gain):
        i0 = int(round(start_beat * self.beat * SR))
        n = self.length
        buf = self.buf
        for k, s in enumerate(samples):
            buf[(i0 + k) % n] += s * gain

    def note(self, start_beat, beats, midi, voice, gain=0.2):
        dur = beats * self.beat
        self.add(start_beat, voice(midi_hz(midi), dur), gain)

    def drum(self, start_beat, kind, gain=0.2):
        self.add(start_beat, DRUMS[kind](), gain)

    def write(self, path, master=0.9):
        peak = max(abs(x) for x in self.buf) or 1.0
        scale = master / peak
        with wave.open(path, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x * scale)) * 32767)) for x in self.buf))


# ---- Voices (all simple additive / subtractive synthesis) -----------------

def env(t, dur, a=0.01, r=0.25):
    if t < a:
        return t / a
    if t > dur:
        return max(0.0, 1 - (t - dur) / r)
    return 1.0


def music_box(f, dur):
    total = dur + 1.2
    out = []
    for i in range(int(total * SR)):
        t = i / SR
        d = math.exp(-3.2 * t)
        s = math.sin(2 * math.pi * f * t) + 0.35 * math.sin(2 * math.pi * f * 3.01 * t) * math.exp(-6 * t)
        out.append(s * d * min(1, t / 0.004))
    return out


def e_piano(f, dur):
    total = dur + 0.6
    out = []
    for i in range(int(total * SR)):
        t = i / SR
        mod = math.sin(2 * math.pi * f * 2 * t) * 1.2 * math.exp(-5 * t)
        s = math.sin(2 * math.pi * f * t + mod)
        out.append(s * math.exp(-1.6 * t) * env(t, dur, 0.005, 0.5))
    return out


def soft_pad(f, dur):
    total = dur + 0.8
    out = []
    for i in range(int(total * SR)):
        t = i / SR
        s = (math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 1.003 * t)
             + 0.25 * math.sin(2 * math.pi * f * 2 * t))
        out.append(s * env(t, dur, 0.4, 0.8))
    return out


def triangle(f, dur):
    total = dur + 0.08
    out = []
    for i in range(int(total * SR)):
        t = i / SR
        ph = (f * t) % 1.0
        s = 4 * abs(ph - 0.5) - 1
        out.append(s * env(t, dur, 0.005, 0.08) * (0.75 + 0.25 * math.exp(-4 * t)))
    return out


def soft_square(f, dur):
    total = dur + 0.08
    out = []
    for i in range(int(total * SR)):
        t = i / SR
        # Square approximated with three odd harmonics: rounder than a real square.
        vib = 1 + 0.004 * math.sin(2 * math.pi * 5.5 * t) * min(1, t / 0.2)
        s = sum(math.sin(2 * math.pi * f * vib * h * t) / h for h in (1, 3, 5))
        out.append(s * 0.7 * env(t, dur, 0.01, 0.08) * (0.7 + 0.3 * math.exp(-3 * t)))
    return out


def bass(f, dur):
    total = dur + 0.06
    out = []
    for i in range(int(total * SR)):
        t = i / SR
        s = math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 2 * t)
        out.append(s * env(t, dur * 0.9, 0.005, 0.06))
    return out


def pluck_bass(f, dur):
    total = dur + 0.05
    out = []
    for i in range(int(total * SR)):
        t = i / SR
        s = math.sin(2 * math.pi * f * t + 0.8 * math.sin(2 * math.pi * f * t) * math.exp(-8 * t))
        out.append(s * math.exp(-3 * t) * env(t, dur, 0.003, 0.05))
    return out


_rng = random.Random(7)
_NOISE = [_rng.uniform(-1, 1) for _ in range(SR)]


def kick():
    out = []
    for i in range(int(0.3 * SR)):
        t = i / SR
        f = 45 + 70 * math.exp(-30 * t)
        out.append(math.sin(2 * math.pi * f * t) * math.exp(-9 * t))
    return out


def hat():
    out, prev = [], 0.0
    for i in range(int(0.06 * SR)):
        n = _NOISE[i]
        hp = n - prev
        prev = n
        out.append(hp * 0.5 * math.exp(-60 * i / SR))
    return out


def snare():
    out = []
    for i in range(int(0.18 * SR)):
        t = i / SR
        out.append(_NOISE[i + 100] * 0.6 * math.exp(-22 * t) + 0.4 * math.sin(2 * math.pi * 190 * t) * math.exp(-30 * t))
    return out


def shaker():
    out = []
    for i in range(int(0.08 * SR)):
        t = i / SR
        out.append(_NOISE[i + 500] * 0.4 * math.sin(math.pi * t / 0.08))
    return out


DRUMS = {'kick': kick, 'hat': hat, 'snare': snare, 'shaker': shaker}


# ---- Composition helpers ---------------------------------------------------

def melody(rng, chords, steps_per_bar, scale, start, low, high, rest=0.25):
    """A gentle stepwise melody that leans on chord tones on strong beats."""
    notes = []
    cur = start
    for bar, chord in enumerate(chords):
        for step in range(steps_per_bar):
            strong = step % (steps_per_bar // 2) == 0
            if not strong and rng.random() < rest:
                continue
            if strong:
                tones = [n for n in range(low, high + 1) if n % 12 in [c % 12 for c in chord]]
                cur = min(tones, key=lambda n: abs(n - cur) + rng.random() * 2)
            else:
                cands = [n for n in range(cur - 3, cur + 4) if low <= n <= high and n % 12 in scale]
                cur = rng.choice(cands) if cands else cur
            notes.append((bar, step, cur))
    return notes


MAJOR = [0, 2, 4, 5, 7, 9, 11]
DORIAN = [0, 2, 3, 5, 7, 9, 10]


def menu():
    t = Track(bpm=84, bars=16)
    rng = random.Random(11)
    prog = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]] * 4  # C Am F G
    for bar, ch in enumerate(prog):
        b0 = bar * 4
        for n in ch:
            t.note(b0, 4, n - 12, soft_pad, 0.05)
        t.note(b0, 2, ch[0] - 24, bass, 0.12)
        t.note(b0 + 2, 2, ch[0] - 24 + 7, bass, 0.1)
        for k, n in enumerate([ch[0], ch[1], ch[2], ch[1] + 12, ch[2], ch[1], ch[0] + 12, ch[2]]):
            t.note(b0 + k * 0.5, 0.5, n + 12, music_box, 0.06)
    for bar, step, n in melody(rng, prog, 4, MAJOR, 76, 72, 84, rest=0.35):
        if bar % 4 == 3 and step > 1:
            continue
        t.note(bar * 4 + step, 1, n, music_box, 0.11)
    return t


def chill():
    t = Track(bpm=76, bars=16)
    rng = random.Random(21)
    prog = [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59]] * 4  # Fmaj7 Em7 Dm7 Cmaj7
    for bar, ch in enumerate(prog):
        b0 = bar * 4
        for k, at in enumerate([0, 1.5, 2.5]):
            for n in ch:
                t.note(b0 + at, 1 if k == 0 else 0.75, n, e_piano, 0.045)
        t.note(b0, 1.5, ch[0] - 12, bass, 0.16)
        t.note(b0 + 2, 1, ch[0] - 12 + 7, bass, 0.12)
        t.note(b0 + 3, 1, ch[0] - 12 + 5, bass, 0.1)
        t.drum(b0, 'kick', 0.22)
        t.drum(b0 + 2.5, 'kick', 0.16)
        t.drum(b0 + 1, 'snare', 0.07)
        t.drum(b0 + 3, 'snare', 0.07)
        for h in range(8):
            t.drum(b0 + h * 0.5 + (0.08 if h % 2 else 0), 'hat', 0.05)
    for bar, step, n in melody(rng, prog, 4, MAJOR, 72, 67, 81, rest=0.45):
        if bar % 2 == 1 and step == 3:
            continue
        t.note(bar * 4 + step, 1, n, triangle, 0.07)
    return t


def fever():
    t = Track(bpm=128, bars=24)
    rng = random.Random(31)
    prog = [[50, 53, 57, 60], [55, 59, 62, 65], [48, 52, 55, 59], [57, 61, 64, 67]] * 6  # Dm7 G7 Cmaj7 A7
    for bar, ch in enumerate(prog):
        b0 = bar * 4
        for at in [0.5, 1.5, 2.5, 3.5]:
            for n in ch[1:]:
                t.note(b0 + at, 0.35, n, soft_square, 0.022)
        for k, (at, off) in enumerate([(0, 0), (0.75, 12), (1.5, 7), (2, 0), (2.75, 12), (3.5, 10)]):
            t.note(b0 + at, 0.4, ch[0] - 12 + off, pluck_bass, 0.17)
        t.drum(b0, 'kick', 0.2)
        t.drum(b0 + 2, 'kick', 0.2)
        t.drum(b0 + 1, 'snare', 0.09)
        t.drum(b0 + 3, 'snare', 0.09)
        for h in range(8):
            t.drum(b0 + h * 0.5, 'shaker', 0.05)
    for bar, step, n in melody(rng, prog, 8, DORIAN, 74, 69, 84, rest=0.3):
        t.note(bar * 4 + step * 0.5, 0.45, n, soft_square, 0.075)
    return t


def hip():
    t = Track(bpm=96, bars=16)
    rng = random.Random(41)
    prog = [[57, 60, 64, 67], [57, 60, 64, 67], [50, 53, 57, 60], [52, 56, 59, 62]] * 4  # Am7 Am7 Dm7 E7
    swing = lambda x: x + (0.17 if (x * 2) % 2 == 1 else 0)
    for bar, ch in enumerate(prog):
        b0 = bar * 4
        for at in [0, 1.5, 3]:
            for n in ch:
                t.note(b0 + swing(at), 0.4, n, e_piano, 0.04)
        line = [(0, 0), (0.5, 0), (1.5, 12), (2, 10), (2.5, 7), (3, 5), (3.5, 3)]
        for at, off in line:
            t.note(b0 + swing(at), 0.4, ch[0] - 12 + off, pluck_bass, 0.17)
        t.drum(b0, 'kick', 0.22)
        t.drum(b0 + swing(1.5), 'kick', 0.15)
        t.drum(b0 + 2.5, 'kick', 0.18)
        t.drum(b0 + 1, 'snare', 0.1)
        t.drum(b0 + 3, 'snare', 0.1)
        for h in range(8):
            t.drum(b0 + swing(h * 0.5), 'hat', 0.06 if h % 2 == 0 else 0.035)
    for bar, step, n in melody(rng, prog, 8, DORIAN, 69, 64, 81, rest=0.5):
        t.note(bar * 4 + swing(step * 0.5), 0.45, n, triangle, 0.08)
    return t


if __name__ == '__main__':
    out = sys.argv[1]
    for name, fn in [('menu', menu), ('chill', chill), ('fever', fever), ('hip', hip)]:
        track = fn()
        track.write(f'{out}/{name}.wav')
        print(name, round(track.length / SR, 1), 's')
