#!/usr/bin/env python3
"""Generates Pocket Boundary's original sound palette procedurally (stdlib only).

Every sound here is synthesised from oscillators, filtered noise and envelopes written in
this file, so the project owns them outright (see ASSET_LICENSES.md). Deterministic:
re-running produces identical files.

    python3 tools/gen_audio.py
"""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def write(name, samples, sr=SR):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-9, max(abs(x) for x in samples))
    gain = 0.89 / peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, x * gain)) * 32767)) for x in samples))


def n(sec):
    return int(sec * SR)


class Biquad:
    def __init__(self, kind, f, q=0.707):
        w0 = 2 * math.pi * f / SR
        a = math.sin(w0) / (2 * q)
        c = math.cos(w0)
        if kind == "lp":
            b0, b1, b2 = (1 - c) / 2, 1 - c, (1 - c) / 2
        elif kind == "hp":
            b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
        else:  # band-pass (constant peak)
            b0, b1, b2 = a, 0, -a
        a0, a1, a2 = 1 + a, -2 * c, 1 - a
        self.b = (b0 / a0, b1 / a0, b2 / a0)
        self.a = (a1 / a0, a2 / a0)
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0

    def __call__(self, x):
        y = self.b[0] * x + self.b[1] * self.x1 + self.b[2] * self.x2 - self.a[0] * self.y1 - self.a[1] * self.y2
        self.x2, self.x1, self.y2, self.y1 = self.x1, x, self.y1, y
        return y


def env_exp(i, decay):
    return math.exp(-i / (decay * SR))


def mix(*tracks):
    L = max(len(t) for t in tracks)
    out = [0.0] * L
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def pad(t, L):
    return t + [0.0] * (L - len(t))


def place(dst, src, at, g=1.0):
    s = n(at)
    for i, v in enumerate(src):
        if s + i < len(dst):
            dst[s + i] += v * g


# ---------------------------------------------------------------- impacts
def bat_hit(seed, pitch=1.0, bright=1.0, length=0.22):
    r = random.Random(seed)
    bp = Biquad("bp", 2600 * bright, 1.2)
    bp2 = Biquad("bp", 1100 * pitch, 3.0)
    out = []
    for i in range(n(length)):
        t = i / SR
        noise = r.uniform(-1, 1)
        crack = bp(noise) * env_exp(i, 0.012) * 2.5
        body = (math.sin(2 * math.pi * 920 * pitch * t) * 0.5 + math.sin(2 * math.pi * 1540 * pitch * t) * 0.3) * env_exp(i, 0.035)
        tape = bp2(noise) * env_exp(i, 0.05) * 0.6
        out.append(crack + body + tape)
    return out


def bounce(seed, f=150):
    r = random.Random(seed)
    lp = Biquad("lp", 900)
    return [math.sin(2 * math.pi * f * (1 - i / n(0.2) * 0.3) * i / SR) * env_exp(i, 0.03) + lp(r.uniform(-1, 1)) * env_exp(i, 0.012) * 0.8 for i in range(n(0.16))]


def stumps():
    out = [0.0] * n(0.7)
    r = random.Random(5)
    for k, (at, f) in enumerate([(0.0, 520), (0.03, 690), (0.07, 430), (0.16, 820), (0.3, 760), (0.42, 900)]):
        g = 1.0 if k < 3 else 0.45
        knock = [(math.sin(2 * math.pi * f * i / SR) + 0.4 * math.sin(2 * math.pi * f * 2.7 * i / SR) + 0.3 * r.uniform(-1, 1)) * env_exp(i, 0.025) for i in range(n(0.12))]
        place(out, knock, at, g)
    return out


def catch_slap():
    r = random.Random(9)
    lp = Biquad("lp", 1400)
    return [lp(r.uniform(-1, 1)) * env_exp(i, 0.03) + math.sin(2 * math.pi * 210 * i / SR) * env_exp(i, 0.05) * 0.6 for i in range(n(0.2))]


