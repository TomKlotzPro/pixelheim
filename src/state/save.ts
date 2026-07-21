import { ITEMS } from "../game/economy/items";
import { LEVELS } from "../game/hero/levels";
import { createGear } from "../game/economy/rarity";
import { freshJobs } from "../game/economy/jobs";
import { ROLES } from "../game/hero/roles";
import { SKILL_TREES } from "../game/hero/skillTree";
import type { GameState, GearInstance } from "../game/types";
import { discoverAround } from "../world/discover";
import { getMap } from "../world/maps/index";
import { initialState, TOWN_SPAWN } from "./gameReducer";

const SAVE_KEY = "pixelheim-save-v1";
const CODE_PREFIX = "PXH1.";

/**
 * Bump this whenever the persisted GameState shape changes in a way a spread
 * over initialState cannot absorb (renames, moved fields, changed meanings),
 * and add a migration step below. Purely additive fields need NO version bump:
 * normalizeSave rebases every save onto initialState, so new fields pick up
 * their defaults automatically.
 */
const SAVE_VERSION = 4;

type Envelope = { version: number; state: unknown };

/**
 * Each entry upgrades a save from `version` to `version + 1`. Old saves are
 * replayed through every step between their version and SAVE_VERSION, so a
 * player can skip any number of releases and still load.
 */
const MIGRATIONS: Record<number, (state: Record<string, unknown>) => Record<string, unknown>> = {
  // v1 -> v2: v1 saves were a bare GameState with no version envelope.
  // The shape itself did not change; v2 only introduced the envelope.
  1: (state) => state,
  // v2 -> v3: `world` grew from a flat position into { position, discovered,
  // openedChests } so exploration persists. Flat positions get wrapped;
  // saves that never entered the world keep world: null via the rebase.
  2: (state) => {
    const world = state.world as { mapId?: string } | null | undefined;
    if (!world || !world.mapId) return { ...state, world: null };
    return { ...state, world: { position: world, discovered: {}, openedChests: [] } };
  },
  // v3 -> v4: gear became instance-based for rarity rolls. Weapon/apparel
  // counts in the old inventory turn into common instances, and equipped
  // slots switch from item ids to instance uids.
  3: (state) => {
    const inventory = { ...(state.inventory as Record<string, number>) };
    const equipped = { ...(state.equipped as Record<string, string>) };
    const gear: GearInstance[] = [];
    for (const [itemId, count] of Object.entries(inventory)) {
      const item = ITEMS[itemId];
      if (!item?.slot) continue;
      for (let i = 0; i < count; i++) gear.push(createGear(itemId));
      delete inventory[itemId];
    }
    for (const [slot, itemId] of Object.entries(equipped)) {
      if (!itemId) continue;
      const instance = createGear(itemId);
      gear.push(instance);
      equipped[slot] = instance.uid;
    }
    return { ...state, inventory, equipped, gear };
  },
};

function isEnvelope(value: unknown): value is Envelope {
  return (
    typeof value === "object" && value !== null && typeof (value as Envelope).version === "number" && "state" in value
  );
}

