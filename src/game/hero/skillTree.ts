import type { Hero, Infliction, RoleId, Skill } from "../types";
import { getSpec } from "./specs";

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

/** Tier-3 branch capstones: the payoff active at the end of a line. */
const capstone = (
  id: string,
  requires: string,
  branch: number,
  name: string,
  description: string,
  skill: Omit<Skill, "unlockLevel">,
): SkillNode => ({ id, requires, branch, tier: 3, name, description, kind: "active", skill: { ...skill, unlockLevel: 1 } });

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
    passive("warrior_rampage", "warrior_blood_rage", 2, 2, "Rampage", "Kills refund 3 EN.", { killRefundMp: 3 }),
    capstone("warrior_skullsplitter", "warrior_executioner", 0, "Skullsplitter", "One blow to end arguments: enormous STR damage.", {
      name: "Skullsplitter", description: "One blow to end arguments.", mpCost: 12, kind: "damage", multiplier: 3.4, stat: "strength",
    }),
    passive("warrior_mountainheart", "warrior_unshakeable", 1, 3, "Mountainheart", "+30 max HP and +1 DEF, permanently.", { defense: 1 }, { maxHp: 30 }),
    passive("warrior_warpath", "warrior_rampage", 2, 3, "Warpath", "+10% chance to crit for 1.5x damage.", { critChance: 0.1 }),
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
    capstone("mage_meteor", "mage_cinders", 0, "Meteor", "Calls a piece of the sky down: colossal INT damage.", {
      name: "Meteor", description: "A piece of the sky.", mpCost: 14, kind: "damage", multiplier: 3.6, stat: "intelligence",
    }),
    passive("mage_archmage", "mage_clarity", 1, 3, "Archmage", "+20 max MP and kills refund 2 more MP.", { killRefundMp: 2 }, { maxMp: 20 }),
    passive("mage_rimeguard", "mage_winters_grace", 2, 3, "Rimeguard", "A sheath of ice: +2 DEF and +5% flee.", { defense: 2, fleeBonus: 0.05 }),
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
    capstone("rogue_deathblow", "rogue_keen_edge", 0, "Deathblow", "The knife you never see: extreme DEX damage.", {
      name: "Deathblow", description: "The knife you never see.", mpCost: 12, kind: "damage", multiplier: 3.5, stat: "dexterity",
    }),
    passive("rogue_venom_master", "rogue_toxin_ward", 1, 3, "Venom Master", "Plain attacks have a 25% chance to poison.", {
      attackInflict: { kind: "poison", chance: 0.25, turns: 2, power: 5 },
    }),
    passive("rogue_ghostwalk", "rogue_pickpocket", 2, 3, "Ghostwalk", "+10% flee and +10% gold: leave rich, leave alive.", { fleeBonus: 0.1, goldBonus: 0.1 }),
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
    capstone("cleric_divine_word", "cleric_martyr", 0, "Divine Word", "A word that unmakes wounds: massive heal and full cleanse.", {
      name: "Divine Word", description: "Unmakes wounds.", mpCost: 14, kind: "heal", multiplier: 4.0, stat: "intelligence", cleanse: true,
    }),
    capstone("cleric_judgement", "cleric_zealotry", 1, "Judgement", "The light decides: huge INT damage.", {
      name: "Judgement", description: "The light decides.", mpCost: 12, kind: "damage", multiplier: 3.2, stat: "intelligence",
    }),
    passive("cleric_sainthood", "cleric_serenity", 2, 3, "Sainthood", "+15 max HP, +10 max MP and +2 DEF, permanently.", { defense: 2 }, { maxHp: 15, maxMp: 10 }),
  ],
  ranger: [
    active("ranger_aimed_shot", 0, "Aimed Shot", "A measured arrow to a weak point.", {
      name: "Aimed Shot", description: "A measured arrow.", mpCost: 4, kind: "damage", multiplier: 1.9, stat: "dexterity",
    }),
    upgrade("ranger_aimed_shot_2", "ranger_aimed_shot", 0, "Aimed Shot II", "Aimed Shot bites deeper.", { multiplier: 2.4 }),
    passive("ranger_deadeye", "ranger_aimed_shot_2", 0, 2, "Deadeye", "+10% chance to crit for 1.5x damage.", { critChance: 0.1 }),
    active("ranger_barbed_arrow", 1, "Barbed Arrow", "A cruel arrowhead that poisons the wound.", {
      name: "Barbed Arrow", description: "Poisons the wound.", mpCost: 6, kind: "damage", multiplier: 1.1, stat: "dexterity",
      inflicts: { kind: "poison", chance: 0.85, turns: 3, power: 5 },
    }),
    passive("ranger_fieldcraft", "ranger_barbed_arrow", 1, 1, "Fieldcraft", "+15 carry weight, always.", { carryBonus: 15 }),
    passive("ranger_pathfinder", "ranger_fieldcraft", 1, 2, "Pathfinder", "+15% flee chance.", { fleeBonus: 0.15 }),
    active("ranger_rain", 2, "Rain of Arrows", "The sky darkens over the enemy.", {
      name: "Rain of Arrows", description: "The sky darkens.", mpCost: 10, kind: "damage", multiplier: 2.7, stat: "dexterity",
    }),
    upgrade("ranger_storm", "ranger_rain", 2, "Arrowstorm", "Rain of Arrows costs 7 EN.", { mpCost: 7 }),
    passive("ranger_second_wind", "ranger_storm", 2, 2, "Second Wind", "Kills refund 3 EN.", { killRefundMp: 3 }),
    capstone("ranger_heartseeker", "ranger_deadeye", 0, "Heartseeker", "One arrow, one answer: enormous DEX damage.", {
      name: "Heartseeker", description: "One arrow, one answer.", mpCost: 12, kind: "damage", multiplier: 3.3, stat: "dexterity",
    }),
    passive("ranger_wolfblood", "ranger_pathfinder", 1, 3, "Wolfblood", "+20 max HP and poison never touches you.", { poisonResist: true }, { maxHp: 20 }),
    passive("ranger_hunters_eye", "ranger_second_wind", 2, 3, "Hunter's Eye", "+40% damage against enemies below 30% HP.", { lowHpBonus: 0.4 }),
  ],
  paladin: [
    active("paladin_judgement", 0, "Judgement", "A blessed blow of righteous strength.", {
      name: "Judgement", description: "A blessed blow.", mpCost: 5, kind: "damage", multiplier: 1.7, stat: "strength",
    }),
    upgrade("paladin_judgement_2", "paladin_judgement", 0, "Judgement II", "Judgement lands heavier.", { multiplier: 2.2 }),
    passive("paladin_retribution", "paladin_judgement_2", 0, 2, "Retribution", "+40% damage against enemies below 30% HP.", { lowHpBonus: 0.4 }),
    active("paladin_lay_on_hands", 1, "Lay on Hands", "Healing light through gauntleted palms.", {
      name: "Lay on Hands", description: "Healing light.", mpCost: 6, kind: "heal", multiplier: 2.0, stat: "intelligence",
    }),
    passive("paladin_bulwark", "paladin_lay_on_hands", 1, 1, "Bulwark", "+2 DEF, always.", { defense: 2 }),
    passive("paladin_stalwart", "paladin_bulwark", 1, 2, "Stalwart", "You cannot be stunned.", { stunResist: true }),
    active("paladin_consecrate", 2, "Consecrate", "Holy fire that clings.", {
      name: "Consecrate", description: "Holy fire that clings.", mpCost: 9, kind: "damage", multiplier: 1.5, stat: "strength",
      inflicts: { kind: "burn", chance: 0.85, turns: 3, power: 5 },
    }),
    upgrade("paladin_purifier", "paladin_consecrate", 2, "Purifier", "Consecrate burns hotter.", { inflicts: { kind: "burn", chance: 0.9, turns: 3, power: 8 } }),
    passive("paladin_tithe", "paladin_purifier", 2, 2, "Tithe", "+15% gold from victories.", { goldBonus: 0.15 }),
    capstone("paladin_wrath", "paladin_retribution", 0, "Wrath of Heaven", "The sky takes a side: massive STR damage.", {
      name: "Wrath of Heaven", description: "The sky takes a side.", mpCost: 12, kind: "damage", multiplier: 3.2, stat: "strength",
    }),
    passive("paladin_sanctified", "paladin_stalwart", 1, 3, "Sanctified", "+25 max HP and +1 DEF, permanently.", { defense: 1 }, { maxHp: 25 }),
    capstone("paladin_absolution", "paladin_tithe", 2, "Absolution", "A verdict of light: heal and full cleanse.", {
      name: "Absolution", description: "A verdict of light.", mpCost: 12, kind: "heal", multiplier: 3.0, stat: "intelligence", cleanse: true,
    }),
  ],
  necromancer: [
    active("necro_soul_bolt", 0, "Soul Bolt", "A lash of stolen life.", {
      name: "Soul Bolt", description: "A lash of stolen life.", mpCost: 5, kind: "damage", multiplier: 2.0, stat: "intelligence",
    }),
    upgrade("necro_soul_bolt_2", "necro_soul_bolt", 0, "Soul Bolt II", "Soul Bolt steals more.", { multiplier: 2.6 }),
    passive("necro_grave_touch", "necro_soul_bolt_2", 0, 2, "Grave Touch", "Plain attacks have a 20% chance to poison.", {
      attackInflict: { kind: "poison", chance: 0.2, turns: 2, power: 4 },
    }),
    active("necro_blight", 1, "Blight", "A creeping rot that poisons for turns.", {
      name: "Blight", description: "A creeping rot.", mpCost: 7, kind: "damage", multiplier: 1.0, stat: "intelligence",
      inflicts: { kind: "poison", chance: 0.9, turns: 4, power: 6 },
    }),
    passive("necro_marrow_well", "necro_blight", 1, 1, "Marrow Well", "+15 max MP, permanently.", {}, { maxMp: 15 }),
    passive("necro_harvest", "necro_marrow_well", 1, 2, "Harvest", "Kills refund 3 MP.", { killRefundMp: 3 }),
    active("necro_grave_chill", 2, "Grave Chill", "The cold of the tomb; the enemy may freeze.", {
      name: "Grave Chill", description: "The cold of the tomb.", mpCost: 9, kind: "damage", multiplier: 1.4, stat: "intelligence",
      inflicts: { kind: "stun", chance: 0.55, turns: 1, power: 0 },
    }),
    passive("necro_pallor", "necro_grave_chill", 2, 1, "Pallor", "Poison never touches you.", { poisonResist: true }),
    passive("necro_deathward", "necro_pallor", 2, 2, "Deathward", "+2 DEF, always.", { defense: 2 }),
    capstone("necro_soul_rend", "necro_grave_touch", 0, "Soul Rend", "Tears the seam between body and soul: enormous INT damage.", {
      name: "Soul Rend", description: "Tears the seam.", mpCost: 13, kind: "damage", multiplier: 3.3, stat: "intelligence",
    }),
    capstone("necro_plague", "necro_harvest", 1, "Plaguebringer", "Rot given ambition: damage and a vicious lasting poison.", {
      name: "Plaguebringer", description: "Rot given ambition.", mpCost: 12, kind: "damage", multiplier: 1.8, stat: "intelligence",
      inflicts: { kind: "poison", chance: 0.95, turns: 5, power: 8 },
    }),
    passive("necro_lichbone", "necro_deathward", 2, 3, "Lichbone", "+20 max HP and +10 max MP, permanently.", {}, { maxHp: 20, maxMp: 10 }),
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
  const skills = nodes
    .filter((n) => n.kind === "active" && owned.has(n.id))
    .map((node) => {
      const skill = Object.assign({}, node.skill);
      for (const up of nodes) {
        if (up.kind === "upgrade" && owned.has(up.id) && up.requires === node.id) {
          Object.assign(skill, up.patch);
        }
      }
      return skill;
    });
  // the specialization's signature skill: taught by identity, not the tree
  const spec = getSpec(hero);
  if (spec) skills.push(spec.signature);
  return skills;
}

