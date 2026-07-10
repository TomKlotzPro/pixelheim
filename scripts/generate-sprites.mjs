/**
 * Generates the game's pixel-art sprites as real PNG files (no dependencies,
 * hand-rolled PNG encoder on top of node:zlib). Run: node scripts/generate-sprites.mjs
 * Outputs 16x16 PNGs to public/sprites/ and a x8 preview sheet to scripts/preview.png
 */
import { deflateSync } from "node:zlib";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const OUT = join(ROOT, "public", "sprites");
mkdirSync(OUT, { recursive: true });

function crc32(buf) {
  let crc = ~0;
  for (let n = 0; n < buf.length; n++) {
    crc ^= buf[n];
    for (let k = 0; k < 8; k++) crc = crc & 1 ? (crc >>> 1) ^ 0xedb88320 : crc >>> 1;
  }
  return ~crc >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

function encodePng(width, height, rgba) {
  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // color type RGBA
  const raw = Buffer.alloc(height * (1 + width * 4));
  for (let y = 0; y < height; y++) {
    raw[y * (1 + width * 4)] = 0; // filter: none
    rgba.copy(raw, y * (1 + width * 4) + 1, y * width * 4, (y + 1) * width * 4);
  }
  return Buffer.concat([sig, chunk("IHDR", ihdr), chunk("IDAT", deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]);
}

function hexToRgba(hex) {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff, 255];
}

function renderSprite(rows, palette, scale = 1) {
  const h = rows.length, w = rows[0].length;
  const buf = Buffer.alloc(w * scale * h * scale * 4);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const ch = rows[y][x];
      if (ch === ".") continue;
      const hex = palette[ch];
      if (!hex) throw new Error(`Unknown palette char "${ch}" at ${x},${y}`);
      const [r, g, b, a] = hexToRgba(hex);
      for (let sy = 0; sy < scale; sy++) {
        for (let sx = 0; sx < scale; sx++) {
          const i = ((y * scale + sy) * w * scale + x * scale + sx) * 4;
          buf[i] = r; buf[i + 1] = g; buf[i + 2] = b; buf[i + 3] = a;
        }
      }
    }
  }
  return { buf, w: w * scale, h: h * scale };
}