def swing():
    r = random.Random(11)
    out = []
    L = n(0.22)
    for i in range(L):
        t = i / L
        bp = None
        out.append(r.uniform(-1, 1) * math.sin(math.pi * t) ** 2)
    f = Biquad("bp", 900, 0.8)
    return [f(x) * 1.5 for x in out]


def step(seed):
    r = random.Random(seed)
    lp = Biquad("lp", 500)
    return [lp(r.uniform(-1, 1)) * env_exp(i, 0.02) for i in range(n(0.08))]


# ---------------------------------------------------------------- crowd & ambience
def crowd_loop(sec=8.0, seed=21, level=1.0):
    r = random.Random(seed)
    L = n(sec)
    f1, f2 = Biquad("bp", 500, 0.6), Biquad("bp", 1400, 0.9)
    base = []
    for i in range(L):
        t = i / SR
        mod = 0.7 + 0.2 * math.sin(2 * math.pi * 0.23 * t) + 0.1 * math.sin(2 * math.pi * 0.61 * t + 1)
        x = r.uniform(-1, 1)
        base.append((f1(x) * 0.8 + f2(x) * 0.3) * mod * level)
    # Scattered murmurs / claps.
    for k in range(int(sec * 3)):
        at = r.uniform(0, sec - 0.3)
        clap = [r.uniform(-1, 1) * env_exp(i, 0.01) * 0.5 for i in range(n(0.05))]
        place(base, clap, at, r.uniform(0.2, 0.6))
    # Seamless loop: crossfade tail into head.
    xf = n(0.5)
    for i in range(xf):
        a = i / xf
        base[i] = base[i] * a + base[L - xf + i] * (1 - a)
    return base[: L - xf]


def _loopify(out, xf_sec=0.5):
    xf = n(xf_sec)
    L = len(out)
    for i in range(xf):
        a = i / xf
        out[i] = out[i] * a + out[L - xf + i] * (1 - a)
    return out[: L - xf]


def _babble_voice(r, L, pitch):
    # One distant talker: jittery glottal buzz, syllable-rate swells, vowel formants that hop.
    vowels = [(730, 1090), (530, 1840), (270, 2290), (570, 840), (440, 1020), (660, 1720)]
    f1 = Biquad("bp", 600, 4.0)
    f2 = Biquad("bp", 1400, 5.0)
    out = [0.0] * L
    ph = 0.0
    i = 0
    talking = r.random() < 0.6
    while i < L:
        if talking:
            syl = n(r.uniform(0.12, 0.26))
            v1, v2 = r.choice(vowels)
            f1.__init__("bp", v1, 4.0)
            f2.__init__("bp", v2, 5.0)
            p0 = pitch * r.uniform(0.85, 1.2)
            amp = r.uniform(0.5, 1.0)
            for k in range(min(syl, L - i)):
                u = k / syl
                ph += 2 * math.pi * p0 * (1.0 - 0.15 * u) / SR
                buzz = (ph / math.pi % 2.0) - 1.0  # sawtooth
                e = math.sin(math.pi * u) ** 0.7 * amp
                out[i + k] = (f1(buzz) * 0.9 + f2(buzz) * 0.5) * e
            i += syl
            if r.random() < 0.18:
                talking = False
        else:
            i += n(r.uniform(0.3, 1.6))
            talking = True
    return out


def _rickshaw(r, L, at, dur):
    # A two-stroke auto-rickshaw puttering past in the lane: firing pulses + exhaust noise,
    # rising then falling with a slight Doppler drop.
    out = [0.0] * L
    lp = Biquad("lp", 900)
    s0 = n(at)
    ph = 0.0
    for k in range(n(dur)):
        if s0 + k >= L:
            break
        u = k / n(dur)
        prox = math.exp(-((u - 0.5) / 0.22) ** 2)
        rate = 31.0 * (1.03 if u < 0.5 else 0.97) * (1 + 0.04 * math.sin(2 * math.pi * 1.3 * k / SR))
        ph += rate / SR
        fire = math.exp(-(ph % 1.0) / 0.12)
        x = fire * (0.7 + 0.6 * r.uniform(-1, 1))
        out[s0 + k] = lp(x) * prox * 0.55
    return out


