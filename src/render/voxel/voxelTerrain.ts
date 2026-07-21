import {
  BoxGeometry,
  BufferAttribute,
  Color,
  Group,
  InstancedMesh,
  Matrix4,
  Mesh,
  MeshBasicMaterial,
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
  darken,
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
};

/** Ground that is not at the standard height; everything else lies at 1. */
const FLAT_TOPS: Partial<Record<TileId, number>> = { water: 0.45, marsh: 0.8, bridge: 1.6 };
/** How far a pixel's brightness pushes its column out of the ground. */
const FLAT_RELIEF: Partial<Record<TileId, number>> = { water: 0, bridge: 0.3, path: 0.5, floor: 0.3, sand: 0.5 };
const DEFAULT_RELIEF = 1.1;
export const GROUND_TOP = 1;

/** Cliff faces: the cave mouth renders on the mountain face, facade-style. */
const FACADE_TILES: Partial<Record<TileId, number>> = { cave: 14 };

/** The tiles that belong to a building footprint (PIX-113). */
const BUILDING_TILES = new Set<TileId>([
  "roof",
  "roof_slate",
  "roof_violet",
  "roof_awning",
  "roof_moss",
  "door",
  "door_shut",
  "sign_goods",
  "sign_smith",
  "sign_potion",
  "sign_inn",
]);

// ---------------- the medieval palette (PIX-113) ----------------
const PLASTER = "#e7dcc3";
const BEAM = "#5a4228";
const BEAM_DARK = "#47341f";
const STONE = "#8b8578";
const GLASS = "#f2c14e";
const DOOR_WOOD = "#7a5230";
const DOOR_PLANK = "#5c3d20";
const KNOB = "#e0b84a";
const WALL_H = 10;
const ROOF_STEP = 2;
const ROOF_MAX_LEVELS = 6;
const OVERHANG = 2;

