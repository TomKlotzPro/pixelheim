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
const SPRITE_EXTRAS = [
  "atlas.json",
  "road_glint.png",
  "herb_patch.png",
  "hero_warrior.png",
  "hero_warrior_walk.png",
  "hero_warrior_walk_up.png",
  "slime.png",
  "wolf.png",
  // the bestiary's two-beat idle sheets (PIX-126)
  ...["slime", "goblin", "skeleton", "wolf", "orc", "ghost", "golem", "troll", "wyvern", "dragon"].map(
    (id) => `${id}_idle.png`,
  ),
  ...["boneknight", "shade", "mimic", "imp", "lich"].map((id) => `${id}_idle.png`),
  // villagers' two-beat idle sheets (PIX-123)
  "elder_idle.png",
  "villager_idle.png",
  "villager_woman_idle.png",
  "merchant_idle.png",
  "smith_idle.png",
  "alchemist_idle.png",
  "innkeeper_idle.png",
  "mayor_idle.png",
];

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
for (const name of [...spriteNames, ...SPRITE_EXTRAS]) {
  sync(path.join(SPRITES_DST, name), readFileSync(path.join(SPRITES_SRC, name)));
}

if (check && drifted.length > 0) {
  console.error(`godot assets out of sync — run \`pnpm godot:sync\`:\n  ${drifted.join("\n  ")}`);
  process.exit(1);
}
