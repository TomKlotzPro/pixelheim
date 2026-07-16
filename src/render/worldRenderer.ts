import { Application, Assets, Container, Rectangle, Sprite, Texture, TextureStyle } from "pixi.js";
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
    for (const entry of this.npcSprites) {
      const at = npcPosition(entry.npc, state.worldSteps);
      entry.target = { x: at.x * ART, y: at.y * ART };
    }
  }

  private buildMap(map: WorldMap, state: GameState): void {
    this.mapC.removeChildren();
    this.waterSprites = [];
    this.npcSprites = [];

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

  destroy(): void {
    this.destroyed = true;
    this.app?.canvas.removeEventListener("pointerdown", this.onPointerDown);
    this.app?.destroy(true, { children: true });
    this.app = null;
  }
}
