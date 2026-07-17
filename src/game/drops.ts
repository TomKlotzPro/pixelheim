import { createGear, rollRarity } from "./rarity";
import type { GearInstance, Rarity } from "./types";

/**
 * What a defeated monster can leave behind, beyond gold and XP.
 * Pools are gated by dungeon floor so drops track progression; wild
 * encounters (PIX-23) and chests (PIX-27) reuse the same tables.
 */
type DropPool = {
  /** Highest pool whose floor <= the current one applies. */
  floor: number;
  gearIds: string[];
  stackIds: string[];
};

const POOLS: DropPool[] = [
  {
    floor: 1,
    gearIds: ["rusty_sword", "hunting_bow", "traveler_cloak", "leather_armor"],
    stackIds: ["bread", "apple", "potion_hp", "wolf_pelt"],
  },
  {
    floor: 4,
    gearIds: ["iron_sword", "apprentice_staff", "moon_wand", "steel_shield", "leather_armor", "leather_cap", "bone_charm"],
    stackIds: ["potion_hp", "potion_mp", "antidote", "dried_meat", "wolf_pelt"],
  },
  {
    floor: 7,
    gearIds: ["steel_axe", "longbow", "shadow_dagger", "mage_robe", "iron_armor", "tower_shield", "iron_helm", "runed_grips", "moon_pendant"],
    stackIds: ["potion_hp", "potion_mp", "elixir", "antidote", "ember_salve", "gem"],
  },
  {
    floor: 11,
    gearIds: ["war_hammer", "longbow", "arch_staff", "shadow_cloak", "runic_armor", "obsidian_blade", "wyrm_visor", "duelists_ring"],
    stackIds: ["greater_potion", "elixir", "antidote", "ember_salve", "imp_horn", "gem"],
  },
];

const RARITY_WEIGHTS: Record<"normal" | "elite" | "boss", Record<Rarity, number>> = {
  normal: { common: 0.75, fine: 0.22, epic: 0.03 },
  elite: { common: 0.55, fine: 0.35, epic: 0.1 },
  boss: { common: 0.3, fine: 0.5, epic: 0.2 },
};

const DROP_CHANCE = { normal: 0.22, elite: 0.4, boss: 1 };

export type MonsterKind = keyof typeof DROP_CHANCE;

export type Drop = { kind: "gear"; gear: GearInstance } | { kind: "stack"; itemId: string };

function pick<T>(list: T[]): T {
  return list[Math.floor(Math.random() * list.length)];
}

/** Rolls the after-battle drop. Returns null most of the time; that is the point. */
export function rollDrop(dungeonLevel: number, kind: MonsterKind): Drop | null {
  if (Math.random() >= DROP_CHANCE[kind]) return null;
  const pool = POOLS.findLast((p) => p.floor <= dungeonLevel) ?? POOLS[0];
  // Gear is the exciting third of drops; the rest keeps the satchel stocked.
  if (Math.random() < 0.35) {
    return { kind: "gear", gear: createGear(pick(pool.gearIds), rollRarity(RARITY_WEIGHTS[kind])) };
  }
  return { kind: "stack", itemId: pick(pool.stackIds) };
}
