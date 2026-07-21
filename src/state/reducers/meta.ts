import { createHero } from "../../game/hero/character";
import { addItem } from "../../game/economy/inventory";
import { createGear } from "../../game/economy/rarity";
import type { GameState, RoleId } from "../../game/types";
import { discoverAround } from "../../world/discover";
import { getMap } from "../../world/maps/index";
import type { MetaAction } from "../actions";
import { initialState, TOWN_SPAWN } from "../shared";

export function metaReducer(draft: GameState, action: MetaAction): GameState | void {
  switch (action.type) {
    case "NEW_GAME":
      return { ...initialState, screen: "create" };

    case "LOAD":
      return action.state;

    case "CREATE_HERO": {
      const hero = createHero(action.name, action.roleId, action.look);
      const starterWeapon: Record<RoleId, string> = {
        warrior: "rusty_sword",
        mage: "rusty_sword",
        rogue: "rusty_sword",
        cleric: "rusty_sword",
        ranger: "hunting_bow",
        paladin: "rusty_sword",
        necromancer: "rusty_sword",
      };
      // Rogue/mage/necromancer skills are strong; they begin with the humble rusty sword.
      const weaponId = starterWeapon[action.roleId];
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
      draft.openPanel = null;
      draft.dialogue = null;
  }
}
