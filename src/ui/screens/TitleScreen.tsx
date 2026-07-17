import { useState } from "react";
import { GAME_VERSION, hasUnseenChanges, markChangesSeen } from "../../app/changelog";
import { ChangelogPage } from "./Changelog";

/**
 * The title is a diorama: a night sky over the Ashenreach, three mountain
 * ridges deep, and the game's own monsters crossing the foreground on their
 * own schedules. Pure DOM/CSS - it must render instantly.
 */

// Each walker crosses the whole screen on its own clock; negative delays mean
// the parade is already mid-march when the screen appears.
const PARADE = [
  { name: "slime", size: 40, duration: 46, delay: -8, flip: false },
  { name: "wolf", size: 44, duration: 34, delay: -20, flip: true },
  { name: "goblin", size: 44, duration: 40, delay: -2, flip: false },
  { name: "skeleton", size: 46, duration: 52, delay: -33, flip: false },
  { name: "ghost", size: 42, duration: 38, delay: -15, flip: true },
  { name: "golem", size: 52, duration: 64, delay: -40, flip: false },
];

const STARS = [
  [4, 8, 3],
  [11, 22, 2],
  [17, 6, 2],
  [24, 15, 3],
  [31, 9, 2],
  [38, 24, 2],
  [45, 4, 3],
  [52, 18, 2],
  [59, 10, 2],
  [66, 26, 3],
  [73, 7, 2],
  [80, 20, 2],
  [87, 12, 3],
  [94, 25, 2],
  [8, 33, 2],
  [48, 31, 2],
  [70, 35, 2],
  [90, 32, 2],
] as const;

const EMBERS = [12, 27, 43, 58, 71, 86];

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

  const base = import.meta.env.BASE_URL;

  return (
    <div className="screen title-screen">
      <div className="title-scene" aria-hidden="true">
        {STARS.map(([x, y, px], i) => (
          <span
            key={i}
            className="title-star"
            style={{ left: `${x}%`, top: `${y}%`, width: px, height: px, animationDelay: `${(i % 7) * 0.8}s` }}
          />
        ))}
        <span className="title-moon" />
        <span className="title-dragon-flight" style={{ backgroundImage: `url(${base}sprites/dragon_idle.png)` }} />
        <div className="title-ridge title-ridge-far" />
        <div className="title-ridge title-ridge-mid" />
        <div className="title-fog" />
        <div className="title-ridge title-ridge-near" />
        {EMBERS.map((x, i) => (
          <span key={i} className="title-ember" style={{ left: `${x}%`, animationDelay: `${i * 2.1}s` }} />
        ))}
        <div className="title-ground" style={{ backgroundImage: `url(${base}sprites/tile_grass.png)` }} />
        <div className="title-parade">
          {PARADE.map((walker) => (
            <span
              key={walker.name}
              className={`title-walker ${walker.flip ? "title-walker-flip" : ""}`}
              style={{
                width: walker.size,
                height: walker.size,
                animationDuration: `${walker.duration}s`,
                animationDelay: `${walker.delay}s`,
              }}
            >
              <span
                className="title-walker-art"
                style={{
                  backgroundImage: `url(${base}sprites/${walker.name}_idle.png)`,
                  backgroundSize: `${walker.size * 2}px ${walker.size}px`,
                }}
              />
            </span>
          ))}
        </div>
      </div>

      <div className="title-card">
        <h1 className="game-title" aria-label="PIXELHEIM">
          {"PIXELHEIM".split("").map((letter, i) => (
            <span key={i} className="title-letter" style={{ animationDelay: `${i * 0.07}s` }}>
              {letter}
            </span>
          ))}
        </h1>
        <div className="title-rule" aria-hidden="true">
          <span className="title-rule-gem" />
        </div>
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
    </div>
  );
}
