import { Application, Assets, Container, Graphics, Rectangle, Sprite, Texture, TextureStyle } from "pixi.js";
import { ROLES } from "../game/roles";
import type { GameState } from "../game/types";
import { WILD_TILES } from "../state/shared";
import { getMap } from "../world/maps";
import { npcPosition, npcsOn, type Npc } from "../world/npcs";
import { regionAt } from "../world/parseMap";
import { TILES } from "../world/tiles";
import type { WorldMap, WorldPosition } from "../world/types";

export const ART = 16;
export const VIEW_W = 15;
export const VIEW_H = 11;

const WALK_MS = 160; // per walk frame
const IDLE_MS = 500; // per idle frame
const WATER_MS = 250; // per shimmer frame
const WALK_LINGER_MS = 240; // keep the legs moving briefly after the last step

/** Maps under the open sky; interiors stay lit and ember-free. */
const OUTDOOR_MAPS = new Set(["overworld", "town", "demo"]);
const EMBER_CAP = 36;
const EMBER_TINTS = [0xffa03c, 0xff7a28, 0xffc86e];

/**
 * The day/night wheel, turned by worldSteps (deterministic, saved). Each stop
 * is [r, g, b, alpha] for a screen overlay; steps between stops interpolate.
 */
const DAY_CYCLE_STEPS = 480;
const SKY_STOPS: { at: number; color: [number, number, number, number] }[] = [
  { at: 0.0, color: [0, 0, 0, 0] }, // day
  { at: 0.45, color: [0, 0, 0, 0] },
  { at: 0.55, color: [255, 122, 50, 0.13] }, // dusk
  { at: 0.65, color: [10, 16, 48, 0.36] }, // night
  { at: 0.85, color: [10, 16, 48, 0.36] },
  { at: 0.93, color: [255, 190, 110, 0.1] }, // dawn
  { at: 1.0, color: [0, 0, 0, 0] },
];

function skyAt(steps: number): { color: number; alpha: number } {
  const t = (steps % DAY_CYCLE_STEPS) / DAY_CYCLE_STEPS;
  let i = 0;
  while (i < SKY_STOPS.length - 2 && SKY_STOPS[i + 1].at < t) i++;
  const a = SKY_STOPS[i];
  const b = SKY_STOPS[i + 1];
  const k = (t - a.at) / (b.at - a.at || 1);
  const mix = a.color.map((v, c) => v + (b.color[c] - v) * k);
  return { color: (Math.round(mix[0]) << 16) | (Math.round(mix[1]) << 8) | Math.round(mix[2]), alpha: mix[3] };
}

/** A soft radial light, drawn once on a 2D canvas and reused for every glow. */
function makeGlowTexture(): Texture {
  const size = 64;
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d")!;
  const gradient = ctx.createRadialGradient(size / 2, size / 2, 2, size / 2, size / 2, size / 2);
  gradient.addColorStop(0, "rgba(255, 200, 110, 0.9)");
  gradient.addColorStop(0.5, "rgba(255, 160, 70, 0.35)");
  gradient.addColorStop(1, "rgba(255, 140, 50, 0)");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, size, size);
  return Texture.from(canvas);
}

type Ember = { sprite: Sprite; x: number; y: number; vy: number; sway: number; life: number; maxLife: number };

type Atlas = {
  frameSize: number;
  animations: Record<string, { sheet: string; frames: number; fps: number }>;
};

// Pixel art: never smooth a texel.
TextureStyle.defaultOptions.scaleMode = "nearest";

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

/** The DOM renderer's camera, verbatim: center small maps, clamp large ones. */
function cameraFor(map: WorldMap, pos: WorldPosition): { x: number; y: number } {
  const x =
    map.width <= VIEW_W
      ? -Math.floor((VIEW_W - map.width) / 2)
      : clamp(pos.x - Math.floor(VIEW_W / 2), 0, map.width - VIEW_W);
  const y =
    map.height <= VIEW_H
      ? -Math.floor((VIEW_H - map.height) / 2)
      : clamp(pos.y - Math.floor(VIEW_H / 2), 0, map.height - VIEW_H);
  return { x, y };
}

/**
 * The WebGL world renderer (Painted World G2). Owns a Pixi Application and a
 * scene it rebuilds per map; `update(state)` feeds it fresh game state and the
 * ticker animates sprites and eases positions toward their targets. It never
 * touches the store: input goes back out through the onTileClick callback.
 */
