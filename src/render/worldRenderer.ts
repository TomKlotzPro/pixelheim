import { Application, Assets, Container, Graphics, Sprite, type Texture } from "pixi.js";
import type { GameState } from "../game/types";
import { getMap } from "../world/maps/index";
import { TILES } from "../world/tiles";
import { loadSettings } from "../app/settings";
import { ART, type FrameBank, loadFrameBank, makeVignetteTexture } from "./pixiUtils";
import { ActorLayer } from "./worldActors";
import { AtmosphereLayer } from "./worldAtmosphere";
import { TerrainLayer } from "./worldTerrain";
import { cameraFor, OUTDOOR_MAPS, VIEW_H, VIEW_W, type WorldRenderer as WorldRendererContract } from "./worldCamera";

export { VIEW_H, VIEW_W } from "./worldCamera";

export { ART } from "./pixiUtils";
/**
 * The WebGL world renderer: a Pixi Application composing three scene layers -
 * terrain (ground), actors (people), atmosphere (light and weather) - plus
 * the camera. `update(state)` feeds it fresh game state; the ticker animates.
 * It never touches the store: input goes back out through onTileClick.
 */
export class WorldRenderer implements WorldRendererContract {
  private app: Application | null = null;
  private root = new Container();
  private mapC = new Container();
  private lightC = new Container();
  private terrain: TerrainLayer | null = null;
  private actors: ActorLayer | null = null;
  private atmosphere: AtmosphereLayer | null = null;
  private cam = { x: 0, y: 0 };
  private camTarget = { x: 0, y: 0 };
  private fade: Graphics | null = null;
  private reduceMotion = loadSettings().reduceMotion;
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

    const bank = await this.loadAssets();
    if (this.destroyed) return;
    this.terrain = new TerrainLayer(bank);
    this.actors = new ActorLayer(bank);

    this.root.scale.set(scale);
    this.root.addChild(this.mapC);
    // The sky overlay covers the viewport (not the map): night follows the camera.
    const sky = new Graphics().rect(0, 0, VIEW_W * ART, VIEW_H * ART).fill(0xffffff);
    sky.alpha = 0;
    this.root.addChild(sky);
    // Lights and embers live above the darkness, world-anchored like the map.
    this.root.addChild(this.lightC);
    this.atmosphere = new AtmosphereLayer(sky, this.lightC);
    // Quiet corner darkening: the frame recedes, the center breathes.
    this.root.addChild(new Sprite(makeVignetteTexture(VIEW_W * ART, VIEW_H * ART)));
    // Doors fade the world in: black above everything, eased away each tick.
    this.fade = new Graphics().rect(0, 0, VIEW_W * ART, VIEW_H * ART).fill(0x0d0e13);
    this.fade.alpha = 0;
    this.root.addChild(this.fade);
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

  private async loadAssets(): Promise<FrameBank> {
    const base = import.meta.env.BASE_URL;
    const tiles = [...new Set(Object.values(TILES).map((t) => t.sprite))];
    const [bank] = await Promise.all([
      loadFrameBank(),
      Assets.load([
        ...tiles.map((name) => ({ alias: name, src: `${base}sprites/${name}.png` })),
        { alias: "overlay_wild", src: `${base}sprites/overlay_wild.png` },
        { alias: "overlay_path_edge", src: `${base}sprites/overlay_path_edge.png` },
        { alias: "overlay_shore", src: `${base}sprites/overlay_shore.png` },
        { alias: "icon_anvil", src: `${base}sprites/icon_anvil.png` },
        { alias: "icon_cauldron", src: `${base}sprites/icon_cauldron.png` },
        { alias: "overlay_roofcut", src: `${base}sprites/overlay_roofcut.png` },
        { alias: "overlay_chimney", src: `${base}sprites/overlay_chimney.png` },
        ...["chest_closed", "chest_open", "road_glint", "herb_patch"].map((name) => ({
          alias: name,
          src: `${base}sprites/${name}.png`,
        })),
      ]) as Promise<Record<string, Texture>>,
    ]);
    return bank;
  }

  /** Feed fresh state: rebuild on map change, retarget layers otherwise. */
  update(state: GameState): void {
    const pos = state.world?.position;
    if (!pos || !this.app || !this.terrain || !this.actors || !this.atmosphere) return;
    const map = getMap(pos.mapId);
    if (this.mapId !== map.id) {
      this.mapC.removeChildren();
      this.terrain.build(this.mapC, map);
      this.actors.build(this.mapC, map, state, this.scale);
      this.atmosphere.build(map, OUTDOOR_MAPS.has(map.id));
      const firstBuild = this.mapId === null;
      this.mapId = map.id;
      this.cam = cameraFor(map, pos);
      this.actors.snapTo(pos.x, pos.y);
      if (this.fade && !firstBuild && !this.reduceMotion) this.fade.alpha = 1;
    }
    this.camTarget = cameraFor(map, pos);
    this.actors.update(map, state, this.clock);
    this.atmosphere.update(state.worldSteps);
  }

  private tick(deltaMS: number): void {
    this.clock += deltaMS;
    // Exponential ease: frame-rate independent, snaps when close.
    const t = 1 - Math.exp(-deltaMS / 55);
    const ease = (from: number, to: number) => (Math.abs(to - from) < 0.3 ? to : from + (to - from) * t);

    this.cam = { x: ease(this.cam.x, this.camTarget.x), y: ease(this.cam.y, this.camTarget.y) };
    this.mapC.position.set(-this.cam.x * ART, -this.cam.y * ART);
    this.lightC.position.copyFrom(this.mapC.position);

    this.terrain?.tick(this.clock);
    this.actors?.tick(this.clock, ease);
    this.atmosphere?.tick(deltaMS, this.clock);
    if (this.fade && this.fade.alpha > 0) {
      this.fade.alpha = Math.max(0, this.fade.alpha - deltaMS / 280);
    }
  }

  destroy(): void {
    this.destroyed = true;
    this.app?.canvas.removeEventListener("pointerdown", this.onPointerDown);
    this.app?.destroy(true, { children: true });
    this.app = null;
  }
}
