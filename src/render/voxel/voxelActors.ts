import {
  type BufferGeometry,
  CanvasTexture,
  Color,
  Group,
  Mesh,
  MeshBasicMaterial,
  MeshLambertMaterial,
  NearestFilter,
  Sprite as BillboardSprite,
  SpriteMaterial,
} from "three";
import { heroSprite } from "../../game/hero/character";
import { outfitFor } from "../../game/economy/wearables";
import { outfitKey } from "../outfit";
import { rankPresence } from "../../game/hero/ranks";
import type { GameState } from "../../game/types";
import { spawnSpecies } from "../../game/combat/encounters";
import { getMonster } from "../../game/combat/monsters";
import { type Chest, chestSpriteName, chestsOn } from "../../world/chests";
import { furnitureOn } from "../../game/economy/house";
import { getItem } from "../../game/economy/items";
import { npcPosition, npcsOn, type Npc } from "../../world/npcs";
import { interactionPrompt } from "../../world/interactionPrompt";
import { type MonsterSpawn, spawnPosition, spawnRegion, spawnsOn } from "../../world/spawns";
import { signsOn } from "../../world/signs";
import type { WorldMap } from "../../world/types";
import { GROUND_TOP } from "./voxelTerrain";
import {
  ACTOR_OMIT,
  ART,
  type ColorGrid,
  colorGrid,
  heroStrideGrids,
  heroStrideGeometries,
  idleFrameGrids,
  overlayGrids,
  uprightGeometry,
  type VoxelSheet,
  strideGeometries,
} from "./voxelData";

const WALK_MS = 140;
const WALK_LINGER_MS = 240;

/** Same de-synced idle beat as the Pixi actors: nobody breathes in unison. */
function idleBeat(id: string): { phase: number; period: number } {
  let h = 0;
  for (const c of id) h = (h * 31 + c.charCodeAt(0)) % 9973;
  return { phase: h, period: 420 + (h % 5) * 45 };
}

/** The talk prompt, as voxels: a bright "!" that ignores the night. */
const PROMPT_GRID: ColorGrid = ["Y", "Y", "Y", "Y", ".", "Y"].map((ch) => [ch === "." ? null : "#ffd469"]);

/** The wooden door plate as a crisp canvas texture, same palette as Pixi's. */
function makeSignTexture(label: string): { texture: CanvasTexture; w: number; h: number } {
  const scale = 6;
  const canvas = document.createElement("canvas");
  const ctx = canvas.getContext("2d")!;
  ctx.font = `bold ${7 * scale}px monospace`;
  const w = Math.ceil(ctx.measureText(label).width) + 6 * scale;
  const h = 11 * scale;
  canvas.width = w;
  canvas.height = h;
  const c = canvas.getContext("2d")!;
  c.fillStyle = "#2a2118";
  c.fillRect(0, 0, w, h);
  c.fillStyle = "#8a6238";
  c.fillRect(0, 0, w, scale);
  c.fillStyle = "#5c3f24";
  c.fillRect(0, h - scale, w, scale);
  c.fillStyle = "#e8c34a";
  c.font = `bold ${7 * scale}px monospace`;
  c.textAlign = "center";
  c.textBaseline = "middle";
  c.fillText(label, w / 2, h / 2 + scale / 2);
  const texture = new CanvasTexture(canvas);
  texture.magFilter = NearestFilter;
  texture.minFilter = NearestFilter;
  return { texture, w: w / scale, h: h / scale };
}

type Walker = { mesh: Mesh; frames: BufferGeometry[]; target: { x: number; z: number } };

/**
 * The people as voxel figures, extruded from the same grids as their PNGs.
 * The hero wears the outfit grids painted over the body grid (PIX-107, in 3D
 * for free); walking bobs the figure; the sun does the shadows.
 */
export class VoxelActors {
  readonly group = new Group();
  /**
   * Figures get their own material with a gentle emissive floor: the hero
   * should read bright and heroic even when the sun is behind the building.
   * Terrain keeps the plain material so shadows stay dramatic there.
   */
  private figureMaterial: MeshLambertMaterial;
  private promptMaterial = new MeshBasicMaterial({ vertexColors: true });
  private sheet: VoxelSheet | null = null;