/**
 * Terrain that breathes, matching the Pixi sway sheets: frame B is the same
 * grid wrap-shifted, and the pair alternates on a slow beat.
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

function decorHash(x: number, y: number): number {
  return Math.abs((x * 83492791) ^ (y * 19349663));
}

type DecorKind = "flowers" | "stone" | "tuft" | "bush" | "tree";

function decorFor(tile: TileId, h: number, wild: boolean): DecorKind | null {
  if (tile === "grass" && !wild) {
    if (h % 17 === 0) return "flowers";
    if (h % 23 === 3) return "stone";
    if (h % 7 === 1) return "tuft";
    return null;
  }
  // The wilds stay stern - no flower patches - but stones and greenery belong.
  if (tile === "grass" && h % 23 === 3) return "stone";
  if (tile === "forest") {
    if (h % 7 === 0) return "tree";
    if (h % 5 < 2) return "bush";
  }
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
  } else if (kind === "tree") {
    // a real tree: trunk and three tiers of canopy, berries for luck
    b.box(-1.5, 0, -1.5, 3, 6, 3, "#5c4530");
    b.box(-6, 5, -6, 12, 3.5, 12, "#2d6b44");
    b.box(-4.5, 8.5, -4.5, 9, 3, 9, "#3e8f5c");
    b.box(-2.5, 11.5, -2.5, 5, 2, 5, "#4a9f5c");
    b.box(2, 7, 3, 1, 1, 1, "#e64a5f");
    b.box(-3, 9.5, -2, 1, 1, 1, "#e64a5f");
  } else {
    b.box(-4, 0, -3, 8, 2, 7, "#2d6b44");
    b.box(-3, 2, -2, 6, 2, 5, "#3e8f5c");
    b.box(-1, 4, -1, 3, 1, 3, "#4a9f5c");
    b.box(2, 3, 0, 1, 1, 1, "#e64a5f");
    b.box(-2, 2, -2, 1, 1, 1, "#e64a5f");
  }
  return b;
}

// ---------------- crafted props: tiles that deserve real carpentry (PIX-113) ----------------

/** Props built in tile-local coordinates (0..16), feet at y=1 (the ground top). */
const CRAFTED_PROPS: Partial<Record<TileId, (b: VoxelBuilder) => void>> = {
  lamp: (b) => {
    b.box(6, 1, 6, 4, 1.2, 4, STONE);
    b.box(7.3, 2, 7.3, 1.4, 7.5, 1.4, "#3a3f45");
    b.box(6.4, 9.5, 6.4, 3.2, 3, 3.2, "#ffd469");
    b.box(6, 12.5, 6, 4, 0.8, 4, "#2a2d35");
    b.box(7.5, 13.3, 7.5, 1, 0.8, 1, "#2a2d35");
  },
  well: (b) => {
    b.box(4, 1, 4, 8, 1, 8, "#6f6a5e");
    b.box(4, 2, 4, 8, 1.8, 2, "#7a7468");
    b.box(4, 2, 10, 8, 1.8, 2, "#7a7468");
    b.box(4, 2, 6, 2, 1.8, 4, "#7a7468");
    b.box(10, 2, 6, 2, 1.8, 4, "#7a7468");
    b.box(4.6, 3.8, 7.3, 1.2, 4.5, 1.2, BEAM);
    b.box(10.2, 3.8, 7.3, 1.2, 4.5, 1.2, BEAM);
    b.box(4.6, 7.2, 7.5, 6.8, 0.8, 0.8, DOOR_PLANK);
    b.box(7.2, 4.4, 7.2, 1.6, 1.4, 1.6, "#6b4a2b");
    b.box(3, 8.3, 5.5, 10, 1, 5, "#8a5a30");
    b.box(4.5, 9.3, 6.5, 7, 1, 3, "#6e4423");
  },
  barrel: (b) => {
    b.box(5, 1, 5, 6, 1, 6, "#8a6238");
    b.box(4.2, 2, 4.2, 7.6, 3, 7.6, "#96703f");
    b.box(4, 2.4, 4, 8, 0.7, 8, "#3f3f46");
    b.box(4, 4.2, 4, 8, 0.7, 8, "#3f3f46");
    b.box(5, 5, 5, 6, 0.8, 6, "#a87a4a");
  },
  crate: (b) => {
    b.box(4, 1, 4, 8, 7, 8, "#9a7444");
    for (const [cx, cz] of [
      [3.7, 3.7],
      [3.7, 11.1],
      [11.1, 3.7],
      [11.1, 11.1],
    ]) {
      b.box(cx, 1, cz, 1.2, 7.4, 1.2, "#6b4a28");
    }
    b.box(3.7, 7.6, 3.7, 8.6, 0.8, 8.6, "#6b4a28");
  },
  counter: (b) => {
    // a market stall: plank counter under a striped awning
    b.box(2, 1, 6, 12, 3.2, 4, "#8a6238");
    b.box(1.4, 4.2, 5.4, 13.2, 0.8, 5.2, "#a87a4a");
    for (const [px, pz] of [
      [1.6, 1.6],
      [13.2, 1.6],
      [1.6, 13.2],
      [13.2, 13.2],
    ]) {
      b.box(px, 1, pz, 1.2, 9, 1.2, BEAM);
    }
    for (let i = 0; i < 7; i++) {
      b.box(1 + i * 2, 10, 1, 2, 0.8, 14, i % 2 ? "#dde3ea" : "#c0392b");
    }
  },
};

/** Fence rails run toward fence neighbors; the mask names the connections. */
function fenceGeometry(mask: number): VoxelBuilder {
  const b = new VoxelBuilder();
  b.box(7, 1, 7, 2, 4.6, 2, "#7a5230");
  b.box(6.6, 5.6, 6.6, 2.8, 0.8, 2.8, "#5c3d20");
  const rails: [number, [number, number, number, number, number, number][]][] = [
    [
      1,
      [
        [7.4, 2.2, 0, 1.2, 0.8, 7],
        [7.4, 3.8, 0, 1.2, 0.8, 7],
      ],
    ],
    [
      2,
      [
        [9, 2.2, 7.4, 7, 0.8, 1.2],
        [9, 3.8, 7.4, 7, 0.8, 1.2],
      ],
    ],
    [
      4,
      [
        [7.4, 2.2, 9, 1.2, 0.8, 7],
        [7.4, 3.8, 9, 1.2, 0.8, 7],
      ],
    ],
    [
      8,
      [
        [0, 2.2, 7.4, 7, 0.8, 1.2],
        [0, 3.8, 7.4, 7, 0.8, 1.2],
      ],
    ],
  ];
  for (const [bit, boxes] of rails) {
    if (!(mask & bit)) continue;
    for (const [x, y, z, w, h, d] of boxes) b.box(x, y, z, w, h, d, "#9a7444");
  }
  return b;
}

