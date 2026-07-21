import {
  ACESFilmicToneMapping,
  Color,
  DirectionalLight,
  Fog,
  MeshLambertMaterial,
  OrthographicCamera,
  PCFSoftShadowMap,
  Raycaster,
  Scene,
  Vector2,
  Vector3,
  WebGLRenderer,
} from "three";
import { loadSettings } from "../../app/settings";
import type { GameState } from "../../game/types";
import { getMap } from "../../world/maps/index";
import { VoxelActors } from "./voxelActors";
import { VoxelAtmosphere } from "./voxelAtmosphere";
import { ART, loadVoxelSheet, type VoxelSheet } from "./voxelData";
import { GROUND_TOP, VoxelTerrain } from "./voxelTerrain";
import { cameraFor, OUTDOOR_MAPS, VIEW_H, VIEW_W, type WorldRenderer } from "../worldCamera";

export { VIEW_H, VIEW_W } from "../worldCamera";

const CAMERA_PITCH = Math.PI * 0.19; // ~34 degrees down: facades in view
const CAMERA_DISTANCE = 620;

/**
 * The voxel world renderer (PIX-111): a three.js scene extruded live from the
 * same ASCII grids the PNGs are baked from. Same contract as the Pixi
 * renderer - init/update/destroy plus onTileClick - so the store neither
 * knows nor cares which world it is drawing.
 */
export class VoxelWorldRenderer implements WorldRenderer {
  private renderer: WebGLRenderer | null = null;
  private scene = new Scene();
  private camera: OrthographicCamera;
  private material = new MeshLambertMaterial({ vertexColors: true });
  private waterMaterial = new MeshLambertMaterial({ vertexColors: true, transparent: true, opacity: 0.82 });
  private terrain = new VoxelTerrain(this.material, this.waterMaterial);
  private actors = new VoxelActors();
  private atmosphere = new VoxelAtmosphere(loadSettings().reduceMotion);
  private sheet: VoxelSheet | null = null;
  private cam = { x: 0, y: 0 };
  private camTarget = { x: 0, y: 0 };
  private center = new Vector3();
  private reduceMotion = loadSettings().reduceMotion;
  private mapId: string | null = null;
  private clock = 0;
  private lastTime: number | null = null;
  private destroyed = false;

  private onTileClick: (x: number, y: number) => void;

  /**
   * A soft lamp riding on the camera: figures and facades face the viewer,
   * and the sun alone leaves them in the dark half the day. No shadows -
   * it fills, the sun models.
   */
  private fill = new DirectionalLight(0xfff0dd, 0.72);

  constructor(onTileClick: (x: number, y: number) => void) {
    this.onTileClick = onTileClick;
    const w = VIEW_W * ART;
    const h = VIEW_H * ART;
    this.camera = new OrthographicCamera(-w / 2, w / 2, h / 2, -h / 2, 1, 2500);
    this.scene.background = new Color(0x0d0e13);
    // A whisper of depth: the far edge of the diorama recedes into the frame.
    this.scene.fog = new Fog(0x0d0e13, CAMERA_DISTANCE + 40, CAMERA_DISTANCE + 620);
    this.scene.add(this.terrain.group, this.actors.group, this.atmosphere.group, this.fill, this.fill.target);
  }

  async init(host: HTMLElement, scale: number): Promise<void> {
    this.sheet = await loadVoxelSheet();
    if (this.destroyed) return;
    const renderer = new WebGLRenderer({ antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.setSize(VIEW_W * ART * scale, VIEW_H * ART * scale);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = PCFSoftShadowMap;
    renderer.toneMapping = ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.25;
    this.renderer = renderer;
    host.appendChild(renderer.domElement);
    renderer.domElement.addEventListener("pointerdown", this.onPointerDown);
    renderer.setAnimationLoop((time) => this.tick(time));
  }

  /** Pointer to tile: cast through the camera onto the ground plane. */
  private onPointerDown = (event: PointerEvent) => {
    const canvas = this.renderer?.domElement;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const ndc = new Vector2(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1,
    );
    const ray = new Raycaster();
    ray.setFromCamera(ndc, this.camera);
    const t = (GROUND_TOP - ray.ray.origin.y) / ray.ray.direction.y;
    if (!Number.isFinite(t) || t < 0) return;
    const point = ray.ray.origin.clone().addScaledVector(ray.ray.direction, t);
    this.onTileClick(Math.floor(point.x / ART), Math.floor(point.z / ART));
  };

  /** Feed fresh state: rebuild on map change, retarget layers otherwise. */
  update(state: GameState): void {
    const pos = state.world?.position;
    if (!pos || !this.renderer || !this.sheet) return;
    const map = getMap(pos.mapId);
    if (this.mapId !== map.id) {
      this.terrain.build(this.sheet, map);
      this.actors.build(this.sheet, map, state);
      this.atmosphere.build(map, OUTDOOR_MAPS.has(map.id), this.terrain.chimneyTops);
      this.mapId = map.id;
      this.cam = cameraFor(map, pos);
      this.actors.snapTo(pos.x, pos.y);
    }
    this.camTarget = cameraFor(map, pos);
    this.actors.update(map, state, this.clock);
    this.atmosphere.update(state.worldSteps);
  }

  private tick(time: number): void {
    if (!this.renderer) return;
    const deltaMS = this.lastTime === null ? 0 : Math.min(100, time - this.lastTime);
    this.lastTime = time;
    this.clock += deltaMS;

    // Exponential ease: frame-rate independent, snaps when close.
    const t = 1 - Math.exp(-deltaMS / 55);
    const ease = (from: number, to: number) => (Math.abs(to - from) < 0.3 ? to : from + (to - from) * t);

    this.cam = { x: ease(this.cam.x, this.camTarget.x), y: ease(this.cam.y, this.camTarget.y) };
    this.center.set((this.cam.x + VIEW_W / 2) * ART, 0, (this.cam.y + VIEW_H / 2) * ART);
    this.camera.position.set(
      this.center.x,
      Math.sin(CAMERA_PITCH) * CAMERA_DISTANCE,
      this.center.z + Math.cos(CAMERA_PITCH) * CAMERA_DISTANCE,
    );
    this.camera.lookAt(this.center);
    this.fill.position.copy(this.camera.position);
    this.fill.target.position.copy(this.center);

    if (!this.reduceMotion) this.terrain.tick(this.clock);
    this.actors.tick(this.clock, ease, this.reduceMotion);
    this.atmosphere.tick(deltaMS, this.clock, this.center);
    this.renderer.render(this.scene, this.camera);
  }

  destroy(): void {
    this.destroyed = true;
    this.renderer?.setAnimationLoop(null);
    this.renderer?.domElement.removeEventListener("pointerdown", this.onPointerDown);
    this.terrain.dispose();
    this.actors.destroy();
    this.material.dispose();
    this.waterMaterial.dispose();
    this.renderer?.dispose();
    this.renderer?.domElement.remove();
    this.renderer = null;
  }
}
