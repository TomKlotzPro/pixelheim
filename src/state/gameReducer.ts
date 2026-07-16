import { applyLevelUps, carriedWeight, carryCapacity, createHero } from "../game/character";
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
} from "../game/combat";
import { getItem } from "../game/items";
import { getLevel, LEVELS } from "../game/levels";
import { buyPrice, sellPrice, shopStock } from "../game/shop";
import { ROLES } from "../game/roles";
import type { EquipSlot, GameState, Hero, RoleId } from "../game/types";
import { getMap } from "../world/maps";
import { isWalkable, portalAt } from "../world/parseMap";
import type { Direction } from "../world/types";

export const REST_COST = 10;

export type Action =
  | { type: "NEW_GAME" }
  | { type: "LOAD"; state: GameState }
  | { type: "CREATE_HERO"; name: string; roleId: RoleId }
  | { type: "ENTER_LEVEL"; level: number }
  | { type: "ATTACK" }
  | { type: "SKILL"; skillIndex: number }
  | { type: "FLEE" }
  | { type: "USE_ITEM"; itemId: string }
  | { type: "EQUIP"; itemId: string }
  | { type: "UNEQUIP"; slot: EquipSlot }
  | { type: "DROP"; itemId: string }
  | { type: "TOGGLE_INVENTORY" }
  | { type: "TOGGLE_SHOP" }
  | { type: "BUY_ITEM"; itemId: string }
  | { type: "SELL_ITEM"; itemId: string }
  | { type: "NEXT_ENCOUNTER" }
  | { type: "COLLECT_AND_RETURN" }
  | { type: "REST" }
  | { type: "RETURN_TO_HUB" }
  | { type: "ENTER_WORLD"; mapId: string }
  | { type: "EXIT_WORLD" }
  | { type: "MOVE"; direction: Direction };

export const initialState: GameState = {
  screen: "title",
  hero: null,
  gold: 0,
  inventory: {},
  equipped: {},
  unlockedLevel: 1,
  clearedLevels: [],
  battle: null,
  inventoryOpen: false,
  shopOpen: false,
  world: null,
};

const DIRECTION_DELTAS: Record<Direction, { dx: number; dy: number }> = {
  up: { dx: 0, dy: -1 },
  down: { dx: 0, dy: 1 },
  left: { dx: -1, dy: 0 },
  right: { dx: 1, dy: 0 },
};

function addItem(inventory: Record<string, number>, itemId: string, count = 1): Record<string, number> {
  return { ...inventory, [itemId]: (inventory[itemId] ?? 0) + count };
}

function removeItem(inventory: Record<string, number>, itemId: string, count = 1): Record<string, number> {
  const next = { ...inventory };
  const remaining = (next[itemId] ?? 0) - count;
  if (remaining > 0) next[itemId] = remaining;
  else delete next[itemId];
  return next;
}

const EFFECT_VERBS: Record<string, string> = { poison: "Poison", burn: "Burning" };

/**
 * Everything that happens after the hero's action: damage-over-time ticks on
 * the monster, the monster's attack (unless stunned) with its infliction roll,
 * then damage-over-time on the hero. Mutates the given draft slices.
 */
function monsterTurn(state: GameState, hero: Hero, log: string[]): void {
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
    const dmg = monsterAttackDamage(battle.monster, hero, state.equipped);
    hero.hp = Math.max(0, hero.hp - dmg);
    log.push(`${battle.monster.name} hits you for ${dmg} damage.`);
    const inflicted = rollInfliction(battle.heroEffects, battle.monster.def.inflicts);
    if (inflicted.applied) {
      battle.heroEffects = inflicted.effects;
      log.push(`You are afflicted by ${battle.monster.def.inflicts!.kind}!`);
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
  }
}

/**
 * If the hero is stunned, their action is wasted: the stun is consumed, the
 * monster still acts, and the caller must return immediately. Returns true
 * when the turn was skipped.
 */
function heroStunGate(state: GameState, hero: Hero, log: string[]): boolean {
  const battle = state.battle!;
  if (!isStunned(battle.heroEffects)) return false;
  battle.heroEffects = consumeStun(battle.heroEffects);
  log.push("You are stunned and cannot act!");
  monsterTurn(state, hero, log);
  return true;
}

