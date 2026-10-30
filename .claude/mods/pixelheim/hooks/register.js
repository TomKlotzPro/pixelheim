// Pixelheim's mod: a band above the prompt, Tom's weekly usage cap, and his house rules.
// Load it with: claude --plugin-dir .claude/mods/pixelheim

const CAP = 12
const LIVE = ['pending', 'running', 'waiting']
// The harness's --slot writes real saves; only a godot run is refused, not a grep for the word.
const SLOT_RUN = /(^|[\s;&|(])godot\s[^;&|]*--slot\b/
// A windowed run comes up on top of Tom's screen (PIX-407): a godot started as
// a command without --headless, or the windowed flows and the look book.
// Pictures go through godot/tools/shot.sh, which opens in the background.
const WINDOWED_RUN = /(^|[;&|(\n]\s*)godot\s(?![^;&|\n]*--headless)[^;&|\n]*--path\b/
const WINDOWED_TOOL = /(^|[;&|(\n]\s*)(\S*\/)?(flows\.sh(?![^;&|\n]*--(quiet|list|boot)\b)|lookbook\.sh)/
const PANE = 'pixelheim'

// The game's HUD colours (ui_style.gd), lifted a little for a dark terminal.
const GOLD = '#f2c14e'
const CREAM = '#f3e6c4'
const WOOD = '#b47c44'
const FADED = '#7d5f3e'
const PV = '#e05a47'
const EN = '#7cc464'

// The red warrior's first frame, puny/characters/Warrior-Red.png (Shade, CC0).
const HERO_COLOURS = {
  a: 0x000000, b: 0xff1515, c: 0x363636, d: 0x4d4c4b, e: 0x7d7b76, f: 0xae0000, g: 0x290505, h: 0x1e1e1e,
  i: 0xa29e96, j: 0x520c0c, k: 0xbebbb5, l: 0xe8e8e8, m: 0x040404, n: 0xf6a954, o: 0x84482a, p: 0xd97f40, q: 0x3f3013,
}
const HERO = [
  'aa..aaaaaa..aa',
  'abaacdeedcaaba',
  'afghddiiddhgfa',
  'ajfccdiidccfja',
  '.ajdcceeccdja.',
  '.adeiikkiieda.',
  '.ahiikkkkiiha.',
  '..adccddccda..',
  '..aelmeemlea..',
  '..mcddnnddcm..',
  '.meecooooceem.',
  'mnnmdeeeedmnnm',
  'mnpmddddddmpnm',
  '.mmmcddddcmmm.',
  '...mqqmmqqm...',
]
const DEFAULT = 0x01000000

// Two pixels a cell: the upper half block takes the top pixel as its colour and the bottom one as its background.
function heroCells() {
  const at = (x, y) => HERO_COLOURS[HERO[y]?.[x]] ?? DEFAULT
  const cells = []
  for (let y = 0; y < HERO.length; y += 2) {
    for (let x = 0; x < HERO[0].length; x += 1) {
      const top = at(x, y)
      const bottom = at(x, y + 1)
      if (top === DEFAULT && bottom === DEFAULT) cells.push(32, DEFAULT, DEFAULT)
      else if (top === DEFAULT) cells.push(0x2584, bottom, DEFAULT)
      else cells.push(0x2580, top, bottom)
    }
  }
  return new Uint8Array(Uint32Array.from(cells).buffer).toBase64()
}

function bar(fraction, cells) {
  const full = Math.round(Math.min(1, Math.max(0, fraction)) * cells)
  return '▰'.repeat(full) + '▱'.repeat(cells - full)
}

let version = ''
let week
let fiveHour
let cap = CAP
let agents = 0

async function refresh($) {
  const u = await $.session.usage()
  week = u.rateLimits.find(r => r.kind === 'seven_day')?.percentUsed
  fiveHour = u.rateLimits.find(r => r.kind === 'five_hour')?.percentUsed
  agents = (await $.agent.list()).filter(a => LIVE.includes(a.status)).length
  try {
    version = (await $.fs.read('README.md')).match(/Currently (v[\d.]+)/)?.[1] ?? ''
  } catch {
    version = ''
  }
  $.ui.invalidate('ui.render')
}

function pct(n) {
  return n === undefined ? '?' : Math.round(n) + '%'
}

function level() {
  return 'Niv. ' + (version.split('.')[1] ?? '?')
}

// The week's budget is the hero's PV (what's left of the cap), the five-hour window his EN.
function gauges(Text) {
  const left = week === undefined ? undefined : Math.max(0, cap - week)
  const pv =
    left === undefined
      ? [Text({ color: FADED, children: ['PV ?'] })]
      : [
          Text({ color: WOOD, children: ['PV'] }),
          Text({ color: PV, children: [bar(left / cap, 10)] }),
          Text({ color: left > 0 ? CREAM : PV, children: [left > 0 ? Math.round(left) + '/' + cap : 'K.O.'] }),
        ]
  const en =
    fiveHour === undefined
      ? [Text({ color: FADED, children: ['EN ?'] })]
      : [
          Text({ color: WOOD, children: ['EN'] }),
          Text({ color: EN, children: [bar(1 - fiveHour / 100, 10)] }),
          Text({ color: CREAM, children: [Math.round(100 - fiveHour) + '%'] }),
        ]
  return { pv, en }
}

// The checks main requires (the required-checks ruleset) plus the windowed shares behind `pictures`.
const CHECKS = 8
const DONE = ['SUCCESS', 'FAILURE', 'CANCELLED', 'SKIPPED', 'TIMED_OUT', 'NEUTRAL', 'ACTION_REQUIRED', 'STARTUP_FAILURE', 'STALE']

async function pullRequest($, pr) {
  const r = await $.process.run(['gh', 'pr', 'view', String(pr), '--json', 'headRefOid,state,statusCheckRollup'])
  if (r.exitCode !== 0) throw new Error(r.stderr.trim() || 'gh pr view failed')
  const j = JSON.parse(r.stdout)
  return {
    head: j.headRefOid.slice(0, 8),
    state: j.state,
    checks: j.statusCheckRollup.map(c => ({ name: c.name, state: c.conclusion || c.status })),
  }
}

function verdict(info) {
  const waiting = info.checks.filter(c => !DONE.includes(c.state)).map(c => c.name)
  const red = info.checks.filter(c => DONE.includes(c.state) && c.state !== 'SUCCESS').map(c => c.name + ' ' + c.state)
  const green = info.checks.length >= CHECKS && waiting.length === 0 && red.length === 0
  const line = '#' + info.pr + ' ' + info.state + ' head ' + info.head + ': ' +
    info.checks.filter(c => c.state === 'SUCCESS').length + '/' + info.checks.length + ' green' +
    (waiting.length ? ' · waiting: ' + waiting.join(', ') : '') + (red.length ? ' · red: ' + red.join(', ') : '') +
    (info.checks.length < CHECKS ? ' · only ' + info.checks.length + ' of ' + CHECKS + ' checks reported' : '')
  return { green, line }
}

// Merges only when every check is green, then fast-forwards the main checkout (not a worktree).
async function ship($, pr) {
  const info = { pr, ...(await pullRequest($, pr)) }
  const v = verdict(info)
  if (info.state !== 'OPEN') return v.line + ' - not open, nothing merged'
  if (!v.green) return v.line + ' - not merged'
  const m = await $.process.run(['gh', 'pr', 'merge', String(pr), '--merge'])
  if (m.exitCode !== 0) return v.line + ' - merge refused: ' + m.stderr.trim()
  const common = await $.process.run(['git', 'rev-parse', '--path-format=absolute', '--git-common-dir'])
  const main = common.stdout.trim().replace(/\/\.git$/, '')
  await $.process.run(['git', '-C', main, 'fetch', '-q', 'origin'])
  const ff = await $.process.run(['git', '-C', main, 'merge', '--ff-only', '-q', 'origin/main'])
  const head = await $.process.run(['git', '-C', main, 'log', '--oneline', '-1'])
  return v.line + ' - merged; main checkout ' + (ff.exitCode === 0 ? 'at ' + head.stdout.trim() : 'NOT fast-forwarded: ' + ff.stderr.trim())
}

function summary() {
  return [
    'Pixelheim ' + (version || '?'),
    'week ' + pct(week) + ' of ' + cap + '% cap',
    '5h ' + pct(fiveHour),
    agents + (agents === 1 ? ' agent' : ' agents'),
  ].join(' · ')
}

export function register(on) {
  on('session.start', async ($, e, next) => {
    const saved = await $.store.get('cap')
    if (typeof saved === 'number') cap = saved
    await refresh($).catch(() => undefined)
    $.clock.every(60_000, () => refresh($).catch(() => undefined))
    await $.tool.register({
      name: 'usage',
      description: "Tom's plan usage this week and in the last five hours, against his weekly Pixelheim cap. Check it before spawning agents.",
      inputSchema: { type: 'object', properties: {} },
      isDeferred: false,
    })
    const prArg = { type: 'object', properties: { pr: { type: 'integer', description: 'the pull request number' } }, required: ['pr'] }
    await $.tool.register({
      name: 'pr_status',
      description: "A Pixelheim pull request's CI in one line: head, how many checks are green, which are waiting or red.",
      inputSchema: prArg,
    })
    await $.tool.register({
      name: 'ship',
      description: "Merge a Pixelheim pull request only if all its checks are green, then fast-forward the main checkout. Refuses otherwise and says why. Use this instead of gh pr merge.",
      inputSchema: prArg,
    })
    await $.command.register({
      name: 'pix',
      description: 'Pixelheim at a glance; /pix cap 20 sets the weekly usage cap',
      argumentHint: '[cap <percent>]',
      immediate: true,
    })
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    await refresh($).catch(() => undefined)
    return next(e)
  })

  on('command.run', { command: 'pix' }, async ($, e) => {
    const m = e.args.trim().match(/^cap\s+(\d+(?:\.\d+)?)%?$/)
    if (m) {
      cap = Number(m[1])
      await $.store.set('cap', cap)
    }
    await refresh($).catch(() => undefined)
    await $.ui.open({ id: PANE, title: 'Pixelheim', closeOnEscape: true })
    return { text: summary() }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Raster } = $.ui.resolve(e)
    const { pv, en } = gauges(Text)
    const sheet = Box({
      flexDirection: 'column',
      children: [
        Text({ color: GOLD, weight: 'semibold', children: ['Pixelheim ' + version] }),
        Text({ color: CREAM, children: [level() + ' · Fantassin'] }),
        Box({ flexDirection: 'row', columnGap: 1, children: pv }),
        Box({ flexDirection: 'row', columnGap: 1, children: en }),
        Text({ color: agents ? GOLD : FADED, children: ['⚔ ' + agents + (agents === 1 ? ' compagnon en route' : ' compagnons en route')] }),
        Text({ color: FADED, children: ['semaine ' + pct(week) + ' · plafond ' + cap + '% · /pix cap N'] }),
      ],
    })
    if (e.surface !== 'terminal' || !Raster) return sheet
    const hero = Raster({ key: 'hero', columns: HERO[0].length, rows: Math.ceil(HERO.length / 2), cells: heroCells() })
    return Box({ flexDirection: 'row', columnGap: 2, children: [hero, sheet] })
  })

  on('tool.call', { tool: 'mcp__pixelheim__pr_status' }, async ($, e) => {
    try {
      return { result: verdict({ pr: e.pr, ...(await pullRequest($, e.pr)) }).line }
    } catch (err) {
      return { result: 'pr_status failed: ' + String(err?.message ?? err) }
    }
  })

  on('tool.call', { tool: 'mcp__pixelheim__ship' }, async ($, e) => {
    try {
      return { result: await ship($, e.pr) }
    } catch (err) {
      return { result: 'ship failed, nothing merged: ' + String(err?.message ?? err) }
    }
  })

  on('tool.call', { tool: 'mcp__pixelheim__usage' }, async ($) => {
    await refresh($).catch(() => undefined)
    return { result: summary() + (week !== undefined && week >= cap ? ' - over the cap: ask Tom before more work.' : '') }
  })


  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    if (SLOT_RUN.test(e.command)) return { deny: 'Never pass --slot to the game: it writes real saves. Use the harness without it.' }
    if (WINDOWED_RUN.test(e.command) || WINDOWED_TOOL.test(e.command)) {
      return { deny: "A windowed game run comes up on top of Tom's screen. Take pictures with godot/tools/shot.sh (in the background, never in front), run flows with --quiet, and leave the windowed flows and the look book to CI." }
    }
    return next(e)
  }).catch(($, e, next) => next(e))

  on('agent.spawn', async ($, e, next) => {
    if (week !== undefined && week >= cap) {
      return { deny: 'Weekly usage is at ' + pct(week) + ", at or past Tom's " + cap + '% cap: ask Tom before starting another agent.' }
    }
    return next(e)
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const { Box, Text } = $.ui.resolve(e)
    const { pv, en } = gauges(Text)
    const line = Box({
      flexDirection: 'row',
      columnGap: 1,
      children: [
        Text({ color: GOLD, children: ['✦ Pixelheim'] }),
        Text({ color: CREAM, children: [level()] }),
        Text({ color: FADED, children: ['│'] }),
        ...pv,
        Text({ color: FADED, children: ['│'] }),
        ...en,
        Text({ color: FADED, children: ['│'] }),
        Text({ color: agents ? GOLD : FADED, children: ['⚔ ' + agents] }),
      ],
    })
    const theirs = await next(e)
    return Box({ flexDirection: 'column', children: [line, ...(theirs ? [theirs] : [])] })
  })
}
