"""The real game played unseen, one move at a time (PIX-423): an agent's
hands on the web build in headless Chrome, for playtests.

    play.py start [--port N] [--dir D] [--lang xx] [--role r --level n] [--map id --at x,y]
    play.py keys "right:1.2, e, esc"      # held 1.2 s, tapped, tapped
    play.py look [--out D]                # a screenshot and what the game knows, as JSON
    play.py stop

`start` leaves a small daemon on the port (8642, or the next free one; give
each its own --port when several start at once; the other commands take
--port too). It serves godot/export/web as web_perf.py does and opens it in
headless Chrome, muted, on a fresh profile in the session's folder that
`stop` throws away with its saves. Without options it is a plain launch
from the title, as a new player sees it; --role, --level, --map and --at
start a harness run's throwaway hero with those presets instead (`fight`
always `hurt`, never `kill`), the game's command line then:
--fixed-fps 60 -- --screenshot play --lang fr --role mage --level 5 --map overworld --at 93,33

The game runs only during a command: between commands the page gives the
engine no frames at all (the shim below; scripts/play_bridge.gd says when a
command is done), so thinking costs it nothing, and stepped at 60 a frame
is a sixtieth of a second however slowly Chrome draws it. A key is a Godot
key name (e, esc, enter, space, up, right, shift, 1, R...); `a+b` holds keys
together, `name:s` holds for s seconds (else a tap), `wait:s` waits.
Needs the export (with the private art copied in) and Playwright for Python
in a venv, run with the venv's python:

    mkdir -p godot/export/web && godot --headless --path godot --export-release Web export/web/index.html
    python3 -m venv /tmp/pw && /tmp/pw/bin/pip install playwright==1.56.0
    /tmp/pw/bin/python godot/tools/play.py start --dir /tmp/play
"""
import argparse
import functools
import http.server
import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
EXPORT = os.path.join(HERE, "..", "export", "web")
FIRST_PORT = 8642
# A session nobody has spoken to this long shuts itself, Chrome and all.
IDLE_S = 30 * 60
# What the harness says of a few keys, as Godot names them.
ALIASES = {"esc": "Escape", "pgup": "PageUp", "pgdn": "PageDown"}
# Before the page's own scripts: the game's command line, the first command
# (a second to boot into) and the frames held back while a command isn't running.
SHIM = """
window.pixelheimArgs = %s;
(() => {
  const raf = window.requestAnimationFrame.bind(window);
  let held = [];
  const play = window.pixelheimPlay = {command: %s, state: null, frozen: false, thaw() {
    play.frozen = false;
    const ready = held;
    held = [];
    ready.forEach((callback) => raf(callback));
  }};
  window.requestAnimationFrame = (callback) => {
    if (!play.frozen) return raf(callback);
    held.push(callback);
    return 0;
  };
})();
"""


def parse_keys(text):
    """`"right:1.2, e+up, wait:2"` as the bridge's steps: the keys pressed
    together and the seconds held (None: a tap)."""
    steps = []
    for part in text.split(","):
        part = part.strip()
        if not part:
            continue
        name, _, seconds = part.partition(":")
        if seconds:
            try:
                seconds = float(seconds)
            except ValueError:
                raise ValueError("%r: the time is seconds, as right:1.5" % part)
            if seconds < 0:
                raise ValueError("%r: a time can't be negative" % part)
        else:
            seconds = None
        names = [ALIASES.get(key.strip().lower(), key.strip()) for key in name.split("+")]
        if names == ["wait"]:
            if seconds is None:
                raise ValueError("wait takes its seconds, as wait:2")
            names = []
        elif "" in names:
            raise ValueError("%r: a key has no name" % part)
        steps.append({"keys": names, "seconds": seconds})
    if not steps:
        raise ValueError("no keys given")
    return steps


def game_args(options):
    """The game's command line for `start`: a plain launch, or with presets
    a harness run's (scripts/harness_flags.txt) that `play` keeps up."""
    presets = []
    for flag, value in (("--role", options.role), ("--level", options.level), ("--map", options.map), ("--at", options.at)):
        if value is not None:
            presets += [flag, str(value)]
    more = (options.flags or "").split()
    if "kill" in more:
        raise SystemExit("no kill: it swings for up to five minutes of play, through your own keys; fight with yours")
    # A playtest's fighter is hit, dodges and can fall: the harness's is untouchable without `hurt`.
    if "fight" in more and "hurt" not in more:
        more.append("hurt")
    presets += more
    flags = (["--screenshot", "play"] + (["--lang", options.lang] if options.lang else []) + presets) if presets else ["play"]
    return ["--fixed-fps", "60", "--"] + flags


def free_port(first=FIRST_PORT):
    for port in range(first, first + 100):
        with socket.socket() as probe:
            # As the daemon's server binds: a session just stopped leaves its port free, not taken.
            probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            try:
                probe.bind(("127.0.0.1", port))
                return port
            except OSError:
                continue
    raise SystemExit("no free port from %d" % first)


