import {
  BoxGeometry,
  BufferAttribute,
  Color,
  Group,
  InstancedMesh,
  Matrix4,
  Mesh,
  type MeshLambertMaterial,
} from "three";
import { WILD_TILES } from "../../state/shared";
import { regionAt } from "../../world/parseMap";
import { TILES } from "../../world/tiles";
import type { TileId, WorldMap } from "../../world/types";
import {
  ART,
  averageColor,
  colorGrid,
  extrudeFlat,
  extrudeUpright,
  shiftGrid,
  splitGround,
  VoxelBuilder,
  type VoxelSheet,
} from "./voxelData";

/** Tall solid blocks: the sprite becomes the top face, the sides are stone. */
const BLOCK_HEIGHTS: Partial<Record<TileId, number>> = {
  mountain: 14,
  wall: 10,
  roof: 11,
  roof_slate: 11,
  roof_violet: 11,
  roof_awning: 11,
  roof_moss: 11,
};

/** Ground that is not at the standard height; everything else lies at 1. */
const FLAT_TOPS: Partial<Record<TileId, number>> = { water: 0.45, marsh: 0.8, bridge: 1.6 };
/** How far a pixel's brightness pushes its column out of the ground. */
const FLAT_RELIEF: Partial<Record<TileId, number>> = { water: 0, bridge: 0.3, path: 0.5, floor: 0.3, sand: 0.5 };
const DEFAULT_RELIEF = 1.1;
export const GROUND_TOP = 1;

/**
 * Facade tiles are PART of a building or cliff in the maps: they render as a
 * solid block with their art extruded onto the street face. Doors and cave
 * mouths sit at ground level (walking in reads as stepping through them);
 * hanging shop signs float high on the wall. Value = block height.
 */
const FACADE_TILES: Partial<Record<TileId, number>> = {
  sign_goods: 11,
  sign_smith: 11,
  sign_potion: 11,
  sign_inn: 11,
  door: 10,
  door_shut: 10,
  cave: 14,
};
/** Where the facade prop's feet land: doors on the ground, signs held high. */
const FACADE_PROP_Y: Partial<Record<TileId, number>> = { door: 1, door_shut: 1, cave: 1 };
const SIGN_PROP_Y = -1;

/**
 * Terrain that breathes, matching the Pixi sway/shimmer sheets: frame B is
 * the same grid wrap-shifted, and the pair alternates on a slow beat.
 */
const ANIMATED: Partial<Record<TileId, { dx: number; dy: number; period: number }>> = {
  grass: { dx: 1, dy: 1, period: 800 },
  flowers: { dx: 1, dy: 1, period: 800 },
  forest: { dx: 1, dy: 1, period: 800 },
  marsh: { dx: 1, dy: 1, period: 800 },
};

/** Same stable hash as the Pixi terrain: grass repeats less. */
const GRASS_VARIANTS = [
  "tile_grass",
  "tile_grass",
  "tile_grass",
  "tile_grass",
  "tile_grass",
  "tile_grass2",
  "tile_grass3",
];

function grassVariant(x: number, y: number): string {
  const hash = Math.abs((x * 73856093) ^ (y * 19349663));
  return GRASS_VARIANTS[hash % GRASS_VARIANTS.length];
}

/**
 * Derived decoration, no map edits: a position hash sprinkles flower patches,
 * stones and tall tufts over grass, and round bushes through the forest.
 */
function decorHash(x: number, y: number): number {
  return Math.abs((x * 83492791) ^ (y * 19349663));
}

type DecorKind = "flowers" | "stone" | "tuft" | "bush";

function decorFor(tile: TileId, h: number, wild: boolean): DecorKind | null {
  if (tile === "grass" && !wild) {
    if (h % 17 === 0) return "flowers";
    if (h % 23 === 3) return "stone";
    if (h % 7 === 1) return "tuft";
    return null;
  }
  // The wilds stay stern - no flower patches - but stones and bushes belong.
  if (tile === "grass" && h % 23 === 3) return "stone";
  if (tile === "forest" && h % 5 < 2) return "bush";
  return null;
}

