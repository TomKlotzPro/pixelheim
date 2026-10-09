# The game's newer sounds (PIX-158), generated in code in the chiptune voice
# of the rest: square, triangle and stepped noise, each note shaped and the
# whole normalised to the levels the older sounds sit at. Writes WAVs the
# game plays as they are (Godot compresses them on import):
# - sfx/: the dodge, a named monster's roar, a bounty claimed;
# - ambience/: one-shots for birds, crickets, town chatter and fire, a few
#   variants each, the looping wind beds of the mountain's floors and the
#   rain's (PIX-224);
# - music/theme_*.wav: the short story themes, from the notes in
#   assets/data/audio.json "themes".
# Seeded, so a rerun writes the same files.
#   python3 godot/tools/synth.py
import json
import math
import os
import random
import struct
import wave

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
AUDIO = os.path.join(ROOT, "assets", "audio")
FX_RATE = 44100
MUSIC_RATE = 22050
NOTES = {"C": -9, "C#": -8, "Db": -8, "D": -7, "D#": -6, "Eb": -6, "E": -5, "F": -4, "F#": -3,
         "Gb": -3, "G": -2, "G#": -1, "Ab": -1, "A": 0, "A#": 1, "Bb": 1, "B": 2}


def hz(note):
    """'A4' -> 440.0."""
    name, octave = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((NOTES[name] + 12 * (octave - 4)) / 12)


def wave_at(kind, phase, duty=0.5):
    if kind == "square":
        return 1.0 if phase < duty else -1.0
    if kind == "triangle":
        return 4.0 * abs(phase - 0.5) - 1.0
    if kind == "saw":
        return 2.0 * phase - 1.0
    return math.sin(2 * math.pi * phase)


def tone(seconds, kind, f0, f1, vol, rate, duty=0.5, attack=0.01, release=1.0, vibrato=0.0, rng=None):
    """A blip: `kind` sweeping f0 -> f1 Hz; noise steps at the frequency (low
    is a rumble, high a hiss). Attack in seconds, then a fade over the last
    `release` share of it."""
    count = int(seconds * rate)
    out = []
    phase = 0.0
    held = 0.0
    rng = rng or random.Random(1)
    for i in range(count):
        t = i / max(1, count)
        freq = f0 + (f1 - f0) * t
        if vibrato:
            freq *= 1.0 + vibrato * math.sin(2 * math.pi * 5.5 * i / rate)
        before = phase
        phase = (phase + freq / rate) % 1.0
        if kind == "noise":
            if phase < before or i == 0:
                held = rng.uniform(-1.0, 1.0)
            sample = held
        else:
            sample = wave_at(kind, phase, duty)
        env = min(1.0, (i / rate) / attack) if attack > 0 else 1.0
        if t > 1.0 - release:
            env *= (1.0 - t) / release
        out.append(sample * vol * env)
    return out


def silence(seconds, rate):
    return [0.0] * int(seconds * rate)


def mix(length, *parts):
    """Sums [(offset_seconds, samples, rate)] into one track of `length` samples."""
    out = [0.0] * length
    for offset, samples, rate in parts:
        start = int(offset * rate)
        for i, s in enumerate(samples):
            if start + i < length:
                out[start + i] += s
    return out


def write(path, samples, rate, peak, rms=None, loop=False):
    """Writes 16-bit mono at `peak` (or quieter, at `rms` for music, so a
    theme sits at the loops' loudness), the narrow squares' offset removed -
    except from a loop, whose seam the filter would open."""
    if not loop:
        out, last_in, last_out = [], 0.0, 0.0
        for s in samples:
            last_out = s - last_in + 0.995 * last_out
            last_in = s
            out.append(last_out)
        samples = out
    top = max(1e-9, max(abs(s) for s in samples))
    scale = peak / top
    if rms is not None:
        level = max(1e-9, (sum(s * s for s in samples) / len(samples)) ** 0.5)
        scale = min(scale, rms / level)
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(b"".join(struct.pack("<h", int(max(-32767, min(32767, s * scale)))) for s in samples))


# ---- effects ---------------------------------------------------------------

def dodge():
    rng = random.Random(11)
    whoosh = tone(0.17, "noise", 7000, 1400, 1.0, FX_RATE, attack=0.05, release=0.7, rng=rng)
    tail = tone(0.12, "triangle", 760, 380, 0.25, FX_RATE, attack=0.01)
    return mix(len(whoosh), (0, whoosh, FX_RATE), (0.03, tail, FX_RATE))


def roar():
    rng = random.Random(23)
    length = 0.8
    growl = tone(length, "square", 118, 58, 0.7, FX_RATE, duty=0.25, attack=0.06, release=0.5, vibrato=0.06)
    breath = tone(length, "noise", 1100, 260, 0.6, FX_RATE, attack=0.08, release=0.6, rng=rng)
    out = mix(int(length * FX_RATE), (0, growl, FX_RATE), (0, breath, FX_RATE))
    # A rattle in the throat.
    return [s * (0.75 + 0.25 * math.sin(2 * math.pi * 21 * i / FX_RATE)) for i, s in enumerate(out)]


