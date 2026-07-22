import { Assets, type Container, Graphics, Sprite, Texture } from "pixi.js";
import { heroSprite } from "../game/hero/character";
import { outfitFor } from "../game/economy/wearables";
import { composeWalkSheet, outfitKey } from "./outfit";
import { RANK_AURAS, rankIndex, rankPresence } from "../game/hero/ranks";
import type { GameState } from "../game/types";
import { spawnSpecies } from "../game/combat/encounters";
import { getMonster } from "../game/combat/monsters";
import { type Chest, chestSpriteName, chestsOn } from "../world/chests";
import { furnitureOn } from "../game/economy/house";
import { getItem } from "../game/economy/items";
import { npcPosition, npcsOn, type Npc } from "../world/npcs";
import { interactionPrompt } from "../world/interactionPrompt";
import { signsOn } from "../world/signs";
import { type MonsterSpawn, spawnPosition, spawnRegion, spawnsOn } from "../world/spawns";
import type { WorldMap } from "../world/types";
import { ART, type FrameBank, makeGlowTexture, makeShadowTexture, sliceSheet } from "./pixiUtils";
import { pixelText } from "./pixelFont";

const WALK_MS = 160; // per walk frame
const IDLE_MS = 500; // per idle frame
const WALK_LINGER_MS = 240; // keep the legs moving briefly after the last step

/**
 * Nobody breathes in unison: each actor gets its own idle phase and a slightly
 * different period, so the village stops ticking on one global metronome
 * (which read as the NPCs "moving with the grass").
 */
function idleBeat(id: string): { phase: number; period: number } {
  let h = 0;
  for (const c of id) h = (h * 31 + c.charCodeAt(0)) % 9973;
  return { phase: h, period: IDLE_MS - 80 + (h % 5) * 45 };
}

/** The people: the hero's walk cycle, wandering NPCs, and the talk prompt. */
export class ActorLayer {
  private bank: FrameBank;
  private npcs: { npc: Npc; sprite: Sprite; shadow: Sprite; target: { x: number; y: number } }[] = [];
  private monsters: {
    spawn: MonsterSpawn;
    sheet: string;
    sprite: Sprite;
    shadow: Sprite;
    target: { x: number; y: number };
  }[] = [];
  private chests: { chest: Chest; sprite: Sprite }[] = [];
  private furniture: Sprite[] = [];
  private furnitureKey: string | null = null;
  private container: Container | null = null;
  private hero: Sprite | null = null;
  private heroShadow: Sprite | null = null;
  private heroAura: Sprite | null = null;
  private heroPresence = 1;
  private heroOutfitKey = "";
  private shadowTexture = makeShadowTexture();
  private heroFrames: Texture[] | null = null;
  private heroFramesUp: Texture[] | null = null;
  private heroFacingUp = false;
  private heroTarget = { x: 0, y: 0 };
  private heroFlip = false;
  private walkUntil = 0;
  private lastPos: string | null = null;
  private prompt: Sprite | null = null;

  constructor(bank: FrameBank) {
    this.bank = bank;
  }

