#!/usr/bin/env tsx
// Exports every world map to godot/assets/maps/<id>.json by importing the
// game's real map modules — programmatic maps, tier redraws, and the
// cross-map portal validation in src/world/maps/index.ts all run for free.
// Part of `pnpm godot:sync`; CI runs with --check and fails on drift.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { MAPS } from "../src/world/maps";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT = path.join(ROOT, "godot/assets/maps");

const check = process.argv.includes("--check");
const drifted: string[] = [];

mkdirSync(OUT, { recursive: true });
for (const map of Object.values(MAPS)) {
  const payload = `${JSON.stringify({
    id: map.id,
    width: map.width,
    height: map.height,
    spawn: map.spawn,
    portals: map.portals,
    tiles: map.tiles,
  })}\n`;
  const file = path.join(OUT, `${map.id}.json`);
  const current = existsSync(file) ? readFileSync(file, "utf8") : null;
  if (current === payload) continue;
  if (check) {
    drifted.push(path.relative(ROOT, file));
    continue;
  }
  writeFileSync(file, payload);
  console.log(`exported ${path.relative(ROOT, file)}`);
}

if (check && drifted.length > 0) {
  console.error(`godot maps out of sync — run \`pnpm godot:sync\`:\n  ${drifted.join("\n  ")}`);
  process.exit(1);
}
