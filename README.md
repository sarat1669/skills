# skills

Agent skills in the [Agent Skills](https://agentskills.io) format. They work with Claude Code, Codex, Cursor and other
agents that support `SKILL.md`, and are listed on [skills.sh](https://skills.sh).

```bash
npx skills add sarat1669/skills
```

## codebase-dojo

Onboards a developer onto an unfamiliar codebase by having them make small, real changes **by hand** while the agent
navigates. The agent never writes the code.

1. **Recon:** a read-only survey maps the stack, commands, CI, tests, entry points, churn hotspots, and anything
   with real side effects (network, processes, payments, orders, deploys). The agent then traces one real feature
   end to end.
2. **Route:** it plans 4 to 12 short missions along that feature, from the outside in: get it running, change
   something visible, follow the request, change a rule, add a field end to end, write a test, run what CI runs, and
   finish with a small capstone feature. Pointers get vaguer as the developer progresses.
3. **Missions:** each has a brief (why it matters, the task, how to tell it's done, where to start). Hints come
   one rung at a time, from a nudge up to pairing. The agent checks each change with `git diff` and the repo's own
   tests or build, then reviews it and asks one question to check understanding.
4. **Wrap-up:** a take-home map of the codebase, a real first PR drawn from the doc gaps they hit, and next tasks.

Progress is saved in `.onboarding/`, which is ignored only in their clone, so a long route can resume in a later
session.

```bash
npx skills add sarat1669/skills --skill codebase-dojo
```

Then, in the repo you're new to, ask your agent to "onboard me" or "walk me through this codebase hands-on".

| Path | What it holds |
|---|---|
| [`SKILL.md`](skills/codebase-dojo/SKILL.md) | The workflow and its rules |
| [`scripts/recon.sh`](skills/codebase-dojo/scripts/recon.sh) | Read-only repo survey (bash; GNU and BSD/macOS userlands) |
| [`references/touchpoints.md`](skills/codebase-dojo/references/touchpoints.md) | Where things live per stack, and how to rank and trace touchpoints |
| [`references/missions.md`](skills/codebase-dojo/references/missions.md) | 13 mission archetypes, a worked route, example briefs |
| [`assets/`](skills/codebase-dojo/assets) | Templates for the progress file and the codebase map |
