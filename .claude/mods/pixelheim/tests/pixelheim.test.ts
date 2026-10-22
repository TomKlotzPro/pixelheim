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
}

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

test('commits and PRs carry no attribution lines', async ($, on) => {
  world(on, 5)
  await start($)
  expect((await $.attribution.text({ kind: 'commit', text: 'Co-Authored-By: Claude' })).text).toBe('')
  expect((await $.attribution.text({ kind: 'pr', text: 'Generated with Claude Code' })).text).toBe('')
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
  const ui = await $.ui.mount({
    plugin: 'pixelheim',
    component: 'AbovePrompt',
    surface: 'terminal',
    props: { hasSurvey: false, isWorking: false, maxRows: 4, bodyColumns: 100, scroll: { offset: 0, bodyRows: 4 }, view: {} },
    viewport: { columns: 120, rows: 40, isFullscreen: false },
  })
  expect(await ui.find({ type: 'Text', text: /v0\.271 · week 7% of 12% cap/ })).toBeDefined()
  await ui.unmount()
})
