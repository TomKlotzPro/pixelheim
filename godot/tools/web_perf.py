"""The web build measured (PIX-361): serves a web export, opens it in
headless Chrome with a harness command line (the page's
window.pixelheimArgs, which web/shell.html hands the engine), and reads the
numbers the harness leaves on the page (window.pixelheimPerf).

The export is single-threaded, so it needs no COOP/COEP headers: it is
served as GitHub Pages serves it, the .wasm as application/wasm. Chrome's
frame rate is uncapped and the run stepped (--fixed-fps 60, as flows.sh's),
so frames run back to back and cpu= is what a frame costs, as headless on
the desktop. Needs Playwright for Python and Google Chrome (no browser
download):

    godot --headless --path godot --export-release Web export/web/index.html
    python3 -m venv /tmp/pw && /tmp/pw/bin/pip install playwright==1.56.0
    /tmp/pw/bin/python godot/tools/web_perf.py [--out web-perf.json]
"""
import argparse
import functools
import http.server
import json
import os
import sys
import threading
import time

EXPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "export", "web")
# The desktop's cpu-night and cpu-line flows (flows.txt), with PerfProbe's
# sample and the crossing's frames. test_harness_flags reads these lines.
RUNS = {
    "night": "--fixed-fps 60 -- --screenshot --map overworld night cpu perf --wait 2 --shot user://web_perf.png",
    "line": "--fixed-fps 60 -- --screenshot --map overworld --at 93,33 seamless --walk r,r,r cpu crossing --wait 1 --shot user://web_perf.png",
}


class Quiet(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

    def log_message(self, *args):
        pass


def measure(browser, url, args, timeout_s):
    """One harness run on the page: its numbers, timed from the page's load."""
    page = browser.new_page(viewport={"width": 1280, "height": 720})
    said = []
    page.on("console", lambda message: said.append(message.text))
    page.add_init_script("window.pixelheimArgs = " + json.dumps(args.split()))
    began = time.monotonic()
    try:
        page.goto(url)
        page.wait_for_function("window.pixelheimPerf", timeout=timeout_s * 1000)
    except Exception:
        print("\n".join(said[-30:]), file=sys.stderr)
        raise
    numbers = page.evaluate("window.pixelheimPerf")
    numbers["seconds"] = round(time.monotonic() - began, 1)
    page.close()
    return numbers


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("export", nargs="?", default=EXPORT, help="the web export's folder")
    parser.add_argument("--out", help="write the numbers here as JSON")
    parser.add_argument("--timeout", type=int, default=240, help="seconds a run may take")
    options = parser.parse_args()
    from playwright.sync_api import sync_playwright  # only here: the tests import this file

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=options.export))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = "http://127.0.0.1:%d/index.html" % server.server_address[1]
    with sync_playwright() as playwright:
        # Uncapped frames; WebGL in software where there's no GPU (CI).
        browser = playwright.chromium.launch(channel="chrome", args=[
            "--disable-frame-rate-limit", "--disable-gpu-vsync", "--enable-unsafe-swiftshader"])
        result = {"chrome": browser.version, "runs": {}}
        for name, args in RUNS.items():
            numbers = measure(browser, url, args, options.timeout)
            result["runs"][name] = numbers
            print("WEB %s: map=%s cpu=%s frames=%s %ss | %s" % (
                name, numbers["map"], numbers["cpu"], numbers["frames"] or "-", numbers["seconds"], numbers["perf"] or "-"))
        browser.close()
    server.shutdown()
    if options.out:
        with open(options.out, "w") as out:
            json.dump(result, out, indent=1)


if __name__ == "__main__":
    main()