/** All owned passive effects, merged. */
export function getPassives(hero: Hero): PassiveEffects {
  const merged = { ...NO_PASSIVES };
  const owned = new Set(hero.skillNodes);
  const spec = getSpec(hero);
  const sources: Partial<PassiveEffects>[] = spec ? [spec.passive] : [];
  for (const node of SKILL_TREES[hero.roleId]) {
    if (node.kind !== "passive" || !owned.has(node.id) || !node.passive) continue;
    sources.push(node.passive);
  }
  for (const effects of sources) {
    merged.defense += effects.defense ?? 0;
    merged.fleeBonus += effects.fleeBonus ?? 0;
    merged.carryBonus += effects.carryBonus ?? 0;
    merged.critChance += effects.critChance ?? 0;
    merged.killRefundMp += effects.killRefundMp ?? 0;
    merged.goldBonus += effects.goldBonus ?? 0;
    merged.lowHpBonus += effects.lowHpBonus ?? 0;
    merged.stunResist = merged.stunResist || (effects.stunResist ?? false);
    merged.poisonResist = merged.poisonResist || (effects.poisonResist ?? false);
    merged.attackInflict = effects.attackInflict ?? merged.attackInflict;
  }
  return merged;
}


export function canBuyNode(hero: Hero, node: SkillNode): boolean {
  if (hero.skillPoints <= 0) return false;
  if (hero.skillNodes.includes(node.id)) return false;
  if (node.requires && !hero.skillNodes.includes(node.requires)) return false;
  return true;
}
