import type { GameState } from "./types";

/**
 * Quests: reasons to walk somewhere. Talking to a giver ACCEPTS their quest;
 * talking again with the objective met COMPLETES it. Kill quests count via
 * the battle-victory hook, deliveries consume from the pack on turn-in.
 */
export type QuestObjective =
  | { kind: "kill"; monsterId: string; count: number; label: string }
  | { kind: "deliver"; itemId: string; count: number; label: string };

export type Quest = {
  id: string;
  giver: string;
  name: string;
  brief: string;
  objective: QuestObjective;
  reward: { gold: number; xp: number; itemId?: string };
  accepted: string;
  completed: string;
};

export const QUESTS: Quest[] = [
  {
    id: "slime_trouble",
    giver: "innkeeper",
    name: "Slime Trouble",
    brief: "Sela's cellar smells of slime. Thin the forest's supply of them.",
    objective: { kind: "kill", monsterId: "slime", count: 3, label: "Slimes flattened" },
    reward: { gold: 60, xp: 30 },
    accepted: "Three fewer slimes in the world and there's coin in it for you.",
    completed: "The cellar thanks you. So does my nose. Here - you've earned it.",
  },
  {
    id: "cheese_run",
    giver: "villager_bram",
    name: "The Cheese Run",
    brief: "Bram wants a cheese wheel. Of course he does.",
    objective: { kind: "deliver", itemId: "cheese_wheel", count: 1, label: "Cheese wheels delivered" },
    reward: { gold: 25, xp: 15 },
    accepted: "One wheel. Uncut. I'll know if you nibbled.",
    completed: "Magnificent. Roll on, friend. Roll on.",
  },
  {
    id: "wolf_watch",
    giver: "villager_ana",
    name: "Wolf Watch",
    brief: "Ana's ankles have opinions about the road wolves.",
    objective: { kind: "kill", monsterId: "wolf", count: 2, label: "Dire wolves driven off" },
    reward: { gold: 90, xp: 45 },
    accepted: "Two of the big ones, gone. Then I'll walk where I please.",
    completed: "I walked the whole road today and nothing bit me. Take this.",
  },
  {
    id: "troll_toll",
    giver: "elder",
    name: "The Troll Toll",
    brief: "Something under the Deepwood charges travelers in teeth.",
    objective: { kind: "kill", monsterId: "troll", count: 1, label: "Trolls tolled" },
    reward: { gold: 200, xp: 90 },
    accepted: "It squats where the old road bends. Mind your kneecaps.",
    completed: "The road east breathes easier. The village remembers this.",
  },
  {
    id: "herbs_for_vex",
    giver: "alchemist_vex",
    name: "Greens for the Cauldron",
    brief: "Vex is out of forest herbs and out of patience.",
    objective: { kind: "deliver", itemId: "forest_herb", count: 3, label: "Forest herbs delivered" },
    reward: { gold: 70, xp: 35, itemId: "greater_potion" },
    accepted: "Three sprigs, forest-fresh. The cauldron waits for no one.",
    completed: "Green as they should be. Here - the good stuff, brewed proper.",
  },
];

export function questsFor(giver: string): Quest[] {
  return QUESTS.filter((q) => q.giver === giver);
}

export function getQuest(id: string): Quest | null {
  return QUESTS.find((q) => q.id === id) ?? null;
}

export function questProgress(state: GameState, quest: Quest): number {
  const entry = state.quests[quest.id];
  if (!entry) return 0;
  if (quest.objective.kind === "deliver") {
    return Math.min(quest.objective.count, state.inventory[quest.objective.itemId] ?? 0);
  }
  return Math.min(quest.objective.count, entry.progress);
}

export function questReady(state: GameState, quest: Quest): boolean {
  const entry = state.quests[quest.id];
  return !!entry && !entry.done && questProgress(state, quest) >= quest.objective.count;
}