def ambience_pindi(sec=16.0):
    # Neighbourhood ground ambience (replaces the old birdsong): rooftop spectators
    # chatting, a soft breeze, a rickshaw in the lane, distant traffic and tea-stall clinks.
    r = random.Random(33)
    L = n(sec)
    wind_lp = Biquad("lp", 260)
    hum_lp = Biquad("lp", 140)
    out = []
    for i in range(L):
        t = i / SR
        gust = 0.75 + 0.25 * math.sin(2 * math.pi * 0.07 * t) * math.sin(2 * math.pi * 0.19 * t + 0.6)
        out.append(wind_lp(r.uniform(-1, 1)) * 0.22 * gust + hum_lp(r.uniform(-1, 1)) * 0.35)
    # Distant chatter: a handful of voices, low-passed by distance.
    chat = [0.0] * L
    for v in range(7):
        voice = _babble_voice(r, L, r.choice([105, 120, 135, 190, 215, 240]))
        g = r.uniform(0.10, 0.2)
        for i in range(L):
            chat[i] += voice[i] * g
    dist = Biquad("lp", 1700)
    for i in range(L):
        out[i] += dist(chat[i])
    # Lane traffic: one rickshaw pass, a far-off motorbike.
    for i, v in enumerate(_rickshaw(r, L, 3.0, 5.5)):
        out[i] += v
    for i, v in enumerate(_rickshaw(r, L, 10.5, 4.0)):
        out[i] += v * 0.4
    # Tea-stall cup clinks and a spoon stirring.
    for k in range(5):
        at = r.uniform(0, sec - 0.3)
        cl = [(math.sin(2 * math.pi * 3100 * i / SR) + math.sin(2 * math.pi * 4700 * i / SR)) * env_exp(i, 0.04) * 0.1 for i in range(n(0.2))]
        place(out, cl, at)
    # A couple of claps and a distant shout of encouragement-like swell.
    for k in range(6):
        at = r.uniform(0, sec - 0.2)
        clap = [r.uniform(-1, 1) * env_exp(i, 0.008) * 0.35 for i in range(n(0.04))]
        place(out, clap, at)
    pk = max(abs(v) for v in out)
    return _loopify([math.tanh(1.8 * v / pk) for v in out])  # tame the rickshaw peak


def cheer(sec=2.2, seed=41, big=True):
    r = random.Random(seed)
    L = n(sec)
    f1, f2 = Biquad("bp", 700, 0.7), Biquad("bp", 1800, 0.8)
    out = []
    for i in range(L):
        t = i / L
        e = min(1.0, t / 0.12) * (1 - t) ** 1.5
        x = r.uniform(-1, 1)
        out.append((f1(x) + 0.6 * f2(x)) * e)
    for k in range(40 if big else 15):
        at = r.uniform(0.05, sec * 0.7)
        clap = [r.uniform(-1, 1) * env_exp(i, 0.008) for i in range(n(0.03))]
        place(out, clap, at, r.uniform(0.2, 0.5))
    # "Ooh"-ish formant swell for big cheers.
    if big:
        for i in range(L):
            t = i / SR
            out[i] += 0.25 * math.sin(2 * math.pi * (220 + 40 * math.sin(t * 3)) * t) * min(1, t / 0.2) * max(0, 1 - t / sec)
    return out


def groan(sec=1.4):
    r = random.Random(51)
    L = n(sec)
    out = []
    bp = Biquad("bp", 450, 1.5)
    for i in range(L):
        t = i / L
        f = 260 - 80 * t
        voice = math.sin(2 * math.pi * f * i / SR) * 0.35 + math.sin(2 * math.pi * f * 2 * i / SR) * 0.15
        out.append((bp(r.uniform(-1, 1)) * 0.8 + voice) * min(1, t / 0.1) * (1 - t))
    return out


