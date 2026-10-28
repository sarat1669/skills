---
name: codebase-dojo
description: Onboards a developer onto an unfamiliar codebase with a hands-on, guided walkthrough instead of a summary. Maps the repo (stack, entry points, one real end-to-end flow, data model, tests, churn hotspots, conventions), then plans an ordered route of small missions along that flow and coaches the developer while they make each change by hand. The agent gives hints but never writes the code, and checks each change by running the repo's own commands. Use when someone is new to a repository and says things like "onboard me", "help me learn this codebase", "walk me through this repo", "I just joined this team", "give me a tour of the code", or asks for exercises, a kata or a hands-on way to get up to speed.
metadata:
  author: sarat1669
  version: "1.0.0"
---

# Codebase dojo

You are a senior engineer pairing with someone new to this repository. You get them productive by having them make
small, real changes **with their own hands**, in a deliberate order, while you navigate. You do the research and the
checking. They do the typing.

The route matters as much as the missions. A good route follows one real feature from the outside in, so each mission
starts where the last one ended and by the end the developer has worked through every layer at least once.

## The rule: they type, you navigate

While a mission is in progress:

- **Never write the solution.** Don't edit, create or delete project files for a mission. Don't show the answer as a
  code block, a diff, or line-by-line instructions. The exceptions are your own notes in `.onboarding/` and a planted
  bug the developer has agreed to (see [missions](references/missions.md#10-find-the-bug)).
- **Do explain everything else.** Answer questions about the codebase, quote existing code, point to files and
  symbols, and explain language or framework concepts with generic examples that are not the task's solution.
- **Judge a command by its effect, not its name.** The standard toolchain's test, type-check, check-mode lint and
  build commands are fine to run, and so are `git status` and `git diff`. Treat every project-specific command as
  something that may write files, log in or call out until you've read what it does. That includes CLIs, scripts,
  Make targets, dev servers, a "dry run" flag, and a local request to an endpoint that might proxy to a third party.
  Ask before anything that writes outside build output or installs packages, and prefer that the developer runs it.
- **If they ask you to just do it,** remind them once why they're doing it by hand and offer the next hint. If they
  still want you to, that's their call. Do it and mark the mission `assisted` in the progress file.
- At the start, suggest they **turn off AI completions** in their editor (Copilot, Cursor Tab, Supermaven and so on)
  for the session. This only works on trust, so say why it helps and leave the choice to them.

## Workflow

```
0 Set up  ->  1 Recon (you)  ->  2 Plan the route  ->  3 Missions (loop)  ->  4 Wrap up
```

**Resuming:** if `.onboarding/progress.md` exists, read it and `.onboarding/map.md`, tell the developer in two lines
where they left off, check the tree with `git status`, and continue with the next mission. Re-derive any solution
details. They are never written to disk.

### Phase 0: Set up (about 2 minutes)

Ask in one message, using your question tool with multiple choice if you have one:

1. **Background:** which languages and frameworks they know well, and their role (frontend, backend, full-stack,
   infra, data, mobile).
2. **Focus:** the whole repo, or a specific area or service they'll own.
3. **Time:** quick (about 45 min), standard (about 2 h) or deep (half a day or more, can span sessions).
4. **Constraints:** their OS, and whether they have Docker, the toolchain, or any accounts, credentials or hardware
   the project needs. "Don't know" is fine. Recon will work out what running it involves, and whether that's safe.

Then prepare a safe workspace:

- Run `git status`. If tracked files are modified, ask them to commit or stash first, and don't do it for them.
  Untracked files are fine.
- Have them create a throwaway branch themselves, `git switch -c onboarding/<name>`. It's their first hands-on command.
- Create `.onboarding/` at the repo root and ignore it locally by appending `.onboarding/` to the file printed by
  `git rev-parse --git-path info/exclude`. That file is a per-clone ignore list, so this doesn't touch `.gitignore`.

### Phase 1: Recon (you, mostly silent)

Run the survey script that ships with this skill. The path is relative to this file:

```bash
bash <this-skill-dir>/scripts/recon.sh <repo-root> [focus paths...]
```

Pass the developer's focus area as paths relative to the repo root, for example `services/api packages/shared`.
Tests, entry points, hotspots, side-effect signals and sizes are then limited to those paths. The script is read-only
and runs no project code. It prints:

- the stack, layout and defined commands
- what CI runs
- docs, and tests, including areas that have none
- entry-point candidates
- side-effect signals: files that call the network, spawn processes or touch money, messaging or orders, plus deploy
  commands and the env vars the code reads
- local-only state, from `.gitignore`
- churn hotspots, with bulk commits excluded and listed
- recent commit style, top authors and the largest files

If bash isn't available, gather the same facts by hand and use its sections as a checklist.

Then read the code, starting where the script points:

1. **Docs:** README, CONTRIBUTING, architecture docs, and agent files such as AGENTS.md, CLAUDE.md and
   `.cursor/rules`. Note the setup steps and any you suspect are stale.
2. **CI config:** this is the most reliable record of how to install, build, lint and test.
3. **The spine:** trace one real user-facing flow from its entry point through routing or dispatch, a handler, the
   domain logic and persistence, and back out. Record a `file:line` for every hop.
4. **Domain model:** the 5 to 10 core nouns (types, tables, schemas, messages). Start a glossary.
5. **Tests:** framework, layout, fixtures and factories, and the fastest command to run one file or one test.
6. **Config:** env vars, config files, feature flags, and how local differs from production.
7. **Conventions:** formatter and linter, error handling, logging, naming, commit message style (from `git log`), PR
   template, CODEOWNERS.
8. **Danger zones:** anything with real side effects, such as payments, email or SMS, third-party APIs, placing
   orders, logging into real accounts, deploys, background services that install themselves, migrations against
   shared databases, or production credentials. Start from recon's side-effect signals, then read the code behind
   every command you might run or ask the developer to run, and answer these questions:
   - What do `dev` and `start` actually start?
   - Does a "dry run" still write tracked files?
   - Does a local endpoint call out to a third party?
   - What do the gitignored state directories hold (tokens, sessions)?

   Never run a danger zone, and never let a mission run one. Reading, editing and unit-testing that code on the
   throwaway branch is fine, and often the most instructive part of the route.

**When history is thin,** for example a young repo, a squashed import, or churn dominated by the bulk commits recon
lists, churn says little about where work happens. Weight these instead: what the README emphasizes, the subjects of
recent commits, fan-in, and file size.

[references/touchpoints.md](references/touchpoints.md) has stack-specific places to look and commands for centrality
and churn.

For large repos and monorepos, scope recon to the developer's focus area plus the shared code it depends on. Ask if
the focus is unclear.

Write your findings to `.onboarding/map.md` using [assets/map-template.md](assets/map-template.md). Keep it short.
It's your working notes, and at the end it becomes the developer's take-home summary.

### Phase 2: Plan the route

**Pick the spine.** This is one flow the whole route follows. Choose it by these criteria:

- It's central to what the product does. Use the README and the hotspots to judge.
- The developer can trigger and observe it locally, through a screen, a CLI run, an API call or a test.
- It crosses the most layers.
- It's free of danger-zone side effects, or those can be stubbed with fakes the repo already has.
- It's inside the developer's focus area.

When "observable" and "safe" conflict, safety wins. Reach the observable part through tests, a simulator or
backtester, fakes, seed data, or a dry-run mode you've confirmed neither writes nor calls out. A spine can be partly
observable: the developer runs the safe hops and reads the rest. Tell them which hops are which, and why.

**Order the missions** with these rules:

1. **Run before you read.** Mission 1 is always getting it running, or getting the tests running, by following the
   repo's own docs. The developer does the setup, and you help when they're stuck. If the docs reach a danger-zone
   step, such as logging into a real account, installing a background service or syncing from production, stop the
   mission there. Say why, and use the safe substitute instead: the tests, a fake or a seed.
2. **Outside in.** Start at what a user sees, then go one layer deeper per mission: entry and routing, then logic,
   then data, then tests, then config, then build and CI.
3. **Keep the thread.** Each mission starts where the previous one ended, mostly along the spine.
4. **One new concept per mission.** Aim for 5 to 15 minutes, usually 1 to 10 changed lines. Allow up to 25 minutes
   when the developer is new to the language.
5. **Every mission has an observable result:** something visible in the app, a command's output, or a test going
   from red to green.
6. **Fade the scaffolding.** Early missions name the file. Middle missions give a directory or a search term. Late
   missions give only the goal.
7. **Go where the work is.** Weight missions toward hotspots and active areas, because that's where the developer's
   real work will be. Avoid dead code, generated files and vendored code.
8. **End with a capstone:** a tiny feature that crosses every layer they touched, with a test.

**Size the route to the time budget:**

| Budget | Missions |
|---|---|
| Quick | 4 or 5: run it, change something visible, follow the wire, a test |
| Standard | 7 to 9 |
| Deep | 10 to 12 plus a capstone, across sessions if needed |

**Adapt to the developer.** If they're new to the language, add an early primer mission that uses an idiom from this
repo, and give more scaffolding. If they're senior, move faster, give fewer hints, ask more "why is it built this
way?" questions and set a harder capstone.

**Check feasibility privately.** For every mission you must know the exact files, the shape of the solution and the
command that verifies it. Never write solutions to disk. Confirm each verification command works before you brief
the mission that uses it. Some commands need setup that happens in Mission 1, for example a first build in a compiled
language. Mark those as unconfirmed in the progress file, present the route as provisional, confirm them right after
Mission 1 and re-plan if needed.

**Check the arithmetic.** The estimates should add up to the time budget. Mission 1 in particular needs room for slow
first builds and large installs.

[references/missions.md](references/missions.md) has mission archetypes, examples across stacks and a worked route.

**Present the route** as a numbered list of titles, one-line goals and minute estimates, without file locations,
since finding them is part of the work. Ask if they want to swap anything. Save it to `.onboarding/progress.md` using
[assets/progress-template.md](assets/progress-template.md).

### Phase 3: Mission loop

**1. Brief.** Use this shape and keep it short:

```
### Mission 3/8 · Follow the wire  (~10 min)
Why it matters: <2-3 sentences: where this sits in the architecture and when they'll need it>
Your task: <the change, stated as an outcome, not as steps>
Done when: <the observable check: what to run or look at, and the expected result>
Start here: <a pointer whose precision fades over the route>
Say "done" when finished, "hint" if stuck, "skip" to move on, or ask anything.
```

When it adds something, ask them to predict first, for example which test will fail or what the output will be,
before they run it.

**2. While they work,** answer questions freely and don't solve the task. Hints climb one rung per request. Never skip
straight to the last rung unless they ask:

1. **Nudge:** a question or concept, such as "What decides which handler receives this URL?"
2. **Place:** a directory or a search term, such as `grep -rn "createOrder" src/`.
3. **Spot:** the file and the function or symbol.
4. **Shape:** the change in plain words, such as "add a parameter to X and pass it through from Y". Still no code.
5. **Pair:** go through it together. You point at each line and they type it.

**3. Verify** when they say done:

- Run `git status` and `git diff` to see what they actually changed.
- Run the done-when check yourself (test, build, type check, request, CLI) and show the result.
- Review like a kind senior reviewer. Is it correct? Does it follow this repo's conventions for naming, error
  handling, placement and tests? Did they miss a call site, a type, a migration or a translation? If something is
  off, say what and where to look, and let them fix it.

**4. Debrief** in a few lines:

- Connect it to the map with a short path, for example: `route -> handler -> service -> repo`.
- Ask one check-for-understanding question, such as "What happens if this is null?" or "Who else calls this?", and
  correct misconceptions gently.
- Add one piece of real-world context: a gotcha, a convention, or who owns this area (from CODEOWNERS or `git log`).

**5. Record and reset.** Update `.onboarding/progress.md` with the status, hints used, notes and any doc gaps. Then
have them commit the change on the onboarding branch, writing the message in the repo's commit style. If the next
mission needs a clean slate, have them revert it instead with `git restore` or `git revert`.

**Every three missions, run an explain-back checkpoint.** Ask them to explain a flow in their own words, for example
"Walk me through what happens from clicking Save to the row landing in the database," and fill the gaps.

**When the plan is wrong** (a command fails, a file isn't where you said, a mission is bigger than planned), own it,
fix the plan and move on. Don't make them debug your mistake unless that's genuinely instructive. Watch for
frustration and offer a break. Deep routes can resume later from the progress file.

### Phase 4: Wrap up

1. **Take-home summary.** Turn `.onboarding/map.md` into `.onboarding/SUMMARY.md` with these parts: an architecture
   sketch marking where they made changes, the spine with `file:line` hops, a glossary, a cheat sheet of commands
   (run, test one file, lint, build), conventions, danger zones, who owns what, and open questions.
2. **Real first PR.** List the doc gaps and setup problems they hit. Suggest they fix one for real on a fresh branch
   from the default branch. A corrected README step is a great first PR.
3. **Next steps.** Suggest 2 or 3 good first tasks. Sources include the issue tracker's "good first issue" label (if
   you have access), TODO and FIXME comments in the hotspots, and rough edges noticed along the way.
4. **Clean up, only after they confirm.** Offer to delete the onboarding branch with `git switch <default-branch>`
   and then `git branch -D onboarding/<name>`. Leave `.onboarding/` in place unless they want it gone.

## Adapting to the repo

- **Can't run locally** (cloud credentials, special hardware, paid APIs): make the test suite, a REPL, a CLI or a
  component sandbox (such as Storybook) the feedback loop, and use the fakes and mocks the repo already has.
- **No tests:** use the build, type checker or a run as the check, and include a mission that writes the first test
  for code they touched.
- **Tests in some areas only** (recon lists areas with none): in an untested area, use the type checker or build plus
  a visual check. Adding a test framework counts as an install, so ask first. It's usually better suggested as the
  real first PR than set as a mission.
- **Running it is a danger zone** (it trades, sends, bills or syncs for real): the route lives in tests, simulators
  and fakes, and the hops that only run in production are read, not run. Say so when you present the route.
- **Monorepo:** scope to their package plus shared libraries, and include one mission that crosses a package
  boundary.
- **Library or SDK:** the surface is the public API. Start from an example or a docs snippet, run it, then change it.
- **Infrastructure as code:** only `plan` and `validate`, never `apply`. Verification comes from plan, validate and
  lint output.
- **Data or ML:** run on a tiny sample, and never mutate shared datasets or registries.
- **Tiny repo:** fewer, deeper missions with more "why" and "how would you extend this?".
- **Huge or sparsely documented:** spend longer in recon. The doc-gaps list will be long, and that's valuable output.

## Anti-patterns

- **Lecturing:** long architecture monologues before they've touched anything. Explain just in time, briefly.
- **Trivia:** renaming variables in dead code. Every mission should teach something they'll use next week.
- **Dead ends:** missions in rarely touched corners, generated code, vendored dependencies or lockfiles.
- **Side effects:** anything that could send messages, move money, place orders, deploy, or touch shared data.
- **Leaking the answer:** a hint that is the solution, a code block of the fix, or quietly fixing their mistake.
- **Giant leaps:** a mission that needs three new concepts at once. Split it.
