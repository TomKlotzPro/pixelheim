# The French reader

**Goal:** play the game in French and find every word that's wrong. Cut-off or overflowing text, English left untranslated, mistakes, and typography that breaks the game's rules.

**Start:** three sessions, each a fresh profile. Stop each before starting the next.
1. `start --lang fr`: the title, Options, hero creation and the opening scene, up to the first fight on the road. Wait out each caption before you press E (`SKILL.md`), so none goes by unread.
2. `start --lang fr --map town --at 11,8 --flags "--prologue 5"`, then `keys "w, e"`: Maren and the dawn's boxes. For the night's earlier steps, `--prologue 2` to `4` start on the square, a long walk away: add an `--at` beside that step's place (the caller on Upper Street, Sela's tent, the well and the burning homes). Then `start --lang fr --role warrior --map town`: the village's people by day.
3. `start --lang fr --role warrior --map town_shop --flags shop`: a shop's goods.

Quote the words from `look`'s `text` and `hud` when they show them, so the quote is exact.

**Model:** Fable (`lessons.md`, 2026-11-13).

## Route

1. **The title and its menu**, then the options screen.
2. **Making a hero**: choose each role in turn and read its description before you type the name.
3. **The opening scene, the Night of Ash and the dawn**: read every box.
4. **In the village**: talk to each person you meet, and open each screen at least once (I, M, Q, C, K, B, Esc). A shop's list of goods, the bank and the notice board. Then with « Texte de lecture agrandi » on: the ledger screens (the mayor's works, the bank) and each counter.
5. **One fight**, for the numbers and words it shows.

## Check

- **Words only.** Colours, greyed rows and the way through a map belong to the other players.
- **Text that doesn't fit**: cut off, running out of its frame or button, overlapping other text. French runs about a third longer than English.
- **English left over**: any English word on a French screen, apart from names.
- **Mistakes**: spelling, grammar, gender and number agreement, a word missing.
- **One voice**: the game's own words (menus, hints, items, quests) say « vous » to the player; a « tu » there is a finding. In a conversation a character may say « tu » (a child, an old friend, Bram), but one character should keep to one of the two.
- **The game's names**: la Marche, Fernoir, la Porte-Givre, les Bois-Profonds. One place written two ways is a finding.
- **The player is neutral**: « vous avez atteint », not « vous êtes arrivé ».
- **Typography**, the game's French house style (`.claude/skills/pixelheim-godot/release.md`). Report typography only against these rules: a form they don't name is not a finding.
  - a narrow no-break space before `: ; ! ?` and inside « » (U+202F; on screen it looks like a thin space, and the mark never starts a line);
  - « » for quotes, never " ";
  - the straight apostrophe ' only (fr.po has no curly one);
  - … for an ellipsis;
  - French numbers: « 0,5 % » (a decimal comma, U+202F before %);
  - a spaced hyphen ( - ) is the game's dash in both languages: report only one that starts a line.

  Check the marks with a script over each state's `text` and `hud` (as french-fable/typo.py did on 2026-11-13), and spend looks on line breaks and fit, which only the picture shows.

Quote the French exactly, and say what it should be. One finding per screen with several small mistakes is fine. List them in it.
