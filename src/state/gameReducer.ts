import { produce } from "immer";
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

/**
 * The pure game loop: state in, state out. Immer turns the mutation-style
 * cases below into an immutable update with structural sharing, so unchanged
 * branches keep their identity (and a no-op case returns the same state).
 */
export function gameReducer(state: GameState, action: Action): GameState {
  return produce(state, (draft) => applyAction(draft as GameState, action));
}

/** One action against a draft: either mutate it, or return a replacement state. */
function applyAction(draft: GameState, action: Action): GameState | void {
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
      if (!draft.hero || action.level > draft.unlockedLevel) return;
      if (carriedWeight(draft.inventory, draft.gear, draft.equipped) > carryCapacity(draft.hero)) return;
      draft.screen = "battle";
      draft.inventoryOpen = false;
      draft.shopOpen = false;
      draft.battle = createDungeonBattle(action.level);
      return;
    }

    case "ATTACK": {
      if (!draft.hero || draft.battle?.phase !== "player") return;
      heroAttack(draft);
      return;
    }

    case "SKILL": {
      if (!draft.hero || draft.battle?.phase !== "player") return;
      const skill = getHeroSkills(draft.hero)[action.skillIndex];
      if (!skill) return;
      if (draft.hero.mp < skill.mpCost) return;
      if (skill.hpCost && draft.hero.hp <= skill.hpCost) return;
      heroSkill(draft, action.skillIndex);
      return;
    }

    case "FLEE": {
      if (!draft.hero || draft.battle?.phase !== "player") return;
      heroFlee(draft);
      return;
    }

    case "USE_ITEM": {
      if (!draft.hero) return;
      const item = getItem(action.itemId);
      if ((draft.inventory[action.itemId] ?? 0) <= 0) return;
      if (!item.restoreHp && !item.restoreMp && !item.cures) return;
      const inBattle = draft.screen === "battle" && draft.battle?.phase === "player";
      if (draft.screen === "battle" && !inBattle) return;
      const hero = draft.hero;
      // A stunned hero fumbles the bag: the turn is lost but nothing is consumed.
      if (inBattle && heroStunGate(draft, hero, draft.battle!.log)) {
        draft.inventoryOpen = false;
        return;
      }
      draft.inventory = removeItem(draft.inventory, action.itemId);
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
        const battle = draft.battle!;
        if (item.cures && battle.heroEffects.some((e) => e.kind === item.cures)) {
          battle.heroEffects = battle.heroEffects.filter((e) => e.kind !== item.cures);
          parts.push(`cured ${item.cures}`);
        }
        battle.log.push(`You use ${item.name}. ${parts.length ? `Restored ${parts.join(", ")}.` : "Nothing happens."}`);
        draft.inventoryOpen = false;
        monsterTurn(draft, hero, battle.log);
      }
      return;
    }

    case "EQUIP": {
      const instance = gearByUid(draft.gear, action.uid);
      if (!instance) return;
      const slot = gearItem(instance).slot;
      if (!slot) return;
      draft.equipped[slot] = action.uid;
      return;
    }

    case "UNEQUIP": {
      if (!draft.equipped[action.slot]) return;
      delete draft.equipped[action.slot];
      return;
    }

    case "DROP": {
      if ((draft.inventory[action.itemId] ?? 0) <= 0) return;
      draft.inventory = removeItem(draft.inventory, action.itemId);
      return;
    }

    case "DROP_GEAR": {
      if (Object.values(draft.equipped).includes(action.uid)) return;
      if (!gearByUid(draft.gear, action.uid)) return;
      draft.gear = draft.gear.filter((g) => g.uid !== action.uid);
      return;
    }

    case "SELL_GEAR": {
      const shopId = draft.shopOpen ? activeShopId(draft) : null;
      if (!shopId || Object.values(draft.equipped).includes(action.uid)) return;
      const instance = gearByUid(draft.gear, action.uid);
      if (!instance) return;
      const rate = SHOPS[shopId].buyRates[gearItem(instance).category] ?? 0.5;
      draft.gold += Math.max(1, Math.floor(gearValue(instance) * rate));
      draft.gear = draft.gear.filter((g) => g.uid !== action.uid);
      return;
    }

    case "TOGGLE_INVENTORY": {
      draft.inventoryOpen = !draft.inventoryOpen;
      return;
    }

    case "TOGGLE_SHOP": {
      // Shops live inside their keepers' buildings.
      if (draft.screen !== "world" || !activeShopId(draft)) return;
      draft.shopOpen = !draft.shopOpen;
      return;
    }

    case "BUY_ITEM": {
      const shopId = draft.shopOpen ? activeShopId(draft) : null;
      if (!shopId) return;
      const item = getItem(action.itemId);
      if (!shopStock(shopId, draft.unlockedLevel).some((stocked) => stocked.id === item.id)) return;
      const price = buyPrice(item);
      if (draft.gold < price) return;
      draft.gold -= price;
      // Shops sell honest common gear; the exciting rolls come from monsters.
      if (item.slot) draft.gear.push(createGear(item.id));
      else draft.inventory = addItem(draft.inventory, item.id);
      return;
    }

    case "SELL_ITEM": {
      const shopId = draft.shopOpen ? activeShopId(draft) : null;
      if (!shopId || (draft.inventory[action.itemId] ?? 0) <= 0) return;
      const item = getItem(action.itemId);
      draft.gold += sellPriceAt(shopId, item);
      draft.inventory = removeItem(draft.inventory, item.id);
      return;
    }

    case "UPGRADE_GEAR": {
      const shopId = draft.shopOpen ? activeShopId(draft) : null;
      if (!shopId || !SHOPS[shopId].forge) return;
      const instance = gearByUid(draft.gear, action.uid);
      if (!instance || instance.bonus >= FORGE_BONUS_CAP) return;
      const cost = forgeCost(gearItem(instance), instance.bonus);
      if (draft.gold < cost) return;
      draft.gold -= cost;
      instance.bonus += 1;
      return;
    }

    case "NEXT_ENCOUNTER": {
      if (!draft.hero || draft.battle?.phase !== "won") return;
      advanceEncounter(draft);
      return;
    }

    case "COLLECT_AND_RETURN": {
      if (!draft.hero || draft.battle?.phase !== "cleared") return;
      const battle = draft.battle;
      // Wild battles have no floor rewards; the hero walks on from the same tile.
      if (battle.wild) {
        draft.battle = null;
        draft.screen = "world";
        return;
      }
      const dungeon = getLevel(battle.dungeonLevel);
      const firstClear = !draft.clearedLevels.includes(dungeon.level);
      if (firstClear) grantFloorRewards(draft, dungeon.level);
      draft.battle = null;
      // Clearing a floor steps you back out of the dungeon door.
      draft.dungeonSelect = null;
      draft.screen = dungeon.level === LEVELS.length && firstClear ? "victory" : "world";
      return;
    }

    case "RETURN_TO_WORLD": {
      if (!draft.hero || !draft.world) return;
      // Defeat is forgiving: you wake at the village inn, healed, purse intact.
      if (draft.battle?.phase === "lost") {
        draft.hero.hp = draft.hero.stats.maxHp;
        draft.hero.mp = draft.hero.stats.maxMp;
        draft.world.position = { ...INN_REST };
        draft.worldMessage = "You wake at the inn. The innkeeper says nothing. Kind of her.";
      }
      draft.battle = null;
      draft.dungeonSelect = null;
      draft.screen = "world";
      return;
    }

    case "ENTER_WORLD": {
      const map = getMap(action.mapId);
      const previous = draft.world;
      // Re-entering the map you left resumes in place; otherwise spawn there.
      // Exploration memory always survives.
      const position =
        previous && previous.position.mapId === map.id
          ? { ...previous.position }
          : { mapId: map.id, x: map.spawn.x, y: map.spawn.y, facing: "down" as const };
      draft.screen = "world";
      draft.inventoryOpen = false;
      draft.shopOpen = false;
      draft.world = {
        position,
        discovered: discoverAround(previous?.discovered ?? {}, map, position.x, position.y),
        openedChests: previous ? [...previous.openedChests] : [],
      };
      return;
    }

    case "EXIT_WORLD": {
      // Only the hero-less ?world demo can leave the world; it IS the game now.
      if (draft.screen !== "world" || draft.hero) return;
      draft.screen = "title";
      return;
    }

    case "DISMISS_INTRO": {
      draft.introSeen = true;
      return;
    }

    case "SPEND_STAT_POINT": {
      if (!draft.hero || draft.hero.statPoints <= 0) return;
      draft.hero.stats[action.stat] += 1;
      draft.hero.statPoints -= 1;
      return;
    }

    case "CRAFT": {
      if (!draft.hero) return;
      const recipe = RECIPES.find((r) => r.id === action.recipeId);
      if (!recipe || !canCraft(recipe, draft.inventory)) return;
      let inventory = draft.inventory;
      for (const [itemId, count] of Object.entries(recipe.needs)) {
        inventory = removeItem(inventory, itemId, count);
      }
      draft.inventory = addItem(inventory, recipe.itemId);
      return;
    }

    case "BUY_SKILL_NODE": {
      if (!draft.hero) return;
      const node = getNode(draft.hero.roleId, action.nodeId);
      if (!node || !canBuyNode(draft.hero, node)) return;
      const hero = draft.hero;
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
      return;
    }

    case "CLOSE_DUNGEON_SELECT": {
      if (draft.screen !== "dungeon_select") return;
      draft.screen = "world";
      draft.dungeonSelect = null;
      return;
    }

    case "INTERACT": {
      if (draft.screen !== "world" || !draft.world || !draft.hero) return;
      if (draft.dialogue) return applyAction(draft, { type: "ADVANCE_DIALOGUE" });
      const { position } = draft.world;
      const { dx, dy } = DIRECTION_DELTAS[position.facing];
      const npc = npcAt(position.mapId, position.x + dx, position.y + dy, draft.worldSteps);
      if (!npc) return;
      draft.dialogue = { npcId: npc.id, page: 0 };
      draft.worldMessage = null;
      return;
    }

    case "ADVANCE_DIALOGUE": {
      if (!draft.dialogue) return;
      const npc = NPCS.find((n) => n.id === draft.dialogue!.npcId);
      if (!npc || draft.dialogue.page >= npc.lines.length - 1) {
        draft.dialogue = null;
        return;
      }
      draft.dialogue.page += 1;
      return;
    }

    case "MOVE": {
      if (draft.screen !== "world" || !draft.world) return;
      if (draft.dialogue) return;
      const { position } = draft.world;
      const map = getMap(position.mapId);
      const { dx, dy } = DIRECTION_DELTAS[action.direction];
      const x = position.x + dx;
      const y = position.y + dy;
      // Bumping into something (or someone) still turns the hero toward it.
      if (!isWalkable(map, x, y) || npcAt(map.id, x, y, draft.worldSteps)) {
        position.facing = action.direction;
        return;
      }
      const portal = portalAt(map, x, y);
      if (portal && portal.to.kind === "map") {
        const target = getMap(portal.to.mapId);
        draft.worldMessage = null;
        draft.world.position = { mapId: target.id, x: portal.to.x, y: portal.to.y, facing: action.direction };
        draft.world.discovered = discoverAround(draft.world.discovered, target, portal.to.x, portal.to.y);
        // Entering a keeper's building opens their counter.
        if (SHOP_MAPS[target.id] && draft.hero) {
          draft.shopOpen = true;
          return;
        }
        // Entering the inn rests the hero, for the usual price.
        if (target.id === "town_inn" && draft.hero) {
          const hero = draft.hero;
          if (hero.hp === hero.stats.maxHp && hero.mp === hero.stats.maxMp) {
            draft.worldMessage = "The innkeeper nods. You are already well rested.";
          } else if (draft.gold < REST_COST) {
            draft.worldMessage = `No coin, no bed. (Rest costs ${REST_COST}g.)`;
          } else {
            draft.gold -= REST_COST;
            hero.hp = hero.stats.maxHp;
            hero.mp = hero.stats.maxMp;
            draft.worldMessage = `You rest at the inn. Fully restored. (-${REST_COST}g)`;
          }
        }
        return;
      }
      if (portal && portal.to.kind === "exit") {
        if (!draft.hero) draft.screen = "title";
        return;
      }
      // Dungeon entrances open the floor select; the hero stays at the door.
      if (portal && portal.to.kind === "dungeon") {
        if (!draft.hero) return;
        draft.screen = "dungeon_select";
        draft.dungeonSelect = portal.to.dungeon;
        position.facing = action.direction;
        return;
      }
      draft.worldMessage = null;
      draft.worldSteps += 1;
      draft.world.position = { mapId: position.mapId, x, y, facing: action.direction };
      draft.world.discovered = discoverAround(draft.world.discovered, map, x, y);

      // The wilds bite: stepping on wild terrain in a monster region can
      // start a battle. The world position stays, so winning or fleeing
      // drops the hero back on this exact tile.
      const region = regionAt(map, x, y);
      const tile = tileAt(map, x, y);
      if (draft.hero && region && tile && WILD_TILES.has(tile)) {
        const encounter = rollWildEncounter(region);
        if (encounter) {
          draft.screen = "battle";
          draft.battle = createWildBattle(encounter);
        }
      }
      return;
    }

    default:
      return;
  }
}
