import type { Hero, Infliction, RoleId, Skill } from "./types";

/**
 * The skill trees: 3 branches x 3 tiers per role. Tier-0 nodes are the old
 * level-gated skills (the first is granted free at creation); deeper nodes
 * need their parent. One skill point per level, spending is permanent.
 */
export type PassiveEffects = {
  defense: number;
  fleeBonus: number;
  carryBonus: number;
  critChance: number;
  killRefundMp: number;
  goldBonus: number;
  /** Extra damage multiplier against monsters below 30% HP. */
  lowHpBonus: number;
  stunResist: boolean;
  poisonResist: boolean;
  attackInflict: Infliction | null;
};

const NO_PASSIVES: PassiveEffects = {
  defense: 0,
  fleeBonus: 0,
  carryBonus: 0,
  critChance: 0,
  killRefundMp: 0,
  goldBonus: 0,
  lowHpBonus: 0,
  stunResist: false,
  poisonResist: false,
  attackInflict: null,
};

export type SkillNode = {
  id: string;
  name: string;
  description: string;
  kind: "active" | "upgrade" | "passive";
  branch: number;
  tier: number;
  requires?: string;
  /** Actives: the skill this node grants. */
  skill?: Skill;
  /** Upgrades: patch applied to the parent active's skill. */
  patch?: Partial<Skill>;
  passive?: Partial<PassiveEffects>;
  /** Permanent stat grant applied once when bought. */
  grantStats?: { maxHp?: number; maxMp?: number };
};

const active = (
  id: string,
  branch: number,
  name: string,
  description: string,
  skill: Omit<Skill, "unlockLevel">,
): SkillNode => ({ id, branch, tier: 0, name, description, kind: "active", skill: { ...skill, unlockLevel: 1 } });

const upgrade = (
  id: string,
  requires: string,
  branch: number,
  name: string,
  description: string,
  patch: Partial<Skill>,
): SkillNode => ({ id, requires, branch, tier: 1, name, description, kind: "upgrade", patch });

const passive = (
  id: string,
  requires: string,
  branch: number,
  tier: number,
  name: string,
  description: string,
  effects: Partial<PassiveEffects>,
  grantStats?: { maxHp?: number; maxMp?: number },
): SkillNode => ({ id, requires, branch, tier, name, description, kind: "passive", passive: effects, grantStats });

