# The menu tester

**Goal:** go through every screen and every setting with the keyboard only, and find what doesn't open, doesn't close, loses its focus or lies about its keys.

**Start:** a plain launch: `start` with no option, in English. A fresh profile. The title's intro runs about 8 s before its menu shows: send `wait:8` before the first look. The state's `focus` says which row is chosen: read it before each E on a setting rather than counting presses.

Then one session per preset, for what the plain launch doesn't reach. Stop each before starting the next:
* `start --role mage --level 10 --flags skills` and `start --role warrior --flags stats`: 3 skill points and 5 stat points to spend ("E do it" and the path chooser). A `--level` hero alone arrives with none;
* `start --role warrior --map town_shop --flags shop`: a counter's Sell and Craft tabs (500 g and a pack to sell);
* `start --role warrior --map town_smith --flags shop`: Hilda's Forge and Craft tabs;
* `start --role warrior --map town_alchemist --flags shop`: Vex, who stands inside at 8,2.

**Model:** Fable (`lessons.md`, 2026-11-13).

## Route

1. **The title's menu**: every entry. Go in and come back out with Esc.
2. **Options**: change every setting and change it back, Language too (it reloads the game). Skip Fullscreen, since the headless browser shows nothing of it. Rebind one key, use the new key in the game, then set it back. Try Reduce motion on, then off.
3. **The saves screen**, if the title has one.
4. **In the game**, open each screen by its key and close it with the same key, then again with Esc: inventory (I), world map (M, then Tab), journal (Q), stats (C), skills (K), codex (B).
5. **The pause menu** (Esc) and every entry in it.
6. **A conversation** (E next to someone) and a shop: choose, buy one cheap thing, leave. For the Sell, Craft and Forge tabs, the counter sessions above: check each tab by picture.
7. **Back to the title** from the pause menu, then into the game again.
8. **Large reading text** on (Options), then every screen once more.

The dock (its Menu button and how it is drawn) is out of your route. Each of its screens has its own key (step 4).

## Check

- **Every screen opens with its key and closes** with that key and with Esc.
- **One key, one screen.** Esc closing a screen must not also open the pause menu behind it. E closing a conversation must not open it again.
- **The focus.** Something is always chosen and you can see what. W/S and the arrows reach every entry, with no entry you can't reach and no dead end. A list whose focus doesn't wrap while the others do is a finding.
- **The footer tells the truth.** Each key it shows does what it says.
- **Nothing overlaps or spills** out of its page: tabs, lists, buttons, footers.
- **Settings take effect** and are still set after you leave the screen.
- **A rebound key** works in play, and the old letter no longer does what it did. The arrows, Enter, Space and Tab keep working.

Report each screen's problems separately, with the screen's name in `where`.
