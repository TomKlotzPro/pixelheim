import { BufferAttribute, BufferGeometry } from "three";

export const ART = 16;

/**
 * The voxel source of truth: generate-sprites.mjs dumps every sprite's ASCII
 * grid + palette into voxels.json, and the 3D renderer extrudes those grids
 * directly. Same rows the PNGs are baked from - one art source (PIX-111).
 */
export type VoxelSprite = { rows: string[]; palette: Record<string, string> };
export type VoxelSheet = { art: number; sprites: Record<string, VoxelSprite> };

let sheetPromise: Promise<VoxelSheet> | null = null;

export function loadVoxelSheet(): Promise<VoxelSheet> {
  if (!sheetPromise) {
    sheetPromise = fetch(`${import.meta.env.BASE_URL}sprites/voxels.json`).then((res) => {
      if (!res.ok) throw new Error(`voxels.json failed to load: ${res.status}`);
      return res.json() as Promise<VoxelSheet>;
    });
  }
  return sheetPromise;
}

/** A 16x16 grid of resolved colors; null is transparent. Indexed [y][x]. */
export type ColorGrid = (string | null)[][];

export function colorGrid(sprite: VoxelSprite): ColorGrid {
  return sprite.rows.map((row) => Array.from(row, (ch) => (ch === "." ? null : (sprite.palette[ch] ?? null))));
}

/** Paint overlay grids (worn gear) over a base grid, PIX-107 style. */
export function overlayGrids(base: ColorGrid, overlays: ColorGrid[]): ColorGrid {
  const out = base.map((row) => row.slice());
  for (const grid of overlays) {
    for (let y = 0; y < ART; y++) {
      for (let x = 0; x < ART; x++) {
        if (grid[y][x]) out[y][x] = grid[y][x];
      }
    }
  }
  return out;
}

function hexToRgb(hex: string): [number, number, number] {
  const n = Number.parseInt(hex.slice(1), 16);
  return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
}

export function darken(hex: string, k: number): string {
  const n = Number.parseInt(hex.slice(1), 16);
  const scale = (shift: number) => Math.round(((n >> shift) & 255) * k);
  return `#${((scale(16) << 16) | (scale(8) << 8) | scale(0)).toString(16).padStart(6, "0")}`;
}

/** The grid's average color; the earth under tiles and skirt sides wear it. */
export function averageColor(grid: ColorGrid): string {
  let r = 0;
  let g = 0;
  let b = 0;
  let count = 0;
  for (const row of grid) {
    for (const hex of row) {
      if (!hex) continue;
      const n = Number.parseInt(hex.slice(1), 16);
      r += (n >> 16) & 255;
      g += (n >> 8) & 255;
      b += n & 255;
      count++;
    }
  }
  if (count === 0) return "#000000";
  const c = (v: number) => Math.round(v / count);
  return `#${((c(r) << 16) | (c(g) << 8) | c(b)).toString(16).padStart(6, "0")}`;
}

const GROUND_DISTANCE_SQ = 90 * 90;

function colorDistanceSq(a: string, b: string): number {
  const an = Number.parseInt(a.slice(1), 16);
  const bn = Number.parseInt(b.slice(1), 16);
  const dr = ((an >> 16) & 255) - ((bn >> 16) & 255);
  const dg = ((an >> 8) & 255) - ((bn >> 8) & 255);
  const db = (an & 255) - (bn & 255);
  return dr * dr + dg * dg + db * db;
}

/**
 * Prop tiles bake their ground into the grid (a lamp stands on grass pixels).
 * The corners are always ground, so anything close to a corner color lies
 * flat and the rest stands up. Prop holes in the ground get the average
 * ground color, so nothing floats over a gap.
 */
export function splitGround(grid: ColorGrid): { ground: ColorGrid; prop: ColorGrid } {
  const corners = [grid[0][0], grid[0][ART - 1], grid[ART - 1][0], grid[ART - 1][ART - 1]].filter(
    (hex): hex is string => hex !== null,
  );
  const isGround = (hex: string) => corners.some((corner) => colorDistanceSq(hex, corner) < GROUND_DISTANCE_SQ);
  const ground: ColorGrid = grid.map((row) => row.map((hex) => (hex && isGround(hex) ? hex : null)));
  const prop: ColorGrid = grid.map((row) => row.map((hex) => (hex && !isGround(hex) ? hex : null)));
  const fill = averageColor(ground);
  for (let y = 0; y < ART; y++) {
    for (let x = 0; x < ART; x++) {
      if (!ground[y][x]) ground[y][x] = fill;
    }
  }
  return { ground, prop };
}

type Faces = { top?: boolean; bottom?: boolean; north?: boolean; south?: boolean; west?: boolean; east?: boolean };
const ALL_FACES: Faces = { top: true, bottom: true, north: true, south: true, west: true, east: true };

/**
 * Accumulates colored cuboids into one BufferGeometry with vertex colors;
 * a single Lambert material lights everything. Face selection lets flat
 * ground skip the faces nobody can see.
 */
export class VoxelBuilder {
  private positions: number[] = [];
  private normals: number[] = [];
  private colors: number[] = [];
  private indices: number[] = [];

