import { createWildBattle } from "../../game/combat/battleEngine";
import { encounterForSpawn, spawnSpecies } from "../../game/combat/encounters";
import { applyLevelUps, carriedWeight, carryCapacity } from "../../game/hero/character";
import { getItem } from "../../game/economy/items";
import { createGear, gearName } from "../../game/economy/rarity";
import { SHOP_MAPS } from "../../game/economy/shop";
import type { GameState } from "../../game/types";
import { type Chest, chestAt, chestRegion, solidChestAt } from "../../world/chests";
import { discoverAround } from "../../world/discover";
import { getMap } from "../../world/maps/index";
import { npcAt, npcBeside, npcById } from "../../world/npcs";
import { isSettled, resolveSettler } from "../../game/settlers";
import { furnitureAt, furnitureBlocks, GARDEN_WINS_PER_YIELD } from "../../game/economy/house";
import { monsterSpawnAt, spawnRegion } from "../../world/spawns";
import { waypointUsable, WAYPOINTS } from "../../world/waypoints";
import { isWalkable, portalAt } from "../../world/parseMap";
import type { WorldAction } from "../actions";
import { DIRECTION_DELTAS, HOUSE_DEED_COST, HOUSE_DOOR, INN_MAP_ID, WORKBENCH_COST } from "../shared";
import { restCostFor, townTierOf } from "../../game/economy/town";
import { addItem, removeItem } from "../../game/economy/inventory";
import { questProgress, questReady, questsFor } from "../../game/quests";

/**
 * Everything E can touch inside the player's house (PIX-33/34/109): placed
 * furniture first, then the home tiles. Returns true when it handled the
 * interaction so INTERACT can fall through to NPCs otherwise.
 */
function handleHouseInteract(draft: GameState, tx: number, ty: number): boolean {
  if (!draft.world || !draft.hero || draft.world.position.mapId !== "town_house") return false;
  // Placed furniture comes back to the pack with a touch (PIX-34).
  const placed = furnitureAt(draft, "town_house", tx, ty);
  if (placed) {
    draft.house.furniture = (draft.house.furniture ?? []).filter((f) => f !== placed);
    draft.inventory = addItem(draft.inventory, placed.itemId);
    draft.worldMessage = `${getItem(placed.itemId).name} back in the pack.`;
    return true;
  }
  const homeTile = getMap("town_house").tiles[ty]?.[tx];
  switch (homeTile) {
    case "bed":
      draft.hero.hp = draft.hero.stats.maxHp;
      draft.hero.mp = draft.hero.stats.maxMp;
      draft.worldMessage = "Your own bed. Fully rested, free of charge.";
      return true;
    case "barrel":
      draft.openPanel = "storage";
      return true;
    // The shelf is where the workbench fits (PIX-109): E names the price,
    // pays it deed-style, and afterwards opens the pack to craft from.
    case "shelf":
      if (draft.house.workbench) {
        draft.openPanel = "inventory";
        draft.worldMessage = null;
      } else if (draft.gold >= WORKBENCH_COST) {
        draft.gold -= WORKBENCH_COST;
        draft.house.workbench = true;
        draft.worldMessage = "A workbench and a small cauldron, fitted to the shelf. Craft at home, forever.";
      } else {
        draft.worldMessage = `A proper workbench would fit this shelf. Tools and parts cost ${WORKBENCH_COST}g.`;
      }
      return true;
    // Every piece of furniture answers to E: silence reads as a bug.
    case "hearth":
      draft.worldMessage = draft.house.workbench
        ? "The hearth roars beside your workbench. Home industry."
        : "The hearth crackles, warm and idle. A workbench would fit by the shelf...";
      return true;
    case "counter":
      draft.worldMessage = "Your kitchen counter. Clean, empty, hopeful.";
      return true;
    // The cottage's shelf of honor (PIX-34): display trophies for buffs.
    case "trophy_shelf":
      draft.openPanel = "trophies";
      return true;
    // The manor garden ripens on victories; E reads its progress.
    case "garden": {
      const wins = draft.house.gardenWins ?? 0;
      draft.worldMessage = `The garden drinks your victories: ${wins}/${GARDEN_WINS_PER_YIELD} until the next harvest.`;
      return true;
    }
    // The manor's alchemy nook: two brews become a better one.
    case "cauldron":
      draft.openPanel = "nook";
      return true;
    default:
      return false;
  }
}

