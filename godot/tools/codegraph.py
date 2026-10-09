#!/usr/bin/env python3
## The game's code as a graph (Solid Ground, P-PIX-16), for graphify.
## graphify reads a dozen languages but not GDScript, so this reads the
## scripts itself and writes graphify-out/graph.json at the repo root in
## graphify's own shape (networkx node_link_data with "links", graphify's ids
## and fields). graphify's commands then work on the game, with no LLM:
##
##     python3 godot/tools/codegraph.py [repo] [--tests] [--private]
##     graphify cluster-only . --no-label     # communities, GRAPH_REPORT.md
##     graphify god-nodes --top 15            # the hubs
##     graphify affected godot_scripts_world  # what leans on world.gd
##     graphify query "camera"
##
## It reads godot/scripts/**/*.gd (never godot/addons/; the tests only with
## --tests). Nodes: each script, named by its class_name, else its autoload
## name, else its res:// path; and each top-level func and signal, which its
## script "contains". Edges start from the func they are written in (from the
## script itself outside any func):
## - extends     the script extends another, by class_name or path;
## - imports     preload() or load() of another script;
## - calls       Foo.bar(), GameState.bar(), world.bar(), a typed variable's
##               method, an inherited or the script's own func, Foo.new(), or
##               such a func handed over as a Callable. `private: true` when
##               it reaches through a receiver into another script's _func;
## - references  a class as a type (`: Foo`, `-> Foo`, `as`, `is`), the
##               variables and constants read through it (`members`, and
##               `private` when it reads another script's _var), and a signal
##               connected to (`context: "signal"`).
## Each edge says how often (`count`) and how its receiver was known (`via`:
## class, autoload, typed, self, inherited, world...). Each node carries its
## ## doc comment as `rationale`, the text graphify's query searches.
## An untyped `world` is the main scene (world.gd), and so is
## get_tree().current_scene: those edges are INFERRED, like a signal
## connected on a receiver of unknown type that only one script declares.
## Everything else is EXTRACTED. Regexes, not a parser: right about the
## shape of the code, not a compiler's word for it. --private lists every
## call into another script's _func, the coupling Solid Ground takes apart.
import argparse
import json
import re
import subprocess
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
## The main scene's script (scenes/main.tscn): what an untyped `world` holds.
WORLD = "res://scripts/world.gd"
## graphify's scores per confidence (graphify/export.py); a guess at `world`
## is a good one, a signal matched by its name alone less so.
SCORE = {"EXTRACTED": 1.0, "INFERRED": 0.8, "INFERRED_SIGNAL": 0.6}

# The declarations that start a top-level line.
CLASS_NAME = re.compile(r"^class_name\s+(\w+)(?:\s+extends\s+(\"[^\"]*\"|[\w.]+))?")
EXTENDS = re.compile(r"^extends\s+(\"[^\"]*\"|[\w.]+)")
FUNC = re.compile(r"^(static\s+)?func\s+(\w+)\s*\(")
SIGNAL = re.compile(r"^signal\s+(\w+)")
MEMBER = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?(?:var|const)\s+(\w+)\s*(?::\s*([\w.]+))?\s*(?::?=\s*(.*))?")
ENUM = re.compile(r"^enum\s+(\w+)")
# What a func body declares: its locals, loop variables and lambdas' params.
LOCAL = re.compile(r"^\s*(?:var|const)\s+(\w+)\s*(?::\s*([\w.]+))?\s*(?::?=\s*(.*))?")
LOOP = re.compile(r"\bfor\s+(\w+)\s*(?::\s*([\w.]+))?\s+in\b")
ASSIGN = re.compile(r"^\s+(?:self\.)?(\w+)\s*=(?!=)\s*(.+)$")
LAMBDA = re.compile(r"\bfunc\s*\(([^)]*)\)")
PARAM = re.compile(r"(\w+)\s*(?::\s*([\w.]+))?\s*(?::?=[^,]*)?(?:,|$)")
# What a line uses.
PRELOAD = re.compile(r"\b(preload|load)\(\s*\"(res://[^\"]+\.gd)\"\s*\)")
CHAIN = re.compile(r"(?<![\w.])([A-Za-z_]\w*)((?:\s*\.\s*[A-Za-z_]\w*)+)(\s*\()?")
CALL = re.compile(r"(?<![\w.])([A-Za-z_]\w*)\s*\(")
NAME = re.compile(r"(?<![\w.])([A-Za-z_]\w*)\b(?!\s*[.(])")
SCENE = re.compile(r"\bcurrent_scene\s*\.\s*([A-Za-z_]\w*)(\s*\()?")