const PLAIN = new Color(1, 1, 1);
/** Wild-region tiles darken a touch: danger reads without the 2D tuft overlay. */
const DANGER = new Color(0.68, 0.68, 0.72);
const EARTH = new Color("#3a2c20");

type Cell = { x: number; y: number; danger: boolean };
type SwayPair = { a: InstancedMesh; b: InstancedMesh; period: number; phase: number };
type Building = { cells: { x: number; y: number }[]; roofTile: TileId; doors: { x: number; y: number }[] };

/**
 * The ground as a diorama (PIX-113, the medieval pass): open land is extruded
 * and instanced from the sprite grids; buildings rise as real timber houses -
 * plaster and beams, amber windows, framed plank doors under little awnings,
 * stepped pitched roofs in each building's own hue, a chimney on the ridge.
 * Props are carpentered in 3D; a two-frame breeze sways the green.
 */
export class VoxelTerrain {
  readonly group = new Group();
  /** Chimney mouths, for the atmosphere's smoke. */
  chimneyTops: { x: number; y: number; z: number }[] = [];
  private material: MeshLambertMaterial;
  /** Water alone is translucent: the earth ghosts through the shallows. */
  private waterMaterial: MeshLambertMaterial;
  /** Window panes collect here and render UNLIT: honey by day, aglow by night. */
  private glass = new VoxelBuilder();
  private glassMaterial = new MeshBasicMaterial({ vertexColors: true });
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

  /** Flood-fill the building footprints: roofs plus their embedded doors and signs. */
  private findBuildings(map: WorldMap): { buildings: Building[]; consumed: Set<string> } {
    const inSet = (x: number, y: number) =>
      y >= 0 && y < map.height && x >= 0 && x < map.width && BUILDING_TILES.has(map.tiles[y][x]);
    const seen = new Set<string>();
    const buildings: Building[] = [];
    const consumed = new Set<string>();
    for (let y = 0; y < map.height; y++) {
      for (let x = 0; x < map.width; x++) {
        if (!inSet(x, y) || seen.has(`${x},${y}`)) continue;
        const cells: { x: number; y: number }[] = [];
        const queue = [{ x, y }];
        seen.add(`${x},${y}`);
        while (queue.length > 0) {
          const c = queue.pop()!;
          cells.push(c);
          for (const [dx, dy] of [
            [1, 0],
            [-1, 0],
            [0, 1],
            [0, -1],
          ]) {
            const nx = c.x + dx;
            const ny = c.y + dy;
            if (inSet(nx, ny) && !seen.has(`${nx},${ny}`)) {
              seen.add(`${nx},${ny}`);
              queue.push({ x: nx, y: ny });
            }
          }
        }
        const roofCounts = new Map<TileId, number>();
        const doors: { x: number; y: number }[] = [];
        for (const c of cells) {
          const tile = map.tiles[c.y][c.x];
          if (tile.startsWith("roof")) roofCounts.set(tile, (roofCounts.get(tile) ?? 0) + 1);
          if (tile === "door" || tile === "door_shut") doors.push(c);
          consumed.add(`${c.x},${c.y}`);
        }
        const roofTile = [...roofCounts.entries()].toSorted((a, b) => b[1] - a[1])[0]?.[0] ?? "roof";
        buildings.push({ cells, roofTile, doors });
      }
    }
    return { buildings, consumed };
  }

