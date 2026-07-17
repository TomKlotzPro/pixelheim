import { createHero } from "../../game/character";
import { addItem } from "../../game/inventory";
import { createGear } from "../../game/rarity";
import type { GameState, RoleId } from "../../game/types";
import { discoverAround } from "../../world/discover";
import { getMap } from "../../world/maps";
import type { MetaAction } from "../actions";
import { initialState, TOWN_SPAWN } from "../shared";

export function metaReducer(draft: GameState, action: MetaAction): GameState | void {
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
          slain: [],
        },
      };
    }

    case "DISMISS_INTRO":
      draft.introSeen = true;
      return;

    // Back to the title with everything intact: Continue resumes in place.
    case "QUIT_TO_TITLE":
      draft.screen = "title";
      draft.inventoryOpen = false;
      draft.shopOpen = false;
      draft.dialogue = null;
  }
}
