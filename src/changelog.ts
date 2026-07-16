export type Release = {
  version: string;
  date: string;
  codename: string;
  notes: string[];
};

/**
 * Newest first. The first entry is the game's displayed version, so shipping
 * a release means adding an entry here and nothing else.
 */
export const CHANGELOG: Release[] = [
  {
    version: "0.5.0",
    date: "2026-07-16",
    codename: "The Ashenreach",
    notes: [
      "First look at the open world: walk the Ashenreach from town (beta)",
      "Pixelheim village, marshland, forest, ash fields, and a river bridge",
      "Enter the village, poke around the shop and the inn",
      "Exploration is remembered: where you have been persists in your save",
    ],
  },
  {
    version: "0.4.0",
    date: "2026-07-16",
    codename: "The Undermountain",
    notes: [
      "Five new floors beneath the mountain, for those who beat the dragon",
      "New monsters: Bone Knight, Shade, Mimic, Fire Imp, and Morvax the Deathless",
      "New gear: Obsidian Blade, Runic Armor, Greater Health Potions",
      "Beat the dragon before this update? Floor 11 is already open for you",
    ],
  },
  {
    version: "0.3.0",
    date: "2026-07-16",
    codename: "Sharpened Steel",
    notes: [
      "Status effects: poison and burn tick every turn, stun steals turns",
      "Monsters fight dirty now: wyverns poison, the dragon burns, golems stun",
      "Every role learns three skills, unlocked at levels 1, 3 and 6",
      "New skills include Berserk, Frost Nova, Poison Blade and Sanctuary",
    ],
  },
  {
    version: "0.2.0",
    date: "2026-07-16",
    codename: "Open for Business",
    notes: [
      "The game is live on the web, with auto-deploys on every change",
      "Save codes: copy your save as a PXH1. code and load it anywhere",
      "The merchant opens shop: buy gear and potions, sell your loot",
      "Versioned saves: old saves keep working forever as the game grows",
    ],
  },
  {
    version: "0.1.0",
    date: "2026-07-10",
    codename: "The Ashen Mountain",
    notes: [
      "Ten floors of monsters, from cellar slimes to Fafnyr the Ashen",
      "Four roles: Warrior, Mage, Rogue, Cleric",
      "Turn-based combat, Skyrim-style inventory, carry weight, cheese wheels",
      "Auto-save in your browser",
    ],
  },
];

export const GAME_VERSION = CHANGELOG[0].version;

const SEEN_KEY = "pixelheim-seen-version";

export function hasUnseenChanges(): boolean {
  try {
    return localStorage.getItem(SEEN_KEY) !== GAME_VERSION;
  } catch {
    return false;
  }
}

export function markChangesSeen(): void {
  try {
    localStorage.setItem(SEEN_KEY, GAME_VERSION);
  } catch {
    // Storage unavailable; the badge just stays.
  }
}