  build(container: Container, map: WorldMap, state: GameState, _scale: number): void {
    this.container = container;
    this.furnitureKey = null;
    this.furniture = [];
    this.syncFurniture(map, state);
    // Treasure sits under everyone: the hero walks over glints, not behind them.
    this.chests = [];
    for (const chest of chestsOn(map.id)) {
      const name = chestSpriteName(chest, (state.world?.openedChests ?? []).includes(chest.id));
      const sprite = new Sprite(Assets.get(name ?? "chest_closed") as Texture);
      sprite.position.set(chest.x * ART, chest.y * ART);
      sprite.visible = name !== null;
      container.addChild(sprite);
      this.chests.push({ chest, sprite });
    }

    // Feet cast shadows: a shared oval under every walker sells the depth.
    const makeShadow = () => {
      const shadow = new Sprite(this.shadowTexture);
      shadow.anchor.set(0.5, 0.5);
      container.addChild(shadow);
      return shadow;
    };

    this.npcs = [];
    for (const npc of npcsOn(map.id)) {
      const sheet = this.bank.frames.get(`${npc.sprite}_idle`);
      const sprite = new Sprite(sheet ? sheet[0] : (Assets.get(npc.sprite) as Texture));
      const at = npcPosition(npc, state.worldSteps);
      sprite.position.set(at.x * ART, at.y * ART);
      this.npcs.push({ npc, sprite, shadow: makeShadow(), target: { x: at.x * ART, y: at.y * ART } });
    }

    this.monsters = [];
    for (const spawn of spawnsOn(map.id)) {
      const species = getMonster(spawnSpecies(spawnRegion(spawn), spawn.x * 31 + spawn.y));
      const sheetName = `${species.sprite}_idle`;
      const sheet = this.bank.frames.get(sheetName);
      const sprite = new Sprite(sheet ? sheet[0] : (Assets.get(species.sprite) as Texture));
      const at = spawnPosition(spawn, state.worldSteps);
      sprite.position.set(at.x * ART, at.y * ART);
      this.monsters.push({
        spawn,
        sheet: sheetName,
        sprite,
        shadow: makeShadow(),
        target: { x: at.x * ART, y: at.y * ART },
      });
    }

    this.heroShadow = makeShadow();
    // Shadows sit under everyone: add the walkers only after every shadow.
    for (const entry of this.npcs) container.addChild(entry.sprite);
    for (const entry of this.monsters) container.addChild(entry.sprite);

    // Rank shows: an aura under the ascended, and a touch more presence.
    const rank = state.hero ? rankIndex(state.hero.level) : 0;
    this.heroPresence = state.hero ? rankPresence(state.hero.level) : 1;
    const auraColor = RANK_AURAS[rank];
    this.heroAura = new Sprite(makeGlowTexture());
    this.heroAura.anchor.set(0.5, 0.5);
    this.heroAura.width = ART * 2.2;
    this.heroAura.height = ART * 1.4;
    this.heroAura.alpha = auraColor ? 0.4 : 0;
    if (auraColor) this.heroAura.tint = Number.parseInt(auraColor.slice(1), 16);
    container.addChild(this.heroAura);

    const sheet = state.hero ? heroSprite(state.hero) : "hero_warrior";
    this.heroFrames = this.bank.frames.get(`${sheet}_walk`) ?? null;
    this.heroFramesUp = this.bank.frames.get(`${sheet}_walk_up`) ?? null;
    this.heroOutfitKey = "";
    this.hero = new Sprite(this.heroFrames?.[0]);
    this.hero.anchor.set(0.5, 0);
    container.addChild(this.hero);

    this.prompt = pixelText("!", 0xffd469);
    this.prompt.anchor.set(0.5, 1);
    this.prompt.visible = false;
    container.addChild(this.prompt);

    // Door signs: little wooden plates telling you what each building is.
    for (const sign of signsOn(map.id, state.house.owned)) {
      // Craft stations advertise their trade with an icon over the plate.
      if (sign.icon) {
        const icon = new Sprite(Assets.get(sign.icon) as Texture);
        icon.anchor.set(0.5, 1);
        icon.position.set(sign.x * ART + ART / 2, sign.y * ART - 10);
        container.addChild(icon);
      }
      const label = pixelText(sign.label, 0xe8c34a);
      const w = label.width + 4;
      const h = label.height + 2;
      const plate = new Graphics()
        .rect(0, 0, w, h)
        .fill(0x2a2118)
        .rect(0, 0, w, 1)
        .fill(0x8a6238)
        .rect(0, h - 1, w, 1)
        .fill(0x5c3f24);
      plate.position.set(sign.x * ART + ART / 2 - w / 2, sign.y * ART - h - 1);
      label.position.set(2, 1);
      plate.addChild(label);
      container.addChild(plate);
    }
  }

  /** Snap the hero into place after a map change. */
  snapTo(x: number, y: number): void {
    this.heroTarget = { x: x * ART, y: y * ART };
    this.hero?.position.set(this.heroTarget.x + ART / 2, this.heroTarget.y);
    this.lastPos = `${x},${y}`;
  }