export const SKILL_TREES: Record<RoleId, SkillNode[]> = {
  warrior: [
    active("warrior_power_strike", 0, "Power Strike", "A crushing blow dealing heavy physical damage.", {
      name: "Power Strike", description: "A crushing blow.", mpCost: 4, kind: "damage", multiplier: 1.9, stat: "strength",
    }),
    upgrade("warrior_power_strike_2", "warrior_power_strike", 0, "Power Strike II", "Power Strike hits much harder.", { multiplier: 2.4 }),
    passive("warrior_executioner", "warrior_power_strike_2", 0, 2, "Executioner", "+40% damage against enemies below 30% HP.", { lowHpBonus: 0.4 }),
    active("warrior_shield_slam", 1, "Shield Slam", "A staggering bash that can stun for a turn.", {
      name: "Shield Slam", description: "A staggering bash.", mpCost: 6, kind: "damage", multiplier: 1.1, stat: "strength",
      inflicts: { kind: "stun", chance: 0.55, turns: 1, power: 0 },
    }),
    passive("warrior_iron_skin", "warrior_shield_slam", 1, 1, "Iron Skin", "+2 DEF, always.", { defense: 2 }),
    passive("warrior_unshakeable", "warrior_iron_skin", 1, 2, "Unshakeable", "You cannot be stunned.", { stunResist: true }),
    active("warrior_berserk", 2, "Berserk", "Reckless fury: massive damage, costs 8 HP.", {
      name: "Berserk", description: "Reckless fury.", mpCost: 5, hpCost: 8, kind: "damage", multiplier: 2.7, stat: "strength",
    }),
    upgrade("warrior_blood_rage", "warrior_berserk", 2, "Blood Rage", "Berserk costs only 4 HP.", { hpCost: 4 }),
    passive("warrior_rampage", "warrior_blood_rage", 2, 2, "Rampage", "Kills refund 3 MP.", { killRefundMp: 3 }),
  ],
  mage: [
    active("mage_fireball", 0, "Fireball", "Hurls a fireball for heavy magic damage.", {
      name: "Fireball", description: "Heavy magic damage.", mpCost: 6, kind: "damage", multiplier: 2.2, stat: "intelligence",
    }),
    upgrade("mage_fireball_2", "mage_fireball", 0, "Fireball II", "Fireball burns brighter.", { multiplier: 2.8 }),
    passive("mage_cinders", "mage_fireball_2", 0, 2, "Cinders", "Plain attacks have a 20% chance to set enemies burning.", {
      attackInflict: { kind: "burn", chance: 0.2, turns: 2, power: 4 },
    }),
    active("mage_ignite", 1, "Ignite", "Sets the enemy ablaze for several turns.", {
      name: "Ignite", description: "Burn damage over time.", mpCost: 7, kind: "damage", multiplier: 1.2, stat: "intelligence",
      inflicts: { kind: "burn", chance: 0.9, turns: 3, power: 6 },
    }),
    passive("mage_mana_well", "mage_ignite", 1, 1, "Mana Well", "+15 max MP, permanently.", {}, { maxMp: 15 }),
    passive("mage_clarity", "mage_mana_well", 1, 2, "Clarity", "Kills refund 3 MP.", { killRefundMp: 3 }),
    active("mage_frost_nova", 2, "Frost Nova", "A blast of cold that can freeze the enemy solid.", {
      name: "Frost Nova", description: "Cold blast, may stun.", mpCost: 9, kind: "damage", multiplier: 1.5, stat: "intelligence",
      inflicts: { kind: "stun", chance: 0.6, turns: 1, power: 0 },
    }),
    upgrade("mage_deep_freeze", "mage_frost_nova", 2, "Deep Freeze", "Frost Nova stuns far more reliably.", {
      inflicts: { kind: "stun", chance: 0.85, turns: 1, power: 0 },
    }),
    passive("mage_winters_grace", "mage_deep_freeze", 2, 2, "Winter's Grace", "+10% flee chance.", { fleeBonus: 0.1 }),
  ],
  rogue: [
    active("rogue_backstab", 0, "Backstab", "Strikes a vital spot for heavy dexterity damage.", {
      name: "Backstab", description: "Strike a vital spot.", mpCost: 5, kind: "damage", multiplier: 2.0, stat: "dexterity",
    }),
    upgrade("rogue_backstab_2", "rogue_backstab", 0, "Backstab II", "Backstab cuts deeper.", { multiplier: 2.5 }),
    passive("rogue_keen_edge", "rogue_backstab_2", 0, 2, "Keen Edge", "+15% chance to crit for 1.5x damage.", { critChance: 0.15 }),
    active("rogue_poison_blade", 1, "Poison Blade", "A coated dagger that leaves the enemy poisoned.", {
      name: "Poison Blade", description: "Poison damage over time.", mpCost: 6, kind: "damage", multiplier: 1.1, stat: "dexterity",
      inflicts: { kind: "poison", chance: 0.85, turns: 3, power: 5 },
    }),
    upgrade("rogue_virulence", "rogue_poison_blade", 1, "Virulence", "Your poison bites much harder.", {
      inflicts: { kind: "poison", chance: 0.85, turns: 3, power: 8 },
    }),
    passive("rogue_toxin_ward", "rogue_virulence", 1, 2, "Toxin Ward", "You cannot be poisoned.", { poisonResist: true }),
    active("rogue_shadowstep", 2, "Shadowstep", "Vanish and strike from behind for devastating damage.", {
      name: "Shadowstep", description: "Devastating ambush.", mpCost: 10, kind: "damage", multiplier: 3.0, stat: "dexterity",
    }),
    passive("rogue_fleet_foot", "rogue_shadowstep", 2, 1, "Fleet Foot", "+15% flee chance.", { fleeBonus: 0.15 }),
    passive("rogue_pickpocket", "rogue_fleet_foot", 2, 2, "Pickpocket", "+25% gold from kills.", { goldBonus: 0.25 }),
  ],
  cleric: [
    active("cleric_mend", 0, "Mend", "Channels light to restore health.", {
      name: "Mend", description: "Restore health.", mpCost: 5, kind: "heal", multiplier: 2.5, stat: "intelligence",
    }),
    upgrade("cleric_mend_2", "cleric_mend", 0, "Mend II", "Mend restores far more.", { multiplier: 3.2 }),
    passive("cleric_martyr", "cleric_mend_2", 0, 2, "Martyr", "+20 max HP, permanently.", {}, { maxHp: 20 }),
    active("cleric_smite", 1, "Smite", "Searing radiance burns the enemy.", {
      name: "Smite", description: "Searing radiance.", mpCost: 6, kind: "damage", multiplier: 1.8, stat: "intelligence",
    }),
    upgrade("cleric_smite_2", "cleric_smite", 1, "Smite II", "Smite sears harder.", { multiplier: 2.3 }),
    passive("cleric_zealotry", "cleric_smite_2", 1, 2, "Zealotry", "Kills refund 3 MP.", { killRefundMp: 3 }),
    active("cleric_sanctuary", 2, "Sanctuary", "A ward of light that heals and purges all ailments.", {
      name: "Sanctuary", description: "Heal and cleanse.", mpCost: 10, kind: "heal", multiplier: 2.0, stat: "intelligence", cleanse: true,
    }),
    passive("cleric_aegis", "cleric_sanctuary", 2, 1, "Aegis", "+2 DEF, always.", { defense: 2 }),
    passive("cleric_serenity", "cleric_aegis", 2, 2, "Serenity", "You cannot be stunned.", { stunResist: true }),
  ],
};

