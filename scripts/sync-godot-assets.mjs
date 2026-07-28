#!/usr/bin/env node
// Syncs the Godot project's copies of generated art and maps from the web
// game's sources of truth (public/sprites + src/world/maps). Run
// `pnpm godot:sync` after `pnpm sprites` or a map edit; CI runs it with
// --check and fails on drift so the two projects can never diverge silently.
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SPRITES_SRC = path.join(ROOT, "public/sprites");
const SPRITES_DST = path.join(ROOT, "godot/assets/sprites");
const MAPS_SRC = path.join(ROOT, "src/world/maps");
const MAPS_DST = path.join(ROOT, "godot/assets/maps");

// What the Godot project consumes today; widen as migration phases land.
const SPRITE_PATTERNS = [/^tile_.*\.png$/, /^sign_.*\.png$/, /_sway\.png$/, /^water_shimmer\.png$/];
const SPRITE_EXTRAS = [
  "atlas.json",
  "hero_warrior.png",
  "hero_warrior_walk.png",
  "hero_warrior_walk_up.png",
  "slime.png",
  "slime_idle.png",
  "wolf.png",
  "wolf_idle.png",
];

const MAP_SOURCES = {
  "ashenreach.ts": "overworld.txt",
  "frontier.ts": "frontier.txt",
  "demo.ts": "demo.txt",
};

const check = process.argv.includes("--check");
const drifted = [];

function sync(destination, content) {
  const current = existsSync(destination) ? readFileSync(destination) : null;
  if (current && current.equals(Buffer.from(content))) return;
  if (check) {
    drifted.push(path.relative(ROOT, destination));
    return;
  }
  mkdirSync(path.dirname(destination), { recursive: true });
  writeFileSync(destination, content);
  console.log(`synced ${path.relative(ROOT, destination)}`);
}

/** Pulls the ASCII grid out of a map module's template literal. */
function extractMap(source, name) {
  const match = source.match(/`\n([\s\S]*?)`/);
  if (!match) throw new Error(`${name}: no map template literal found`);
  const lines = match[1]
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
  const widths = new Set(lines.map((line) => line.length));
  if (widths.size !== 1) {
    throw new Error(`${name}: ragged map rows (widths ${[...widths].join(", ")})`);
  }
  return lines.join("\n");
}

const spriteNames = readdirSync(SPRITES_SRC).filter((name) => SPRITE_PATTERNS.some((pattern) => pattern.test(name)));
for (const name of [...spriteNames, ...SPRITE_EXTRAS]) {
  sync(path.join(SPRITES_DST, name), readFileSync(path.join(SPRITES_SRC, name)));
}

for (const [source, target] of Object.entries(MAP_SOURCES)) {
  const module = readFileSync(path.join(MAPS_SRC, source), "utf8");
  sync(path.join(MAPS_DST, target), extractMap(module, source));
}

if (check && drifted.length > 0) {
  console.error(`godot assets out of sync — run \`pnpm godot:sync\`:\n  ${drifted.join("\n  ")}`);
  process.exit(1);
}
