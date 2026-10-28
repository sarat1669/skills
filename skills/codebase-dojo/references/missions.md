# Mission catalog

Archetypes to build a route from, roughly in the order they usually appear. Adapt each to the repo's spine. Don't use
all of them. Pick the ones that cover the layers this repo has, in the time the developer has.

## Contents

- [Mission anatomy](#mission-anatomy)
- [Archetypes 1 to 13](#archetypes)
- [A worked route](#a-worked-route)
- [Briefs: good and bad](#briefs-good-and-bad)
- [Check-for-understanding questions](#check-for-understanding-questions)

## Mission anatomy

Every mission needs all of these before you brief it. Keep the private parts in your head, not on disk.

| Part | Shared with the developer? |
|---|---|
| Title, why it matters, task as an outcome, done-when check, starting pointer | Yes |
| Exact files and symbols, shape of the solution, likely mistakes | No, these feed your hints and review |
| Verification command, confirmed to work | You run it, they can too |
| Layer(s) and concept it teaches | Yes, in the debrief |

## Archetypes

### 1. Get it running

- **Teaches:** setup, the toolchain, the dev loop, and whether the docs can be trusted.
- **Task:** follow the README or CONTRIBUTING guide to run the app (or the test suite) locally.
- **Done when:** the app answers on localhost, or the CLI prints its help, or the tests run, even if some fail.
- **Your role:** watch and unblock. Every place the docs were wrong or missing goes in the doc-gaps list, which feeds
  the real first PR at the end.
- **Then:** run one single test file, and find out whether code changes hot-reload. These two speed up every later
  mission.

### 2. Make a visible change

- **Teaches:** "grep for what you see", where presentation lives, and the change-reload-check loop.
- **Task:** change something a user sees on the spine's first screen: a label, an empty-state message, CLI help text
  or an API error message.
- **Done when:** they see the new text in the running app or output.
- **Pointer:** the exact text to search for. This is the only mission where the pointer is that direct.
- **Watch for:** i18n catalogs (the string lives in a translations file), snapshot tests that now fail (a good teaching
  moment: snapshot tests should be updated on purpose, not blindly), and copies in several places.

### 3. Follow the wire

- **Teaches:** the request or command lifecycle, which is the spine itself.
- **Task:** add a temporary log statement at each hop of one action (component, API call, route, handler, service,
  query), trigger the action, and read the order in which they print.
- **Done when:** the logs appear in the expected order and they can name each hop.
- **Then:** remove them, or keep one at debug level using the repo's real logger. The second option teaches logging
  conventions.
- **Variant:** use a debugger breakpoint instead of logs, if the repo has a debugger config.

### 4. Tweak a rule

- **Teaches:** where business logic lives, and that tests pin behavior.
- **Task:** change a domain rule or constant (a page size, a validation limit, a rounding rule, a retry count) and
  update the test that pins it.
- **Done when:** the behavior changed in the app and the updated test passes.
- **Watch for:** the same constant duplicated client-side and server-side, and config overriding code defaults.

### 5. Break it on purpose

- **Teaches:** the shape of the test suite, and which tests guard what.
- **Task:** predict which test(s) will fail if you invert a specific condition or remove a guard on the spine. Make the
  change, run the tests, compare with the prediction, then revert.
- **Done when:** they've explained why each failing test failed. If nothing failed, that's a finding: a gap in the
  tests, which makes good material for archetype 7.

### 6. Add a field end to end

- **Teaches:** the data path, and how many places one change touches. This is often the most valuable mission.
- **Task:** add a small field (a `note`, `priority` or `archived` flag) that is stored, returned by the API or
  command, and shown in the UI or output.
- **Done when:** a value set through the app survives a reload or re-run, and the type checks or build pass. Where
  that part of the app can't safely run, use a test that round-trips the value, the type checker on both sides of
  the boundary, and a serialized sample (a JSON response from a test, a fixture) that shows the field.
- **Watch for:** migrations (local database only; check how the repo generates them), serializers or DTOs, API
  schemas (OpenAPI, GraphQL), generated clients (regenerate them, don't hand-edit), factories and fixtures, and forms.
- **Scope down** if needed: a computed or derived field avoids a migration.

### 7. Write a test

- **Teaches:** test style, fixtures, factories, mocking conventions and the speed of the feedback loop.
- **Task:** write a test for an untested branch on or near the spine, or for the field from mission 6, in the style
  of the neighboring tests.
- **Done when:** it fails for the right reason when the code is broken (have them check this) and passes otherwise.

### 8. Config and feature flags

- **Teaches:** how configuration is loaded and layered (defaults, files, env vars, secrets) and how flags gate code.
- **Task:** make something on the spine configurable with a sensible default, or flip an existing feature flag
  locally and observe the difference.
- **Done when:** changing the config locally changes behavior without a code change.
- **Watch for:** where the repo documents env vars (such as `.env.example`) and whether a new one needs adding there.

### 9. The error path

- **Teaches:** how errors propagate, how they're shown to users, and where they're logged or reported.
- **Task:** trigger a failure on the spine (invalid input, missing record, a downstream fake failing) and make the
  user-facing result better: a clearer message, the right status code, or a retry.
- **Done when:** the failure produces the improved behavior and a test covers it.

### 10. Find the bug

This is the only mission where you edit code. Use it only with explicit consent.

- **Teaches:** debugging in this codebase: reading stack traces, using the logs, bisecting with tests.
- **Setup:** with their OK, plant one small bug in code they've already visited, such as an off-by-one, an inverted
  check or a wrong field. Make sure a test or a visible symptom exposes it. Before planting it, write down the exact
  change in your head and confirm with `git diff` afterwards. Don't put it in the progress file, which they may read.
- **Task:** they see the symptom only, then find and fix it.
- **Done when:** fixed, with `git diff` against the pre-plant state showing nothing unexpected. If they give up,
  reveal it and revert it yourself.

### 11. Read the pipeline

- **Teaches:** delivery and conventions: what CI enforces and how code ships.
- **Task:** from the CI config, predict which checks will run on their onboarding branch, then run the same lint,
  format check, type check and tests locally and fix anything that fails.
- **Done when:** all the local equivalents of CI pass.
- **Also:** how a release or deploy happens, read only. Never trigger one.

### 12. Language primer

Use this only when the developer is new to the language.

- **Teaches:** one or two idioms this repo leans on heavily, such as Rust's `Result` and `?`, Go's error returns and
  interfaces, TypeScript discriminated unions, Python decorators and context managers, Elixir pattern matching and
  pipes, or Kotlin coroutines.
- **Task:** a tiny change on the spine that requires the idiom. Explain the idiom with a generic example first, never
  the solution.

### 13. Capstone

- **Teaches:** working independently, from the goal alone.
- **Task:** a tiny feature crossing every layer they touched, with a test. Examples: a filter or sort option, a new
  CLI flag, a new read-only endpoint or field, or a small validation with a clear error.
- **Pointer:** the goal only. Hints are still available.
- **Review:** treat it like a real PR review. Have them write the commit message and a PR-style description.

## A worked route

This is an example for a hypothetical Next.js, Prisma and Postgres task tracker, where the developer is full-stack,
new to the repo and has a standard budget. The spine is creating a task: the form in `app/tasks/new/page.tsx` calls a
server action in `app/tasks/actions.ts`, which calls `lib/tasks/service.ts` and then Prisma.

| # | Mission | Goal | Min | Pointer given |
|---|---|---|---|---|
| 1 | Get it running | App on localhost:3000 with seed data; one test file runs | 15 | README |
| 2 | Make it yours | Change the "No tasks yet" empty state | 5 | The text itself |
| 3 | Follow the wire | Log each hop when a task is created; name every hop | 10 | `app/tasks/` |
| 4 | Tweak a rule | Max title length 200 to 120, test updated | 10 | "validation" |
| 5 | Break it on purpose | Predict which tests fail if the ownership check is removed | 5 | The service file |
| 6 | Add a field | `priority` (low/med/high) stored, shown in the list, settable in the form | 25 | Goal only, plus "check the schema" |
| 7 | Test it | Test that the list sorts by priority | 15 | Goal only |
| 8 | Pipeline | Run what CI runs; fix what fails | 10 | Goal only |
| 9 | Capstone | `?priority=high` filters the list | 25 | Goal only |

Notice how the pointers fade, how each mission continues from the last, and that missions 6 to 9 all build on the same
field.

## Briefs: good and bad

Bad, because it leaks the solution and has no reason or check:

> Open `lib/tasks/service.ts`, go to line 42 and change `200` to `120`. Then in `service.test.ts` line 18 change the
> expected value.

Good:

> ### Mission 4/9 · Tweak a rule (~10 min)
> **Why it matters:** business rules live in the service layer, not the UI, and tests pin them so they can't drift.
> You'll change rules like this constantly.
> **Your task:** product wants task titles capped at 120 characters instead of 200.
> **Done when:** a 121-character title is rejected in the app with a clear message, and the test suite passes.
> **Start here:** you already passed through the place that validates input in the last mission.
> Say "done", "hint" or "skip", or ask anything.

## Check-for-understanding questions

Ask one per debrief. Pick a question whose answer forces them to look at code they haven't read yet, or to reason
about the change they just made.

- What would happen if this value were missing or null? Where would it fail?
- Who else calls this function? Would your change affect them?
- If this ran twice concurrently, what could go wrong?
- Where would you look first if this broke in production? What would the log line look like?
- Why do you think this lives in X and not Y?
- What test would have caught a mistake here? Does it exist?
- How would this change look if it had to be behind a feature flag?