def anticipation(sec=1.2):
    r = random.Random(61)
    L = n(sec)
    bp = Biquad("bp", 600, 0.9)
    out = []
    for i in range(L):
        t = i / L
        f = 200 + 140 * t
        out.append((bp(r.uniform(-1, 1)) * 0.7 + 0.3 * math.sin(2 * math.pi * f * i / SR)) * t * (1.0 if t < 0.85 else (1 - t) / 0.15))
    return out


def ambience_rain(sec=8.0):
    r = random.Random(71)
    L = n(sec)
    lp, hp = Biquad("lp", 5000), Biquad("hp", 400)
    out = [hp(lp(r.uniform(-1, 1))) * 0.5 for i in range(L)]
    for k in range(int(sec * 40)):
        at = r.uniform(0, sec - 0.05)
        drop = [r.uniform(-1, 1) * env_exp(i, 0.004) * 0.6 for i in range(n(0.02))]
        place(out, drop, at, r.uniform(0.2, 0.8))
    xf = n(0.5)
    for i in range(xf):
        a = i / xf
        out[i] = out[i] * a + out[L - xf + i] * (1 - a)
    return out[: L - xf]


def ambience_night(sec=8.0):
    r = random.Random(81)
    L = n(sec)
    lp = Biquad("lp", 250)
    out = [lp(r.uniform(-1, 1)) * 0.3 for i in range(L)]
    # Crickets: rapid pulsed high sine trills.
    for k in range(10):
        at = r.uniform(0, sec - 0.6)
        f = r.uniform(4200, 5200)
        tr = []
        for i in range(n(0.45)):
            t = i / SR
            pulse = 1.0 if (int(t * 38) % 2 == 0) else 0.0
            tr.append(math.sin(2 * math.pi * f * t) * pulse * 0.12 * math.sin(math.pi * i / n(0.45)))
        place(out, tr, at)
    xf = n(0.5)
    for i in range(xf):
        a = i / xf
        out[i] = out[i] * a + out[L - xf + i] * (1 - a)
    return out[: L - xf]


def _air_horn(f, dur, amp=1.0, bend=0.05, bright=1.0, flutter=0.0, sag=0.0):
    # One trumpet of a truck pressure-horn set: buzzy reed tone that "blooms" up to pitch
    # as the air pressure builds, a resonant bell, a little breath, two detuned trumpets.
    # flutter: valve tremolo depth (the wavering "baja" sound); sag: pitch drop as the
    # air runs out at the end of a long blast.
    out = []
    bell = Biquad("bp", 1250 * bright, 1.1)
    hp = Biquad("hp", 140)
    rr = random.Random(int(f * 10))
    phs = [0.0, 0.0]
    for i in range(n(dur)):
        t = i / SR
        e = min(1.0, t / 0.025) * min(1.0, (dur - t) / 0.05)
        tail = max(0.0, (t - dur * 0.7) / (dur * 0.3))
        trem = 1.0 - flutter * (0.5 + 0.5 * math.sin(2 * math.pi * 11.0 * t))
        v = 0.0
        for j, det in enumerate((1.0, 1.006)):
            fi = f * det * (1.0 - bend * math.exp(-t / 0.05)) * (1 + 0.003 * math.sin(2 * math.pi * 6.0 * t))
            fi *= 1.0 - sag * tail * tail
            phs[j] += 2 * math.pi * fi / SR
            p = phs[j]
            w = 0.0
            for k in range(1, 12):
                if f * k > 6000:
                    break
                w += math.sin(k * p) / (k ** 0.8)
            v += math.tanh(1.8 * w)  # reed overdrive
        v += rr.uniform(-1, 1) * 0.15 * math.exp(-t / 0.05)
        out.append(hp(v * 0.6 + bell(v) * 1.2) * e * amp * trem)
    return out


def _play_tune(out, tune, at=0.0, amp=0.8, gap=0.92, **kw):
    # tune: [(freq or None for a rest, seconds)]; returns the time after the last note.
    for f, d in tune:
        if f:
            place(out, _air_horn(f, d * gap, amp, **kw), at)
        at += d
    return at


