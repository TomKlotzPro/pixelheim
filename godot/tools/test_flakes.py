"""Tests for flakes.py (PIX-276): a round's runs collected from flows.sh's
folders, and the tally that names every flow that failed or changed its
report between runs.

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import os
import sys
import tempfile
import unittest

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import flakes  # noqa: E402

REPORT = "screenshot saved; map=town cell=(40, 33) hp=42 gold=30 draws=%d paused=false open=none"


def run(flow, status="ok", mode="headless", report=REPORT % 0, why=""):
    out = {"tag": mode + " 1.1", "mode": mode, "flow": flow, "status": status, "seconds": 2.0,
           "report": report.replace("screenshot saved; ", "")}
    if status == "FAIL":
        out["why"] = why
        out["tail"] = ["the end of its output"]
    return out


class CollectTest(unittest.TestCase):
    def test_a_rounds_runs_read_from_their_folders(self):
        with tempfile.TemporaryDirectory() as runs:
            for name, result, output in (
                ("dodge", "ok|dodge|3.1|map=town", "Godot\n" + REPORT % 0 + "\n"),
                ("board", "FAIL|board|9.0|expected open=town_hall_screen", "\x1b[1mWARNING\x1b[0m: x\n" + REPORT % 0 + "\n"),
                ("motion", "skip|motion|0|needs a window", ""),
            ):
                os.makedirs(os.path.join(runs, name))
                with open(os.path.join(runs, name, "result"), "w", encoding="utf-8") as file:
                    file.write(result + "\n")
                with open(os.path.join(runs, name, "output.txt"), "w", encoding="utf-8") as file:
                    file.write(output)
            os.makedirs(os.path.join(runs, "still-running"))
            got = {one["flow"]: one for one in flakes.collect("headless 2.3", runs)}
        self.assertEqual(sorted(got), ["board", "dodge", "motion"], "a run without its result isn't one")
        self.assertEqual(got["dodge"]["report"], (REPORT % 0).replace("screenshot saved; ", ""))
        self.assertEqual(got["dodge"]["mode"], "headless")
        self.assertNotIn("tail", got["dodge"])
        self.assertEqual(got["board"]["why"], "expected open=town_hall_screen")
        self.assertEqual(got["board"]["tail"][0], "WARNING: x", "its output kept, without colours")


class TallyTest(unittest.TestCase):
    def test_steady_runs_pass(self):
        summary, passed = flakes.tally([run("dodge"), run("dodge"), run("dodge", mode="windowed", report=REPORT % 55)])
        self.assertTrue(passed)
        self.assertIn("all steady", summary)
        self.assertNotIn("| dodge |", summary, "draws= is the renderer's: a window's count isn't a change")

    def test_a_flow_that_failed_once_fails_the_hunt(self):
        summary, passed = flakes.tally([run("board"), run("board", "FAIL", why="expected open=town_hall_screen"), run("dodge")])
        self.assertFalse(passed)
        self.assertIn("| board | 1 (headless 1) | 2 | `expected open=town_hall_screen` |", summary)
        self.assertIn("the end of its output", summary)

    def test_a_report_that_changed_is_named_and_fails_only_when_strict(self):
        runs = [run("dodge"), run("dodge", report=(REPORT % 0).replace("(40, 33)", "(40, 34)"))]
        summary, passed = flakes.tally(runs)
        self.assertTrue(passed)
        self.assertIn("| dodge | headless 2 | cell |", summary)
        self.assertFalse(flakes.tally(runs, strict=True)[1])

    def test_reports_compare_within_their_mode(self):
        # The windowed runs have Shade's CC0 art alone, the headless ones the
        # paid art: the dice can fall another way between them, never within.
        windowed = (REPORT % 55).replace("gold=30", "gold=31")
        summary, passed = flakes.tally([run("fight"), run("fight"), run("fight", mode="windowed", report=windowed),
                                        run("fight", mode="windowed", report=windowed)], strict=True)
        self.assertTrue(passed)
        self.assertIn("all steady", summary)

    def test_a_skipped_run_is_no_run(self):
        summary, passed = flakes.tally([run("motion", "skip"), run("dodge")])
        self.assertTrue(passed)
        self.assertIn("1 runs of 1 flows", summary)


if __name__ == "__main__":
    unittest.main()
