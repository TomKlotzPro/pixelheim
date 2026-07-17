import { resourceLabel } from "../../game/hero/character";
import { canBuyNode, SKILL_TREES, type SkillNode } from "../../game/hero/skillTree";
import { dispatch, useHero } from "../../state/store";
import { useEscapeClose } from "../useEscapeClose";

const KIND_LABELS: Record<SkillNode["kind"], string> = {
  active: "SKILL",
  upgrade: "UPGRADE",
  passive: "PASSIVE",
};

const STAT_ABBR: Record<string, string> = {
  strength: "STR",
  intelligence: "INT",
  dexterity: "DEX",
};

const TIER_BADGES = ["I", "II", "III", "CAP"];

export function SkillTree({ onClose }: { onClose: () => void }) {
  useEscapeClose(onClose);
  const hero = useHero();
  const tree = SKILL_TREES[hero.roleId];
  const owned = new Set(hero.skillNodes);
  const resource = resourceLabel(hero.roleId);
  const branches = [0, 1, 2].map((branch) =>
    tree.filter((n) => n.branch === branch).sort((a, b) => a.tier - b.tier),
  );

  return (
    <div className="overlay" onClick={onClose}>
      <div className="panel skill-tree" onClick={(e) => e.stopPropagation()}>
        <div className="inventory-header">
          <h2>Skills</h2>
          <span className={`points-chip ${hero.skillPoints > 0 ? "points-chip-live" : ""}`}>
            {hero.skillPoints} skill point{hero.skillPoints === 1 ? "" : "s"}
          </span>
          <button className="btn btn-small" onClick={onClose}>
            Close
          </button>
        </div>
        <div className="skill-branches">
          {branches.map((nodes, i) => (
            <div key={i} className="skill-branch">
              <h3 className="skill-branch-title">Path of {nodes[0]?.skill?.name ?? nodes[0]?.name}</h3>
              {nodes.map((node) => {
                const isOwned = owned.has(node.id);
                const buyable = canBuyNode(hero, node);
                const locked = !isOwned && !buyable;
                const skill = node.skill;
                return (
                  <div
                    key={node.id}
                    className={`skill-node ${isOwned ? "owned" : buyable ? "buyable" : "locked"}`}
                  >
                    <div className="skill-node-head">
                      <span className="skill-node-tier">{TIER_BADGES[node.tier] ?? "?"}</span>
                      <span className="skill-node-name">{node.name}</span>
                      <span className={`skill-node-kind kind-${node.kind}`}>{KIND_LABELS[node.kind]}</span>
                    </div>
                    <p className="skill-node-desc">{node.description}</p>
                    {skill && skill.kind === "damage" && (
                      <p className="skill-node-numbers">
                        {skill.multiplier}x {STAT_ABBR[skill.stat] ?? skill.stat} damage · {skill.mpCost} {resource}
                        {skill.hpCost ? ` + ${skill.hpCost} HP` : ""}
                      </p>
                    )}
                    {skill && skill.kind === "heal" && (
                      <p className="skill-node-numbers">
                        {skill.multiplier}x {STAT_ABBR[skill.stat] ?? skill.stat} healing · {skill.mpCost} {resource}
                      </p>
                    )}
                    {isOwned && <span className="cleared-tag">OWNED</span>}
                    {!isOwned && buyable && (
                      <button
                        className="btn btn-small btn-primary"
                        onClick={() => dispatch({ type: "BUY_SKILL_NODE", nodeId: node.id })}
                      >
                        Learn (1 pt)
                      </button>
                    )}
                    {locked && (
                      <span className="skill-node-locked">
                        {node.requires && !owned.has(node.requires) ? "Requires the skill above" : "No points"}
                      </span>
                    )}
                  </div>
                );
              })}
            </div>
          ))}
        </div>
        <p className="options-footer">One point per level. Learning is permanent.</p>
      </div>
    </div>
  );
}
