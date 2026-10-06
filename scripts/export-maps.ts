#!/usr/bin/env tsx
// Exports every world map (plus chests and door signs) to godot/assets/maps/
// and the game-data catalog the save layer needs (PIX-122) to
// godot/assets/data/, by importing the game's real modules — programmatic
// maps, tier redraws, and all the module-load validation (portal links, chest
// placement) run for free. Part of `pnpm godot:sync`; CI runs with --check
// and fails on drift.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ITEMS } from "../src/game/economy/items";
import { RECRUITS } from "../src/game/settlers";
import { LEVELS } from "../src/game/hero/levels";
import { PATH_NODES } from "../src/game/hero/paths";
import { ROLES } from "../src/game/hero/roles";
import { SKILL_TREES } from "../src/game/hero/skillTree";
import { INN_REST, TOWN_SPAWN } from "../src/state/shared";
import { CHESTS } from "../src/world/chests";
import { NPCS } from "../src/world/npcs";
import { chartedMapId, MAP_NAMES } from "../src/world/mapNames";
import { MAPS } from "../src/world/maps";
import { signsOn } from "../src/world/signs";
import { WAYPOINTS } from "../src/world/waypoints";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const OUT = path.join(ROOT, "godot/assets/maps");
const DATA_OUT = path.join(ROOT, "godot/assets/data");

const check = process.argv.includes("--check");
const drifted: string[] = [];

function emit(name: string, data: unknown, dir = OUT): void {
  const payload = `${JSON.stringify(data)}\n`;
  const file = path.join(dir, name);
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
mkdirSync(DATA_OUT, { recursive: true });
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
  signs: Object.fromEntries(Object.keys(MAPS).map((id) => [id, signsOn(id)])),
  // Only the maps whose signs change once the hero owns the house (FOR SALE -> HOME).
  signsHouseOwned: Object.fromEntries(
    Object.keys(MAPS)
      .filter((id) => JSON.stringify(signsOn(id, true)) !== JSON.stringify(signsOn(id)))
      .map((id) => [id, signsOn(id, true)]),
  ),
  waypoints: WAYPOINTS,
});

// What the save layer must know to read, migrate and grow a web save: item
// slots and weights (gear migration, carry limits), role base stats (new
// heroes, the endurance backfill), each role's tier-0 skill roots in branch
// order (the pre-skill-tree backfill), and every carry-weight passive.
const carryBonus = (passive?: { carryBonus?: number }) => passive?.carryBonus ?? 0;
emit(
  "catalog.json",
  {
    items: Object.fromEntries(
      Object.values(ITEMS).map((item) => [
        item.id,
        {
          name: item.name,
          category: item.category,
          weight: item.weight,
          value: item.value,
          ...(item.slot ? { slot: item.slot } : {}),
          ...(item.grants ? { grants: item.grants } : {}),
        },
      ]),
    ),
    roles: Object.fromEntries(
      Object.values(ROLES).map((role) => [
        role.id,
        { name: role.name, baseStats: role.baseStats, growth: role.growth, resource: role.resource },
      ]),
    ),
    skillRoots: Object.fromEntries(
      Object.entries(SKILL_TREES).map(([roleId, tree]) => [
        roleId,
        tree
          .filter((node) => node.tier === 0)
          .toSorted((a, b) => a.branch - b.branch)
          .map((node) => node.id),
      ]),
    ),
    // Skill passives count when owned; a path node counts only as the hero's
    // deepest step (activeNode in paths.ts).
    carryBonus: {
      skillNodes: Object.fromEntries(
        Object.values(SKILL_TREES)
          .flat()
          .filter((node) => node.kind === "passive" && carryBonus(node.passive) > 0)
          .map((node) => [node.id, carryBonus(node.passive)]),
      ),
      pathNodes: Object.fromEntries(
        PATH_NODES.filter((node) => carryBonus(node.passive) > 0).map((node) => [node.id, carryBonus(node.passive)]),
      ),
    },
    // Every map's player-facing place name; interiors take their town's.
    places: Object.fromEntries(Object.keys(MAPS).map((id) => [id, MAP_NAMES[chartedMapId(id)]])),
    levelCount: LEVELS.length,
    townSpawn: TOWN_SPAWN,
    innRest: INN_REST,
  },
  DATA_OUT,
);

// Villagers (PIX-123): the fixed townsfolk, tier-gated settlers included, and
// the recruits who wait in the wilds until they move to town (PIX-92).
emit("npcs.json", { npcs: NPCS, recruits: RECRUITS }, DATA_OUT);

if (check && drifted.length > 0) {
  console.error(`godot maps out of sync — run \`pnpm godot:sync\`:\n  ${drifted.join("\n  ")}`);
  process.exit(1);
}
