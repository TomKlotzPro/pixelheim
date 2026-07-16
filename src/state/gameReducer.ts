import {
  advanceEncounter,
  createDungeonBattle,
  createWildBattle,
  grantFloorRewards,
  heroAttack,
  heroFlee,
  heroSkill,
  heroStunGate,
  monsterTurn,
} from "../game/battleEngine";
import { carriedWeight, carryCapacity, createHero, gearByUid } from "../game/character";
import { createGear, gearItem, gearValue } from "../game/rarity";
import { rollWildEncounter } from "../game/encounters";
import { addItem, removeItem } from "../game/inventory";
import { getItem } from "../game/items";
import { getLevel, LEVELS } from "../game/levels";
import { buyPrice, FORGE_BONUS_CAP, forgeCost, sellPriceAt, SHOP_MAPS, SHOPS, shopStock } from "../game/shop";
import type { EquipSlot, GameState, RoleId, SpendableStat } from "../game/types";
import { canCraft, RECIPES } from "../game/recipes";
import { canBuyNode, getHeroSkills, getNode } from "../game/skillTree";
import { discoverAround } from "../world/discover";
import { getMap } from "../world/maps";
import { npcAt, NPCS } from "../world/npcs";
import { isWalkable, portalAt, regionAt, tileAt } from "../world/parseMap";
import type { Direction, TileId } from "../world/types";

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
  | { type: "EQUIP"; uid: string }
  | { type: "UNEQUIP"; slot: EquipSlot }
  | { type: "DROP"; itemId: string }
  | { type: "DROP_GEAR"; uid: string }
  | { type: "SELL_GEAR"; uid: string }
  | { type: "TOGGLE_INVENTORY" }
  | { type: "TOGGLE_SHOP" }
  | { type: "BUY_ITEM"; itemId: string }
  | { type: "SELL_ITEM"; itemId: string }
  | { type: "NEXT_ENCOUNTER" }
  | { type: "COLLECT_AND_RETURN" }
  | { type: "RETURN_TO_WORLD" }
  | { type: "ENTER_WORLD"; mapId: string }
  | { type: "EXIT_WORLD" }
  | { type: "MOVE"; direction: Direction }
  | { type: "CLOSE_DUNGEON_SELECT" }
  | { type: "DISMISS_INTRO" }
  | { type: "INTERACT" }
  | { type: "ADVANCE_DIALOGUE" }
  | { type: "SPEND_STAT_POINT"; stat: SpendableStat }
  | { type: "BUY_SKILL_NODE"; nodeId: string }
  | { type: "CRAFT"; recipeId: string }
  | { type: "UPGRADE_GEAR"; uid: string };

/** The shop whose building the hero is standing in, if any. */
export function activeShopId(state: GameState) {
  return state.world ? (SHOP_MAPS[state.world.position.mapId] ?? null) : null;
}

export const initialState: GameState = {
  screen: "title",
  hero: null,
  gold: 0,
  inventory: {},
  gear: [],
  equipped: {},
  unlockedLevel: 1,
  clearedLevels: [],
  battle: null,
  inventoryOpen: false,
  shopOpen: false,
  world: null,
  dungeonSelect: null,
  introSeen: true,
  worldMessage: null,
  worldSteps: 0,
  dialogue: null,
};

/** Where heroes wake up: the middle of Pixelheim village. */
export const TOWN_SPAWN = { mapId: "town", x: 14, y: 15, facing: "down" as const };
const INN_REST = { mapId: "town", x: 12, y: 5, facing: "down" as const };

const DIRECTION_DELTAS: Record<Direction, { dx: number; dy: number }> = {
  up: { dx: 0, dy: -1 },
  down: { dx: 0, dy: 1 },
  left: { dx: -1, dy: 0 },
  right: { dx: 1, dy: 0 },
};

