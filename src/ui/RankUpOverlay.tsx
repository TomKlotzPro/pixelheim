import { heroSprite } from "../game/hero/character";
import type { PathNode } from "../game/hero/paths";
import { ROLES } from "../game/hero/roles";
import { SFX } from "../audio/sfx";
import type { Hero } from "../game/types";
import { dispatch } from "../state/store";
import { Sprite } from "./widgets/Sprite";

/**
 * The ascension cinematic (PIX-98/100/101/105): letterbox bars, rays, the
 * marching hero, the title card - and, at a fork, the path-choice cards that
 * hold the scene until a walk is chosen.
 */
export function RankUpOverlay({
  hero,
  title,
  choices,
  onDismiss,
}: {
  hero: Hero;
  title: string;
  choices: PathNode[];
  onDismiss: () => void;
}) {
  return (
    <div className={`rankup-overlay${choices.length > 0 ? " rankup-choosing" : ""}`} aria-live="polite">
      <div className="rankup-bar rankup-bar-top" />
      <div className="rankup-bar rankup-bar-bottom" />
      <span className="rankup-rays" aria-hidden="true" />
      <span
        className="rankup-hero"
        aria-hidden="true"
        style={{ backgroundImage: `url(${import.meta.env.BASE_URL}sprites/${heroSprite(hero)}_walk.png)` }}
      />
      <div className="rankup-card">
        <span className="rankup-eyebrow">Ascension</span>
        <span className="rankup-title">{title}</span>
        <span className="rankup-note">+1 bonus skill point</span>
      </div>
      {choices.length > 0 && (
        <div className="rankup-paths">
          <span className="rankup-eyebrow">The path forks</span>
          <div className="rankup-path-cards">
            {choices.map((node) => (
              <button
                key={node.id}
                className="rankup-path-card"
                data-testid={`rankup-path-${node.id}`}
                onClick={() => {
                  dispatch({ type: "CHOOSE_PATH", nodeId: node.id });
                  SFX.learn();
                }}
              >
                <Sprite name={`${ROLES[hero.roleId].sprite}_p${node.branch}_r${node.tier}`} size={32} alt="" />
                <span className="spec-name">{node.name}</span>
                <span className="rankup-path-blurb">{node.blurb}</span>
                <span className="skill-node-numbers">Signature: {node.signature.name}</span>
              </button>
            ))}
          </div>
          <button className="btn btn-small rankup-later" onClick={onDismiss}>
            Choose later, in Skills
          </button>
        </div>
      )}
    </div>
  );
}
