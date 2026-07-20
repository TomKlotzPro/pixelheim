import type { Hero, RoleId, Skill } from "../types";
import { rankIndex } from "./ranks";
import { SPECS, type Spec } from "./specs";

/**
 * The Path Graph (PIX-105): identity is a walk, not a checkbox. Rank 1 forks
 * into the class's two specs; rank 2 offers each path's advanced form - and
 * the crossover into the other's; rank 3 is the capstone, earned only through
 * its own advanced form. Every node carries the WHOLE identity at that step:
 * passives replace (they do not stack), the signature skill is superseded.
 *
 *   tier 1 (rank 1):   a1 ─┬─→ a2 ──→ a3
 *                          ╳
 *                      b1 ─┴─→ b2 ──→ b3
 */
export type PathNode = Spec & {
  /** Rank required to take this node; also its column in the graph. */
  tier: 1 | 2 | 3;
  /** Palette identity family: which side's colors the hero wears. */
  branch: "a" | "b";
  /** Node ids that may ascend into this one (empty for tier 1). */
  from: string[];
};

const sig = (skill: Omit<Skill, "unlockLevel">): Skill => ({ ...skill, unlockLevel: 1 });

/** Tier 1 is the existing spec fork: first spec of a role is branch a. */
const TIER1: PathNode[] = SPECS.map((spec, i) => ({
  ...spec,
  tier: 1,
  branch: i % 2 === 0 ? "a" : "b",
  from: [],
}));

/** tier-2 nodes accept both tier-1 nodes of the role: the crossover. */
const both = (roleId: RoleId): string[] => SPECS.filter((s) => s.roleId === roleId).map((s) => s.id);

