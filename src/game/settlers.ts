import { removeItem } from "./economy/inventory";
import { getItem } from "./economy/items";
import { townTierOf } from "./economy/town";
import type { GameState } from "./types";

/**
 * Settlers (PIX-92): wanderers found out in the world, each with a story, an
 * ask, and a trade. Meet them where they wait, meet their ask, and they move
 * into Pixelheim - a face on the streets and a service for its patron.
 * Recruitment and services ride the dialogue close, like quests do.
 */
export type SettlerAsk = { kind: "gold"; amount: number } | { kind: "deliver"; itemId: string; count: number };

export type Recruit = {
  id: string;
  name: string;
  sprite: string;
  /** Where they wait in the world, until recruited. */
  found: { mapId: string; x: number; y: number; wander: boolean };
  /** Where they live in town, once recruited. */
  home: { x: number; y: number; wander: boolean };
  /** Finer folk want a finer town: the tier they demand before joining. */
  minTownTier?: number;
  ask: SettlerAsk;
  /** Their story, told where you find them. */
  meetLines: string[];
  /** Spoken when the ask is not yet met (the price, named). */
  askLine: string;
  /** Spoken when the town is still too small for them. */
  tierLine?: string;
  joinedLine: string;
  /** Their street talk once settled - the first line doubles as their service. */
  townLines: string[];
};

export const RECRUITS: Recruit[] = [
  {
    id: "settler_iva",
    name: "Iva the Healer",
    sprite: "villager_woman",
    found: { mapId: "mirefen", x: 52, y: 24, wander: false },
    home: { x: 34, y: 16, wander: false },
    ask: { kind: "deliver", itemId: "marsh_reed", count: 3 },
    meetLines: [
      "Careful in the fen. I patch up what it bites, but I am running out of reeds to bind with.",
      "A town with a shrine and no healer... bring me three marsh reeds and I will set up beside it.",
    ],
    askLine: "Three marsh reeds, and my tent moves to Pixelheim.",
    joinedLine: "Reeds enough to start with. Find me by the shrine - and come to me before you climb.",
    townLines: [
      "Sit. Breathe. There - whole again. My door is always open to the town's patron.",
      "The shrine hums some nights. Good company for a healer.",
    ],
  },
  {
    id: "settler_loras",
    name: "Loras the Bard",
    sprite: "merchant",
    found: { mapId: "deepwood", x: 6, y: 24, wander: true },
    home: { x: 26, y: 10, wander: true },
    minTownTier: 2,
    ask: { kind: "gold", amount: 150 },
    meetLines: [
      "A bard in a forest sings to trees. Trees, friend, do not tip.",
      "Get me an audience with lamplight and I will make your battles sound like legends. 150 gold - relocation is art too.",
    ],
    askLine: "150 gold, and my lute follows you home.",
    tierLine: "Sing for a hamlet? Darling, no. Light some lamps first - fund the Village, then we talk.",
    joinedLine: "A patron! Pixelheim gains its first verse tonight.",
    townLines: [
      "A song before you march! There - carry that fire into the fight, it sharpens the blade's edge.",
      "I am composing 'The Ballad of the Ashen Patron'. It needs a triumphant ending. No pressure.",
    ],
  },
  {
    id: "settler_wren",
    name: "Wren the Stablemaster",
    sprite: "smith",
    found: { mapId: "overworld", x: 54, y: 40, wander: true },
    home: { x: 31, y: 3, wander: true },
    ask: { kind: "deliver", itemId: "wolf_pelt", count: 2 },
    meetLines: [
      "Lost my stable to the ash years back. Been walking travelers' horses by the gate ever since.",
      "Two wolf pelts for saddle leather and I will run a proper post in town - straight to the square, no gate queue.",
    ],
    askLine: "Two wolf pelts for the saddles, and the stable is Pixelheim's.",
    joinedLine: "Leather enough! The post stands by the north road - the square is a whistle away now.",
    townLines: [
      "The post runs like a dream. Fast travel drops you right at the square now - no gate queue.",
      "Horses hate the ash fields. Smart animals.",
    ],
  },
  {
    id: "settler_mirelle",
    name: "Mirelle the Banker",
    sprite: "alchemist",
    found: { mapId: "overworld", x: 52, y: 36, wander: false },
    home: { x: 46, y: 20, wander: false },
    minTownTier: 3,
    ask: { kind: "gold", amount: 500 },
    meetLines: [
      "I count coins for caravans that never stop anywhere worth banking in.",
      "Give me a town with a fountain and 500 gold of founding capital, and I will make Pixelheim's money WORK.",
    ],
    askLine: "500 gold of founding capital, and the bank follows you home.",
    tierLine: "A bank needs a TOWN, not a village fair. Fund the third charter and we will talk.",
    joinedLine: "Capital received. Find my ledger by the city hall - bring your idle gold.",
    townLines: [
      "Idle gold is lazy gold. Savings, a caravan, an expansion - put it to work.",
      "The mayor builds with your gold. I make it come BACK. We are not the same.",
    ],
  },
];

