"""The bundle's music (PIX-416): the manifest gives every track and story
theme a retro track out of the bundle's zips, with its runner-up and why;
the prep pads a loop with its own next samples, levels within the peak and
leaves out a slot this build doesn't play. The tracks themselves are paid
and never in this repo.

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import os
import re
import unittest
import zipfile

import music_prep

# The bundle's zips, where Tom keeps them.
ZIPS = os.environ.get("LEOHPAZ_MUSIC_ZIPS", os.path.expanduser("~/playground/leohpaz-music/zips"))


class MusicPrepTest(unittest.TestCase):
    def setUp(self):
        self.manifest = music_prep.sound_prep.load(music_prep.MANIFEST)
        self.audio = music_prep.sound_prep.load(music_prep.sound_prep.AUDIO)

    def sources(self):
        for slot, entry in self.manifest["tracks"].items():
            yield slot, entry["from"]
            if "intro" in entry:
                yield slot, entry["intro"][:2]

    def test_every_slot_has_a_track(self):
        slots = set(self.audio["tracks"]) | {"theme_" + theme for theme in self.audio["themes"]}
        self.assertEqual(sorted(slots - set(self.manifest["tracks"])), [], "slots the bundle plays nothing for")
        self.assertEqual(sorted(set(self.manifest["tracks"]) - slots), [], "picks for no slot")
        for slot, entry in self.manifest["tracks"].items():
            self.assertLessEqual(set(entry), {"from", "intro", "runnerUp", "why"}, slot)
            self.assertTrue(entry["runnerUp"] and entry["why"], "%s: its runner-up and why" % slot)
            if "intro" in entry:
                self.assertGreater(entry["intro"][2], 0, "%s: the handover, in seconds" % slot)

    def test_every_track_is_a_retro_one_from_a_zip(self):
        for slot, (zip_name, member) in self.sources():
            self.assertEqual(os.path.basename(zip_name), zip_name, slot)
            self.assertRegex(zip_name, r"^LEOHPAZ_RPG-Music.*_Retro\.zip$", "%s: the retro versions, to match the pixel art" % slot)
            self.assertRegex(member.lower(), r"\.(wav|ogg)$", slot)
            self.assertNotIn("..", member, slot)

    def test_every_track_is_in_its_zip(self):
        if not os.path.isdir(ZIPS):
            self.skipTest("the bundle's zips aren't here (%s)" % ZIPS)
        members = {}
        for slot, (zip_name, member) in self.sources():
            if zip_name not in members:
                with zipfile.ZipFile(os.path.join(ZIPS, zip_name)) as archive:
                    members[zip_name] = set(archive.namelist())
            self.assertIn(member, members[zip_name], slot)

    def test_no_track_may_hold_words(self):
        # The game speaks English and French: no singing, no choir.
        words = re.compile(r"(?<![a-z])(voiced?|vocals?|songs?|sing(ing)?|choir|(?<!no_)chorus|lyrics?)(?![a-z])", re.I)
        for slot, (_, member) in self.sources():
            self.assertIsNone(words.search(member), "%s: %s" % (slot, member))

    def test_a_loop_is_padded_with_its_own_next_samples(self):
        # The encoder pads a track's end up to 64 samples: a loop's pad is
        # its own next samples after its loopBegin, at least one.
        pad, graph = music_prep.rounded(100, 0, True)
        self.assertEqual(pad, 28)
        self.assertIn("atrim=start_sample=0:end_sample=28", graph)
        pad, graph = music_prep.rounded(128, 70, True)
        self.assertEqual(pad, 64, "never a loop back to its first sample")
        self.assertIn("atrim=start_sample=70:end_sample=134", graph)
        # A theme plays once: silence, and none where none is needed.
        self.assertEqual(music_prep.rounded(100, 0, False), (28, "[0:a]apad=pad_len=28[out]"))
        self.assertEqual(music_prep.rounded(128, 0, False)[0], 0)

    def test_an_intro_is_never_cut_short(self):
        # Frost's intro ends on its handover; one ringing on past it is refused.
        self.assertIn("atrim=end_sample=705600", music_prep.joined(705600, 705600))
        with self.assertRaises(ValueError):
            music_prep.joined(476280, 542430)

    def test_a_track_is_levelled_within_its_peak(self):
        manifest = {"loudness": -34.5, "peak": -15.5}
        self.assertEqual(music_prep.gain_for(-20.0, -6.0, manifest), -14.5)
        self.assertEqual(music_prep.gain_for(-20.0, 0.0, manifest), -15.5, "a loud peak holds it lower")
        self.assertLess(music_prep.gain_for(-30.0, -1.0, manifest), -4.5)

    def test_a_slot_this_build_lacks_is_left_out(self):
        # The private repo may run ahead of a branch: its new slot is skipped.
        manifest = {"tracks": {"town": {}, "theme_dawn": {}, "a_place_to_come": {}}}
        self.assertEqual(music_prep.slots(manifest, self.audio), ["town", "theme_dawn"])

    def test_the_tracks_stay_out_of_this_repo(self):
        with self.assertRaises(ValueError):
            music_prep.sound_prep.refuse_public(os.path.join(music_prep.sound_prep.GODOT, "assets", "audio", "music"))


if __name__ == "__main__":
    unittest.main()