  /** One axis-aligned cuboid: min corner (x, y, z), size (w, h, d). */
  box(x: number, y: number, z: number, w: number, h: number, d: number, hex: string, faces: Faces = ALL_FACES): void {
    const [r, g, b] = hexToRgb(hex);
    const x1 = x + w;
    const y1 = y + h;
    const z1 = z + d;
    // Each face: 4 corners counter-clockwise seen from outside, one normal.
    const quads: [boolean | undefined, number[][], [number, number, number]][] = [
      [
        faces.top,
        [
          [x, y1, z1],
          [x1, y1, z1],
          [x1, y1, z],
          [x, y1, z],
        ],
        [0, 1, 0],
      ],
      [
        faces.bottom,
        [
          [x, y, z],
          [x1, y, z],
          [x1, y, z1],
          [x, y, z1],
        ],
        [0, -1, 0],
      ],
      [
        faces.north,
        [
          [x1, y, z],
          [x, y, z],
          [x, y1, z],
          [x1, y1, z],
        ],
        [0, 0, -1],
      ],
      [
        faces.south,
        [
          [x, y, z1],
          [x1, y, z1],
          [x1, y1, z1],
          [x, y1, z1],
        ],
        [0, 0, 1],
      ],
      [
        faces.west,
        [
          [x, y, z],
          [x, y, z1],
          [x, y1, z1],
          [x, y1, z],
        ],
        [-1, 0, 0],
      ],
      [
        faces.east,
        [
          [x1, y, z1],
          [x1, y, z],
          [x1, y1, z],
          [x1, y1, z1],
        ],
        [1, 0, 0],
      ],
    ];
    for (const [wanted, corners, normal] of quads) {
      if (!wanted) continue;
      const base = this.positions.length / 3;
      for (const corner of corners) {
        this.positions.push(corner[0], corner[1], corner[2]);
        this.normals.push(normal[0], normal[1], normal[2]);
        this.colors.push(r, g, b);
      }
      this.indices.push(base, base + 1, base + 2, base, base + 2, base + 3);
    }
  }

  build(): BufferGeometry {
    const geometry = new BufferGeometry();
    geometry.setAttribute("position", new BufferAttribute(new Float32Array(this.positions), 3));
    geometry.setAttribute("normal", new BufferAttribute(new Float32Array(this.normals), 3));
    geometry.setAttribute("color", new BufferAttribute(new Float32Array(this.colors), 3));
    geometry.setIndex(this.indices);
    return geometry;
  }
}

/** Merge a grid row into same-color runs; the unit of extrusion. */
function runs(row: (string | null)[]): { x0: number; len: number; hex: string }[] {
  const out: { x0: number; len: number; hex: string }[] = [];
  let x = 0;
  while (x < row.length) {
    const hex = row[x];
    if (!hex) {
      x++;
      continue;
    }
    let end = x + 1;
    while (end < row.length && row[end] === hex) end++;
    out.push({ x0: x, len: end - x, hex });
    x = end;
  }
  return out;
}

function luminance(hex: string): number {
  const n = Number.parseInt(hex.slice(1), 16);
  return (0.299 * ((n >> 16) & 255) + 0.587 * ((n >> 8) & 255) + 0.114 * (n & 255)) / 255;
}

/**
 * The grid lying on the ground as voxel columns: every pixel run becomes a
 * block rising to `top`, nudged by its brightness (`relief`) so grass blades
 * and pebbles physically stick out of the ground instead of being paint.
 * Origin: tile corner (0,0). Bottom faces are never visible and are skipped.
 */
export function extrudeFlat(builder: VoxelBuilder, grid: ColorGrid, top: number, relief = 0): void {
  for (let y = 0; y < grid.length; y++) {
    for (const run of runs(grid[y])) {
      const h = Math.max(0.3, top + (relief > 0 ? (luminance(run.hex) - 0.4) * relief : 0));
      builder.box(run.x0, 0, y, run.len, h, 1, run.hex, {
        top: true,
        north: true,
        south: true,
        west: true,
        east: true,
      });
    }
  }
}

/**
 * The grid standing up, diorama style: the bottom pixel row lands at y=oy
 * (feet on the ground) and the slab is `depth` voxels thick around z=oz.
 * Default origin is centered (-8..8) so actor meshes can flip in place;
 * terrain passes tile-corner offsets instead.
 */
export function extrudeUpright(builder: VoxelBuilder, grid: ColorGrid, depth = 2, ox = -ART / 2, oy = 0, oz = 0): void {
  const rows = grid.length;
  for (let y = 0; y < rows; y++) {
    for (const run of runs(grid[y])) {
      builder.box(run.x0 + ox, rows - 1 - y + oy, oz - depth / 2, run.len, 1, depth, run.hex);
    }
  }
}

/** A one-off upright mesh geometry for actors, prompt marks, chests. */
export function uprightGeometry(grid: ColorGrid, depth = 2): BufferGeometry {
  const builder = new VoxelBuilder();
  extrudeUpright(builder, grid, depth, -(grid[0]?.length ?? ART) / 2);
  return builder.build();
}
