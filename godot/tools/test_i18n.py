"""Tests for i18n.py's catalogue references (PIX-273): a `#:` reference names
the file a string was found in, never its line, so editing a script changes
the catalogue only when one of its strings changes. With lines, every edit
moved the references below it, and two branches that touched one script
conflicted in messages.pot and fr.po with no string changed.

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import os
import shutil
import sys
import tempfile
import unittest

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import i18n  # noqa: E402

LOCALE = os.path.join(os.path.dirname(TOOLS), "locale")


class ReferenceTest(unittest.TestCase):
    def test_a_reference_is_a_file(self):
        strings = i18n.gather()
        self.assertGreater(len(strings), 1000)
        for where in set(strings.values()):
            self.assertRegex(where, r"^[\w./-]+\.(gd|json|py)$", "a file, no line")

    def test_the_catalogues_carry_no_line(self):
        for name in ("messages.pot", "fr.po"):
            self.assertEqual(i18n.line_references(os.path.join(LOCALE, name)), [], name)

    def test_editing_a_script_leaves_the_catalogue_alone(self):
        # A copy of what i18n.py reads, a script edited without touching its
        # strings: lines added above them and a word in a comment.
        with tempfile.TemporaryDirectory() as root:
            for folder in ("scripts", os.path.join("assets", "data")):
                shutil.copytree(os.path.join(i18n.ROOT, folder), os.path.join(root, folder))
            os.makedirs(os.path.join(root, "assets", "maps"))
            for name in i18n.MAPS_DATA:
                shutil.copy(os.path.join(i18n.ROOT, "assets", "maps", name + ".json"), os.path.join(root, "assets", "maps"))
            saved = i18n.ROOT
            try:
                i18n.ROOT = root
                before = i18n.pot(i18n.gather())
                path = os.path.join(root, "scripts", "world_interaction.gd")
                with open(path, encoding="utf-8") as file:
                    source = file.read()
                with open(path, "w", encoding="utf-8") as file:
                    file.write("\n\n## An edit that adds no string.\nvar _unused := 0\n" + source)
                self.assertEqual(i18n.pot(i18n.gather()), before)
            finally:
                i18n.ROOT = saved


class SetLineTest(unittest.TestCase):
    """A line's rules, written into the catalogues (PIX-478, PIX-484)."""

    def test_the_dash_holds_and_a_questions_last_word_stays_whole(self):
        nbsp, narrow, hyphen = "\u00a0", "\u202f", "\u2011"
        self.assertEqual(i18n.set_line("Inferno - the room burns"), "Inferno" + nbsp + "- the room burns")
        self.assertEqual(i18n.set_line("well-made, -5 HP"), "well-made, -5 HP", "a hyphen in a word or a number is no dash")
        self.assertEqual(i18n.set_line("Qui êtes-vous" + narrow + "?"), "Qui êtes" + hyphen + "vous" + narrow + "?")
        asked = "Peut-être, mais où est-il passé" + narrow + "?"
        self.assertEqual(i18n.set_line(asked), asked, "only the last word's hyphen")
        once = i18n.set_line("Quel temps fait-il" + narrow + "? - Maren")
        self.assertEqual(i18n.set_line(once), once, "a set line stays as it is")

    def test_every_catalogue_line_is_set(self):
        self.assertEqual(i18n.unset_lines(os.path.join(LOCALE, "fr.po")), [])
        english = i18n.read_po(os.path.join(LOCALE, "en.po"))
        self.assertGreater(len(english), 100)
        for source, said in english.items():
            if source == "":
                continue  # the header
            self.assertEqual(said, i18n.set_line(source))
            self.assertNotEqual(said, source, "only the strings a rule changes")


if __name__ == "__main__":
    unittest.main()
