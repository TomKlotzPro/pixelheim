import {
  CanvasTexture,
  Group,
  Mesh,
  MeshBasicMaterial,
  type MeshLambertMaterial,
  NearestFilter,
  PlaneGeometry,
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
import { type Chest, chestSpriteName, chestsOn, solidChestAt } from "../../world/chests";
import { npcBeside, npcPosition, npcsOn, type Npc } from "../../world/npcs";
import { type MonsterSpawn, spawnPosition, spawnRegion, spawnsOn } from "../../world/spawns";
import { signsOn } from "../../world/signs";
import type { WorldMap } from "../../world/types";
import { GROUND_TOP } from "./voxelTerrain";
import {
  ACTOR_OMIT,
  ART,
  type ColorGrid,
  colorGrid,
  overlayGrids,
  uprightGeometry,
  type VoxelSheet,
} from "./voxelData";

const WALK_MS = 160;
const WALK_LINGER_MS = 240;

/** Same de-synced idle beat as the Pixi actors: nobody breathes in unison. */
function idleBeat(id: string): { phase: number; period: number } {
  let h = 0;
  for (const c of id) h = (h * 31 + c.charCodeAt(0)) % 9973;
  return { phase: h, period: 420 + (h % 5) * 45 };
}

const FACING_DELTAS = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] } as const;

/** The talk prompt, as voxels: a bright "!" that ignores the night. */
const PROMPT_GRID: ColorGrid = ["Y", "Y", "Y", "Y", ".", "Y"].map((ch) => [ch === "." ? null : "#ffd469"]);

/** A soft dark oval, drawn once: the contact shadow that grounds each figure. */
function makeContactTexture(): CanvasTexture {
  const size = 64;
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d")!;
  const gradient = ctx.createRadialGradient(size / 2, size / 2, 2, size / 2, size / 2, size / 2);
  gradient.addColorStop(0, "rgba(0, 0, 0, 0.55)");
  gradient.addColorStop(0.6, "rgba(0, 0, 0, 0.28)");
  gradient.addColorStop(1, "rgba(0, 0, 0, 0)");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, size, size);
  return new CanvasTexture(canvas);
}

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

type Walker = { mesh: Mesh; disc: Mesh; target: { x: number; z: number } };

/**
 * The people as voxel figures, extruded from the same grids as their PNGs.
 * The hero wears the outfit grids painted over the body grid (PIX-107, in 3D
 * for free); walking bobs the figure; the sun does the shadows.
 */
export class VoxelActors {
  readonly group = new Group();
  private material: MeshLambertMaterial;
  private promptMaterial = new MeshBasicMaterial({ vertexColors: true });
  private contactTexture = makeContactTexture();
  private discMaterial = new MeshBasicMaterial({
    map: this.contactTexture,
    transparent: true,
    depthWrite: false,
  });
  private discGeometry = new PlaneGeometry(ART * 1.05, ART * 0.65).rotateX(-Math.PI / 2);
  private sheet: VoxelSheet | null = null;

  private npcs: (Walker & { npc: Npc })[] = [];
  private monsters: (Walker & { spawn: MonsterSpawn })[] = [];
  private chests: { chest: Chest; mesh: Mesh; shownSprite: string | null }[] = [];
  private signs: BillboardSprite[] = [];
  private signKey = "";
  private hero: Mesh | null = null;
  private heroDisc: Mesh | null = null;
  private heroTarget = { x: 0, z: 0 };
  private heroFlip = false;
  private heroPresence = 1;
  private heroKey = "";
  private walkUntil = 0;
  private lastPos: string | null = null;
  private prompt: Mesh | null = null;

  constructor(material: MeshLambertMaterial) {
    this.material = material;
  }

  private figure(spriteName: string, depth = 2): Mesh {
    const sprite = this.sheet!.sprites[spriteName];
    const grid = sprite ? colorGrid(sprite, ACTOR_OMIT) : PROMPT_GRID;
    const mesh = new Mesh(uprightGeometry(grid, depth), this.material);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    return mesh;
  }

  /** The grounding disc under a figure; sits just over the tallest relief. */
  private disc(): Mesh {
    const mesh = new Mesh(this.discGeometry, this.discMaterial);
    mesh.position.y = GROUND_TOP + 0.8;
    this.group.add(mesh);
    return mesh;
  }

