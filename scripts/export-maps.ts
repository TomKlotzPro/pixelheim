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
import { JOB_LEVEL_CAP, JOB_STATIONS } from "../src/game/economy/jobs";
import { RARITIES } from "../src/game/economy/rarity";
import { RECIPES, REGION_MATERIALS } from "../src/game/economy/recipes";
import { FORGE_BONUS_CAP, SHOP_MAPS, SHOPS, shopStock } from "../src/game/economy/shop";
import { QUESTS } from "../src/game/quests";
import { RECRUITS } from "../src/game/settlers";
import { DUNGEONS, LEVELS } from "../src/game/hero/levels";
import { PATH_NODES } from "../src/game/hero/paths";
import { RANK_AURAS, RANK_TITLES } from "../src/game/hero/ranks";
import { ROLES } from "../src/game/hero/roles";
import { SKILL_TREES } from "../src/game/hero/skillTree";
import {
  HOUSE_DEED_COST,
  HOUSE_DOOR,
  INN_REST,
  PROPERTY_PRICES,
  RENT_PER_VICTORY,
  REST_COST,
  TOWN_SPAWN,
  WORKBENCH_COST,
} from "../src/state/shared";
import {
  DAY_STEPS,
  EXPANSION_COST,
  EXPANSION_RENT,
  SAVINGS_MAX_DAYS,
  SAVINGS_RATE,
  VENTURE_COST,
  VENTURE_STEPS,
} from "../src/game/economy/bank";
import { GARDEN_WINS_PER_YIELD, HOUSE_TIERS, NOOK_COMBINES, TROPHY_BUFFS } from "../src/game/economy/house";
import { TOWN_TIERS } from "../src/game/economy/town";
import { BOSS_IDS } from "../src/game/combat/battleEngine";
import { DROP_CHANCE, POOLS, RARITY_WEIGHTS } from "../src/game/combat/drops";
import { REGIONS, WILD_REWARD_MULT } from "../src/game/combat/encounters";
import { MONSTERS } from "../src/game/combat/monsters";
import { STAT_POINTS_PER_LEVEL } from "../src/game/hero/character";
import { FAMILY_NAMES, FAMILY_OF, MASTERY_TIERS } from "../src/game/hero/mastery";
import { SPAWNS } from "../src/world/spawns";
import { CHESTS } from "../src/world/chests";
import { NPCS } from "../src/world/npcs";
import { chartedMapId, MAP_NAMES } from "../src/world/mapNames";
import { getMap, MAPS, setHouseTier, setTownTier } from "../src/world/maps";
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
const mapDoc = (map: (typeof MAPS)[string]) => ({
  id: map.id,
  width: map.width,
  height: map.height,
  spawn: map.spawn,
  portals: map.portals,
  tiles: map.tiles,
  // Per-tile encounter region (forest, marsh, ash, ...) where monsters lurk.
  ...(map.regions ? { regions: map.regions } : {}),
});
for (const map of Object.values(MAPS)) emit(`${map.id}.json`, mapDoc(map));

// The town redraws itself as it grows (PIX-91) and the house as it is upgraded
// (PIX-34): tier variants above the base export as `<id>@<tier>.json`.
for (let tier = 2; tier <= TOWN_TIERS.length; tier++) {
  setTownTier(tier);
  emit(`town@${tier}.json`, mapDoc(getMap("town")));
}
for (let tier = 2; tier <= 3; tier++) {
  setHouseTier(tier);
  emit(`town_house@${tier}.json`, mapDoc(getMap("town_house")));
}
setTownTier(1);
setHouseTier(1);

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

// What the save layer must know to read, migrate and grow a web save: items,
// role base stats (new heroes, the endurance backfill), and each role's tier-0
// skill roots in branch order (the pre-skill-tree backfill). Passives live in
// combat.json with the skill trees.
emit(
  "catalog.json",
  {
    // Every item, whole: shops, the pack and combat all read it (id is the key).
    items: Object.fromEntries(Object.values(ITEMS).map(({ id, ...item }) => [id, item])),
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
    // Every map's player-facing place name; interiors take their town's.
    places: Object.fromEntries(Object.keys(MAPS).map((id) => [id, MAP_NAMES[chartedMapId(id)]])),
    levelCount: LEVELS.length,
    townSpawn: TOWN_SPAWN,
    innRest: INN_REST,
  },
  DATA_OUT,
);