def parser():
    top = argparse.ArgumentParser(prog="play.py", description=__doc__.split("\n\n")[0])
    commands = top.add_subparsers(dest="command", required=True)
    start = commands.add_parser("start", help="open the game and leave it waiting")
    start.add_argument("--port", type=int, help="the session's port (default: %d or the next free one)" % FIRST_PORT)
    start.add_argument("--dir", help="the session's folder: its screenshots, log and Chrome profile (default: a new temp folder)")
    start.add_argument("--lang", help="the game's language (en, fr): the browser's, and a harness run's --lang")
    start.add_argument("--role", help="a new hero of that role (a harness preset)")
    start.add_argument("--level", type=int, help="a hero of that level (a harness preset)")
    start.add_argument("--map", help="start on that map's spawn (a harness preset)")
    start.add_argument("--at", help="x,y: stand the hero on that cell (a harness preset)")
    start.add_argument("--flags", help='more harness flags, as "fight --foe orc --foe-distance 3" (scripts/harness_flags.txt)')
    look = commands.add_parser("look", help="a screenshot and the game's state, as JSON")
    look.add_argument("--out", help="the folder the screenshot goes to (default: the session's)")
    keys = commands.add_parser("keys", help="press and hold keys, the game running only meanwhile")
    keys.add_argument("keys", help='as "right:1.2, e, esc, up+left:0.5, wait:2"')
    commands.add_parser("stop", help="close the game, Chrome and the daemon")
    serve = commands.add_parser("serve", help=argparse.SUPPRESS)
    serve.add_argument("--dir", required=True)
    serve.add_argument("--lang")
    serve.add_argument("--args", required=True)
    for command in (look, keys, commands.choices["stop"], serve):
        command.add_argument("--port", type=int, default=FIRST_PORT, help="the session's port (default: %d)" % FIRST_PORT)
    return top


def call(port, request, timeout=600):
    """One command to the session on `port`, its JSON answer."""
    body = json.dumps(request).encode()
    try:
        with urllib.request.urlopen("http://127.0.0.1:%d/" % port, body, timeout=timeout) as answer:
            return json.load(answer)
    except (ConnectionError, urllib.error.URLError) as error:
        raise SystemExit("no session on port %d (play.py start): %s" % (port, error))


def start(options):
    args = game_args(options)
    if not os.path.exists(os.path.join(EXPORT, "index.html")):
        raise SystemExit("no web export in %s: mkdir -p godot/export/web && godot --headless --path godot --export-release Web export/web/index.html" % EXPORT)
    port = options.port or free_port()
    if options.port and free_port(port) != port:
        raise SystemExit("port %d is taken" % port)
    folder = os.path.abspath(options.dir or tempfile.mkdtemp(prefix="pixelheim-play-"))
    os.makedirs(folder, exist_ok=True)
    log = os.path.join(folder, "daemon.log")
    with open(log, "w") as out:
        daemon = subprocess.Popen(
            [sys.executable, os.path.abspath(__file__), "serve", "--port", str(port), "--dir", folder,
             "--lang", options.lang or "", "--args", json.dumps(args)],
            stdout=out, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, start_new_session=True)
    # The daemon binds its port at once and answers once the game has booted: is it this one?
    for _ in range(300):
        if daemon.poll() is not None:
            break
        try:
            answer = call(port, {"command": "hello"})
        except SystemExit:
            time.sleep(0.2)
            continue
        # Two starts at once can both find the same port free: the other one's game isn't ours.
        if answer.get("pid") != daemon.pid:
            daemon.terminate()
            raise SystemExit("port %d answers another session: give each session its own --port" % port)
        print(json.dumps({"port": port, "dir": folder, **call(port, {"command": "look"})}, ensure_ascii=False))
        return
    with open(log) as out:
        sys.stderr.write(out.read()[-3000:])
    if daemon.poll() is None:
        daemon.terminate()
    raise SystemExit("the session didn't start (its log: %s)" % log)


def gone(pid, timeout_s=30):
    """Until the daemon has closed Chrome and gone; its whole group killed past the timeout."""
    for _ in range(timeout_s * 10):
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return
        time.sleep(0.1)
    sys.stderr.write("the session didn't close in %d s: killed\n" % timeout_s)
    os.killpg(pid, signal.SIGKILL)


def forget(profile):
    """The session's Chrome profile deleted, its saves with it; Chrome's
    last helpers may still be writing as it goes: until it's gone."""
    for _ in range(50):
        shutil.rmtree(profile, ignore_errors=True)
        if not os.path.exists(profile):
            return
        time.sleep(0.1)


