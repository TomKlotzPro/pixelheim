import {
  AdditiveBlending,
  BufferAttribute,
  BufferGeometry,
  Color,
  DirectionalLight,
  Group,
  HemisphereLight,
  PointLight,
  Points,
  PointsMaterial,
  type Vector3,
} from "three";
import { regionAt } from "../../world/parseMap";
import { DAY_CYCLE_STEPS, EMBER_CAP, EMBER_TINT_INTS, skyAt } from "../dayNight";
import type { WorldMap } from "../../world/types";
import { ART } from "./voxelData";

/**
 * The same day/night wheel as the Pixi renderer (worldAtmosphere.ts), turned
 * by worldSteps. There the ramp tints a screen overlay; here it drives a real
 * light rig - the numbers stay in lockstep so both renderers share one clock.
 */
/** Sky tint as three.js wants it: a Color + alpha. */
function skyTint(steps: number): { color: Color; alpha: number } {
  const { r, g, b, alpha } = skyAt(steps);
  return { color: new Color(r / 255, g / 255, b / 255), alpha };
}

const SUN_DAY = new Color("#fff3dc");
const SUN_ELEVATION = Math.PI * 0.27;
const SUN_DISTANCE = 420;
const LIGHT_CAP = 32;

const EMBER_TINTS = EMBER_TINT_INTS.map((tint) => new Color(tint));
const SMOKE_CAP = 24;
const SMOKE_TINT = new Color(0x2e3138);

type Ember = { x: number; y: number; z: number; vy: number; sway: number; life: number; maxLife: number; tint: Color };

/**
 * Sun, sky bounce, and fire: a directional sun whose angle and warmth follow
 * worldSteps, hemisphere fill that dims into the night, and point lights on
 * the tiles that glow in 2D - lamps and doors after dark, forges always.
 */
export class VoxelAtmosphere {
  readonly group = new Group();
  private hemi = new HemisphereLight(0xbdd1e8, 0x4a3f33, 0.9);
  private sun = new DirectionalLight(SUN_DAY, 1.1);
  private fires: { light: PointLight; always: boolean }[] = [];
  private outdoor = false;
  private steps = 0;
  private darkness = 0;
  private darknessTarget = 0;
  private reduceMotion: boolean;
  private ashTiles: { x: number; y: number }[] = [];
  private embers: Ember[] = [];
  private emberPoints: Points | null = null;
  private chimneys: { x: number; y: number; z: number }[] = [];
  private smoke: Ember[] = [];
  private smokePoints: Points | null = null;

  constructor(reduceMotion = false) {
    this.reduceMotion = reduceMotion;
    this.sun.castShadow = true;
    this.sun.shadow.mapSize.set(2048, 2048);
    const half = 12.5 * ART;
    this.sun.shadow.camera.left = -half;
    this.sun.shadow.camera.right = half;
    this.sun.shadow.camera.top = half;
    this.sun.shadow.camera.bottom = -half;
    this.sun.shadow.camera.near = 1;
    this.sun.shadow.camera.far = SUN_DISTANCE * 2.5;
    this.sun.shadow.bias = -0.0004;
    this.sun.shadow.normalBias = 0.6;
    // Shadows are a tone, not a hole: half-strength keeps the ground readable
    // under long morning light (Tom: "the player is still too shadowy").
    this.sun.shadow.intensity = 0.55;
    this.group.add(this.hemi, this.sun, this.sun.target);
  }

  build(map: WorldMap, outdoor: boolean, chimneys: { x: number; y: number; z: number }[] = []): void {
    this.outdoor = outdoor;
    this.chimneys = chimneys;
    for (const { light } of this.fires) this.group.remove(light);
    this.fires = [];
    for (let y = 0; y < map.height && this.fires.length < LIGHT_CAP; y++) {
      for (let x = 0; x < map.width && this.fires.length < LIGHT_CAP; x++) {
        const tile = map.tiles[y][x];
        const nightLight = outdoor && (tile === "door" || tile === "shrine" || tile === "lamp");
        const alwaysLight = tile === "forge" || tile === "hearth";
        if (!nightLight && !alwaysLight) continue;
        const light = new PointLight(0xffb066, 0, ART * 4.5, 1.7);
        light.position.set(x * ART + ART / 2, ART * 0.7, y * ART + ART / 2);
        this.group.add(light);
        this.fires.push({ light, always: alwaysLight });
      }
    }
    this.buildEmbers(map, outdoor);
    this.buildSmoke();
  }

