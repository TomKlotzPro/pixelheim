import { Assets, type Container, Sprite, type Texture } from "pixi.js";
import { WILD_TILES } from "../state/shared";
import { regionAt } from "../world/parseMap";
import { TILE_ANIMATIONS, TILES } from "../world/tiles";
import type { WorldMap } from "../world/types";
import { ART, type FrameBank } from "./pixiUtils";

/** The ground: static tiles, breathing tiles, and danger tufts. */
export class TerrainLayer {
  private animated: { sprite: Sprite; name: string }[] = [];
  private bank: FrameBank;

  constructor(bank: FrameBank) {
    this.bank = bank;
  }

  build(container: Container, map: WorldMap): void {
    this.animated = [];
    for (let y = 0; y < map.height; y++) {
      for (let x = 0; x < map.width; x++) {
        const tile = map.tiles[y][x];
        const animName = TILE_ANIMATIONS[tile];
        const sheet = animName ? this.bank.frames.get(animName) : undefined;
        const sprite = new Sprite(sheet ? sheet[0] : (Assets.get(TILES[tile].sprite) as Texture));
        sprite.position.set(x * ART, y * ART);
        container.addChild(sprite);
        if (animName && sheet) this.animated.push({ sprite, name: animName });
        // Dangerous ground stays visible: wild-region tiles grow dark tufts.
        if (WILD_TILES.has(tile) && regionAt(map, x, y) !== null) {
          const tuft = new Sprite(Assets.get("overlay_wild") as Texture);
          tuft.position.set(x * ART, y * ART);
          container.addChild(tuft);
        }
      }
    }
  }

  tick(clock: number): void {
    for (const { sprite, name } of this.animated) {
      const sheet = this.bank.frames.get(name)!;
      const ms = this.bank.ms.get(name) ?? 500;
      sprite.texture = sheet[Math.floor(clock / ms) % sheet.length];
    }
  }
}
