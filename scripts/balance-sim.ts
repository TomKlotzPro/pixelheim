/**
 * Headless balance simulator: drives the REAL game reducer with a simple bot
 * for every role, floor by floor, and reports deaths, levels and gold.
 *
 *   pnpm sim            full report (30 runs per role)
 *   pnpm sim --check    regression mode: fewer runs, exits 1 on loose bounds
 *
 * The bot mirrors a sensible player: quaff below 35% HP, heal below 40%,
 * use the strongest affordable skill, buy potions in town, equip the best
 * drops, dump stat points into the role's primary stat (1 in 5 into DEF),
 * and learn skill-tree nodes in a per-role priority order.
 */
import { gearArmor, gearDamage, gearItem } from "../src/game/rarity";
import { getHeroSkills, SKILL_TREES } from "../src/game/skillTree";
import { LEVELS } from "../src/game/levels";
import type { GameState, GearInstance, RoleId } from "../src/game/types";
import { gameReducer, initialState, REST_COST, type Action } from "../src/state/gameReducer";

const CHECK_MODE = process.argv.includes("--check");
const RUNS_PER_ROLE = CHECK_MODE ? 10 : 30;
const MAX_ATTEMPTS_PER_FLOOR = 12;
const ROLES: RoleId[] = ["warrior", "mage", "rogue", "cleric"];

const PRIMARY: Record<RoleId, "strength" | "intelligence" | "dexterity"> = {
  warrior: "strength",
  mage: "intelligence",
  rogue: "dexterity",
  cleric: "intelligence",
};

type FloorStat = { attempts: number; deaths: number; clearLevel: number; clearGold: number };

function dispatch(state: GameState, action: Action): GameState {
  return gameReducer(state, action);
}

/** Town chores between attempts: heal (inn price), shop, gear, points. */
function townTurn(state: GameState): GameState {
  let s = state;
  const hero = s.hero!;
  // rest at the inn
  if (s.gold >= REST_COST && (hero.hp < hero.stats.maxHp || hero.mp < hero.stats.maxMp)) {
    s = { ...s, gold: s.gold - REST_COST, hero: { ...hero, hp: hero.stats.maxHp, mp: hero.stats.maxMp } };
  }
  // spend stat points: 4 into the primary stat, every 5th into DEF
  while (s.hero!.statPoints > 0) {
    const stat = s.hero!.statPoints % 5 === 0 ? "defense" : PRIMARY[s.hero!.roleId];
    s = dispatch(s, { type: "SPEND_STAT_POINT", stat });
  }
  // learn skill nodes in tree order (roots then depth)
  for (const node of SKILL_TREES[s.hero!.roleId]) {
    if (s.hero!.skillPoints <= 0) break;
    s = dispatch(s, { type: "BUY_SKILL_NODE", nodeId: node.id });
  }
  // equip best gear per slot
  const best: Record<string, GearInstance | undefined> = {};
  for (const g of s.gear) {
    const slot = gearItem(g).slot;
    if (!slot) continue;
    const score = slot === "weapon" ? gearDamage(g) + s.hero!.stats[gearItem(g).scaling ?? "strength"] : gearArmor(g);
    const current = best[slot];
    const currentScore = current
      ? slot === "weapon"
        ? gearDamage(current) + s.hero!.stats[gearItem(current).scaling ?? "strength"]
        : gearArmor(current)
      : -1;
    if (score > currentScore) best[slot] = g;
  }
  for (const g of Object.values(best)) {
    if (g && !Object.values(s.equipped).includes(g.uid)) s = dispatch(s, { type: "EQUIP", uid: g.uid });
  }
  // sell spare gear, keep the satchel light
  for (const g of s.gear) {
    if (!Object.values(s.equipped).includes(g.uid) && !Object.values(best).some((b) => b?.uid === g.uid)) {
      s = { ...s, shopOpen: true };
      s = dispatch(s, { type: "SELL_GEAR", uid: g.uid });
      s = { ...s, shopOpen: false };
    }
  }
  // stock up on the best affordable healing potion
  const potion = (s.unlockedLevel >= 11 ? "greater_potion" : "potion_hp") as string;
  const price = potion === "greater_potion" ? 70 : 25;
  while ((s.inventory[potion] ?? 0) < 5 && s.gold >= price + REST_COST) {
    s = { ...s, shopOpen: true };
    s = dispatch(s, { type: "BUY_ITEM", itemId: potion });
    s = { ...s, shopOpen: false };
  }
  return s;
}

