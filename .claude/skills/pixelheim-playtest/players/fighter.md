# The fighter

**Goal:** find what's wrong or unfair in combat, role by role. Hits that land from too far or not at all, foes' attacks you can't read, numbers that lie.

**Start:** a hero of a given role and level, next to a foe. Use play.py's presets (`.claude/skills/pixelheim-godot/playtest.md`): role, level, map, and when it passes harness flags, `fight --foe <id>` with `--foe-distance <n>` to stand a foe a few cells off. Without them, walk to the packs `look`'s state lists.

**Model:** Sonnet.

## Route

Play four roles, about 15 looks each: **warrior**, **ranger**, **mage**, **rogue**. If looks are left, add the cleric, paladin or necromancer. Use level 5 or 10 for each, so you have skills.

For each role:
1. **One plain foe**, such as an orc or a goblin: fight it close, then from as far as your weapon should reach.
2. **A pack** (`pack` when the preset takes it, or a pack in the wild): do the foes spread round you, and can you get out?
3. **A foe that shoots**: the Smuggler Gunner (`pirate_gunner`), the Turncoat Bowman (`turncoat_bowman`) or the Fire Imp. Does it keep its distance? Does it glow before it fires? Can you see its shot fly, and dodge it?
4. **Your skills**: each one by its number key, at least once. Does it reach where it should, and cost what it says?

## Check

- **Reach.** A sword, axe, hammer, dagger or fist lands only on the cell in front. A bow or a staff reaches three cells, with its arrow or bolt flying. A hit from further than that, or a miss at the right distance, is a bug.
- **Numbers.** Does the damage that floats up match the foe's health in the state? Does your health bar match your health in the state?
- **Reading a foe.** Is every big attack told before it lands (a glow, a band or a circle on the ground)? Is there time to roll out of it (Shift)? An elite's cleave should reach about one cell and a quarter.
- **Dodging.** A roll through an attack in time should take no damage.
- **Skills.** Number keys 1 to 6. Does each one fire, and does the dock show its turn coming back? Does one fire with nothing to hit and waste its energy?
- **The fall.** Let one fight go badly once. Where do you wake, and what did you lose?
- **Loot.** Can you pick up what drops? Does the gold count go up by what floated?

Gold and XP numbers floating up are wanted. Don't report the weapons' reach above as a bug when it works as described.
