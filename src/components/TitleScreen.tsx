import { useState } from "react";
import { GAME_VERSION, hasUnseenChanges, markChangesSeen } from "../changelog";
import { ChangelogPage } from "./Changelog";
import { Sprite } from "./Sprite";

const LINEUP = ["slime", "goblin", "skeleton", "dragon", "golem", "ghost", "wolf"];
const EMBERS = [8, 22, 37, 55, 68, 84];
const STARS = [
  [6, 12], [15, 28], [24, 8], [33, 20], [45, 6], [52, 24], [63, 14], [72, 30], [83, 10], [91, 22],
  [12, 40], [88, 42], [40, 34], [58, 38],
];

type TitleScreenProps = {
  canContinue: boolean;
  onNewGame: () => void;
  onContinue: () => void;
  onOpenOptions: () => void;
};

export function TitleScreen({ canContinue, onNewGame, onContinue, onOpenOptions }: TitleScreenProps) {
  const [changelogOpen, setChangelogOpen] = useState(false);
  const [showNewBadge, setShowNewBadge] = useState(hasUnseenChanges);

  const openChangelog = () => {
    markChangesSeen();
    setShowNewBadge(false);
    setChangelogOpen(true);
  };

  // The changelog is a page of its own, not an overlay.
  if (changelogOpen) return <ChangelogPage onBack={() => setChangelogOpen(false)} />;

  return (
    <div className="screen title-screen">
      <div className="title-backdrop" aria-hidden="true">
        {STARS.map(([x, y], i) => (
          <span key={i} className="title-star" style={{ left: `${x}%`, top: `${y}%`, animationDelay: `${(i % 5) * 0.9}s` }} />
        ))}
        <div className="title-mountains" />
        {EMBERS.map((x, i) => (
          <span key={i} className="title-ember" style={{ left: `${x}%`, animationDelay: `${i * 1.7}s` }} />
        ))}
      </div>

      <div className="title-monsters">
        {LINEUP.map((name, i) => (
          <span
            key={name}
            className={`title-monster ${name === "dragon" ? "title-dragon" : ""}`}
            style={{ animationDelay: `${i * 0.35}s` }}
          >
            <Sprite name={name} size={name === "dragon" ? 72 : 48} />
          </span>
        ))}
      </div>
      <h1 className="game-title">PIXELHEIM</h1>
      <p className="tagline">Fifteen floors. One dragon. Worse things below.</p>
      <div className="menu">
        <button className="btn btn-primary" onClick={onNewGame}>
          New Game
        </button>
        {canContinue && (
          <button className="btn" onClick={onContinue}>
            Continue
          </button>
        )}
        <button className="btn" onClick={onOpenOptions}>
          Options
        </button>
      </div>
      <button className="changelog-link" onClick={openChangelog}>
        v{GAME_VERSION} - a retro RPG built with React + TypeScript
        {showNewBadge && <span className="new-badge">NEW</span>}
      </button>
    </div>
  );
}