/** One battle turn of bot policy. */
function battleTurn(state: GameState): GameState {
  const s = state;
  const hero = s.hero!;
  const battle = s.battle!;
  if (battle.phase === "won") return dispatch(s, { type: "NEXT_ENCOUNTER" });
  if (battle.phase === "cleared") return dispatch(s, { type: "COLLECT_AND_RETURN" });
  if (battle.phase === "lost") return dispatch(s, { type: "RETURN_TO_WORLD" });

  const hpRatio = hero.hp / hero.stats.maxHp;
  const potion = (s.inventory["greater_potion"] ?? 0) > 0 ? "greater_potion" : "potion_hp";
  if (hpRatio < 0.35 && (s.inventory[potion] ?? 0) > 0) {
    return dispatch(s, { type: "USE_ITEM", itemId: potion });
  }
  const skills = getHeroSkills(hero);
  const heal = skills.findIndex((sk) => sk.kind === "heal");
  if (hpRatio < 0.4 && heal >= 0 && hero.mp >= skills[heal].mpCost) {
    return dispatch(s, { type: "SKILL", skillIndex: heal });
  }
  // strongest affordable damage skill, else attack
  let bestIndex = -1;
  let bestPower = 0;
  skills.forEach((sk, i) => {
    if (sk.kind !== "damage" || hero.mp < sk.mpCost || (sk.hpCost ?? 0) >= hero.hp) return;
    const power = hero.stats[sk.stat] * sk.multiplier;
    if (power > bestPower) {
      bestPower = power;
      bestIndex = i;
    }
  });
  const weapon = s.gear.find((g) => g.uid === s.equipped.weapon);
  const attackPower = hero.stats[weapon ? (gearItem(weapon).scaling ?? "strength") : "strength"] + (weapon ? gearDamage(weapon) : 2);
  if (bestIndex >= 0 && bestPower > attackPower * 1.15) {
    return dispatch(s, { type: "SKILL", skillIndex: bestIndex });
  }
  return dispatch(s, { type: "ATTACK" });
}

function runRole(roleId: RoleId): FloorStat[] {
  const floors: FloorStat[] = LEVELS.map(() => ({ attempts: 0, deaths: 0, clearLevel: 0, clearGold: 0 }));
  for (let run = 0; run < RUNS_PER_ROLE; run++) {
    let s = dispatch(initialState, { type: "CREATE_HERO", name: "Bot", roleId });
    for (let floor = 1; floor <= LEVELS.length; floor++) {
      let cleared = false;
      for (let attempt = 0; attempt < MAX_ATTEMPTS_PER_FLOOR && !cleared; attempt++) {
        s = townTurn(s);
        floors[floor - 1].attempts++;
        s = dispatch(s, { type: "ENTER_LEVEL", level: floor });
        if (s.screen !== "battle") break; // over-encumbered or locked: bail
        let guard = 0;
        while (s.battle && guard++ < 400) s = battleTurn(s);
        if (s.clearedLevels.includes(floor)) cleared = true;
        else floors[floor - 1].deaths++;
      }
      if (!cleared) break;
      floors[floor - 1].clearLevel += s.hero!.level;
      floors[floor - 1].clearGold += s.gold;
    }
  }
  return floors;
}

let failed = false;
for (const roleId of ROLES) {
  const floors = runRole(roleId);
  const totalDeaths = floors.reduce((sum, f) => sum + f.deaths, 0);
  const finished = floors[LEVELS.length - 1].clearLevel > 0;
  console.log(`\n=== ${roleId.toUpperCase()} (${RUNS_PER_ROLE} runs) - total deaths ${totalDeaths} ===`);
  console.log("floor  attempts  deaths  avg-level  avg-gold");
  floors.forEach((f, i) => {
    const clears = Math.max(1, f.attempts - f.deaths);
    console.log(
      `${String(i + 1).padStart(5)}  ${String(f.attempts).padStart(8)}  ${String(f.deaths).padStart(6)}  ` +
        `${(f.clearLevel / Math.max(1, RUNS_PER_ROLE)).toFixed(1).padStart(9)}  ${(f.clearGold / Math.max(1, RUNS_PER_ROLE)).toFixed(0).padStart(8)}`,
    );
    void clears;
  });
  // loose regression bounds: every role finishes, without absurd death counts
  if (!finished || totalDeaths > RUNS_PER_ROLE * 12) {
    console.error(`BOUNDS FAILED for ${roleId}: finished=${finished} deaths=${totalDeaths}`);
    failed = true;
  }
}
if (CHECK_MODE && failed) process.exit(1);
