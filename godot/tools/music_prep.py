#!/usr/bin/env python3
"""The prep pass that turns Leohpaz's RPG music bundle into the tracks the
game plays (PIX-416), as tools/sound_prep.py does his sounds.

For each slot godot/assets/audio/paid_music.json names (a track of
audio.json's "tracks", or a story theme as "theme_<name>"), this pipes the
file straight out of its zip into ffmpeg, never extracting one, puts its
intro before it if it has one (cut at the bundle's handover, where the loop
starts: loopBegin), brings it to the manifest's "loudness" (integrated LUFS)
never past its "peak" (true peak), and encodes it as stereo Ogg Vorbis at
the manifest's "quality": music_<slot>.ogg, with music.json, the list the
game reads them by (each slot's file, loopBegin, length, loudness, peak,
size and source).

Vorbis, not MP3: both loop in Godot with no gap and no click (decoded
around the loop point against the source, PIX-416's PR), but Godot starts
an MP3 part-way in by decoding up to there, on the main thread: a place's
track taken up where it was left cost 15 to 70 ms a change of place, where
a Vorbis one costs 1 to 2. The only Vorbis encoder this machine's ffmpeg has
is its own (experimental, stereo only), and it rounds a track's length up to
64 samples, padding its end: a loop would play the pad. So each track is
first made a whole number of 64 samples long with its loop's own next
samples (its loopBegin moved past them, so the loop goes on exactly where
the pad ends), a theme with silence.

The bundle may not be redistributed: write the tracks to the private
pixelheim-assets repo (retro-rpg/leohpaz/music/), never this one;
scripts/fetch-private-art.sh installs them. Run it with -I: the zips are
downloads.

    python3 -I godot/tools/music_prep.py <zips> <out>

<zips> is the folder of the bundle's zips (~/playground/leohpaz-music/zips).
Needs ffmpeg.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import zipfile

# Run with -I, Python leaves this folder off its path: sound_prep beside it is ours.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sound_prep  # noqa: E402

MANIFEST = os.path.join(sound_prep.GODOT, "assets", "audio", "paid_music.json")
RATE = 44100
# The Vorbis encoder pads a track's end up to a multiple of this.
BLOCK = 64
# A member bigger than this is no track (the bundle's longest WAV is 60 MiB).
LARGEST = 128 * 1024 * 1024
# What a track may come out over the manifest's peak (the encoder's rounding).
SLACK_DB = 0.2


def slots(manifest, audio):
    """The manifest's slots this build plays: a track, or a story theme as
    theme_<name>; one it doesn't know yet is no slot of this build's."""
    known = set(audio["tracks"]) | {"theme_" + name for name in audio["themes"]}
    return [slot for slot in manifest["tracks"] if slot in known]


def piped(zips, zip_name, member, into):
    """The member, read by name out of its zip, decoded by ffmpeg from a pipe
    into `into` (32-bit float, stereo, 44.1 kHz): no file of the zip's is
    ever written."""
    if os.path.basename(zip_name) != zip_name or not zip_name.endswith(".zip"):
        raise ValueError("%s: a zip's own name, in the zips' folder" % zip_name)
    with zipfile.ZipFile(os.path.join(zips, zip_name)) as archive:
        info = archive.getinfo(member)
        if info.file_size > LARGEST:
            raise ValueError("%s in %s: %d bytes" % (member, zip_name, info.file_size))
        data = archive.read(info)
    subprocess.run(["ffmpeg", "-hide_banner", "-nostdin", "-y", "-v", "error", "-i", "pipe:0", "-ac", "2", "-ar", str(RATE),
                    "-c:a", "pcm_f32le", into], input=data, check=True)


def joined(handover, intro_frames):
    """The filter graph that plays the intro (input 0) up to `handover`
    samples, then the loop (input 1). An intro ringing on past its handover
    is refused: cut there, its tail would be lost (PIX-416 review)."""
    # shortcut: no tail kept; to pick one, ring it over the loop's first pass only (mixed into the
    # loop's start, the loop rotated by the tail's length), never into every pass.
    if intro_frames > handover + RATE // 100:
        raise ValueError("the intro rings %.2f s past its handover: its tail would be cut" % ((intro_frames - handover) / RATE))
    return "[0:a]atrim=end_sample=%d,asetpts=PTS-STARTPTS[intro];[intro][1:a]concat=n=2:v=0:a=1[out]" % handover


def rounded(frames, loop_begin, looped):
    """(the samples that make `frames` a whole number of BLOCKs, the filter
    graph adding them): a loop's own next ones after its loopBegin, so it
    goes on from there seamlessly, at least one (a loop back to the very
    first sample decoded worse for some 20 ms than one landing past it), or
    a theme's silence."""
    if not looped:
        pad = -frames % BLOCK
        return pad, "[0:a]apad=pad_len=%d[out]" % pad
    pad = BLOCK - frames % BLOCK
    return pad, ("[0:a]asplit[a][b];[b]atrim=start_sample=%d:end_sample=%d,asetpts=PTS-STARTPTS[pad];"
                 "[a][pad]concat=n=2:v=0:a=1[out]") % (loop_begin, loop_begin + pad)