## graphify's ids (graphify/ids.py), so its lookups agree with ours:
## casefold and NFKC to a fixpoint, runs of non-word characters to one "_".
def normalize_id(text):
    for _ in range(6):
        folded = unicodedata.normalize("NFKC", text.casefold())
        if folded == text:
            break
        text = folded
    text = re.sub(r"[^\w]+", "_", text, flags=re.UNICODE)
    return re.sub(r"_+", "_", text).strip("_")


def make_id(*parts):
    return normalize_id("_".join(p.strip("_.") for p in parts if p))


## Each line twice: without its comment (strings kept, for the paths in
## preload and extends), and with every string's contents blanked as well, so
## a name inside a message or a path is never read as code. Only a triple
## quote runs on past its line.
def scrub(lines):
    code, bare = [], []
    quote = None
    for line in lines:
        kept, blank = [], []
        i = 0
        while i < len(line):
            c = line[i]
            if quote:
                if c == "\\":
                    kept.append(line[i:i + 2])
                    i += 2
                elif line.startswith(quote, i):
                    kept.append(quote)
                    blank.append(quote)
                    i += len(quote)
                    quote = None
                else:
                    kept.append(c)
                    i += 1
            elif c == "#":
                break
            elif c in "\"'":
                quote = c * 3 if line.startswith(c * 3, i) else c
                kept.append(quote)
                blank.append(quote)
                i += len(quote)
            else:
                kept.append(c)
                blank.append(c)
                i += 1
        if quote and len(quote) == 1:
            quote = None
        code.append("".join(kept).rstrip())
        bare.append("".join(blank).rstrip())
    return code, bare


class Func:
    def __init__(self, script, name, line, static, params):
        self.script = script
        self.name = name
        self.line = line
        self.end = line
        self.static = static
        ## param name -> its type as written ("" when untyped)
        self.params = params
        self.id = None


class Script:
    def __init__(self, path, repo):
        self.rel = path.relative_to(repo).as_posix()
        self.res = "res://" + path.relative_to(repo / "godot").as_posix()
        self.id = make_id(path.relative_to(repo).with_suffix("").as_posix())
        self.raw = path.read_text(encoding="utf-8").splitlines()
        self.length = len(self.raw)
        self.code, self.bare = scrub(self.raw)
        self.class_name = None
        self.autoload = None
        ## as written: a class name or a "res://" path
        self.extends = None
        self.extends_line = 1
        ## the project script it extends, if it does
        self.base = None
        self.funcs = {}
        ## signal name -> [line, node id]
        self.signals = {}
        ## variable, constant or enum name -> (type, initializer) as written
        self.members = {}
        ## the top-level func each line belongs to (None outside any)
        self.owner = []
        ## the script's own ## doc comment, and each func's and signal's
        self.doc = None
        self.docs = {}
        self._read()

    ## Top-level lines declare; an indented one belongs to the func above it.
    ## Inner classes are part of the script: their lines belong to no func.
    ## A ## block belongs to the declaration right under it; the first one,
    ## if a blank line ends it before anything is declared, to the script.
    def _read(self):
        current = None
        doc = []
        declared = False
        for i, line in enumerate(self.bare):
            if self.raw[i].startswith("##"):
                doc.append(self.raw[i][2:].strip())
            elif not self.raw[i].strip():
                if doc and not declared and self.doc is None:
                    self.doc = " ".join(doc)
                doc = []
            if line.strip() and line[0] not in " \t":
                current = None
                code = self.code[i]
                note = " ".join(doc) or None
                doc = []
                if m := CLASS_NAME.match(code):
                    self.class_name = m.group(1)
                    if m.group(2):
                        self.extends, self.extends_line = m.group(2), i + 1
                elif m := EXTENDS.match(code):
                    self.extends, self.extends_line = m.group(1), i + 1
                elif m := FUNC.match(line):
                    current = m.group(2)
                    signature = line[m.end():].split(")", 1)[0]
                    params = {p: t or "" for p, t in PARAM.findall(signature) if p}
                    self.funcs[current] = Func(self, current, i + 1, bool(m.group(1)), params)
                    self.docs[current] = note
                    declared = True
                elif m := SIGNAL.match(line):
                    self.signals[m.group(1)] = [i + 1, None]
                    self.docs["signal " + m.group(1)] = note
                    declared = True
                elif m := MEMBER.match(code):
                    self.members[m.group(1)] = (m.group(2) or "", m.group(3) or "")
                    declared = True
                elif m := ENUM.match(line):
                    self.members[m.group(1)] = ("", "")
                    declared = True
            elif current and line.strip():
                self.funcs[current].end = i + 1
            self.owner.append(current)

    ## The short name its funcs and signals are labelled with.
    @property
    def short(self):
        return self.class_name or self.autoload or Path(self.rel).stem

    @property
    def label(self):
        return self.class_name or self.autoload or self.res