  private npcs: (Walker & { npc: Npc })[] = [];
  private monsters: (Walker & { spawn: MonsterSpawn })[] = [];
  private chests: { chest: Chest; mesh: Mesh; shownSprite: string | null }[] = [];
  private furniture: Mesh[] = [];
  private furnitureKey: string | null = null;
  private signs: BillboardSprite[] = [];
  private signKey = "";
  private hero: Mesh | null = null;
  private heroFrames: BufferGeometry[] = [];
  private heroFramesUp: BufferGeometry[] = [];
  private heroFacingUp = false;
  private heroTarget = { x: 0, z: 0 };
  private heroFlip = false;
  private heroPresence = 1;
  private heroKey = "";
  private walkUntil = 0;
  private lastPos: string | null = null;
  private prompt: Mesh | null = null;

  constructor() {
    this.figureMaterial = new MeshLambertMaterial({ vertexColors: true, emissive: new Color(0x33333a) });
  }

  /** A figure with its true 2-beat idle frames, extruded like the 2D sheets. */
  private figure(spriteName: string, depth = 2): { mesh: Mesh; frames: BufferGeometry[] } {
    const sprite = this.sheet!.sprites[spriteName];
    const grid = sprite ? colorGrid(sprite, ACTOR_OMIT) : PROMPT_GRID;
    const frames = idleFrameGrids(grid).map((frame) => uprightGeometry(frame, depth));
    const mesh = new Mesh(frames[0], this.figureMaterial);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    return { mesh, frames };
  }

  build(sheet: VoxelSheet, map: WorldMap, state: GameState): void {
    this.dispose();
    this.sheet = sheet;

    this.chests = [];
    for (const chest of chestsOn(map.id)) {
      const shown = chestSpriteName(chest, (state.world?.openedChests ?? []).includes(chest.id));
      const { mesh, frames } = this.figure(shown ?? "chest_closed", 4);
      frames[1].dispose(); // furniture holds still
      mesh.position.set(chest.x * ART + ART / 2, GROUND_TOP, chest.y * ART + ART / 2);
      mesh.visible = shown !== null;
      this.group.add(mesh);
      this.chests.push({ chest, mesh, shownSprite: shown });
    }
    this.furnitureKey = null;
    this.furniture = [];
    this.syncFurniture(map, state);

    this.npcs = [];
    for (const npc of npcsOn(map.id)) {
      const { mesh, frames } = this.figure(npc.sprite);
      const at = npcPosition(npc, state.worldSteps);
      mesh.position.set(at.x * ART + ART / 2, GROUND_TOP, at.y * ART + ART / 2);
      this.group.add(mesh);
      this.npcs.push({ npc, mesh, frames, target: { x: mesh.position.x, z: mesh.position.z } });
    }

    this.monsters = [];
    for (const spawn of spawnsOn(map.id)) {
      const species = getMonster(spawnSpecies(spawnRegion(spawn), spawn.x * 31 + spawn.y));
      const { mesh, frames } = this.figure(species.sprite);
      const at = spawnPosition(spawn, state.worldSteps);
      mesh.position.set(at.x * ART + ART / 2, GROUND_TOP, at.y * ART + ART / 2);
      this.group.add(mesh);
      this.monsters.push({ spawn, mesh, frames, target: { x: mesh.position.x, z: mesh.position.z } });
    }

    this.heroKey = "";
    this.hero = null;
    this.dressHero(state);

    this.signKey = "";
    this.rebuildSigns(map, state);

    this.prompt = new Mesh(uprightGeometry(PROMPT_GRID, 2), this.promptMaterial);
    this.prompt.visible = false;
    this.group.add(this.prompt);
  }

  /** Wooden plates over the doors, as camera-facing billboards. */
  private rebuildSigns(map: WorldMap, state: GameState): void {
    const signs = signsOn(map.id, state.house.owned);
    const key = signs.map((sign) => `${sign.x},${sign.y}:${sign.label}`).join("|");
    if (key === this.signKey) return;
    this.signKey = key;
    for (const sign of this.signs) {
      sign.material.map?.dispose();
      sign.material.dispose();
      this.group.remove(sign);
    }
    this.signs = [];
    for (const sign of signs) {
      const { texture, w, h } = makeSignTexture(sign.label);
      const plate = new BillboardSprite(new SpriteMaterial({ map: texture, transparent: true }));
      plate.scale.set(w * 0.8, h * 0.8, 1);
      // hung against the facade above the door - never inside the wall, however
      // tall the building (two-story walls swallowed centered plates, PIX-114)
      plate.position.set(sign.x * ART + ART / 2, GROUND_TOP + 11.2, sign.y * ART + ART + 2.4);
      this.group.add(plate);
      this.signs.push(plate);
    }
  }

