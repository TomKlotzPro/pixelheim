"""Tests for play.py (PIX-423): the keys an agent types read as the
bridge's steps, and `start`'s options as the game's command line.

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import contextlib
import io
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import play  # noqa: E402


class KeysTest(unittest.TestCase):
    def test_a_hold_a_tap_and_a_wait(self):
        self.assertEqual(play.parse_keys("right:1.2, e, wait:2"), [
            {"keys": ["right"], "seconds": 1.2},
            {"keys": ["e"], "seconds": None},
            {"keys": [], "seconds": 2.0},
        ])

    def test_keys_held_together(self):
        self.assertEqual(play.parse_keys("up+left:0.5"), [{"keys": ["up", "left"], "seconds": 0.5}])

    def test_the_harness_names_read_as_godots(self):
        self.assertEqual([step["keys"] for step in play.parse_keys("esc, Esc, pgup, pgdn")],
                         [["Escape"], ["Escape"], ["PageUp"], ["PageDown"]])

    def test_a_letter_keeps_its_case_for_a_name_typed(self):
        self.assertEqual([step["keys"] for step in play.parse_keys("R,o,b")], [["R"], ["o"], ["b"]])

    def test_spaces_and_empty_parts_are_skipped(self):
        self.assertEqual(len(play.parse_keys(" e ,, esc , ")), 2)

    def test_what_cannot_be_played_is_refused(self):
        for text in ("", " , ", "right:soon", "right:-1", "wait", "up+:1", ":1"):
            with self.assertRaises(ValueError, msg=text):
                play.parse_keys(text)


class StartTest(unittest.TestCase):
    def args(self, *argv):
        return play.game_args(play.parser().parse_args(["start", *argv]))

    def test_a_plain_launch_from_the_title(self):
        self.assertEqual(self.args(), ["--fixed-fps", "60", "--", "play"])
        self.assertEqual(self.args("--lang", "fr"), ["--fixed-fps", "60", "--", "play"], "the browser's language says it")

    def test_presets_make_a_harness_run_that_stays_up(self):
        self.assertEqual(self.args("--lang", "fr", "--role", "mage", "--level", "5", "--map", "overworld", "--at", "93,33"), [
            "--fixed-fps", "60", "--", "--screenshot", "play", "--lang", "fr",
            "--role", "mage", "--level", "5", "--map", "overworld", "--at", "93,33"])

    def test_more_harness_flags_after_the_presets(self):
        self.assertEqual(self.args("--level", "8", "--flags", "fight --foe orc --foe-distance 3")[4:], [
            "play", "--level", "8", "fight", "--foe", "orc", "--foe-distance", "3"])

    def test_every_command_finds_its_session_by_port(self):
        self.assertEqual(play.parser().parse_args(["look"]).port, play.FIRST_PORT)
        self.assertEqual(play.parser().parse_args(["keys", "e", "--port", "9000"]).port, 9000)
        self.assertIsNone(play.parser().parse_args(["start"]).port, "start finds a free one")

    def test_keys_are_required(self):
        with self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
            play.parser().parse_args(["keys"])


if __name__ == "__main__":
    unittest.main()
