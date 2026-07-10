import type { Hero } from "../game/types";
import { Sprite } from "./Sprite";

type VictoryProps = {
  hero: Hero;
  onContinue: () => void;
};

export function Victory({ hero, onContinue }: VictoryProps) {
  return (
    <div className="screen victory-screen">
      <Sprite name="dragon" size={128} className="fallen" alt="Defeated dragon" />
      <h1 className="game-title">VICTORY</h1>
      <p className="tagline">
        {hero.name} has slain Fafnyr the Ashen. The mountain is quiet, the tavern is loud, and the cheese has never
        tasted better.
      </p>
      <button className="btn btn-primary" onClick={onContinue}>
        Return to town
      </button>
    </div>
  );
}
