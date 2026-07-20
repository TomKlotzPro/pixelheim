import { applyStatPoint } from "../../game/hero/character";
import { canBuyNode, getNode } from "../../game/hero/skillTree";
import type { GameState } from "../../game/types";
import type { ProgressionAction } from "../actions";
import { heroPath, pathChoices } from "../../game/hero/paths";

export function progressionReducer(draft: GameState, action: ProgressionAction): void {
  switch (action.type) {
    case "SPEND_STAT_POINT": {
      if (!draft.hero || draft.hero.statPoints <= 0) return;
      applyStatPoint(draft.hero, action.stat);
      draft.hero.statPoints -= 1;
      return;
    }

    case "CHOOSE_SPEC": {
      // Legacy alias for the tier-1 fork; the Path Graph owns the rules now.
      progressionReducer(draft, { type: "CHOOSE_PATH", nodeId: action.specId });
      return;
    }

    case "CHOOSE_PATH": {
      // One step deeper into the graph: role-checked, tier-gated, edge-checked,
      // permanent. `spec` mirrors the first step so pre-graph code keeps working.
      if (!draft.hero) return;
      const node = pathChoices(draft.hero).find((n) => n.id === action.nodeId);
      if (!node) return;
      draft.hero.path = [...heroPath(draft.hero), node.id];
      draft.hero.spec = draft.hero.path[0];
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
