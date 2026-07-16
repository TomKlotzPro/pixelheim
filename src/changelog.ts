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
    version: "1.7.0",
    date: "2026-07-16",
    codename: "Main Street",
    notes: [
      "Two new shops: Smith Hilda sells steel, Alchemist Vex sells brews",
      "The Forge: pay Hilda to sharpen any weapon or armor, up to +7",
      "Vex pays FULL price for reagents and trophies; Hilda pays 60% for steel",
      "Odo goes general goods: food, sundries, and he still buys anything",
    ],
  },
  {
    version: "1.6.0",
    date: "2026-07-16",
    codename: "Field Alchemy",
    notes: [
      "Crafting! A new Craft tab in the inventory turns materials into potions",
      "Win wild battles to forage: herbs in the forest, reeds in the marsh, ember shards in the ash",
      "Six recipes, from a humble health potion to a full elixir",
      "Materials weigh nothing and sell for pocket change - brew, don't hoard",
    ],
  },
  {
    version: "1.5.0",
    date: "2026-07-16",
    codename: "Neighbors",
    notes: [
      "Pixelheim village grew into a real town: bigger, more houses, a shrine square",
      "People live here now - talk to them with E, Enter or Space",
      "Elder Maren remembers the fire; Ana doubts the elixirs; Bram guards his fence",
      "Merchant Odo and Innkeeper Sela finally have faces",
      "An empty lot sits between the lower houses. For sale? Soon.",
    ],
  },
  {
    version: "1.4.0",
    date: "2026-07-16",
    codename: "Danger, Visibly",
    notes: [
      "Dangerous ground is visible: wild terrain grows dark tufts on the map",
      "Roads and town stay clean-looking because they ARE safe",
      "Ambushes feel like ambushes: the monster lunges in, the screen shakes, !",
    ],
  },
  {
    version: "1.3.0",
    date: "2026-07-16",
    codename: "A Fair Fight",
    notes: [
      "Balance pass, informed by simulating hundreds of playthroughs",
      "Fafnyr and Morvax hit harder and last longer - bosses are events again",
      "The Hall of Echoes death spike is softened: shades calmed down a little",
      "Every role verified to be able to finish the game",
    ],
  },
  {
    version: "1.2.0",
    date: "2026-07-16",
    codename: "Branches of Power",
    notes: [
      "Skill trees! One skill point per level, three branches per role",
      "Learn new skills, upgrade old ones, or take passives: crits, resists, +DEF...",
      "Open Skills from the HUD; your old skills are already in the tree",
      "Veterans get their banked points retroactively. Spend wisely - no take-backs.",
    ],
  },
  {
    version: "1.1.0",
    date: "2026-07-16",
    codename: "Your Hero, Your Rules",
    notes: [
      "Level-ups now bank 5 stat points: spend them on STR, INT, DEX or DEF",
      "Open the Stats sheet from the HUD; unspent points show as a badge",
      "HP and MP still grow by role; the build is yours to shape",
      "Spent points are permanent. Choose like it matters.",
    ],
  },
  {
    version: "1.0.0",
    date: "2026-07-16",
    codename: "The Open World",
    notes: [
      "Pixelheim is an open-world game now: you live on the map, not in menus",
      "New heroes wake in the village; walk to the shop, the inn, the mountain",
      "Your hero rides along as a compact HUD; I opens the inventory",
      "Old saves from any version wake up standing in town, progress intact",
      "The hub screen retires with honor. It served well.",
    ],
  },
  {
    version: "0.10.0",
    date: "2026-07-16",
    codename: "Doors in the Mountain",
    notes: [
      "Dungeons live in the world now: walk to the mountain gate to climb",
      "The cave at the mountain's base leads below, once the dragon falls",
      "Clearing a floor steps you back out of the door you entered",
      "Fall in a dungeon you entered from the world? The inn takes you in",
    ],
  },
  {
    version: "0.9.0",
    date: "2026-07-16",
    codename: "The Wilds Bite",
    notes: [
      "Random encounters in the open world: forests, marshes and ash fields are dangerous now",
      "Each region has its own monsters; deeper regions hit harder and drop better",
      "Paths, bridges and town stay safe - stray off the road at your own risk",
      "Beaten in the wilds? You wake up at the inn, purse intact",
    ],
  },
  {
    version: "0.8.0",
    date: "2026-07-16",
    codename: "Polish and Knobs",
    notes: [
      "The title screen lives: stars, embers, bobbing monsters, a breathing dragon",
      "Options menu: music and effects volume, CRT scanlines, reduced motion",
      "Save codes and delete-save moved into Options",
      "The world is much bigger on screen and scales to your window",
    ],
  },
  {
    version: "0.7.0",
    date: "2026-07-16",
    codename: "A Little Night Music",
    notes: [
      "The game has sound: hits, heals, coins, level-ups, loot drops",
      "Three chiptune tracks: the title theme, the overworld, and battle",
      "Everything is synthesized live in your browser, no audio files",
      "Mute button top right; your choice is remembered",
    ],
  },
  {
    version: "0.6.0",
    date: "2026-07-16",
    codename: "Fortune and Steel",
    notes: [
      "Monsters drop loot: gear now rolls Fine and Epic rarities with bonus stats",
      "A dozen new items: bows, war hammers, wands, cloaks, tower shields...",
      "Antidote and Ember Salve cure poison and burn mid-fight",
      "Elites and bosses drop better; the dragon and the lich always drop",
      "Trophies like wolf pelts and imp horns to sell at the shop",
    ],
  },
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