  /** Placed furniture (PIX-34): rebuilt whenever the layout changes, live. */
  private syncFurniture(map: WorldMap, state: GameState): void {
    const placed = furnitureOn(state, map.id);
    const key = placed.map((f) => `${f.itemId}:${f.x},${f.y}`).join("|");
    if (key === this.furnitureKey || !this.container) return;
    this.furnitureKey = key;
    for (const sprite of this.furniture) this.container.removeChild(sprite);
    this.furniture = [];
    for (const f of placed) {
      const sprite = new Sprite(Assets.get(getItem(f.itemId).sprite) as Texture);
      sprite.position.set(f.x * ART, f.y * ART);
      // Rugs and company sit under every walker, like the treasure does.
      this.container.addChildAt(sprite, 0);
      this.furniture.push(sprite);
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
    this.heroTarget = { x: pos.x * ART, y: pos.y * ART };
    this.heroFlip = pos.facing === "left";
    this.heroFacingUp = pos.facing === "up";
    for (const entry of this.npcs) {
      const at = npcPosition(entry.npc, state.worldSteps);
      entry.target = { x: at.x * ART, y: at.y * ART };
    }
    for (const entry of this.monsters) {
      entry.sprite.visible = !(state.world?.slain ?? []).includes(entry.spawn.id);
      const at = spawnPosition(entry.spawn, state.worldSteps);
      entry.target = { x: at.x * ART, y: at.y * ART };
    }

    for (const entry of this.chests) {
      const name = chestSpriteName(entry.chest, (state.world?.openedChests ?? []).includes(entry.chest.id));
      entry.sprite.visible = name !== null;
      if (name) entry.sprite.texture = Assets.get(name) as Texture;
    }

    // The outfit is part of the sprite now: recompose the walk sheet whenever
    // the equipped set changes, cached per combination (PIX-107).
    if (state.hero) {
      const sheetName = heroSprite(state.hero);
      const outfit = outfitFor(state.gear, state.equipped);
      const dressKey = outfitKey(sheetName, outfit);
      if (dressKey !== this.heroOutfitKey) {
        this.heroOutfitKey = dressKey;
        if (outfit.length === 0) {
          this.heroFrames = this.bank.frames.get(`${sheetName}_walk`) ?? null;
          this.heroFramesUp = this.bank.frames.get(`${sheetName}_walk_up`) ?? null;
        } else {
          void composeWalkSheet(sheetName, outfit).then((canvas) => {
            if (this.heroOutfitKey !== dressKey) return null;
            const texture = Texture.from(canvas);
            texture.source.scaleMode = "nearest";
            this.heroFrames = sliceSheet(texture, 4);
            return null;
          });
          void composeWalkSheet(sheetName, outfit, "up").then((canvas) => {
            if (this.heroOutfitKey !== dressKey) return null;
            const texture = Texture.from(canvas);
            texture.source.scaleMode = "nearest";
            this.heroFramesUp = sliceSheet(texture, 4);
            return null;
          });
        }
      }
    }

    // Someone to talk to (or something to open): an NPC beside the hero wins
    // (faced tile first, any neighbor after), then the chest the hero faces.
    if (this.prompt) {
      const at = interactionPrompt(state, map.id);
      this.prompt.visible = at !== null;
      if (at) this.prompt.position.set(at.x * ART + ART / 2, at.y * ART - 2);
    }
  }

  tick(clock: number, ease: (from: number, to: number) => number): void {
    for (const { npc, sprite, shadow, target } of this.npcs) {
      sprite.position.set(ease(sprite.position.x, target.x), ease(sprite.position.y, target.y));
      shadow.position.set(sprite.position.x + ART / 2, sprite.position.y + ART - 2);
      const sheet = this.bank.frames.get(`${npc.sprite}_idle`);
      const beat = idleBeat(npc.id);
      if (sheet) sprite.texture = sheet[Math.floor((clock + beat.phase) / beat.period) % sheet.length];
    }

    for (const { spawn, sheet, sprite, shadow, target } of this.monsters) {
      sprite.position.set(ease(sprite.position.x, target.x), ease(sprite.position.y, target.y));
      shadow.position.set(sprite.position.x + ART / 2, sprite.position.y + ART - 2);
      shadow.visible = sprite.visible;
      const frames = this.bank.frames.get(sheet);
      const beat = idleBeat(spawn.id);
      if (frames) sprite.texture = frames[Math.floor((clock + beat.phase) / beat.period) % frames.length];
    }

    if (this.hero && this.heroFrames) {
      const cx = this.heroTarget.x + ART / 2;
      this.hero.position.set(ease(this.hero.position.x, cx), ease(this.hero.position.y, this.heroTarget.y));
      this.hero.scale.set(this.heroFlip ? -this.heroPresence : this.heroPresence, this.heroPresence);
      const walking = clock < this.walkUntil;
      // Walking away shows the hero's back (PIX-117): the up-sheet when it
      // exists, the front sheet for every other direction.
      const frames = (this.heroFacingUp && this.heroFramesUp) || this.heroFrames;
      this.hero.texture = walking ? frames[Math.floor(clock / WALK_MS) % frames.length] : frames[0];
      this.heroShadow?.position.set(this.hero.position.x, this.hero.position.y + ART - 2);
      this.heroAura?.position.set(this.hero.position.x, this.hero.position.y + ART - 3);
    }

    // The talk prompt bobs over whoever the hero is facing.
    if (this.prompt?.visible) {
      this.prompt.pivot.y = Math.round(Math.sin(clock / 150) * 1.5);
    }
  }
}
