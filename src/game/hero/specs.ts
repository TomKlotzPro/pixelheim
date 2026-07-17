import type { Hero, RoleId, Skill } from "../types";
import type { PassiveEffects } from "./skillTree";
import { rankIndex } from "./ranks";

/**
 * Specializations: at the first ascension (rank 1, level 5) every class faces
 * a fork. A spec is a permanent identity - a passive theme that is always on,
 * and a signature skill no tree can teach. Two Rangers need never play alike.
 */
export type Spec = {
  id: string;
  roleId: RoleId;
  name: string;
  blurb: string;
  passive: Partial<PassiveEffects>;
  signature: Skill;
};

const sig = (skill: Omit<Skill, "unlockLevel">): Skill => ({ ...skill, unlockLevel: 1 });

export const SPECS: Spec[] = [
  // warrior
  {
    id: "juggernaut",
    roleId: "warrior",
    name: "Juggernaut",
    blurb: "The wall that walks. +3 DEF always, and nothing staggers you.",
    passive: { defense: 3, stunResist: true },
    signature: sig({
      name: "Immovable",
      description: "Plant your feet: a crushing counter-blow.",
      mpCost: 7,
      kind: "damage",
      multiplier: 2.2,
      stat: "strength",
    }),
  },
  {
    id: "warlord",
    roleId: "warrior",
    name: "Warlord",
    blurb: "The blade that leads. +12% crit, and the killing gets easier.",
    passive: { critChance: 0.12, lowHpBonus: 0.2 },
    signature: sig({
      name: "War Cry",
      description: "A roar and a wide swing that can stagger.",
      mpCost: 8,
      kind: "damage",
      multiplier: 1.8,
      stat: "strength",
      inflicts: { kind: "stun", chance: 0.45, turns: 1, power: 0 },
    }),
  },
  // mage
  {
    id: "pyromancer",
    roleId: "mage",
    name: "Pyromancer",
    blurb: "Everything burns. Plain attacks can ignite; fire answers to you.",
    passive: { attackInflict: { kind: "burn", chance: 0.3, turns: 2, power: 5 } },
    signature: sig({
      name: "Inferno",
      description: "The room becomes a furnace.",
      mpCost: 11,
      kind: "damage",
      multiplier: 2.4,
      stat: "intelligence",
      inflicts: { kind: "burn", chance: 0.9, turns: 3, power: 7 },
    }),
  },
  {
    id: "stormcaller",
    roleId: "mage",
    name: "Stormcaller",
    blurb: "The sky on a leash. Kills refund 4 MP; lightning stuns.",
    passive: { killRefundMp: 4 },
    signature: sig({
      name: "Thunderlash",
      description: "A whipcrack of lightning that can stun.",
      mpCost: 9,
      kind: "damage",
      multiplier: 2.0,
      stat: "intelligence",
      inflicts: { kind: "stun", chance: 0.55, turns: 1, power: 0 },
    }),
  },
  // rogue
  {
    id: "assassin",
    roleId: "rogue",
    name: "Assassin",
    blurb: "One opening is plenty. +15% crit for 1.5x damage.",
    passive: { critChance: 0.15 },
    signature: sig({
      name: "Killing Blow",
      description: "The artery, found.",
      mpCost: 9,
      kind: "damage",
      multiplier: 2.6,
      stat: "dexterity",
    }),
  },
  {
    id: "trickster",
    roleId: "rogue",
    name: "Trickster",
    blurb: "Never where they look. +20% flee, and escape artistry pays.",
    passive: { fleeBonus: 0.2, goldBonus: 0.1 },
    signature: sig({
      name: "Smoke Bomb",
      description: "Vanish, strike, reappear grinning. May stun.",
      mpCost: 8,
      kind: "damage",
      multiplier: 1.6,
      stat: "dexterity",
      inflicts: { kind: "stun", chance: 0.5, turns: 1, power: 0 },
    }),
  },
  // cleric
  {
    id: "templar",
    roleId: "cleric",
    name: "Templar",
    blurb: "Faith in plate. +2 DEF, +20 HP, and the light hits back.",
    passive: { defense: 2 },
    signature: sig({
      name: "Radiant Hammer",
      description: "A hammer of light falls.",
      mpCost: 8,
      kind: "damage",
      multiplier: 2.2,
      stat: "intelligence",
    }),
  },
  {
    id: "oracle",
    roleId: "cleric",
    name: "Oracle",
    blurb: "The wound refuses. Kills refund 4 MP; your mending deepens.",
    passive: { killRefundMp: 4 },
    signature: sig({
      name: "Foresight",
      description: "Heal what was about to happen.",
      mpCost: 8,
      kind: "heal",
      multiplier: 3.0,
      stat: "intelligence",
    }),
  },
  // ranger
  {
    id: "deadeye",
    roleId: "ranger",
    name: "Deadeye",
    blurb: "One arrow, one ledger line. +15% crit.",
    passive: { critChance: 0.15 },
    signature: sig({
      name: "Piercing Shot",
      description: "Through armor, through excuses.",
      mpCost: 8,
      kind: "damage",
      multiplier: 2.4,
      stat: "dexterity",
    }),
  },
  {
    id: "beastmaster",
    roleId: "ranger",
    name: "Beastmaster",
    blurb: "The wilds walk with you. +20 carry, poison never touches you.",
    passive: { carryBonus: 20, poisonResist: true },
    signature: sig({
      name: "Wolf Companion",
      description: "Your shadow has teeth: a savaging that poisons.",
      mpCost: 8,
      kind: "damage",
      multiplier: 1.7,
      stat: "dexterity",
      inflicts: { kind: "poison", chance: 0.9, turns: 3, power: 6 },
    }),
  },
  // paladin
  {
    id: "justicar",
    roleId: "paladin",
    name: "Justicar",
    blurb: "Verdicts, delivered. +12% crit and richer spoils.",
    passive: { critChance: 0.12, goldBonus: 0.15 },
    signature: sig({
      name: "Final Verdict",
      description: "The gavel is a warhammer.",
      mpCost: 9,
      kind: "damage",
      multiplier: 2.3,
      stat: "strength",
    }),
  },
  {
    id: "guardian",
    roleId: "paladin",
    name: "Guardian",
    blurb: "Nothing gets past. +3 DEF, and stuns break on you.",
    passive: { defense: 3, stunResist: true },
    signature: sig({
      name: "Aegis Strike",
      description: "The shield answers for you.",
      mpCost: 7,
      kind: "damage",
      multiplier: 1.9,
      stat: "strength",
    }),
  },
  // necromancer
  {
    id: "plaguelord",
    roleId: "necromancer",
    name: "Plaguelord",
    blurb: "Rot with ambition. Plain attacks can poison.",
    passive: { attackInflict: { kind: "poison", chance: 0.3, turns: 3, power: 5 } },
    signature: sig({
      name: "Pestilence",
      description: "A sickness with a name on it.",
      mpCost: 10,
      kind: "damage",
      multiplier: 1.6,
      stat: "intelligence",
      inflicts: { kind: "poison", chance: 0.95, turns: 5, power: 7 },
    }),
  },
  {
    id: "bonelord",
    roleId: "necromancer",
    name: "Bonelord",
    blurb: "Death, declined. +2 DEF, poison immunity, kills refund 3 MP.",
    passive: { defense: 2, poisonResist: true, killRefundMp: 3 },
    signature: sig({
      name: "Bone Armor",
      description: "The dead stand between you and harm, then lash out.",
      mpCost: 8,
      kind: "damage",
      multiplier: 1.9,
      stat: "intelligence",
    }),
  },
];

export function specsFor(roleId: RoleId): Spec[] {
  return SPECS.filter((s) => s.roleId === roleId);
}

export function getSpec(hero: Hero): Spec | null {
  if (!hero.spec) return null;
  return SPECS.find((s) => s.id === hero.spec && s.roleId === hero.roleId) ?? null;
}

/** A spec may be chosen once the first ascension has happened. */
export function canChooseSpec(hero: Hero): boolean {
  return rankIndex(hero.level) >= 1 && !hero.spec;
}
