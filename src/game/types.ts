import type { DungeonId, WorldState } from "../world/types";

export type RoleId = "warrior" | "mage" | "rogue" | "cleric";

export type Stats = {
  maxHp: number;
  maxMp: number;
  strength: number;
  intelligence: number;
  dexterity: number;
  defense: number;
};

export type ScalingStat = "strength" | "intelligence" | "dexterity";

export type StatusKind = "poison" | "burn" | "stun";

/** An active effect on a combatant. `power` is damage per tick (0 for stun). */
export type StatusEffect = {
  kind: StatusKind;
  turnsLeft: number;
  power: number;
};

/** A chance to apply a status effect when an attack or skill lands. */
export type Infliction = {
  kind: StatusKind;
  chance: number;
  turns: number;
  power: number;
};

export type Skill = {
  name: string;
  description: string;
  mpCost: number;
  /** Extra health price, paid on cast (Berserk-style skills). */
  hpCost?: number;
  kind: "damage" | "heal";
  multiplier: number;
  stat: ScalingStat;
  /** Hero level required to use this skill. */
  unlockLevel: number;
  inflicts?: Infliction;
  /** Heals only: also removes all status effects from the hero. */
  cleanse?: boolean;
};

export type Role = {
  id: RoleId;
  name: string;
  description: string;
  sprite: string;
  baseStats: Stats;
  /** Automatic per-level gains; combat stats come from spendable points. */
  growth: { maxHp: number; maxMp: number };
  /** Ordered by unlockLevel; index 0 is the starting skill. */
  skills: Skill[];
};

export type ItemCategory = "weapons" | "apparel" | "potions" | "food" | "misc";

export type EquipSlot = "weapon" | "body" | "offhand";

export type Rarity = "common" | "fine" | "epic";

/**
 * An owned piece of gear (weapon or apparel). Gear is instance-based so each
 * piece can roll its own rarity bonus; stackables stay in `inventory`.
 */
export type GearInstance = {
  uid: string;
  itemId: string;
  rarity: Rarity;
  /** Flat bonus to the item's damage or armor, rolled from rarity. */
  bonus: number;
};

export type Item = {
  id: string;
  name: string;
  category: ItemCategory;
  sprite: string;
  weight: number;
  value: number;
  description: string;
  // weapons
  damage?: number;
  scaling?: ScalingStat;
  // apparel
  armor?: number;
  slot?: EquipSlot;
  // consumables
  restoreHp?: number;
  restoreMp?: number;
  /** Removes this status effect from the hero when used. */
  cures?: StatusKind;
};

export type Monster = {
  id: string;
  name: string;
  sprite: string;
  maxHp: number;
  attack: number;
  defense: number;
  xp: number;
  gold: number;
  /** Status effect this monster can apply when its attack lands. */
  inflicts?: Infliction;
};

export type EncounterDef = {
  monsterId: string;
  /** Elite variants get boosted stats and a prefix in their name. */
  elite?: boolean;
};

export type DungeonLevel = {
  level: number;
  name: string;
  description: string;
  encounters: EncounterDef[];
  rewardItemIds: string[];
  rewardGold: number;
};

export type Hero = {
  name: string;
  roleId: RoleId;
  level: number;
  xp: number;
  xpToNext: number;
  hp: number;
  mp: number;
  stats: Stats;
  /** Unspent points from level-ups, placed freely into combat stats. */
  statPoints: number;
};

/** The four stats a point can be spent on. */
export type SpendableStat = "strength" | "intelligence" | "dexterity" | "defense";

export type Equipped = Partial<Record<EquipSlot, string>>;

export type BattleMonster = {
  def: Monster;
  name: string;
  elite: boolean;
  hp: number;
  maxHp: number;
  attack: number;
  defense: number;
  xp: number;
  gold: number;
};

export type BattlePhase = "player" | "won" | "lost" | "cleared";

export type BattleState = {
  /** For wild battles this is the drop-pool floor, not a dungeon. */
  dungeonLevel: number;
  encounterIndex: number;
  monster: BattleMonster;
  log: string[];
  phase: BattlePhase;
  heroEffects: StatusEffect[];
  monsterEffects: StatusEffect[];
  /** Set for random battles in the overworld; win/flee returns to the world. */
  wild?: boolean;
  wildRegion?: string;
};

export type Screen = "title" | "create" | "battle" | "victory" | "world" | "dungeon_select";

export type GameState = {
  screen: Screen;
  hero: Hero | null;
  gold: number;
  /** Stackables only (potions, food, misc): itemId -> count. */
  inventory: Record<string, number>;
  /** Every owned weapon/apparel piece, equipped or not. */
  gear: GearInstance[];
  /** Slot -> gear uid. */
  equipped: Equipped;
  /** Highest dungeon level the hero can enter (1-10). */
  unlockedLevel: number;
  clearedLevels: number[];
  battle: BattleState | null;
  inventoryOpen: boolean;
  shopOpen: boolean;
  /** World position and exploration memory; null until the hero enters it. */
  world: WorldState | null;
  /** The dungeon entrance the hero is standing at (floor-select open or inside). */
  dungeonSelect: DungeonId | null;
  /** False right after character creation until the intro is dismissed. */
  introSeen: boolean;
  /** One-line feedback shown under the world viewport (inn, gate...). Cleared on move. */
  worldMessage: string | null;
};