def _blast(out, at, freqs, dur, sag=0.0, flutter=0.0):
    for k, f in enumerate(freqs):
        place(out, _air_horn(f, dur, 0.9 - 0.15 * k, 0.08 + 0.01 * k, 0.8 + 0.1 * k, flutter, sag), at)


def _street(out):
    # Street slap-back so it sounds outdoors between houses, then pressure-horn loudness.
    d1, d2 = n(0.07), n(0.16)
    y = out + [0.0] * d2
    for i, v in enumerate(out):
        y[i + d1] += v * 0.28
        y[i + d2] += v * 0.14
    pk = max(abs(v) for v in y)
    return [math.tanh(2.2 * v / pk) for v in y]


# Note names (Hz)
G3, Ab3, Bb3, C4, Db4, D4, E4, F4, G4, A4, B4 = 196.0, 207.7, 233.1, 261.6, 277.2, 293.7, 329.6, 349.2, 392.0, 440.0, 493.9
C5, D5, E5, F5, G5, A5 = 523.3, 587.3, 659.3, 698.5, 784.0, 880.0


def truck_horns():
    """Pakistani decorated-truck horns - a different one each time the truck rolls in.
    All tunes are original; each is a set of tuned air-horn trumpets (and the big
    pressure horn) as fitted to painted trucks."""
    horns = []
    # 1. Jaunty tune, then the two-tone pressure blast.
    out = [0.0] * n(2.0)
    at = _play_tune(out, [(D5, 0.1), (D5, 0.1), (B4, 0.1), (G4, 0.1), (A4, 0.1), (B4, 0.1),
                          (C5, 0.1), (E5, 0.18), (D5, 0.24)])
    _blast(out, at + 0.08, [Db4, F4, Ab3], 0.75)
    horns.append(_street(out))
    # 2. Shaadi band: a quick wedding-procession flourish, ending on a held chord.
    out = [0.0] * n(2.0)
    at = _play_tune(out, [(A4, 0.08), (C5, 0.08), (E5, 0.08), (A5, 0.16), (G5, 0.08), (E5, 0.08),
                          (F5, 0.08), (E5, 0.08), (D5, 0.08), (C5, 0.16), (None, 0.04)], amp=0.75)
    _blast(out, at, [C5, E5, A4], 0.7, flutter=0.25)
    horns.append(_street(out))
    # 3. Big pressure blasts: "PAAAM ... POOOOM", air sagging at the end.
    out = [0.0] * n(2.2)
    _blast(out, 0.0, [Bb3, D4, F4], 0.55, sag=0.03)
    _blast(out, 0.75, [G3, Bb3, D4], 1.25, sag=0.09)
    horns.append(_street(out))
    # 4. Rolling arpeggio up and down the trumpet set, twice, then a held top note.
    out = [0.0] * n(2.1)
    roll = [(C5, 0.07), (D5, 0.07), (E5, 0.07), (G5, 0.07), (A5, 0.07), (G5, 0.07), (E5, 0.07), (D5, 0.07)]
    at = _play_tune(out, roll + roll, amp=0.7, gap=0.9)
    _play_tune(out, [(C5, 0.5)], at, amp=0.85)
    _blast(out, at, [C4, E4], 0.5)
    horns.append(_street(out))
    # 5. Toot-toot-toot, then a long fluttering valve horn.
    out = [0.0] * n(2.1)
    at = 0.0
    for k in range(3):
        _blast(out, at, [G4, B4], 0.11)
        at += 0.18
    _blast(out, at + 0.05, [E4, G4, C5], 1.1, flutter=0.55, sag=0.02)
    horns.append(_street(out))
    # 6. Call and answer: high trumpets ask, the deep pressure horn answers, a last flourish.
    out = [0.0] * n(2.2)
    at = _play_tune(out, [(E5, 0.12), (D5, 0.12), (C5, 0.12), (G4, 0.22)], amp=0.8)
    _blast(out, at + 0.06, [Ab3, C4], 0.55, sag=0.04)
    at += 0.7
    _play_tune(out, [(G4, 0.08), (C5, 0.08), (E5, 0.08), (G5, 0.3)], at, amp=0.8)
    horns.append(_street(out))
    return horns