def bounty():
    parts = []
    for i, note in enumerate(["C5", "E5", "G5"]):
        parts.append((i * 0.07, tone(0.08, "square", hz(note), hz(note), 0.5, FX_RATE, attack=0.004), FX_RATE))
    parts.append((0.21, tone(0.32, "square", hz("C6"), hz("C6"), 0.5, FX_RATE, attack=0.004, release=0.6), FX_RATE))
    parts.append((0.21, tone(0.32, "triangle", hz("C4"), hz("C4"), 0.6, FX_RATE, attack=0.004, release=0.6), FX_RATE))
    for i, note in enumerate(["G6", "C7"]):
        parts.append((0.3 + i * 0.05, tone(0.05, "triangle", hz(note), hz(note), 0.25, FX_RATE), FX_RATE))
    return mix(int(0.55 * FX_RATE), *parts)


# ---- ambience one-shots ----------------------------------------------------

def birds(seed):
    rng = random.Random(100 + seed)
    parts, at = [], 0.0
    for _ in range(rng.randint(2, 4)):
        f = rng.uniform(2300, 3500)
        up = rng.random() < 0.6
        length = rng.uniform(0.04, 0.08)
        parts.append((at, tone(length, "triangle", f, f * (1.35 if up else 0.75), 0.6, FX_RATE, attack=0.005), FX_RATE))
        at += length + rng.uniform(0.04, 0.11)
    return mix(int((at + 0.1) * FX_RATE), *parts)


def crickets(seed):
    rng = random.Random(200 + seed)
    f = rng.uniform(4200, 4900)
    parts, at = [], 0.0
    for _ in range(2):
        for _ in range(rng.randint(3, 5)):
            parts.append((at, tone(0.018, "square", f, f, 0.35, FX_RATE, attack=0.002, release=0.5), FX_RATE))
            at += 0.042
        at += rng.uniform(0.12, 0.2)
    return mix(int((at + 0.05) * FX_RATE), *parts)


def chatter(seed):
    """Two neighbours talking far off: syllables of a voice's pitch, each with
    a breath of a consonant, the second voice answering lower."""
    rng = random.Random(300 + seed)
    parts, at = [], 0.0
    for speaker in range(2):
        base = rng.uniform(190, 250) if speaker == 0 else rng.uniform(130, 170)
        for _ in range(rng.randint(3, 6)):
            length = rng.uniform(0.05, 0.11)
            f = base * rng.uniform(0.9, 1.2)
            parts.append((at, tone(0.012, "noise", 3000, 2000, 0.25, FX_RATE, attack=0.001, rng=rng), FX_RATE))
            parts.append((at + 0.01, tone(length, "triangle", f, f * rng.uniform(0.85, 1.1), 0.6, FX_RATE, attack=0.01, release=0.5), FX_RATE))
            at += length + rng.uniform(0.02, 0.06)
        at += rng.uniform(0.15, 0.3)
    return mix(int((at + 0.05) * FX_RATE), *parts)


def fire(seed):
    """A fire's crackle: pops of noise over a low hiss."""
    rng = random.Random(400 + seed)
    length = 0.7
    parts = [(0, tone(length, "noise", 1600, 1200, 0.18, FX_RATE, attack=0.1, release=0.4, rng=rng), FX_RATE)]
    at = rng.uniform(0.0, 0.08)
    while at < length - 0.05:
        pop = rng.uniform(0.004, 0.014)
        parts.append((at, tone(pop, "noise", rng.uniform(5000, 11000), 2000, rng.uniform(0.5, 1.0), FX_RATE, attack=0.0005, release=0.9, rng=rng), FX_RATE))
        at += rng.uniform(0.03, 0.16)
    return mix(int(length * FX_RATE), *parts)


# ---- beds ------------------------------------------------------------------

def wind(deep):
    """Wind on the mountain's floors: stepped noise through a slowly opening
    and closing low-pass, swelling and falling. Its moves repeat exactly
    over the loop, and the end is folded into the start so it never clicks."""
    rng = random.Random(500 + deep)
    seconds, fold = 8.0, 0.6
    count = int((seconds + fold) * MUSIC_RATE)
    low, high = (90, 380) if deep else (260, 900)
    out, level, held, phase = [], 0.0, 0.0, 0.0
    for i in range(count):
        t = i / MUSIC_RATE
        sweep = 0.5 + 0.5 * math.sin(2 * math.pi * t / 4.0) * math.sin(2 * math.pi * t / 8.0 + 1.0)
        cutoff = low + (high - low) * sweep
        before = phase
        phase = (phase + 3000 / MUSIC_RATE) % 1.0
        if phase < before:
            held = rng.uniform(-1.0, 1.0)
        alpha = 1 - math.exp(-2 * math.pi * cutoff / MUSIC_RATE)
        level += alpha * (held - level)
        gust = 0.55 + 0.45 * math.sin(2 * math.pi * t / 8.0) ** 2
        sample = level * gust
        if deep:
            sample += 0.12 * math.sin(2 * math.pi * 44 * t) * gust
        out.append(sample)
    body = out[: int(seconds * MUSIC_RATE)]
    tail = out[int(seconds * MUSIC_RATE):]
    for i, s in enumerate(tail):
        w = i / len(tail)
        body[i] = body[i] * w + s * (1 - w)
    return body


