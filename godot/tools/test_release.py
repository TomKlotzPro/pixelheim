"""Tests for release.py (PIX-274): the French spacing, the version check, and
releases cut on a temp copy of the checkout.

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import datetime
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(TOOLS))
sys.path.insert(0, TOOLS)
import release  # noqa: E402

N = "\u202f"


class FrenchTest(unittest.TestCase):
    def test_a_plain_or_no_break_space_before_a_mark_becomes_narrow(self):
        for space in (" ", "\u00a0", N):
            for mark in ":;!?":
                self.assertEqual(release.french("Mot%s%s fin" % (space, mark)), "Mot%s%s fin" % (N, mark))

    def test_a_mark_typed_without_a_space_gets_one(self):
        self.assertEqual(release.french("Attention: le pont!"), "Attention" + N + ": le pont" + N + "!")
        self.assertEqual(release.french("Vraiment? Oui; bien."), "Vraiment" + N + "? Oui" + N + "; bien.")
        self.assertEqual(release.french("Enfin:"), "Enfin" + N + ":")
        self.assertEqual(release.french("Vendre %s?"), "Vendre %s" + N + "?")

    def test_guillemets_hold_their_words_at_a_narrow_space(self):
        self.assertEqual(release.french("« Garde-le »"), "«" + N + "Garde-le" + N + "»")
        self.assertEqual(release.french("«Garde-le»"), "«" + N + "Garde-le" + N + "»")
        self.assertEqual(release.french("«\u00a0Garde-le\u00a0»"), "«" + N + "Garde-le" + N + "»")
        self.assertEqual(release.french("un « ! » doré"), "un «" + N + "!" + N + "» doré")

    def test_clocks_links_placeholders_and_formats_keep_their_colons(self):
        for text in ("Il ouvre à 06:00 et ferme à 18:30", "Voir https://example.com/a?b=c pour plus",
                     "{key:interact} pour parler", "Temps %d:%02d", "res://assets/x.png"):
            self.assertEqual(release.french(text), text)

    def test_a_run_of_marks_takes_one_space(self):
        self.assertEqual(release.french("Quoi ?!"), "Quoi" + N + "?!")
        self.assertEqual(release.french("Quoi?!"), "Quoi" + N + "?!")
        self.assertEqual(release.french("Non!!!"), "Non" + N + "!!!")

    def test_the_first_character_and_an_opening_bracket_take_none(self):
        self.assertEqual(release.french("?"), "?")
        self.assertEqual(release.french("(!)"), "(!)")

    def test_apostrophes_are_straight(self):
        self.assertEqual(release.french("l\u2019écran s\u2019ouvre"), "l'écran s'ouvre")

    def test_it_is_idempotent(self):
        for text in ("Attention : le pont !", "« Garde-le »", "Quoi ?!", "à 06:00 : fin", "un « ? » gris ; bien"):
            once = release.french(text)
            self.assertEqual(release.french(once), once)

    def test_what_it_writes_passes_the_check(self):
        for text in ("Attention : le pont !", "« Garde-le »", "Un ? doré", "a\u00a0;b", "( !)", "x  :y"):
            self.assertEqual(release.bad_spacing(release.french(text)), [], text)

    def test_the_check_finds_plain_and_no_break_spaces(self):
        self.assertEqual(release.bad_spacing("Mot : fin"), [3])
        self.assertEqual(release.bad_spacing("Mot\u00a0!"), [3])
        self.assertEqual(release.bad_spacing("« a »"), [1, 3])
        self.assertEqual(release.bad_spacing("Mot" + N + ": «" + N + "a" + N + "» 06:00 {key:x}"), [])


class VersionTest(unittest.TestCase):
    def test_the_next_versions_are_a_patch_a_minor_and_a_major(self):
        self.assertEqual(release.next_versions("0.203.0"), ["0.203.1", "0.204.0", "1.0.0"])
        self.assertEqual(release.next_versions("1.2.3"), ["1.2.4", "1.3.0", "2.0.0"])

    def test_it_accepts_each_bump(self):
        for version in ("0.203.1", "0.204.0", "1.0.0"):
            release.check_version(version, "0.203.0")

    def test_it_refuses_a_repeat_a_step_back_or_a_jump(self):
        for version in ("0.203.0", "0.202.0", "0.202.9", "0.205.0", "0.203.2", "0.204.1", "2.0.0", "1.1.0"):
            with self.assertRaises(release.ReleaseError, msg=version):
                release.check_version(version, "0.203.0")

    def test_it_refuses_what_isnt_a_version(self):
        for version in ("0.204", "v0.204.0", "0.204.0-rc1", "0.0204.0", "", None, 204):
            with self.assertRaises(release.ReleaseError, msg=repr(version)):
                release.check_version(version, "0.203.0")


def copy_checkout(dest):
    """What release.py and i18n.py read and write, copied from this checkout."""
    shutil.copy2(os.path.join(REPO, "README.md"), dest)
    for path in ("godot/tools/release.py", "godot/tools/i18n.py", "godot/assets/maps/interactables.json"):
        os.makedirs(os.path.join(dest, os.path.dirname(path)), exist_ok=True)
        shutil.copy2(os.path.join(REPO, path), os.path.join(dest, path))
    for path in ("godot/assets/data", "godot/scripts", "godot/locale"):
        shutil.copytree(os.path.join(REPO, path), os.path.join(dest, path))


class CopyTest(unittest.TestCase):
    """Releases cut and checked on a temp copy of this checkout, by the copy's
    own release.py: it finds its files from where it stands."""

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="pixelheim-release-")
        self.addCleanup(shutil.rmtree, self.root)
        copy_checkout(self.root)
        self.script = os.path.join(self.root, "godot", "tools", "release.py")
        self.newest = self.changelog()["releases"][0]["version"]
        self.next = release.next_versions(self.newest)[1]
        # A branch may carry a string its feature left untranslated, which a
        # release would refuse: in the copy it stands as its own French, so
        # only what a test adds is new.
        lines = self.read("godot", "locale", "fr.po").split("\n")
        msgid = None
        for index, line in enumerate(lines):
            if line.startswith("msgid "):
                msgid = json.loads(line[6:])
            elif line == 'msgstr ""' and msgid:
                lines[index] = "msgstr " + release.quote(msgid)
        self.write("\n".join(lines), "godot", "locale", "fr.po")

    def path(self, *parts):
        return os.path.join(self.root, *parts)

    def read(self, *parts):
        with open(self.path(*parts), encoding="utf-8") as file:
            return file.read()

    def write(self, text, *parts):
        with open(self.path(*parts), "w", encoding="utf-8") as file:
            file.write(text)

    def changelog(self):
        return json.loads(self.read("godot", "assets", "data", "changelog.json"))

    def run_script(self, *args):
        return subprocess.run([sys.executable, self.script] + list(args), capture_output=True, text=True)

    def spec(self, **fields):
        spec = {
            "version": self.next,
            "codename": ["Test Release", "Version d'essai"],
            "notes": [
                ["The first test note: the bridge holds!", "La première note d'essai : le pont tient !"],
                ["Another test note, with a clock at 06:00", "Une autre note d'essai, avec une horloge à 06:00"],
            ],
        }
        spec.update(fields)
        path = self.path("spec.json")
        with open(path, "w", encoding="utf-8") as file:
            json.dump(spec, file, ensure_ascii=False)
        return path

    def snapshot(self):
        return {name: self.read(*name.split("/")) for name in (
            "README.md", "godot/assets/data/changelog.json", "godot/locale/messages.pot", "godot/locale/fr.po")}

    def test_a_release_is_cut_whole(self):
        done = self.run_script(self.spec())
        self.assertEqual(done.returncode, 0, done.stderr)
        top = self.changelog()["releases"][0]
        self.assertEqual(top, {
            "version": self.next,
            "date": datetime.date.today().isoformat(),
            "codename": "Test Release",
            "notes": ["The first test note: the bridge holds!", "Another test note, with a clock at 06:00"],
        })
        self.assertEqual(self.changelog()["releases"][1]["version"], self.newest)
        self.assertIn("Currently v%s - 1.0 has to be earned." % release.major_minor(self.next), self.read("README.md"))
        po = release.read_po(self.path("godot", "locale", "fr.po"))
        self.assertEqual(po["Test Release"], "Version d'essai")
        self.assertEqual(po["The first test note: the bridge holds!"],
                         "La première note d'essai" + N + ": le pont tient" + N + "!")
        self.assertEqual(po["Another test note, with a clock at 06:00"],
                         "Une autre note d'essai, avec une horloge à 06:00")
        self.assertIn("Test Release", self.read("godot", "locale", "messages.pot"))
        self.assertIn("Currently v%s -> v%s" % (release.major_minor(self.newest), release.major_minor(self.next)),
                      done.stdout)
        check = self.run_script("--check")
        self.assertEqual(check.returncode, 0, check.stderr)
        linear = self.run_script("--linear")
        self.assertEqual(linear.stdout.splitlines()[0],
                         "## v%s · Test Release · %s" % (self.next, datetime.date.today().isoformat()))
        self.assertIn("- The first test note: the bridge holds!", linear.stdout)

    def test_a_patch_leaves_the_readme_as_it_is(self):
        patch = release.next_versions(self.newest)[0]
        readme = self.read("README.md")
        done = self.run_script(self.spec(version=patch))
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(self.read("README.md"), readme)
        self.assertEqual(self.run_script("--check").returncode, 0)

    def test_a_version_out_of_turn_changes_nothing(self):
        before = self.snapshot()
        for version in (self.newest, release.next_versions(self.next)[1]):
            done = self.run_script(self.spec(version=version))
            self.assertEqual(done.returncode, 1)
            self.assertIn("doesn't follow v%s" % self.newest, done.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_a_release_cut_twice_is_refused(self):
        self.assertEqual(self.run_script(self.spec()).returncode, 0)
        after = self.snapshot()
        done = self.run_script(self.spec())
        self.assertEqual(done.returncode, 1)
        self.assertEqual(self.snapshot(), after)

    def test_a_string_the_game_never_shows_rolls_everything_back(self):
        before = self.snapshot()
        done = self.run_script(self.spec(extra={"No such string anywhere in the game": "Nulle part"}))
        self.assertEqual(done.returncode, 1)
        self.assertIn("No such string anywhere in the game", done.stderr)
        self.assertEqual(self.snapshot(), before)

    def test_a_string_left_untranslated_rolls_everything_back(self):
        # A new string in the data that the spec doesn't translate.
        path = ("godot", "assets", "data", "hints.json")
        hints = self.read(*path)
        doc = json.loads(hints)
        doc["pix274_test"] = "A brand new hint nobody translated"
        self.write(json.dumps(doc, indent=2, ensure_ascii=False), *path)
        before = self.snapshot()
        done = self.run_script(self.spec())
        self.assertEqual(done.returncode, 1)
        self.assertIn("A brand new hint nobody translated", done.stderr)
        self.assertEqual(self.snapshot(), before)
        extra = {"A brand new hint nobody translated": "Un tout nouveau conseil"}
        done = self.run_script(self.spec(extra=extra))
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn("1 extra", done.stdout)

    def test_the_check_finds_a_readme_behind(self):
        readme = self.read("README.md")
        self.write(readme.replace("Currently v%s" % release.major_minor(self.newest), "Currently v0.1"), "README.md")
        done = self.run_script("--check")
        self.assertEqual(done.returncode, 1)
        self.assertIn("README.md says Currently v0.1", done.stderr)

    def test_the_check_finds_a_note_without_french(self):
        note = self.changelog()["releases"][3]["notes"][0]
        po = self.read("godot", "locale", "fr.po").split("\n")
        at = po.index("msgid " + release.quote(note))
        po[at + 1] = 'msgstr ""'
        self.write("\n".join(po), "godot", "locale", "fr.po")
        done = self.run_script("--check")
        self.assertEqual(done.returncode, 1)
        self.assertIn("note has no French in fr.po: " + note, done.stderr)

    def test_the_check_finds_a_plain_space_before_a_mark(self):
        po = self.read("godot", "locale", "fr.po")
        self.write(po.replace(N + "!", " !", 1), "godot", "locale", "fr.po")
        done = self.run_script("--check")
        self.assertEqual(done.returncode, 1)
        self.assertIn("1 plain or no-break space (␣) where U+202F belongs", done.stderr)


if __name__ == "__main__":
    unittest.main()