export class WorldRenderer {
  private app: Application | null = null;
  private root = new Container();
  private mapC = new Container();
  private frames = new Map<string, Texture[]>();
  private waterSprites: Sprite[] = [];
  private npcSprites: { npc: Npc; sprite: Sprite; target: { x: number; y: number } }[] = [];
  private hero: Sprite | null = null;
  private heroFrames: Texture[] | null = null;
  private heroTarget = { x: 0, y: 0 };
  private heroFlip = false;
  private walkUntil = 0;
  private lastPos: string | null = null;
  private cam = { x: 0, y: 0 };
  private camTarget = { x: 0, y: 0 };
  private mapId: string | null = null;
  private scale = 2;
  private clock = 0;
  private destroyed = false;
  private sky: Graphics | null = null;
  private lightC = new Container();
  private skyTarget = { color: 0, alpha: 0 };
  private glowTexture: Texture | null = null;
  private glows: Sprite[] = [];
  private embers: Ember[] = [];
  private ashTiles: { x: number; y: number }[] = [];
  private outdoor = false;

  private onTileClick: (x: number, y: number) => void;

  constructor(onTileClick: (x: number, y: number) => void) {
    this.onTileClick = onTileClick;
  }

  async init(host: HTMLElement, scale: number): Promise<void> {
    this.scale = scale;
    const app = new Application();
    await app.init({
      width: VIEW_W * ART * scale,
      height: VIEW_H * ART * scale,
      background: 0x0d0e13,
      antialias: false,
    });
    if (this.destroyed) {
      app.destroy(true, { children: true });
      return;
    }
    this.app = app;
    host.appendChild(app.canvas);
    await this.loadAssets();
    if (this.destroyed) return;

    this.root.scale.set(scale);
    this.root.addChild(this.mapC);
    // The sky overlay covers the viewport (not the map): night follows the camera.
    this.sky = new Graphics().rect(0, 0, VIEW_W * ART, VIEW_H * ART).fill(0xffffff);
    this.sky.alpha = 0;
    this.root.addChild(this.sky);
    // Lights and embers live above the darkness, world-anchored like the map.
    this.root.addChild(this.lightC);
    this.glowTexture = makeGlowTexture();
    app.stage.addChild(this.root);

    app.canvas.addEventListener("pointerdown", this.onPointerDown);
    app.ticker.add(() => this.tick(app.ticker.deltaMS));
  }

  private onPointerDown = (event: PointerEvent) => {
    const canvas = this.app?.canvas;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const x = Math.floor((event.clientX - rect.left) / this.scale / ART + this.camTarget.x);
    const y = Math.floor((event.clientY - rect.top) / this.scale / ART + this.camTarget.y);
    this.onTileClick(x, y);
  };

  private async loadAssets(): Promise<void> {
    const base = import.meta.env.BASE_URL;
    const atlas: Atlas = await Assets.load({ alias: "atlas", src: `${base}sprites/atlas.json` });
    const tiles = [...new Set(Object.values(TILES).map((t) => t.sprite))];
    await Assets.load([
      ...tiles.map((name) => ({ alias: name, src: `${base}sprites/${name}.png` })),
      { alias: "overlay_wild", src: `${base}sprites/overlay_wild.png` },
      ...Object.entries(atlas.animations).map(([name, anim]) => ({
        alias: name,
        src: `${base}sprites/${anim.sheet}`,
      })),
    ]);
    // Slice every sheet into per-frame textures once.
    for (const [name, anim] of Object.entries(atlas.animations)) {
      const source = (Assets.get(name) as Texture).source;
      this.frames.set(
        name,
        Array.from(
          { length: anim.frames },
          (_, i) => new Texture({ source, frame: new Rectangle(i * ART, 0, ART, ART) }),
        ),
      );
    }
  }

  /** Feed fresh state: rebuild on map change, retarget hero/NPCs/camera otherwise. */
  update(state: GameState): void {
    const pos = state.world?.position;
    if (!pos || !this.app) return;
    const map = getMap(pos.mapId);
    if (this.mapId !== map.id) {
      this.buildMap(map, state);
      this.mapId = map.id;
      this.cam = cameraFor(map, pos);
      this.heroTarget = { x: pos.x * ART, y: pos.y * ART };
      this.hero?.position.set(this.heroTarget.x + ART / 2, this.heroTarget.y);
      this.lastPos = `${pos.x},${pos.y}`;
    }
    const key = `${pos.x},${pos.y}`;
    if (key !== this.lastPos) {
      this.walkUntil = this.clock + WALK_LINGER_MS;
      this.lastPos = key;
    }
    this.heroTarget = { x: pos.x * ART, y: pos.y * ART };
    this.heroFlip = pos.facing === "left";
    this.camTarget = cameraFor(map, pos);
    this.skyTarget = this.outdoor ? skyAt(state.worldSteps) : { color: 0, alpha: 0 };
    for (const entry of this.npcSprites) {
      const at = npcPosition(entry.npc, state.worldSteps);
      entry.target = { x: at.x * ART, y: at.y * ART };
    }
  }

