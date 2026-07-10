import type { Monster } from "./types";

const list: Monster[] = [
  { id: "slime", name: "Slime", sprite: "slime", maxHp: 14, attack: 5, defense: 0, xp: 8, gold: 4 },
  { id: "goblin", name: "Goblin", sprite: "goblin", maxHp: 20, attack: 7, defense: 1, xp: 12, gold: 8 },
  { id: "skeleton", name: "Skeleton", sprite: "skeleton", maxHp: 26, attack: 9, defense: 2, xp: 17, gold: 12 },
  { id: "wolf", name: "Dire Wolf", sprite: "wolf", maxHp: 32, attack: 12, defense: 2, xp: 23, gold: 14 },
  { id: "orc", name: "Orc Raider", sprite: "orc", maxHp: 42, attack: 14, defense: 4, xp: 30, gold: 22 },
  { id: "ghost", name: "Ghost", sprite: "ghost", maxHp: 38, attack: 17, defense: 3, xp: 38, gold: 26 },
  { id: "golem", name: "Stone Golem", sprite: "golem", maxHp: 60, attack: 16, defense: 8, xp: 48, gold: 34 },
  { id: "troll", name: "Cave Troll", sprite: "troll", maxHp: 74, attack: 21, defense: 6, xp: 60, gold: 45 },
  { id: "wyvern", name: "Wyvern", sprite: "wyvern", maxHp: 88, attack: 25, defense: 7, xp: 75, gold: 60 },
  { id: "dragon", name: "Fafnyr the Ashen", sprite: "dragon", maxHp: 130, attack: 29, defense: 9, xp: 150, gold: 250 },
];

export const MONSTERS: Record<string, Monster> = Object.fromEntries(list.map((m) => [m.id, m]));

export function getMonster(id: string): Monster {
  const monster = MONSTERS[id];
  if (!monster) throw new Error(`Unknown monster: ${id}`);
  return monster;
}