def rain():
    """A shower on the land (PIX-224): a soft hiss of fine noise, breathing
    once over the loop, under many small drops - each a short, falling tick
    of a high tone. Folded like the wind, so it loops without a click."""
    rng = random.Random(900)
    seconds, fold = 8.0, 0.6
    count = int((seconds + fold) * MUSIC_RATE)
    out, low, lower = [], 0.0, 0.0
    for i in range(count):
        t = i / MUSIC_RATE
        noise = rng.uniform(-1.0, 1.0)
        low += 0.45 * (noise - low)
        lower += 0.08 * (low - lower)
        breath = 0.85 + 0.15 * math.sin(2 * math.pi * t / seconds)
        out.append((0.55 * (low - lower) + 0.25 * lower) * breath)
    for _ in range(int((seconds + fold) * 70)):
        at = rng.randrange(0, count - 500)
        level = rng.uniform(0.08, 0.35)
        f0 = rng.uniform(2200.0, 4800.0)
        for j in range(480):
            t = j / MUSIC_RATE
            f = f0 * (1.0 - 0.35 * j / 480)
            out[at + j] += level * math.exp(-j / 55.0) * math.sin(2 * math.pi * f * t)
    body = out[: int(seconds * MUSIC_RATE)]
    tail = out[int(seconds * MUSIC_RATE):]
    for i, s in enumerate(tail):
        w = i / len(tail)
        body[i] = body[i] * w + s * (1 - w)
    return body


# ---- themes ----------------------------------------------------------------

def theme(spec):
    """A short story theme: voices of notes ("D4:1", "-:0.5" a rest, "x:1" a
    drum hit) at `bpm`, each voice its wave, duty and volume."""
    beat = 60.0 / spec["bpm"]
    parts, end = [], 0.0
    for voice in spec["voices"]:
        at = 0.0
        rng = random.Random(7)
        for token in voice["notes"].split():
            note, beats = token.split(":")
            length = float(beats) * beat
            if note == "x":
                hit = tone(min(length, 0.12), "noise", 900, 120, voice["vol"], MUSIC_RATE, attack=0.001, release=0.9, rng=rng)
                parts.append((at, hit, MUSIC_RATE))
            elif note != "-":
                f = hz(note)
                body = tone(length * 0.95, voice["wave"], f, f, voice["vol"], MUSIC_RATE, duty=voice.get("duty", 0.5),
                            attack=0.012, release=voice.get("release", 0.35), vibrato=voice.get("vibrato", 0.0))
                parts.append((at, body, MUSIC_RATE))
            at += length
        end = max(end, at)
    return mix(int((end + 0.4) * MUSIC_RATE), *parts)


def main():
    doc = json.load(open(os.path.join(ROOT, "assets", "data", "audio.json")))
    write(os.path.join(AUDIO, "sfx", "dodge.wav"), dodge(), FX_RATE, 1900)
    write(os.path.join(AUDIO, "sfx", "roar.wav"), roar(), FX_RATE, 2600)
    write(os.path.join(AUDIO, "sfx", "bounty.wav"), bounty(), FX_RATE, 2300)
    makers = {"birds": (birds, 650), "crickets": (crickets, 420), "chatter": (chatter, 520), "fire": (fire, 760)}
    for name, extra in doc["ambienceExtras"].items():
        make, peak = makers[name]
        for v in range(extra["variants"]):
            write(os.path.join(AUDIO, "ambience", "%s_%d.wav" % (name, v)), make(v), FX_RATE, peak)
    for name in doc["beds"]:
        bed, peak = (rain(), 1300) if name == "rain" else (wind(name == "deepwind"), 900)
        write(os.path.join(AUDIO, "ambience", "bed_%s.wav" % name), bed, MUSIC_RATE, peak, loop=True)
    for name, spec in doc["themes"].items():
        write(os.path.join(AUDIO, "music", "theme_%s.wav" % name), theme(spec), MUSIC_RATE, 4000, rms=520)
    print("wrote the effects, %d ambience sets, %d beds and %d themes" % (len(doc["ambienceExtras"]), len(doc["beds"]), len(doc["themes"])))


if __name__ == "__main__":
    main()