const SKIN = "#e8b88a";
const sprites = {
  // ---------------- heroes ----------------
  hero_warrior: {
    palette: { H: "#9aa5b1", D: "#5c6670", F: SKIN, K: "#22242b", B: "#7d8894", L: "#4a4f5a", O: "#8a5a2b", R: "#c23b3b" },
    rows: [
      "......RR........",
      ".....RRRR.......",
      "....HHHHHH......",
      "...HHHHHHHH.....",
      "...HFFFFFFH.....",
      "...HFKFFKFH.....",
      "...HFFFFFFH.....",
      "....FFFFFF......",
      "...BBBBBBBB.....",
      "..BBBBBBBBBB....",
      ".FBBBBBBBBBBF...",
      ".FBBOOOOOOBBF...",
      "..BBBBBBBBBB....",
      "...LLL..LLL.....",
      "...LLL..LLL.....",
      "...DD....DD.....",
    ],
  },
  hero_mage: {
    palette: { H: "#3b5bd6", D: "#26398f", F: SKIN, K: "#22242b", R: "#4a6be6", L: "#26398f", W: "#d8d0c0", Y: "#e8c34a" },
    rows: [
      ".......HH.......",
      "......HHHH......",
      ".....HHHHHH.....",
      "....HHHHHHHH....",
      "..HHHHHHHHHHHH..",
      "...WFFFFFFFFW...",
      "...WFKFFFFKW....",
      "...WFFFFFFFW....",
      "....WWWWWWW.....",
      "...RRRRRRRRR....",
      "..RRRRYYRRRRR...",
      ".FRRRRYYRRRRF...",
      "..RRRRRRRRRR....",
      "..RRRRRRRRRR....",
      "..LLLLLLLLLL....",
      "...DD....DD.....",
    ],
  },
  hero_rogue: {
    palette: { H: "#3a3f4a", D: "#23262e", F: SKIN, K: "#c23b3b", B: "#4a4f5a", L: "#2e323b", O: "#6b4a2b" },
    rows: [
      "................",
      ".....HHHHHH.....",
      "....HHHHHHHH....",
      "...HHHHHHHHHH...",
      "...HHFFFFFFHH...",
      "...HHFKFFKFHH...",
      "...HHHFFFFHHH...",
      "....HHHHHHHH....",
      "...BBBBBBBB.....",
      "..BBBBBBBBBB....",
      ".FBBBBBBBBBBF...",
      ".FBBOOOOOOBBF...",
      "..BBBBBBBBBB....",
      "...LLL..LLL.....",
      "...LLL..LLL.....",
      "...DD....DD.....",
    ],
  },
  hero_cleric: {
    palette: { H: "#e8e2d0", D: "#b8b0a0", F: SKIN, K: "#22242b", B: "#f0ead8", L: "#c8c0b0", Y: "#e8c34a" },
    rows: [
      ".......YY.......",
      ".....YYYYYY.....",
      "....HHHHHHHH....",
      "...HHHHHHHHHH...",
      "...HFFFFFFFFH...",
      "...HFKFFFFKFH...",
      "...HFFFFFFFFH...",
      "....FFFFFFFF....",
      "...BBBBBBBBBB...",
      "..BBBBYYBBBBB...",
      ".FBBBBYYBBBBBF..",
      ".FBBBYYYYBBBBF..",
      "..BBBBYYBBBBB...",
      "..BBBBBBBBBBB...",
      "..LLLLLLLLLLL...",
      "...DD.....DD....",
    ],
  },
  // ---------------- monsters ----------------
  slime: {
    palette: { G: "#4ec04e", D: "#2e8a2e", W: "#ffffff", K: "#1a1a1a" },
    rows: [
      "................",
      "................",
      "................",
      "................",
      "......GGGG......",
      "....GGGGGGGG....",
      "...GGGGGGGGGG...",
      "..GGGGGGGGGGGG..",
      "..GWWGGGGGGWWG..",
      ".GGWKGGGGGGWKGG.",
      ".GGGGGGGGGGGGGG.",
      ".GGGGGKKKKGGGGG.",
      ".GGGGGGGGGGGGGG.",
      ".GDGGGGGGGGGGDG.",
      "..DDGGGGGGGGDD..",
      "...DDDDDDDDDD...",
    ],
  },
  goblin: {
    palette: { G: "#6aa84f", D: "#456f33", K: "#1a1a1a", R: "#c23b3b", B: "#6b4a2b", W: "#e8e2d0" },
    rows: [
      "................",
      "..G..........G..",
      ".GG..GGGGGG..GG.",
      ".GGGGGGGGGGGGGG.",
      "..GGGGGGGGGGGG..",
      "...GRRGGGGRRG...",
      "...GRKGGGGKRG...",
      "...GGGGGGGGGG...",
      "....GWGWGWGG....",
      ".....GGGGGG.....",
      "....BBBBBBBB....",
      "...BBBBBBBBBB...",
      "..GBBBBBBBBBBG..",
      "...BBBBBBBBBB...",
      "....GG....GG....",
      "...GGG....GGG...",
    ],
  },
  skeleton: {
    palette: { W: "#e8e4d8", D: "#b0aa98", K: "#1a1a1a" },
    rows: [
      "....WWWWWWWW....",
      "...WWWWWWWWWW...",
      "...WWWWWWWWWW...",
      "...WKKWWWWKKW...",
      "...WKKWWWWKKW...",
      "...WWWWKKWWWW...",
      "....WKWKWKWW....",
      "......WWWW......",
      "....WWWWWWWW....",
      "..WWWWWWWWWWWW..",
      ".WW.WWWWWWWW.WW.",
      ".W..WWWWWWWW..W.",
      ".W..WWWWWWWW..W.",
      "....WW....WW....",
      "....WW....WW....",
      "...WWW....WWW...",
    ],
  },
  wolf: {
    palette: { G: "#8a8f9a", D: "#5c6070", K: "#1a1a1a", R: "#c23b3b", W: "#e8e4d8" },
    rows: [
      "................",
      ".GG..........GG.",
      ".GGG........GGG.",
      ".GGGG......GGGG.",
      "..GGGGGGGGGGGG..",
      "..GGGGGGGGGGGG..",
      "..GKKGGGGGGKKG..",
      "..GRRGGGGGGRRG..",
      "...GGGGGGGGGG...",
      "...GGGDDDDGGG...",
      "....GGDDDDGG....",
      ".....GWWWWG.....",
      ".....GWKKWG.....",
      "......WWWW......",
      "......W..W......",
      "................",
    ],
  },
  orc: {
    palette: { G: "#4f7a3a", D: "#365427", K: "#1a1a1a", R: "#c23b3b", W: "#e8e2d0", B: "#5c4630" },
    rows: [
      "..GG........GG..",
      ".GGGGGGGGGGGGGG.",
      ".GGGGGGGGGGGGGG.",
      ".GGRRGGGGGGRRGG.",
      ".GGRKGGGGGGKRGG.",
      ".GGGGGGGGGGGGGG.",
      ".GGWGGGGGGGGWGG.",
      ".GGWGGGGGGGGWGG.",
      "..GGGGGGGGGGGG..",
      "...BBBBBBBBBB...",
      "..BBBBBBBBBBBB..",
      ".GBBBBBBBBBBBBG.",
      ".GBBBBBBBBBBBBG.",
      "..BBBBBBBBBBBB..",
      "...GGG....GGG...",
      "..GGGG....GGGG..",
    ],
  },
  ghost: {
    palette: { W: "#dfe6f0", D: "#aab6c8", K: "#1a1a2a" },
    rows: [
      "......WWWW......",
      "....WWWWWWWW....",
      "...WWWWWWWWWW...",
      "..WWWWWWWWWWWW..",
      "..WWKKWWWWKKWW..",
      "..WWKKWWWWKKWW..",
      "..WWWWWWWWWWWW..",
      "..WWWWWKKWWWWW..",
      "..WWWWWWWWWWWW..",
      "..WWWWWWWWWWWW..",
      "..WWWWWWWWWWWW..",
      "..WWWWWWWWWWWW..",
      "..WDWWDWWDWWDW..",
      "..W.WW.WW.WW.W..",
      "................",
      "................",
    ],
  },
  golem: {
    palette: { S: "#8a8478", D: "#5f5a50", K: "#e8c34a", M: "#3a362e" },
    rows: [
      "...SSSSSSSSSS...",
      "..SSSSSSSSSSSS..",
      "..SSKKSSSSKKSS..",
      "..SSKKSSSSKKSS..",
      "..SSSSSSSSSSSS..",
      "..SSSSMMMMSSSS..",
      "...SSSSSSSSSS...",
      ".SSSSSSSSSSSSSS.",
      ".SSDSSSSSSSSDSS.",
      ".SSDSSSDDSSSDSS.",
      ".SSDSSSDDSSSDSS.",
      ".SSSSSSSSSSSSSS.",
      "..SSSS....SSSS..",
      "..SSSS....SSSS..",
      "..SSSS....SSSS..",
      ".SSSSSS..SSSSSS.",
    ],
  },
  troll: {
    palette: { T: "#7a6a4f", D: "#544933", K: "#1a1a1a", R: "#c23b3b", W: "#e8e2d0", G: "#4f7a3a" },
    rows: [
      "...TTTTTTTTTT...",
      "..TTTTTTTTTTTT..",
      "..TTKKTTTTKKTT..",
      "..TTKRTTTTRKTT..",
      "..TTTTTTTTTTTT..",
      "..TTWTTTTTTWTT..",
      "...TTTTTTTTTT...",
      "..TTTTTTTTTTTT..",
      ".TTTTTTTTTTTTTT.",
      "TTTTTTTTTTTTTTTT",
      "TTTGGGGGGGGGGTTT",
      ".TTGGGGGGGGGGTT.",
      "..TTTTTTTTTTTT..",
      "...TTT....TTT...",
      "...TTT....TTT...",
      "..TTTT....TTTT..",
    ],
  },
  wyvern: {
    palette: { G: "#3f8a5f", D: "#2a5f40", K: "#1a1a1a", Y: "#e8c34a", W: "#e8e2d0" },
    rows: [
      "DD............DD",
      "DDD..........DDD",
      "DDDD.GGGGGG.DDDD",
      ".DDDGGGGGGGGDDD.",
      ".DDGGYKGGKYGGDD.",
      "..DGGGGGGGGGGD..",
      "..GGGGWWWWGGGG..",
      "...GGGGGGGGGG...",
      "....GGGGGGGG....",
      "...GGGGGGGGGG...",
      "..GGGGGGGGGGGG..",
      "..GGGGGGGGGGGG..",
      "...GGGGGGGGGG...",
      "....GG....GG....",
      "....GGG..GGG....",
      "......DDDD......",
    ],
  },
  dragon: {
    palette: { R: "#c23b3b", D: "#8a2525", K: "#1a1a1a", Y: "#e8c34a", W: "#e8e2d0", O: "#e87a2a" },
    rows: [
      "DD.....YY.....DD",
      "DDD...YYYY...DDD",
      "DDDD.RRRRRR.DDDD",
      ".DDDRRRRRRRRDDD.",
      ".DDRRYKRRKYRRDD.",
      "..DRRRRRRRRRRD..",
      "..RRRRWWWWRRRR..",
      "...RRRWWWWRRR...",
      "....RRRRRRRR....",
      "...RRROOOORRR...",
      "..RRRROOOORRRR..",
      "..RRRRRRRRRRRR..",
      ".RRRRRRRRRRRRRR.",
      "..RRR.RRRR.RRR..",
      "..RR...RR...RR..",
      ".DDD...DD...DDD.",
    ],
  },
  // ---------------- items ----------------
  sword: {
    palette: { W: "#d8dde4", D: "#9aa5b1", G: "#e8c34a", B: "#6b4a2b" },
    rows: [
      ".......WW.......",
      ".......WW.......",
      ".......WW.......",
      ".......WW.......",
      ".......WW.......",
      ".......WW.......",
      ".......WW.......",
      ".......WW.......",
      ".......WW.......",
      ".......DD.......",
      "....GGGGGGGG....",
      ".......BB.......",
      ".......BB.......",
      ".......BB.......",
      "......GBBG......",
      ".......GG.......",
    ],
  },
  axe: {
    palette: { W: "#c8ced6", D: "#8a939e", B: "#6b4a2b" },
    rows: [
      "....WWWW........",
      "...WWWWWW.......",
      "..WWWWWWWW......",
      "..WWWWBBWW......",
      "..WWWWBBWWW.....",
      "...WWWBBWWW.....",
      "....WWBBWW......",
      "......BB........",
      "......BB........",
      "......BB........",
      "......BB........",
      "......BB........",
      "......BB........",
      "......BB........",
      "......BB........",
      "................",
    ],
  },
  dagger: {
    palette: { W: "#d8dde4", D: "#9aa5b1", G: "#3a3f4a", B: "#23262e" },
    rows: [
      "................",
      "................",
      ".......WW.......",
      ".......WW.......",
      ".......WW.......",
      ".......WW.......",
      ".......WW.......",
      ".......DD.......",
      ".....GGGGGG.....",
      ".......BB.......",
      ".......BB.......",
      ".......BB.......",
      "......GBBG......",
      "................",
      "................",
      "................",
    ],
  },
  staff: {
    palette: { B: "#6b4a2b", D: "#4f371f", M: "#7a4ae6", W: "#c8a8ff" },
    rows: [
      "......MMMM......",
      ".....MMWWMM.....",
      ".....MWWWWM.....",
      ".....MMWWMM.....",
      "......MMMM......",
      ".......BB.......",
      ".......BB.......",
      ".......BB.......",
      ".......BB.......",
      ".......BB.......",
      ".......BB.......",
      ".......BB.......",
      ".......BB.......",
      ".......BB.......",
      ".......DD.......",
      "................",
    ],
  },
  armor: {
    palette: { S: "#9aa5b1", D: "#5c6670", G: "#e8c34a" },
    rows: [
      "................",
      "..SS........SS..",
      ".SSSS......SSSS.",
      ".SSSSSSSSSSSSSS.",
      ".SSSSSSSSSSSSSS.",
      ".SSDSSSSSSSSDSS.",
      "..SSSSSSSSSSSS..",
      "..SSSSSSSSSSSS..",
      "..SSSSGGGSSSSS..",
      "..SSSSSSSSSSSS..",
      "..SSSSSSSSSSSS..",
      "...SSSSSSSSSS...",
      "...SSSSSSSSSS...",
      "....SSSSSSSS....",
      "................",
      "................",
    ],
  },
  robe: {
    palette: { R: "#4a6be6", D: "#26398f", Y: "#e8c34a" },
    rows: [
      "................",
      "..RR........RR..",
      ".RRRR......RRRR.",
      ".RRRRRRRRRRRRRR.",
      ".RRRRRRRRRRRRRR.",
      ".RRDRRRRRRRRDRR.",
      "..RRRRYYRRRRRR..",
      "..RRRRYYRRRRRR..",
      "..RRRYYYYRRRRR..",
      "..RRRRYYRRRRRR..",
      "..RRRRRRRRRRRR..",
      "..RRRRRRRRRRRR..",
      ".RRRRRRRRRRRRRR.",
      ".RRRRRRRRRRRRRR.",
      "................",
      "................",
    ],
  },
  shield: {
    palette: { S: "#8a939e", D: "#5c6670", B: "#6b4a2b", G: "#e8c34a" },
    rows: [
      "...SSSSSSSSSS...",
      "..SSSSSSSSSSSS..",
      "..SSBBBBBBBBSS..",
      "..SSBBBBBBBBSS..",
      "..SSBBGGGGBBSS..",
      "..SSBBGGGGBBSS..",
      "..SSBBBBBBBBSS..",
      "..SSBBBBBBBBSS..",
      "..SSSBBBBBBSSS..",
      "...SSBBBBBBSS...",
      "...SSSBBBBSSS...",
      "....SSBBBBSS....",
      ".....SSBBSS.....",
      "......SSSS......",
      ".......SS.......",
      "................",
    ],
  },
  potion_hp: {
    palette: { R: "#e64a5f", D: "#a82a3a", G: "#c8ced6", B: "#6b4a2b", W: "#ffffff" },
    rows: [
      "......BBBB......",
      "......BBBB......",
      ".......GG.......",
      ".......GG.......",
      "......GGGG......",
      ".....GGGGGG.....",
      "....GGRRRRGG....",
      "....GRRRRRRG....",
      "...GRRRRRRRRG...",
      "...GRRWRRRRRG...",
      "...GRRRRRRRRG...",
      "...GRRRRRRRRG...",
      "....GRRRRRRG....",
      "....GGRRRRGG....",
      ".....GGGGGG.....",
      "................",
    ],
  },
  potion_mp: {
    palette: { R: "#4a6be6", D: "#26398f", G: "#c8ced6", B: "#6b4a2b", W: "#ffffff" },
    rows: [
      "......BBBB......",
      "......BBBB......",
      ".......GG.......",
      ".......GG.......",
      "......GGGG......",
      ".....GGGGGG.....",
      "....GGRRRRGG....",
      "....GRRRRRRG....",
      "...GRRRRRRRRG...",
      "...GRRWRRRRRG...",
      "...GRRRRRRRRG...",
      "...GRRRRRRRRG...",
      "....GRRRRRRG....",
      "....GGRRRRGG....",
      ".....GGGGGG.....",
      "................",
    ],
  },
  bread: {
    palette: { B: "#d8a85a", D: "#a87a3a", W: "#f0d8a8" },
    rows: [
      "................",
      "................",
      "................",
      "................",
      "....BBBBBBB.....",
      "...BBBBBBBBBB...",
      "..BBWWBBBBBBBB..",
      "..BBBBWWBBBBBB..",
      ".BBBBBBBWWBBBBB.",
      ".BBBBBBBBBWWBBB.",
      ".DBBBBBBBBBBBBD.",
      ".DDBBBBBBBBBBDD.",
      "..DDDDDDDDDDDD..",
      "................",
      "................",
      "................",
    ],
  },
  cheese: {
    palette: { Y: "#e8c34a", D: "#c89a2a", O: "#a87a1a" },
    rows: [
      "................",
      "................",
      "................",
      "......YYYYY.....",
      "....YYYYYYYYY...",
      "..YYYYYYYYYYYY..",
      ".YYYYYYYYYYYYYY.",
      ".YYODYYYYYODYYY.",
      ".YYYYYYYYYYYYYY.",
      ".YYYYYODYYYYYYY.",
      ".YYYYYYYYYYODYY.",
      ".YYODYYYYYYYYYY.",
      ".DDDDDDDDDDDDDD.",
      ".DDDDDDDDDDDDDD.",
      "................",
      "................",
    ],
  },
  gold: {
    palette: { Y: "#e8c34a", D: "#c89a2a", W: "#f8e8a8" },
    rows: [
      "................",
      "................",
      "................",
      "......YYYY......",
      "....YYYYYYYY....",
      "...YYWWYYYYYY...",
      "...YWYYYYYYYY...",
      "..YYYYYYYYYYYY..",
      "..YYYYYDDYYYYY..",
      "..YYYYDYYDYYYY..",
      "..YYYYYDDYYYYY..",
      "...YYYYYYYYYY...",
      "...YYYYYYYYYY...",
      "....YYYYYYYY....",
      "......DDDD......",
      "................",
    ],
  },
  gem: {
    palette: { G: "#4ae6c8", D: "#2aa890", W: "#c8fff0" },
    rows: [
      "................",
      "................",
      "................",
      "....GGGGGGGG....",
      "...GWGGGGGGGG...",
      "..GWWGGGGGGGGG..",
      "..GWGGGGGGGGDG..",
      "...GGGGGGGGDD...",
      "....GGGGGGDD....",
      ".....GGGGDD.....",
      "......GGDD......",
      ".......GD.......",
      "................",
      "................",
      "................",
      "................",
    ],
  },
  scale: {
    palette: { R: "#c23b3b", D: "#8a2525", W: "#e88a8a" },
    rows: [
      "................",
      "................",
      "....RRRRRRRR....",
      "...RRRRRRRRRR...",
      "...RWRRRRRRRR...",
      "...RWRRRRRRRR...",
      "...RRRRRRRRDR...",
      "....RRRRRRDD....",
      "....RRRRRRDD....",
      ".....RRRRDD.....",
      ".....RRRRDD.....",
      "......RRDD......",
      "......RRDD......",
      ".......DD.......",
      "................",
      "................",
    ],
  },
};

