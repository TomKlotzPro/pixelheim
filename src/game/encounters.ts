import type { EncounterDef } from "./types";

/**
 * What lurks in each region of the Ashenreach. Weights are relative;
 * dropFloor picks which drop pool (drops.ts) a wild kill rolls from.
 * Wild kills award reduced XP/gold: dungeons stay the main progression.
 */
type RegionTable = {
  name: string;
  dropFloor: number;
  eliteChance: number;
  monsters: { monsterId: string; weight: number }[];
};

export const ENCOUNTER_CHANCE = 0.1;
export const WILD_REWARD_MULT = 0.65;

const REGIONS: Record<string, RegionTable> = {
  forest: {
    name: "the Whispering Forest",
    dropFloor: 1,
    eliteChance: 0.08,
    monsters: [
      { monsterId: "slime", weight: 4 },
      { monsterId: "goblin", weight: 4 },
      { monsterId: "wolf", weight: 2 },
    ],
  },
  marsh: {
    name: "the Sunken Marsh",
    dropFloor: 4,
    eliteChance: 0.12,
    monsters: [
      { monsterId: "skeleton", weight: 4 },
      { monsterId: "ghost", weight: 3 },
      { monsterId: "wolf", weight: 2 },
    ],
  },
  ash: {
    name: "the Ash Fields",
    dropFloor: 7,
    eliteChance: 0.15,
    monsters: [
      { monsterId: "orc", weight: 4 },
      { monsterId: "wyvern", weight: 2 },
      { monsterId: "imp", weight: 2 },
    ],
  },
};

export type WildEncounter = {
  def: EncounterDef;
  regionName: string;
  dropFloor: number;
};

/** Rolls one step's encounter for a region; null means the wilds stay quiet. */
export function rollWildEncounter(region: string): WildEncounter | null {
  const table = REGIONS[region];
  if (!table || Math.random() >= ENCOUNTER_CHANCE) return null;
  const total = table.monsters.reduce((sum, m) => sum + m.weight, 0);
  let roll = Math.random() * total;
  let monsterId = table.monsters[0].monsterId;
  for (const entry of table.monsters) {
    roll -= entry.weight;
    if (roll <= 0) {
      monsterId = entry.monsterId;
      break;
    }
  }
  return {
    def: { monsterId, elite: Math.random() < table.eliteChance },
    regionName: table.name,
    dropFloor: table.dropFloor,
  };
}
