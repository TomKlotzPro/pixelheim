// Renders the web game's synth (src/audio) to WAVs for the Godot build
// (PIX-128): the same oscillators, buses and echo, on an OfflineAudioContext
// in headless Chromium, so both builds sound alike. Writes
// godot/assets/audio/{sfx,music,ambience}/ and godot/assets/data/audio.json.
// Re-run with `pnpm audio:render` after changing src/audio; the noise is
// random, so files differ run to run and CI does not check them. Renders run
// one at a time: one page, one shared synth context.
import { existsSync, mkdirSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "@playwright/test";
import { build } from "vite";
import { TRACK_NAMES, loopBeats } from "../src/audio/music";
import { TICK_MS } from "../src/audio/ambience";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT = path.join(ROOT, "godot/assets/audio");
const VARIANTS = 4;

const bundle = await build({
  configFile: false,
  logLevel: "silent",
  build: {
    write: false,
    minify: false,
    lib: { entry: path.join(ROOT, "scripts/audio/render-entry.ts"), formats: ["iife"], name: "PixelheimAudioRender" },
  },
});
const output = (Array.isArray(bundle) ? bundle[0] : bundle) as { output: { code?: string }[] };
const code = output.output.find((chunk) => chunk.code)?.code;
if (!code) throw new Error("render entry did not bundle");

const browser = await chromium.launch();
const page = await browser.newPage();
await page.setContent("<!doctype html><html><body></body></html>");
await page.addScriptTag({ content: code });

const write = (folder: string, name: string, base64: string) => {
  mkdirSync(path.join(OUT, folder), { recursive: true });
  writeFileSync(path.join(OUT, folder, `${name}.wav`), Buffer.from(base64, "base64"));
};
// Old renders go (a removed sound must not linger); Godot's .import files stay.
for (const folder of ["sfx", "music", "ambience"]) {
  const dir = path.join(OUT, folder);
  if (!existsSync(dir)) continue;
  for (const file of readdirSync(dir)) if (file.endsWith(".wav")) rmSync(path.join(dir, file));
}

type Api = {
  stingers: string[];
  palettes: Record<string, number[]>;
};
const api = (await page.evaluate("({ stingers: pixelheimAudio.stingers, palettes: pixelheimAudio.palettes })")) as Api;

for (const name of api.stingers) {
  write("sfx", name, (await page.evaluate(`pixelheimAudio.stinger(${JSON.stringify(name)})`)) as string);
}
const tracks: Record<string, { seconds: number; beats: number }> = {};
for (const name of TRACK_NAMES) {
  const result = (await page.evaluate(`pixelheimAudio.track(${JSON.stringify(name)})`)) as {
    seconds: number;
    wav: string;
  };
  write("music", name, result.wav);
  tracks[name] = { seconds: result.seconds, beats: loopBeats(name) };
}
const ambience: Record<string, { chance: number; variants: number }[]> = {};
for (const [place, chances] of Object.entries(api.palettes)) {
  ambience[place] = chances.map((chance) => ({ chance, variants: VARIANTS }));
  for (let index = 0; index < chances.length; index++) {
    for (let variant = 0; variant < VARIANTS; variant++) {
      const base64 = (await page.evaluate(`pixelheimAudio.ambient(${JSON.stringify(place)}, ${index})`)) as string;
      write("ambience", `${place}_${index}_${variant}`, base64);
    }
  }
}
await browser.close();

writeFileSync(
  path.join(ROOT, "godot/assets/data/audio.json"),
  `${JSON.stringify({ stingers: api.stingers, tracks, ambience, ambienceTick: TICK_MS / 1000 }, null, 2)}\n`,
);
console.log(
  `rendered ${api.stingers.length} stingers, ${TRACK_NAMES.length} themes, ambience for ${Object.keys(ambience).length} places`,
);