const names = Object.keys(sprites);
for (const name of names) {
  const { rows, palette } = sprites[name];
  if (rows.length !== 16 || rows.some((r) => r.length !== 16)) throw new Error(`${name} is not 16x16`);
  const { buf, w, h } = renderSprite(rows, palette);
  writeFileSync(join(OUT, `${name}.png`), encodePng(w, h, buf));
}

// x8 preview sheet for eyeballing the art (not shipped in the app)
const SCALE = 8, COLS = 7, CELL = 16 * SCALE + 8;
const rowsCount = Math.ceil(names.length / COLS);
const sheet = Buffer.alloc(COLS * CELL * rowsCount * CELL * 4);
// dark checker background so light sprites stay visible
for (let i = 0; i < sheet.length; i += 4) { sheet[i] = 30; sheet[i + 1] = 32; sheet[i + 2] = 38; sheet[i + 3] = 255; }
names.forEach((name, idx) => {
  const { buf, w, h } = renderSprite(sprites[name].rows, sprites[name].palette, SCALE);
  const ox = (idx % COLS) * CELL + 4, oy = Math.floor(idx / COLS) * CELL + 4;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const si = (y * w + x) * 4;
      if (buf[si + 3] === 0) continue;
      const di = ((oy + y) * COLS * CELL + ox + x) * 4;
      buf.copy(sheet, di, si, si + 4);
    }
  }
});
writeFileSync(join(ROOT, "scripts", "preview.png"), encodePng(COLS * CELL, rowsCount * CELL, sheet));
console.log(`Wrote ${names.length} sprites to public/sprites/ and scripts/preview.png`);
