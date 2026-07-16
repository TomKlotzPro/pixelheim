import { Assets, type Container, Sprite, type Texture } from "pixi.js";
import { WILD_TILES } from "../state/shared";
import { regionAt } from "../world/parseMap";
import { TILE_ANIMATIONS, TILES } from "../world/tiles";
import type { TileId, WorldMap } from "../world/types";
import { ART, type FrameBank } from "./pixiUtils";

/**
 * Grass repeats less: most tiles use the base sheet, some roll a denser or
 * pebblier variant, picked by position hash so the choice is stable.
 */
const GRASS_SWAYS = ["grass_sway", "grass_sway", "grass_sway", "grass_sway", "grass_sway", "grass2_sway", "grass3_sway"];

function grassVariant(x: number, y: number): string {
  const hash = Math.abs((x * 73856093) ^ (y * 19349663));
  return GRASS_SWAYS[hash % GRASS_SWAYS.length];
}

/** Ground the path fringe grows from; murkier terrain gets no green edge. */
const FRINGE_NEIGHBORS = new Set<TileId>(["grass", "forest", "flowers"]);
/** Fringe rotations per side the grass hangs over from: up, right, down, left. */
const FRINGE_SIDES: { dx: number; dy: number; rotation: number }[] = [
  { dx: 0, dy: -1, rotation: 0 },
  { dx: 1, dy: 0, rotation: Math.PI / 2 },
  { dx: 0, dy: 1, rotation: Math.PI },
  { dx: -1, dy: 0, rotation: -Math.PI / 2 },
];

/** The ground: tiles with variation, breathing tiles, framed paths, danger tufts. */
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
        const animName = tile === "grass" ? grassVariant(x, y) : TILE_ANIMATIONS[tile];
        const sheet = animName ? this.bank.frames.get(animName) : undefined;
        const sprite = new Sprite(sheet ? sheet[0] : (Assets.get(TILES[tile].sprite) as Texture));
        sprite.position.set(x * ART, y * ART);
        container.addChild(sprite);
        if (animName && sheet) this.animated.push({ sprite, name: animName });
        // Paths read as built roads: green fringes hang over from bordering grass.
        if (tile === "path") {
          for (const side of FRINGE_SIDES) {
            const neighbor = map.tiles[y + side.dy]?.[x + side.dx];
            if (neighbor && FRINGE_NEIGHBORS.has(neighbor)) {
              const fringe = new Sprite(Assets.get("overlay_path_edge") as Texture);
              fringe.anchor.set(0.5);
              fringe.rotation = side.rotation;
              fringe.position.set(x * ART + ART / 2, y * ART + ART / 2);
              container.addChild(fringe);
            }
          }
        }
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