  /** Snap the hero into place after a map change. */
  snapTo(x: number, y: number): void {
    this.heroTarget = { x: x * ART + ART / 2, z: y * ART + ART / 2 };
    this.hero?.position.set(this.heroTarget.x, GROUND_TOP, this.heroTarget.z);
    this.lastPos = `${x},${y}`;
  }

  /** The dressed figure: body grid + worn gear grids, extruded together. */
  private dressHero(state: GameState): void {
    if (!this.sheet) return;
    const sheetName = state.hero ? heroSprite(state.hero) : "hero_warrior";
    const outfit = state.hero ? outfitFor(state.gear, state.equipped) : [];
    const dressKey = outfitKey(sheetName, outfit);
    if (dressKey === this.heroKey) return;
    this.heroKey = dressKey;
    const body = this.sheet.sprites[sheetName] ?? this.sheet.sprites.hero_warrior;
    const wears = outfit
      .map((name) => this.sheet!.sprites[name])
      .filter((sprite) => sprite !== undefined)
      .map((sprite) => colorGrid(sprite));
    // The drawn walk frames (PIX-117), extruded per frame: gear composes
    // first, so plate and blade ride the step exactly as the 2D sheets do.
    // Sheets without authored strides fall back to the synthesized gait.
    for (const frame of [...this.heroFrames, ...this.heroFramesUp]) frame.dispose();
    const drawn = heroStrideGrids(this.sheet, sheetName, body, wears);
    this.heroFrames = drawn
      ? heroStrideGeometries(drawn, 2)
      : strideGeometries(overlayGrids(colorGrid(body, ACTOR_OMIT), wears), 2);
    const drawnUp = heroStrideGrids(this.sheet, sheetName, body, wears, "up");
    this.heroFramesUp = drawnUp ? heroStrideGeometries(drawnUp, 2) : [];
    if (this.hero) {
      this.hero.geometry = this.heroFrames[0];
    } else {
      this.hero = new Mesh(this.heroFrames[0], this.figureMaterial);
      this.hero.castShadow = true;
      this.hero.receiveShadow = true;
      this.group.add(this.hero);
    }
    this.heroPresence = state.hero ? rankPresence(state.hero.level) : 1;
  }

  /** Placed furniture (PIX-34): extruded like the actors, rugs laid flat. */
  private syncFurniture(map: WorldMap, state: GameState): void {
    const placed = furnitureOn(state, map.id);
    const key = placed.map((f) => `${f.itemId}:${f.x},${f.y}`).join("|");
    if (key === this.furnitureKey || !this.sheet) return;
    this.furnitureKey = key;
    for (const mesh of this.furniture) {
      mesh.geometry.dispose();
      this.group.remove(mesh);
    }
    this.furniture = [];
    for (const f of placed) {
      const sprite = this.sheet.sprites[getItem(f.itemId).sprite];
      if (!sprite) continue;
      const flat = f.itemId === "furn_rug";
      const mesh = new Mesh(uprightGeometry(colorGrid(sprite), flat ? 1 : 3), this.figureMaterial);
      if (flat) {
        mesh.rotation.x = -Math.PI / 2;
        mesh.position.set(f.x * ART + ART / 2, GROUND_TOP + 0.4, f.y * ART + ART);
      } else {
        mesh.position.set(f.x * ART + ART / 2, GROUND_TOP, f.y * ART + ART / 2);
        mesh.castShadow = true;
      }
      mesh.receiveShadow = true;
      this.group.add(mesh);
      this.furniture.push(mesh);
    }
  }

