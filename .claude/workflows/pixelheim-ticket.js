export const meta = {
  name: 'pixelheim-ticket',
  description: 'Take one Pixelheim Linear ticket to a pushed PR: implement, then an independent review and up to two fix rounds for art and feature tickets',
  whenToUse: 'One Pixelheim ticket with a written brief. args: {ticket, brief, branch, prTitle, kind: "art"|"feature"|"code"}. The main session still releases, ships and updates Linear.',
  phases: [
    { title: 'Implement', detail: 'one agent in its own worktree writes the change and opens the PR' },
    { title: 'Review', detail: 'an independent agent checks the PR against the ticket (art and feature tickets)' },
    { title: 'Fix', detail: 'the review findings fixed on the same branch, then reviewed again' },
  ],
}

const RULES = [
  'Load the `pixelheim-godot` skill first and follow it.',
  'Tom is the sole author: no Co-Authored-By trailer and no "Generated with" footer in commits or PR bodies.',
  'Never commit paid art (godot/assets/puny/shade, medieval, gegx, animals) or any picture made from it; copy it in from /Users/klotztom/playground/pixelheim/godot/assets/puny/ when you need it and delete it after.',
  'Quiet runs (--audio-driver Dummy); never --slot. Do not cut a release, merge or watch CI: the main session does.',
  'Do not touch repo settings or secrets; do not delete branches.',
].join('\n- ')

const PR = {
  type: 'object',
  properties: {
    pr: { type: 'integer' },
    head: { type: 'string', description: 'head SHA, 8 characters' },
    summary: { type: 'string', description: 'what changed, how it was checked, what was left' },
    shots: { type: 'string', description: 'scratch folder of before/after shots, or empty' },
  },
  required: ['pr', 'head', 'summary', 'shots'],
}

const REVIEW = {
  type: 'object',
  properties: {
    ok: { type: 'boolean', description: 'true only if nothing below needs fixing before release' },
    issues: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          what: { type: 'string' },
          where: { type: 'string', description: 'file:line, flow name or shot path' },
          fix: { type: 'string' },
        },
        required: ['what', 'where', 'fix'],
      },
    },
  },
  required: ['ok', 'issues'],
}

const a = args || {}
if (!a.ticket || !a.brief || !a.branch || !a.prTitle) throw new Error('args needs ticket, brief, branch and prTitle')
const reviewed = a.kind === 'art' || a.kind === 'feature'

phase('Implement')
const built = await agent(
  `${a.ticket} for Pixelheim (Godot 4.7, game under godot/). Start from an up-to-date origin/main.\n\n${a.brief}\n\n` +
  `Commit on branch \`${a.branch}\`, push, and open a PR titled "${a.prTitle}". Rules:\n- ${RULES}`,
  { label: `implement ${a.ticket}`, phase: 'Implement', isolation: 'worktree', schema: PR },
)
if (!built) return { ticket: a.ticket, error: 'the implement agent returned nothing' }
log(`${a.ticket}: PR #${built.pr} at ${built.head}`)
if (!reviewed) return { ticket: a.ticket, ...built, review: 'skipped (code ticket)' }

let review = null
let head = built.head
for (let round = 1; round <= 3; round++) {
  review = await agent(
    `Review PR #${built.pr} (branch \`${a.branch}\`, head ${head}) of Pixelheim against its ticket, independently: you did not write it. ` +
    `Check it out in your worktree (git fetch origin && git switch ${a.branch}). Change nothing.\n\nThe ticket's brief:\n${a.brief}\n\n` +
    `The author's summary: ${built.summary}\nTheir shots: ${built.shots || 'none'}\n\nCheck each of these and report only real problems:\n` +
    `- does it do every point of the brief, and nothing the brief did not ask?\n` +
    `- player-facing text: French in fr.po in the game's voice (la Marche, Fernoir, la Porte-Givre, les Bois-Profonds; U+202F before : ; ! ?), English plain; i18n.py --check\n` +
    `- art and layout: look at every shot yourself; anything overlapping, cut off, untranslated, off-palette or unreadable; for art, the AI-made UI kit may only be in menus, never the world\n` +
    `- no paid art or pictures of it in the diff (git diff --stat origin/main...HEAD)\n` +
    `- tests: is new logic covered, and do the flows the change touches pass (run the relevant ones headless)?\n` +
    `- budgets: decor nodes, night lights, cpu= flows, if the change adds drawing\n` +
    `Set ok=false only for things that must be fixed before release; list nits as issues with ok=true.`,
    { label: `review ${a.ticket} #${round}`, phase: 'Review', isolation: 'worktree', schema: REVIEW },
  )
  if (!review || review.ok || round === 3) break
  log(`${a.ticket}: review round ${round} found ${review.issues.length} to fix`)
  const fixed = await agent(
    `Fix the review findings on Pixelheim PR #${built.pr} (branch \`${a.branch}\`). Check the branch out in your worktree ` +
    `(git fetch origin && git switch ${a.branch}), fix each finding at its root, rerun the checks it touches, commit and push to the same branch.\n\n` +
    `Findings:\n${review.issues.map((i, n) => `${n + 1}. ${i.what} (${i.where}): ${i.fix}`).join('\n')}\n\nThe ticket's brief, for context:\n${a.brief}\n\nRules:\n- ${RULES}`,
    { label: `fix ${a.ticket} #${round}`, phase: 'Fix', isolation: 'worktree', schema: PR },
  )
  if (!fixed) break
  head = fixed.head
}
return { ticket: a.ticket, pr: built.pr, head, summary: built.summary, shots: built.shots, review }
