# The fighter

**Goal:** find what's wrong or unfair in combat, role by role. Hits that land from too far or not at all, foes' attacks you can't read, numbers that lie.

**Start:** one session per fight, each with a hero of a given role and level next to a foe. Stop it before starting the next. For example:
* `--role warrior --level 5 --flags "fight --foe orc"`: an orc beside the hero;
* `--role ranger --level 5 --flags "fight --foe orc --foe-distance 3"`: the orc three cells off;
* `--role mage --level 10 --flags "fight pack --foe goblin"`: a goblin and its pack;
* `--role warrior --level 8 --flags "fight --foe turncoat_bowman --foe-distance 3"`: a shooter;
* `--role warrior --level 10 --flags "fight elite --foe orc"`: an elite, for its cleave.

The `fight` preset hands the fight over before its first swing (PIX-435): at the first look the foe is whole and where the flags put it, `--foe-distance 3` three cells off. Read `foes` at the first look: the first blow is yours.

play.py makes every such fight real: the foe can hurt you. Never pass `kill` or `slay`.

**Model:** Sonnet.

## Route

Play four roles, about 15 looks each: **warrior**, **ranger**, **mage**, **rogue**. If looks are left, add the cleric, paladin or necromancer. Use level 5 or 10 for each, so you have skills. One of the four roles fights an elite: watch its cleave and roll through it once.

For each role:
1. **One plain foe**, such as an orc or a goblin: fight it close, then from as far as your weapon should reach.
2. **A pack** (`fight pack --foe goblin`): do the foes spread round you, and can you get out?
3. **A foe that shoots**: the Smuggler Gunner (`--foe pirate_gunner`) or the Turncoat Bowman (`--foe turncoat_bowman`). Does it keep its distance? Does it glow before it fires? Can you see its shot fly, and dodge it?
4. **Your skills**: each one by its number key, at least once. Does it reach where it should, and cost what it says?

## Check

- **Reach.** A sword, axe, hammer, dagger or fist lands only on the cell in front. A bow or a staff reaches three cells, with its arrow or bolt flying. A hit from further than that, or a miss at the right distance, is a bug.
- **Numbers.** Does the damage that floats up match the foe's health in the state? Does your health bar match your health in the state?
- **Reading a foe.** Is every big attack told before it lands (a glow, a band or a circle on the ground)? An elite's cleave should reach about one cell and a quarter.
- **Dodging.** Roll (Shift) when the warning shows: being hit through a roll started then is a finding. How long the warning lasts is not.
- **Skills.** Number keys 1 to 6. Does each one fire, and does the dock show its turn coming back? Does one fire with nothing to hit and waste its energy? A skill that costs nothing and shows nothing is a finding: the state shows no effects of skills, so compare the dock and the picture before and after.
- **The fall.** Let one fight go badly once. Where do you wake, and what did you lose?
- **Loot.** Can you pick up what drops? Does the gold count go up by what floated?

Gold and XP numbers floating up are wanted. Don't report the weapons' reach above as a bug when it works as described.