def jingle():
    # Bells/chains swinging (like decorated truck chains).
    r = random.Random(91)
    out = [0.0] * n(1.8)
    for k in range(26):
        at = r.uniform(0, 1.5)
        f = r.uniform(2400, 3600)
        bell = [(math.sin(2 * math.pi * f * i / SR) + 0.5 * math.sin(2 * math.pi * f * 2.76 * i / SR)) * env_exp(i, 0.08) * 0.2 for i in range(n(0.3))]
        place(out, bell, at, r.uniform(0.4, 1.0))
    return out


# ---------------------------------------------------------------- UI & music
def tone(f, sec, decay, amp=1.0, harm=0.0):
    return [(math.sin(2 * math.pi * f * i / SR) + harm * math.sin(2 * math.pi * f * 2 * i / SR)) * env_exp(i, decay) * amp for i in range(n(sec))]


def dhol_dhum(amp=1.0):
    # Low membrane hit with pitch drop (original synthesis, dhol-inspired).
    out = []
    ph = 0.0
    for i in range(n(0.35)):
        t = i / SR
        f = 70 + 60 * math.exp(-t * 25)
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph) * math.exp(-t * 9) * amp)
    return out


def dhol_tak(seed, amp=0.6):
    r = random.Random(seed)
    bp = Biquad("bp", 1800, 1.2)
    return [(bp(r.uniform(-1, 1)) * 2 + math.sin(2 * math.pi * 420 * i / SR) * 0.5) * env_exp(i, 0.03) * amp for i in range(n(0.12))]


def milestone_fanfare():
    """Fifty / hundred: a dhol roll that speeds up into a horn fanfare, then a held,
    fluttering horn chord over dhol beats (original)."""
    out = [0.0] * n(3.0)
    # Accelerating dhol roll.
    at, gap, k = 0.0, 0.12, 0
    while at < 0.62:
        place(out, dhol_tak(500 + k, 0.45 + 0.4 * at), at)
        if k % 3 == 0:
            place(out, dhol_dhum(0.8), at)
        at += gap
        gap = max(0.045, gap * 0.86)
        k += 1
    # Fanfare up the horn trumpets, then the big chord.
    at = _play_tune(out, [(G4, 0.12), (C5, 0.12), (E5, 0.12), (G5, 0.2)], 0.62, amp=0.85)
    _blast(out, at, [C5, E5, G5, C4], 1.5, flutter=0.3)
    for b in range(5):
        place(out, dhol_dhum(1.0), at + b * 0.3)
        place(out, dhol_tak(600 + b, 0.5), at + b * 0.3 + 0.15)
    return _street(out)


def music_loop(bpm=96, bars=4):
    beat = 60.0 / bpm
    L = n(beat * 4 * bars)
    out = [0.0] * L
    # 8-step groove per bar (dhum . tak dhum | tak . dhum tak) — an original pattern.
    pat = ["D", "", "T", "D", "T", "", "D", "T"]
    for b in range(bars):
        for s, hit in enumerate(pat):
            at = (b * 4 + s * 0.5) * beat
            if hit == "D":
                place(out, dhol_dhum(0.9), at)
            elif hit == "T":
                place(out, dhol_tak(b * 10 + s), at, 0.7)
            place(out, [x * 0.12 for x in dhol_tak(99 + s, 0.4)], at + beat * 0.25)
    # Warm drone pad (Sa-Pa) with slow swell.
    for i in range(L):
        t = i / SR
        pad_v = 0.08 * (math.sin(2 * math.pi * 146.8 * t) + 0.6 * math.sin(2 * math.pi * 220.0 * t) + 0.3 * math.sin(2 * math.pi * 293.7 * t))
        out[i] += pad_v * (0.7 + 0.3 * math.sin(2 * math.pi * t / (L / SR)))
    # Simple pentatonic motif on a plucked tone.
    notes = [293.7, 329.6, 392.0, 440.0, 392.0, 329.6, 293.7, 220.0]
    for k, f in enumerate(notes * bars):
        if k % 2 == 0 or k % 8 == 5:
            place(out, tone(f, 0.4, 0.12, 0.18, 0.3), k * beat * 0.5 + beat * 0.02)
    return out


