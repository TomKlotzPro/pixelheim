import { Application, Assets, Container, Graphics, Sprite, type Texture } from "pixi.js";
import type { GameState } from "../game/types";
import { heroSprite } from "../game/hero/character";
import { sliceSheet } from "./pixiUtils";
import { pixelText } from "./pixelFont";

export const SCENE_W = 288;
export const SCENE_H = 104;
const CHAR_SCALE = 4; // fighters draw at 64 art px
const HERO_X = 72;
const MONSTER_X = SCENE_W - 72;
const GROUND_Y = 92;
const IDLE_MS = 500;

type Fx =
  | { kind: "lunge"; who: "hero" | "monster"; t: number; dur: number }
  | { kind: "flash"; who: "hero" | "monster"; t: number; dur: number }
  | { kind: "shake"; t: number; dur: number }
  | { kind: "popin"; t: number; dur: number }
  | { kind: "death"; who: "hero" | "monster"; t: number; dur: number }
  | { kind: "number"; text: Sprite; t: number; dur: number };

type Snapshot = { heroHp: number; monsterHp: number; monsterSprite: string; encounterIndex: number; phase: string };

/**
 * The Pixi battle scene (Painted World G3): two fighters on one stage so
 * lunges can cross it. `update(state)` diffs battle state against the last
 * snapshot and turns deltas into effects: hits lunge and flash, damage floats
 * up and fades, deaths sink, new encounters pop in. All game logic stays in
 * the reducer; this file only reacts to what already happened.
 */
export class BattleRenderer {
  private app: Application | null = null;
  private root = new Container();
  private hero: Sprite | null = null;
  private monster: Sprite | null = null;
  private monsterFrames: Texture[] | null = null;
  private monsterToken = 0;
  private fx: Fx[] = [];
  private prev: Snapshot | null = null;
  private scale = 3;
  private clock = 0;
  private destroyed = false;

  async init(host: HTMLElement, scale: number, state: GameState): Promise<void> {
    this.scale = scale;
    const app = new Application();
    await app.init({
      width: SCENE_W * scale,
      height: SCENE_H * scale,
      backgroundAlpha: 0,
      antialias: false,
    });
    if (this.destroyed) {
      app.destroy(true, { children: true });
      return;
    }
    this.app = app;
    host.appendChild(app.canvas);

    const heroName = state.hero ? heroSprite(state.hero) : "hero_warrior";
    const heroSheet: Texture = await Assets.load({
      alias: `${heroName}_walk`,
      src: `${import.meta.env.BASE_URL}sprites/${heroName}_walk.png`,
    });
    if (this.destroyed) return;

    this.root.scale.set(scale);
    app.stage.addChild(this.root);

    const shadows = new Graphics();
    // oxlint-disable-next-line unicorn/no-array-fill-with-reference-type -- Pixi Graphics.fill, not Array.fill
    shadows.ellipse(HERO_X, GROUND_Y, 26, 6).fill({ color: 0x000000, alpha: 0.35 });
    // oxlint-disable-next-line unicorn/no-array-fill-with-reference-type -- Pixi Graphics.fill, not Array.fill
    shadows.ellipse(MONSTER_X, GROUND_Y, 26, 6).fill({ color: 0x000000, alpha: 0.35 });
    this.root.addChild(shadows);

    this.hero = new Sprite(sliceSheet(heroSheet, 4)[0]);
    this.hero.anchor.set(0.5, 1);
    this.hero.scale.set(CHAR_SCALE);
    this.hero.position.set(HERO_X, GROUND_Y + 2);
    this.root.addChild(this.hero);

    this.monster = new Sprite();
    this.monster.anchor.set(0.5, 1);
    // Mirror so the two fighters face each other.
    this.monster.scale.set(-CHAR_SCALE, CHAR_SCALE);
    this.monster.position.set(MONSTER_X, GROUND_Y + 2);
    this.root.addChild(this.monster);

    app.ticker.add(() => this.tick(app.ticker.deltaMS));
    this.update(state);
  }

  private async ensureMonster(spriteName: string): Promise<void> {
    const token = ++this.monsterToken;
    const sheet: Texture = await Assets.load({
      alias: `${spriteName}_idle`,
      src: `${import.meta.env.BASE_URL}sprites/${spriteName}_idle.png`,
    });
    if (this.destroyed || token !== this.monsterToken || !this.monster) return;
    this.monsterFrames = sliceSheet(sheet, 2);
    this.monster.texture = this.monsterFrames[0];
    this.monster.alpha = 1;
    this.monster.rotation = 0;
  }

