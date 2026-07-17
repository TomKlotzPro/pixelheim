import { applyLevelUps, STAT_POINTS_PER_LEVEL, staminaRegen } from "../hero/character";
import {
  consumeStun,
  fleeChance,
  heroAttackDamage,
  heroSkillDamage,
  heroSkillPower,
  isStunned,
  monsterAttackDamage,
  rollInfliction,
  spawnMonster,
  tickDamageEffects,
} from "./combat";
import { rollDrop } from "./drops";
import { WILD_REWARD_MULT, type WildEncounter } from "./encounters";
import { addItem } from "../economy/inventory";
import { getItem } from "../economy/items";
import { doubleForageChance, forageChance, grantJobXp } from "../economy/jobs";
import { getLevel, LEVELS } from "../hero/levels";
import { createGear, gearName } from "../economy/rarity";
import { REGION_MATERIALS } from "../economy/recipes";
import { getHeroSkills, getPassives } from "../hero/skillTree";
import type { BattleState, GameState, Hero } from "../types";
import { recordKill } from "../hero/mastery";
import { RENT_PER_VICTORY } from "../../state/shared";

/**
 * The battle engine: the whole turn pipeline as functions over the game
 * state. Every function here mutates a draft the reducer has already cloned;
 * the reducer stays the only place that copies state.
 */

const EFFECT_VERBS: Record<string, string> = { poison: "Poison", burn: "Burning" };

const BOSS_IDS = new Set(["dragon", "lich"]);

/** A fresh battle at the door of a dungeon floor. */
export function createDungeonBattle(level: number): BattleState {
  const dungeon = getLevel(level);
  const monster = spawnMonster(dungeon.encounters[0]);
  return {
    dungeonLevel: level,
    encounterIndex: 0,
    monster,
    phase: "player",
    log: [`You enter ${dungeon.name}.`, `A ${monster.name} blocks your path!`],
    heroEffects: [],
    monsterEffects: [],
  };
}

/** An ambush in the wilds: reduced rewards, drops from the region's floor pool. */
export function createWildBattle(encounter: WildEncounter): BattleState {
  const monster = spawnMonster(encounter.def);
  monster.xp = Math.round(monster.xp * WILD_REWARD_MULT);
  monster.gold = Math.round(monster.gold * WILD_REWARD_MULT);
  return {
    dungeonLevel: encounter.dropFloor,
    encounterIndex: 0,
    monster,
    phase: "player",
    log: [`A ${monster.name} turns to face you in ${encounter.regionName}!`],
    heroEffects: [],
    monsterEffects: [],
    wild: true,
    wildRegion: encounter.regionName,
    wildRegionId: encounter.regionId,
  };
}

/**
 * Everything that happens after the hero's action: damage-over-time ticks on
 * the monster, the monster's attack (unless stunned) with its infliction roll,
 * then damage-over-time on the hero. Mutates the given draft slices.
 */
export function monsterTurn(state: GameState, hero: Hero, log: string[]): void {
  const battle = state.battle!;
  if (battle.monster.hp <= 0) return;

  const monsterTick = tickDamageEffects(battle.monsterEffects);
  battle.monsterEffects = monsterTick.effects;
  for (const tick of monsterTick.ticks) {
    battle.monster.hp = Math.max(0, battle.monster.hp - tick.damage);
    log.push(`${EFFECT_VERBS[tick.kind]} deals ${tick.damage} damage to ${battle.monster.name}.`);
  }
  if (battle.monster.hp <= 0) {
    onMonsterDefeated(state, hero, log);
    return;
  }

  if (isStunned(battle.monsterEffects)) {
    battle.monsterEffects = consumeStun(battle.monsterEffects);
    log.push(`${battle.monster.name} is stunned and cannot act!`);
  } else {
    const dmg = monsterAttackDamage(battle.monster, hero, state.gear, state.equipped);
    hero.hp = Math.max(0, hero.hp - dmg);
    log.push(`${battle.monster.name} hits you for ${dmg} damage.`);
    const monsterInflicts = battle.monster.def.inflicts;
    const passives = getPassives(hero);
    const resisted =
      (monsterInflicts?.kind === "stun" && passives.stunResist) ||
      (monsterInflicts?.kind === "poison" && passives.poisonResist);
    const inflicted = resisted
      ? { effects: battle.heroEffects, applied: false }
      : rollInfliction(battle.heroEffects, monsterInflicts);
    if (inflicted.applied) {
      battle.heroEffects = inflicted.effects;
      log.push(`You are afflicted by ${monsterInflicts!.kind}!`);
    }
    if (hero.hp <= 0) {
      battle.phase = "lost";
      log.push("You collapse. Everything goes dark...");
      return;
    }
  }

  const heroTick = tickDamageEffects(battle.heroEffects);
  battle.heroEffects = heroTick.effects;
  for (const tick of heroTick.ticks) {
    hero.hp = Math.max(0, hero.hp - tick.damage);
    log.push(`${EFFECT_VERBS[tick.kind]} deals ${tick.damage} damage to you.`);
  }
  if (hero.hp <= 0) {
    battle.phase = "lost";
    log.push("You succumb to your wounds. Everything goes dark...");
    return;
  }
  // Martials catch their breath: endurance trickles back every round.
  hero.mp = Math.min(hero.stats.maxMp, hero.mp + staminaRegen(hero));
}