const DEEPER: PathNode[] = [
  // ---------------- warrior: juggernaut (a) / warlord (b) ----------------
  {
    id: "bastion",
    roleId: "warrior",
    tier: 2,
    branch: "a",
    from: both("warrior"),
    name: "Bastion",
    blurb: "A fortress that marches. +5 DEF, unstaggerable, stronger when bloodied.",
    passive: { defense: 5, stunResist: true, lowHpBonus: 0.1 },
    signature: sig({
      name: "Bastion Break",
      description: "The wall falls forward.",
      mpCost: 8,
      kind: "damage",
      multiplier: 2.6,
      stat: "strength",
    }),
  },
  {
    id: "battlelord",
    roleId: "warrior",
    tier: 2,
    branch: "b",
    from: both("warrior"),
    name: "Battlelord",
    blurb: "The war has a favorite. +16% crit, and desperation sharpens you.",
    passive: { critChance: 0.16, lowHpBonus: 0.3 },
    signature: sig({
      name: "Rallying Roar",
      description: "A war cry that armies would follow.",
      mpCost: 9,
      kind: "damage",
      multiplier: 2.1,
      stat: "strength",
      inflicts: { kind: "stun", chance: 0.55, turns: 1, power: 0 },
    }),
  },
  {
    id: "unbroken",
    roleId: "warrior",
    tier: 3,
    branch: "a",
    from: ["bastion"],
    name: "The Unbroken",
    blurb: "Nothing has ever knocked you down. +8 DEF, immune to stun and poison.",
    passive: { defense: 8, stunResist: true, poisonResist: true, lowHpBonus: 0.15 },
    signature: sig({
      name: "Worldsplitter",
      description: "The ground remembers where it landed.",
      mpCost: 10,
      kind: "damage",
      multiplier: 3.2,
      stat: "strength",
    }),
  },
  {
    id: "warfather",
    roleId: "warrior",
    tier: 3,
    branch: "b",
    from: ["battlelord"],
    name: "Warfather",
    blurb: "Battles are named after you. +22% crit, fury at the brink, spoils flow.",
    passive: { critChance: 0.22, lowHpBonus: 0.4, goldBonus: 0.1 },
    signature: sig({
      name: "Hundred Wars",
      description: "Every war you ever won, swung at once.",
      mpCost: 11,
      kind: "damage",
      multiplier: 2.8,
      stat: "strength",
      inflicts: { kind: "stun", chance: 0.6, turns: 1, power: 0 },
    }),
  },
  // ---------------- mage: pyromancer (a) / stormcaller (b) ----------------
  {
    id: "cinderlord",
    roleId: "mage",
    tier: 2,
    branch: "a",
    from: both("mage"),
    name: "Cinderlord",
    blurb: "Ash follows you like a court. Attacks burn far more often.",
    passive: { attackInflict: { kind: "burn", chance: 0.4, turns: 2, power: 6 } },
    signature: sig({
      name: "Firestorm",
      description: "The horizon catches.",
      mpCost: 12,
      kind: "damage",
      multiplier: 2.8,
      stat: "intelligence",
      inflicts: { kind: "burn", chance: 0.95, turns: 3, power: 8 },
    }),
  },
  {
    id: "tempest",
    roleId: "mage",
    tier: 2,
    branch: "b",
    from: both("mage"),
    name: "Tempest",
    blurb: "Weather with a grudge. Kills refund 6 MP; the bolts bite harder.",
    passive: { killRefundMp: 6, critChance: 0.08 },
    signature: sig({
      name: "Stormlash",
      description: "The sky cracks its whip twice.",
      mpCost: 10,
      kind: "damage",
      multiplier: 2.4,
      stat: "intelligence",
      inflicts: { kind: "stun", chance: 0.6, turns: 1, power: 0 },
    }),
  },
  {
    id: "sun_incarnate",
    roleId: "mage",
    tier: 3,
    branch: "a",
    from: ["cinderlord"],
    name: "Sun Incarnate",
    blurb: "You stopped casting fire. You started being it.",
    passive: { attackInflict: { kind: "burn", chance: 0.5, turns: 3, power: 8 }, critChance: 0.1 },
    signature: sig({
      name: "Supernova",
      description: "Daylight, delivered personally.",
      mpCost: 14,
      kind: "damage",
      multiplier: 3.4,
      stat: "intelligence",
      inflicts: { kind: "burn", chance: 1, turns: 3, power: 10 },
    }),
  },
  {
    id: "stormeye",
    roleId: "mage",
    tier: 3,
    branch: "b",
    from: ["tempest"],
    name: "Eye of the Storm",
    blurb: "Perfect calm, catastrophic weather. Kills refund 8 MP, +15% crit.",
    passive: { killRefundMp: 8, critChance: 0.15, fleeBonus: 0.1 },
    signature: sig({
      name: "Heavenfall",
      description: "You point. The sky agrees.",
      mpCost: 12,
      kind: "damage",
      multiplier: 3.0,
      stat: "intelligence",
      inflicts: { kind: "stun", chance: 0.65, turns: 1, power: 0 },
    }),
  },
  // ---------------- rogue: assassin (a) / trickster (b) ----------------
  {
    id: "nightblade",
    roleId: "rogue",
    tier: 2,
    branch: "a",
    from: both("rogue"),
    name: "Nightblade",
    blurb: "The dark keeps your appointments. +22% crit.",
    passive: { critChance: 0.22 },
    signature: sig({
      name: "Throatseeker",
      description: "It knows the way.",
      mpCost: 10,
      kind: "damage",
      multiplier: 3.0,
      stat: "dexterity",
    }),
  },
  {
    id: "phantom_jester",
    roleId: "rogue",
    tier: 2,
    branch: "b",
    from: both("rogue"),
    name: "Phantom Jester",
    blurb: "The joke lands; you don't. +30% flee, +20% gold, +8% crit.",
    passive: { fleeBonus: 0.3, goldBonus: 0.2, critChance: 0.08 },
    signature: sig({
      name: "Mirror Feint",
      description: "They hit the laugh, not the throat.",
      mpCost: 9,
      kind: "damage",
      multiplier: 1.9,
      stat: "dexterity",
      inflicts: { kind: "stun", chance: 0.55, turns: 1, power: 0 },
    }),
  },
  {
    id: "deaths_whisper",
    roleId: "rogue",
    tier: 3,
    branch: "a",
    from: ["nightblade"],
    name: "Death's Whisper",
    blurb: "+30% crit, and your blades carry a rumor of venom.",
    passive: { critChance: 0.3, attackInflict: { kind: "poison", chance: 0.25, turns: 2, power: 4 } },
    signature: sig({
      name: "Thousand Cuts",
      description: "Count them later.",
      mpCost: 12,
      kind: "damage",
      multiplier: 3.4,
      stat: "dexterity",
    }),
  },
  {
    id: "unseen",
    roleId: "rogue",
    tier: 3,
    branch: "b",
    from: ["phantom_jester"],
    name: "The Unseen",
    blurb: "Officially, you were never there. +40% flee, +30% gold, unstunned.",
    passive: { fleeBonus: 0.4, goldBonus: 0.3, critChance: 0.12, stunResist: true },
    signature: sig({
      name: "Vanishing Act",
      description: "Applause from an empty room.",
      mpCost: 10,
      kind: "damage",
      multiplier: 2.4,
      stat: "dexterity",
      inflicts: { kind: "stun", chance: 0.6, turns: 1, power: 0 },
    }),
  },
  // ---------------- cleric: templar (a) / oracle (b) ----------------
  {
    id: "dawn_crusader",
    roleId: "cleric",
    tier: 2,
    branch: "a",
    from: both("cleric"),
    name: "Crusader of Dawn",
    blurb: "Morning, weaponized. +4 DEF, +8% crit.",
    passive: { defense: 4, critChance: 0.08 },
    signature: sig({
      name: "Dawnbreaker",
      description: "The first light lands like a verdict.",
      mpCost: 10,
      kind: "damage",
      multiplier: 2.6,
      stat: "intelligence",
    }),
  },
  {
    id: "seer",
    roleId: "cleric",
    tier: 2,
    branch: "b",
    from: both("cleric"),
    name: "Seer",
    blurb: "You read the next page. Kills refund 6 MP; mending deepens.",
    passive: { killRefundMp: 6 },
    signature: sig({
      name: "Providence",
      description: "Heal the wound before its echo.",
      mpCost: 9,
      kind: "heal",
      multiplier: 3.6,
      stat: "intelligence",
    }),
  },
  {
    id: "light_avatar",
    roleId: "cleric",
    tier: 3,
    branch: "a",
    from: ["dawn_crusader"],
    name: "Avatar of Light",
    blurb: "Shadows file complaints. +6 DEF, +12% crit, unstaggerable.",
    passive: { defense: 6, critChance: 0.12, stunResist: true },
    signature: sig({
      name: "Judgement Sun",
      description: "Noon, at midnight, on demand.",
      mpCost: 12,
      kind: "damage",
      multiplier: 3.0,
      stat: "intelligence",
    }),
  },
  {
    id: "fate_voice",
    roleId: "cleric",
    tier: 3,
    branch: "b",
    from: ["seer"],
    name: "Voice of Fate",
    blurb: "The book listens back. Kills refund 8 MP, poison-proof, +2 DEF.",
    passive: { killRefundMp: 8, poisonResist: true, defense: 2 },
    signature: sig({
      name: "Rewrite Fate",
      description: "Cross out the wound. Write 'whole'.",
      mpCost: 11,
      kind: "heal",
      multiplier: 4.5,
      stat: "intelligence",
    }),
  },
  // ---------------- ranger: deadeye (a) / beastmaster (b) ----------------
  {
    id: "hawkeye",
    roleId: "ranger",
    tier: 2,
    branch: "a",
    from: both("ranger"),
    name: "Hawkeye",
    blurb: "Distance is a rumor. +22% crit.",
    passive: { critChance: 0.22 },
    signature: sig({
      name: "Twin Arrows",
      description: "Two answers to one question.",
      mpCost: 10,
      kind: "damage",
      multiplier: 2.8,
      stat: "dexterity",
    }),
  },
  {
    id: "packlord",
    roleId: "ranger",
    tier: 2,
    branch: "b",
    from: both("ranger"),
    name: "Packlord",
    blurb: "The forest hunts beside you. +30 carry, venom-proof, attacks poison.",
    passive: {
      carryBonus: 30,
      poisonResist: true,
      attackInflict: { kind: "poison", chance: 0.25, turns: 2, power: 4 },
    },
    signature: sig({
      name: "Alpha's Call",
      description: "The pack answers before the echo.",
      mpCost: 10,
      kind: "damage",
      multiplier: 2.0,
      stat: "dexterity",
      inflicts: { kind: "poison", chance: 0.95, turns: 3, power: 7 },
    }),
  },
  {
    id: "stormbow",
    roleId: "ranger",
    tier: 3,
    branch: "a",
    from: ["hawkeye"],
    name: "Stormbow",
    blurb: "You shoot where the world will be. +28% crit, +10% flee.",
    passive: { critChance: 0.28, fleeBonus: 0.1 },
    signature: sig({
      name: "Arrow of Ages",
      description: "Loosed once. Arrives always.",
      mpCost: 12,
      kind: "damage",
      multiplier: 3.3,
      stat: "dexterity",
    }),
  },
  {
    id: "wild_sovereign",
    roleId: "ranger",
    tier: 3,
    branch: "b",
    from: ["packlord"],
    name: "Wild Sovereign",
    blurb: "The wilds crowned you. +40 carry, immune to poison and stun.",
    passive: {
      carryBonus: 40,
      poisonResist: true,
      stunResist: true,
      attackInflict: { kind: "poison", chance: 0.35, turns: 3, power: 5 },
    },
    signature: sig({
      name: "Stampede",
      description: "Every hoof, claw and wing you ever spared.",
      mpCost: 12,
      kind: "damage",
      multiplier: 2.6,
      stat: "dexterity",
      inflicts: { kind: "poison", chance: 1, turns: 4, power: 8 },
    }),
  },
  // ---------------- paladin: justicar (a) / guardian (b) ----------------
  {
    id: "high_judge",
    roleId: "paladin",
    tier: 2,
    branch: "a",
    from: both("paladin"),
    name: "High Judge",
    blurb: "The bench is a battlement. +16% crit, +20% gold.",
    passive: { critChance: 0.16, goldBonus: 0.2 },
    signature: sig({
      name: "Sentence",
      description: "Read aloud, carried out.",
      mpCost: 10,
      kind: "damage",
      multiplier: 2.7,
      stat: "strength",
    }),
  },
  {
    id: "faith_bulwark",
    roleId: "paladin",
    tier: 2,
    branch: "b",
    from: both("paladin"),
    name: "Bulwark of Faith",
    blurb: "Doubt breaks on you first. +5 DEF, unstaggerable.",
    passive: { defense: 5, stunResist: true },
    signature: sig({
      name: "Aegis Wall",
      description: "The shield speaks for the whole line.",
      mpCost: 8,
      kind: "damage",
      multiplier: 2.2,
      stat: "strength",
    }),
  },
  {
    id: "justice_incarnate",
    roleId: "paladin",
    tier: 3,
    branch: "a",
    from: ["high_judge"],
    name: "Justice Incarnate",
    blurb: "The law grew hands. +20% crit, +30% gold, +2 DEF.",
    passive: { critChance: 0.2, goldBonus: 0.3, defense: 2 },
    signature: sig({
      name: "Final Dawn",
      description: "The last case anyone tries.",
      mpCost: 12,
      kind: "damage",
      multiplier: 3.2,
      stat: "strength",
    }),
  },
  {
    id: "undying_shield",
    roleId: "paladin",
    tier: 3,
    branch: "b",
    from: ["faith_bulwark"],
    name: "The Undying Shield",
    blurb: "+8 DEF, immune to stun and poison, fiercer when bloodied.",
    passive: { defense: 8, stunResist: true, poisonResist: true, lowHpBonus: 0.15 },
    signature: sig({
      name: "Last Bastion",
      description: "Where you stand, the losing stops.",
      mpCost: 10,
      kind: "damage",
      multiplier: 2.7,
      stat: "strength",
      inflicts: { kind: "stun", chance: 0.5, turns: 1, power: 0 },
    }),
  },
  // ---------------- necromancer: plaguelord (a) / bonelord (b) ----------------
  {
    id: "rot_herald",
    roleId: "necromancer",
    tier: 2,
    branch: "a",
    from: both("necromancer"),
    name: "Herald of Rot",
    blurb: "Decay sends invitations. Attacks poison far more often.",
    passive: { attackInflict: { kind: "poison", chance: 0.4, turns: 3, power: 6 } },
    signature: sig({
      name: "Black Harvest",
      description: "The field reaps itself.",
      mpCost: 12,
      kind: "damage",
      multiplier: 2.0,
      stat: "intelligence",
      inflicts: { kind: "poison", chance: 1, turns: 5, power: 8 },
    }),
  },
  {
    id: "gravelord",
    roleId: "necromancer",
    tier: 2,
    branch: "b",
    from: both("necromancer"),
    name: "Gravelord",
    blurb: "The dead pay rent. +4 DEF, venom-proof, kills refund 4 MP.",
    passive: { defense: 4, poisonResist: true, killRefundMp: 4 },
    signature: sig({
      name: "Tomb Legion",
      description: "Your honor guard has been waiting.",
      mpCost: 10,
      kind: "damage",
      multiplier: 2.3,
      stat: "intelligence",
    }),
  },
  {
    id: "plague_incarnate",
    roleId: "necromancer",
    tier: 3,
    branch: "a",
    from: ["rot_herald"],
    name: "Plague Incarnate",
    blurb: "Epidemics cite you. Attacks fester; kills feed the mind.",
    passive: { attackInflict: { kind: "poison", chance: 0.5, turns: 4, power: 7 }, killRefundMp: 3 },
    signature: sig({
      name: "Extinction Bloom",
      description: "One flower. No survivors.",
      mpCost: 14,
      kind: "damage",
      multiplier: 2.6,
      stat: "intelligence",
      inflicts: { kind: "poison", chance: 1, turns: 6, power: 10 },
    }),
  },
  {
    id: "bone_king",
    roleId: "necromancer",
    tier: 3,
    branch: "b",
    from: ["gravelord"],
    name: "King in Bone",
    blurb: "Death filed for retirement. +6 DEF, immune to poison and stun.",
    passive: { defense: 6, poisonResist: true, stunResist: true, killRefundMp: 6 },
    signature: sig({
      name: "Ossuary Throne",
      description: "Sit. Let the kingdom defend itself.",
      mpCost: 12,
      kind: "damage",
      multiplier: 2.8,
      stat: "intelligence",
    }),
  },
];

