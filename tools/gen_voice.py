#!/usr/bin/env python3
"""Generates PLACEHOLDER spoken commentary (English + Urdu) with eSpeak NG.

These are synthetic, robotic stand-ins so the voice pipeline can be heard end to end.
They are NOT the final voice experience: real recordings, reviewed by a native speaker,
should replace them (drop a file with the same name into assets/audio/).

For each line in scripts/sim/commentary.gd this writes
    assets/audio/vo_<id>_en.wav   (English text, en-gb voice)
    assets/audio/vo_<id>_ur.wav   (Urdu-script text below, eSpeak NG 'ur' voice)
and regenerates VOICE_SCRIPT.csv with clip paths and durations.

    sudo apt-get install espeak-ng
    python3 tools/gen_voice.py
"""
import csv, math, os, re, struct, subprocess, wave, io

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "audio")
SR = 22050

# Urdu-script versions of the Roman Urdu captions (what the 'ur' voice actually reads).
# Drafted by the developer - needs native-speaker review.
URDU = {
    "intro_1": "تیار؟ بال پہ نظر!",
    "six_1": "کیا شاٹ ہے! سیدھا چھکا!",
    "six_2": "سیدھا باؤنڈری کے پار!",
    "six_3": "چھت پہ گئی بال!",
    "four_1": "چوکا! زبردست ٹائمنگ!",
    "four_2": "بال رسّی تک دوڑ گئی!",
    "four_3": "کوئی نہیں روک سکتا اسے!",
    "perfect_runs": "کیا ٹائمنگ ہے!",
    "runs_1": "بھاگو، بھاگو! دو رن!",
    "runs_2": "ایک رن، سٹرائیک گھماؤ۔",
    "runs_3": "تین رن! کیا دوڑ ہے!",
    "dot_early": "اس دفعہ تھوڑا جلدی۔",
    "dot_late": "تھوڑی دیر ہو گئی۔",
    "dot_none": "بال کو جانے دیا۔",
    "dot_field": "اچھی فیلڈنگ، کوئی رن نہیں۔",
    "bowled_1": "ارے! سٹمپس اڑ گئے!",
    "bowled_2": "بولڈ! اگلی بال پہ دھیان۔",
    "caught_1": "پکڑ لیا! کیا کیچ ہے۔",
    "caught_2": "ہوا میں تھی، پکڑی گئی۔",
    "edge_1": "بیٹ کا کنارہ لگا!",
    "last_ball_4": "آخری بال، چار رن چاہئیں!",
    "last_ball_6": "آخری بال، چھکا چاہیے!",
    "last_ball_1": "آخری بال، بس ایک رن!",
    "last_ball_n": "آخری بال! سب کچھ اس پہ ہے۔",
    "win_1": "جیت گئے! محلے کا ہیرو!",
    "lost_1": "کوئی بات نہیں، ایک اور میچ!",
    "tied_1": "برابر! کیا مقابلہ تھا!",
}

VOICES = {"en": ["-v", "en-gb+m3", "-s", "165", "-p", "42"],
          "ur": ["-v", "ur+m3", "-s", "150", "-p", "40"]}


def parse_lines():
    src = open(os.path.join(ROOT, "scripts", "sim", "commentary.gd"), encoding="utf-8").read()
    pat = re.compile(r'\[\s*"([^"]+)",\s*"([^"]*)",\s*"([^"]*)",\s*"([^"]*)",\s*"([^"]*)"\s*\]')
    return [m.groups() for m in pat.finditer(src)]


def synth(text, lang):
    raw = subprocess.run(["espeak-ng", *VOICES[lang], "--stdout", text],
                         check=True, capture_output=True).stdout
    with wave.open(io.BytesIO(raw)) as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 2
        sr = w.getframerate()
        frames = w.readframes(w.getnframes())
    x = [s / 32768.0 for s in struct.unpack("<%dh" % (len(frames) // 2), frames)]
    if sr != SR:  # linear resample (eSpeak NG normally emits 22050 Hz already)
        ratio = sr / SR
        x = [x[min(len(x) - 1, int(i * ratio))] for i in range(int(len(x) / ratio))]
    return x


def process(x):
    # Trim silence, then a short "stadium PA" slap-back so it sits in the crowd bed.
    thr = 0.01
    a = next((i for i, v in enumerate(x) if abs(v) > thr), 0)
    b = len(x) - next((i for i, v in enumerate(reversed(x)) if abs(v) > thr), 0)
    x = x[max(0, a - 200):min(len(x), b + 400)]
    taps = [(int(0.045 * SR), 0.22), (int(0.11 * SR), 0.12)]
    tail = taps[-1][0]
    y = x + [0.0] * tail
    for d, g in taps:
        for i, v in enumerate(x):
            y[i + d] += v * g
    fade = int(0.02 * SR)
    for i in range(fade):
        y[-1 - i] *= i / fade
    peak = max(1e-9, max(abs(v) for v in y))
    return [v * 0.85 / peak for v in y]


def write(name, y):
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in y))
    return len(y) / SR


def main():
    lines = parse_lines()
    missing = [l[0] for l in lines if l[0] not in URDU]
    if missing:
        raise SystemExit("Missing Urdu text for: " + ", ".join(missing))
    rows = []
    prov = "eSpeak NG 1.51 synthetic placeholder (tools/gen_voice.py)"
    status = "PLACEHOLDER robotic TTS - replace with reviewed recording; text needs native-speaker review"
    for lid, event, cond, roman, english in lines:
        for lang, caption_lang, caption, spoken in (("ur", "roman_urdu", roman, URDU[lid]),
                                                    ("en", "english", english, english)):
            name = "vo_%s_%s" % (lid, lang)
            dur = write(name, process(synth(spoken, lang)))
            rows.append([lid, event, cond, caption_lang, caption, spoken,
                         "assets/audio/%s.wav" % name, "%.2f" % dur, prov, status])
    with open(os.path.join(ROOT, "VOICE_SCRIPT.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["id", "event", "condition", "language", "text", "spoken_text",
                    "clip_path", "duration_s", "licence_provider", "review_status"])
        w.writerows(rows)
    print("wrote %d clips" % len(rows))


if __name__ == "__main__":
    main()
