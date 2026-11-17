"""The loading screen's live points (PIX-517), as tools/splash.py wrote them
into web/shell.html: the courier and the lamps on the road, the page's words
in both languages with a letter cut for every one of theirs, each line
fitting the picture, the French in the house style; and the page itself
small. Read off the shell, so they run without Pillow; with it, the shell
and the picture are checked against splash.py too.

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import importlib.util
import json
import os
import re
import subprocess
import sys
import unittest

TOOLS = os.path.dirname(os.path.abspath(__file__))
SHELL = os.path.join(TOOLS, "..", "web", "shell.html")
PICTURE = os.path.join(TOOLS, "..", "assets", "splash.png")
W, H = 640, 360


def scene():
    with open(SHELL, encoding="utf-8") as shell:
        page = shell.read()
    return json.loads(re.search(r"^const SCENE = (\{.*\});$", page, re.M).group(1))


def lines(words):
    return words["tips"] + [words[key] for key in sorted(words) if key != "tips"]


class SplashTest(unittest.TestCase):
    def setUp(self):
        self.scene = scene()

    def wide(self, line):
        return sum(self.scene["glyphs"][letter][0] for letter in line)

    def test_the_courier_walks_the_road_past_every_lamp(self):
        poses = self.scene["courier"]
        self.assertEqual(sorted(poses), ["pass", "stand", "stride"])
        sizes = {(len(rows[0]), len(rows)) for rows in poses.values()}
        self.assertEqual(len(sizes), 1, "every pose the same size: the courier doesn't jump")
        wide, high = sizes.pop()
        for rows in poses.values():
            self.assertEqual({len(row) for row in rows}, {wide})
            self.assertLessEqual(set("".join(rows)) - {"."}, set(self.scene["ink"]), "every letter has its colour")
        road, lamps = self.scene["road"], self.scene["lamps"]
        self.assertGreaterEqual(road["from"], 0)
        self.assertLessEqual(road["to"] + wide, W, "the courier ends the walk in the picture")
        self.assertGreater(road["y"] - high, 320, "on the street, under the houses")
        self.assertLess(lamps["y"], H)
        self.assertEqual(lamps["xs"], sorted(lamps["xs"]))
        self.assertGreater(lamps["xs"][0], road["from"] + wide, "no lamp lit before a byte has arrived")
        self.assertLessEqual(lamps["xs"][-1], road["to"] + wide, "the last lamp lit by the end")
        self.assertGreaterEqual(len(lamps["xs"]), 10, "a lamp for every step of the way")

    def test_the_water_and_the_torches_are_in_the_picture(self):
        left, top, right, bottom = self.scene["lake"]
        self.assertTrue(0 <= left < right <= W and 0 <= top < bottom <= H)
        for x, y in self.scene["torches"] + self.scene["chimneys"] + [self.scene["summit"]]:
            self.assertTrue(0 <= x < W and 0 <= y < H)

    def test_both_languages_say_the_same_things(self):
        english, french = self.scene["words"]["en"], self.scene["words"]["fr"]
        self.assertEqual(sorted(english), sorted(french))
        self.assertEqual(len(english["tips"]), len(french["tips"]))
        self.assertGreaterEqual(len(english["tips"]), 6, "enough lines for a minute's wait")
        for words in (english, french):
            self.assertEqual(len(set(lines(words))), len(lines(words)), "no line twice")
            for line in lines(words):
                self.assertTrue(line.strip() == line and line != "")

    def test_every_line_has_its_letters_and_fits(self):
        glyphs = self.scene["glyphs"]
        for code in range(32, 127):
            self.assertIn(chr(code), glyphs, "the engine's own error may say anything")
        self.assertIn("…", glyphs, "a long error ends on an ellipsis")
        for glyph in glyphs.values():
            self.assertEqual(len(glyph), 12, "its advance and 11 rows")
        for words in self.scene["words"].values():
            for line in words["tips"] + [words["stalled"]]:
                self.assertLessEqual(set(line), set(glyphs), line)
                self.assertLessEqual(self.wide(line), self.scene["line"], line)
            for line in (words["failed"], words["again"], words["missing"]):
                self.assertLessEqual(set(line), set(glyphs), line)
                self.assertLessEqual(self.wide(line), self.scene["notice"], line)
        self.assertLess(self.scene["line"], W * 2 / 3, "a line fits a window two thirds the picture's size, a letter's pixel a screen's")
        self.assertLess(self.scene["notice"], 360, "inside the notice's plate")

    def test_the_french_is_in_the_house_style(self):
        for line in lines(self.scene["words"]["fr"]):
            self.assertIsNone(re.search(r"[  ](?=[:;!?])|(?<=[^\s ])[:;!?]", line), "U+202F before : ; ! ? in: %s" % line)
            self.assertNotIn("’", line, "straight apostrophes")

    def test_the_page_is_small(self):
        # The loading screen is the page and its picture: under 200 KB.
        self.assertLess(os.path.getsize(SHELL) + os.path.getsize(PICTURE), 200 * 1024)

    @unittest.skipUnless(importlib.util.find_spec("PIL"), "needs Pillow")
    def test_the_shell_and_the_picture_are_splash_pys(self):
        done = subprocess.run([sys.executable, os.path.join(TOOLS, "splash.py"), "--check"], capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)


if __name__ == "__main__":
    unittest.main()
