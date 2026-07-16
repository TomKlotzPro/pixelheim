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

export type Skill = {
  name: string;
  description: string;
  mpCost: number;
  kind: "damage" | "heal";
  multiplier: number;
  stat: ScalingStat;
};

export type Role = {
  id: RoleId;
  name: string;
  description: string;
  sprite: string;
  baseStats: Stats;
  /** Stat gains applied on each level up. */
  growth: Stats;
  skill: Skill;
};

export type ItemCategory = "weapons" | "apparel" | "potions" | "food" | "misc";

export type EquipSlot = "weapon" | "body" | "offhand";

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
};

export type Equipped = Partial<Record<EquipSlot, string>>;

export type BattleMonster = {
  def: Monster;
  name: string;
  hp: number;
  maxHp: number;
  attack: number;
  defense: number;
  xp: number;
  gold: number;
};

export type BattlePhase = "player" | "won" | "lost" | "cleared";

export type BattleState = {
  dungeonLevel: number;
  encounterIndex: number;
  monster: BattleMonster;
  log: string[];
  phase: BattlePhase;
};

export type Screen = "title" | "create" | "hub" | "battle" | "gameover" | "victory";

export type GameState = {
  screen: Screen;
  hero: Hero | null;
  gold: number;
  /** itemId -> count */
  inventory: Record<string, number>;
  equipped: Equipped;
  /** Highest dungeon level the hero can enter (1-10). */
  unlockedLevel: number;
  clearedLevels: number[];
  battle: BattleState | null;
  inventoryOpen: boolean;
  shopOpen: boolean;
};
