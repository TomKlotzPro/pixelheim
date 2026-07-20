import { Color, DirectionalLight, Group, HemisphereLight, PointLight, type Vector3 } from "three";
import type { WorldMap } from "../../world/types";
import { ART } from "./voxelData";

/**
 * The same day/night wheel as the Pixi renderer (worldAtmosphere.ts), turned
 * by worldSteps. There the ramp tints a screen overlay; here it drives a real
 * light rig - the numbers stay in lockstep so both renderers share one clock.
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

function skyAt(steps: number): { color: Color; alpha: number } {
  const t = (steps % DAY_CYCLE_STEPS) / DAY_CYCLE_STEPS;
  let i = 0;
  while (i < SKY_STOPS.length - 2 && SKY_STOPS[i + 1].at < t) i++;
  const a = SKY_STOPS[i];
  const b = SKY_STOPS[i + 1];
  const k = (t - a.at) / (b.at - a.at || 1);
  const mix = a.color.map((v, c) => v + (b.color[c] - v) * k);
  return { color: new Color(mix[0] / 255, mix[1] / 255, mix[2] / 255), alpha: mix[3] };
}

const SUN_DAY = new Color("#fff3dc");
const SUN_ELEVATION = Math.PI * 0.24;
const SUN_DISTANCE = 420;
const LIGHT_CAP = 32;

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

  constructor() {
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
    this.group.add(this.hemi, this.sun, this.sun.target);
  }

  build(map: WorldMap, outdoor: boolean): void {
    this.outdoor = outdoor;
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
  }

  update(worldSteps: number): void {
    this.steps = worldSteps;
    this.darknessTarget = this.outdoor ? Math.min(1, skyAt(worldSteps).alpha / 0.36) : 0;
  }

  /** Eases the sky and flickers the fires; the sun rides along with the camera. */
  tick(deltaMS: number, clock: number, center: Vector3): void {
    this.darkness += (this.darknessTarget - this.darkness) * (1 - Math.exp(-deltaMS / 400));
    const dark = this.darkness;

    const sky = skyAt(this.steps);
    this.sun.color.copy(SUN_DAY);
    if (sky.alpha > 0.01) this.sun.color.lerp(sky.color, Math.min(1, sky.alpha * 2.4));
    this.sun.intensity = this.outdoor ? 1.15 - 0.95 * dark : 0.95;
    this.hemi.intensity = 0.9 - 0.55 * dark;

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
  }
}