/**
 * If the hero is stunned, their action is wasted: the stun is consumed, the
 * monster still acts, and the caller must return immediately. Returns true
 * when the turn was skipped.
 */
export function heroStunGate(state: GameState, hero: Hero, log: string[]): boolean {
  const battle = state.battle!;
  if (!isStunned(battle.heroEffects)) return false;
  battle.heroEffects = consumeStun(battle.heroEffects);
  log.push("You are stunned and cannot act!");
  monsterTurn(state, hero, log);
  return true;
}

function onMonsterDefeated(state: GameState, hero: Hero, log: string[]): void {
  const slain = recordKill(hero, state.battle!.monster.def.id);
  if (slain) log.push(slain);
  // The landlord's cut: every owned business pays its rent on a victory.
  if (state.properties.length > 0) {
    const rent = state.properties.length * RENT_PER_VICTORY;
    state.gold += rent;
    log.push(`Rent from your properties: +${rent}g.`);
  }
  const battle = state.battle!;
  const passives = getPassives(hero);
  const { xp, name } = battle.monster;
  const gold = Math.round(battle.monster.gold * (1 + passives.goldBonus));
  log.push(`${name} is defeated! +${xp} XP, +${gold} gold.`);
  hero.xp += xp;
  state.gold += gold;
  if (passives.killRefundMp > 0) {
    hero.mp = Math.min(hero.stats.maxMp, hero.mp + passives.killRefundMp);
  }
  const gained = applyLevelUps(hero);
  if (gained > 0) {
    log.push(
      `LEVEL UP! You are now level ${hero.level}. Fully restored. ` +
        `+${gained * STAT_POINTS_PER_LEVEL} stat points and +${gained} skill point${gained > 1 ? "s" : ""} to spend.`,
    );
  }

  const kind = BOSS_IDS.has(battle.monster.def.id) ? "boss" : battle.monster.elite ? "elite" : "normal";
  const drop = rollDrop(battle.dungeonLevel, kind);
  if (drop?.kind === "gear") {
    state.gear.push(drop.gear);
    log.push(`${name} drops: ${gearName(drop.gear)}!`);
  } else if (drop?.kind === "stack") {
    state.inventory = addItem(state.inventory, drop.itemId);
    log.push(`${name} drops: ${getItem(drop.itemId).name}.`);
  }

  // Ailments do not linger between fights.
  battle.heroEffects = [];
  battle.monsterEffects = [];

  if (battle.wild) {
    battle.phase = "cleared";
    log.push("The wilds fall quiet again.");
    if (battle.wildSpawnId && state.world) state.world.slain.push(battle.wildSpawnId);
    // Forage the region while the ground is still warm.
    const material = battle.wildRegionId ? REGION_MATERIALS[battle.wildRegionId] : undefined;
    if (material && Math.random() < forageChance(hero.jobs.foraging.level)) {
      const count = 1 + (Math.random() < doubleForageChance(hero.jobs.foraging.level) ? 1 : 0);
      state.inventory = addItem(state.inventory, material, count);
      log.push(`You forage ${count} ${getItem(material).name}${count > 1 ? "s" : ""}.`);
      if (grantJobXp(hero, "foraging", 5) > 0) {
        log.push(`Foraging reached ${hero.jobs.foraging.level}!`);
      }
    }
    return;
  }

  const dungeon = getLevel(battle.dungeonLevel);
  if (battle.encounterIndex >= dungeon.encounters.length - 1) {
    battle.phase = "cleared";
    log.push(`${dungeon.name} cleared!`);
  } else {
    battle.phase = "won";
  }
}