export function getRecruit(id: string): Recruit | null {
  return RECRUITS.find((recruit) => recruit.id === id) ?? null;
}

export function isSettled(state: GameState, id: string): boolean {
  return (state.settlers ?? []).includes(id);
}

/** What still blocks this recruit from joining, or null when they would. */
export function recruitBlocker(state: GameState, recruit: Recruit): "tier" | "ask" | null {
  if ((recruit.minTownTier ?? 1) > townTierOf(state)) return "tier";
  if (recruit.ask.kind === "gold" && state.gold < recruit.ask.amount) return "ask";
  if (recruit.ask.kind === "deliver" && (state.inventory[recruit.ask.itemId] ?? 0) < recruit.ask.count) return "ask";
  return null;
}

/**
 * Rides the dialogue close (like resolveQuests): recruiting where they wait,
 * services once they live in town. Returns false when the npc is no settler,
 * so the caller can fall through to quests.
 */
export function resolveSettler(draft: GameState, npcId: string): boolean {
  const recruit = getRecruit(npcId);
  if (!recruit) return false;

  if (!isSettled(draft, npcId)) {
    const blocker = recruitBlocker(draft, recruit);
    if (blocker === "tier") {
      draft.worldMessage = `${recruit.name}: ${recruit.tierLine ?? "The town is not ready for me yet."}`;
      return true;
    }
    if (blocker === "ask") {
      const price =
        recruit.ask.kind === "gold"
          ? `${recruit.ask.amount}g`
          : `${recruit.ask.count}x ${getItem(recruit.ask.itemId).name}`;
      draft.worldMessage = `${recruit.name} asks: ${price}. (${recruit.askLine})`;
      return true;
    }
    if (recruit.ask.kind === "gold") draft.gold -= recruit.ask.amount;
    else draft.inventory = removeItem(draft.inventory, recruit.ask.itemId, recruit.ask.count);
    draft.settlers = [...(draft.settlers ?? []), recruit.id];
    draft.worldMessage = `${recruit.name} joins Pixelheim! ${recruit.joinedLine}`;
    return true;
  }

  // Settled services, rendered where they live.
  if (draft.world?.position.mapId === "town") {
    if (recruit.id === "settler_iva" && draft.hero) {
      draft.hero.hp = draft.hero.stats.maxHp;
      draft.hero.mp = draft.hero.stats.maxMp;
      draft.worldMessage = "Iva's hands glow warm. Fully healed, free of charge.";
      return true;
    }
    if (recruit.id === "settler_loras") {
      draft.bardSong = true;
      draft.worldMessage = "Loras plays you a marching song. Your next hunt strikes truer. (+12% crit)";
      return true;
    }
  }
  return true;
}
