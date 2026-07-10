import { Sprite } from "./Sprite";

type TitleScreenProps = {
  canContinue: boolean;
  onNewGame: () => void;
  onContinue: () => void;
};

export function TitleScreen({ canContinue, onNewGame, onContinue }: TitleScreenProps) {
  return (
    <div className="screen title-screen">
      <div className="title-monsters">
        <Sprite name="slime" size={48} />
        <Sprite name="goblin" size={48} />
        <Sprite name="skeleton" size={48} />
        <Sprite name="dragon" size={72} />
        <Sprite name="golem" size={48} />
        <Sprite name="ghost" size={48} />
        <Sprite name="wolf" size={48} />
      </div>
      <h1 className="game-title">PIXELHEIM</h1>
      <p className="tagline">Ten floors. One dragon. Infinite cheese wheels.</p>
      <div className="menu">
        <button className="btn btn-primary" onClick={onNewGame}>
          New Game
        </button>
        {canContinue && (
          <button className="btn" onClick={onContinue}>
            Continue
          </button>
        )}
      </div>
      <p className="footnote">v0.1 - a retro RPG built with React + TypeScript</p>
    </div>
  );
}
