"""Composes PawlyPaint's four music loops from scratch (no samples, no
third-party material), so they are free of copyright concerns.

Writes 16-bit stereo WAV files; each track is a whole number of bars and its
release, delay and reverb tails wrap around to the start, so it loops
seamlessly. Melodies are built from repeated motifs on the major pentatonic
scale, so they sound like tunes rather than wandering notes, and every voice
is layered, detuned and sent through a room reverb so the mix sounds warm
instead of thin.
"""
import math
import random
import struct
import sys
import wave

SR = 32000
TWO_PI = 2 * math.pi


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


class Track:
    def __init__(self, bpm, bars, beats_per_bar=4, swing=0.0):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.swing = swing
        self.length = int(round(bars * beats_per_bar * self.beat * SR))
        self.left = [0.0] * self.length
        self.right = [0.0] * self.length

    def time(self, beat):
        """Beat position with swing: every off-eighth is pushed late."""
        if self.swing and (beat * 2) % 2 == 1:
            beat += self.swing
        return beat

    def add(self, start_beat, samples, gain, pan=0.0):
        i0 = int(round(self.time(start_beat) * self.beat * SR))
        n = self.length
        a = (pan + 1) * math.pi / 4
        gl, gr = gain * math.cos(a), gain * math.sin(a)
        left, right = self.left, self.right
        for k, s in enumerate(samples):
            j = (i0 + k) % n
            left[j] += s * gl
            right[j] += s * gr

    def note(self, start_beat, beats, midi, voice, gain=0.2, pan=0.0, echo=None):
        """Plays one note. echo=(beats, gain, repeats) adds a ping-pong delay."""
        dur = beats * self.beat
        samples = voice(midi_hz(midi), dur)
        self.add(start_beat, samples, gain, pan)
        if echo:
            delay, egain, reps = echo
            for r in range(1, reps + 1):
                self.add(start_beat + delay * r, samples, gain * egain ** r, -pan if r % 2 else pan)

    def drum(self, start_beat, kind, gain=0.2, pan=0.0):
        self.add(start_beat, DRUMS[kind](), gain, pan)

    def finish(self, reverb_mix=0.22):
        self.left = reverb(self.left, reverb_mix, 0)
        self.right = reverb(self.right, reverb_mix, 23)

    def write(self, path, master=0.89):
        peak = max(max(abs(x) for x in self.left), max(abs(x) for x in self.right)) or 1.0
        scale = master / peak
        frames = bytearray()
        for l, r in zip(self.left, self.right):
            frames += struct.pack('<hh', int(soft_clip(l * scale) * 32767), int(soft_clip(r * scale) * 32767))
        with wave.open(path, 'wb') as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(bytes(frames))


def soft_clip(x):
    return math.tanh(x * 1.1) / math.tanh(1.1)


def reverb(buf, mix, offset):
    """Schroeder room reverb run twice around the loop so its tail wraps."""
    n = len(buf)
    combs = [int(c * SR / 44100) + offset for c in (1557, 1617, 1491, 1422)]
    allpasses = [int(a * SR / 44100) for a in (225, 556)]
    wet = [0.0] * n
    cbuf = [[0.0] * c for c in combs]
    cfilt = [0.0] * len(combs)
    abuf = [[0.0] * a for a in allpasses]
    for p in range(2):
        for i in range(n):
            x = buf[i] * 0.35
            acc = 0.0
            for k, c in enumerate(combs):
                j = i % c
                y = cbuf[k][j]
                cfilt[k] = y * 0.55 + cfilt[k] * 0.45
                cbuf[k][j] = x + cfilt[k] * 0.82
                acc += y
            for k, a in enumerate(allpasses):
                j = i % a
                y = abuf[k][j]
                abuf[k][j] = acc + y * 0.5
                acc = y - acc * 0.5
            if p == 1:
                wet[i] = acc
    return [d * (1 - mix * 0.5) + w * mix for d, w in zip(buf, wet)]


# ---- Voices (all simple additive / subtractive / physical synthesis) -------

def env(t, dur, a=0.01, r=0.25):
    if t < a:
        return t / a
    if t > dur:
        return max(0.0, 1 - (t - dur) / r)
    return 1.0


_noise_rng = random.Random(7)
_NOISE = [_noise_rng.uniform(-1, 1) for _ in range(SR)]
_pluck_rng = random.Random(3)


def pluck(f, dur):
    """Karplus-Strong string: a nylon guitar / harp kind of pluck."""
    n = max(2, int(SR / f))
    ring = [_pluck_rng.uniform(-1, 1) for _ in range(n)]
    # Soften the burst so the attack is a fingertip, not a pick.
    for _ in range(2):
        ring = [(ring[i] + ring[i - 1]) / 2 for i in range(n)]
    total = dur + 1.4
    out = []
    damp = 0.9975 if f < 300 else 0.996
    for k in range(int(total * SR)):
        j = k % n
        s = ring[j]
        ring[j] = damp * (s + ring[(j + 1) % n]) / 2
        out.append(s * (1 if k > 20 else k / 20))
    return out