/** The hero's plain attack, then the monster's whole turn. */
export function heroAttack(state: GameState): void {
  const hero = state.hero!;
  const battle = state.battle!;
  if (heroStunGate(state, hero, battle.log)) return;
  const dmg = heroAttackDamage(hero, state.gear, state.equipped, battle.monster);
  battle.monster.hp = Math.max(0, battle.monster.hp - dmg);
  battle.log.push(`You strike ${battle.monster.name} for ${dmg} damage.`);
  if (battle.monster.hp <= 0) {
    onMonsterDefeated(state, hero, battle.log);
    return;
  }
  // Cinders-style passives can set the enemy alight on a plain attack.
  const attackInflict = getPassives(hero).attackInflict;
  if (attackInflict) {
    const inflicted = rollInfliction(battle.monsterEffects, attackInflict);
    if (inflicted.applied) {
      battle.monsterEffects = inflicted.effects;
      battle.log.push(`${battle.monster.name} is afflicted by ${attackInflict.kind}!`);
    }
  }
  monsterTurn(state, hero, battle.log);
}

/** Casts the hero's skill at the given index. The reducer has already checked costs. */
export function heroSkill(state: GameState, skillIndex: number): void {
  const hero = state.hero!;
  const battle = state.battle!;
  if (heroStunGate(state, hero, battle.log)) return;
  const skill = getHeroSkills(hero)[skillIndex];
  hero.mp -= skill.mpCost;
  if (skill.hpCost) hero.hp -= skill.hpCost;
  if (skill.kind === "heal") {
    const amount = heroSkillPower(hero, skill, state.gear, state.equipped);
    hero.hp = Math.min(hero.stats.maxHp, hero.hp + amount);
    battle.log.push(`${skill.name} restores ${amount} HP.`);
    if (skill.cleanse && battle.heroEffects.length > 0) {
      battle.heroEffects = [];
      battle.log.push("All ailments are purged!");
    }
    monsterTurn(state, hero, battle.log);
    return;
  }
  const dmg = heroSkillDamage(hero, skill, state.gear, state.equipped, battle.monster);
  battle.monster.hp = Math.max(0, battle.monster.hp - dmg);
  battle.log.push(`${skill.name} hits ${battle.monster.name} for ${dmg} damage!`);
  if (battle.monster.hp <= 0) {
    onMonsterDefeated(state, hero, battle.log);
    return;
  }
  const inflicted = rollInfliction(battle.monsterEffects, skill.inflicts);
  if (inflicted.applied) {
    battle.monsterEffects = inflicted.effects;
    battle.log.push(`${battle.monster.name} is afflicted by ${skill.inflicts!.kind}!`);
  }
  monsterTurn(state, hero, battle.log);
}

/** Attempts to flee: escaping leaves the battle, failing hands the turn over. */
export function heroFlee(state: GameState): void {
  const hero = state.hero!;
  const battle = state.battle!;
  if (heroStunGate(state, hero, battle.log)) return;
  if (Math.random() < fleeChance(hero, state.gear, state.equipped)) {
    state.screen = battle.wild ? "world" : "dungeon_select";
    state.battle = null;
    return;
  }
  battle.log.push("You fail to escape!");
  monsterTurn(state, hero, battle.log);
}

/** After a won fight, brings out the floor's next monster. */
export function advanceEncounter(state: GameState): void {
  const battle = state.battle!;
  const dungeon = getLevel(battle.dungeonLevel);
  battle.encounterIndex += 1;
  battle.monster = spawnMonster(dungeon.encounters[battle.encounterIndex]);
  battle.phase = "player";
  battle.heroEffects = [];
  battle.monsterEffects = [];
  battle.log.push(`A ${battle.monster.name} appears!`);
}

/** Grants a cleared dungeon's first-time rewards and unlocks the next floor. */
export function grantFloorRewards(state: GameState, level: number): void {
  const dungeon = getLevel(level);
  state.clearedLevels.push(dungeon.level);
  state.gold += dungeon.rewardGold;
  for (const id of dungeon.rewardItemIds) {
    if (getItem(id).slot) state.gear.push(createGear(id));
    else state.inventory = addItem(state.inventory, id);
  }
  state.unlockedLevel = Math.max(state.unlockedLevel, Math.min(dungeon.level + 1, LEVELS.length));
}
