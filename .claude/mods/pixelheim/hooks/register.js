// Pixelheim's mod: a band above the prompt, Tom's weekly usage cap, and his house rules.
// Load it with: claude --plugin-dir .claude/mods/pixelheim

const CAP = 12
const LIVE = ['pending', 'running', 'waiting']
// The harness's --slot writes real saves; only a godot run is refused, not a grep for the word.
const SLOT_RUN = /(^|[\s;&|(])godot\s[^;&|]*--slot\b/

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
    return { text: summary() }
  })

  on('tool.call', { tool: 'mcp__pixelheim__usage' }, async ($) => {
    await refresh($).catch(() => undefined)
    return { result: summary() + (week !== undefined && week >= cap ? ' - over the cap: ask Tom before more work.' : '') }
  })

  // Tom is the sole author: no Co-Authored-By trailer, no "Generated with" footer.
  on('attribution.text', { kind: ['commit', 'pr'] }, async () => ({ text: '' }))

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    if (SLOT_RUN.test(e.command)) return { deny: 'Never pass --slot to the game: it writes real saves. Use the harness without it.' }
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
    const color = week === undefined ? 'gray' : week >= cap ? 'red' : week >= cap * 0.8 ? 'yellow' : 'green'
    const theirs = await next(e)
    return Box({
      flexDirection: 'column',
      children: [
        Text({ color, wrap: 'truncate-end', children: ['◆ ' + summary()] }),
        ...(theirs ? [theirs] : []),
      ],
    })
  })
}
