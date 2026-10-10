#!/usr/bin/env python3
"""Cut a release of Pixelheim, or check that the newest one is whole (PIX-274).

Every player-visible change ships as a release, and a release is four edits
made together:

- an entry at the top of godot/assets/data/changelog.json (version, date,
  English codename and notes): it is the game's version and its What's new;
- the root README's "Currently vX.Y - 1.0 has to be earned." line, at the new
  major.minor;
- the translation catalogue regenerated (godot/tools/i18n.py), which merges
  the new strings into godot/locale/fr.po;
- the French filled in fr.po for the codename, each note and any other string
  the change added (the game shows the changelog through the catalogue).

The release is described by a spec, a JSON file:

    {
      "version": "0.204.0",
      "codename": ["Open Country", "Rase campagne"],
      "notes": [
        ["The roads run out through the ridge", "Les routes sortent par la crête"]
      ],
      "extra": {"A string the change added": "Sa traduction"}
    }

The version must follow the newest release: a patch (0.203.1), a minor
(0.204.0) or a major (1.0.0) bump, never a repeat, a step back or a jump.
"extra" is optional. Type the French plainly: the script sets it in the house
style (straight apostrophes, a narrow no-break space U+202F before : ; ! ? and
inside guillemets). If anything goes wrong, from a version out of turn to a
string left untranslated in fr.po, nothing is changed.

The paths are the script's own checkout's, so it works the same from any
worktree.

    python3 godot/tools/release.py SPEC.json        # cut the release
    python3 godot/tools/release.py --check          # CI: the newest release is whole
    python3 godot/tools/release.py --linear [X.Y.Z] # its section for Linear's Changelog
"""
import argparse
import datetime
import json
import os
import re
import subprocess
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(TOOLS)
REPO = os.path.dirname(GODOT)
CHANGELOG = os.path.join(GODOT, "assets", "data", "changelog.json")
README = os.path.join(REPO, "README.md")
POT = os.path.join(GODOT, "locale", "messages.pot")
FR_PO = os.path.join(GODOT, "locale", "fr.po")
I18N = os.path.join(TOOLS, "i18n.py")

if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)
from i18n import quote, read_po  # noqa: E402  (the .po format is i18n.py's)

NNBSP = "\u202f"
VERSION = re.compile(r"(\d+)\.(\d+)\.(\d+)")
README_LINE = re.compile(r"(Currently v)(\d+\.\d+)( - 1\.0 has to be earned\.)")
CHANGELOG_HEAD = '{\n  "releases": [\n'


class ReleaseError(Exception):
    """A release refused, or a check failed: the message says why."""


def rel(path):
    return os.path.relpath(path, REPO)


# --- French typography ------------------------------------------------------

# A link keeps its marks as typed (https://..., ?a=b).
_URL = re.compile(r"[A-Za-z][A-Za-z0-9+.-]*://\S+")
# Any space typed before a mark, or inside guillemets.
_SPACED_MARK = re.compile(r"[ \u00a0\u202f]+(?=[:;!?])")
_OPEN_QUOTE = re.compile(r"«[ \u00a0\u202f]*")
_CLOSE_QUOTE = re.compile(r"[ \u00a0\u202f]*»")
# A mark typed straight after a word: ; ! ? always; a colon only when it ends
# a clause (a space or the end follows), so a clock's (06:00), a placeholder's
# ({key:interact}) or a format's (%d:%02d) stays. Never the second mark of a
# run (?!), the text's first character, or right after an opening bracket.
_BARE_MARK = re.compile(r"(?<=[^\s:;!?(\[])(?=[;!?]|:(?:\s|$))")
# What --check refuses: a plain or no-break space where U+202F belongs.
_BAD_SPACE = re.compile(r"[ \u00a0](?=[:;!?»])|(?<=«)[ \u00a0]")