  /** A second pool for the chimneys: pale wisps that widen as they climb. */
  private buildSmoke(): void {
    if (this.smokePoints) {
      this.smokePoints.geometry.dispose();
      (this.smokePoints.material as PointsMaterial).dispose();
      this.group.remove(this.smokePoints);
      this.smokePoints = null;
    }
    this.smoke = [];
    if (this.chimneys.length === 0 || this.reduceMotion) return;
    const geometry = new BufferGeometry();
    geometry.setAttribute("position", new BufferAttribute(new Float32Array(SMOKE_CAP * 3), 3));
    geometry.setAttribute("color", new BufferAttribute(new Float32Array(SMOKE_CAP * 3), 3));
    const material = new PointsMaterial({
      size: 3.4,
      vertexColors: true,
      blending: AdditiveBlending,
      transparent: true,
      depthWrite: false,
    });
    this.smokePoints = new Points(geometry, material);
    this.smokePoints.frustumCulled = false;
    this.group.add(this.smokePoints);
  }

  /** One recycled particle pool: embers drift up from ash ground, as in 2D. */
  private buildEmbers(map: WorldMap, outdoor: boolean): void {
    if (this.emberPoints) {
      this.emberPoints.geometry.dispose();
      (this.emberPoints.material as PointsMaterial).dispose();
      this.group.remove(this.emberPoints);
      this.emberPoints = null;
    }
    this.embers = [];
    this.ashTiles = [];
    if (!outdoor || this.reduceMotion) return;
    for (let y = 0; y < map.height; y++) {
      for (let x = 0; x < map.width; x++) {
        if (regionAt(map, x, y) === "ash") this.ashTiles.push({ x, y });
      }
    }
    if (this.ashTiles.length === 0) return;
    const geometry = new BufferGeometry();
    geometry.setAttribute("position", new BufferAttribute(new Float32Array(EMBER_CAP * 3), 3));
    geometry.setAttribute("color", new BufferAttribute(new Float32Array(EMBER_CAP * 3), 3));
    const material = new PointsMaterial({
      size: 2.2,
      vertexColors: true,
      blending: AdditiveBlending,
      transparent: true,
      depthWrite: false,
    });
    this.emberPoints = new Points(geometry, material);
    this.emberPoints.frustumCulled = false;
    this.group.add(this.emberPoints);
  }

  update(worldSteps: number): void {
    this.steps = worldSteps;
    this.darknessTarget = this.outdoor ? Math.min(1, skyTint(worldSteps).alpha / 0.36) : 0;
  }

  /** Eases the sky and flickers the fires; the sun rides along with the camera. */
  tick(deltaMS: number, clock: number, center: Vector3): void {
    this.darkness += (this.darknessTarget - this.darkness) * (1 - Math.exp(-deltaMS / 400));
    const dark = this.darkness;

    const sky = skyTint(this.steps);
    this.sun.color.copy(SUN_DAY);
    if (sky.alpha > 0.01) this.sun.color.lerp(sky.color, Math.min(1, sky.alpha * 2.4));
    // Shade stays readable: the hemisphere reaches into shadowed ground, so
    // a figure's cast shadow is a tone, not a hole (Tom: "always in shadow").
    this.sun.intensity = this.outdoor ? 1.08 - 0.88 * dark : 0.95;
    this.hemi.intensity = 0.98 - 0.55 * dark;

    // The sun wheels around the diorama over the day - east through south to
    // west, so the standing figures keep their faces lit; indoors it holds.
    const t = this.outdoor ? (this.steps % DAY_CYCLE_STEPS) / DAY_CYCLE_STEPS : 0.25;
    const azimuth = t * Math.PI * 2;
    this.sun.position.set(
      center.x + Math.cos(azimuth) * SUN_DISTANCE * Math.cos(SUN_ELEVATION),
      SUN_DISTANCE * Math.sin(SUN_ELEVATION),
      center.z + Math.sin(azimuth) * SUN_DISTANCE * Math.cos(SUN_ELEVATION),
    );
    this.sun.target.position.set(center.x, 0, center.z);

    for (const { light, always } of this.fires) {
      const strength = always ? 1 : dark;
      light.intensity = strength * ART * ART * 0.55 * (0.8 + 0.2 * Math.sin(clock / 300 + light.position.x));
    }

    this.tickEmbers(deltaMS);
    this.tickSmoke(deltaMS);
  }

