import { type Container, type Graphics, Sprite, Texture } from "pixi.js";
import { regionAt } from "../world/parseMap";
import { EMBER_CAP, EMBER_TINT_INTS, skyAt } from "./dayNight";
import type { WorldMap } from "../world/types";
import { ART, makeGlowTexture } from "./pixiUtils";

/** Sky tint as Pixi wants it: packed int + alpha. */
function skyTint(steps: number): { color: number; alpha: number } {
  const { r, g, b, alpha } = skyAt(steps);
  return { color: (Math.round(r) << 16) | (Math.round(g) << 8) | Math.round(b), alpha };
}

type Ember = { sprite: Sprite; x: number; y: number; vy: number; sway: number; life: number; maxLife: number };

/** The weather: the day/night sky, night lights, always-burning fires, embers. */
export class AtmosphereLayer {
  private sky: Graphics;
  private lightC: Container;
  private glowTexture = makeGlowTexture();
  private glows: { sprite: Sprite; always: boolean }[] = [];
  private embers: Ember[] = [];
  private ashTiles: { x: number; y: number }[] = [];
  private skyTarget = { color: 0, alpha: 0 };
  private outdoor = false;

  constructor(sky: Graphics, lightC: Container) {
    this.sky = sky;
    this.lightC = lightC;
  }

  build(map: WorldMap, outdoor: boolean): void {
    this.lightC.removeChildren();
    this.glows = [];
    this.embers = [];
    this.ashTiles = [];
    this.outdoor = outdoor;

    for (let y = 0; y < map.height; y++) {
      for (let x = 0; x < map.width; x++) {
        const tile = map.tiles[y][x];
        if (outdoor && regionAt(map, x, y) === "ash") this.ashTiles.push({ x, y });
        // Doors, lamps and the shrine glow after dark; forges and hearths
        // burn all day, indoors included.
        const nightLight = outdoor && (tile === "door" || tile === "shrine" || tile === "lamp");
        const alwaysLight = tile === "forge" || tile === "hearth";
        if (nightLight || alwaysLight) {
          const glow = new Sprite(this.glowTexture);
          glow.anchor.set(0.5);
          glow.position.set(x * ART + ART / 2, y * ART + ART / 2);
          glow.width = ART * 3;
          glow.height = ART * 3;
          glow.blendMode = "add";
          glow.alpha = 0;
          this.lightC.addChild(glow);
          this.glows.push({ sprite: glow, always: alwaysLight });
        }
      }
    }
  }

  update(worldSteps: number): void {
    this.skyTarget = this.outdoor ? skyTint(worldSteps) : { color: 0, alpha: 0 };
  }

  tick(deltaMS: number, clock: number): void {
    // Sky drifts toward its target so dusk falls rather than snaps.
    this.sky.tint = this.skyTarget.color;
    this.sky.alpha += (this.skyTarget.alpha - this.sky.alpha) * (1 - Math.exp(-deltaMS / 400));
    const darkness = Math.min(1, this.sky.alpha / 0.36);
    for (const { sprite, always } of this.glows) {
      const strength = always ? 0.8 : darkness;
      sprite.alpha = strength * (0.75 + 0.25 * Math.sin(clock / 300 + sprite.position.x));
    }
    this.tickEmbers(deltaMS);
  }

  /** Embers drift up from ash ground, sway, fade, and are reborn elsewhere. */
  private tickEmbers(deltaMS: number): void {
    if (this.ashTiles.length === 0) return;
    const cap = Math.min(EMBER_CAP, this.ashTiles.length * 2);
    if (this.embers.length < cap && Math.random() < 0.3) {
      const at = this.ashTiles[Math.floor(Math.random() * this.ashTiles.length)];
      const sprite = new Sprite(Texture.WHITE);
      sprite.width = 1.4;
      sprite.height = 1.4;
      sprite.tint = EMBER_TINT_INTS[Math.floor(Math.random() * EMBER_TINT_INTS.length)];
      sprite.blendMode = "add";
      this.lightC.addChild(sprite);
      this.embers.push({
        sprite,
        x: at.x * ART + Math.random() * ART,
        y: at.y * ART + ART,
        vy: 4 + Math.random() * 5,
        sway: Math.random() * Math.PI * 2,
        life: 0,
        maxLife: 2200 + Math.random() * 1600,
      });
    }
    this.embers = this.embers.filter((ember) => {
      ember.life += deltaMS;
      if (ember.life >= ember.maxLife) {
        ember.sprite.destroy();
        return false;
      }
      const k = ember.life / ember.maxLife;
      ember.y -= (ember.vy * deltaMS) / 1000;
      ember.sprite.position.set(ember.x + Math.sin(ember.life / 400 + ember.sway) * 2.5, ember.y);
      ember.sprite.alpha = k < 0.15 ? k / 0.15 : 1 - (k - 0.15) / 0.85;
      return true;
    });
  }
}
