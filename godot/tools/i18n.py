#!/usr/bin/env python3
"""The game's strings for translation (PIX-195).

English is the source and each string its own key (gettext's msgid). This
gathers every string a player can read into godot/locale/messages.pot and
merges it into each godot/locale/<lang>.po, keeping what is translated:

- the data's words, picked by the rule the game translates them by at load
  (scripts/state/text.gd: a capital or a space, under a key that isn't an id);
- in the scripts, the templates handed to Text.t()/tr(), and the fixed
  strings a label or button shows (Godot translates those by itself), with
  the words of key footers and hints.

    python3 godot/tools/i18n.py           # write messages.pot, merge the .po files
    python3 godot/tools/i18n.py --check   # fail if messages.pot is stale (CI)
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
LOCALE = os.path.join(ROOT, "locale")
POT = os.path.join(LOCALE, "messages.pot")
DATA = ["catalog", "progression", "npcs", "combat", "economy", "town", "story", "changelog", "hints"]
MAPS_DATA = ["interactables"]
LANGUAGES = ["fr"]
HEADER = {
    "fr": 'Language: fr\\nPlural-Forms: nplurals=2; plural=(n > 1);\\n',
}


def not_words():
    source = open(os.path.join(ROOT, "scripts/state/text.gd")).read()
    block = source.split("const NOT_WORDS := [", 1)[1].split("]", 1)[0]
    return set(re.findall(r'"([^"]+)"', block))


def is_words(key, value, deny):
    if key in deny:
        return False
    return value != value.lower() or " " in value


def walk(value, key, deny, where, out):
    if isinstance(value, dict):
        for k, v in value.items():
            if isinstance(v, str):
                if is_words(str(k), v, deny):
                    out.setdefault(v, where)
            else:
                walk(v, str(k), deny, where, out)
    elif isinstance(value, list):
        for v in value:
            if isinstance(v, str):
                if is_words(key, v, deny):
                    out.setdefault(v, where)
            else:
                walk(v, key, deny, where, out)


LITERAL = r'"((?:[^"\\\n]|\\.)*)"'
CALLED = re.compile(r'(?:Text\.t|(?<![\w.])tr|tr_n)\(\s*' + LITERAL)
ANY = re.compile(LITERAL)
FOOTER = re.compile(r'UiStyle\.footer\(\s*' + LITERAL)
HINTS = re.compile(r'UiStyle\.hints\(\s*\[([^\]]*)\]')


ESCAPES = {"n": "\n", "t": "\t", '"': '"', "\\": "\\", "'": "'"}


def unescape(text):
    """A GDScript string literal's text, its escapes resolved."""
    def one(match):
        code = match.group(1)
        if code.startswith("u"):
            return chr(int(code[1:], 16))
        return ESCAPES.get(code, code)
    return re.sub(r"\\(u[0-9a-fA-F]{4}|.)", one, text)


def prose(text):
    if not re.search(r"[A-Za-z]{2,}", text):
        return False
    if any(mark in text for mark in ("res://", "user://", ".png", ".json", ".gd", ".wav", ".tscn")):
        return False
    if re.fullmatch(r"[a-z0-9_:/.#-]+", text):
        return False  # an id, an action, a group, a colour
    return " " in text.strip() or bool(re.match(r"[A-Z][a-z]", text))


def from_scripts(out):
    for path in sorted(glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True)):
        name = os.path.relpath(path, ROOT)
        if name.endswith("harness.gd"):
            continue
        for number, line in enumerate(open(path, encoding="utf-8"), 1):
            stripped = line.strip()
            if stripped.startswith("#") or "print(" in line or "push_" in line:
                continue
            where = "%s:%d" % (name, number)
            for match in CALLED.finditer(line):
                out.setdefault(unescape(match.group(1)), where)
            for match in FOOTER.finditer(line):
                for command in re.split(r" {4,}", unescape(match.group(1)).strip()):
                    if "  " in command:
                        out.setdefault(command.split("  ", 1)[1].strip(), where)
            for match in HINTS.finditer(line):
                words = re.findall(LITERAL, match.group(1))
                for word in words[1::2]:
                    out.setdefault(unescape(word), where)
            for match in ANY.finditer(line):
                text = match.group(1)
                rest = line[match.end():].lstrip()
                if rest.startswith("%") or rest.startswith(":") and stripped.startswith(("\"", "{")) is False:
                    continue
                before = line[:match.start()]
                if re.search(r"(Text\.t|tr|tr_n|footer)\(\s*$", before):
                    continue
                if prose(unescape(text)):
                    out.setdefault(unescape(text), where)


def gather():
    deny = not_words()
    out = {}
    for name in DATA:
        walk(json.load(open(os.path.join(ROOT, "assets", "data", name + ".json"))), "", deny, "assets/data/%s.json" % name, out)
    for name in MAPS_DATA:
        walk(json.load(open(os.path.join(ROOT, "assets", "maps", name + ".json"))), "", deny, "assets/maps/%s.json" % name, out)
    from_scripts(out)
    return out


def quote(text):
    text = text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")
    return '"%s"' % text


def pot(strings):
    lines = [
        "# Pixelheim's strings, English as the source (PIX-195).",
        "# Generated by godot/tools/i18n.py - do not edit; translate in <lang>.po.",
        'msgid ""',
        'msgstr ""',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        "",
    ]
    for text, where in sorted(strings.items(), key=lambda kv: (kv[1], kv[0])):
        lines += ["#: " + where, "msgid " + quote(text), 'msgstr ""', ""]
    return "\n".join(lines)


def read_po(path):
    """msgid -> msgstr of a .po file (single-line entries, as written here)."""
    if not os.path.exists(path):
        return {}
    out = {}
    msgid = None
    for line in open(path, encoding="utf-8"):
        if line.startswith("msgid "):
            msgid = json.loads(line[6:])
        elif line.startswith("msgstr ") and msgid is not None:
            out[msgid] = json.loads(line[7:])
            msgid = None
    return out


def write_po(lang, strings):
    path = os.path.join(LOCALE, lang + ".po")
    known = read_po(path)
    lines = [
        "# Pixelheim in %s (PIX-195). Translate the msgstr lines; tools/i18n.py merges new strings in." % lang,
        'msgid ""',
        'msgstr ""',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        '"%s"' % HEADER[lang],
        "",
    ]
    for text, where in sorted(strings.items(), key=lambda kv: (kv[1], kv[0])):
        lines += ["#: " + where, "msgid " + quote(text), "msgstr " + quote(known.get(text, "")), ""]
    open(path, "w", encoding="utf-8").write("\n".join(lines))
    done = sum(1 for text in strings if known.get(text))
    print("%s.po: %d of %d translated" % (lang, done, len(strings)))


def main():
    strings = gather()
    text = pot(strings)
    if "--check" in sys.argv:
        current = open(POT, encoding="utf-8").read() if os.path.exists(POT) else ""
        if current != text:
            sys.exit("locale/messages.pot is stale: run python3 godot/tools/i18n.py")
        print("messages.pot is current (%d strings)" % len(strings))
        return
    os.makedirs(LOCALE, exist_ok=True)
    open(POT, "w", encoding="utf-8").write(text)
    print("messages.pot: %d strings" % len(strings))
    for lang in LANGUAGES:
        write_po(lang, strings)


if __name__ == "__main__":
    main()
