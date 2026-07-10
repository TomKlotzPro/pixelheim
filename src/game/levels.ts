import type { DungeonLevel } from "./types";

export const LEVELS: DungeonLevel[] = [
  {
    level: 1,
    name: "Mossy Cellar",
    description: "Something gelatinous lurks beneath the tavern.",
    encounters: [{ monsterId: "slime" }, { monsterId: "slime" }, { monsterId: "slime", elite: true }],
    rewardItemIds: ["potion_hp", "bread"],
    rewardGold: 20,
  },
  {
    level: 2,
    name: "Whispering Woods",
    description: "Goblins have been robbing travelers on the forest road.",
    encounters: [{ monsterId: "slime" }, { monsterId: "goblin" }, { monsterId: "goblin", elite: true }],
    rewardItemIds: ["leather_armor", "potion_hp"],
    rewardGold: 30,
  },
  {
    level: 3,
    name: "Barrow Crypt",
    description: "The dead of the old kingdom do not rest easy.",
    encounters: [{ monsterId: "goblin" }, { monsterId: "skeleton" }, { monsterId: "skeleton", elite: true }],
    rewardItemIds: ["iron_sword", "potion_mp"],
    rewardGold: 45,
  },
  {
    level: 4,
    name: "Frosthowl Pass",
    description: "Wolves with eyes like embers stalk the mountain trail.",
    encounters: [{ monsterId: "skeleton" }, { monsterId: "wolf" }, { monsterId: "wolf", elite: true }],
    rewardItemIds: ["apprentice_staff", "cheese_wheel", "potion_hp"],
    rewardGold: 60,
  },
  {
    level: 5,
    name: "Ruined Watchtower",
    description: "An orc warband has claimed the old garrison.",
    encounters: [{ monsterId: "wolf" }, { monsterId: "orc" }, { monsterId: "orc", elite: true }],
    rewardItemIds: ["steel_shield", "potion_hp", "potion_mp"],
    rewardGold: 85,
  },
  {
    level: 6,
    name: "Drowned Chapel",
    description: "Cold voices sing hymns in the flooded nave.",
    encounters: [{ monsterId: "orc" }, { monsterId: "ghost" }, { monsterId: "ghost", elite: true }],
    rewardItemIds: ["mage_robe", "shadow_dagger", "potion_hp"],
    rewardGold: 110,
  },
  {
    level: 7,
    name: "Sunken Forge",
    description: "The dwarven guardians still obey their final order: none shall pass.",
    encounters: [{ monsterId: "ghost" }, { monsterId: "golem" }, { monsterId: "golem", elite: true }],
    rewardItemIds: ["steel_axe", "iron_armor", "potion_mp"],
    rewardGold: 140,
  },
  {
    level: 8,
    name: "Gloomdeep Caverns",
    description: "Miners fled when the bridge trolls stopped charging tolls and started charging people.",
    encounters: [{ monsterId: "golem" }, { monsterId: "troll" }, { monsterId: "troll", elite: true }],
    rewardItemIds: ["arch_staff", "gem", "potion_hp", "potion_hp"],
    rewardGold: 180,
  },
  {
    level: 9,
    name: "Stormcrag Aerie",
    description: "Wyverns nest in the high crags, guarding the path to the summit.",
    encounters: [{ monsterId: "troll" }, { monsterId: "wyvern" }, { monsterId: "wyvern", elite: true }],
    rewardItemIds: ["dragonbane", "potion_hp", "potion_mp", "cheese_wheel"],
    rewardGold: 240,
  },
  {
    level: 10,
    name: "The Ashen Throne",
    description: "Fafnyr the Ashen waits atop the mountain. End this.",
    encounters: [{ monsterId: "wyvern" }, { monsterId: "dragon" }],
    rewardItemIds: ["dragon_scale", "gem"],
    rewardGold: 500,
  },
];

export function getLevel(level: number): DungeonLevel {
  const def = LEVELS[level - 1];
  if (!def) throw new Error(`Unknown dungeon level: ${level}`);
  return def;
}
