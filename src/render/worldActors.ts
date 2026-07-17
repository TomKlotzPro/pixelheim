import { Assets, type Container, Sprite, type Text, type Texture } from "pixi.js";
import { ROLES } from "../game/roles";
import type { GameState } from "../game/types";
import { spawnSpecies } from "../game/encounters";
import { getMonster } from "../game/monsters";
import { npcAt, npcPosition, npcsOn, type Npc } from "../world/npcs";
import { type MonsterSpawn, spawnPosition, spawnRegion, spawnsOn } from "../world/spawns";
import type { WorldMap } from "../world/types";
import { ART, type FrameBank, retroText } from "./pixiUtils";

const WALK_MS = 160; // per walk frame
const IDLE_MS = 500; // per idle frame
const WALK_LINGER_MS = 240; // keep the legs moving briefly after the last step

const FACING_DELTAS = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] } as const;

/** The people: the hero's walk cycle, wandering NPCs, and the talk prompt. */
export class ActorLayer {
  private bank: FrameBank;
  private npcs: { npc: Npc; sprite: Sprite; target: { x: number; y: number } }[] = [];
  private monsters: { spawn: MonsterSpawn; sheet: string; sprite: Sprite; target: { x: number; y: number } }[] = [];
  private hero: Sprite | null = null;
  private heroFrames: Texture[] | null = null;
  private heroTarget = { x: 0, y: 0 };
  private heroFlip = false;
  private walkUntil = 0;
  private lastPos: string | null = null;
  private prompt: Text | null = null;

  constructor(bank: FrameBank) {
    this.bank = bank;
  }

  build(container: Container, map: WorldMap, state: GameState, scale: number): void {
    this.npcs = [];
    for (const npc of npcsOn(map.id)) {
      const sheet = this.bank.frames.get(`${npc.sprite}_idle`);
      const sprite = new Sprite(sheet ? sheet[0] : (Assets.get(npc.sprite) as Texture));
      const at = npcPosition(npc, state.worldSteps);
      sprite.position.set(at.x * ART, at.y * ART);
      container.addChild(sprite);
      this.npcs.push({ npc, sprite, target: { x: at.x * ART, y: at.y * ART } });
    }

    this.monsters = [];
    for (const spawn of spawnsOn(map.id)) {
      const species = getMonster(spawnSpecies(spawnRegion(spawn), spawn.x * 31 + spawn.y));
      const sheetName = `${species.sprite}_idle`;
      const sheet = this.bank.frames.get(sheetName);
      const sprite = new Sprite(sheet ? sheet[0] : (Assets.get(species.sprite) as Texture));
      const at = spawnPosition(spawn, state.worldSteps);
      sprite.position.set(at.x * ART, at.y * ART);
      container.addChild(sprite);
      this.monsters.push({ spawn, sheet: sheetName, sprite, target: { x: at.x * ART, y: at.y * ART } });
    }

    const role = ROLES[state.hero?.roleId ?? "warrior"];
    this.heroFrames = this.bank.frames.get(`${role.sprite}_walk`) ?? null;
    this.hero = new Sprite(this.heroFrames?.[0]);
    this.hero.anchor.set(0.5, 0);
    container.addChild(this.hero);

    this.prompt = retroText("!", 0xffd469, scale * 2);
    this.prompt.anchor.set(0.5, 1);
    this.prompt.visible = false;
    container.addChild(this.prompt);
  }

  /** Snap the hero into place after a map change. */
  snapTo(x: number, y: number): void {
    this.heroTarget = { x: x * ART, y: y * ART };
    this.hero?.position.set(this.heroTarget.x + ART / 2, this.heroTarget.y);
    this.lastPos = `${x},${y}`;
  }

  update(map: WorldMap, state: GameState, clock: number): void {
    const pos = state.world!.position;
    const key = `${pos.x},${pos.y}`;
    if (key !== this.lastPos) {
      this.walkUntil = clock + WALK_LINGER_MS;
      this.lastPos = key;
    }
    this.heroTarget = { x: pos.x * ART, y: pos.y * ART };
    this.heroFlip = pos.facing === "left";
    for (const entry of this.npcs) {
      const at = npcPosition(entry.npc, state.worldSteps);
      entry.target = { x: at.x * ART, y: at.y * ART };
    }
    for (const entry of this.monsters) {
      entry.sprite.visible = !(state.world?.slain ?? []).includes(entry.spawn.id);
      const at = spawnPosition(entry.spawn, state.worldSteps);
      entry.target = { x: at.x * ART, y: at.y * ART };
    }

    // Someone to talk to: the prompt floats over the NPC the hero is facing.
    if (this.prompt) {
      const delta = FACING_DELTAS[pos.facing];
      const facing =
        state.hero && !state.dialogue && !state.shopOpen && !state.inventoryOpen
          ? npcAt(map.id, pos.x + delta[0], pos.y + delta[1], state.worldSteps)
          : null;
      this.prompt.visible = facing !== null;
      if (facing) {
        this.prompt.position.set((pos.x + delta[0]) * ART + ART / 2, (pos.y + delta[1]) * ART - 2);
      }
    }
  }

  tick(clock: number, ease: (from: number, to: number) => number): void {
    for (const { npc, sprite, target } of this.npcs) {
      sprite.position.set(ease(sprite.position.x, target.x), ease(sprite.position.y, target.y));
      const sheet = this.bank.frames.get(`${npc.sprite}_idle`);
      if (sheet) sprite.texture = sheet[Math.floor(clock / IDLE_MS) % sheet.length];
    }

    for (const { sheet, sprite, target } of this.monsters) {
      sprite.position.set(ease(sprite.position.x, target.x), ease(sprite.position.y, target.y));
      const frames = this.bank.frames.get(sheet);
      if (frames) sprite.texture = frames[Math.floor(clock / IDLE_MS) % frames.length];
    }

    if (this.hero && this.heroFrames) {
      const cx = this.heroTarget.x + ART / 2;
      this.hero.position.set(ease(this.hero.position.x, cx), ease(this.hero.position.y, this.heroTarget.y));
      this.hero.scale.x = this.heroFlip ? -1 : 1;
      const walking = clock < this.walkUntil;
      this.hero.texture = walking
        ? this.heroFrames[Math.floor(clock / WALK_MS) % this.heroFrames.length]
        : this.heroFrames[0];
    }

    // The talk prompt bobs over whoever the hero is facing.
    if (this.prompt?.visible) {
      this.prompt.pivot.y = Math.round(Math.sin(clock / 150) * 1.5);
    }
  }
}
