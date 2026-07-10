import { applyLevelUps, carriedWeight, carryCapacity, createHero } from "../game/character";
import {
  fleeChance,
  heroAttackDamage,
  heroSkillDamage,
  heroSkillPower,
  monsterAttackDamage,
  spawnMonster,
} from "../game/combat";
import { getItem } from "../game/items";
import { getLevel, LEVELS } from "../game/levels";
import { ROLES } from "../game/roles";
import type { EquipSlot, GameState, Hero, RoleId } from "../game/types";

export const REST_COST = 10;

export type Action =
  | { type: "NEW_GAME" }
  | { type: "LOAD"; state: GameState }
  | { type: "CREATE_HERO"; name: string; roleId: RoleId }
  | { type: "ENTER_LEVEL"; level: number }
  | { type: "ATTACK" }
  | { type: "SKILL" }
  | { type: "FLEE" }
  | { type: "USE_ITEM"; itemId: string }
  | { type: "EQUIP"; itemId: string }
  | { type: "UNEQUIP"; slot: EquipSlot }
  | { type: "DROP"; itemId: string }
  | { type: "TOGGLE_INVENTORY" }
  | { type: "NEXT_ENCOUNTER" }
  | { type: "COLLECT_AND_RETURN" }
  | { type: "REST" }
  | { type: "RETURN_TO_HUB" };

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

/** Monster retaliation + death check. Mutates the given draft slices. */
function monsterTurn(state: GameState, hero: Hero, log: string[]): void {
  const battle = state.battle!;
  if (battle.monster.hp <= 0) return;
  const dmg = monsterAttackDamage(battle.monster, hero, state.equipped);
  hero.hp = Math.max(0, hero.hp - dmg);
  log.push(`${battle.monster.name} hits you for ${dmg} damage.`);
  if (hero.hp <= 0) {
    battle.phase = "lost";
    log.push("You collapse. Everything goes dark...");
  }
}

function onMonsterDefeated(state: GameState, hero: Hero, log: string[]): void {
  const battle = state.battle!;
  const { xp, gold, name } = battle.monster;
  log.push(`${name} is defeated! +${xp} XP, +${gold} gold.`);
  hero.xp += xp;
  state.gold += gold;
  const gained = applyLevelUps(hero);
  if (gained > 0) log.push(`LEVEL UP! You are now level ${hero.level}. Fully restored.`);

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
        battle: {
          dungeonLevel: action.level,
          encounterIndex: 0,
          monster,
          phase: "player",
          log: [`You enter ${dungeon.name}.`, `A ${monster.name} blocks your path!`],
        },
      };
    }

    case "ATTACK": {
      if (!state.hero || state.battle?.phase !== "player") return state;
      const next = structuredClone(state);
      const hero = next.hero!;
      const battle = next.battle!;
      const dmg = heroAttackDamage(hero, next.equipped, battle.monster);
      battle.monster.hp = Math.max(0, battle.monster.hp - dmg);
      battle.log.push(`You strike ${battle.monster.name} for ${dmg} damage.`);
      if (battle.monster.hp <= 0) onMonsterDefeated(next, hero, battle.log);
      else monsterTurn(next, hero, battle.log);
      return next;
    }

    case "SKILL": {
      if (!state.hero || state.battle?.phase !== "player") return state;
      const skill = ROLES[state.hero.roleId].skill;
      if (state.hero.mp < skill.mpCost) return state;
      const next = structuredClone(state);
      const hero = next.hero!;
      const battle = next.battle!;
      hero.mp -= skill.mpCost;
      if (skill.kind === "heal") {
        const amount = heroSkillPower(hero);
        hero.hp = Math.min(hero.stats.maxHp, hero.hp + amount);
        battle.log.push(`${skill.name} restores ${amount} HP.`);
        monsterTurn(next, hero, battle.log);
      } else {
        const dmg = heroSkillDamage(hero, battle.monster);
        battle.monster.hp = Math.max(0, battle.monster.hp - dmg);
        battle.log.push(`${skill.name} hits ${battle.monster.name} for ${dmg} damage!`);
        if (battle.monster.hp <= 0) onMonsterDefeated(next, hero, battle.log);
        else monsterTurn(next, hero, battle.log);
      }
      return next;
    }

    case "FLEE": {
      if (!state.hero || state.battle?.phase !== "player") return state;
      const next = structuredClone(state);
      const hero = next.hero!;
      const battle = next.battle!;
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

    case "NEXT_ENCOUNTER": {
      if (!state.hero || state.battle?.phase !== "won") return state;
      const next = structuredClone(state);
      const battle = next.battle!;
      const dungeon = getLevel(battle.dungeonLevel);
      battle.encounterIndex += 1;
      battle.monster = spawnMonster(dungeon.encounters[battle.encounterIndex]);
      battle.phase = "player";
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

    default:
      return state;
  }
}
