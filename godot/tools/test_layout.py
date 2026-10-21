"""The README's Layout from the scripts' docs (PIX-358): which line of a
script is its doc, and where its first sentence ends.

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import unittest

import layout


class LayoutTest(unittest.TestCase):
    def test_the_doc_is_the_first_paragraph_of_double_hashes(self):
        script = [
            "class_name Lamps\n",
            "extends RefCounted\n",
            "## areas: travel field night\n",
            "## The land heals round the lamps\n",
            "## (PIX-323). Each morning a ring.\n",
            "##\n",
            "## A second paragraph.\n",
        ]
        self.assertEqual(layout.doc_paragraph(script), "The land heals round the lamps (PIX-323). Each morning a ring.")

    def test_areas_alone_is_no_doc(self):
        self.assertEqual(layout.doc_paragraph(["class_name X\n", "## areas: none\n", "\n", "var a := 1\n"]), "")

    def test_a_sentence_ends_outside_brackets_and_quotes(self):
        said = 'The map\'s pages (PIX-266: "it grew. a lot"). The screen showed more.'
        self.assertEqual(layout.first_sentence(said), 'The map\'s pages (PIX-266: "it grew. a lot").')
        self.assertEqual(layout.first_sentence("Ported from src/x.ts and v0.243 too"), "Ported from src/x.ts and v0.243 too")

    def test_a_long_sentence_stops_at_its_first_clause(self):
        said = "The look book (PIX-220): the same scenes, staged the same way every time - " + "the town, " * 20 + "all."
        self.assertEqual(layout.first_sentence(said), "The look book (PIX-220): the same scenes, staged the same way every time")

    def test_every_script_has_a_line(self):
        self.assertTrue(all(" — " in line and "(no doc yet)" not in line for line in layout.lines()))


if __name__ == "__main__":
    unittest.main()
