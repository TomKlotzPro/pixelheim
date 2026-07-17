<p align="center">
  <img src="scripts/preview.png" alt="Pixelheim sprite sheet" width="600" />
</p>

<h1 align="center">Pixelheim</h1>

<p align="center">
  <b>A retro pixel-art open-world RPG built with React, TypeScript and PixiJS. No game engine - a pure reducer for the rules, a WebGL canvas for the world.</b><br />
  Fifteen floors. Two bosses. Infinite cheese wheels. Currently v0.19 - 1.0 has to be earned.
</p>

---

## Play it

**https://tomklotzpro.github.io/pixelheim/** - deployed to GitHub Pages on every push to `main`. Every pull request gets its own playable preview.

## The game

You wake in Pixelheim village, in an open world called **the Ashenreach**: walk the roads (safe) or the wilds (not safe), talk to villagers, forage for materials, trade on Main Street, and climb the Ashen Mountain - ten floors of increasingly rude monsters - to slay **Fafnyr the Ashen** at the summit. Behind the dragon's hoard, a stairway descends: five more floors of the **Undermountain**, down to **Morvax the Deathless**.

- **A living open world**: a WebGL-rendered overworld with walk cycles, flowing water, swaying grass, a day/night cycle, lantern glows after dark and embers drifting over the ashen wastes
- **A real village**: Main Street with signed shops you walk into and trade by talking to the keeper, houses with distinct roofs, a market corner, an orchard, and villagers with dialogue (a bobbing "!" shows who will talk)
- **4 playable roles**: Warrior, Mage, Rogue, Cleric, each with its own stats, growth and skill kit
- **Skill trees**: one skill point per level, spent across three branches per role - actives, upgrades and passives, each branch ending in a tier-3 capstone (48 nodes total). No respec. Retro rules
- **Stat points that explain themselves**: 5 points per level, and the stat sheet shows what each stat does with live numbers and a preview of what the next point buys
- **Turn-based combat on a canvas stage**: lunges, hit flashes and floating damage numbers. Poison and burn tick every turn, stun steals them, and fleeing is always an option (dexterity helps)
- **Loot with rarities**: gear drops as common, fine or epic instances, and Smith Hilda's **Forge** upgrades a piece up to +7 for gold
- **Crafting**: forage regional materials from the wilds (forest herbs, marsh reeds, ember shards) and craft potions, cures and upgrades at the shrine
- **Main Street**: three specialized shops - Odo's general goods, the smithy, and Alchemist Vex, who pays full price for reagents
- **Skyrim-style inventory**: category tabs, equip weapon + body + off-hand, carry weight with over-encumbrance, and yes, cheese wheels
- **Chiptune audio**: music and sound effects synthesized in the browser with the Web Audio API, no audio files, volume options included
- **Auto-save + save codes**: progress persists in localStorage, and a `PXH1.…` code moves your save to any other device. Saves are versioned and migrated forward on load, so day-one saves still work today
- **Comfort**: Escape pauses (save code, options, quit-to-title that resumes in place), controls are rebindable, and AZERTY keyboards get ZQSD out of the box

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
pnpm test:unit # vitest over the pure game modules, milliseconds
pnpm test:e2e  # Playwright suite against the production build
pnpm sim       # headless balance simulation (--check for the regression gate)
```

## How it works

React 19 + TypeScript + PixiJS v8. The rules live in a pure reducer over a Zustand store; the renderer subscribes to state and draws - it never decides anything:

```text
src/
  app/             # the shell: boot, App routing, settings, changelog, global css
  game/            # pure game data and rules (no React)
    types.ts         # every type in the game - the shared vocabulary
    hero/            # character, roles, levels, skill tree, stat sheet math
    combat/          # battle engine, damage formulas, bestiary, encounters, drops
    economy/         # items, rarity, shops, crafting recipes, professions
  world/           # the tile engine
    tiles.ts         # tile definitions and walkability
    parseMap.ts      # ASCII grid parser with startup validation
    npcs.ts          # villagers, wander loops, dialogue hooks
    maps/            # maps authored as text grids, like the sprites
  audio/           # Web Audio chiptune synth: sequencer, sfx, buses
  render/          # the PixiJS layer: terrain, actors, atmosphere, battle stage
  state/
    store.ts         # vanilla Zustand store + dispatch (sim-drivable)
    gameReducer.ts   # a router over six domain reducers (Immer drafts)
    reducers/        # meta, battle, inventory, economy, progression, world
    save.ts          # versioned localStorage persistence + migrations
  ui/              # React on top of it all
    screens/         # full-screen views: title, creation, world, battle...
    panels/          # overlays: inventory, shop, skill tree, map, options
    widgets/         # small reusable pieces: sprites, stat bars, the HUD
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
- [x] A WebGL renderer (PixiJS): walk cycles, particles, lighting
- [x] A pause menu, rebindable controls, a stat sheet that explains itself
- [ ] Fast travel and a fog-of-war map screen
- [ ] Quests, chests, and a house to own
- [ ] More regions beyond the Ashenreach
- [ ] Crafting professions that level up
- [ ] 1.0, eventually - it has to be earned

## License

MIT