/** Little hand-built voxel props, centered on their own origin. */
function decorGeometry(kind: DecorKind): VoxelBuilder {
  const b = new VoxelBuilder();
  if (kind === "flowers") {
    const blooms: [number, number, string][] = [
      [-4, -2, "#e64a5f"],
      [1, 3, "#e8c34a"],
      [4, -3, "#b06ee8"],
    ];
    for (const [x, z, color] of blooms) {
      b.box(x, 0, z, 1, 2, 1, "#2d6b44");
      b.box(x - 1, 2, z - 1, 2, 1, 2, color);
    }
  } else if (kind === "stone") {
    b.box(-3, 0, -2, 4, 2, 4, "#8a8f9a");
    b.box(0, 0, 0, 3, 3, 3, "#6b7078");
    b.box(-1, 2, -1, 2, 1, 2, "#9aa0ab");
  } else if (kind === "tuft") {
    b.box(-3, 0, 0, 1, 3, 1, "#4a8f40");
    b.box(0, 0, -2, 1, 4, 1, "#5aa04a");
    b.box(2, 0, 1, 1, 3, 1, "#3d7a35");
  } else {
    b.box(-4, 0, -3, 8, 2, 7, "#2d6b44");
    b.box(-3, 2, -2, 6, 2, 5, "#3e8f5c");
    b.box(-1, 4, -1, 3, 1, 3, "#4a9f5c");
    b.box(2, 3, 0, 1, 1, 1, "#e64a5f");
    b.box(-2, 2, -2, 1, 1, 1, "#e64a5f");
  }
  return b;
}

const PLAIN = new Color(1, 1, 1);
/** Wild-region tiles darken a touch: danger reads without the 2D tuft overlay. */
const DANGER = new Color(0.68, 0.68, 0.72);
const EARTH = new Color("#3a2c20");

type Cell = { x: number; y: number; danger: boolean };
type SwayPair = { a: InstancedMesh; b: InstancedMesh; period: number; phase: number };

/**
 * The ground as a diorama: every tile type is extruded once from its grid and
 * instanced across the map - flat ground with colored relief, tall blocks for
 * walls and roofs, props standing upright over their own ground pixels -
 * plus derived chimneys and scattered decor, and a two-frame breeze.
 */
export class VoxelTerrain {
  readonly group = new Group();
  /** Chimney mouths, for the atmosphere's smoke. */
  chimneyTops: { x: number; y: number; z: number }[] = [];
  private material: MeshLambertMaterial;
  /** Water alone is translucent: the earth ghosts through the shallows. */
  private waterMaterial: MeshLambertMaterial;
  private animated: SwayPair[] = [];

  constructor(material: MeshLambertMaterial, waterMaterial: MeshLambertMaterial) {
    this.material = material;
    this.waterMaterial = waterMaterial;
  }

  private instanced(
    builder: VoxelBuilder,
    cells: Cell[],
    castShadow: boolean,
    material = this.material,
  ): InstancedMesh {
    const mesh = new InstancedMesh(builder.build(), material, cells.length);
    const matrix = new Matrix4();
    cells.forEach((cell, i) => {
      matrix.makeTranslation(cell.x * ART, 0, cell.y * ART);
      mesh.setMatrixAt(i, matrix);
      mesh.setColorAt(i, cell.danger ? DANGER : PLAIN);
    });
    mesh.castShadow = castShadow;
    mesh.receiveShadow = true;
    mesh.computeBoundingSphere();
    this.group.add(mesh);
    return mesh;
  }