  /**
   * One medieval timber house over ANY footprint: per-cell plaster walls with
   * beams on every street face, amber windows, crafted doorways, and a hipped
   * roof whose height follows each cell's distance to the footprint edge.
   */
  private buildHouse(sheet: VoxelSheet, building: Building): void {
    const b = new VoxelBuilder();
    const inside = new Set(building.cells.map((c) => `${c.x},${c.y}`));
    const doorSet = new Set(building.doors.map((c) => `${c.x},${c.y}`));
    const roofSprite = sheet.sprites[TILES[building.roofTile].sprite];
    const roofHue = roofSprite ? averageColor(colorGrid(roofSprite)) : "#8a4a3a";

    // roof levels: BFS distance to the outside, capped - a stepped hip roof
    const level = new Map<string, number>();
    let frontier = building.cells.filter((c) =>
      [
        [1, 0],
        [-1, 0],
        [0, 1],
        [0, -1],
      ].some(([dx, dy]) => !inside.has(`${c.x + dx},${c.y + dy}`)),
    );
    for (const c of frontier) level.set(`${c.x},${c.y}`, 0);
    let depth = 0;
    while (frontier.length > 0) {
      depth += 1;
      const next: { x: number; y: number }[] = [];
      for (const c of frontier) {
        for (const [dx, dy] of [
          [1, 0],
          [-1, 0],
          [0, 1],
          [0, -1],
        ]) {
          const k = `${c.x + dx},${c.y + dy}`;
          if (inside.has(k) && !level.has(k)) {
            level.set(k, depth);
            next.push({ x: c.x + dx, y: c.y + dy });
          }
        }
      }
      frontier = next;
    }

    let chimneyAt = building.cells[0];
    let chimneyLevel = -1;
    for (const cell of building.cells) {
      const key = `${cell.x},${cell.y}`;
      const wx = cell.x * ART;
      const wz = cell.y * ART;
      const d = Math.min(level.get(key) ?? 0, ROOF_MAX_LEVELS - 1);
      if ((level.get(key) ?? 0) > chimneyLevel) {
        chimneyLevel = level.get(key) ?? 0;
        chimneyAt = cell;
      }

      // the plaster body of this cell
      b.box(wx, 0, wz, ART, WALL_H, ART, PLASTER, { north: true, south: true, west: true, east: true });

      // the roof column: banded shingle courses climbing toward the middle
      const roofH = (d + 1) * ROOF_STEP;
      const color = d === ROOF_MAX_LEVELS - 1 ? darken(roofHue, 0.7) : d % 2 ? darken(roofHue, 0.74) : roofHue;
      b.box(wx, WALL_H, wz, ART, roofH, ART, color);

      // dress every exterior face
      const faces: { dx: number; dy: number; south?: boolean }[] = [
        { dx: 0, dy: 1, south: true },
        { dx: 0, dy: -1 },
        { dx: 1, dy: 0 },
        { dx: -1, dy: 0 },
      ];
      for (const face of faces) {
        if (inside.has(`${cell.x + face.dx},${cell.y + face.dy}`)) continue;
        const alongX = face.dy !== 0;
        const fo = face.dx > 0 || face.dy > 0 ? ART : 0;
        // eave lip over this face
        if (alongX) {
          b.box(wx - 1, WALL_H, wz + fo - (face.dy > 0 ? 0 : OVERHANG), ART + 2, 1.2, OVERHANG, darken(roofHue, 0.62));
        } else {
          b.box(wx + fo - (face.dx > 0 ? 0 : OVERHANG), WALL_H, wz - 1, OVERHANG, 1.2, ART + 2, darken(roofHue, 0.62));
        }
        // stone footing and timber: plate, corner studs, twin rails
        const t = 0.6;
        const put = (u0: number, y0: number, len: number, h: number, color2: string, extrude = t) => {
          if (alongX) {
            b.box(wx + u0, y0, face.dy > 0 ? wz + ART - 0.2 : wz - extrude + 0.2, len, h, extrude, color2);
          } else {
            b.box(face.dx > 0 ? wx + ART - 0.2 : wx - extrude + 0.2, y0, wz + u0, extrude, h, len, color2);
          }
        };
        put(0, 0, ART, 1.4, STONE, 1);
        put(0, WALL_H - 1, ART, 1, BEAM, 0.9);
        put(0, 0, 1.2, WALL_H, BEAM, 0.9);
        put(ART - 1.2, 0, 1.2, WALL_H, BEAM, 0.9);
        put(0, 3.4, ART, 0.7, BEAM_DARK);
        put(0, 6.6, ART, 0.7, BEAM_DARK);

        const isDoorFace = doorSet.has(key) && face.south;
        if (isDoorFace) {
          // the crafted doorway: posts, lintel, plank door, knob, awning, step
          const px = wx;
          const facez = wz + ART;
          b.box(px + 2.8, 0, facez - 0.7, 1.5, 6.6, 1.5, BEAM);
          b.box(px + 11.7, 0, facez - 0.7, 1.5, 6.6, 1.5, BEAM);
          b.box(px + 2.8, 6.4, facez - 0.8, 10.4, 1.2, 1.7, BEAM);
          b.box(px + 4.3, 0, facez - 0.5, 7.4, 6.4, 1, DOOR_WOOD);
          b.box(px + 6.6, 0.3, facez + 0.5, 0.6, 5.8, 0.15, DOOR_PLANK);
          b.box(px + 9, 0.3, facez + 0.5, 0.6, 5.8, 0.15, DOOR_PLANK);
          b.box(px + 10.4, 3, facez + 0.5, 0.9, 0.9, 0.5, KNOB);
          b.box(px + 1.5, 7.4, facez - 1.2, 13, 0.9, 3.4, darken(roofHue, 0.8));
          b.box(px + 2.5, 8.3, facez - 3, 11, 0.9, 3, roofHue);
          b.box(px + 4, 0, facez, 8, 0.7, 1.8, STONE);
        } else if (decorHash(cell.x + face.dx * 3, cell.y + face.dy * 3) % 3 !== 0) {
          // an amber window: beam frame, stone sill, glowing pane
          if (alongX) {
            const facez = face.dy > 0 ? wz + ART - 0.3 : wz - 0.5;
            b.box(wx + 4.5, 3, facez, 7, 5.4, 0.8, BEAM);
            b.box(wx + 4.2, 2.4, facez, 7.6, 0.7, 0.9, STONE);
            this.glass.box(wx + 5.5, 3.8, face.dy > 0 ? facez + 0.2 : facez - 0.2, 5, 3.8, 0.8, GLASS);
            b.box(wx + 7.7, 3.8, face.dy > 0 ? facez + 0.4 : facez - 0.4, 0.6, 3.8, 0.6, BEAM);
          } else {
            const facex = face.dx > 0 ? wx + ART - 0.3 : wx - 0.5;
            b.box(facex, 3, wz + 4.5, 0.8, 5.4, 7, BEAM);
            this.glass.box(face.dx > 0 ? facex + 0.2 : facex - 0.2, 3.8, wz + 5.5, 0.8, 3.8, 5, GLASS);
          }
        }
      }
    }

    // one chimney on the highest ridge cell; the atmosphere smokes it
    const chx = chimneyAt.x * ART + 6;
    const chz = chimneyAt.y * ART + 6;
    const chTop = WALL_H + (Math.min(chimneyLevel, ROOF_MAX_LEVELS - 1) + 1) * ROOF_STEP;
    b.box(chx, chTop, chz, 4, 5, 4, "#6b4034");
    b.box(chx - 1, chTop + 5, chz - 1, 6, 1, 6, "#3a2a26");
    this.chimneyTops.push({ x: chx + 2, y: chTop + 6, z: chz + 2 });

    const mesh = new Mesh(b.build(), this.material);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    this.group.add(mesh);
  }