export const PATH_NODES: PathNode[] = [...TIER1, ...DEEPER];

export function getPathNode(id: string): PathNode | null {
  return PATH_NODES.find((n) => n.id === id) ?? null;
}

/** The hero's walked path, tolerant of pre-graph saves (spec = first step). */
export function heroPath(hero: Hero): string[] {
  if (hero.path && hero.path.length > 0) return hero.path;
  return hero.spec ? [hero.spec] : [];
}

/** The deepest identity on the walk: passives and signature come from here. */
export function activeNode(hero: Hero): PathNode | null {
  const path = heroPath(hero);
  if (path.length === 0) return null;
  return getPathNode(path[path.length - 1]);
}

/** Which tier the hero may choose right now, or null if none is pending. */
export function pendingTier(hero: Hero): 1 | 2 | 3 | null {
  const walked = heroPath(hero).length;
  if (walked >= 3) return null;
  const next = (walked + 1) as 1 | 2 | 3;
  return rankIndex(hero.level) >= next ? next : null;
}

export function canChoosePath(hero: Hero): boolean {
  return pendingTier(hero) !== null;
}

/** The nodes on offer for the pending choice: tier-gated, edge-checked. */
export function pathChoices(hero: Hero): PathNode[] {
  const tier = pendingTier(hero);
  if (!tier) return [];
  const path = heroPath(hero);
  const last = path[path.length - 1];
  return PATH_NODES.filter((n) => n.roleId === hero.roleId && n.tier === tier && (tier === 1 || n.from.includes(last)));
}

/** The palette family the hero wears: the deepest node decides. */
export function pathBranch(hero: Hero): "a" | "b" | null {
  return activeNode(hero)?.branch ?? null;
}

/** Every legal full walk through a role's graph, for the balance sim. */
export function pathChains(roleId: RoleId): string[][] {
  const tier1 = PATH_NODES.filter((n) => n.roleId === roleId && n.tier === 1);
  const chains: string[][] = [];
  for (const t1 of tier1) {
    for (const t2 of PATH_NODES.filter((n) => n.roleId === roleId && n.tier === 2 && n.from.includes(t1.id))) {
      for (const t3 of PATH_NODES.filter((n) => n.roleId === roleId && n.tier === 3 && n.from.includes(t2.id))) {
        chains.push([t1.id, t2.id, t3.id]);
      }
    }
  }
  return chains;
}
