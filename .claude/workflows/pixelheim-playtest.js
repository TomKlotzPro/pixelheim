export const meta = {
  name: 'pixelheim-playtest',
  description: 'Agents play Pixelheim unseen (the web build in a headless Chrome) on cheaper models; an Opus triage replays every bug and files what holds in Linear',
  whenToUse: 'A playtest after a big release, or when Tom asks for one. args: {run: "2026-11-07", players?: ["newcomer","fighter","explorer","french","menus"], compare?: "menus" | null, looks?: 70, file?: true}. Needs godot/tools/play.py (PIX-423) and the pixelheim-playtest skill on main. The main session applies the lessons it returns.',
  phases: [
    { title: 'Build', detail: 'one web export of main, with the private art, shared by every player' },
    { title: 'Play', detail: 'each player plays its own session and reports findings with proof' },
    { title: 'Triage', detail: 'findings merged and checked against Linear; each bug replayed on Opus' },
    { title: 'File', detail: 'what held filed in the Agent Playtests project, with screenshots' },
    { title: 'Lessons', detail: 'what the run taught about the rules, the tool and the models' },
  ],
}

// Who plays, and on which model (Tom, 2026-11-07: cheaper players, Opus
// orchestrates and triages). lessons.md may move a player to another model.
const PLAYERS = {
  newcomer: 'sonnet',
  fighter: 'sonnet',
  explorer: 'sonnet',
  french: 'haiku',
  menus: 'haiku',
}
const OTHER = { sonnet: 'haiku', haiku: 'sonnet' }

const REPO = '/Users/klotztom/playground/pixelheim'
const SKILL = `${REPO}/.claude/skills/pixelheim-playtest`
const a = args || {}
if (!a.run) throw new Error('args needs run, a name for this run such as the date')
const RUN_DIR = `/Users/klotztom/playground/pixelheim-playtests/${a.run}`
const LOOKS = a.looks || 70
const FILE = a.file !== false
const chosen = a.players || Object.keys(PLAYERS)
const compare = a.compare === undefined ? 'menus' : a.compare

const SAFETY = [
  'Never run godot with a window, shot.sh, flows.sh without --quiet, lookbook.sh, or any --slot.',
  'Never git add, commit, push, or edit a file in the repo. Screenshots show paid art: they stay in the run folder and go only to Linear.',
  'Never `open` a file on Tom\'s screen.',
  'Stop every play.py session you start, even when something fails.',
].join('\n- ')

const LINEAR = 'Linear tools: load them with ToolSearch (query "Linear issue"); the claude_ai_Linear or the linear-pixelheim server, whichever is there. Team "Pixelheim".'

// ---------------------------------------------------------------- Build
phase('Build')
const BUILD = {
  type: 'object',
  properties: {
    ok: { type: 'boolean' },
    head: { type: 'string', description: 'main\'s head, 8 characters' },
    version: { type: 'string', description: 'the game version, from godot/assets/data/changelog.json' },
    export: { type: 'string', description: 'absolute path of the exported web folder' },
    note: { type: 'string', description: 'why not ok, or anything the players should know' },
  },
  required: ['ok', 'head', 'version', 'export', 'note'],
}
const build = await agent(
  `Prepare a Pixelheim playtest: one web export of main that every player will serve.\n\n` +
  `Work in the main checkout, ${REPO}. First check: it is on main, \`git status --porcelain\` is empty, and it is at origin/main after \`git fetch\` ` +
  `(if behind, \`git merge --ff-only origin/main\`; if anything else is off, change nothing and return ok=false saying what). ` +
  `Check that godot/tools/play.py and .claude/skills/pixelheim-godot/playtest.md exist (PIX-423); if not, return ok=false.\n\n` +
  `Then export the web build the way playtest.md says (else: \`godot --headless --audio-driver Dummy --path godot --import\`, then ` +
  `\`godot --headless --audio-driver Dummy --path godot --export-release Web export/web/index.html\`). The private art is installed in this checkout; ` +
  `check the export has it (the paid packs under godot/assets/puny/ are present before exporting). Afterwards run \`git checkout -- godot/default_bus_layout.tres\` ` +
  `(the import rewrites its header) and check \`git status --porcelain\` is empty again.\n\n` +
  `Then smoke-test it: one play.py session on port 8790, one look, stop. Create the run folder ${RUN_DIR}.\n\nRules:\n- ${SAFETY}`,
  { label: 'build the web export', phase: 'Build', schema: BUILD, model: 'sonnet' },
)
if (!build || !build.ok) return { run: a.run, error: 'build failed', build }
log(`v${build.version} at ${build.head}, exported to ${build.export}`)