def sting(kind):
    out = [0.0] * n(2.0)
    if kind == "open":
        for k, at in enumerate([0, 0.18, 0.36, 0.5, 0.62]):
            place(out, dhol_dhum(1.0) if k % 2 == 0 else dhol_tak(k), at)
        for k, f in enumerate([293.7, 392.0, 440.0, 587.3]):
            place(out, tone(f, 0.8, 0.25, 0.25, 0.4), 0.7 + k * 0.12)
    elif kind == "boundary":
        for k, at in enumerate([0, 0.12, 0.24]):
            place(out, dhol_tak(k + 20, 0.8), at)
        place(out, dhol_dhum(1.0), 0.36)
        for k, f in enumerate([440.0, 587.3, 659.3]):
            place(out, tone(f, 0.6, 0.2, 0.25, 0.3), 0.36 + k * 0.08)
    elif kind == "wicket":
        place(out, dhol_dhum(1.0), 0.0)
        for k, f in enumerate([392.0, 329.6, 293.7]):
            place(out, tone(f, 0.6, 0.2, 0.25, 0.2), 0.1 + k * 0.14)
    elif kind == "win":
        for k in range(8):
            place(out, dhol_dhum(0.9) if k % 3 == 0 else dhol_tak(k + 40), k * 0.1)
        for k, f in enumerate([293.7, 369.99, 440.0, 587.3, 740.0]):
            place(out, tone(f, 0.9, 0.3, 0.22, 0.35), 0.4 + k * 0.1)
    elif kind == "lose":
        for k, f in enumerate([440.0, 392.0, 329.6, 293.7]):
            place(out, tone(f, 0.8, 0.3, 0.22, 0.2), k * 0.2)
        place(out, dhol_dhum(0.7), 0.8)
    return out


if __name__ == "__main__":
    for k, (p, b) in enumerate([(1.0, 1.0), (1.06, 1.1), (0.94, 0.92), (1.02, 1.2)], start=1):
        write("bat_hit_%d" % k, bat_hit(100 + k, p, b))
    write("bat_edge", bat_hit(200, 1.35, 1.6, 0.12))
    for k, f in enumerate([140, 160, 180], start=1):
        write("bounce_%d" % k, bounce(300 + k, f))
    write("stumps", stumps())
    write("catch", catch_slap())
    write("swing", swing())
    for k in range(1, 3):
        write("step_%d" % k, step(400 + k))
    write("crowd_loop", crowd_loop())
    write("amb_pindi", ambience_pindi())
    write("amb_rain", ambience_rain())
    write("amb_night", ambience_night())
    write("sting_milestone", milestone_fanfare())
    for k, h in enumerate(truck_horns(), 1):
        write("truck_horn_%d" % k, h)
    write("jingle", jingle())
    write("cheer_big", cheer(2.4, 41, True))
    write("cheer_small", cheer(1.4, 43, False))
    write("groan", groan())
    write("anticipation", anticipation())
    write("ui_tap", tone(1200, 0.08, 0.015, 1.0, 0.3))
    write("ui_confirm", mix(tone(880, 0.2, 0.05, 1.0, 0.2), pad([0.0] * n(0.06) + tone(1320, 0.2, 0.05, 0.8, 0.2), n(0.26))))
    for kind in ["open", "boundary", "wicket", "win", "lose"]:
        write("sting_" + kind, sting(kind))
    write("music_loop", music_loop())
    print("ok")
