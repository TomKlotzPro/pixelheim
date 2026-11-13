# Triage: from the players' findings to Linear

The triage runs on Opus. A player can be wrong; nothing they report reaches Linear until triage has checked it.

## 1. Merge

- **Two findings are one** when they show the same fault in the same place: same map and nearby cells, or the same screen, with the same symptom. Keep the clearest screenshot and the shortest steps, and keep the other players' names as "also seen by".
- **The same fault in several places** (one typography rule broken on five screens, one seam on three lines between maps) is one finding listing every place.
- **Read each player's summary too.** An observation left there that can cost the player gold, progress or a choice (something bought, a quest taken without asking) gets one replay for its picture, like a finding with no screenshot (step 2), and is kept or dropped the same way.
- **Check Linear.** Search the open Pixelheim issues, and the closed ones of the last month, for the same thing. Already ticketed and still open: drop it, and note the ticket. Closed but back: keep it, and link the old ticket ("came back after PIX-NNN").

## 2. Confirm

- **A bug is replayed.** Start a fresh session with the finding's start options, on your own port, and send its keys in order. Take a `look` where the player saw it.
  - Seen again: **confirmed**.
  - Seen once in two tries: **flaky**. Keep it, and say so in the ticket.
  - Not seen: **dropped**. Keep a line about it for `lessons.md`, since a false alarm teaches the rules something.
  - The steps can't be replayed (the player's log was incomplete): try once to reach the same place another way, else drop it.
- **A finding with no screenshot** (only the state's words, or the code) gets one replay for its picture before it is kept. Without a picture, drop it.
- **A confusing or polish finding isn't replayed.** Judge it from its screenshots: would most players agree? Keep it only if yes.
- **Re-rate the severity** with `SKILL.md`'s table, from what you saw yourself.
- **You may read the code** to point the ticket at the right place, but a ticket says what a player sees, not a guess at the fix.

## 3. File

Each kept finding becomes one issue in the Pixelheim team, project **Pixelheim: Agent Playtests**, in Backlog:

- **Title**: what a player sees, in a few words ("The hero walks through the mill's west wall").
- **Body**, short sentences, for people:
  - what happens, and where (map and cell, or screen);
  - what should happen;
  - how to see it: the start options and the keys;
  - which player found it, the model, and confirmed, flaky or judged.
- **The screenshots**, uploaded to the issue. They show paid art, so they go only to Linear: never into the repo.
- **Agent notes** in a collapsed section: the state JSON, and the code area if you found it.
- **Priority** by severity: S1 High, S2 Medium, S3 Low. **S4 nits** are not filed one by one: put them all in one issue for the run, "Playtest nits, <date>", as a checklist.

## 4. Report

Return, for the orchestrator:
- the issues filed, each with its identifier, title and severity;
- what was dropped, and why, one line each;
- per player: findings sent, confirmed, flaky, dropped;
- what in the rules or the tool led a player wrong. The orchestrator turns that into `lessons.md` and rule changes.
