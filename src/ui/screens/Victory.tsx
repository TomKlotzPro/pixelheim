import type { Hero } from "../../game/types";
import { Sprite } from "../widgets/Sprite";

type VictoryProps = {
  hero: Hero;
  onContinue: () => void;
};

export function Victory({ hero, onContinue }: VictoryProps) {
  return (
    <div className="screen victory-screen">
      <Sprite name="lich" size={128} className="fallen" alt="Defeated lich" />
      <h1 className="game-title">VICTORY</h1>
      <p className="tagline">
        {hero.name} slew Fafnyr the Ashen above and cast down Morvax the Deathless below. The mountain is quiet at
        last, the tavern is loud, and the cheese has never tasted better.
      </p>
      <button className="btn btn-primary" onClick={onContinue}>
        Return to town
      </button>
    </div>
  );
}