class Quiet(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

    def log_message(self, *args):
        pass


class Session:
    """The daemon's side: the page, and what it said since the last look."""

    def __init__(self, page, folder):
        self.page = page
        self.folder = folder
        self.said = []
        self.looks = 0
        self.done = False
        page.on("console", lambda message: self.said.append("%s: %s" % (message.type, message.text))
                if message.type in ("error", "warning") else None)
        page.on("pageerror", lambda error: self.said.append("pageerror: %s" % error))

    def wait(self, timeout_s):
        """Until the bridge has answered the command and frozen the page."""
        self.page.wait_for_function("window.pixelheimPlay.frozen", polling=100, timeout=timeout_s * 1000)
        return json.loads(self.page.evaluate("window.pixelheimPlay.state"))

    def answer(self, request):
        command = request["command"]
        if command == "keys":
            seconds = sum(step["seconds"] or 0.1 for step in request["steps"])
            self.page.evaluate("(command) => { window.pixelheimPlay.command = command; window.pixelheimPlay.thaw(); }",
                               json.dumps(request["steps"]))
            return self.wait(60 + 20 * seconds)
        if command == "look":
            self.looks += 1
            folder = request.get("out") or self.folder
            os.makedirs(folder, exist_ok=True)
            shot = os.path.abspath(os.path.join(folder, "look-%03d.png" % self.looks))
            self.page.screenshot(path=shot)
            # Each line once, with how often it came (an error a frame would bury the rest).
            counted = {}
            for line in self.said:
                counted[line] = counted.get(line, 0) + 1
            self.said = []
            state = json.loads(self.page.evaluate("window.pixelheimPlay.state"))
            return {"shot": shot, **state, "errors": [line if n == 1 else "%s (x%d)" % (line, n) for line, n in counted.items()]}
        if command == "hello":  # `start`'s: whose session it is (the pid every answer carries)
            return {}
        if command == "stop":
            self.done = True
            return {"stopped": True, "profile": os.path.join(self.folder, "chrome-profile")}
        return {"error": "no command %s" % command}


def serve(options):
    """The daemon: the export served, Chrome on it, commands answered on the
    port until `stop` (or IDLE_S of silence)."""
    from playwright.sync_api import sync_playwright  # only here: the tests import this file

    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    session = None

    class Control(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            request = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            try:
                answer = session.answer(request)
            except Exception as error:  # the game hung or Chrome went: say so, keep serving
                answer = {"error": str(error).split("\n")[0], "errors": session.said[-20:]}
            # Whose answer it is: `start` checks it's its own daemon's, `stop` waits for it to go.
            answer["pid"] = os.getpid()
            body = json.dumps(answer, ensure_ascii=False).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    control = http.server.HTTPServer(("127.0.0.1", options.port), Control)
    files = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=EXPORT))
    threading.Thread(target=files.serve_forever, daemon=True).start()
    profile = os.path.join(options.dir, "chrome-profile")
    shutil.rmtree(profile, ignore_errors=True)
    try:
        with sync_playwright() as playwright:
            # Unseen and unheard, uncapped frames, WebGL in software where there's no GPU.
            context = playwright.chromium.launch_persistent_context(
                profile, channel="chrome", headless=True, viewport={"width": 1280, "height": 720},
                locale=options.lang or "en-US",
                args=["--mute-audio", "--disable-frame-rate-limit", "--disable-gpu-vsync", "--enable-unsafe-swiftshader"])
            page = context.pages[0] if context.pages else context.new_page()
            session = Session(page, options.dir)
            boot = json.dumps([{"keys": [], "seconds": 1}])
            page.add_init_script(SHIM % (options.args, json.dumps(boot)))
            page.goto("http://127.0.0.1:%d/index.html" % files.server_address[1])
            try:
                session.wait(300)
            except Exception:
                print("\n".join(session.said[-30:]), flush=True)  # what the page said, into daemon.log
                raise
            # The page's loading picture fades in its own time (web/shell.html), not the game's.
            page.wait_for_function("!document.getElementById('status')", polling=100, timeout=15000)
            print("ready on port %d" % options.port, flush=True)
            control.timeout = IDLE_S
            control.handle_timeout = lambda: setattr(session, "done", True)
            while not session.done:
                control.handle_request()
            context.close()
    finally:
        files.shutdown()
        control.server_close()
        forget(profile)


def main(argv=None):
    options = parser().parse_args(argv)
    if options.command == "start":
        start(options)
    elif options.command == "serve":
        serve(options)
    else:
        request = {"command": options.command}
        if options.command == "keys":
            try:
                request["steps"] = parse_keys(options.keys)
            except ValueError as error:
                raise SystemExit(str(error))
        if options.command == "look" and options.out:
            request["out"] = os.path.abspath(options.out)
        answer = call(options.port, request)
        if options.command == "stop":
            gone(answer["pid"])
            # A daemon killed or fallen on the way out left the profile behind: its Chrome has gone with it.
            forget(answer["profile"])
        print(json.dumps(answer, ensure_ascii=False))
        if "error" in answer:
            sys.exit(1)


if __name__ == "__main__":
    main()