def _french_words(text):
    text = _OPEN_QUOTE.sub("«" + NNBSP, text)
    text = _CLOSE_QUOTE.sub(NNBSP + "»", text)
    text = _SPACED_MARK.sub(NNBSP, text)
    return _BARE_MARK.sub(NNBSP, text)


def french(text):
    """French in the house style, whatever it was typed with.

    Straight apostrophes; a narrow no-break space (U+202F) before : ; ! ? and
    inside « », replacing a plain or no-break space or added where there was
    none. Links, clocks, placeholders and runs of marks keep their own.
    """
    text = text.replace("\u2019", "'")
    out = []
    at = 0
    for link in _URL.finditer(text):
        out.append(_french_words(text[at:link.start()]))
        out.append(link.group(0))
        at = link.end()
    out.append(_french_words(text[at:]))
    return "".join(out)


def bad_spacing(text):
    """Where a msgstr has a plain or no-break space that should be U+202F."""
    return [match.start() for match in _BAD_SPACE.finditer(text)]


# --- Versions ---------------------------------------------------------------

def parse_version(text):
    match = VERSION.fullmatch(text) if isinstance(text, str) else None
    if not match:
        raise ReleaseError("%r is not a version (MAJOR.MINOR.PATCH)" % (text,))
    return tuple(int(part) for part in match.groups())


def next_versions(newest):
    """The versions that may follow `newest`: its patch, minor and major bumps."""
    major, minor, patch = parse_version(newest)
    return [
        "%d.%d.%d" % (major, minor, patch + 1),
        "%d.%d.0" % (major, minor + 1),
        "%d.0.0" % (major + 1),
    ]


def check_version(version, newest):
    """Refuse a version that isn't the next one after `newest`."""
    parse_version(version)
    allowed = next_versions(newest)
    if version not in allowed:
        raise ReleaseError(
            "v%s doesn't follow v%s, the newest release: the next is v%s (patch), v%s (minor) or v%s (major)"
            % ((version, newest) + tuple(allowed)))


def major_minor(version):
    return "%d.%d" % parse_version(version)[:2]


# --- The files --------------------------------------------------------------

def read(path):
    with open(path, encoding="utf-8") as file:
        return file.read()


def write(path, text):
    with open(path, "w", encoding="utf-8") as file:
        file.write(text)


def releases():
    return json.loads(read(CHANGELOG))["releases"]


def readme_version(text):
    """The major.minor of the README's "Currently vX.Y" line."""
    found = README_LINE.findall(text)
    if len(found) != 1:
        raise ReleaseError("README.md has %d \"Currently vX.Y - 1.0 has to be earned.\" lines, not one" % len(found))
    return found[0][1]


def load_spec(path):
    """The spec's version, the translations it brings (English -> French) and
    the entry it adds to the changelog."""
    try:
        spec = json.loads(read(path))
    except (OSError, ValueError) as error:
        raise ReleaseError("can't read the spec %s: %s" % (path, error))
    if not isinstance(spec, dict):
        raise ReleaseError("the spec is a JSON object: {version, codename, notes, extra}")
    unknown = set(spec) - {"version", "codename", "notes", "extra"}
    if unknown:
        raise ReleaseError("the spec has unknown keys: %s" % ", ".join(sorted(unknown)))
    version = spec.get("version")
    parse_version(version)

    def pair(value, what):
        if (not isinstance(value, list) or len(value) != 2
                or not all(isinstance(text, str) and text.strip() for text in value)):
            raise ReleaseError("%s is an [English, French] pair of non-empty strings: %r" % (what, value))
        return value

    codename = pair(spec.get("codename"), "the codename")
    notes = spec.get("notes")
    if not isinstance(notes, list) or not notes:
        raise ReleaseError("the spec's notes are a non-empty list of [English, French] pairs")
    notes = [pair(note, "note %d" % (number + 1)) for number, note in enumerate(notes)]
    extra = spec.get("extra", {})
    if not isinstance(extra, dict):
        raise ReleaseError("the spec's extra is an object of English -> French")
    for english, french_text in extra.items():
        pair([english, french_text], "extra %r" % english)

    french_of = {}
    for english, french_text in [codename] + notes + list(extra.items()):
        if english in french_of and french_of[english] != french_text:
            raise ReleaseError("the spec translates %r twice, differently" % english)
        french_of[english] = french_text
    entry = {
        "version": version,
        "date": datetime.date.today().isoformat(),
        "codename": codename[0],
        "notes": [note[0] for note in notes],
    }
    return entry, french_of