  /** Wisps leave the chimney mouths, drift, and thin out into the sky. */
  private tickSmoke(deltaMS: number): void {
    if (!this.smokePoints || this.chimneys.length === 0) return;
    const cap = Math.min(SMOKE_CAP, this.chimneys.length * 4);
    if (this.smoke.length < cap && Math.random() < 0.18) {
      const at = this.chimneys[Math.floor(Math.random() * this.chimneys.length)];
      this.smoke.push({
        x: at.x + Math.random() * 2 - 1,
        y: at.y,
        z: at.z + Math.random() * 2 - 1,
        vy: 2.5 + Math.random() * 2,
        sway: Math.random() * Math.PI * 2,
        life: 0,
        maxLife: 3200 + Math.random() * 1800,
        tint: SMOKE_TINT,
      });
    }
    this.smoke = this.smoke.filter((wisp) => {
      wisp.life += deltaMS;
      wisp.y += (wisp.vy * deltaMS) / 1000;
      return wisp.life < wisp.maxLife;
    });
    const positions = this.smokePoints.geometry.getAttribute("position") as BufferAttribute;
    const colors = this.smokePoints.geometry.getAttribute("color") as BufferAttribute;
    for (let i = 0; i < SMOKE_CAP; i++) {
      const wisp = this.smoke[i];
      if (!wisp) {
        colors.setXYZ(i, 0, 0, 0);
        positions.setXYZ(i, 0, -50, 0);
        continue;
      }
      const k = wisp.life / wisp.maxLife;
      const fade = k < 0.2 ? k / 0.2 : 1 - (k - 0.2) / 0.8;
      positions.setXYZ(i, wisp.x + Math.sin(wisp.life / 600 + wisp.sway) * 3, wisp.y, wisp.z);
      colors.setXYZ(i, wisp.tint.r * fade, wisp.tint.g * fade, wisp.tint.b * fade);
    }
    positions.needsUpdate = true;
    colors.needsUpdate = true;
  }

  /** Embers rise from ash ground, sway, fade, and are reborn elsewhere. */
  private tickEmbers(deltaMS: number): void {
    if (!this.emberPoints || this.ashTiles.length === 0) return;
    const cap = Math.min(EMBER_CAP, this.ashTiles.length * 2);
    if (this.embers.length < cap && Math.random() < 0.3) {
      const at = this.ashTiles[Math.floor(Math.random() * this.ashTiles.length)];
      this.embers.push({
        x: at.x * ART + Math.random() * ART,
        y: 1,
        z: at.y * ART + Math.random() * ART,
        vy: 4 + Math.random() * 5,
        sway: Math.random() * Math.PI * 2,
        life: 0,
        maxLife: 2200 + Math.random() * 1600,
        tint: EMBER_TINTS[Math.floor(Math.random() * EMBER_TINTS.length)],
      });
    }
    this.embers = this.embers.filter((ember) => {
      ember.life += deltaMS;
      ember.y += (ember.vy * deltaMS) / 1000;
      return ember.life < ember.maxLife;
    });
    const positions = this.emberPoints.geometry.getAttribute("position") as BufferAttribute;
    const colors = this.emberPoints.geometry.getAttribute("color") as BufferAttribute;
    for (let i = 0; i < EMBER_CAP; i++) {
      const ember = this.embers[i];
      if (!ember) {
        colors.setXYZ(i, 0, 0, 0); // additive black: invisible
        positions.setXYZ(i, 0, -50, 0);
        continue;
      }
      const k = ember.life / ember.maxLife;
      const fade = k < 0.15 ? k / 0.15 : 1 - (k - 0.15) / 0.85;
      positions.setXYZ(i, ember.x + Math.sin(ember.life / 400 + ember.sway) * 2.5, ember.y, ember.z);
      colors.setXYZ(i, ember.tint.r * fade, ember.tint.g * fade, ember.tint.b * fade);
    }
    positions.needsUpdate = true;
    colors.needsUpdate = true;
  }
}
