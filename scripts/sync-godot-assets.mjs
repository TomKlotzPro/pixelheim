#!/usr/bin/env node
// Syncs what the Godot project still takes from the web game's sources of
// truth: the pixel font. (Maps and data are exported by scripts/export-maps.ts.)
// Its art is all Shade's now (PIX-137): the web's generated sprites stay with
// the classic edition. Run `pnpm godot:sync`; CI runs it with --check and
// fails on drift so the two projects can never diverge silently.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

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

// The web's pixel font (Press Start 2P, headings and the logo only).
sync(
  path.join(ROOT, "godot/assets/fonts/press-start-2p.woff2"),
  readFileSync(path.join(ROOT, "src/assets/fonts/press-start-2p.woff2")),
);

if (check && drifted.length > 0) {
  console.error(`godot assets out of sync — run \`pnpm godot:sync\`:\n  ${drifted.join("\n  ")}`);
  process.exit(1);
}