  private spawnNumber(value: string, color: number, x: number): void {
    if (!this.app) return;
    const text = pixelText(value, color, 2);
    text.anchor.set(0.5, 1);
    text.position.set(x, GROUND_Y - 56);
    this.root.addChild(text);
    this.fx.push({ kind: "number", text, t: 0, dur: 900 });
  }

  /** Diff fresh battle state against the last snapshot; deltas become effects. */
  update(state: GameState): void {
    const battle = state.battle;
    const hero = state.hero;
    if (!battle || !hero || !this.app) return;
    const snap: Snapshot = {
      heroHp: hero.hp,
      monsterHp: battle.monster.hp,
      monsterSprite: battle.monster.def.sprite,
      encounterIndex: battle.encounterIndex,
      phase: battle.phase,
    };
    const p = this.prev;
    this.prev = snap;

    if (!p || p.monsterSprite !== snap.monsterSprite || p.encounterIndex !== snap.encounterIndex) {
      void this.ensureMonster(snap.monsterSprite);
      if (p) this.fx.push({ kind: "popin", t: 0, dur: 350 });
      return;
    }

    if (snap.monsterHp < p.monsterHp) {
      this.fx.push({ kind: "lunge", who: "hero", t: 0, dur: 260 }, { kind: "flash", who: "monster", t: 0, dur: 240 });
      this.spawnNumber(`-${p.monsterHp - snap.monsterHp}`, 0xffd24a, MONSTER_X);
    }
    if (snap.heroHp < p.heroHp) {
      this.fx.push(
        { kind: "lunge", who: "monster", t: 0, dur: 260 },
        { kind: "flash", who: "hero", t: 0, dur: 240 },
        { kind: "shake", t: 0, dur: 260 },
      );
      this.spawnNumber(`-${p.heroHp - snap.heroHp}`, 0xff6b6b, HERO_X);
    }
    if (snap.heroHp > p.heroHp) {
      this.spawnNumber(`+${snap.heroHp - p.heroHp}`, 0x7ddb6e, HERO_X);
    }
    if (snap.monsterHp <= 0 && p.monsterHp > 0) this.fx.push({ kind: "death", who: "monster", t: 0, dur: 700 });
    if (snap.phase === "lost" && p.phase !== "lost") this.fx.push({ kind: "death", who: "hero", t: 0, dur: 700 });
  }

  private tick(deltaMS: number): void {
    this.clock += deltaMS;
    const hero = this.hero;
    const monster = this.monster;
    if (!hero || !monster) return;

    // Idle baseline every frame; effects below layer on top of it.
    if (this.monsterFrames && (this.prev?.monsterHp ?? 1) > 0) {
      monster.texture = this.monsterFrames[Math.floor(this.clock / IDLE_MS) % this.monsterFrames.length];
    }
    let heroX = HERO_X;
    let monsterX = MONSTER_X;
    let rootX = 0;
    hero.alpha = this.prev?.phase === "lost" ? hero.alpha : 1;
    monster.alpha = (this.prev?.monsterHp ?? 1) <= 0 ? monster.alpha : 1;

    this.fx = this.fx.filter((fx) => {
      fx.t += deltaMS;
      const k = Math.min(1, fx.t / fx.dur);
      switch (fx.kind) {
        case "lunge": {
          const reach = Math.sin(Math.PI * k) * 26;
          if (fx.who === "hero") heroX += reach;
          else monsterX -= reach;
          break;
        }
        case "flash": {
          const target = fx.who === "hero" ? hero : monster;
          target.alpha = k >= 1 ? 1 : Math.floor(fx.t / 60) % 2 ? 0.35 : 1;
          break;
        }
        case "shake":
          rootX = k >= 1 ? 0 : Math.sin(fx.t / 18) * 2 * (1 - k);
          break;
        case "popin":
          monster.alpha = k;
          monster.scale.set(-CHAR_SCALE * (0.6 + 0.4 * k), CHAR_SCALE * (0.6 + 0.4 * k));
          break;
        case "death": {
          const target = fx.who === "hero" ? hero : monster;
          target.alpha = 1 - k;
          target.rotation = (fx.who === "hero" ? -1 : 1) * (Math.PI / 2) * k;
          break;
        }
        case "number":
          fx.text.position.y = GROUND_Y - 56 - k * 22;
          fx.text.alpha = 1 - k * k;
          if (fx.t >= fx.dur) {
            fx.text.destroy();
            return false;
          }
          break;
      }
      return fx.t < fx.dur;
    });

    hero.position.x = Math.round(heroX);
    monster.position.x = Math.round(monsterX);
    this.root.position.x = Math.round(rootX * this.scale);
  }

  destroy(): void {
    this.destroyed = true;
    this.app?.destroy(true, { children: true });
    this.app = null;
  }
}
