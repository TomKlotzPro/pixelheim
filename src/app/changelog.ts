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
    version: "0.47.0",
    date: "2026-07-18",
    codename: "Dressed",
    notes: [
      "TRUE EQUIPMENT LAYERS: gear is drawn into your sprite now, pixel by pixel - plate on the torso, helm on the crown, shield on the arm, blade in the hand",
      "Thirty wearables got hand-fitted overlays cut to the hero's anatomy - every sword, axe, bow, staff, robe, helm and shield, tiered by palette",
      "One source of truth for what you look like: the world, the battle, the inventory doll, the HUD portrait and the stat sheet all wear the same outfit",
      "Walk in armor: the overlays ride the walk-cycle bob, so your gear moves with you instead of floating over you",
    ],
  },
  {
    version: "0.46.0",
    date: "2026-07-18",
    codename: "Tailored",
    notes: [
      "Worn gear got a fitting: the helm sits on the crown instead of floating, and equipped BODY ARMOR finally shows on the torso",
      "The inventory doll wears your gear live - equip a piece and watch your character change right there in the preview",
      "The sound and settings buttons got proper glyphs, and loading is a big honest LOADING with marching dots",
    ],
  },
  {
    version: "0.45.0",
    date: "2026-07-18",
    codename: "Centered",
    notes: [
      "The world sits centered on the screen, where a world belongs",
      "The corner buttons speak pixel now: a proper gold speaker and gear instead of emoji",
      "The controls moved into a legend at the side - every key at a glance, rebindable in Options",
      "Entering the world shows 'Entering the Ashenreach...' instead of a silent black box while it loads",
    ],
  },
  {
    version: "0.44.0",
    date: "2026-07-18",
    codename: "Promises and Rooftops",
    notes: [
      "QUESTS! Five promises around the village: slimes for Sela, cheese for Bram (of course), wolves for Ana, a troll for the elder, herbs for Vex - talk to accept, deliver or slay, talk again to collect",
      "The JOURNAL (J) tracks every promise with progress bars and tells you who to see when it's ready",
      "The village stopped being rectangles: shingled roof courses, rounded building corners, and chimneys with smoke wisps - form, not squares",
    ],
  },
  {
    version: "0.43.0",
    date: "2026-07-18",
    codename: "The Wide View",
    notes: [
      "The viewport grew from 15x11 to 21x13 tiles: you see MORE world at once, and the finer scale reads as sharper, denser pixel art",
      "Your house announces itself: a FOR SALE sign hangs over the door, and turns to HOME once the deed is yours",
      "The mini-map learned the landmarks: gold dots mark the forge and the cauldron, green marks your house",
    ],
  },
  {
    version: "0.42.0",
    date: "2026-07-18",
    codename: "The Landlord",
    notes: [
      "Buy the street: Odo's Emporium (2,500g), Vex's Workshop (3,500g) and Hilda's Smithy (4,000g) each sell their deed - ask the keeper behind the counter",
      "Owned businesses pay RENT: +2g each after every victory, straight into your purse with a line in the battle log",
      "The keepers keep working. They just work for you now.",
    ],
  },
  {
    version: "0.41.0",
    date: "2026-07-18",
    codename: "Welcome Home",
    notes: [
      "You can own a HOUSE. The shut door in the south of town names its price: the deed costs 1,500g - press E and it's yours",
      "Inside: your own bed (free rest, forever - the inn can keep its prices) and a storage barrel",
      "Home storage is the answer to carry weight: stored goods weigh NOTHING on the road. Hoarding, finally legal",
      "The first stone of Your Town: property, the city hall and the settlers come next",
    ],
  },
  {
    version: "0.40.0",
    date: "2026-07-18",
    codename: "Worn with Pride",
    notes: [
      "Your gear finally shows: the equipped weapon rides your hand, the shield your arm, the helm your head - in the world, in both renderers",
      "Swap the rusty sword for Dragonbane and WATCH the swap - appearance is derived live from what you wear",
      "Layers stack the right way: look, then rank, then steel",
    ],
  },
  {
    version: "0.39.0",
    date: "2026-07-18",
    codename: "The Slayer's Ledger",
    notes: [
      "Monster mastery! Every kill teaches: 10 slain of a family earns +5% damage against them, 25 earns +10%, 50 earns +15% - permanently",
      "Five families keep the ledger readable: Beasts, Greenskins, the Undead, Constructs, the Fireborn",
      "Crossing a threshold announces itself in the battle log: 'Beasts Slayer II'",
      "The CODEX opens from the HUD: your mastery progress bars on one tab, a bestiary on the other - monsters reveal their numbers only once you've drawn their family's blood",
    ],
  },
  {
    version: "0.38.0",
    date: "2026-07-18",
    codename: "Dressed for Glory",
    notes: [
      "Ascension is a scene now: letterbox bars, turning light, your hero marching in their NEW look, the title stamped over it",
      "Rank changes how you LOOK: garb brightens with every ascension and your outline turns from shadow to gold to radiant - across every class and every look",
      "Fixed: the ascension card could get stuck on screen until the next fight - it leaves politely now",
      "Fixed: a flaky load could leave the world pitch black until a reload - the renderer retries on its own",
      "Renamed for clarity: the warrior now peaks as WARBRINGER and the paladin as Knight, so titles never collide with specialization names",
    ],
  },
  {
    version: "0.37.0",
    date: "2026-07-18",
    codename: "The Fork in the Path",
    notes: [
      "Specializations! At your first ascension, every class faces a choice of two paths - Juggernaut or Warlord, Pyromancer or Stormcaller, Plaguelord or Bonelord... fourteen identities across the roster",
      "A path is a permanent identity: an always-on passive theme and a SIGNATURE SKILL no tree can teach",
      "Choose in the Skills menu; your title on the stat sheet carries the path. A path is for life - choose like it matters",
      "Old saves lose nothing: the fork simply waits in Skills for any hero past level 5",
    ],
  },
  {
    version: "0.36.0",
    date: "2026-07-18",
    codename: "Ascension",
    notes: [
      "Rank evolution! Every 5 levels your hero ascends: Apprentice becomes Mage becomes Magus becomes ARCHMAGE - every class has its ladder",
      "Ascension is a moment: a title card, a fanfare, and a bonus skill point on the spot",
      "Rank shows on the hero: an aura that deepens with each ascension (silver, gold, radiant) and a touch more presence on the map",
      "Your title lives on the HUD and the stat sheet - you are not 'Lv 12 Warrior', you are a Champion",
      "Old saves are already ranked: rank derives from level, nothing stored",
    ],
  },
  {
    version: "0.35.0",
    date: "2026-07-18",
    codename: "The Bard Arrives",
    notes: [
      "Every place has its own music now: a warm folk tune in town, old minor wanderings in the Deepwood, drowned bells over the Mirefen, a cozy lull indoors, a pulse before the dungeon plunge - and bosses get their own menace",
      "Tracks crossfade instead of cutting, and the whole score plays through a touch of echo",
      "The world hums underneath: birdsong in the greenwood, drips and frogs in the bog, wind in the old trees, a crackling hearth indoors",
      "Six new sounds: the clink of equipping steel, a chest's creak and shine, the fast-travel rush, a skill settling into the mind, the anvil's answer, and the growl of something noticing you",
      "Still not a single audio file - every note is synthesized live, like the sprites",
    ],
  },
  {
    version: "0.34.0",
    date: "2026-07-18",
    codename: "Know Thyself",
    notes: [
      "The skill tree looks like a tree: three named paths, tier badges from I to CAP, connector lines, and the numbers on every skill - multiplier, stat, cost - before you commit",
      "Nodes you can afford glow. Learning them still feels as permanent as it is.",
      "The stat sheet got an identity: your portrait, name and rank up top, jewelry bonuses shown as '+n worn' beside each stat",
      "Points to spend live in a gold chip in the header of both menus",
    ],
  },
  {
    version: "0.33.0",
    date: "2026-07-17",
    codename: "Signposted",
    notes: [
      "The craft stations finally introduce themselves: an anvil hangs over the FORGE door, a bubbling cauldron over BREWS",
      "Lost with a pocket full of pelts? The Craft tab now offers 'Travel to town' - one click to Pixelheim Gate",
      "Standing at a station, the Craft tab says so in green: craft freely",
      "Esc got manners: it closes the menu you are in, and only pauses when nothing else is open",
      "Any stack can be dropped - one at a time, or the whole pile with Drop All",
    ],
  },
  {
    version: "0.32.0",
    date: "2026-07-17",
    codename: "New Blood",
    notes: [
      "Three new classes! The RANGER (death at a distance, poison arrows, unmatched escapes), the PALADIN (armor outside, faith inside - hits, heals and never flinches), and the NECROMANCER (everything they touch keeps dying)",
      "Each comes with a full 12-node skill tree, its own look palette, and a proven path to the final boss - the balance sim clears the game with all seven classes",
      "Old saves are untouched; new heroes just have more doors",
    ],
  },
  {
    version: "0.31.0",
    date: "2026-07-17",
    codename: "Mirror Mirror",
    notes: [
      "Character customization! Pick your hero's look at creation: four palette styles per class - skin tones and outfit colors, the retro way",
      "Your look follows you everywhere: the world, battles, the inventory doll",
      "Old heroes keep their classic look; new ones choose",
    ],
  },
  {
    version: "0.30.0",
    date: "2026-07-17",
    codename: "A Fresh Coat",
    notes: [
      "The world got redrawn: mottled grass, real cobblestone roads, rippled sand, sunlit tree canopies, and water with depth, crests and foam where it meets the land",
      "Every living thing wears a 1px outline now - heroes, villagers and monsters pop off the terrain instead of melting into it",
      "In-world lettering is TRUE pixel text: door signs on wooden plates, the talk prompt and battle damage numbers use a hand-built bitmap font, crisp at any zoom",
      "Press Start 2P headlines the title and panel headers (bundled, no CDN)",
      "Everyone casts a shadow, and a quiet vignette frames the world",
    ],
  },
  {
    version: "0.29.0",
    date: "2026-07-17",
    codename: "Dressed to Kill",
    notes: [
      "The inventory grew a mirror: a paper doll of your hero with every worn piece laid on the body - click a piece to take it off",
      "Six new places to wear something: helmet, gloves, boots, collar, and TWO rings",
      "Jewelry grants stats while worn: +STR charms, +INT pendants, +DEX rings - and a strength charm literally helps you carry more",
      "Sixteen new pieces across the tiers: shops stock the basics, the best drop deep or come off the bench (Scaled Greaves, Wolfstooth Collar)",
      "A live stats panel beside the doll: ATK, DEF and every granted bonus, updating as you dress",
    ],
  },
  {
    version: "0.28.0",
    date: "2026-07-17",
    codename: "First Impressions",
    notes: [
      "The title screen is a living diorama: three mountain ridges deep, a smoldering summit, drifting fog, and the game's own monsters parading past - watch for the dragon",
      "Character creation got the mirror-and-ledger treatment: your hero marches in place while stat bars compare every class at a glance",
      "The town signs its doors: GOODS, FORGE, BREWS, INN - no more hunting for the craft stations",
      "Talking is easy now: E finds whoever stands beside you and turns you toward them",
      "The world stopped ticking on one metronome - every villager, beast and blade of grass moves to its own beat",
    ],
  },
  {
    version: "0.27.0",
    date: "2026-07-17",
    codename: "Buried Riches",
    notes: [
      "Exploration pays: 12 treasures hide across the maps - chests in the corners of the world, gold glinting on the road, an herb patch worth gathering",
      "Chests are furniture: face one, press E, and it opens once per save - the corner finds hold gear a tier ahead of their region",
      "Ground treasure is taken in stride: walk over a glint or herb patch and it is yours",
      "One chest in the Mirefen is not a chest. Good luck.",
    ],
  },
  {
    version: "0.26.0",
    date: "2026-07-17",
    codename: "Open Season",
    notes: [
      "No more ambushes. Monsters are VISIBLE in the wilds now - see them prowl, choose your fights",
      "Every spawn belongs to its terrain: ash beasts in the ash, bog things in the Mirefen - the beast you see is the beast you fight",
      "Bump into a monster to attack it; a slain spawn stays clear until you leave the map and return",
      "Fleeing and forage work exactly as before - only the surprise is gone",
    ],
  },
  {
    version: "0.25.0",
    date: "2026-07-17",
    codename: "At the Bench",
    notes: [
      "Crafting moved to the stations: forge gear at Hilda's, brew at Vex's cauldron - the Craft tab still browses recipes anywhere and tells you where to go",
      "The mini-map no longer hides under the sound and settings buttons",
      "A small-screen pass: panels fit, the HUD compacts, and nothing overlaps at any width",
    ],
  },
  {
    version: "0.24.0",
    date: "2026-07-17",
    codename: "Beyond the Ring",
    notes: [
      "Two new regions past the mountain ring: the old-growth Deepwood in the east, the drowned Mirefen in the west",
      "Late-game hunting grounds: trolls and golems under the trees, ghosts and mimics in the bog - elites roam thick",
      "New forage: Deep Root and Grave Moss feed three top-shelf recipes, from Troll Salve to the Grave Ward",
      "The passes are fast-travel waypoints the moment you lay eyes on them",
      "The world map already knows the way - the fog is yours to lift",
    ],
  },
  {
    version: "0.23.0",
    date: "2026-07-17",
    codename: "The Cartographer",
    notes: [
      "The world map is here: press M for the Ashenreach under fog of war - you only see what you have walked",
      "Fast travel: any waypoint you have laid eyes on is one click away - seen once, reachable forever",
      "No teleporting over-encumbered. Lighten the pack.",
      "A mini-map rides in the corner of the world, fog included",
      "The map key is rebindable like everything else",
    ],
  },
  {
    version: "0.22.0",
    date: "2026-07-17",
    codename: "The Maker's Mark",
    notes: [
      "Eight new items, and five of them can ONLY be made, never bought: from the Reedwoven Buckler to Scaled Mail",
      "Recipes now demand skill: Smithing forges gear, Alchemy brews, and locked recipes show what level they ask",
      "Crafting difficulty comes from making, never wearing - no level requirements on gear, ever (the Skyrim rule)",
      "New brews: Stamina Draughts for fighters, Hunter's Stew, and the scale-steeped Dragon Tonic",
      "Monster trophies matter: pelts, horns and dragon scales are now the raw stuff of the best gear",
    ],
  },
  {
    version: "0.21.0",
    date: "2026-07-17",
    codename: "Honest Work",
    notes: [
      "Professions! Smithing, Alchemy and Foraging level up as you work them",
      "Smithing shaves the Forge's prices and, at level 5, unlocks the +8 masterwork cap",
      "Alchemy learns to brew doubles; Foraging finds more, and finds pairs",
      "Job levels and progress live on the stat sheet, next to your stats",
      "Also: the town gate moved to the north wall - no more door ping-pong when holding a key",
    ],
  },
  {
    version: "0.20.0",
    date: "2026-07-17",
    codename: "Second Wind",
    notes: [
      "Fighters run on Endurance now: Warrior and Rogue skills cost EN, and it trickles back every combat round - rhythm over potion-chugging",
      "Endurance is a stat: a little health for everyone, stamina pool and faster regen for martials",
      "Intelligence finally feeds the mana pool: casters gain +2 max MP per INT point",
      "The stat sheet explains all of it with live numbers, as always",
      "Old heroes are seeded their role's base grit automatically - no save lost",
    ],
  },
  {
    version: "0.19.0",
    date: "2026-07-17",
    codename: "The Painted World",
    notes: [
      "The world is WebGL now, no flag needed: walk cycles, flowing water, swaying grass, day and night, lantern glows, drifting embers",
      "Battles got a stage: lunges, hit flashes and floating damage numbers",
      "Escape pauses the game: copy your save code, open options, or quit to the title and resume in place",
      "Controls are rebindable, and French keyboards get ZQSD out of the box",
      "The stat sheet explains every stat with live numbers and previews what your next point buys",
      "Every skill branch grew a tier-3 capstone: 12 nodes per role, from Skullsplitter to Divine Word",
      "Pixelheim doubled east: new houses, a market corner, an orchard - and shops are rooms you walk into and trade by talking",
      "Honest version numbers: we are not 1.0 yet, so the old 1.x releases are now 0.11 through 0.18",
    ],
  },
  {
    version: "0.18.0",
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
    version: "0.17.0",
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
    version: "0.16.0",
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
    version: "0.15.0",
    date: "2026-07-16",
    codename: "Danger, Visibly",
    notes: [
      "Dangerous ground is visible: wild terrain grows dark tufts on the map",
      "Roads and town stay clean-looking because they ARE safe",
      "Ambushes feel like ambushes: the monster lunges in, the screen shakes, !",
    ],
  },
  {
    version: "0.14.0",
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
    version: "0.13.0",
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
    version: "0.12.0",
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
    version: "0.11.0",
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
