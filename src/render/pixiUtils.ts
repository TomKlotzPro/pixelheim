import { Assets, Rectangle, Texture, TextureStyle } from "pixi.js";

export const ART = 16;

// Pixel art: never smooth a texel. Module-level so every renderer inherits it.
TextureStyle.defaultOptions.scaleMode = "nearest";

export type Atlas = {
  frameSize: number;
  animations: Record<string, { sheet: string; frames: number; fps: number }>;
};

export type FrameBank = {
  /** animation name -> per-frame textures */
  frames: Map<string, Texture[]>;
  /** animation name -> milliseconds per frame */
  ms: Map<string, number>;
};

/** Cuts a horizontal sheet into per-frame textures. */
export function sliceSheet(sheet: Texture, count: number): Texture[] {
  return Array.from(
    { length: count },
    (_, i) => new Texture({ source: sheet.source, frame: new Rectangle(i * ART, 0, ART, ART) }),
  );
}

/** Loads atlas.json plus every sheet it names, sliced and paced. */
export async function loadFrameBank(): Promise<FrameBank> {
  const base = import.meta.env.BASE_URL;
  const atlas: Atlas = await Assets.load({ alias: "atlas", src: `${base}sprites/atlas.json` });
  await Assets.load(
    Object.entries(atlas.animations).map(([name, anim]) => ({ alias: name, src: `${base}sprites/${anim.sheet}` })),
  );
  const bank: FrameBank = { frames: new Map(), ms: new Map() };
  for (const [name, anim] of Object.entries(atlas.animations)) {
    bank.frames.set(name, sliceSheet(Assets.get(name) as Texture, anim.frames));
    bank.ms.set(name, 1000 / anim.fps);
  }
  return bank;
}

/** A soft oval shadow, drawn once and reused under every actor. */
export function makeShadowTexture(): Texture {
  const canvas = document.createElement("canvas");
  canvas.width = 16;
  canvas.height = 6;
  const ctx = canvas.getContext("2d")!;
  ctx.fillStyle = "rgba(0, 0, 0, 0.32)";
  ctx.beginPath();
  ctx.ellipse(8, 3, 6, 2.4, 0, 0, Math.PI * 2);
  ctx.fill();
  return Texture.from(canvas);
}

/** Corner darkening for the world viewport: quiet depth, no drama. */
export function makeVignetteTexture(width: number, height: number): Texture {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d")!;
  const gradient = ctx.createRadialGradient(
    width / 2,
    height / 2,
    Math.min(width, height) * 0.42,
    width / 2,
    height / 2,
    Math.max(width, height) * 0.72,
  );
  gradient.addColorStop(0, "rgba(0, 0, 0, 0)");
  gradient.addColorStop(1, "rgba(5, 6, 10, 0.42)");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);
  return Texture.from(canvas);
}

/** A soft radial light, drawn once on a 2D canvas and reused for every glow. */
export function makeGlowTexture(): Texture {
  const size = 64;
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d")!;
  const gradient = ctx.createRadialGradient(size / 2, size / 2, 2, size / 2, size / 2, size / 2);
  gradient.addColorStop(0, "rgba(255, 200, 110, 0.9)");
  gradient.addColorStop(0.5, "rgba(255, 160, 70, 0.35)");
  gradient.addColorStop(1, "rgba(255, 140, 50, 0)");
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, size, size);
  return Texture.from(canvas);
}