export function getNode(roleId: RoleId, nodeId: string): SkillNode | null {
  return SKILL_TREES[roleId].find((n) => n.id === nodeId) ?? null;
}

/** The role's free starting node (the first branch-0 active). */
export function rootNode(roleId: RoleId): SkillNode {
  return SKILL_TREES[roleId].find((n) => n.tier === 0 && n.branch === 0)!;
}

/** The hero's usable battle skills: owned actives with owned upgrades applied. */
export function getHeroSkills(hero: Hero): Skill[] {
  const owned = new Set(hero.skillNodes);
  const nodes = SKILL_TREES[hero.roleId];
  return nodes
    .filter((n) => n.kind === "active" && owned.has(n.id))
    .map((node) => {
      let skill = { ...node.skill! };
      for (const up of nodes) {
        if (up.kind === "upgrade" && owned.has(up.id) && up.requires === node.id) {
          skill = { ...skill, ...up.patch };
        }
      }
      return skill;
    });
}

/** All owned passive effects, merged. */
export function getPassives(hero: Hero): PassiveEffects {
  const merged = { ...NO_PASSIVES };
  const owned = new Set(hero.skillNodes);
  for (const node of SKILL_TREES[hero.roleId]) {
    if (node.kind !== "passive" || !owned.has(node.id) || !node.passive) continue;
    merged.defense += node.passive.defense ?? 0;
    merged.fleeBonus += node.passive.fleeBonus ?? 0;
    merged.carryBonus += node.passive.carryBonus ?? 0;
    merged.critChance += node.passive.critChance ?? 0;
    merged.killRefundMp += node.passive.killRefundMp ?? 0;
    merged.goldBonus += node.passive.goldBonus ?? 0;
    merged.lowHpBonus += node.passive.lowHpBonus ?? 0;
    merged.stunResist = merged.stunResist || (node.passive.stunResist ?? false);
    merged.poisonResist = merged.poisonResist || (node.passive.poisonResist ?? false);
    merged.attackInflict = node.passive.attackInflict ?? merged.attackInflict;
  }
  return merged;
}

export function canBuyNode(hero: Hero, node: SkillNode): boolean {
  if (hero.skillPoints <= 0) return false;
  if (hero.skillNodes.includes(node.id)) return false;
  if (node.requires && !hero.skillNodes.includes(node.requires)) return false;
  return true;
}