  update(map: WorldMap, state: GameState, clock: number): void {
    this.syncFurniture(map, state);
    const pos = state.world!.position;
    const key = `${pos.x},${pos.y}`;
    if (key !== this.lastPos) {
      this.walkUntil = clock + WALK_LINGER_MS;
      this.lastPos = key;
    }
    this.heroTarget = { x: pos.x * ART + ART / 2, z: pos.y * ART + ART / 2 };
    this.heroFlip = pos.facing === "left";
    this.heroFacingUp = pos.facing === "up";
    this.dressHero(state);
    this.rebuildSigns(map, state);

    for (const entry of this.npcs) {
      const at = npcPosition(entry.npc, state.worldSteps);
      entry.target = { x: at.x * ART + ART / 2, z: at.y * ART + ART / 2 };
    }
    for (const entry of this.monsters) {
      entry.mesh.visible = !(state.world?.slain ?? []).includes(entry.spawn.id);
      const at = spawnPosition(entry.spawn, state.worldSteps);
      entry.target = { x: at.x * ART + ART / 2, z: at.y * ART + ART / 2 };
    }
    for (const entry of this.chests) {
      const shown = chestSpriteName(entry.chest, (state.world?.openedChests ?? []).includes(entry.chest.id));
      entry.mesh.visible = shown !== null;
      if (shown && shown !== entry.shownSprite && this.sheet) {
        entry.shownSprite = shown;
        entry.mesh.geometry.dispose();
        const sprite = this.sheet.sprites[shown];
        if (sprite) entry.mesh.geometry = uprightGeometry(colorGrid(sprite), 4);
      }
    }

    // Someone to talk to (or something to open): same rules as the 2D world.
    if (this.prompt) {
      const at = interactionPrompt(state, map.id);
      this.prompt.visible = at !== null;
      if (at) this.prompt.position.set(at.x * ART + ART / 2, GROUND_TOP + ART + 3, at.y * ART + ART / 2);
    }
  }

  tick(clock: number, ease: (from: number, to: number) => number, reduceMotion: boolean): void {
    // True frame animation, not a bob: idle figures breathe on their own
    // de-synced beat, exactly like the 2D idle sheets.
    for (const { npc, mesh, frames, target } of this.npcs) {
      const beat = idleBeat(npc.id);
      mesh.geometry = reduceMotion ? frames[0] : frames[Math.floor((clock + beat.phase) / beat.period) % frames.length];
      mesh.position.set(ease(mesh.position.x, target.x), GROUND_TOP, ease(mesh.position.z, target.z));
    }
    for (const { spawn, mesh, frames, target } of this.monsters) {
      const beat = idleBeat(spawn.id);
      mesh.geometry = reduceMotion ? frames[0] : frames[Math.floor((clock + beat.phase) / beat.period) % frames.length];
      mesh.position.set(ease(mesh.position.x, target.x), GROUND_TOP, ease(mesh.position.z, target.z));
    }

    if (this.hero && this.heroFrames.length > 0) {
      // The 4-beat walk plays while steps land; standing rests on frame 0.
      // 3D can afford drama the 16px sprite could not: the frames carry the
      // footwork, a hop carries the weight, and a waddle carries the charm.
      const walking = clock < this.walkUntil && !reduceMotion;
      const beat = clock / WALK_MS;
      // Walking away shows the hero's back (PIX-117), same as the 2D sheets.
      const frames = this.heroFacingUp && this.heroFramesUp.length > 0 ? this.heroFramesUp : this.heroFrames;
      this.hero.geometry = walking ? frames[Math.floor(beat) % frames.length] : frames[0];
      const hop = walking ? Math.abs(Math.sin(beat * Math.PI)) * 1.8 : 0;
      this.hero.rotation.z = walking ? Math.sin(beat * Math.PI) * 0.18 : 0;
      this.hero.position.set(
        ease(this.hero.position.x, this.heroTarget.x),
        GROUND_TOP + hop,
        ease(this.hero.position.z, this.heroTarget.z),
      );
      this.hero.scale.set(this.heroFlip ? -this.heroPresence : this.heroPresence, this.heroPresence, 1);
    }

    if (this.prompt?.visible && !reduceMotion) {
      this.prompt.position.y = GROUND_TOP + ART + 3 + Math.sin(clock / 150) * 1.5;
    }
  }

  dispose(): void {
    for (const sign of this.signs) {
      sign.material.map?.dispose();
      sign.material.dispose();
    }
    this.signs = [];
    this.signKey = "";
    for (const entry of this.npcs) for (const frame of entry.frames) frame.dispose();
    for (const entry of this.monsters) for (const frame of entry.frames) frame.dispose();
    for (const frame of this.heroFrames) frame.dispose();
    this.heroFrames = [];
    for (const child of this.group.children) {
      if (child instanceof Mesh) child.geometry.dispose();
    }
    this.group.clear();
    this.npcs = [];
    this.monsters = [];
    this.chests = [];
    this.hero = null;
    this.prompt = null;
  }

  destroy(): void {
    this.dispose();
    this.promptMaterial.dispose();
    this.figureMaterial.dispose();
  }
}