class Graph:
    def __init__(self, scripts, autoloads):
        self.scripts = scripts
        self.by_res = {s.res: s for s in scripts}
        for name, res in autoloads.items():
            if res in self.by_res:
                self.by_res[res].autoload = name
        ## class_name and autoload names -> their scripts
        self.globals = {}
        for s in scripts:
            for name in (s.class_name, s.autoload):
                if name:
                    self.globals[name] = s
        self.world = self.by_res.get(WORLD)
        ## signal name -> the scripts that declare it
        self.signal_owners = defaultdict(list)
        self.nodes = {}
        self.edges = {}
        self._holding = set()
        self._name_nodes()
        for s in scripts:
            if s.extends:
                path = s.extends.strip('"')
                s.base = self.by_res.get(path) if path.startswith("res://") else self.globals.get(path.split(".")[0])
        # Nodes are built in code: `var dock: Control` declared, then
        # `dock = preload("res://scripts/hud_dock.gd").new()` in a func. The
        # first such assignment says what a member with no initializer holds.
        for s in scripts:
            for code in s.code:
                m = ASSIGN.match(code)
                if m and m.group(1) in s.members and not s.members[m.group(1)][1]:
                    type_name = s.members[m.group(1)][0]
                    if self.holds(s, {}, type_name, "") is None and self.holds(s, {}, "", m.group(2)) is not None:
                        s.members[m.group(1)] = (type_name, m.group(2))
        for s in scripts:
            self._scan(s)

    ## graphify's ids: the file's path without its extension for the script,
    ## the script's id and the name for a func (graphify's file and symbol
    ## ids). `_foo` and `foo` would share one, as would world.gd's `tiles_x`
    ## and world_tiles.gd's `x`; the later one takes a qualified id.
    def _name_nodes(self):
        taken = set()

        def unique(*parts):
            nid = make_id(*parts)
            n = 2
            while nid in taken:
                nid = make_id(*parts[:-1], "%s_%d" % (parts[-1], n))
                n += 1
            taken.add(nid)
            return nid

        for s in self.scripts:
            taken.add(s.id)
        # The ## doc comments go in `rationale`, the text graphify's query
        # searches beside the labels; a script's variables in `attributes`.
        for s in self.scripts:
            self._node(s.id, s.label, s.rel, 1, kind="script", res_path=s.res, lines=s.length,
                       functions=len(s.funcs), signals=len(s.signals), class_name=s.class_name,
                       autoload=s.autoload, extends=(s.extends or "").strip('"') or None,
                       rationale=s.doc, attributes={"members": sorted(s.members)} if s.members else None)
            for name, f in s.funcs.items():
                f.id = unique(s.id, name) if make_id(s.id, name) not in taken else unique(s.id, "func", name)
                self._node(f.id, "%s.%s()" % (s.short, name), s.rel, f.line, kind="function",
                           private=name.startswith("_"), static=f.static, lines=f.end - f.line + 1,
                           rationale=s.docs.get(name))
                self.edge(s, s.id, f.id, "contains", f.line)
            for name, entry in s.signals.items():
                entry[1] = unique(s.id, "signal", name)
                self._node(entry[1], "%s.%s (signal)" % (s.short, name), s.rel, entry[0], kind="signal",
                           rationale=s.docs.get("signal " + name))
                self.edge(s, s.id, entry[1], "contains", entry[0])
                self.signal_owners[name].append(s)

    def _node(self, nid, label, source_file, line, **extra):
        node = {"id": nid, "label": label, "file_type": "code", "source_file": source_file,
                "source_location": "L%d" % line}
        node.update({k: v for k, v in sorted(extra.items()) if v is not None})
        self.nodes[nid] = node

    ## One edge per (source, target, relation, context, private): `count`
    ## says how often, the location is the first time, `members` what it read.
    def edge(self, script, source, target, relation, line, context=None, via=None,
             confidence="EXTRACTED", private=False, member=None):
        if source == target:
            return
        key = (source, target, relation, context or "", private)
        e = self.edges.get(key)
        if e is None:
            e = {"source": source, "target": target, "relation": relation,
                 "confidence": "INFERRED" if confidence.startswith("INFERRED") else confidence,
                 "confidence_score": SCORE[confidence], "source_file": script.rel,
                 "source_location": "L%d" % line, "weight": 1.0, "count": 0}
            if context:
                e["context"] = context
            if via:
                e["via"] = via
            if private:
                e["private"] = True
            self.edges[key] = e
        e["count"] += 1
        if member and member not in e.setdefault("members", []):
            e["members"].append(member)
            e["members"].sort()

    ## `name` among a script's funcs, signals or members, else its bases':
    ## (the script that declares it, the entry), or (None, None).
    def find(self, script, table, name):
        seen = set()
        while script is not None and script.id not in seen:
            seen.add(script.id)
            if name in getattr(script, table):
                return script, getattr(script, table)[name]
            script = script.base
        return None, None

    ## The project script a declaration holds: from its type when that is
    ## one, else from Foo.new(), preload("...gd") or a chain of typed members.
    def holds(self, script, scope, type_name, init):
        key = (script.id, type_name, init)
        if key in self._holding:
            return None  # a declaration that leads back to itself
        self._holding.add(key)
        try:
            if type_name[:1].isupper():
                held = self.receiver(script, type_name.split(".")[0], {})[0]
                if held is not None:
                    return held
            if m := PRELOAD.match(init):
                return self.by_res.get(m.group(2))
            if m := CHAIN.match(init):
                chain = [p.strip() for p in (m.group(1) + m.group(2)).split(".")]
                if chain[-1] == "new" or not m.group(3):
                    return self.follow(script, scope, chain)[2]
            return None
        finally:
            self._holding.discard(key)

    ## What `name` holds where it's read: (script, how it was reached).
    def receiver(self, script, name, scope):
        if name == "self":
            return script, "self"
        if name == "super":
            return script.base, "inherited"
        if scope.get(name) is not None:
            return scope[name], "typed"
        if name not in scope:
            owner, member = self.find(script, "members", name)
            if member is not None:
                held = self.holds(owner, {}, *member)
                if held is not None:
                    # A preloaded class (const Foo := preload(...)), or an instance.
                    const = member[1].startswith("preload") and ".new(" not in member[1]
                    return held, "preload" if const else "typed"
            if name in self.globals:
                held = self.globals[name]
                return held, "autoload" if held.autoload == name else "class"
        if name == "world" and self.world is not None and script is not self.world:
            return self.world, "world"
        return None, None

    ## Where a dotted chain (a.b.c) leads from what `a` holds: the hops it
    ## makes - a "member" read on the way, then the "func", "signal" or "new"
    ## it ends on - how `a` was reached, and the script the last hop holds.
    def follow(self, script, scope, chain):
        target, via = self.receiver(script, chain[0], scope)
        hops = []
        for name in chain[1:]:
            if target is None:
                break
            if name == "new":
                hops.append(("new", target, name))
                break
            owner, func = self.find(target, "funcs", name)
            if func is not None:
                hops.append(("func", owner, name))
                return hops, via, None
            owner, signal = self.find(target, "signals", name)
            if signal is not None:
                hops.append(("signal", owner, name))
                return hops, via, None
            owner, member = self.find(target, "members", name)
            if member is None:
                # Godot's own (add_child, position): a class's is still a
                # dependency on the class, a node's says nothing.
                if via in ("class", "autoload") and not hops:
                    hops.append(("member", target, name))
                return hops, via, None
            hops.append(("member", owner, name))
            target = self.holds(owner, {}, *member)
        return hops, via, target

    ## A script's lines, each from the func it's written in: its locals and
    ## params give the types its receivers hold.
    def _scan(self, s):
        if s.base is not None:
            self.edge(s, s.id, s.base.id, "extends", s.extends_line)
        scope = {}
        for i, (code, bare) in enumerate(zip(s.code, s.bare)):
            if not bare.strip():
                continue
            line = i + 1
            current = s.funcs[s.owner[i]] if s.owner[i] else None
            if bare[0] not in " \t":
                scope = {}
                if current is not None:
                    for name, type_name in current.params.items():
                        scope[name] = self.holds(s, {}, type_name, "")
            source = current.id if current else s.id
            for kind, path in PRELOAD.findall(code):
                if path in self.by_res:
                    self.edge(s, source, self.by_res[path].id, "imports", line, context=kind)
            for m in CHAIN.finditer(bare):
                chain = [p.strip() for p in (m.group(1) + m.group(2)).split(".")]
                self._chain(s, source, scope, chain, bool(m.group(3)), line)
            for m in SCENE.finditer(bare):
                self._chain(s, source, scope, ["world", m.group(1)], bool(m.group(2)), line, via="current_scene")
            for m in CALL.finditer(bare):
                if bare[:m.start()].rstrip().endswith("func"):
                    continue
                self._own(s, source, m.group(1), line, None)
            for m in NAME.finditer(bare):
                name = m.group(1)
                if name in scope or bare[:m.start()].rstrip().endswith(("func", "signal", "class_name", "extends")):
                    continue
                if name in self.globals and name[0].isupper():
                    if self.globals[name] is not s and bare.lstrip()[:7] not in ("extends", "class_n"):
                        self.edge(s, source, self.globals[name].id, "references", line, context="type")
                elif current is not None and self.find(s, "members", name)[1] is None:
                    self._own(s, source, name, line, "callable")
            # What this line declares, for the lines after it.
            if current is not None:
                if m := LOCAL.match(code):
                    scope[m.group(1)] = self.holds(s, scope, m.group(2) or "", m.group(3) or "")
                for name, type_name in LOOP.findall(bare):
                    scope[name] = self.holds(s, scope, type_name, "")
                for params in LAMBDA.findall(bare):
                    for name, type_name in PARAM.findall(params):
                        if name:
                            scope[name] = self.holds(s, scope, type_name, "")

    ## A func of the script or its bases, called bare or handed over.
    def _own(self, s, source, name, line, context):
        owner, func = self.find(s, "funcs", name)
        if func is not None:
            self.edge(s, source, func.id, "calls", line, context=context,
                      via="self" if owner is s else "inherited")

    def _chain(self, s, source, scope, chain, called, line, via=None):
        hops, reached, _ = self.follow(s, scope, chain)
        via = via or reached
        confidence = "INFERRED" if via in ("world", "current_scene") else "EXTRACTED"
        if not hops:
            # A signal connected on something of unknown type: the one script
            # that declares a signal of that name, if only one does.
            if len(chain) >= 3 and chain[-1] == "connect" and chain[0] != "self":
                owners = self.signal_owners.get(chain[-2], [])
                if len(owners) == 1 and owners[0] is not s and chain[-2] not in s.signals:
                    self.edge(s, source, owners[0].signals[chain[-2]][1], "references", line,
                              context="signal", via="signal name", confidence="INFERRED_SIGNAL")
            return
        for n, (kind, target, name) in enumerate(hops):
            last = 1 + n == len(chain) - 1
            # Another object's: past the first hop (self.view._foo), or
            # through anything but self and super.
            outside = target is not s and (n > 0 or via not in ("self", "inherited"))
            private = name.startswith("_") and outside
            if kind == "func":
                self.edge(s, source, target.funcs[name].id, "calls", line,
                          context=None if last and called else "callable", via=via,
                          confidence=confidence, private=private)
            elif kind == "new":
                self.edge(s, source, target.id, "calls", line, context="new", via=via, confidence=confidence)
            elif kind == "signal" and target is not s:
                after = chain[2 + n] if 2 + n < len(chain) else ""
                if after in ("connect", "emit"):
                    self.edge(s, source, target.signals[name][1], "references" if after == "connect" else "calls",
                              line, context="signal" if after == "connect" else "emit", via=via, confidence=confidence)
            elif kind == "member" and target is not s:
                self.edge(s, source, target.id, "references", line, context="member", via=via,
                          confidence=confidence, private=private, member=name)

    ## graph.json as graphify writes it (export.py to_json): node_link_data
    ## with "links", each item's keys id/label (source/target/relation) first,
    ## then sorted, so graphify's own rewrite only adds the communities.
    def data(self, commit):
        def canonical(item, lead):
            return {k: item[k] for k in [*lead, *sorted(k for k in item if k not in lead)] if k in item}

        nodes = [canonical(n, ("id", "label")) for _, n in sorted(self.nodes.items())]
        links = sorted(self.edges.values(), key=lambda e: (e["source"], e["target"], e["relation"], e.get("context", ""), e.get("private", False)))
        out = {"directed": True, "multigraph": False,
               "graph": {"schema_version": 1, "generator": "godot/tools/codegraph.py"},
               "nodes": nodes, "links": [canonical(e, ("source", "target", "relation")) for e in links],
               "hyperedges": []}
        if commit:
            out["built_at_commit"] = commit
        return out

    ## Every call that reaches into another script's _func, by the func
    ## called: who calls it and how often.
    def private_calls(self):
        by_target = defaultdict(lambda: defaultdict(int))
        for e in self.edges.values():
            if e.get("private") and e["relation"] == "calls":
                by_target[e["target"]][self.nodes[e["source"]]["label"]] += e["count"]
        lines = []
        for target, callers in sorted(by_target.items(), key=lambda kv: (self.nodes[kv[0]]["source_file"], -sum(kv[1].values()), kv[0])):
            ranked = sorted(callers.items(), key=lambda kv: (-kv[1], kv[0]))
            lines.append("%-32s %3d  %s" % (self.nodes[target]["label"], sum(callers.values()),
                                            ", ".join("%s x%d" % kv for kv in ranked)))
        return lines