def music_box(f, dur):
    total = dur + 1.2
    out = []
    for i in range(int(total * SR)):
        t = i / SR
        d = math.exp(-3.0 * t)
        s = math.sin(TWO_PI * f * t) + 0.25 * math.sin(TWO_PI * f * 4 * t) * math.exp(-7 * t)
        out.append(s * d * min(1, t / 0.004))
    return out


def rhodes(f, dur):
    """FM electric piano, two slightly detuned layers for a chorused body."""
    total = dur + 0.9
    out = []
    for i in range(int(total * SR)):
        t = i / SR
        s = 0.0
        for det in (0.9985, 1.0015):
            ff = f * det
            mod = math.sin(TWO_PI * ff * 2 * t) * 1.0 * math.exp(-4 * t)
            s += math.sin(TWO_PI * ff * t + mod)
        tine = 0.12 * math.sin(TWO_PI * f * 7 * t) * math.exp(-12 * t)
        out.append((s * 0.5 + tine) * math.exp(-1.3 * t) * env(t, dur, 0.004, 0.6))
    return out


def warm_pad(f, dur):
    """Detuned, low-passed saw pad that slowly opens up."""
    total = dur + 1.2
    out = []
    for i in range(int(total * SR)):
        t = i / SR
        bright = 1.5 + 2.5 * min(1, t / 1.5)
        s = 0.0
        for det in (0.996, 1.0, 1.004):
            ff = f * det
            for h in range(1, 7):
                s += math.sin(TWO_PI * ff * h * t) / h * math.exp(-h / bright)
        out.append(s / 3 * env(t, dur, 0.5, 1.2))
    return out


def vibes(f, dur):
    total = dur + 1.6
    out = []
    for i in range(int(total * SR)):
        t = i / SR
        trem = 1 - 0.18 * (1 - math.cos(TWO_PI * 4.5 * t)) / 2
        s = math.sin(TWO_PI * f * t) * math.exp(-1.8 * t) + 0.3 * math.sin(TWO_PI * f * 4 * t) * math.exp(-6 * t)
        out.append(s * trem * min(1, t / 0.003))
    return out


def flute(f, dur):
    """Breathy, soft lead with a touch of vibrato."""
    total = dur + 0.25
    out = []
    for i in range(int(total * SR)):
        t = i / SR
        vib = 1 + 0.006 * math.sin(TWO_PI * 5 * t) * min(1, max(0, t - 0.15) / 0.3)
        s = math.sin(TWO_PI * f * vib * t) + 0.25 * math.sin(TWO_PI * f * vib * 2 * t) + 0.08 * math.sin(TWO_PI * f * vib * 3 * t)
        breath = _NOISE[i % SR] * 0.015
        out.append((s + breath) * env(t, dur, 0.06, 0.2))
    return out


def bass(f, dur):
    total = dur + 0.1
    out = []
    for i in range(int(total * SR)):
        t = i / SR
        s = math.sin(TWO_PI * f * t) + 0.35 * math.sin(TWO_PI * f * 2 * t) * math.exp(-2 * t) + 0.12 * math.sin(TWO_PI * f * 3 * t) * math.exp(-4 * t)
        out.append(s * env(t, dur * 0.9, 0.006, 0.1))
    return out


def pluck_bass(f, dur):
    total = dur + 0.08
    out = []
    for i in range(int(total * SR)):
        t = i / SR
        s = math.sin(TWO_PI * f * t + 0.7 * math.sin(TWO_PI * f * t) * math.exp(-7 * t))
        s += 0.2 * math.sin(TWO_PI * f * 2 * t) * math.exp(-5 * t)
        out.append(s * math.exp(-2.5 * t) * env(t, dur, 0.003, 0.08))
    return out


def kick():
    out = []
    for i in range(int(0.3 * SR)):
        t = i / SR
        f = 48 + 60 * math.exp(-28 * t)
        out.append(math.sin(TWO_PI * f * t) * math.exp(-9 * t))
    return out


def brush():
    """A soft, low-passed hi-hat: more brush than cymbal."""
    out, lp = [], 0.0
    for i in range(int(0.07 * SR)):
        lp = lp * 0.6 + _NOISE[i] * 0.4
        out.append((_NOISE[i] - lp) * 0.6 * math.exp(-55 * i / SR))
    return out


