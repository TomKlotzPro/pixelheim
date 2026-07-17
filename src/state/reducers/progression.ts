import { applyStatPoint } from "../../game/character";
import { canBuyNode, getNode } from "../../game/skillTree";
import type { GameState } from "../../game/types";
import type { ProgressionAction } from "../actions";

export function progressionReducer(draft: GameState, action: ProgressionAction): void {
  switch (action.type) {
    case "SPEND_STAT_POINT": {
      if (!draft.hero || draft.hero.statPoints <= 0) return;
      applyStatPoint(draft.hero, action.stat);
      draft.hero.statPoints -= 1;
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
    }
  }
}
