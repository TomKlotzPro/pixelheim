"""The packs' sounds (PIX-411): the manifest names, for events the game has,
takes inside the bundle's zips; the prep levels each to its family's
loudness and never past its peak; the prepared takes stay out of git.
The takes themselves are paid and never in this repo.

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import json
import os
import unittest

import sound_prep

GODOT = sound_prep.GODOT


class SoundPrepTest(unittest.TestCase):
    def setUp(self):
        self.manifest = sound_prep.load(sound_prep.MANIFEST)
        self.audio = sound_prep.load(sound_prep.AUDIO)

    def test_every_take_is_an_events_from_a_zip(self):
        for event, sources in self.manifest["events"].items():
            self.assertIn(event, self.audio["events"], "%s: no such event" % event)
            self.assertTrue(sources, event)
            for source in sources:
                self.assertEqual(len(source), 2, "%s: [zip, path inside it]" % event)
                zip_name, member = source
                self.assertEqual(os.path.basename(zip_name), zip_name, event)
                self.assertTrue(zip_name.endswith(".zip"), event)
                self.assertRegex(member.lower(), r"\.(wav|ogg)$", event)
                self.assertNotIn("..", member, event)
            self.assertEqual(len(set(map(tuple, sources))), len(sources), "%s: a take twice" % event)

    def test_footsteps_fill_every_ground(self):
        steps = set(self.audio["steps"].values())
        self.assertEqual(len(steps), 8)
        for event in steps:
            self.assertGreaterEqual(len(self.manifest["events"].get(event, [])), 3, "%s: takes from the packs" % event)

    def test_each_take_is_named_by_its_event(self):
        names = [name for _, name, _, _ in sound_prep.takes(self.manifest)]
        self.assertEqual(len(names), len(set(names)))
        self.assertIn("step_grass_1", names)

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


if __name__ == "__main__":
    unittest.main()