## project.godot's [autoload] names (GameState, Sound) -> their res:// paths.
def autoloads(repo):
    found = {}
    section = None
    for line in (repo / "godot" / "project.godot").read_text(encoding="utf-8").splitlines():
        if line.startswith("["):
            section = line.strip()
        elif section == "[autoload]" and "=" in line:
            name, value = line.split("=", 1)
            found[name.strip()] = value.strip().strip('"').lstrip("*")
    return found


## The commit the graph was built from: graphify's report shows it, to tell
## a stale graph.
def head_commit(repo):
    try:
        return subprocess.run(["git", "-C", str(repo), "rev-parse", "HEAD"], capture_output=True,
                              text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def main():
    parser = argparse.ArgumentParser(description="The game's scripts as a graphify graph (graphify-out/graph.json).")
    parser.add_argument("repo", nargs="?", default=str(REPO), help="the repo root (or its godot/ folder)")
    parser.add_argument("--tests", action="store_true", help="read godot/test/ too")
    parser.add_argument("--private", action="store_true", help="list every call into another script's _func")
    args = parser.parse_args()
    repo = Path(args.repo).resolve()
    if not (repo / "godot" / "project.godot").exists() and (repo / "project.godot").exists():
        repo = repo.parent
    if not (repo / "godot" / "project.godot").exists():
        sys.exit("codegraph: no godot/project.godot under %s" % repo)
    folders = ["scripts"] + (["test"] if args.tests else [])
    paths = sorted(p for folder in folders for p in (repo / "godot" / folder).rglob("*.gd"))
    graph = Graph([Script(p, repo) for p in paths], autoloads(repo))
    out = repo / "graphify-out" / "graph.json"
    out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps(graph.data(head_commit(repo)), indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    kinds = defaultdict(int)
    for node in graph.nodes.values():
        kinds[node["kind"]] += 1
    relations = defaultdict(int)
    for e in graph.edges.values():
        relations[e["relation"]] += 1
    print("%s: %d scripts, %d funcs, %d signals; %d edges (%s)" % (
        out.relative_to(repo), kinds["script"], kinds["function"], kinds["signal"], len(graph.edges),
        ", ".join("%s %d" % kv for kv in sorted(relations.items(), key=lambda kv: -kv[1]))))
    private = sum(e["count"] for e in graph.edges.values() if e.get("private") and e["relation"] == "calls")
    print("%d calls reach into another script's _func (--private lists them)" % private)
    if args.private:
        print("\n".join(graph.private_calls()))


if __name__ == "__main__":
    main()