def gain_for(loudness, peak, manifest):
    """dB that brings a track to the music's loudness, never past its peak."""
    return min(manifest["loudness"] - loudness, manifest["peak"] - peak)


def summary(log):
    """(integrated LUFS, true peak dBTP) from ffmpeg's ebur128 summary."""
    tail = log[log.rindex("Summary:"):]
    loudness = re.search(r"I:\s+(-?\d+(?:\.\d+)?) LUFS", tail)
    peak = re.search(r"Peak:\s+(-?\d+(?:\.\d+)?|-inf) dBFS", tail)
    if loudness is None or peak is None or peak.group(1) == "-inf":
        raise ValueError("no loudness in the log: a silent track?")
    return float(loudness.group(1)), float(peak.group(1))


def frames_of(path):
    """The samples a file holds, as its stream counts them (a Vorbis file's
    last granule, the length Godot loops at)."""
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=duration_ts",
                          "-of", "csv=p=0", path], capture_output=True, text=True, check=True).stdout
    return int(out.strip())


def measure(path):
    """(loudness, true peak) as decoded."""
    return summary(sound_prep.ffmpeg("-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"))


def prepare(zips, out):
    manifest = sound_prep.load(MANIFEST)
    audio = sound_prep.load(sound_prep.AUDIO)
    sound_prep.refuse_public(out)
    os.makedirs(out, exist_ok=True)
    for old in os.listdir(out):
        if old.startswith("music_") and old.endswith(".ogg") or old == "music.json":
            os.remove(os.path.join(out, old))
    listed = {"tracks": {}}
    with tempfile.TemporaryDirectory() as work:
        for slot in slots(manifest, audio):
            entry = manifest["tracks"][slot]
            source = os.path.join(work, slot + ".wav")
            piped(zips, entry["from"][0], entry["from"][1], source)
            loop_begin = 0
            if "intro" in entry:
                intro = os.path.join(work, "intro.wav")
                piped(zips, entry["intro"][0], entry["intro"][1], intro)
                loop_begin = round(float(entry["intro"][2]) * RATE)
                whole = os.path.join(work, slot + "_joined.wav")
                sound_prep.ffmpeg("-i", intro, "-i", source, "-filter_complex", joined(loop_begin, frames_of(intro)), "-map", "[out]",
                                  "-c:a", "pcm_f32le", whole)
                source = whole
            looped = not slot.startswith("theme_")
            pad, graph = rounded(frames_of(source), loop_begin, looped)
            whole = os.path.join(work, slot + "_whole.wav")
            sound_prep.ffmpeg("-i", source, "-filter_complex", graph, "-map", "[out]", "-c:a", "pcm_f32le", whole)
            frames = frames_of(whole)
            if looped:
                loop_begin += pad
            loudness, peak = measure(whole)
            gain = gain_for(loudness, peak, manifest)
            made = os.path.join(out, "music_%s.ogg" % slot)
            for _ in range(3):
                # Bit-exact: the same file every run, no random stream serial.
                sound_prep.ffmpeg("-i", whole, "-af", "volume=%.2fdB" % gain, "-c:a", "vorbis", "-strict", "-2",
                                  "-q:a", str(manifest["quality"]), "-fflags", "+bitexact", "-flags:a", "+bitexact", made)
                loudness, peak = measure(made)
                # The encoder's own overshoot: once more, that much lower.
                if peak <= manifest["peak"] + SLACK_DB:
                    break
                gain -= peak - manifest["peak"]
            else:
                raise ValueError("%s came out at %.1f dBTP, over the music's %s" % (slot, peak, manifest["peak"]))
            if frames_of(made) != frames:
                raise ValueError("%s: %d samples encoded as %d: its loop would play the pad" % (slot, frames, frames_of(made)))
            listed["tracks"][slot] = {"file": os.path.basename(made), "loopBegin": loop_begin / RATE, "seconds": frames / RATE,
                                      "loudness": round(loudness, 1), "peak": round(peak, 1), "bytes": os.path.getsize(made),
                                      "from": "%s/%s" % tuple(entry["from"])}
            print("%-18s %6.1f LUFS %6.1f dBTP %8.3fs %5.2f MiB  %s" % (slot, loudness, peak, frames / RATE, os.path.getsize(made) / 2 ** 20, entry["from"][1]))
    with open(os.path.join(out, "music.json"), "w", encoding="utf-8") as file:
        json.dump(listed, file, indent=1)
        file.write("\n")
    return listed


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: python3 -I godot/tools/music_prep.py <zips> <out>")
    made = prepare(sys.argv[1], sys.argv[2])
    total = sum(track["bytes"] for track in made["tracks"].values())
    print("%d tracks, %.1f MiB, in %s" % (len(made["tracks"]), total / 2 ** 20, sys.argv[2]))
