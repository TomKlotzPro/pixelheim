#!/usr/bin/env python3
"""The prep pass that turns Leohpaz's sound packs into the takes the game
plays (PIX-411), as tools/ui_kit_prep.gd does GegX's UI kit.

For each take godot/assets/audio/paid.json names (an event, then the zip it
is in and its path inside), this reads the file straight out of the zip,
makes it mono at 44.1 kHz, trims the silence before and after it, and brings
it to its family's loudness in godot/assets/data/audio.json's "families" (the
400 ms max, as the audio pass measured the game's own), never past the
family's peak: the packs sit near -1 dBFS, and every bus plays 14 dB over
its renders (Sound.LOUDNESS_DB). It writes <event>_<n>.wav, 16-bit, and
takes.json, the list the game reads them by (each event's takes, each take's
peak, loudness, length and source). Godot compresses them on import as it
does the game's own sounds.

The packs are paid and may not be redistributed, modified or not: write the
takes outside this repo, into the private pixelheim-assets repo
(retro-rpg/leohpaz/pixelheim/); scripts/fetch-private-art.sh installs them.
The zips are downloads: run this with -I, and it reads only the members the
manifest names, by name, never extracting a zip.

    python3 -I godot/tools/sound_prep.py <zips> <out>

<zips> is the folder of the bundle's zips (~/playground/leohpaz-sfx).
Needs ffmpeg.
"""
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
import zipfile

GODOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MANIFEST = os.path.join(GODOT, "assets", "audio", "paid.json")
AUDIO = os.path.join(GODOT, "assets", "data", "audio.json")
RATE = 44100
# A member bigger than this is no sound effect (a zip bomb, a whole album).
LARGEST = 64 * 1024 * 1024
# Silence: under this, before the take starts and after it has rung out.
LEAD_DB = -60
TAIL_DB = -70
# What a take may come out over its family's peak (16-bit rounding).
SLACK_DB = 0.1


def load(path):
    with open(path, encoding="utf-8") as file:
        return json.load(file)


def takes(manifest):
    """[(event, name, zip, path)] in the manifest's order, each named <event>_<n>."""
    out = []
    for event, sources in manifest["events"].items():
        for n, (zip_name, member) in enumerate(sources, 1):
            out.append((event, "%s_%d" % (event, n), zip_name, member))
    return out


def gain_for(loudness, peak, family):
    """dB that brings a take to its family's loudness, never past its peak."""
    return min(family["loudness"] - loudness, family["peak"] - peak)


def measured(log):
    """(the 400 ms max in LUFS, the sample peak in dBFS) from ffmpeg's ebur128 log."""
    moments = [float(m) for m in re.findall(r"M:\s*(-?\d+(?:\.\d+)?)", log)]
    peak = re.search(r"Sample peak:\s+Peak:\s+(-?\d+(?:\.\d+)?|-inf)", log)
    if not moments or peak is None or peak.group(1) == "-inf":
        raise ValueError("no loudness in the log: a silent take?")
    return max(moments), float(peak.group(1))


def ffmpeg(*args):
    return subprocess.run(["ffmpeg", "-hide_banner", "-nostdin", "-y"] + list(args), capture_output=True, text=True, check=True).stderr


def measure(path):
    """(loudness, peak, seconds): padded so a short take fills the 400 ms window."""
    log = ffmpeg("-v", "verbose", "-i", path, "-af", "apad=pad_dur=0.5,ebur128=peak=sample:framelog=verbose", "-f", "null", "-")
    loudness, peak = measured(log)
    probe = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                           capture_output=True, text=True, check=True).stdout
    return loudness, peak, float(probe)


def read_member(zips, zip_name, member, into):
    """The member's bytes written to `into`, read by name out of the zip."""
    if os.path.basename(zip_name) != zip_name or not zip_name.endswith(".zip"):
        raise ValueError("%s: a zip's own name, in the zips' folder" % zip_name)
    with zipfile.ZipFile(os.path.join(zips, zip_name)) as archive:
        info = archive.getinfo(member)
        if info.file_size > LARGEST:
            raise ValueError("%s in %s: %d bytes" % (member, zip_name, info.file_size))
        with open(into, "wb") as file:
            file.write(archive.read(info))


def prepare(zips, out):
    families = load(AUDIO)["families"]
    events = load(AUDIO)["events"]
    manifest = load(MANIFEST)
    os.makedirs(out, exist_ok=True)
    for old in glob.glob(os.path.join(out, "*.wav")) + glob.glob(os.path.join(out, "takes.json")):
        os.remove(old)
    listed = {"events": {}, "takes": {}}
    trim = "silenceremove=start_periods=1:start_threshold=%ddB,areverse,silenceremove=start_periods=1:start_threshold=%ddB,areverse" % (LEAD_DB, TAIL_DB)
    with tempfile.TemporaryDirectory() as work:
        for event, name, zip_name, member in takes(manifest):
            family = families[events[event]["family"]]
            source = os.path.join(work, "source" + os.path.splitext(member)[1].lower())
            read_member(zips, zip_name, member, source)
            trimmed = os.path.join(work, name + ".wav")
            ffmpeg("-i", source, "-ac", "1", "-ar", str(RATE), "-af", trim, "-c:a", "pcm_f32le", trimmed)
            loudness, peak, _ = measure(trimmed)
            gain = gain_for(loudness, peak, family)
            made = os.path.join(out, name + ".wav")
            ffmpeg("-i", trimmed, "-af", "volume=%.2fdB" % gain, "-c:a", "pcm_s16le", made)
            loudness, peak, seconds = measure(made)
            if peak > family["peak"] + SLACK_DB:
                raise ValueError("%s came out at %.1f dBFS, over its family's %s" % (name, peak, family["peak"]))
            listed["events"].setdefault(event, []).append(name)
            listed["takes"][name] = {"loudness": round(loudness, 1), "peak": round(peak, 1), "seconds": round(seconds, 3),
                                     "from": "%s/%s" % (zip_name, member)}
            print("%-18s %6.1f LUFS %6.1f dBFS %5.2fs  %s/%s" % (name, loudness, peak, seconds, zip_name, member))
    with open(os.path.join(out, "takes.json"), "w", encoding="utf-8") as file:
        json.dump(listed, file, indent=1)
        file.write("\n")
    return listed


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: python3 -I godot/tools/sound_prep.py <zips> <out>")
    made = prepare(sys.argv[1], sys.argv[2])
    print("%d takes for %d events in %s" % (len(made["takes"]), len(made["events"]), sys.argv[2]))
