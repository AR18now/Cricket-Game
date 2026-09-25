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


def ambience_pindi(sec=10.0):
    r = random.Random(33)
    L = n(sec)
    lp = Biquad("lp", 300)
    out = [lp(r.uniform(-1, 1)) * 0.35 * (0.8 + 0.2 * math.sin(2 * math.pi * 0.1 * i / SR)) for i in range(L)]
    # Evening birds: short chirps (sine sweeps).
    for k in range(14):
        at = r.uniform(0, sec - 0.4)
        f0 = r.uniform(2800, 4200)
        chirps = r.randint(2, 4)
        for c in range(chirps):
            ch = [math.sin(2 * math.pi * (f0 + 1200 * (i / n(0.06))) * i / SR) * math.sin(math.pi * i / n(0.06)) * 0.25 for i in range(n(0.06))]
            place(out, ch, at + c * 0.09)
    # Distant tea-stall cup clinks.
    for k in range(4):
        at = r.uniform(0, sec - 0.3)
        cl = [(math.sin(2 * math.pi * 3100 * i / SR) + math.sin(2 * math.pi * 4700 * i / SR)) * env_exp(i, 0.04) * 0.12 for i in range(n(0.2))]
        place(out, cl, at)
    xf = n(0.5)
    for i in range(xf):
        a = i / xf
        out[i] = out[i] * a + out[L - xf + i] * (1 - a)
    return out[: L - xf]


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