/**
 * Entering the inn rests the hero. Tier-3 towns honor their patron: the
 * price halves once the fountain sings (PIX-91).
 */
function restAtInn(draft: GameState): void {
  const hero = draft.hero;
  if (!hero) return;
  const restCost = restCostFor(townTierOf(draft));
  if (hero.hp === hero.stats.maxHp && hero.mp === hero.stats.maxMp) {
    draft.worldMessage = "The innkeeper nods. You are already well rested.";
  } else if (draft.gold < restCost) {
    draft.worldMessage = `No coin, no bed. (Rest costs ${restCost}g.)`;
  } else {
    draft.gold -= restCost;
    hero.hp = hero.stats.maxHp;
    hero.mp = hero.stats.maxMp;
    draft.worldMessage = `You rest at the inn. Fully restored. (-${restCost}g)`;
  }
}

export function worldReducer(draft: GameState, action: WorldAction): void {
  switch (action.type) {
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
      draft.openPanel = null;
      draft.world = {
        position,
        discovered: discoverAround(previous?.discovered ?? {}, map, position.x, position.y),
        openedChests: previous ? [...previous.openedChests] : [],
        slain: [],
      };
      return;
    }

    case "EXIT_WORLD": {
      // Only the hero-less ?world demo can leave the world; it IS the game now.
      if (draft.screen !== "world" || draft.hero) return;
      draft.screen = "title";
      return;
    }

    case "FAST_TRAVEL": {
      if (draft.screen !== "world" || !draft.world || !draft.hero) return;
      if (draft.dialogue || draft.openPanel) return;
      // The classic rule: nobody teleports over-encumbered.
      if (
        carriedWeight(draft.inventory, draft.gear, draft.equipped) >
        carryCapacity(draft.hero, draft.gear, draft.equipped)
      ) {
        draft.worldMessage = "Too heavy to travel. Lighten the pack.";
        return;
      }
      const waypoint = WAYPOINTS.find((w) => w.id === action.waypointId);
      if (!waypoint || !waypointUsable(waypoint, draft.world.discovered, draft.settlers ?? [])) return;
      const map = getMap(waypoint.mapId);
      draft.world.position = { mapId: waypoint.mapId, x: waypoint.arrival.x, y: waypoint.arrival.y, facing: "down" };
      draft.world.discovered = discoverAround(draft.world.discovered, map, waypoint.arrival.x, waypoint.arrival.y);
      draft.worldMessage = `You travel to ${waypoint.name}.`;
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
      // Menus are modal: no talking through the shop, the pack or the chest.
      if (draft.openPanel) return;
      if (draft.dialogue) {
        worldReducer(draft, { type: "ADVANCE_DIALOGUE" });
        return;
      }
      const { position } = draft.world;
      const { dx, dy } = DIRECTION_DELTAS[position.facing];
      // Treasure first: a chest the hero faces opens before anyone chats.
      const chest = solidChestAt(position.mapId, position.x + dx, position.y + dy);
      if (chest && !draft.world.openedChests.includes(chest.id)) {
        openChest(draft, chest);
        return;
      }
      // The shut door in town: E buys the deed (or names the price).
      if (
        position.mapId === HOUSE_DOOR.mapId &&
        position.x + dx === HOUSE_DOOR.x &&
        position.y + dy === HOUSE_DOOR.y &&
        !draft.house.owned
      ) {
        if (draft.gold >= HOUSE_DEED_COST) {
          draft.gold -= HOUSE_DEED_COST;
          draft.house.owned = true;
          draft.worldMessage = "The deed is yours. Welcome home.";
        } else {
          draft.worldMessage = `For sale: this house. The deed costs ${HOUSE_DEED_COST}g.`;
        }
        return;
      }
      // Everything home answers to E: furniture, bed, shelf, trophies, nook.
      if (handleHouseInteract(draft, position.x + dx, position.y + dy)) return;
      // Anyone beside the hero counts, faced tile first; no more pixel-perfect
      // shuffling to line up a chat. Interacting turns the hero toward them.
      const beside = npcBeside(position.mapId, position.x, position.y, position.facing, draft.worldSteps);
      if (!beside) return;
      position.facing = beside.facing;
      // Keepers trade instead of chatting: talking to whoever runs a shop
      // opens their counter (the menu no longer jumps at you on entry).
      if (SHOP_MAPS[position.mapId]) {
        draft.openPanel = "shop";
        return;
      }
      // The mayor opens the town ledger instead of small talk (PIX-91).
      if (position.mapId === "town_hall") {
        draft.openPanel = "hall";
        return;
      }
      // A settled banker opens her ledger the same way (PIX-93); before she
      // joins, the conversation is the recruitment.
      if (beside.npc.id === "settler_mirelle" && isSettled(draft, "settler_mirelle")) {
        draft.openPanel = "bank";
        return;
      }
      draft.dialogue = { npcId: beside.npc.id, page: 0 };
      draft.worldMessage = null;
      return;
    }

    case "PLACE_FURNITURE": {
      // Furniture goes where you face (PIX-34): open floor only, one per tile.
      if (draft.screen !== "world" || !draft.world || !draft.hero) return;
      const { position } = draft.world;
      if (position.mapId !== "town_house" || (draft.inventory[action.itemId] ?? 0) <= 0) return;
      if (getItem(action.itemId).category !== "furniture") return;
      const { dx, dy } = DIRECTION_DELTAS[position.facing];
      const tx = position.x + dx;
      const ty = position.y + dy;
      const tile = getMap(position.mapId).tiles[ty]?.[tx];
      if (tile !== "floor") {
        draft.worldMessage = "It needs open floor. Face a free tile and try again.";
        return;
      }
      if (furnitureAt(draft, position.mapId, tx, ty)) {
        draft.worldMessage = "Something already stands there.";
        return;
      }
      draft.inventory = removeItem(draft.inventory, action.itemId);
      draft.house.furniture = [...(draft.house.furniture ?? []), { itemId: action.itemId, x: tx, y: ty }];
      draft.openPanel = null;
      draft.worldMessage = `${getItem(action.itemId).name} placed. E takes it back.`;
      return;
    }

    case "ADVANCE_DIALOGUE": {
      if (!draft.dialogue) return;
      const npc = npcById(draft.dialogue!.npcId);
      if (!npc || draft.dialogue.page >= npc.lines.length - 1) {
        const giverId = draft.dialogue.npcId;
        draft.dialogue = null;
        // Settlers first (recruiting and services ride the close, PIX-92),
        // then quests: closing a conversation accepts or turns in.
        if (draft.hero && resolveSettler(draft, giverId)) return;
        if (draft.hero) resolveQuests(draft, giverId);
        return;
      }
      draft.dialogue.page += 1;
      return;
    }

    case "MOVE": {
      if (draft.screen !== "world" || !draft.world) return;
      // Menus are modal: walking away with the shop open used to strand the
      // overlay on a map with no shop and crash the tree (PIX-58).
      if (draft.dialogue || draft.openPanel) return;
      const { position } = draft.world;
      const map = getMap(position.mapId);
      const { dx, dy } = DIRECTION_DELTAS[action.direction];
      const x = position.x + dx;
      const y = position.y + dy;
      // A living spawn on the target tile: bumping into it IS the attack.
      if (draft.hero) {
        const spawn = monsterSpawnAt(map, x, y, draft.worldSteps, draft.world.slain ?? []);
        if (spawn) {
          position.facing = action.direction;
          const region = spawnRegion(spawn);
          const encounter = encounterForSpawn(region, spawnSpecies(region, spawn.x * 31 + spawn.y));
          draft.screen = "battle";
          draft.battle = createWildBattle(encounter);
          draft.battle.wildSpawnId = spawn.id;
          return;
        }
      }
      // The bought house opens: bumping its shut door walks you in.
      if (map.id === HOUSE_DOOR.mapId && x === HOUSE_DOOR.x && y === HOUSE_DOOR.y) {
        position.facing = action.direction;
        if (draft.house.owned) {
          draft.worldMessage = null;
          draft.world.slain = [];
          draft.world.position = { mapId: "town_house", x: 8, y: 8, facing: "up" };
          draft.world.discovered = discoverAround(draft.world.discovered, getMap("town_house"), 4, 4);
        } else {
          draft.worldMessage = `For sale: this house. The deed costs ${HOUSE_DEED_COST}g. (E to buy)`;
        }
        return;
      }
      // Bumping into something (or someone) still turns the hero toward it.
      const bump = furnitureAt(draft, map.id, x, y);
      if (
        !isWalkable(map, x, y) ||
        npcAt(map.id, x, y, draft.worldSteps) ||
        solidChestAt(map.id, x, y) ||
        (bump && furnitureBlocks(bump.itemId))
      ) {
        position.facing = action.direction;
        return;
      }
      const portal = portalAt(map, x, y);
      if (portal && portal.to.kind === "map") {
        const target = getMap(portal.to.mapId);
        draft.worldMessage = null;
        // fresh hunting grounds: cleared spawns return when you leave and come back
        draft.world.slain = [];
        draft.world.position = { mapId: target.id, x: portal.to.x, y: portal.to.y, facing: action.direction };
        draft.world.discovered = discoverAround(draft.world.discovered, target, portal.to.x, portal.to.y);
        if (target.id === INN_MAP_ID) restAtInn(draft);
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
      // Ground treasure is taken in stride: glints and herbs, not furniture.
      const found = draft.hero ? chestAt(map.id, x, y) : null;
      if (found && found.look !== "chest" && !draft.world.openedChests.includes(found.id)) {
        openChest(draft, found);
      }
    }
  }
}