/** Validates a parsed save and rebases it on the current initialState shape. */
function normalizeSave(state: unknown): GameState | null {
  if (!state || typeof state !== "object" || !(state as GameState).hero) return null;
  // Never resume mid-battle or mid-menu; wake up back in the world.
  const save: GameState = {
    ...initialState,
    ...(state as GameState),
    screen: "world",
    battle: null,
    inventoryOpen: false,
    shopOpen: false,
    hallOpen: false,
    bankOpen: false,
    dungeonSelect: null,
    worldMessage: null,
    dialogue: null,
  };
  // Heroes from before spendable growth start banking from their next level.
  if (save.hero && save.hero.statPoints === undefined) {
    save.hero = { ...save.hero, statPoints: 0 };
  }
  // Heroes from before professions start every job at level 1.
  if (save.hero && save.hero.jobs === undefined) {
    save.hero = { ...save.hero, jobs: freshJobs() };
  }
  // Heroes from before the endurance stat get their role's base grit.
  if (save.hero && save.hero.stats.endurance === undefined) {
    save.hero = { ...save.hero, stats: { ...save.hero.stats, endurance: ROLES[save.hero.roleId].baseStats.endurance } };
  }
  // Heroes from before the skill tree keep the skills their level had earned
  // under the old gates (1/3/6) and bank the leftover points retroactively.
  if (save.hero && save.hero.skillNodes === undefined) {
    const hero = save.hero;
    const tree = SKILL_TREES[hero.roleId];
    const roots = tree.filter((n) => n.tier === 0).toSorted((a, b) => a.branch - b.branch);
    const owned = [roots[0].id];
    if (hero.level >= 3 && roots[1]) owned.push(roots[1].id);
    if (hero.level >= 6 && roots[2]) owned.push(roots[2].id);
    const spent = owned.length - 1; // the first skill was always free
    save.hero = {
      ...hero,
      skillNodes: owned,
      skillPoints: Math.max(0, hero.level - 1 - spent),
    };
  }
  // Saves from before visible monsters have no kill ledger for the map.
  if (save.world && save.world.slain === undefined) {
    save.world = { ...save.world, slain: [] };
  }
  // Saves from the hub era have no world position: they wake up in town.
  if (!save.world) {
    const town = getMap(TOWN_SPAWN.mapId);
    save.world = {
      position: { ...TOWN_SPAWN },
      discovered: discoverAround({}, town, TOWN_SPAWN.x, TOWN_SPAWN.y),
      openedChests: [],
      slain: [],
    };
  }
  // Recompute unlock progress: when new floors ship, players who had cleared
  // the old final floor were capped at the old LEVELS.length and would
  // otherwise never see the new content.
  const maxCleared = save.clearedLevels.reduce((max, level) => Math.max(max, level), 0);
  save.unlockedLevel = Math.max(save.unlockedLevel, Math.min(maxCleared + 1, LEVELS.length));
  return save;
}

/** Takes any historical save payload and upgrades it to the current version. */
/** Exported for the unit tests: the whole upgrade path is pure. */
export function migrate(raw: unknown): GameState | null {
  let version = 1;
  let state = raw;
  if (isEnvelope(raw)) {
    version = raw.version;
    state = raw.state;
  }
  if (version > SAVE_VERSION || !state || typeof state !== "object") return null;
  while (version < SAVE_VERSION) {
    const step = MIGRATIONS[version];
    if (!step) return null;
    state = step(state as Record<string, unknown>);
    version += 1;
  }
  return normalizeSave(state);
}

function serialize(state: GameState): string {
  return JSON.stringify({ version: SAVE_VERSION, state } satisfies Envelope);
}

export function loadSave(): GameState | null {
  try {
    const raw = localStorage.getItem(SAVE_KEY);
    if (!raw) return null;
    return migrate(JSON.parse(raw));
  } catch {
    return null;
  }
}

export function persistSave(state: GameState): void {
  if (!state.hero) return;
  try {
    localStorage.setItem(SAVE_KEY, serialize(state));
  } catch {
    // Storage full or unavailable; playing without saves is fine.
  }
}

export function clearSave(): void {
  localStorage.removeItem(SAVE_KEY);
}

/** Serializes a save into a copy-pastable code, e.g. to move progress between devices. */
export function encodeSaveCode(state: GameState): string {
  const bytes = new TextEncoder().encode(serialize(state));
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return CODE_PREFIX + btoa(binary);
}

/** Parses a save code from any past version of the game. Returns null on anything invalid. */
export function decodeSaveCode(code: string): GameState | null {
  try {
    const trimmed = code.trim();
    if (!trimmed.startsWith(CODE_PREFIX)) return null;
    const binary = atob(trimmed.slice(CODE_PREFIX.length));
    const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
    return migrate(JSON.parse(new TextDecoder().decode(bytes)));
  } catch {
    return null;
  }
}