  build(sheet: VoxelSheet, map: WorldMap): void {
    this.dispose();

    const buckets = new Map<string, { tile: TileId; cells: Cell[] }>();
    const decorCells = new Map<DecorKind, { x: number; y: number; ox: number; oz: number }[]>();
    const chimneys = new VoxelBuilder();
    let chimneyCount = 0;
    const foam = new VoxelBuilder();
    let foamCount = 0;
    for (let y = 0; y < map.height; y++) {
      for (let x = 0; x < map.width; x++) {
        const tile = map.tiles[y][x];
        const spriteName = tile === "grass" ? grassVariant(x, y) : TILES[tile].sprite;
        let bucket = buckets.get(spriteName);
        if (!bucket) {
          bucket = { tile, cells: [] };
          buckets.set(spriteName, bucket);
        }
        bucket.cells.push({ x, y, danger: WILD_TILES.has(tile) && regionAt(map, x, y) !== null });

        const decor = decorFor(tile, decorHash(x, y), regionAt(map, x, y) !== null);
        if (decor) {
          const h = decorHash(x, y);
          let list = decorCells.get(decor);
          if (!list) {
            list = [];
            decorCells.set(decor, list);
          }
          list.push({ x, y, ox: 5 + ((h >> 3) % 7), oz: 5 + ((h >> 7) % 7) });
        }

        // Water meets land with a line of foam, like the 2D shore overlay:
        // a pale lip along every bank, riding just above the surface.
        if (tile === "water") {
          const wx = x * ART;
          const wz = y * ART;
          const top = FLAT_TOPS.water ?? 0.45;
          const banks: [TileId | undefined, number, number, number, number][] = [
            [map.tiles[y - 1]?.[x], wx, wz, ART, 1.1],
            [map.tiles[y + 1]?.[x], wx, wz + ART - 1.1, ART, 1.1],
            [map.tiles[y]?.[x - 1], wx, wz, 1.1, ART],
            [map.tiles[y]?.[x + 1], wx + ART - 1.1, wz, 1.1, ART],
          ];
          for (const [neighbor, fx, fz, w, d] of banks) {
            if (!neighbor || neighbor === "water") continue;
            foam.box(fx, top, fz, w, 0.4, d, "#d9edf5", {
              top: true,
              north: true,
              south: true,
              west: true,
              east: true,
            });
            foamCount++;
          }
        }

        // Hashed chimneys on top-edge roofs, like the Pixi overlay - but with
        // real bricks and (courtesy of the atmosphere) real smoke.
        const height = BLOCK_HEIGHTS[tile];
        if (height && tile.startsWith("roof") && !(map.tiles[y - 1]?.[x] ?? "").startsWith("roof")) {
          if ((x * 31 + y * 7) % 5 === 0) {
            const wx = x * ART;
            const wz = y * ART;
            chimneys.box(wx + 5, height, wz + 4, 4, 5, 4, "#6b4034");
            chimneys.box(wx + 4, height + 5, wz + 3, 6, 1, 6, "#3a2a26");
            this.chimneyTops.push({ x: wx + 7, y: height + 6, z: wz + 6 });
            chimneyCount++;
          }
        }
      }
    }

    for (const [spriteName, { tile, cells }] of buckets) {
      const sprite = sheet.sprites[spriteName];
      if (!sprite) continue;
      const grid = colorGrid(sprite);
      const builder = new VoxelBuilder();
      const blockHeight = BLOCK_HEIGHTS[tile];
      const facadeHeight = FACADE_TILES[tile];
      const facade = facadeHeight !== undefined;
      const upright = !facade && blockHeight === undefined && tile !== "water" && !TILES[tile].walkable;
      if (tile === "water") {
        // Calm waters (PIX-112): one still, glassy pane per tile - the mean
        // of the sprite's blues, no speckle, no motion. Foam marks the banks.
        // Top face only: neighboring panes meet seamlessly, and the banks are
        // walled by the land tiles' own sides.
        builder.box(0, 0, 0, ART, FLAT_TOPS.water ?? GROUND_TOP, ART, averageColor(grid), { top: true });
      } else if (facade) {
        // The building or cliff face carries the door, cave mouth or sign.
        const { ground, prop } = splitGround(grid);
        builder.box(0, 0, 0, ART, facadeHeight, ART, averageColor(ground), {
          top: true,
          north: true,
          south: true,
          west: true,
          east: true,
        });
        extrudeUpright(builder, prop, 2, 0, FACADE_PROP_Y[tile] ?? SIGN_PROP_Y, ART - 1);
      } else if (blockHeight !== undefined) {
        // Gentle relief: enough for shingle texture, no sawtooth roofline.
        extrudeFlat(builder, grid, blockHeight, 0.45);
      } else if (upright) {
        const { ground, prop } = splitGround(grid);
        extrudeFlat(builder, ground, GROUND_TOP, 0.8);
        extrudeUpright(builder, prop, 2, 0, GROUND_TOP, ART / 2);
      } else {
        extrudeFlat(builder, grid, FLAT_TOPS[tile] ?? GROUND_TOP, FLAT_RELIEF[tile] ?? DEFAULT_RELIEF);
      }
      const material = tile === "water" ? this.waterMaterial : this.material;
      const mesh = this.instanced(builder, cells, blockHeight !== undefined || upright || facade, material);

      // The breeze: flat animated tiles get a second, wrap-shifted frame.
      const anim = !facade && blockHeight === undefined && !upright ? ANIMATED[tile] : undefined;
      if (anim) {
        const alt = new VoxelBuilder();
        extrudeFlat(
          alt,
          shiftGrid(grid, anim.dx, anim.dy),
          FLAT_TOPS[tile] ?? GROUND_TOP,
          FLAT_RELIEF[tile] ?? DEFAULT_RELIEF,
        );
        const meshB = this.instanced(alt, cells, false, material);
        meshB.visible = false;
        let phase = 0;
        for (const c of spriteName) phase = (phase * 31 + c.charCodeAt(0)) % 977;
        this.animated.push({ a: mesh, b: meshB, period: anim.period, phase });
      }
    }

    for (const [kind, spots] of decorCells) {
      const mesh = new InstancedMesh(decorGeometry(kind).build(), this.material, spots.length);
      const matrix = new Matrix4();
      spots.forEach((spot, i) => {
        matrix.makeTranslation(spot.x * ART + spot.ox, GROUND_TOP, spot.y * ART + spot.oz);
        mesh.setMatrixAt(i, matrix);
        mesh.setColorAt(i, PLAIN);
      });
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      mesh.computeBoundingSphere();
      this.group.add(mesh);
    }

    if (chimneyCount > 0) {
      const mesh = new Mesh(chimneys.build(), this.material);
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      this.group.add(mesh);
    }

    if (foamCount > 0) {
      const mesh = new Mesh(foam.build(), this.material);
      mesh.receiveShadow = true;
      this.group.add(mesh);
    }

    // The slab the world sits on: bare earth visible at the diorama's edges.
    const earth = new Mesh(new BoxGeometry(map.width * ART, 10, map.height * ART), this.material);
    earth.geometry.translate(0, -5, 0);
    const colors = new Float32Array(earth.geometry.getAttribute("position").count * 3);
    for (let i = 0; i < colors.length; i += 3) {
      colors[i] = EARTH.r;
      colors[i + 1] = EARTH.g;
      colors[i + 2] = EARTH.b;
    }
    earth.geometry.setAttribute("color", new BufferAttribute(colors, 3));
    earth.position.set((map.width * ART) / 2, 0, (map.height * ART) / 2);
    this.group.add(earth);
  }

  /** Alternate the sway frames; the renderer skips this under reduce-motion. */
  tick(clock: number): void {
    for (const { a, b, period, phase } of this.animated) {
      const frame = Math.floor(clock / period + phase) % 2;
      a.visible = frame === 0;
      b.visible = frame === 1;
    }
  }

  dispose(): void {
    for (const child of this.group.children) {
      if (child instanceof Mesh || child instanceof InstancedMesh) child.geometry.dispose();
    }
    this.group.clear();
    this.animated = [];
    this.chimneyTops = [];
  }
}
