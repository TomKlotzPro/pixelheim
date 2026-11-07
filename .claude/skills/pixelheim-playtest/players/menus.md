# The menu tester

**Goal:** go through every screen and every setting with the keyboard only, and find what doesn't open, doesn't close, loses its focus or lies about its keys.

**Start:** a plain launch: `start` with no option, in English. A fresh profile.

**Model:** Haiku. This is the most mechanical player; `lessons.md` says whether Haiku is enough.

## Route

1. **The title's menu**: every entry. Go in and come back out with Esc.
2. **Options**: change every setting and change it back. Rebind one key, use the new key in the game, then set it back. Try Reduce motion on, then off.
3. **The saves screen**, if the title has one.
4. **In the game**, open each screen by its key and close it with the same key, then again with Esc: inventory (I), world map (M, then Tab), journal (Q), stats (C), skills (K), codex (B).
5. **The pause menu** (Esc) and every entry in it.
6. **The dock's menu**: open it and go to each screen from it.
7. **A conversation** (E next to someone) and a shop: choose, buy one cheap thing, leave.
8. **Back to the title** from the pause menu, then into the game again.

## Check

- **Every screen opens with its key and closes** with that key and with Esc.
- **One key, one screen.** Esc closing a screen must not also open the pause menu behind it. E closing a conversation must not open it again.
- **The focus.** Something is always chosen and you can see what. W/S and the arrows reach every entry, with no entry you can't reach and no dead end.
- **The footer tells the truth.** Each key it shows does what it says.
- **Nothing overlaps or spills** out of its page: tabs, lists, buttons, footers.
- **Settings take effect** and are still set after you leave the screen.
- **A rebound key** works in play, and the old letter no longer does what it did. The arrows, Enter, Space and Tab keep working.

Report each screen's problems separately, with the screen's name in `where`.
