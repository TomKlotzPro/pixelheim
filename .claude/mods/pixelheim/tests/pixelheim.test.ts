import { expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

const world = (on: On, week: number) => {
  mock.clock(on, { now: 1_000_000 })
  mock.store(on)
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('session.usage', () => ({
    value: {
      startedAt: 0,
      context: { window: 1_000_000, percent: 10 },
      rateLimits: [
        { kind: 'seven_day', percentUsed: week },
        { kind: 'five_hour', percentUsed: 30 },
      ],
    },
  }))
  on('agent.list', () => ({ value: [{ id: 'a1', status: 'running' }] }))
  on('fs.read', () => ({ value: 'The village burned. You stayed. Currently v0.271 - 1.0 has to be earned.' }))
  on('command.register', ($, e) => ({ value: { command: e.name } }))
  on('tool.register', () => ({ value: undefined }))
  on('tool.call', () => ({ result: 'ran' }))
  on('agent.spawn', () => ({ model: 'inherit' }))
  on('ui.open', () => ({ value: { isPlaced: true as const } }))
}

const BAND = {
  plugin: 'pixelheim',
  component: 'AbovePrompt',
  props: { hasSurvey: false, isWorking: false, maxRows: 4, bodyColumns: 100, scroll: { offset: 0, bodyRows: 4 }, view: {} },
  viewport: { columns: 120, rows: 40, isFullscreen: false },
} as const

const start = ($: Parameters<Parameters<typeof test>[1]>[0]) =>
  $.session.start({ cwd: '/repo', surface: 'terminal', isInteractive: true })

test('/pix sums up the version, the week against the cap and the agents', async ($, on) => {
  world(on, 7)
  await start($)
  const answer = await $.command.run({ command: 'pix', args: '' })
  expect(answer.text).toBe('Pixelheim v0.271 · week 7% of 12% cap · 5h 30% · 1 agent')
  const raised = await $.command.run({ command: 'pix', args: 'cap 20' })
  expect(raised.text).toContain('week 7% of 20% cap')
})

test('no agent starts at or past the cap', async ($, on) => {
  world(on, 12)
  await start($)
  const spawn = await $.agent.spawn({ prompt: 'fix it', description: 'fix', subagentType: 'general-purpose' })
  expect(spawn.deny).toContain('12% cap')
})

test('agents start under the cap', async ($, on) => {
  world(on, 5)
  await start($)
  const spawn = await $.agent.spawn({ prompt: 'fix it', description: 'fix', subagentType: 'general-purpose' })
  expect(spawn.deny).toBeUndefined()
})

test('a godot run with --slot is refused, a search for the word is not', async ($, on) => {
  world(on, 5)
  await start($)
  const run = await $.tool.call({ tool: 'Bash', command: 'godot --headless --path . -- --screenshot --slot 1' })
  expect(run.deny).toContain('--slot')
  const grep = await $.tool.call({ tool: 'Bash', command: 'grep -rn -- "--slot" godot/scripts' })
  expect(grep.deny).toBeUndefined()
})

test('Claude can read the usage', async ($, on) => {
  world(on, 13)
  await start($)
  const r = await $.tool.call({ tool: 'mcp__pixelheim__usage' })
  expect(String(r.result)).toContain('over the cap')
})

test('the band above the prompt shows the summary', async ($, on) => {
  world(on, 7)
  on('ui.render', { component: 'AbovePrompt' }, ($, e) => $.ui.resolve(e).Box({ children: [] }))
  await start($)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /Niv\. 271/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^5\/12$/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^70%$/ })).toBeDefined()
  await ui.unmount()
})

test('past the cap the band reads K.O.', async ($, on) => {
  world(on, 20)
  on('ui.render', { component: 'AbovePrompt' }, ($, e) => $.ui.resolve(e).Box({ children: [] }))
  await start($)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /K\.O\./ })).toBeDefined()
  await ui.unmount()
})

test('/pix opens a pane with the hero drawn in the terminal', async ($, on) => {
  world(on, 7)
  await start($)
  await $.command.run({ command: 'pix', args: '' })
  const pane = {
    plugin: 'pixelheim',
    component: 'Pane',
    requestId: 'pixelheim',
    props: { title: 'Pixelheim', isFocused: false, bodyColumns: 60, placement: 'inline', scroll: { offset: 0, bodyRows: 10 }, view: {} },
    viewport: { columns: 120, rows: 40, isFullscreen: false },
  } as const
  const ui = await $.ui.mount({ ...pane, surface: 'terminal' })
  expect(await ui.find({ key: 'hero' })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /compagnon en route/ })).toBeDefined()
  await ui.unmount()
})

const pr = (checks: [string, string][]) => ({
  exitCode: 0,
  stdout: JSON.stringify({
    headRefOid: 'abcdef1234',
    state: 'OPEN',
    statusCheckRollup: checks.map(([name, conclusion]) => ({ name, conclusion, status: 'COMPLETED' })),
  }),
  stderr: '',
})
const EIGHT = ['desktop', 'godot', 'windowed (1)', 'windowed (2)', 'windowed (3)', 'windowed (4)', 'windowed (look)', 'pictures']

const gh = (on: On, checks: [string, string][]) => {
  const ran: string[] = []
  on('process.run', ($, e) => {
    ran.push(e.argv.join(' '))
    if (e.argv[1] === 'pr' && e.argv[2] === 'view') return { value: pr(checks) }
    if (e.argv[0] === 'git' && e.argv[1] === 'rev-parse') return { value: { exitCode: 0, stdout: '/repo/.git\n', stderr: '' } }
    return { value: { exitCode: 0, stdout: 'abc1234 Merge pull request\n', stderr: '' } }
  })
  return ran
}

test('ship refuses a pull request with a red check', async ($, on) => {
  world(on, 5)
  const ran = gh(on, EIGHT.map(n => [n, n === 'pictures' ? 'FAILURE' : 'SUCCESS']))
  await start($)
  const r = await $.tool.call({ tool: 'mcp__pixelheim__ship', pr: 427 })
  expect(String(r.result)).toContain('red: pictures FAILURE')
  expect(String(r.result)).toContain('not merged')
  expect(ran.some(c => c.startsWith('gh pr merge'))).toBe(false)
})

test('ship merges when all eight are green and fast-forwards the main checkout', async ($, on) => {
  world(on, 5)
  const ran = gh(on, EIGHT.map(n => [n, 'SUCCESS']))
  await start($)
  const r = await $.tool.call({ tool: 'mcp__pixelheim__ship', pr: 436 })
  expect(String(r.result)).toContain('8/8 green')
  expect(String(r.result)).toContain('merged; main checkout at abc1234')
  expect(ran).toContain('gh pr merge 436 --merge')
  expect(ran).toContain('git -C /repo merge --ff-only -q origin/main')
})

test('pr_status says which checks are still running', async ($, on) => {
  world(on, 5)
  gh(on, [['desktop', 'SUCCESS'], ['godot', 'IN_PROGRESS']])
  await start($)
  const r = await $.tool.call({ tool: 'mcp__pixelheim__pr_status', pr: 437 })
  expect(String(r.result)).toContain('waiting: godot')
  expect(String(r.result)).toContain('only 2 of 8 checks reported')
})
