import {
  advanceEncounter,
  createDungeonBattle,
  grantFloorRewards,
  heroAttack,
  heroFlee,
  heroSkill,
  heroStunGate,
  monsterTurn,
} from "../../game/battleEngine";
import { carriedWeight, carryCapacity } from "../../game/character";
import { removeItem } from "../../game/inventory";
import { getItem } from "../../game/items";
import { getLevel, LEVELS } from "../../game/levels";
import { getHeroSkills } from "../../game/skillTree";
import type { GameState } from "../../game/types";
import type { BattleAction } from "../actions";
import { INN_REST } from "../shared";

export function battleReducer(draft: GameState, action: BattleAction): void {
  switch (action.type) {
    case "ENTER_LEVEL": {
      if (!draft.hero || action.level > draft.unlockedLevel) return;
      if (carriedWeight(draft.inventory, draft.gear, draft.equipped) > carryCapacity(draft.hero, draft.gear, draft.equipped)) return;
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
    }
  }
}
