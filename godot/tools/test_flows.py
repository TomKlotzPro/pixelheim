"""Tests for flows.py and flows.txt (PIX-273): every flow a line of its own
under its comment, flows.sh holding none of them nor a sentence naming
them, and a flow's expectation matched by field name, never by where the
field stands on the report line.

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import os
import re
import sys
import tempfile
import unittest

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import flows  # noqa: E402

FLOWS_SH = os.path.join(TOOLS, "flows.sh")
## The tickets flows.sh may name: the runner's own (the release flows, the
## French run, side by side, the job summary, the tags, this). A flow's
## ticket goes beside it in flows.txt.
RUNNER_TICKETS = {"PIX-129", "PIX-196", "PIX-270", "PIX-271", "PIX-272", "PIX-273"}

REPORT = ("screenshot saved; map=town cell=(79, 4) hp=120 gold=90 save=town(79, 4) draws=212 paused=false"
          " open=none night=0 mobs=3 card=The Mirefen floats=+60 gold logged=0 packs=slime,goblin:asleep")


def written(text):
    """A flows.txt with `text`, in a temp file, read back."""
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as file:
        file.write(text)
    try:
        return flows.read_flows(file.name)
    finally:
        os.unlink(file.name)


class MatchTest(unittest.TestCase):
    def test_fields_match_by_name_wherever_they_stand(self):
        self.assertEqual(flows.mismatch("logged=0 map=town", REPORT), "")
        self.assertEqual(flows.mismatch("packs=slime,goblin:asleep", REPORT), "", "the last field, no $ needed")
        self.assertEqual(flows.mismatch("packs=slime,goblin:asleep", REPORT + " tracked=none"), "",
                         "another field after it changes nothing")

    def test_a_pattern_matches_the_whole_value(self):
        self.assertNotEqual(flows.mismatch("map=tow", REPORT), "")
        self.assertNotEqual(flows.mismatch("map=town_.*", REPORT), "", "not one of its rooms")
        self.assertEqual(flows.mismatch("map=town_.*", REPORT.replace("map=town ", "map=town_inn ")), "")
        self.assertNotEqual(flows.mismatch("mobs=3", REPORT.replace("mobs=3", "mobs=31")), "")

    def test_values_hold_spaces(self):
        self.assertEqual(flows.mismatch(r"cell=\(79, 4\) card=The Mirefen floats=\+60 [a-z]+", REPORT), "")
        self.assertEqual(flows.report_fields(REPORT)["save"], "town(79, 4)")

    def test_a_field_the_report_lacks_fails_and_says_so(self):
        self.assertEqual(flows.mismatch("gate=cliff", REPORT), "no gate=")
        self.assertEqual(flows.mismatch("gold=91 fell=1", REPORT), r"gold=90, not /91/; no fell=")
        self.assertEqual(flows.mismatch("map=town", "the watchdog stopped it"), "no report")

    def test_only_the_report_line_counts(self):
        output = "OVERFLOW gate=cliff\n" + REPORT + "\n"
        self.assertEqual(flows.mismatch("map=town", output), "")
        self.assertEqual(flows.mismatch("gate=cliff", output), "no gate=")


class ExpectationTest(unittest.TestCase):
    def test_an_anchor_on_the_lines_end_is_refused(self):
        for text in ("packs=slime$", "map=^town"):
            with self.assertRaises(flows.FlowError):
                flows.expectation(text)
        flows.expectation(r"gold=\$5")

    def test_it_names_a_field(self):
        for text in ("", "screenshot saved", "map=town gold=1 map=inn"):
            with self.assertRaises(flows.FlowError):
                flows.expectation(text)


class FileTest(unittest.TestCase):
    def test_every_flow_reads(self):
        read = flows.read_flows()
        self.assertGreater(len(read), 100, "the flows were found")
        self.assertEqual(len({flow[0] for flow in read}), len(read), "no name twice")
        for name, args, expect, tags in read:
            self.assertTrue(args, name)
            self.assertTrue(tags, "%s has its tags" % name)

    def test_a_flow_has_its_comment(self):
        flows_read = written("# Standing in the village (PIX-129).\nspawn | --map town | map=town | town\n"
                             "portal | --map town portal | map=town_.* | town travel\n")
        self.assertEqual([flow[0] for flow in flows_read], ["spawn", "portal"], "a flow under another shares its comment")
        with self.assertRaises(flows.FlowError):
            written("# The village.\nspawn | --map town | map=town | town\n\nportal | --map town portal | map=town_.* | town\n")

    def test_a_name_twice_or_a_line_out_of_shape_is_refused(self):
        for text in (
            "# a\nspawn | --map town | map=town | town\nspawn | --map inn | map=inn | rooms\n",
            "# a\nspawn | --map town | map=town\n",
            "# a\nSpawn! | --map town | map=town | town\n",
            "# a\nspawn | --map town | map=town$ | town\n",
        ):
            with self.assertRaises(flows.FlowError):
                written(text)

    def test_the_list_is_what_flows_sh_reads(self):
        for line in flows.read_flows():
            self.assertNotIn("|", "".join(line), "a | in a field would part it")

    def test_every_map_boots(self):
        boots = flows.boot_flows()
        self.assertGreater(len(boots), 40)
        self.assertIn(("town", "--map town", "map=town", ""), boots)
        self.assertIn(("town-night", "--map town night", "map=town", ""), boots)
        for name, args, expect, tags in boots:
            flows.expectation(expect)


class RunnerTest(unittest.TestCase):
    """flows.sh runs the flows; it neither holds nor describes them. Every
    branch that added a flow used to add it to the end of flows.sh's list and
    a clause to the sentence above it, so any two at once conflicted."""

    def setUp(self):
        with open(FLOWS_SH, encoding="utf-8") as file:
            self.source = file.read()

    def test_flows_sh_holds_no_flow(self):
        self.assertNotRegex(self.source, re.compile(r'^\s*"[a-z0-9-]+\|', re.M), "a flow is a line of flows.txt")

    def test_flows_sh_names_no_flows_ticket(self):
        named = set(re.findall(r"PIX-\d+", self.source)) - RUNNER_TICKETS
        self.assertEqual(named, set(), "flows.sh describes the runner: a flow's words and its ticket go beside it "
                         "in flows.txt (a change to the runner itself adds its ticket to RUNNER_TICKETS)")

    def test_a_merge_keeps_both_sides_flows(self):
        # Two branches adding flows at the same place keep both on a rebase;
        # a flow both changed comes out twice, which read_flows refuses.
        with open(os.path.join(TOOLS, "..", "..", ".gitattributes"), encoding="utf-8") as file:
            self.assertIn("godot/tools/flows.txt merge=union", file.read())


if __name__ == "__main__":
    unittest.main()
