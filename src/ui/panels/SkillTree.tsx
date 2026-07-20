import { resourceLabel } from "../../game/hero/character";
import { rankIndex } from "../../game/hero/ranks";
import { canBuyNode, SKILL_TREES, type SkillNode } from "../../game/hero/skillTree";
import { activeNode, heroPath, PATH_NODES, pathChoices, pendingTier } from "../../game/hero/paths";
import { ROLES } from "../../game/hero/roles";
import type { Hero } from "../../game/types";
import { dispatch, useHero } from "../../state/store";
import { Sprite } from "../widgets/Sprite";
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
  const branches = [0, 1, 2].map((branch) => tree.filter((n) => n.branch === branch).sort((a, b) => a.tier - b.tier));

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
        {rankIndex(hero.level) >= 1 && <PathGraph hero={hero} />}
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
                  <div key={node.id} className={`skill-node ${isOwned ? "owned" : buyable ? "buyable" : "locked"}`}>
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

/** Node coordinates in the edge SVG: columns by tier, rows by branch. */
const NODE_X = { 1: 50, 2: 150, 3: 250 } as const;
const NODE_Y = { a: 26, b: 78 } as const;

/**
 * The Path Graph (PIX-105): the class's six identities as a walked map.
 * Columns are ranks, edges are allowed ascensions - tier 2 accepts either
 * tier-1 path (the crossover), a capstone only its own advanced form. The
 * walked path glows; a pending choice offers its cards right here (the
 * ascension cinematic is the front door, this is the ledger).
 */
function PathGraph({ hero }: { hero: Hero }) {
  const walked = heroPath(hero);
  const walkedSet = new Set(walked);
  const identity = activeNode(hero);
  const pending = pendingTier(hero);
  const claimable = new Set(pathChoices(hero).map((n) => n.id));
  const nodes = PATH_NODES.filter((n) => n.roleId === hero.roleId);
  const heroBase = ROLES[hero.roleId].sprite;

  const edges = nodes.flatMap((node) =>
    node.from.map((fromId) => {
      const from = nodes.find((n) => n.id === fromId)!;
      const wasWalked =
        walkedSet.has(fromId) && walkedSet.has(node.id) && walked.indexOf(node.id) === walked.indexOf(fromId) + 1;
      return { key: `${fromId}-${node.id}`, from, to: node, walked: wasWalked };
    }),
  );

  return (
    <div className="spec-section">
      <h3 className="skill-branch-title">{pending ? "Your ascension demands a path" : "The Path Graph"}</h3>
      {identity && (
        <div className="spec-chosen" data-testid="spec-chosen">
          <span className="spec-name">{identity.name}</span>
          <span className="options-note">{identity.blurb}</span>
        </div>
      )}
      <div className="path-graph">
        <svg className="path-edges" viewBox="0 0 300 104" preserveAspectRatio="none" aria-hidden="true">
          {edges.map((edge) => (
            <line
              key={edge.key}
              x1={NODE_X[edge.from.tier]}
              y1={NODE_Y[edge.from.branch]}
              x2={NODE_X[edge.to.tier]}
              y2={NODE_Y[edge.to.branch]}
              className={edge.walked ? "path-edge path-edge-walked" : "path-edge"}
            />
          ))}
        </svg>
        {nodes.map((node) => {
          const isWalked = walkedSet.has(node.id);
          const isCurrent = identity?.id === node.id;
          const isClaimable = claimable.has(node.id);
          const state = isCurrent ? "current" : isWalked ? "walked" : isClaimable ? "claimable" : "locked";
          return (
            <div
              key={node.id}
              className={`spec-card path-node path-node-${state}`}
              style={{ gridColumn: node.tier, gridRow: node.branch === "a" ? 1 : 2 }}
              data-testid={isClaimable ? `spec-${node.id}` : `path-node-${node.id}`}
            >
              <div className="path-node-head">
                <Sprite name={`${heroBase}_p${node.branch}_r${node.tier}`} size={24} alt="" />
                <span className="spec-name">{node.name}</span>
                <span className="skill-node-tier">{["I", "II", "III"][node.tier - 1]}</span>
              </div>
              <p className="skill-node-desc">{node.blurb}</p>
              <p className="skill-node-numbers">Signature: {node.signature.name}</p>
              {isClaimable && (
                <button
                  className="btn btn-small btn-primary"
                  onClick={() => dispatch({ type: "CHOOSE_PATH", nodeId: node.id })}
                >
                  Walk this path
                </button>
              )}
              {state === "locked" && !isWalked && <span className="skill-node-locked">Rank {node.tier}</span>}
            </div>
          );
        })}
      </div>
      <p className="options-footer">A path is for life. Each rank walks it deeper - or across.</p>
    </div>
  );
}
