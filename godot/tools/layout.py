#!/usr/bin/env python3
"""The Layout section of godot/README.md, written from the scripts' own docs
(PIX-358).

Every script under godot/scripts/ gets a line: its path and the first
sentence of its first `##` doc paragraph. A script says what it is where it
is written, so a new one is in the README once this runs, and a doc that
changes there changes here. `## areas:` lines (check.sh's areas, PIX-353)
are not doc and are passed over.

    python3 godot/tools/layout.py           # write the section
    python3 godot/tools/layout.py --check   # write nothing; fail when it's stale

The lines go between the README's two layout.py markers; what stands
around them (the scene, the assets, the data) is written by hand.
"""

import sys
from pathlib import Path

GODOT = Path(__file__).resolve().parent.parent
README = GODOT / "README.md"
BEGIN = "<!-- layout.py: from here -->"
END = "<!-- layout.py: to here -->"


def doc_paragraph(lines):
    """The first `##` doc paragraph of a script's lines, joined: its `##`
    lines up to an empty `##` line or the first line that isn't doc."""
    words = []
    for line in lines:
        text = line.rstrip("\n")
        if not text.startswith("##") or text.startswith("## areas:"):
            if words:
                break
            continue
        text = text[2:].strip()
        if not text:
            if words:
                break
            continue
        words.append(text)
    return " ".join(words)


# A sentence longer than this is cut at its first clause (": ", "; " or
# " - ") past CLAUSE characters: a line of the list, not the whole doc.
LONG = 160
CLAUSE = 40


def first_sentence(paragraph):
    """Up to the first full stop outside brackets, quotes and code: "The
    map's pages (PIX-266: "it grew."). Then..." keeps its brackets whole.
    A long one stops at its first clause."""
    depth = 0
    quoted = {'"': False, "`": False}
    clause = None
    for i, char in enumerate(paragraph):
        if char in quoted:
            quoted[char] = not quoted[char]
        elif char in "([":
            depth += 1
        elif char in ")]":
            depth = max(0, depth - 1)
        elif depth == 0 and not any(quoted.values()):
            rest = paragraph[i : i + 3]
            if char == "." and (i + 1 == len(paragraph) or paragraph[i + 1] == " "):
                sentence = paragraph[: i + 1]
                break
            if clause is None and i >= CLAUSE and (rest[:2] in (": ", "; ") or rest == " - "):
                clause = i
    else:
        sentence = paragraph
    if len(sentence) > LONG and clause is not None:
        return paragraph[:clause]
    return sentence


def lines():
    out = []
    for path in sorted((GODOT / "scripts").rglob("*.gd")):
        with open(path, encoding="utf-8") as script:
            said = first_sentence(doc_paragraph(script))
        out.append(f"- `{path.relative_to(GODOT).as_posix()}` — {said or '(no doc yet)'}")
    return out


def written(readme):
    """The README with its section as layout.py writes it."""
    head, begin, rest = readme.partition(BEGIN + "\n")
    _, end, tail = rest.partition(END)
    if not begin or not end:
        sys.exit(f"layout.py: README.md has no {BEGIN} ... {END} markers")
    return head + begin + "\n".join(lines()) + "\n" + end + tail


def main(argv):
    readme = README.read_text(encoding="utf-8")
    wanted = written(readme)
    if "--check" in argv:
        if wanted != readme:
            print("layout.py: godot/README.md's Layout is stale: run python3 godot/tools/layout.py")
            return 1
        print(f"layout.py: README's Layout is current ({len(lines())} scripts)")
        return 0
    if wanted != readme:
        README.write_text(wanted, encoding="utf-8")
    print(f"layout.py: README's Layout written ({len(lines())} scripts)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