// ----------------------------------------------------------------- Play
phase('Play')
const FINDING = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    kind: { type: 'string', enum: ['bug', 'confusing', 'polish'] },
    severity: { type: 'string', enum: ['S1', 'S2', 'S3', 'S4'] },
    where: { type: 'string', description: 'map and cell, or the open screen' },
    happened: { type: 'string' },
    expected: { type: 'string' },
    steps: { type: 'string', description: 'the start options, then every keys command in order' },
    screenshots: { type: 'array', items: { type: 'string' } },
    state: { type: 'string', description: 'the state JSON that matters' },
    seenTwice: { type: ['boolean', 'null'], description: 'for a bug: did it happen again when tried twice' },
  },
  required: ['title', 'kind', 'severity', 'where', 'happened', 'expected', 'steps', 'screenshots', 'state', 'seenTwice'],
}
const REPORT = {
  type: 'object',
  properties: {
    looks: { type: 'integer', description: 'how many looks you used' },
    reached: { type: 'string', description: 'how far you got in your route' },
    summary: { type: 'string', description: 'how the session went, what you did not reach, what slowed you down (the rules or the tool)' },
    findings: { type: 'array', items: FINDING },
  },
  required: ['looks', 'reached', 'summary', 'findings'],
}

const sessions = []
chosen.forEach((id) => {
  if (!PLAYERS[id]) throw new Error(`no player "${id}" (have ${Object.keys(PLAYERS).join(', ')})`)
  sessions.push({ id, model: PLAYERS[id] })
  if (id === compare) sessions.push({ id, model: OTHER[PLAYERS[id]] })
})
sessions.forEach((s, i) => {
  s.label = `${s.id} (${s.model})`
  s.port = 8710 + i * 10
  s.dir = `${RUN_DIR}/${s.id}-${s.model}`
})

const reports = await parallel(sessions.map((s) => () =>
  agent(
    `You are a playtester for Pixelheim: the ${s.id} player. Play the real game as a player would and report what you find.\n\n` +
    `Read first, in this order: ${SKILL}/SKILL.md, ${SKILL}/lessons.md, ${SKILL}/players/${s.id}.md, and ` +
    `${REPO}/.claude/skills/pixelheim-godot/playtest.md (play.py's commands and options). Run play.py from ${REPO}.\n\n` +
    `The game: v${build.version}, exported at ${build.export}. Your session: port ${s.port}. Keep your screenshots and your log of commands in ${s.dir}. ` +
    `Your budget: ${LOOKS} looks. Look at each screenshot yourself with the Read tool.\n\nRules:\n- ${SAFETY}`,
    { label: s.label, phase: 'Play', schema: REPORT, model: s.model },
  ).then((r) => (r ? { ...s, ...r } : { ...s, looks: 0, reached: 'nothing', summary: 'the agent returned nothing', findings: [] })),
))
const sent = reports.reduce((n, r) => n + r.findings.length, 0)
log(`${sent} findings from ${reports.length} sessions`)

// --------------------------------------------------------------- Triage
phase('Triage')
const MERGED = {
  type: 'object',
  properties: {
    kept: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          ...FINDING.properties,
          key: { type: 'string', description: 'a short unique slug' },
          players: { type: 'array', items: { type: 'string' }, description: 'the session labels that reported it' },
          replay: { type: 'boolean', description: 'true for a bug of S1 to S3: it must be replayed before filing' },
          note: { type: 'string', description: 'why kept, the Linear ticket it came back after, or how it was judged' },
        },
        required: [...FINDING.required, 'key', 'players', 'replay', 'note'],
      },
    },
    dropped: {
      type: 'array',
      items: {
        type: 'object',
        properties: { title: { type: 'string' }, players: { type: 'array', items: { type: 'string' } }, why: { type: 'string' } },
        required: ['title', 'players', 'why'],
      },
    },
  },
  required: ['kept', 'dropped'],
}
const all = reports.flatMap((r) => r.findings.map((f) => ({ ...f, player: r.label })))
const merged = all.length === 0 ? { kept: [], dropped: [] } : await agent(
  `Triage a Pixelheim playtest's findings: steps 1 and 2 of ${SKILL}/triage.md, but do not replay bugs yourself. Read ${SKILL}/SKILL.md and triage.md first.\n\n` +
  `- Merge the findings that are one fault; its \`players\` are the \`player\` labels of every finding merged into it, exactly as written.\n` +
  `- Check Linear for each (open Pixelheim issues, and those closed in the last month). ${LINEAR}\n` +
  `- Bugs of S1 to S3: keep them with replay=true; the replays run after you.\n` +
  `- Confusing and polish findings, and S4 bugs: judge each from its screenshots (Read them) and keep only what most players would agree with, replay=false.\n\n` +
  `The findings (JSON):\n${JSON.stringify(all, null, 1)}`,
  { label: 'merge and judge', phase: 'Triage', schema: MERGED },
)
if (!merged) return { run: a.run, error: 'triage returned nothing', reports }