def snap():
    """A gentle rim / finger snap instead of a cracking snare."""
    out = []
    for i in range(int(0.14 * SR)):
        t = i / SR
        out.append(_NOISE[i + 100] * 0.45 * math.exp(-30 * t) + 0.35 * math.sin(TWO_PI * 210 * t) * math.exp(-40 * t))
    return out


def shaker():
    out = []
    for i in range(int(0.08 * SR)):
        t = i / SR
        out.append(_NOISE[i + 500] * 0.35 * math.sin(math.pi * t / 0.08))
    return out


DRUMS = {'kick': kick, 'brush': brush, 'snap': snap, 'shaker': shaker}


# ---- Composition helpers ---------------------------------------------------

PENTATONIC = [0, 2, 4, 7, 9]


def snap_to(n, allowed, low, high):
    """Nearest pitch to n whose pitch class is in allowed, within the range."""
    cands = [m for m in range(low, high + 1) if m % 12 in allowed]
    return min(cands, key=lambda m: abs(m - n))


def motif_melody(rng, chords, steps_per_bar, low, high, density=0.6, scale=PENTATONIC):
    """A tune made of a two-bar motif (A), a contrasting one (B) and a
    closing one (A'), laid out A A B A' over every eight bars. Strong beats
    land on chord tones, the rest follows the motif's contour on the
    pentatonic scale, and each eight-bar section closes on the chord root."""
    def make_motif():
        steps = steps_per_bar * 2
        rhythm = []
        s = 0
        while s < steps:
            if s % (steps_per_bar // 2) == 0 or rng.random() < density:
                length = rng.choice([1, 1, 2]) if s % 2 == 0 else 1
                rhythm.append((s, min(length, steps - s)))
                s += length
            else:
                s += 1
        contour = [rng.choice([-2, -1, -1, 0, 1, 1, 2]) for _ in rhythm]
        return rhythm, contour

    motifs = {'A': make_motif(), 'B': make_motif()}
    notes = []
    cur = (low + high) // 2
    bars = len(chords)
    for chunk in range(bars // 2):
        kind = 'B' if chunk % 4 == 2 else 'A'
        rhythm, contour = motifs[kind]
        closing = chunk % 4 == 3
        for idx, ((step, length), move) in enumerate(zip(rhythm, contour)):
            bar = chunk * 2 + step // steps_per_bar
            sub = step % steps_per_bar
            chord = chords[bar]
            strong = sub % (steps_per_bar // 2) == 0
            if closing and idx == len(rhythm) - 1:
                cur = snap_to(cur, [chord[0] % 12, chord[1] % 12], low, high)
                length = max(length, steps_per_bar // 2)
            elif strong:
                cur = snap_to(cur + move, [c % 12 for c in chord], low, high)
            else:
                cur = snap_to(cur + move * 2, scale, low, high)
            if closing and idx == len(rhythm) - 1 and step > steps_per_bar:
                pass
            notes.append((bar, sub, length, cur))
    return notes


def menu():
    """A gentle lullaby: harp arpeggios over a warm pad, music-box tune."""
    t = Track(bpm=84, bars=16)
    rng = random.Random(11)
    prog = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]] * 4  # C Am F G
    for bar, ch in enumerate(prog):
        b0 = bar * 4
        for n in ch:
            t.note(b0, 4, n - 12, warm_pad, 0.035, pan=0.0)
        t.note(b0, 2, ch[0] - 24, bass, 0.14)
        t.note(b0 + 2, 2, ch[0] - 24 + 7, bass, 0.1)
        arp = [ch[0], ch[1], ch[2], ch[1] + 12, ch[2], ch[1], ch[0] + 12, ch[2]]
        for k, n in enumerate(arp):
            t.note(b0 + k * 0.5, 0.5, n, pluck, 0.09, pan=-0.5 + k * 0.14)
    for bar, step, length, n in motif_melody(rng, prog, 4, 72, 84, density=0.45):
        t.note(bar * 4 + step, length, n, music_box, 0.12, pan=0.25, echo=(1.5, 0.35, 2))
        t.note(bar * 4 + step, length, n - 12, vibes, 0.05, pan=-0.3)
    t.finish(0.28)
    return t


def chill():
    """Lazy lo-fi: rhodes chords, nylon guitar tune, soft brushes."""
    t = Track(bpm=76, bars=16)
    rng = random.Random(21)
    prog = [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59]] * 4  # Fmaj7 Em7 Dm7 Cmaj7
    for bar, ch in enumerate(prog):
        b0 = bar * 4
        for k, at in enumerate([0, 1.5, 2.5]):
            for j, n in enumerate(ch):
                t.note(b0 + at, 1 if k == 0 else 0.75, n, rhodes, 0.05, pan=-0.35 + j * 0.2)
        t.note(b0, 1.5, ch[0] - 12, bass, 0.17)
        t.note(b0 + 2, 1, ch[0] - 12 + 7, bass, 0.12)
        t.note(b0 + 3, 1, ch[0] - 12 + 5, bass, 0.1)
        t.drum(b0, 'kick', 0.22)
        t.drum(b0 + 2.5, 'kick', 0.15)
        t.drum(b0 + 1, 'snap', 0.07, pan=0.2)
        t.drum(b0 + 3, 'snap', 0.07, pan=0.2)
        for h in range(8):
            t.drum(b0 + h * 0.5 + (0.08 if h % 2 else 0), 'brush', 0.045, pan=-0.4)
    for bar, step, length, n in motif_melody(rng, prog, 4, 67, 81, density=0.5):
        t.note(bar * 4 + step, length, n, pluck, 0.14, pan=0.3, echo=(1.5, 0.3, 2))
    t.finish(0.24)
    return t


def fever():
    """Bright and bouncy: pop chords, plucky bass, a vibes-and-flute tune."""
    t = Track(bpm=128, bars=24)
    rng = random.Random(31)
    prog = [[60, 64, 67, 71], [55, 59, 62, 67], [57, 60, 64, 67], [53, 57, 60, 64]] * 6  # Cmaj7 G Am7 Fmaj7
    for bar, ch in enumerate(prog):
        b0 = bar * 4
        for at in [0.5, 1.5, 2.5, 3.5]:
            for j, n in enumerate(ch[1:]):
                t.note(b0 + at, 0.35, n, rhodes, 0.03, pan=-0.3 + j * 0.3)
        for at, off in [(0, 0), (0.75, 12), (1.5, 7), (2, 0), (2.75, 12), (3.5, 7)]:
            t.note(b0 + at, 0.4, ch[0] - 12 + off, pluck_bass, 0.17)
        t.drum(b0, 'kick', 0.2)
        t.drum(b0 + 2, 'kick', 0.2)
        t.drum(b0 + 1, 'snap', 0.09, pan=0.15)
        t.drum(b0 + 3, 'snap', 0.09, pan=0.15)
        for h in range(8):
            t.drum(b0 + h * 0.5, 'shaker', 0.045, pan=0.45)
    for bar, step, length, n in motif_melody(rng, prog, 8, 69, 84, density=0.55):
        t.note(bar * 4 + step * 0.5, length * 0.45, n, vibes, 0.1, pan=-0.2, echo=(0.75, 0.3, 2))
        t.note(bar * 4 + step * 0.5, length * 0.5, n, flute, 0.045, pan=0.2)
    t.finish(0.2)
    return t


def hip():
    """Swingy and groovy: rhodes comping, walking bass, harp lead."""
    t = Track(bpm=96, bars=16, swing=0.17)
    rng = random.Random(41)
    prog = [[60, 64, 67, 71], [57, 60, 64, 67], [50, 53, 57, 60], [55, 59, 62, 64]] * 4  # Cmaj7 Am7 Dm7 G6
    for bar, ch in enumerate(prog):
        b0 = bar * 4
        for at in [0, 1.5, 3]:
            for j, n in enumerate(ch):
                t.note(b0 + at, 0.4, n, rhodes, 0.045, pan=-0.35 + j * 0.2)
        root = ch[0] - 12
        walk = [(0, 0), (1, 4 if ch[1] - ch[0] == 4 else 3), (2, 7), (3, 9 if bar % 2 == 0 else 5)]
        for at, off in walk:
            t.note(b0 + at, 0.9, root + off, bass, 0.17)
        t.drum(b0, 'kick', 0.2)
        t.drum(b0 + 2.5, 'kick', 0.16)
        t.drum(b0 + 1, 'snap', 0.1, pan=0.2)
        t.drum(b0 + 3, 'snap', 0.1, pan=0.2)
        for h in range(8):
            t.drum(b0 + h * 0.5, 'brush', 0.06 if h % 2 == 0 else 0.035, pan=-0.4)
    for bar, step, length, n in motif_melody(rng, prog, 8, 67, 81, density=0.5):
        t.note(bar * 4 + step * 0.5, length * 0.5, n, pluck, 0.15, pan=0.3, echo=(1.5, 0.3, 2))
    t.finish(0.24)
    return t


if __name__ == '__main__':
    out = sys.argv[1]
    wanted = sys.argv[2:] or ['menu', 'chill', 'fever', 'hip']
    for name, fn in [('menu', menu), ('chill', chill), ('fever', fever), ('hip', hip)]:
        if name not in wanted:
            continue
        track = fn()
        track.write(f'{out}/{name}.wav')
        print(name, round(track.length / SR, 1), 's', flush=True)
