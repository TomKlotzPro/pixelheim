import { getMap } from "./maps";
import { isWalkable, portalAt } from "./parseMap";

/**
 * Villagers. Wanderers pace a small loop around their home tile; the loop is
 * derived from the player's step counter, so movement is deterministic and
 * needs no stored NPC state.
 */
export type Npc = {
  id: string;
  mapId: string;
  x: number;
  y: number;
  sprite: string;
  name: string;
  lines: string[];
  wander: boolean;
};

export const NPCS: Npc[] = [
  {
    id: "elder",
    mapId: "town",
    x: 16,
    y: 8,
    sprite: "elder",
    name: "Elder Maren",
    wander: false,
    lines: [
      "The mountain burned before you were born. We rebuilt the village; the monsters rebuilt too.",
      "The gate to the Ashen Mountain is north, past the bridge. Ten floors of teeth and worse manners.",
      "And if you beat the dragon... come see me. There are older things below. I hear them some nights.",
    ],
  },
  {
    id: "villager_ana",
    mapId: "town",
    x: 6,
    y: 6,
    sprite: "villager_woman",
    name: "Ana",
    wander: true,
    lines: [
      "The merchant waters down his elixirs, I swear it. Buy the cheese instead.",
      "Stay on the roads if you value your ankles. The tufty grass BITES.",
    ],
  },
  {
    id: "villager_bram",
    mapId: "town",
    x: 18,
    y: 14,
    sprite: "villager",
    name: "Bram",
    wander: true,
    lines: [
      "I saw a wolf take a whole cheese wheel off a traveler once. Rolled it away and everything.",
      "Me? Climb the mountain? I have a perfectly good fence to lean on right here.",
    ],
  },
  {
    id: "shopkeeper",
    mapId: "town_shop",
    x: 4,
    y: 1,
    sprite: "merchant",
    name: "Merchant Odo",
    wander: false,
    lines: ["Welcome, welcome! Finest goods this side of the mountain. The counter is always open."],
  },
  {
    id: "innkeeper",
    mapId: "town_inn",
    x: 4,
    y: 1,
    sprite: "innkeeper",
    name: "Innkeeper Sela",
    wander: false,
    lines: [
      "Ten gold for a bed and no questions. The bards say my stew brought a man back from the brink.",
      "It was the stew or the poultice. Probably the stew.",
    ],
  },
];

/** The pacing loop, clockwise around home. Filtered per NPC to walkable tiles. */
const LOOP: [number, number][] = [
  [0, 0],
  [1, 0],
  [1, 1],
  [0, 1],
];

const validOffsets = new Map<string, [number, number][]>();
for (const npc of NPCS) {
  const map = getMap(npc.mapId);
  const offsets = LOOP.filter(
    ([dx, dy]) => isWalkable(map, npc.x + dx, npc.y + dy) && !portalAt(map, npc.x + dx, npc.y + dy),
  );
  validOffsets.set(npc.id, offsets.length > 0 ? offsets : [[0, 0]]);
}

function idHash(id: string): number {
  let hash = 0;
  for (const char of id) hash = (hash * 31 + char.charCodeAt(0)) % 997;
  return hash;
}

export function npcsOn(mapId: string): Npc[] {
  return NPCS.filter((npc) => npc.mapId === mapId);
}

/** Where the NPC stands right now, given the player's total step count. */
export function npcPosition(npc: Npc, steps: number): { x: number; y: number } {
  if (!npc.wander) return { x: npc.x, y: npc.y };
  const offsets = validOffsets.get(npc.id)!;
  // one pace every four player steps keeps them ambling, not vibrating
  const index = Math.floor((steps + idHash(npc.id)) / 4) % offsets.length;
  const [dx, dy] = offsets[index];
  return { x: npc.x + dx, y: npc.y + dy };
}

export function npcAt(mapId: string, x: number, y: number, steps: number): Npc | null {
  return (
    npcsOn(mapId).find((npc) => {
      const pos = npcPosition(npc, steps);
      return pos.x === x && pos.y === y;
    }) ?? null
  );
}