  build(sheet: VoxelSheet, map: WorldMap, state: GameState): void {
    this.dispose();
    this.sheet = sheet;

    this.chests = [];
    for (const chest of chestsOn(map.id)) {
      const shown = chestSpriteName(chest, (state.world?.openedChests ?? []).includes(chest.id));
      const mesh = this.figure(shown ?? "chest_closed", 4);
      mesh.position.set(chest.x * ART + ART / 2, GROUND_TOP, chest.y * ART + ART / 2);
      mesh.visible = shown !== null;
      this.group.add(mesh);
      this.chests.push({ chest, mesh, shownSprite: shown });
    }

    this.npcs = [];
    for (const npc of npcsOn(map.id)) {
      const mesh = this.figure(npc.sprite);
      const at = npcPosition(npc, state.worldSteps);
      mesh.position.set(at.x * ART + ART / 2, GROUND_TOP, at.y * ART + ART / 2);
      this.group.add(mesh);
      this.npcs.push({ npc, mesh, disc: this.disc(), target: { x: mesh.position.x, z: mesh.position.z } });
    }

    this.monsters = [];
    for (const spawn of spawnsOn(map.id)) {
      const species = getMonster(spawnSpecies(spawnRegion(spawn), spawn.x * 31 + spawn.y));
      const mesh = this.figure(species.sprite);
      const at = spawnPosition(spawn, state.worldSteps);
      mesh.position.set(at.x * ART + ART / 2, GROUND_TOP, at.y * ART + ART / 2);
      this.group.add(mesh);
      this.monsters.push({ spawn, mesh, disc: this.disc(), target: { x: mesh.position.x, z: mesh.position.z } });
    }

    this.heroKey = "";
    this.hero = null;
    this.heroDisc = null;
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
      plate.position.set(sign.x * ART + ART / 2, GROUND_TOP + ART + 4, sign.y * ART + ART / 2);
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
    const grid = overlayGrids(colorGrid(body, ACTOR_OMIT), wears);
    if (this.hero) {
      this.hero.geometry.dispose();
      this.hero.geometry = uprightGeometry(grid, 2);
    } else {
      this.hero = new Mesh(uprightGeometry(grid, 2), this.material);
      this.hero.castShadow = true;
      this.hero.receiveShadow = true;
      this.group.add(this.hero);
      this.heroDisc = this.disc();
    }
    this.heroPresence = state.hero ? rankPresence(state.hero.level) : 1;
  }

  update(map: WorldMap, state: GameState, clock: number): void {
    const pos = state.world!.position;
    const key = `${pos.x},${pos.y}`;
    if (key !== this.lastPos) {
      this.walkUntil = clock + WALK_LINGER_MS;
      this.lastPos = key;
    }
    this.heroTarget = { x: pos.x * ART + ART / 2, z: pos.y * ART + ART / 2 };
    this.heroFlip = pos.facing === "left";
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
      const idle = state.hero && !state.dialogue && !state.shopOpen && !state.inventoryOpen;
      const beside = idle ? npcBeside(map.id, pos.x, pos.y, pos.facing, state.worldSteps) : null;
      const faced = FACING_DELTAS[pos.facing];
      const chest = idle && !beside ? solidChestAt(map.id, pos.x + faced[0], pos.y + faced[1]) : null;
      const openable = chest && !(state.world?.openedChests ?? []).includes(chest.id) ? chest : null;
      this.prompt.visible = beside !== null || openable !== null;
      if (beside || openable) {
        const delta = beside ? FACING_DELTAS[beside.facing] : faced;
        this.prompt.position.set(
          (pos.x + delta[0]) * ART + ART / 2,
          GROUND_TOP + ART + 3,
          (pos.y + delta[1]) * ART + ART / 2,
        );
      }
    }
  }

  tick(clock: number, ease: (from: number, to: number) => number, reduceMotion: boolean): void {
    for (const { npc, mesh, disc, target } of this.npcs) {
      const beat = idleBeat(npc.id);
      const bob = reduceMotion ? 0 : Math.max(0, Math.sin((clock + beat.phase) / beat.period)) * 0.7;
      mesh.position.set(ease(mesh.position.x, target.x), GROUND_TOP + bob, ease(mesh.position.z, target.z));
      disc.position.set(mesh.position.x, disc.position.y, mesh.position.z);
    }
    for (const { spawn, mesh, disc, target } of this.monsters) {
      const beat = idleBeat(spawn.id);
      const bob = reduceMotion ? 0 : Math.max(0, Math.sin((clock + beat.phase) / beat.period)) * 0.7;
      mesh.position.set(ease(mesh.position.x, target.x), GROUND_TOP + bob, ease(mesh.position.z, target.z));
      disc.position.set(mesh.position.x, disc.position.y, mesh.position.z);
      disc.visible = mesh.visible;
    }

    if (this.hero) {
      const walking = clock < this.walkUntil;
      const bob = walking && !reduceMotion ? Math.abs(Math.sin((clock / WALK_MS) * Math.PI)) * 1.4 : 0;
      this.hero.position.set(
        ease(this.hero.position.x, this.heroTarget.x),
        GROUND_TOP + bob,
        ease(this.hero.position.z, this.heroTarget.z),
      );
      this.hero.scale.set(this.heroFlip ? -this.heroPresence : this.heroPresence, this.heroPresence, 1);
      this.heroDisc?.position.set(this.hero.position.x, this.heroDisc.position.y, this.hero.position.z);
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
    for (const child of this.group.children) {
      // The disc geometry and material are shared; only figures own theirs.
      if (child instanceof Mesh && child.geometry !== this.discGeometry) child.geometry.dispose();
    }
    this.group.clear();
    this.npcs = [];
    this.monsters = [];
    this.chests = [];
    this.hero = null;
    this.heroDisc = null;
    this.prompt = null;
  }

  destroy(): void {
    this.dispose();
    this.promptMaterial.dispose();
    this.discMaterial.dispose();
    this.discGeometry.dispose();
    this.contactTexture.dispose();
  }
}
