import type { RegionId } from "../../world/types";
import type { EncounterDef } from "../types";

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

export const WILD_REWARD_MULT = 0.65;

const REGIONS: Record<RegionId, RegionTable> = {
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
  deepwood: {
    name: "the Deepwood",
    dropFloor: 8,
    eliteChance: 0.18,
    monsters: [
      { monsterId: "troll", weight: 4 },
      { monsterId: "golem", weight: 3 },
      { monsterId: "shade", weight: 2 },
    ],
  },
  mire: {
    name: "the Mirefen",
    dropFloor: 11,
    eliteChance: 0.2,
    monsters: [
      { monsterId: "ghost", weight: 4 },
      { monsterId: "skeleton", weight: 3 },
      { monsterId: "mimic", weight: 2 },
    ],
  },
};

export type WildEncounter = {
  def: EncounterDef;
  regionId: RegionId;
  regionName: string;
  dropFloor: number;
};

/** The species living at a spawn: deterministic, so what you see is what you fight. */
export function spawnSpecies(region: RegionId, seed: number): string {
  const table = REGIONS[region];
  return table.monsters[seed % table.monsters.length].monsterId;
}

/** Builds the wild encounter for a visible spawn; only the elite roll is chance. */
export function encounterForSpawn(region: RegionId, monsterId: string): WildEncounter {
  const table = REGIONS[region];
  return {
    def: { monsterId, elite: Math.random() < table.eliteChance },
    regionId: region,
    regionName: table.name,
    dropFloor: table.dropFloor,
  };
}