function onMonsterDefeated(state: GameState, hero: Hero, log: string[]): void {
  const battle = state.battle!;
  const { xp, gold, name } = battle.monster;
  log.push(`${name} is defeated! +${xp} XP, +${gold} gold.`);
  hero.xp += xp;
  state.gold += gold;
  const gained = applyLevelUps(hero);
  if (gained > 0) log.push(`LEVEL UP! You are now level ${hero.level}. Fully restored.`);

  // Ailments do not linger between fights.
  battle.heroEffects = [];
  battle.monsterEffects = [];

  const dungeon = getLevel(battle.dungeonLevel);
  if (battle.encounterIndex >= dungeon.encounters.length - 1) {
    battle.phase = "cleared";
    log.push(`${dungeon.name} cleared!`);
  } else {
    battle.phase = "won";
  }
}

export function gameReducer(state: GameState, action: Action): GameState {
  switch (action.type) {
    case "NEW_GAME":
      return { ...initialState, screen: "create" };

    case "LOAD":
      return action.state;

    case "CREATE_HERO": {
      const hero = createHero(action.name, action.roleId);
      const starterWeapon: Record<RoleId, string> = {
        warrior: "rusty_sword",
        mage: "apprentice_staff",
        rogue: "shadow_dagger",
        cleric: "rusty_sword",
      };
      // Rogue/mage starters are strong; they begin with the humble rusty sword too.
      const weapon = action.roleId === "warrior" || action.roleId === "cleric" ? starterWeapon[action.roleId] : "rusty_sword";
      let inventory: Record<string, number> = {};
      inventory = addItem(inventory, "potion_hp", 2);
      inventory = addItem(inventory, "bread", 2);
      inventory = addItem(inventory, "cheese_wheel", 1);
      return {
        ...initialState,
        screen: "hub",
        hero,
        gold: 30,
        inventory,
        equipped: { weapon },
      };
    }

    case "ENTER_LEVEL": {
      if (!state.hero || action.level > state.unlockedLevel) return state;
      if (carriedWeight(state.inventory) > carryCapacity(state.hero)) return state;
      const dungeon = getLevel(action.level);
      const monster = spawnMonster(dungeon.encounters[0]);
      return {
        ...state,
        screen: "battle",
        inventoryOpen: false,
        shopOpen: false,
        battle: {
          dungeonLevel: action.level,
          encounterIndex: 0,
          monster,
          phase: "player",
          log: [`You enter ${dungeon.name}.`, `A ${monster.name} blocks your path!`],
          heroEffects: [],
          monsterEffects: [],
        },
      };
    }

    case "ATTACK": {
      if (!state.hero || state.battle?.phase !== "player") return state;
      const next = structuredClone(state);
      const hero = next.hero!;
      const battle = next.battle!;
      if (heroStunGate(next, hero, battle.log)) return next;
      const dmg = heroAttackDamage(hero, next.equipped, battle.monster);
      battle.monster.hp = Math.max(0, battle.monster.hp - dmg);
      battle.log.push(`You strike ${battle.monster.name} for ${dmg} damage.`);
      if (battle.monster.hp <= 0) onMonsterDefeated(next, hero, battle.log);
      else monsterTurn(next, hero, battle.log);
      return next;
    }

    case "SKILL": {
      if (!state.hero || state.battle?.phase !== "player") return state;
      const skill = ROLES[state.hero.roleId].skills[action.skillIndex];
      if (!skill || state.hero.level < skill.unlockLevel) return state;
      if (state.hero.mp < skill.mpCost) return state;
      if (skill.hpCost && state.hero.hp <= skill.hpCost) return state;
      const next = structuredClone(state);
      const hero = next.hero!;
      const battle = next.battle!;
      if (heroStunGate(next, hero, battle.log)) return next;
      hero.mp -= skill.mpCost;
      if (skill.hpCost) hero.hp -= skill.hpCost;
      if (skill.kind === "heal") {
        const amount = heroSkillPower(hero, skill);
        hero.hp = Math.min(hero.stats.maxHp, hero.hp + amount);
        battle.log.push(`${skill.name} restores ${amount} HP.`);
        if (skill.cleanse && battle.heroEffects.length > 0) {
          battle.heroEffects = [];
          battle.log.push("All ailments are purged!");
        }
        monsterTurn(next, hero, battle.log);
      } else {
        const dmg = heroSkillDamage(hero, skill, battle.monster);
        battle.monster.hp = Math.max(0, battle.monster.hp - dmg);
        battle.log.push(`${skill.name} hits ${battle.monster.name} for ${dmg} damage!`);
        if (battle.monster.hp <= 0) {
          onMonsterDefeated(next, hero, battle.log);
        } else {
          const inflicted = rollInfliction(battle.monsterEffects, skill.inflicts);
          if (inflicted.applied) {
            battle.monsterEffects = inflicted.effects;
            battle.log.push(`${battle.monster.name} is afflicted by ${skill.inflicts!.kind}!`);
          }
          monsterTurn(next, hero, battle.log);
        }
      }
      return next;
    }

    case "FLEE": {
      if (!state.hero || state.battle?.phase !== "player") return state;
      const next = structuredClone(state);
      const hero = next.hero!;
      const battle = next.battle!;
      if (heroStunGate(next, hero, battle.log)) return next;
      if (Math.random() < fleeChance(hero)) {
        next.screen = "hub";
        next.battle = null;
        return next;
      }
      battle.log.push("You fail to escape!");
      monsterTurn(next, hero, battle.log);
      return next;
    }

    case "USE_ITEM": {
      if (!state.hero) return state;
      const item = getItem(action.itemId);
      if ((state.inventory[action.itemId] ?? 0) <= 0) return state;
      if (!item.restoreHp && !item.restoreMp) return state;
      const inBattle = state.screen === "battle" && state.battle?.phase === "player";
      if (state.screen === "battle" && !inBattle) return state;
      const next = structuredClone(state);
      const hero = next.hero!;
      // A stunned hero fumbles the bag: the turn is lost but nothing is consumed.
      if (inBattle && heroStunGate(next, hero, next.battle!.log)) {
        next.inventoryOpen = false;
        return next;
      }
      next.inventory = removeItem(next.inventory, action.itemId);
      const parts: string[] = [];
      if (item.restoreHp) {
        const healed = Math.min(hero.stats.maxHp, hero.hp + item.restoreHp) - hero.hp;
        hero.hp += healed;
        parts.push(`${healed} HP`);
      }
      if (item.restoreMp) {
        const restored = Math.min(hero.stats.maxMp, hero.mp + item.restoreMp) - hero.mp;
        hero.mp += restored;
        parts.push(`${restored} MP`);
      }
      if (inBattle) {
        const battle = next.battle!;
        battle.log.push(`You use ${item.name}. Restored ${parts.join(", ")}.`);
        next.inventoryOpen = false;
        monsterTurn(next, hero, battle.log);
      }
      return next;
    }

    case "EQUIP": {
      const item = getItem(action.itemId);
      if (!item.slot || (state.inventory[action.itemId] ?? 0) <= 0) return state;
      const next = structuredClone(state);
      const current = next.equipped[item.slot];
      next.inventory = removeItem(next.inventory, action.itemId);
      if (current) next.inventory = addItem(next.inventory, current);
      next.equipped[item.slot] = action.itemId;
      return next;
    }

    case "UNEQUIP": {
      const current = state.equipped[action.slot];
      if (!current) return state;
      const next = structuredClone(state);
      delete next.equipped[action.slot];
      next.inventory = addItem(next.inventory, current);
      return next;
    }

    case "DROP": {
      if ((state.inventory[action.itemId] ?? 0) <= 0) return state;
      return { ...state, inventory: removeItem(state.inventory, action.itemId) };
    }

    case "TOGGLE_INVENTORY":
      return { ...state, inventoryOpen: !state.inventoryOpen };

    case "TOGGLE_SHOP": {
      if (state.screen !== "hub") return state;
      return { ...state, shopOpen: !state.shopOpen };
    }

    case "BUY_ITEM": {
      if (!state.shopOpen) return state;
      const item = getItem(action.itemId);
      if (!shopStock(state.unlockedLevel).some((stocked) => stocked.id === item.id)) return state;
      const price = buyPrice(item);
      if (state.gold < price) return state;
      return { ...state, gold: state.gold - price, inventory: addItem(state.inventory, item.id) };
    }

    case "SELL_ITEM": {
      if (!state.shopOpen || (state.inventory[action.itemId] ?? 0) <= 0) return state;
      const item = getItem(action.itemId);
      return { ...state, gold: state.gold + sellPrice(item), inventory: removeItem(state.inventory, item.id) };
    }

    case "NEXT_ENCOUNTER": {
      if (!state.hero || state.battle?.phase !== "won") return state;
      const next = structuredClone(state);
      const battle = next.battle!;
      const dungeon = getLevel(battle.dungeonLevel);
      battle.encounterIndex += 1;
      battle.monster = spawnMonster(dungeon.encounters[battle.encounterIndex]);
      battle.phase = "player";
      battle.heroEffects = [];
      battle.monsterEffects = [];
      battle.log.push(`A ${battle.monster.name} appears!`);
      return next;
    }

    case "COLLECT_AND_RETURN": {
      if (!state.hero || state.battle?.phase !== "cleared") return state;
      const next = structuredClone(state);
      const battle = next.battle!;
      const dungeon = getLevel(battle.dungeonLevel);
      const firstClear = !next.clearedLevels.includes(dungeon.level);
      if (firstClear) {
        next.clearedLevels.push(dungeon.level);
        next.gold += dungeon.rewardGold;
        for (const id of dungeon.rewardItemIds) next.inventory = addItem(next.inventory, id);
        next.unlockedLevel = Math.max(next.unlockedLevel, Math.min(dungeon.level + 1, LEVELS.length));
      }
      next.battle = null;
      next.screen = dungeon.level === LEVELS.length && firstClear ? "victory" : "hub";
      return next;
    }

    case "REST": {
      if (!state.hero || state.gold < REST_COST) return state;
      const next = structuredClone(state);
      next.gold -= REST_COST;
      next.hero!.hp = next.hero!.stats.maxHp;
      next.hero!.mp = next.hero!.stats.maxMp;
      return next;
    }

    case "RETURN_TO_HUB": {
      if (!state.hero) return state;
      const next = structuredClone(state);
      // Defeat is forgiving: you wake up in town at full health, purse intact.
      if (next.battle?.phase === "lost") {
        next.hero!.hp = next.hero!.stats.maxHp;
        next.hero!.mp = next.hero!.stats.maxMp;
      }
      next.battle = null;
      next.screen = "hub";
      return next;
    }

    case "ENTER_WORLD": {
      const map = getMap(action.mapId);
      return {
        ...state,
        screen: "world",
        inventoryOpen: false,
        shopOpen: false,
        world: { mapId: map.id, x: map.spawn.x, y: map.spawn.y, facing: "down" },
      };
    }

    case "EXIT_WORLD": {
      if (state.screen !== "world") return state;
      return { ...state, screen: state.hero ? "hub" : "title", world: null };
    }

    case "MOVE": {
      if (state.screen !== "world" || !state.world) return state;
      const map = getMap(state.world.mapId);
      const { dx, dy } = DIRECTION_DELTAS[action.direction];
      const x = state.world.x + dx;
      const y = state.world.y + dy;
      // Bumping into something still turns the hero toward it.
      if (!isWalkable(map, x, y)) {
        return { ...state, world: { ...state.world, facing: action.direction } };
      }
      const portal = portalAt(map, x, y);
      if (portal) {
        if (portal.to.kind === "exit") {
          return { ...state, screen: state.hero ? "hub" : "title", world: null };
        }
        const target = getMap(portal.to.mapId);
        return {
          ...state,
          world: { mapId: target.id, x: portal.to.x, y: portal.to.y, facing: action.direction },
        };
      }
      return { ...state, world: { ...state.world, x, y, facing: action.direction } };
    }

    default:
      return state;
  }
}
