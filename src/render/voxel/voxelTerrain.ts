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
import { ART, colorGrid, extrudeFlat, extrudeUpright, splitGround, VoxelBuilder, type VoxelSheet } from "./voxelData";

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

/** Walkable tiles that still stand up (you pass through them briefly). */
const UPRIGHT_WALKABLE = new Set<TileId>(["door", "cave"]);

/**
 * Where an upright prop stands on its tile (z, in voxels). Doors, cave mouths
 * and shop signs press against the building or cliff face behind them;
 * free-standing props hold the middle.
 */
const UPRIGHT_Z: Partial<Record<TileId, number>> = {
  door: 3,
  door_shut: 3,
  cave: 3,
  sign_goods: 2,
  sign_smith: 2,
  sign_potion: 2,
  sign_inn: 2,
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

const PLAIN = new Color(1, 1, 1);
/** Wild-region tiles darken a touch: danger reads without the 2D tuft overlay. */
const DANGER = new Color(0.68, 0.68, 0.72);
const EARTH = new Color("#3a2c20");

/**
 * The ground as a diorama: every tile type is extruded once from its grid and
 * instanced across the map - flat ground with colored relief, tall blocks for
 * walls and roofs, props standing upright over their own ground pixels.
 */
export class VoxelTerrain {
  readonly group = new Group();
  private material: MeshLambertMaterial;

  constructor(material: MeshLambertMaterial) {
    this.material = material;
  }

  build(sheet: VoxelSheet, map: WorldMap): void {
    this.dispose();

    const buckets = new Map<string, { tile: TileId; cells: { x: number; y: number; danger: boolean }[] }>();
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
      }
    }

    const matrix = new Matrix4();
    for (const [spriteName, { tile, cells }] of buckets) {
      const sprite = sheet.sprites[spriteName];
      if (!sprite) continue;
      const grid = colorGrid(sprite);
      const builder = new VoxelBuilder();
      const blockHeight = BLOCK_HEIGHTS[tile];
      const upright = blockHeight === undefined && (!TILES[tile].walkable || UPRIGHT_WALKABLE.has(tile));
      if (blockHeight !== undefined) {
        extrudeFlat(builder, grid, blockHeight, 0.9);
      } else if (upright) {
        const { ground, prop } = splitGround(grid);
        extrudeFlat(builder, ground, GROUND_TOP, 0.8);
        extrudeUpright(builder, prop, 2, 0, GROUND_TOP, UPRIGHT_Z[tile] ?? ART / 2);
      } else {
        extrudeFlat(builder, grid, FLAT_TOPS[tile] ?? GROUND_TOP, FLAT_RELIEF[tile] ?? DEFAULT_RELIEF);
      }
      const mesh = new InstancedMesh(builder.build(), this.material, cells.length);
      cells.forEach((cell, i) => {
        matrix.makeTranslation(cell.x * ART, 0, cell.y * ART);
        mesh.setMatrixAt(i, matrix);
        mesh.setColorAt(i, cell.danger ? DANGER : PLAIN);
      });
      mesh.castShadow = blockHeight !== undefined || upright;
      mesh.receiveShadow = true;
      mesh.computeBoundingSphere();
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

  dispose(): void {
    for (const child of this.group.children) {
      if (child instanceof Mesh || child instanceof InstancedMesh) child.geometry.dispose();
    }
    this.group.clear();
  }
}
