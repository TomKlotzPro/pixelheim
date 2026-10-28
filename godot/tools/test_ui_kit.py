"""The UI kit's manifest (PIX-385): every piece UiStyle will ask for is named,
with its file, margins, content margins and axis, and what the prep makes it
from. The pieces themselves are paid art and never in this repo.

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import json
import os
import unittest

GODOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MANIFEST = os.path.join(GODOT, "assets", "puny", "ui_kit.json")
PIECES = ["window", "panel", "button", "button_hover", "button_pressed", "button_disabled", "button_chosen",
          "tab", "tab_selected", "slot", "slot_ready", "slot_spent", "slot_focus", "slot_fine", "slot_epic",
          "bar_frame"]
RAMPS = {"night", "wood", "brass", "page", "lamp", "fine", "epic"}


def four(values):
    return isinstance(values, list) and len(values) == 4 and all(isinstance(v, int) and v >= 0 for v in values)


class UiKitTest(unittest.TestCase):
    def setUp(self):
        with open(MANIFEST, encoding="utf-8") as file:
            self.pieces = json.load(file)["pieces"]

    def test_every_piece_ui_style_asks_for_is_named(self):
        self.assertEqual(sorted(self.pieces), sorted(PIECES))

    def test_every_piece_has_its_fields(self):
        for name, piece in self.pieces.items():
            self.assertEqual(piece["file"], name + ".png", name)
            self.assertTrue(four(piece["margins"]), "%s: margins are four art pixels, left/top/right/bottom" % name)
            self.assertTrue(four(piece["content"]), "%s: content is four art pixels" % name)
            self.assertIn(piece["axis"], ("tile", "stretch"), name)
            self.assertRegex(piece["source"], r"^(wood|parchment)/(base|derived)/\w+\.png$", name)

    def test_the_prep_fields_hold_together(self):
        for name, piece in self.pieces.items():
            if "crop" in piece:
                self.assertTrue(four(piece["crop"]) and piece["crop"][2] > 0 and piece["crop"][3] > 0, name)
                width, height = piece["crop"][2], piece["crop"][3]
                margins = piece["margins"]
                self.assertLess(margins[0] + margins[2], width, name)
                self.assertLess(margins[1] + margins[3], height, name)
            if "label" in piece:
                first, past = piece["label"]
                self.assertLess(piece["margins"][0], first, name)
                self.assertLess(first, past, name)
            for family, ramp in piece.get("ramps", {}).items():
                self.assertIn(family, RAMPS, name)
                self.assertIn(ramp, RAMPS, name)
            self.assertIn(piece.get("shift", 0), (-1, 0, 1), name)

    def test_a_pieces_states_cut_alike(self):
        # Swapping a state never moves the words: the same source, crop and
        # label, and margins that differ only by the pressed face's drop.
        for name, piece in self.pieces.items():
            base = self.pieces[name.split("_")[0]] if name.split("_")[0] in self.pieces else piece
            for field in ("source", "crop", "label"):
                self.assertEqual(piece.get(field), base.get(field), "%s: %s" % (name, field))
            drop = piece.get("drop", 0)
            m = base["margins"]
            self.assertEqual(piece["margins"], [m[0], m[1] + drop, m[2], m[3] - drop], name)

    def test_the_prepared_pieces_stay_out_of_git(self):
        with open(os.path.join(GODOT, ".gitignore"), encoding="utf-8") as file:
            self.assertIn("/assets/puny/gegx", file.read().split())


if __name__ == "__main__":
    unittest.main()
