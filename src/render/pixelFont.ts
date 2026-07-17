import { Sprite, Texture } from "pixi.js";

/**
 * A real bitmap pixel font, drawn from bit patterns onto a canvas texture.
 * Browser vector text never sits right on a 16px world; these glyphs are
 * pixels from birth and scale with the same nearest-neighbor crunch as the
 * sprites. Variable width, 5 rows tall, 1px black outline for readability.
 */
const GLYPHS: Record<string, string[]> = {
  A: [".##.", "#..#", "####", "#..#", "#..#"],
  B: ["###.", "#..#", "###.", "#..#", "###."],
  C: [".###", "#...", "#...", "#...", ".###"],
  D: ["###.", "#..#", "#..#", "#..#", "###."],
  E: ["####", "#...", "###.", "#...", "####"],
  F: ["####", "#...", "###.", "#...", "#..."],
  G: [".###", "#...", "#.##", "#..#", ".###"],
  H: ["#..#", "#..#", "####", "#..#", "#..#"],
  I: ["###", ".#.", ".#.", ".#.", "###"],
  J: ["...#", "...#", "...#", "#..#", ".##."],
  K: ["#..#", "#.#.", "##..", "#.#.", "#..#"],
  L: ["#...", "#...", "#...", "#...", "####"],
  M: ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
  N: ["#..#", "##.#", "#.##", "#..#", "#..#"],
  O: [".##.", "#..#", "#..#", "#..#", ".##."],
  P: ["###.", "#..#", "###.", "#...", "#..."],
  Q: [".##.", "#..#", "#..#", "#.##", ".###"],
  R: ["###.", "#..#", "###.", "#.#.", "#..#"],
  S: [".###", "#...", ".##.", "...#", "###."],
  T: ["###", ".#.", ".#.", ".#.", ".#."],
  U: ["#..#", "#..#", "#..#", "#..#", ".##."],
  V: ["#..#", "#..#", "#..#", ".##.", ".#.."],
  W: ["#...#", "#...#", "#.#.#", "#.#.#", ".#.#."],
  X: ["#..#", ".##.", ".##.", ".##.", "#..#"],
  Y: ["#.#", "#.#", ".#.", ".#.", ".#."],
  Z: ["####", "..#.", ".#..", "#...", "####"],
  "0": [".##.", "#..#", "#..#", "#..#", ".##."],
  "1": [".#.", "##.", ".#.", ".#.", "###"],
  "2": ["###.", "...#", ".##.", "#...", "####"],
  "3": ["###.", "...#", ".##.", "...#", "###."],
  "4": ["#..#", "#..#", "####", "...#", "...#"],
  "5": ["####", "#...", "###.", "...#", "###."],
  "6": [".###", "#...", "###.", "#..#", ".##."],
  "7": ["####", "...#", "..#.", ".#..", ".#.."],
  "8": [".##.", "#..#", ".##.", "#..#", ".##."],
  "9": [".##.", "#..#", ".###", "...#", "###."],
  "!": ["#", "#", "#", ".", "#"],
  "?": ["##.", "..#", ".#.", "...", ".#."],
  "-": ["...", "...", "###", "...", "..."],
  "+": ["...", ".#.", "###", ".#.", "..."],
  ".": [".", ".", ".", ".", "#"],
  "'": ["#", "#", ".", ".", "."],
  " ": ["..", "..", "..", "..", ".."],
};

const ROWS = 5;
const SPACING = 1;
const OUTLINE = 1;

function toHex(color: number): string {
  return `#${color.toString(16).padStart(6, "0")}`;
}

const textureCache = new Map<string, Texture>();

/** Renders a string into a crisp pixel texture (1 canvas px per font px). */
export function pixelTextTexture(content: string, fill: number): Texture {
  const key = `${content}|${fill}`;
  const cached = textureCache.get(key);
  if (cached) return cached;

  const glyphs = content
    .toUpperCase()
    .split("")
    .map((ch) => GLYPHS[ch] ?? GLYPHS["?"]);
  const width = glyphs.reduce((sum, g) => sum + g[0].length + SPACING, -SPACING) + OUTLINE * 2;
  const height = ROWS + OUTLINE * 2;

  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d")!;

  const stamp = (ox: number, oy: number, color: string) => {
    ctx.fillStyle = color;
    let x = OUTLINE;
    for (const glyph of glyphs) {
      for (let row = 0; row < ROWS; row++) {
        for (let col = 0; col < glyph[row].length; col++) {
          if (glyph[row][col] === "#") ctx.fillRect(x + col + ox, OUTLINE + row + oy, 1, 1);
        }
      }
      x += glyph[0].length + SPACING;
    }
  };

  // the outline first (8 directions), then the face
  for (const [ox, oy] of [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, -1], [-1, 1], [1, 1]]) {
    stamp(ox, oy, "#000000");
  }
  stamp(0, 0, toHex(fill));

  const texture = Texture.from(canvas);
  textureCache.set(key, texture);
  return texture;
}

/** A ready-to-place sprite of pixel text. Scale it in whole numbers. */
export function pixelText(content: string, fill: number, scale = 1): Sprite {
  const sprite = new Sprite(pixelTextTexture(content, fill));
  sprite.scale.set(scale);
  return sprite;
}