  private buildMap(map: WorldMap, state: GameState): void {
    this.mapC.removeChildren();
    this.lightC.removeChildren();
    this.waterSprites = [];
    this.npcSprites = [];
    this.glows = [];
    this.embers = [];
    this.ashTiles = [];
    this.outdoor = OUTDOOR_MAPS.has(map.id);

    for (let y = 0; y < map.height; y++) {
      for (let x = 0; x < map.width; x++) {
        const tile = map.tiles[y][x];
        const sprite = new Sprite(
          tile === "water" ? this.frames.get("water_shimmer")![0] : (Assets.get(TILES[tile].sprite) as Texture),
        );
        sprite.position.set(x * ART, y * ART);
        this.mapC.addChild(sprite);
        if (tile === "water") this.waterSprites.push(sprite);
        // Dangerous ground stays visible: wild-region tiles grow dark tufts.
        if (WILD_TILES.has(tile) && regionAt(map, x, y) !== null) {
          const tuft = new Sprite(Assets.get("overlay_wild") as Texture);
          tuft.position.set(x * ART, y * ART);
          this.mapC.addChild(tuft);
        }
        if (this.outdoor && regionAt(map, x, y) === "ash") this.ashTiles.push({ x, y });
        // Doors, lamps and the shrine glow after dark.
        if (this.outdoor && this.glowTexture && (tile === "door" || tile === "shrine" || tile === "lamp")) {
          const glow = new Sprite(this.glowTexture);
          glow.anchor.set(0.5);
          glow.position.set(x * ART + ART / 2, y * ART + ART / 2);
          glow.width = ART * 3;
          glow.height = ART * 3;
          glow.blendMode = "add";
          glow.alpha = 0;
          this.lightC.addChild(glow);
          this.glows.push(glow);
        }
      }
    }

    for (const npc of npcsOn(map.id)) {
      const sheet = this.frames.get(`${npc.sprite}_idle`);
      const sprite = new Sprite(sheet ? sheet[0] : (Assets.get(npc.sprite) as Texture));
      const at = npcPosition(npc, state.worldSteps);
      sprite.position.set(at.x * ART, at.y * ART);
      this.mapC.addChild(sprite);
      this.npcSprites.push({ npc, sprite, target: { x: at.x * ART, y: at.y * ART } });
    }

    const role = ROLES[state.hero?.roleId ?? "warrior"];
    this.heroFrames = this.frames.get(`${role.sprite}_walk`) ?? null;
    this.hero = new Sprite(this.heroFrames?.[0]);
    this.hero.anchor.set(0.5, 0);
    this.mapC.addChild(this.hero);
  }

  private tick(deltaMS: number): void {
    this.clock += deltaMS;
    // Exponential ease: frame-rate independent, snaps when close.
    const t = 1 - Math.exp(-deltaMS / 55);
    const ease = (from: number, to: number) => (Math.abs(to - from) < 0.3 ? to : from + (to - from) * t);

    this.cam = { x: ease(this.cam.x, this.camTarget.x), y: ease(this.cam.y, this.camTarget.y) };
    this.mapC.position.set(-this.cam.x * ART, -this.cam.y * ART);
    this.lightC.position.copyFrom(this.mapC.position);

    // Sky drifts toward its target so dusk falls rather than snaps.
    if (this.sky) {
      this.sky.tint = this.skyTarget.color;
      this.sky.alpha += (this.skyTarget.alpha - this.sky.alpha) * (1 - Math.exp(-deltaMS / 400));
      const darkness = Math.min(1, this.sky.alpha / 0.36);
      for (const glow of this.glows) {
        glow.alpha = darkness * (0.75 + 0.25 * Math.sin(this.clock / 300 + glow.position.x));
      }
    }
    this.tickEmbers(deltaMS);

    const water = this.frames.get("water_shimmer");
    if (water) {
      const frame = water[Math.floor(this.clock / WATER_MS) % water.length];
      for (const sprite of this.waterSprites) sprite.texture = frame;
    }

    for (const { npc, sprite, target } of this.npcSprites) {
      sprite.position.set(ease(sprite.position.x, target.x), ease(sprite.position.y, target.y));
      const sheet = this.frames.get(`${npc.sprite}_idle`);
      if (sheet) sprite.texture = sheet[Math.floor(this.clock / IDLE_MS) % sheet.length];
    }

    if (this.hero && this.heroFrames) {
      const cx = this.heroTarget.x + ART / 2;
      this.hero.position.set(ease(this.hero.position.x, cx), ease(this.hero.position.y, this.heroTarget.y));
      this.hero.scale.x = this.heroFlip ? -1 : 1;
      const walking = this.clock < this.walkUntil;
      this.hero.texture = walking
        ? this.heroFrames[Math.floor(this.clock / WALK_MS) % this.heroFrames.length]
        : this.heroFrames[0];
    }
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
      sprite.tint = EMBER_TINTS[Math.floor(Math.random() * EMBER_TINTS.length)];
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

  destroy(): void {
    this.destroyed = true;
    this.app?.canvas.removeEventListener("pointerdown", this.onPointerDown);
    this.app?.destroy(true, { children: true });
    this.app = null;
  }
}
