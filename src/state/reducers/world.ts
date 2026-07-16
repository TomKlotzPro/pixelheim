import { createWildBattle } from "../../game/battleEngine";
import { rollWildEncounter } from "../../game/encounters";
import { SHOP_MAPS } from "../../game/shop";
import type { GameState } from "../../game/types";
import { discoverAround } from "../../world/discover";
import { getMap } from "../../world/maps";
import { npcAt, NPCS } from "../../world/npcs";
import { isWalkable, portalAt, regionAt, tileAt } from "../../world/parseMap";
import type { WorldAction } from "../actions";
import { DIRECTION_DELTAS, REST_COST, WILD_TILES } from "../shared";

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

    case "CLOSE_DUNGEON_SELECT": {
      if (draft.screen !== "dungeon_select") return;
      draft.screen = "world";
      draft.dungeonSelect = null;
      return;
    }

    case "INTERACT": {
      if (draft.screen !== "world" || !draft.world || !draft.hero) return;
      if (draft.dialogue) {
        worldReducer(draft, { type: "ADVANCE_DIALOGUE" });
        return;
      }
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
    }
  }
}