# --- Cutting a release ------------------------------------------------------

def run_i18n():
    done = subprocess.run([sys.executable, I18N], capture_output=True, text=True)
    if done.returncode != 0:
        raise ReleaseError("i18n.py failed:\n" + done.stdout + done.stderr)
    return done.stdout.strip().splitlines()


def prepend(changelog_text, entry):
    if not changelog_text.startswith(CHANGELOG_HEAD):
        raise ReleaseError("changelog.json doesn't open with %r" % CHANGELOG_HEAD)
    body = "\n".join("    " + line for line in json.dumps(entry, indent=2, ensure_ascii=False).split("\n"))
    text = CHANGELOG_HEAD + body + ",\n" + changelog_text[len(CHANGELOG_HEAD):]
    if json.loads(text)["releases"][0] != entry:
        raise ReleaseError("changelog.json didn't take the entry")
    return text


def fill_po(po_text, french_of):
    """fr.po with each spec string's msgstr set; returns the text, the strings
    it found and those whose old translation it replaced."""
    lines = po_text.split("\n")
    found = set()
    replaced = []
    msgid = None
    for index, line in enumerate(lines):
        if line.startswith("msgid "):
            msgid = json.loads(line[6:])
        elif line.startswith("msgstr ") and msgid is not None:
            if msgid in french_of:
                old = json.loads(line[7:])
                new = french(french_of[msgid])
                if old and old != new:
                    replaced.append(msgid)
                lines[index] = "msgstr " + quote(new)
                found.add(msgid)
            msgid = None
    return "\n".join(lines), found, replaced


def cut(spec_path):
    """Release the spec: every file or none."""
    entry, french_of = load_spec(spec_path)
    changelog_text = read(CHANGELOG)
    newest = json.loads(changelog_text)["releases"][0]["version"]
    check_version(entry["version"], newest)
    readme_text = read(README)
    was = readme_version(readme_text)
    now = major_minor(entry["version"])
    strings_before = len(read_po(POT)) - 1 if os.path.exists(POT) else 0

    saved = {}
    for path in (CHANGELOG, README, POT, FR_PO):
        with open(path, "rb") as file:
            saved[path] = file.read()
    try:
        write(CHANGELOG, prepend(changelog_text, entry))
        write(README, README_LINE.sub(lambda m: m.group(1) + now + m.group(3), readme_text))
        run_i18n()
        po_text, found, replaced = fill_po(read(FR_PO), french_of)
        unknown = [english for english in french_of if english not in found]
        if unknown:
            raise ReleaseError(
                "not in the catalogue, so the game would never show their French (i18n.py gathers only"
                " words with a capital or a space, from the data and the scripts):\n"
                + "\n".join("  " + english for english in unknown))
        write(FR_PO, po_text)
        report = run_i18n()
        untranslated = [english for english, text in read_po(FR_PO).items() if english and not text]
        if untranslated:
            raise ReleaseError(
                "fr.po would keep %d strings untranslated: add them to the spec's extra:\n" % len(untranslated)
                + "\n".join("  " + json.dumps(english, ensure_ascii=False) for english in untranslated))
    except BaseException:
        for path, data in saved.items():
            with open(path, "wb") as file:
                file.write(data)
        raise

    strings_after = len(read_po(POT)) - 1
    notes = len(entry["notes"])
    extras = len(french_of) - len(set([entry["codename"]] + entry["notes"]))
    print("v%s \"%s\" (%s):" % (entry["version"], entry["codename"], entry["date"]))
    print("  %s: + v%s, %d note%s" % (rel(CHANGELOG), entry["version"], notes, "" if notes == 1 else "s"))
    if was == now:
        print("  %s: already at v%s" % (rel(README), now))
    else:
        print("  %s: Currently v%s -> v%s" % (rel(README), was, now))
    print("  %s: %d strings (%+d)" % (rel(POT), strings_after, strings_after - strings_before))
    print("  %s: %d filled (the codename, %d note%s, %d extra)%s" % (
        rel(FR_PO), len(french_of), notes, "" if notes == 1 else "s", extras,
        "; replaced the old French of %d" % len(replaced) if replaced else ""))
    for line in report:
        if line.startswith("fr.po"):
            print("  " + line)
    print("For Linear's Changelog: python3 godot/tools/release.py --linear")


