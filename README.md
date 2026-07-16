<p align="center">
  <img src="scripts/preview.png" alt="Pixelheim sprite sheet" width="600" />
</p>

<h1 align="center">Pixelheim</h1>

<p align="center">
  <b>A retro pixel-art open-world RPG built with React and TypeScript. No game engine, no canvas, just components.</b><br />
  Fifteen floors. Two bosses. Infinite cheese wheels.
</p>

---

## Play it

**https://tomklotzpro.github.io/pixelheim/** - deployed to GitHub Pages on every push to `main`. Every pull request gets its own playable preview.

## The game

You wake in Pixelheim village, in an open world called **the Ashenreach**: walk the roads (safe) or the wilds (not safe), talk to villagers, forage for materials, trade on Main Street, and climb the Ashen Mountain - ten floors of increasingly rude monsters - to slay **Fafnyr the Ashen** at the summit. Behind the dragon's hoard, a stairway descends: five more floors of the **Undermountain**, down to **Morvax the Deathless**.

- **An open world**: a tile-based overworld with forests, marshes and ashen wastes, a real village with wandering NPCs and dialogue, and dungeons as places you walk to. Wild regions telegraph their danger, and ambushes look like ambushes
- **4 playable roles**: Warrior, Mage, Rogue, Cleric, each with its own stats, growth and skill kit
- **Skill trees**: one skill point per level, spent across three branches per role - active skills, upgrades that modify them, and always-on passives (36 nodes total). No respec. Retro rules
- **Stat points**: 5 points per level, placed wherever you want. Your Mage can bench-press if you insist
- **Turn-based combat**: attack, cast, chug a potion, or flee like a coward (dexterity helps). Poison and burn tick every turn, stun steals them
- **Loot with rarities**: gear drops as common, fine or epic instances, and Smith Hilda's **Forge** upgrades a piece up to +7 for gold
- **Crafting**: forage regional materials from the wilds (forest herbs, marsh reeds, ember shards) and craft potions, cures and upgrades at the shrine
- **Main Street**: three specialized shops - Odo's general goods, the smithy, and Alchemist Vex, who pays full price for reagents
- **Skyrim-style inventory**: category tabs, equip weapon + body + off-hand, carry weight with over-encumbrance, and yes, cheese wheels
- **Chiptune audio**: music and sound effects synthesized in the browser with the Web Audio API, no audio files, volume options included
- **Auto-save + save codes**: progress persists in localStorage, and a `PXH1.…` code moves your save to any other device. Saves are versioned and migrated forward on load, so day-one saves still work today

| Title | Battle | Inventory |
| --- | --- | --- |
| ![Title screen](docs/title.png) | ![Battle screen](docs/battle.png) | ![Inventory](docs/inventory.png) |

## Run it

```bash
pnpm install
pnpm dev       # play at http://localhost:5173
```

```bash
pnpm build     # typecheck + production build
pnpm preview   # serve the production build
pnpm lint      # oxlint, strict, zero warnings allowed
pnpm sprites   # regenerate the PNG sprites
pnpm test:e2e  # Playwright suite against the production build
pnpm sim       # headless balance simulation (--check for the regression gate)
```

## How it works

Everything is plain React 19 + TypeScript, and the entire game loop lives in one pure reducer:

```text
src/
  game/            # pure game data and rules (no React)
    types.ts         # every type in the game
    roles.ts         # the 4 playable roles
    skillTree.ts     # 36 skill nodes: actives, upgrades, passives
    items.ts         # weapons, apparel, potions, food, misc
    gear.ts          # gear instances, rarities, drop tables
    recipes.ts       # crafting recipes and regional materials
    shop.ts          # the three shops, stock gating, the Forge
    monsters.ts      # the bestiary
    levels.ts        # the 15 floors and their rewards
    combat.ts        # damage formulas, flee chance, elite scaling
    character.ts     # hero creation, level ups, carry weight
  world/           # the tile engine
    tiles.ts         # tile definitions and walkability
    parseMap.ts      # ASCII grid parser with startup validation
    npcs.ts          # villagers, wander loops, dialogue hooks
    maps/            # maps authored as text grids, like the sprites
  audio/           # Web Audio chiptune synth: sequencer, sfx, buses
  state/
    gameReducer.ts   # the whole game loop as a reducer
    save.ts          # versioned localStorage persistence + migrations
  components/      # one component per screen + overlays
```

Maps are ASCII art in source (`.` grass, `f` forest, `^` mountain, `~` water, `=` path, `#` wall, `D` door...). The parser validates every map at load and the e2e suite imports them all, so a malformed map fails CI with a precise message.

Because the reducer is pure and headless, the game can be played by a script: [`scripts/balance-sim.ts`](scripts/balance-sim.ts) runs a bot through the full game for every role and reports win rates, level curves and gold economy. Balance changes are tuned against it.

Old saves never break: saves and save codes carry a version and are replayed through an ordered list of migrations on load, and the e2e suite pins frozen fixtures of every historical save format.

### The sprites

All the pixel art in `public/sprites/` is generated by [`scripts/generate-sprites.mjs`](scripts/generate-sprites.mjs): sprites are authored as 16x16 character grids with per-sprite palettes, and the script encodes them into real PNG files with a dependency-free PNG encoder written on top of `node:zlib`. Edit a grid, run `pnpm sprites`, done. CI fails if the generated PNGs drift from the grids.

## Roadmap ideas

- [x] Shops and gold sinks beyond the inn
- [x] The Undermountain: floors 11-15 and a second boss
- [x] Random loot drops and rarities
- [x] Status effects (poison, burn, stun)
- [x] Sound effects and chiptune music
- [x] A world map instead of a list
- [x] Skill trees, stat points, crafting, specialized shops
- [ ] A WebGL renderer (PixiJS): walk cycles, particles, lighting
- [ ] Fast travel and a fog-of-war map screen
- [ ] Quests, chests, and a house to own
- [ ] More regions beyond the Ashenreach

## License

MIT