// The town economy (PIX-124): shops and what they stock per unlocked floor,
// which building hosts which shop, recipes, where each trade crafts.
const MAX_FLOOR = 15;
emit(
  "economy.json",
  {
    shops: Object.fromEntries(
      Object.values(SHOPS).map((shop) => [
        shop.id,
        {
          ...shop,
          // itemId -> the first unlocked floor at which this shop stocks it
          stock: Object.fromEntries(
            shopStock(shop.id, MAX_FLOOR).map((item) => [
              item.id,
              Array.from({ length: MAX_FLOOR }, (_, i) => i + 1).find((floor) =>
                shopStock(shop.id, floor).some((stocked) => stocked.id === item.id),
              ),
            ]),
          ),
        },
      ]),
    ),
    shopMaps: SHOP_MAPS,
    recipes: RECIPES,
    jobStations: JOB_STATIONS,
    jobLevelCap: JOB_LEVEL_CAP,
    forgeBonusCap: FORGE_BONUS_CAP,
    rarities: RARITIES,
  },
  DATA_OUT,
);

// The settlement (PIX-124): town tiers and what reaching them requires (the
// web's predicates become keys GDScript checks), deeds, rest, the bank.
emit(
  "town.json",
  {
    tiers: TOWN_TIERS.map(({ tier, name, blurb, perks, cost, requires }) => {
      const doc: Record<string, unknown> = { tier, name, blurb, perks };
      if (cost !== undefined) doc.cost = cost;
      if (requires) doc.requires = { line: requires.line, key: tier === 3 ? "own_house" : "own_all_properties" };
      return doc;
    }),
    properties: PROPERTY_PRICES,
    houseDeedCost: HOUSE_DEED_COST,
    // The growing house (PIX-34): Odo's bigger deeds, trophies, the nook, the garden.
    houseTiers: HOUSE_TIERS,
    houseDoor: HOUSE_DOOR,
    trophyBuffs: TROPHY_BUFFS,
    nookCombines: NOOK_COMBINES,
    gardenWinsPerYield: GARDEN_WINS_PER_YIELD,
    workbenchCost: WORKBENCH_COST,
    restCost: REST_COST,
    rentPerVictory: RENT_PER_VICTORY,
    bank: {
      daySteps: DAY_STEPS,
      savingsRate: SAVINGS_RATE,
      savingsMaxDays: SAVINGS_MAX_DAYS,
      ventureCost: VENTURE_COST,
      ventureSteps: VENTURE_STEPS,
      expansionCost: EXPANSION_COST,
      expansionRent: EXPANSION_RENT,
    },
  },
  DATA_OUT,
);

// Combat (PIX-126): the bestiary, what lurks in each region and where it
// stands, what the fallen drop, mastery, the passive-bearing skill and path
// nodes (getPassives), and the dungeons' floors with their encounters and
// first-clear rewards — the same tables the web battle engine reads.
emit(
  "combat.json",
  {
    monsters: MONSTERS,
    regions: REGIONS,
    wildRewardMult: WILD_REWARD_MULT,
    spawns: SPAWNS,
    bossIds: [...BOSS_IDS],
    dropPools: POOLS,
    rarityWeights: RARITY_WEIGHTS,
    dropChance: DROP_CHANCE,
    regionMaterials: REGION_MATERIALS,
    families: FAMILY_OF,
    familyNames: FAMILY_NAMES,
    masteryTiers: MASTERY_TIERS,
    statPointsPerLevel: STAT_POINTS_PER_LEVEL,
    skillTrees: SKILL_TREES,
    pathNodes: PATH_NODES,
    levels: LEVELS,
    dungeons: DUNGEONS,
  },
  DATA_OUT,
);

// Villagers (PIX-123): the fixed townsfolk, tier-gated settlers included, and
// the recruits who wait in the wilds until they move to town (PIX-92).
emit("npcs.json", { npcs: NPCS, recruits: RECRUITS }, DATA_OUT);

// The long game (PIX-125): the villagers' quests and the hero's rank titles.
emit("progression.json", { quests: QUESTS, rankTitles: RANK_TITLES, rankAuras: RANK_AURAS }, DATA_OUT);

if (check && drifted.length > 0) {
  console.error(`godot maps out of sync — run \`pnpm godot:sync\`:\n  ${drifted.join("\n  ")}`);
  process.exit(1);
}