# --- Checking the newest release --------------------------------------------

def check():
    """The problems that make the release in this checkout less than whole."""
    problems = []
    entries = releases()
    newest = entries[0]["version"]
    try:
        shown = readme_version(read(README))
        if shown != major_minor(newest):
            problems.append("README.md says Currently v%s, the newest release is v%s" % (shown, newest))
    except ReleaseError as error:
        problems.append(str(error))

    po = read_po(FR_PO)
    for entry in entries:
        for english in [entry["codename"]] + entry["notes"]:
            if not po.get(english):
                what = "codename" if english == entry["codename"] else "note"
                problems.append("v%s's %s has no French in fr.po: %s" % (entry["version"], what, english))

    for text in po.values():
        spots = bad_spacing(text)
        if spots:
            marked = "".join("␣" if at in spots else char for at, char in enumerate(text))
            problems.append(
                "fr.po: %d plain or no-break space%s (␣) where U+202F belongs, before : ; ! ? or inside « »: %s"
                % (len(spots), "" if len(spots) == 1 else "s", marked))
    return problems, entries


def check_main():
    problems, entries = check()
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        print("release check: %d problem%s" % (len(problems), "" if len(problems) == 1 else "s"), file=sys.stderr)
        return 1
    newest = entries[0]
    notes = sum(len(entry["notes"]) for entry in entries)
    print("release check: v%s \"%s\" is whole" % (newest["version"], newest["codename"]))
    print("  README.md: Currently v%s" % major_minor(newest["version"]))
    print("  fr.po: every codename and note of %d releases (%d notes) translated" % (len(entries), notes))
    print("  fr.po: U+202F before : ; ! ? and inside « » throughout")
    return 0


# --- Linear -----------------------------------------------------------------

def linear(version=None):
    """A release's section for Linear's Changelog document, in markdown."""
    entries = releases()
    if version:
        version = version.lstrip("v")
        entries = [entry for entry in entries if entry["version"] == version]
        if not entries:
            raise ReleaseError("no release v%s in changelog.json" % version)
    entry = entries[0]
    lines = ["## v%s · %s · %s" % (entry["version"], entry["codename"], entry["date"]), ""]
    lines += ["- " + note for note in entry["notes"]]
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Cut a Pixelheim release from a spec, or check that the newest one is whole.",
        epilog="See the docstring at the top of godot/tools/release.py for the spec's shape.")
    parser.add_argument("spec", nargs="?", help="the release's spec (JSON)")
    parser.add_argument("--check", action="store_true",
                        help="check the newest release is whole (README version, French, spacing)")
    parser.add_argument("--linear", nargs="?", const="", metavar="VERSION",
                        help="print a release's section for Linear's Changelog (the newest by default)")
    args = parser.parse_args(argv)
    if [args.spec is not None, args.check, args.linear is not None].count(True) != 1:
        parser.error("give a spec, --check or --linear")
    try:
        if args.check:
            return check_main()
        if args.linear is not None:
            print(linear(args.linear))
            return 0
        cut(args.spec)
        return 0
    except ReleaseError as error:
        print("release: %s" % error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
