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

// What the Godot project consumes today; widen as migration phases land.
const SPRITE_PATTERNS = [
  /^tile_.*\.png$/,
  /^sign_.*\.png$/,
  /^chest_.*\.png$/,
  /^icon_.*\.png$/,
  /_sway\.png$/,
  /^water_shimmer\.png$/,
  /^furniture_.*\.png$/,
  /^effect_.*\.png$/,
];
const SPRITE_EXTRAS = ["atlas.json", "road_glint.png", "herb_patch.png"];
// Item icons for the pack and the paperdoll (PIX-127): every sprite the
// exported catalog names (scripts/export-maps.ts writes it, and it's committed).
const CATALOG = path.join(ROOT, "godot/assets/data/catalog.json");
const ITEM_ICONS = existsSync(CATALOG)
  ? [...new Set(Object.values(JSON.parse(readFileSync(CATALOG, "utf8")).items).map((item) => `${item.sprite}.png`))]
  : [];

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

// Maps are exported separately by scripts/export-maps.ts, which imports the
// real map modules (programmatic maps and portal validation included).
const spriteNames = readdirSync(SPRITES_SRC).filter((name) => SPRITE_PATTERNS.some((pattern) => pattern.test(name)));
for (const name of new Set([...spriteNames, ...SPRITE_EXTRAS, ...ITEM_ICONS])) {
  sync(path.join(SPRITES_DST, name), readFileSync(path.join(SPRITES_SRC, name)));
}

// The web's pixel font (Press Start 2P, headings and the logo only).
sync(
  path.join(ROOT, "godot/assets/fonts/press-start-2p.woff2"),
  readFileSync(path.join(ROOT, "src/assets/fonts/press-start-2p.woff2")),
);

if (check && drifted.length > 0) {
  console.error(`godot assets out of sync — run \`pnpm godot:sync\`:\n  ${drifted.join("\n  ")}`);
  process.exit(1);
}