/** Terrain that can hide monsters; paths, bridges and buildings are safe. */
const WILD_TILES = new Set<TileId>(["grass", "forest", "marsh", "ash", "sand"]);

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
      const weaponId =
        action.roleId === "warrior" || action.roleId === "cleric" ? starterWeapon[action.roleId] : "rusty_sword";
      const weapon = createGear(weaponId);
      let inventory: Record<string, number> = {};
      inventory = addItem(inventory, "potion_hp", 2);
      inventory = addItem(inventory, "bread", 2);
      inventory = addItem(inventory, "cheese_wheel", 1);
      const town = getMap(TOWN_SPAWN.mapId);
      return {
        ...initialState,
        screen: "world",
        hero,
        gold: 30,
        inventory,
        gear: [weapon],
        equipped: { weapon: weapon.uid },
        introSeen: false,
        world: {
          position: { ...TOWN_SPAWN },
          discovered: discoverAround({}, town, TOWN_SPAWN.x, TOWN_SPAWN.y),
          openedChests: [],
        },
      };
    }

    case "ENTER_LEVEL": {
      if (!state.hero || action.level > state.unlockedLevel) return state;
      if (carriedWeight(state.inventory, state.gear, state.equipped) > carryCapacity(state.hero)) return state;
      return {
        ...state,
        screen: "battle",
        inventoryOpen: false,
        shopOpen: false,
        battle: createDungeonBattle(action.level),
      };
    }

    case "ATTACK": {
      if (!state.hero || state.battle?.phase !== "player") return state;
      const next = structuredClone(state);
      heroAttack(next);
      return next;
    }

    case "SKILL": {
      if (!state.hero || state.battle?.phase !== "player") return state;
      const skill = getHeroSkills(state.hero)[action.skillIndex];
      if (!skill) return state;
      if (state.hero.mp < skill.mpCost) return state;
      if (skill.hpCost && state.hero.hp <= skill.hpCost) return state;
      const next = structuredClone(state);
      heroSkill(next, action.skillIndex);
      return next;
    }

    case "FLEE": {
      if (!state.hero || state.battle?.phase !== "player") return state;
      const next = structuredClone(state);
      heroFlee(next);
      return next;
    }

    case "USE_ITEM": {
      if (!state.hero) return state;
      const item = getItem(action.itemId);
      if ((state.inventory[action.itemId] ?? 0) <= 0) return state;
      if (!item.restoreHp && !item.restoreMp && !item.cures) return state;
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
        if (item.cures && battle.heroEffects.some((e) => e.kind === item.cures)) {
          battle.heroEffects = battle.heroEffects.filter((e) => e.kind !== item.cures);
          parts.push(`cured ${item.cures}`);
        }
        battle.log.push(`You use ${item.name}. ${parts.length ? `Restored ${parts.join(", ")}.` : "Nothing happens."}`);
        next.inventoryOpen = false;
        monsterTurn(next, hero, battle.log);
      }
      return next;
    }

    case "EQUIP": {
      const instance = gearByUid(state.gear, action.uid);
      if (!instance) return state;
      const slot = gearItem(instance).slot;
      if (!slot) return state;
      const next = structuredClone(state);
      next.equipped[slot] = action.uid;
      return next;
    }

    case "UNEQUIP": {
      if (!state.equipped[action.slot]) return state;
      const next = structuredClone(state);
      delete next.equipped[action.slot];
      return next;
    }

    case "DROP": {
      if ((state.inventory[action.itemId] ?? 0) <= 0) return state;
      return { ...state, inventory: removeItem(state.inventory, action.itemId) };
    }

    case "DROP_GEAR": {
      if (Object.values(state.equipped).includes(action.uid)) return state;
      if (!gearByUid(state.gear, action.uid)) return state;
      return { ...state, gear: state.gear.filter((g) => g.uid !== action.uid) };
    }

    case "SELL_GEAR": {
      const shopId = state.shopOpen ? activeShopId(state) : null;
      if (!shopId || Object.values(state.equipped).includes(action.uid)) return state;
      const instance = gearByUid(state.gear, action.uid);
      if (!instance) return state;
      const rate = SHOPS[shopId].buyRates[gearItem(instance).category] ?? 0.5;
      return {
        ...state,
        gold: state.gold + Math.max(1, Math.floor(gearValue(instance) * rate)),
        gear: state.gear.filter((g) => g.uid !== action.uid),
      };
    }

    case "TOGGLE_INVENTORY":
      return { ...state, inventoryOpen: !state.inventoryOpen };

    case "TOGGLE_SHOP": {
      // Shops live inside their keepers' buildings.
      if (state.screen !== "world" || !activeShopId(state)) return state;
      return { ...state, shopOpen: !state.shopOpen };
    }

    case "BUY_ITEM": {
      const shopId = state.shopOpen ? activeShopId(state) : null;
      if (!shopId) return state;
      const item = getItem(action.itemId);
      if (!shopStock(shopId, state.unlockedLevel).some((stocked) => stocked.id === item.id)) return state;
      const price = buyPrice(item);
      if (state.gold < price) return state;
      // Shops sell honest common gear; the exciting rolls come from monsters.
      if (item.slot) {
        return { ...state, gold: state.gold - price, gear: [...state.gear, createGear(item.id)] };
      }
      return { ...state, gold: state.gold - price, inventory: addItem(state.inventory, item.id) };
    }

    case "SELL_ITEM": {
      const shopId = state.shopOpen ? activeShopId(state) : null;
      if (!shopId || (state.inventory[action.itemId] ?? 0) <= 0) return state;
      const item = getItem(action.itemId);
      return { ...state, gold: state.gold + sellPriceAt(shopId, item), inventory: removeItem(state.inventory, item.id) };
    }

    case "UPGRADE_GEAR": {
      const shopId = state.shopOpen ? activeShopId(state) : null;
      if (!shopId || !SHOPS[shopId].forge) return state;
      const instance = gearByUid(state.gear, action.uid);
      if (!instance || instance.bonus >= FORGE_BONUS_CAP) return state;
      const cost = forgeCost(gearItem(instance), instance.bonus);
      if (state.gold < cost) return state;
      return {
        ...state,
        gold: state.gold - cost,
        gear: state.gear.map((g) => (g.uid === action.uid ? { ...g, bonus: g.bonus + 1 } : g)),
      };
    }

    case "NEXT_ENCOUNTER": {
      if (!state.hero || state.battle?.phase !== "won") return state;
      const next = structuredClone(state);
      advanceEncounter(next);
      return next;
    }

    case "COLLECT_AND_RETURN": {
      if (!state.hero || state.battle?.phase !== "cleared") return state;
      const next = structuredClone(state);
      const battle = next.battle!;
      // Wild battles have no floor rewards; the hero walks on from the same tile.
      if (battle.wild) {
        next.battle = null;
        next.screen = "world";
        return next;
      }
      const dungeon = getLevel(battle.dungeonLevel);
      const firstClear = !next.clearedLevels.includes(dungeon.level);
      if (firstClear) grantFloorRewards(next, dungeon.level);
      next.battle = null;
      // Clearing a floor steps you back out of the dungeon door.
      next.dungeonSelect = null;
      next.screen = dungeon.level === LEVELS.length && firstClear ? "victory" : "world";
      return next;
    }

    case "RETURN_TO_WORLD": {
      if (!state.hero || !state.world) return state;
      const next = structuredClone(state);
      const wasLost = next.battle?.phase === "lost";
      // Defeat is forgiving: you wake at the village inn, healed, purse intact.
      if (wasLost) {
        next.hero!.hp = next.hero!.stats.maxHp;
        next.hero!.mp = next.hero!.stats.maxMp;
        next.world!.position = { ...INN_REST };
        next.worldMessage = "You wake at the inn. The innkeeper says nothing. Kind of her.";
      }
      next.battle = null;
      next.dungeonSelect = null;
      next.screen = "world";
      return next;
    }

    case "ENTER_WORLD": {
      const map = getMap(action.mapId);
      const previous = state.world;
      // Re-entering the map you left resumes in place; otherwise spawn there.
      // Exploration memory always survives.
      const position =
        previous && previous.position.mapId === map.id
          ? previous.position
          : { mapId: map.id, x: map.spawn.x, y: map.spawn.y, facing: "down" as const };
      return {
        ...state,
        screen: "world",
        inventoryOpen: false,
        shopOpen: false,
        world: {
          position,
          discovered: discoverAround(previous?.discovered ?? {}, map, position.x, position.y),
          openedChests: previous?.openedChests ?? [],
        },
      };
    }

    case "EXIT_WORLD": {
      // Only the hero-less ?world demo can leave the world; it IS the game now.
      if (state.screen !== "world" || state.hero) return state;
      return { ...state, screen: "title" };
    }

    case "DISMISS_INTRO":
      return { ...state, introSeen: true };

    case "SPEND_STAT_POINT": {
      if (!state.hero || state.hero.statPoints <= 0) return state;
      const next = structuredClone(state);
      next.hero!.stats[action.stat] += 1;
      next.hero!.statPoints -= 1;
      return next;
    }

    case "CRAFT": {
      if (!state.hero) return state;
      const recipe = RECIPES.find((r) => r.id === action.recipeId);
      if (!recipe || !canCraft(recipe, state.inventory)) return state;
      let inventory = state.inventory;
      for (const [itemId, count] of Object.entries(recipe.needs)) {
        inventory = removeItem(inventory, itemId, count);
      }
      inventory = addItem(inventory, recipe.itemId);
      return { ...state, inventory };
    }

    case "BUY_SKILL_NODE": {
      if (!state.hero) return state;
      const node = getNode(state.hero.roleId, action.nodeId);
      if (!node || !canBuyNode(state.hero, node)) return state;
      const next = structuredClone(state);
      const hero = next.hero!;
      hero.skillNodes.push(node.id);
      hero.skillPoints -= 1;
      if (node.grantStats?.maxHp) {
        hero.stats.maxHp += node.grantStats.maxHp;
        hero.hp += node.grantStats.maxHp;
      }
      if (node.grantStats?.maxMp) {
        hero.stats.maxMp += node.grantStats.maxMp;
        hero.mp += node.grantStats.maxMp;
      }
      return next;
    }

    case "CLOSE_DUNGEON_SELECT": {
      if (state.screen !== "dungeon_select") return state;
      return { ...state, screen: "world", dungeonSelect: null };
    }

    case "INTERACT": {
      if (state.screen !== "world" || !state.world || !state.hero) return state;
      if (state.dialogue) return gameReducer(state, { type: "ADVANCE_DIALOGUE" });
      const { position } = state.world;
      const { dx, dy } = DIRECTION_DELTAS[position.facing];
      const npc = npcAt(position.mapId, position.x + dx, position.y + dy, state.worldSteps);
      if (!npc) return state;
      return { ...state, dialogue: { npcId: npc.id, page: 0 }, worldMessage: null };
    }

    case "ADVANCE_DIALOGUE": {
      if (!state.dialogue) return state;
      const npc = NPCS.find((n) => n.id === state.dialogue!.npcId);
      if (!npc || state.dialogue.page >= npc.lines.length - 1) return { ...state, dialogue: null };
      return { ...state, dialogue: { ...state.dialogue, page: state.dialogue.page + 1 } };
    }

    case "MOVE": {
      if (state.screen !== "world" || !state.world) return state;
      if (state.dialogue) return state;
      const { position } = state.world;
      const map = getMap(position.mapId);
      const { dx, dy } = DIRECTION_DELTAS[action.direction];
      const x = position.x + dx;
      const y = position.y + dy;
      // Bumping into something (or someone) still turns the hero toward it.
      if (!isWalkable(map, x, y) || npcAt(map.id, x, y, state.worldSteps)) {
        return { ...state, world: { ...state.world, position: { ...position, facing: action.direction } } };
      }
      const portal = portalAt(map, x, y);
      if (portal && portal.to.kind === "map") {
        const target = getMap(portal.to.mapId);
        const through: GameState = {
          ...state,
          worldMessage: null,
          world: {
            ...state.world,
            position: { mapId: target.id, x: portal.to.x, y: portal.to.y, facing: action.direction },
            discovered: discoverAround(state.world.discovered, target, portal.to.x, portal.to.y),
          },
        };
        // Entering a keeper's building opens their counter.
        if (SHOP_MAPS[target.id] && state.hero) return { ...through, shopOpen: true };
        // Entering the inn rests the hero, for the usual price.
        if (target.id === "town_inn" && state.hero) {
          const hero = state.hero;
          if (hero.hp === hero.stats.maxHp && hero.mp === hero.stats.maxMp) {
            return { ...through, worldMessage: "The innkeeper nods. You are already well rested." };
          }
          if (state.gold < REST_COST) {
            return { ...through, worldMessage: `No coin, no bed. (Rest costs ${REST_COST}g.)` };
          }
          return {
            ...through,
            gold: state.gold - REST_COST,
            hero: { ...hero, hp: hero.stats.maxHp, mp: hero.stats.maxMp },
            worldMessage: `You rest at the inn. Fully restored. (-${REST_COST}g)`,
          };
        }
        return through;
      }
      if (portal && portal.to.kind === "exit") {
        return state.hero ? state : { ...state, screen: "title" };
      }
      // Dungeon entrances open the floor select; the hero stays at the door.
      if (portal && portal.to.kind === "dungeon") {
        if (!state.hero) return state;
        return {
          ...state,
          screen: "dungeon_select",
          dungeonSelect: portal.to.dungeon,
          world: { ...state.world, position: { ...position, facing: action.direction } },
        };
      }
      const moved: GameState = {
        ...state,
        worldMessage: null,
        worldSteps: state.worldSteps + 1,
        world: {
          ...state.world,
          position: { ...position, x, y, facing: action.direction },
          discovered: discoverAround(state.world.discovered, map, x, y),
        },
      };

      // The wilds bite: stepping on wild terrain in a monster region can
      // start a battle. The world position stays, so winning or fleeing
      // drops the hero back on this exact tile.
      const region = regionAt(map, x, y);
      const tile = tileAt(map, x, y);
      if (state.hero && region && tile && WILD_TILES.has(tile)) {
        const encounter = rollWildEncounter(region);
        if (encounter) {
          return { ...moved, screen: "battle", battle: createWildBattle(encounter) };
        }
      }
      return moved;
    }

    default:
      return state;
  }
}