const VERDICT = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['confirmed', 'flaky', 'dropped'] },
    severity: { type: 'string', enum: ['S1', 'S2', 'S3', 'S4'] },
    screenshots: { type: 'array', items: { type: 'string' }, description: 'your own, showing it' },
    note: { type: 'string', description: 'what you saw; for a drop, why the player may have been wrong' },
  },
  required: ['verdict', 'severity', 'screenshots', 'note'],
}
const toReplay = merged.kept.filter((f) => f.replay)
const replayed = await parallel(toReplay.map((f, i) => () =>
  agent(
    `Replay one finding from a Pixelheim playtest, step 2 of ${SKILL}/triage.md. Read ${SKILL}/SKILL.md, triage.md and ` +
    `${REPO}/.claude/skills/pixelheim-godot/playtest.md first.\n\nThe game is exported at ${build.export}. Use port ${8800 + i * 5} and keep your screenshots in ${RUN_DIR}/replay-${f.key}. ` +
    `Start a fresh session with the finding's start options and send its keys in order; look where the player saw it, and try twice. ` +
    `You may read the game's code to understand what you see. Re-rate the severity from what you saw yourself.\n\nThe finding:\n${JSON.stringify(f, null, 1)}\n\nRules:\n- ${SAFETY}`,
    { label: `replay ${f.key}`, phase: 'Triage', schema: VERDICT },
  ).then((v) => ({ ...f, verdict: v || { verdict: 'dropped', severity: f.severity, screenshots: [], note: 'the replay returned nothing' } })),
))
const held = [
  ...merged.kept.filter((f) => !f.replay),
  ...replayed.filter((f) => f.verdict.verdict !== 'dropped').map((f) => ({
    ...f, severity: f.verdict.severity, screenshots: [...f.screenshots, ...f.verdict.screenshots], note: `${f.verdict.verdict}: ${f.verdict.note}`,
  })),
]
const replayDrops = replayed.filter((f) => f.verdict.verdict === 'dropped').map((f) => ({ title: f.title, players: f.players, why: `not seen again: ${f.verdict.note}` }))
log(`${held.length} held, ${merged.dropped.length + replayDrops.length} dropped`)

// ----------------------------------------------------------------- File
let filed = []
if (FILE && held.length > 0) {
  phase('File')
  const FILED = {
    type: 'object',
    properties: {
      issues: {
        type: 'array',
        items: {
          type: 'object',
          properties: { id: { type: 'string' }, title: { type: 'string' }, severity: { type: 'string' }, url: { type: 'string' } },
          required: ['id', 'title', 'severity', 'url'],
        },
      },
    },
    required: ['issues'],
  }
  const out = await agent(
    `File a Pixelheim playtest's findings in Linear: step 3 of ${SKILL}/triage.md, exactly as it says (project "Pixelheim: Agent Playtests", Backlog, ` +
    `screenshots uploaded to each issue, S4 nits gathered in one "Playtest nits, ${a.run}" issue). Read triage.md first. ${LINEAR}\n\n` +
    `Game v${build.version} (${build.head}). Say in each issue which player found it and on which model.\n\nThe findings (JSON):\n${JSON.stringify(held, null, 1)}`,
    { label: 'file in Linear', phase: 'File', schema: FILED, model: 'sonnet' },
  )
  filed = out ? out.issues : []
}

// -------------------------------------------------------------- Lessons
phase('Lessons')
const stats = reports.map((r) => {
  const mine = (list) => list.filter((f) => (f.players || []).includes(r.label)).length
  return {
    session: r.label, looks: r.looks, reached: r.reached, sent: r.findings.length,
    held: mine(held), dropped: mine([...merged.dropped, ...replayDrops]),
  }
})
const LESSONS = {
  type: 'object',
  properties: {
    entry: { type: 'string', description: 'the run\'s entry for lessons.md, in its format' },
    changes: {
      type: 'array',
      items: {
        type: 'object',
        properties: { file: { type: 'string' }, change: { type: 'string' }, why: { type: 'string' } },
        required: ['file', 'change', 'why'],
      },
      description: 'rule changes to SKILL.md, a player page, triage.md, or the models in the workflow',
    },
  },
  required: ['entry', 'changes'],
}
const lessons = await agent(
  `You are the orchestrator of Pixelheim's playtests. Read ${SKILL}/SKILL.md, the players' pages, triage.md and lessons.md, then this run's results, ` +
  `and say what it taught: an entry for lessons.md in its format, and the rule changes it calls for. Look for: findings dropped as false alarms ` +
  `(which rule would have stopped them), players who got stuck or wasted looks (on the rules or the tool), checklist items nobody reached, ` +
  `and${compare ? ` the comparison of ${compare} on both models (findings held, false alarms, looks used): which model should it run on, and the other mechanical players?` : ' whether each player\'s model fits.'} ` +
  `Change nothing yourself: the main session applies them.\n\n` +
  `Per session: ${JSON.stringify(stats)}\n\nPlayers' summaries:\n${reports.map((r) => `- ${r.label}: ${r.summary}`).join('\n')}\n\n` +
  `Held: ${JSON.stringify(held.map((f) => ({ title: f.title, kind: f.kind, severity: f.severity, players: f.players, note: f.note })))}\n\n` +
  `Dropped: ${JSON.stringify([...merged.dropped, ...replayDrops])}`,
  { label: 'lessons', phase: 'Lessons', schema: LESSONS },
)

return { run: a.run, version: build.version, head: build.head, stats, filed, held: held.length, dropped: [...merged.dropped, ...replayDrops], lessons }
