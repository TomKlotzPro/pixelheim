"""The packs' sounds (PIX-411): the manifest names, for events the game has,
takes inside the bundle's zips; the prep levels each to its family's
loudness and never past its peak; the prepared takes stay out of git.
The takes themselves are paid and never in this repo.

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import os
import re
import unittest
import zipfile

import sound_prep

GODOT = sound_prep.GODOT
# The bundle's zips, where Tom keeps them (PIX-413).
ZIPS = os.environ.get("LEOHPAZ_ZIPS", os.path.expanduser("~/playground/leohpaz-sfx"))


class SoundPrepTest(unittest.TestCase):
    def setUp(self):
        self.manifest = sound_prep.load(sound_prep.MANIFEST)
        self.audio = sound_prep.load(sound_prep.AUDIO)

    def test_every_take_is_an_events_from_a_zip(self):
        for event, sources in self.manifest["events"].items():
            self.assertIn(event, self.audio["events"], "%s: no such event" % event)
            self.assertTrue(sources, event)
            if isinstance(sources, str):
                # PIX-413: an event sharing another's takes names one that has its own.
                self.assertIsInstance(self.manifest["events"].get(sources), list, "%s shares %s's" % (event, sources))
                # Levelled to that one's family, so of the same family.
                self.assertEqual(self.audio["events"][event]["family"], self.audio["events"][sources]["family"], event)
                continue
            for source in sources:
                self.assertIn(len(source), (2, 3), "%s: [zip, path inside it, how to cut it]" % event)
                zip_name, member = source[:2]
                self.assertEqual(os.path.basename(zip_name), zip_name, event)
                self.assertTrue(zip_name.endswith(".zip"), event)
                self.assertRegex(member.lower(), r"\.(wav|ogg)$", event)
                self.assertNotIn("..", member, event)
                options = source[2] if len(source) > 2 else {}
                self.assertLessEqual(set(options), {"keep", "loop", "pitch", "lowpass", "db"}, event)
            self.assertEqual(len({tuple(s[:2]) for s in sources}), len(sources), "%s: a take twice" % event)

    def test_every_take_is_in_its_zip(self):
        # PIX-413: read by name, so a typo would only show at the prep.
        if not os.path.isdir(ZIPS):
            self.skipTest("the bundle's zips aren't here (%s)" % ZIPS)
        members = {}
        for _, name, zip_name, member, _ in sound_prep.takes(self.manifest):
            if zip_name not in members:
                with zipfile.ZipFile(os.path.join(ZIPS, zip_name)) as archive:
                    members[zip_name] = set(archive.namelist())
            self.assertIn(member, members[zip_name], name)

    def test_no_take_may_hold_words(self):
        # PIX-413: the game speaks English and French, so no voiced line,
        # crier, song, laugh or scream.
        words = re.compile(r"(?<![a-z])(voiced?|crier|songs?|sing(ing)?|laugh\w*|scream\w*|speech|talk\w*)(?![a-z])", re.I)
        for _, name, _, member, _ in sound_prep.takes(self.manifest):
            self.assertIsNone(words.search(member), "%s: %s" % (name, member))

    def test_footsteps_fill_every_ground(self):
        steps = set(self.audio["steps"].values())
        self.assertEqual(len(steps), 8)
        for event in steps:
            sources = self.manifest["events"].get(event, [])
            sources = self.manifest["events"][sources] if isinstance(sources, str) else sources
            self.assertGreaterEqual(len(sources), 3, "%s: takes from the packs" % event)

    def test_each_take_is_named_by_its_event(self):
        names = [take[1] for take in sound_prep.takes(self.manifest)]
        self.assertEqual(len(names), len(set(names)))
        self.assertIn("step_grass_1", names)

    def test_a_take_is_cut_to_its_body(self):
        # PIX-413: kept to its seconds, the tail faded; a bed looped; a bull lower.
        kept = sound_prep.cut({"keep": 0.4})
        self.assertEqual(kept, ["atrim=end=0.400,afade=t=out:st=0.280:d=0.120"])
        self.assertIn("asetrate=35280", sound_prep.cut({"pitch": 0.8})[0])
        # Kept by the source's seconds: a bull's moo as long as the cow's, slower.
        self.assertEqual(sound_prep.cut({"keep": 0.4, "pitch": 0.8})[1], "atrim=end=0.500,afade=t=out:st=0.350:d=0.150")
        self.assertEqual(sound_prep.cut({}), [])
        self.assertIn("concat", sound_prep.loop_graph(12.0))
        for event, sources in self.manifest["events"].items():
            if isinstance(sources, str):
                continue
            for source in sources:
                options = source[2] if len(source) > 2 else {}
                # Every one cut: a take with no "keep" would play its whole length.
                if event.startswith("cast_") or event.startswith("impact_"):
                    self.assertIn("keep", options, event)
                    self.assertLessEqual(options["keep"], 0.6, "%s: long magic cut" % event)
                if event in ("step_snow", "step_mud"):
                    self.assertIn("keep", options, event)
                    self.assertLessEqual(options["keep"], 0.15, event)
                if self.audio["events"][event]["family"] == "ambience":
                    self.assertIn("loop", options, "%s: a bed loops" % event)

    def test_the_takes_stay_small(self):
        # PIX-413: some 15 MB of 16-bit mono, each family at its own rate.
        size = 0
        for event, _, _, _, options in sound_prep.takes(self.manifest):
            rate = self.audio["families"][self.audio["events"][event]["family"]].get("rate", sound_prep.RATE)
            size += float(options.get("keep", options.get("loop", 1.0))) * rate * 2
        self.assertLess(size, 16 * 1024 * 1024)

    def test_a_take_comes_to_its_familys_loudness_never_past_its_peak(self):
        family = {"loudness": -37, "peak": -18}
        self.assertEqual(sound_prep.gain_for(-12, -6, family), -25, "loud and even: to the loudness")
        self.assertEqual(sound_prep.gain_for(-30, -1, family), -17, "a sharp one: held under the peak")
        for name, family in self.audio["families"].items():
            self.assertLess(family["loudness"], family["peak"], name)

    def test_it_reads_ffmpegs_log(self):
        log = ("t: 0.4 TARGET:-23 LUFS    M: -38.7 S:-120.7\n"
               "t: 0.5 TARGET:-23 LUFS    M: -89.5 S:-120.7\n"
               "  Sample peak:\n    Peak:      -18.4 dBFS\n")
        self.assertEqual(sound_prep.measured(log), (-38.7, -18.4))
        with self.assertRaises(ValueError):
            sound_prep.measured("  Sample peak:\n    Peak:       -inf dBFS\n")

    def test_it_reads_only_a_zip_by_its_own_name(self):
        with self.assertRaises(ValueError):
            sound_prep.read_member("/nowhere", "../elsewhere.zip", "a.wav", "/nowhere/out")

    def test_the_prepared_takes_stay_out_of_git(self):
        with open(os.path.join(GODOT, ".gitignore"), encoding="utf-8") as file:
            self.assertIn("/assets/audio/paid", file.read().split())
        with open(os.path.join(GODOT, "..", "scripts", "fetch-private-art.sh"), encoding="utf-8") as file:
            self.assertIn("godot/assets/audio/paid/", file.read())


    def test_it_never_writes_paid_takes_where_git_tracks_them(self):
        with self.assertRaises(ValueError):
            sound_prep.refuse_public(os.path.join(GODOT, "assets", "audio", "sfx"))
        sound_prep.refuse_public(os.path.join(GODOT, "assets", "audio", "paid"))
        sound_prep.refuse_public("/tmp/elsewhere")


if __name__ == "__main__":
    unittest.main()