/** Grants a chest's payout: gold, items, a gear piece, or a mimic's teeth. */
function openChest(draft: GameState, chest: Chest): void {
  if (!draft.world || !draft.hero) return;
  if (chest.mimic) {
    // The chest was the monster all along. No refunds.
    draft.world.openedChests.push(chest.id);
    draft.screen = "battle";
    draft.battle = createWildBattle(encounterForSpawn(chestRegion(chest)!, "mimic"));
    draft.battle.log = ["The chest sprouts teeth. It was a mimic all along!"];
    return;
  }
  const loot = chest.loot!;
  if (loot.kind === "gold") {
    draft.gold += loot.amount;
    draft.world.openedChests.push(chest.id);
    draft.worldMessage =
      chest.look === "glint" ? `Something glitters on the road: ${loot.amount}g.` : `The chest holds ${loot.amount}g.`;
    return;
  }
  const item = getItem(loot.itemId);
  const qty = loot.kind === "item" ? loot.qty : 1;
  const capacity = carryCapacity(draft.hero, draft.gear, draft.equipped);
  if (carriedWeight(draft.inventory, draft.gear, draft.equipped) + item.weight * qty > capacity) {
    draft.worldMessage = "Too heavy to carry. Lighten the pack and come back.";
    return;
  }
  draft.world.openedChests.push(chest.id);
  if (loot.kind === "gear") {
    const gear = createGear(loot.itemId);
    draft.gear.push(gear);
    draft.worldMessage = `The chest holds ${gearName(gear)}!`;
    return;
  }
  draft.inventory[loot.itemId] = (draft.inventory[loot.itemId] ?? 0) + qty;
  draft.worldMessage =
    chest.look === "herb" ? `You gather ${qty}x ${item.name}.` : `The chest holds ${qty}x ${item.name}.`;
}

/** Accept the giver's untaken quest, or turn in a finished one. */
function resolveQuests(draft: GameState, giverId: string): void {
  for (const quest of questsFor(giverId)) {
    const entry = draft.quests[quest.id];
    if (entry?.done) continue;
    if (!entry) {
      draft.quests[quest.id] = { progress: 0, done: false };
      draft.worldMessage = `Quest accepted - ${quest.name}: ${quest.accepted}`;
      return;
    }
    if (questReady(draft, quest)) {
      if (quest.objective.kind === "deliver") {
        draft.inventory = removeItem(draft.inventory, quest.objective.itemId, quest.objective.count);
      }
      entry.done = true;
      draft.gold += quest.reward.gold;
      draft.hero!.xp += quest.reward.xp;
      applyLevelUps(draft.hero!);
      if (quest.reward.itemId) draft.inventory = addItem(draft.inventory, quest.reward.itemId);
      draft.worldMessage = `Quest complete - ${quest.name}! +${quest.reward.gold}g, +${quest.reward.xp} xp. ${quest.completed}`;
      return;
    }
    draft.worldMessage = `${quest.name}: ${questProgress(draft, quest)}/${quest.objective.count} ${quest.objective.label.toLowerCase()}.`;
    return;
  }
}