  build(sheet: VoxelSheet, map: WorldMap): void {
    this.dispose();

    const { buildings, consumed } = this.findBuildings(map);
    for (const building of buildings) this.buildHouse(sheet, building);

    const buckets = new Map<string, { tile: TileId; cells: Cell[] }>();
    const decorCells = new Map<DecorKind, { x: number; y: number; ox: number; oz: number }[]>();
    const foam = new VoxelBuilder();
    let foamCount = 0;
    const fenceMask = (x: number, y: number) =>
      (map.tiles[y - 1]?.[x] === "fence" ? 1 : 0) |
      (map.tiles[y]?.[x + 1] === "fence" ? 2 : 0) |
      (map.tiles[y + 1]?.[x] === "fence" ? 4 : 0) |
      (map.tiles[y]?.[x - 1] === "fence" ? 8 : 0);

    for (let y = 0; y < map.height; y++) {
      for (let x = 0; x < map.width; x++) {
        if (consumed.has(`${x},${y}`)) continue;
        const tile = map.tiles[y][x];
        const spriteName =
          tile === "grass"
            ? grassVariant(x, y)
            : tile === "fence"
              ? `tile_fence:${fenceMask(x, y)}`
              : TILES[tile].sprite;
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

        // Water meets land with a line of foam, like the 2D shore overlay.
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
      }
    }

    for (const [spriteKey, { tile, cells }] of buckets) {
      const isFence = spriteKey.startsWith("tile_fence:");
      const sprite = sheet.sprites[isFence ? "tile_fence" : spriteKey];
      if (!sprite) continue;
      const grid = colorGrid(sprite);
      const builder = new VoxelBuilder();
      const blockHeight = BLOCK_HEIGHTS[tile];
      const facadeHeight = FACADE_TILES[tile];
      const crafted = CRAFTED_PROPS[tile];
      const upright =
        !crafted &&
        !isFence &&
        facadeHeight === undefined &&
        blockHeight === undefined &&
        tile !== "water" &&
        !TILES[tile].walkable;
      if (tile === "water") {
        // Calm waters: one still, glassy pane per tile - the mean of the
        // sprite's blues, no speckle, no motion. Foam marks the banks.
        builder.box(0, 0, 0, ART, FLAT_TOPS.water ?? GROUND_TOP, ART, averageColor(grid), { top: true });
      } else if (isFence || crafted) {
        // Carpentered props stand on their own ground (PIX-113).
        const { ground } = splitGround(grid);
        extrudeFlat(builder, ground, GROUND_TOP, 0.8);
        const propBuilder = isFence ? fenceGeometry(Number(spriteKey.split(":")[1])) : new VoxelBuilder();
        if (crafted) crafted(propBuilder);
        builder.merge(propBuilder, 0, 0, 0);
      } else if (facadeHeight !== undefined) {
        const { ground, prop } = splitGround(grid);
        builder.box(0, 0, 0, ART, facadeHeight, ART, averageColor(ground), {
          top: true,
          north: true,
          south: true,
          west: true,
          east: true,
        });
        extrudeUpright(builder, prop, 2, 0, 1, ART - 1);
      } else if (blockHeight !== undefined) {
        extrudeFlat(builder, grid, blockHeight, 0.45);
      } else if (upright) {
        const { ground, prop } = splitGround(grid);
        extrudeFlat(builder, ground, GROUND_TOP, 0.8);
        extrudeUpright(builder, prop, 2, 0, GROUND_TOP, ART / 2);
      } else {
        extrudeFlat(builder, grid, FLAT_TOPS[tile] ?? GROUND_TOP, FLAT_RELIEF[tile] ?? DEFAULT_RELIEF);
      }
      const material = tile === "water" ? this.waterMaterial : this.material;
      const mesh = this.instanced(
        builder,
        cells,
        blockHeight !== undefined || upright || facadeHeight !== undefined || isFence || crafted !== undefined,
        material,
      );

      // The breeze: flat animated tiles get a second, wrap-shifted frame.
      const anim =
        facadeHeight === undefined && blockHeight === undefined && !upright && !crafted && !isFence
          ? ANIMATED[tile]
          : undefined;
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
        for (const c of spriteKey) phase = (phase * 31 + c.charCodeAt(0)) % 977;
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

    if (foamCount > 0) {
      const mesh = new Mesh(foam.build(), this.material);
      mesh.receiveShadow = true;
      this.group.add(mesh);
    }

    const glassMesh = new Mesh(this.glass.build(), this.glassMaterial);
    this.group.add(glassMesh);

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
    this.glass = new VoxelBuilder();
  }
}
