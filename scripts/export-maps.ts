#!/usr/bin/env tsx
// Exports every world map (plus chests and door signs) to godot/assets/maps/
// by importing the game's real modules — programmatic maps, tier redraws,
// and all the module-load validation (portal links, chest placement) run for
// free. Part of `pnpm godot:sync`; CI runs with --check and fails on drift.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { CHESTS } from "../src/world/chests";
import { MAPS } from "../src/world/maps";
import { signsOn } from "../src/world/signs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT = path.join(ROOT, "godot/assets/maps");

const check = process.argv.includes("--check");
const drifted: string[] = [];

function emit(name: string, data: unknown): void {
  const payload = `${JSON.stringify(data)}\n`;
  const file = path.join(OUT, name);
  const current = existsSync(file) ? readFileSync(file, "utf8") : null;
  if (current === payload) return;
  if (check) {
    drifted.push(path.relative(ROOT, file));
    return;
  }
  writeFileSync(file, payload);
  console.log(`exported ${path.relative(ROOT, file)}`);
}

mkdirSync(OUT, { recursive: true });
for (const map of Object.values(MAPS)) {
  emit(`${map.id}.json`, {
    id: map.id,
    width: map.width,
    height: map.height,
    spawn: map.spawn,
    portals: map.portals,
    tiles: map.tiles,
  });
}

emit("interactables.json", {
  chests: CHESTS,
  // houseOwned=false until saves arrive (PIX-122): the sign reads FOR SALE.
  signs: Object.fromEntries(Object.keys(MAPS).map((id) => [id, signsOn(id)])),
});

if (check && drifted.length > 0) {
  console.error(`godot maps out of sync — run \`pnpm godot:sync\`:\n  ${drifted.join("\n  ")}`);
  process.exit(1);
}
