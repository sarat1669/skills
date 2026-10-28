# <repo>: map

<!-- Recon notes, written by the codebase-dojo skill in Phase 1. At wrap-up this becomes SUMMARY.md, the
developer's take-home. Keep every section short; link to file:line rather than quoting code. -->

## What it is

<One paragraph: what the product or library does, for whom, and the main moving parts.>

## Architecture

```
<ASCII sketch: processes, services, packages and data stores, with arrows for the main flows.
At wrap-up, mark the places the developer changed with *.>
```

## The spine: <flow name>

1. <What the user does> - `path/to/file.ext:line`
2. <Routing or dispatch> - `path:line`
3. <Handler or controller> - `path:line`
4. <Domain logic> - `path:line`
5. <Persistence or outbound call> - `path:line`
6. <Response or render> - `path:line`

Tested in: `path/to/test:line`

Run locally: <which hops the developer can safely run, and which are read-only because they'd hit a danger zone>.

## Glossary

| Term | Meaning | Where it lives |
|---|---|---|
| <Noun> | <one line> | `path` |

## Commands

| Task | Command | Confirmed | Side effects |
|---|---|---|---|
| Install | | | |
| Run locally | | | |
| Run all tests | | | |
| Run one test file | | | |
| Lint and format check | | | |
| Type check and build | | | |

"Confirmed" means you saw it work in this checkout. "Side effects" covers anything beyond build output: files
written, logins, network calls.

## Config

<Where config comes from (files, env vars, flags), what local needs, and where env vars are documented.>

## Conventions

<Formatting, naming, error handling, logging, commit message style, PR process, and anything the docs or CODEOWNERS
insist on.>

## Danger zones

<Code and commands with real side effects: never run them during onboarding.>

## Who knows what

| Area | People (from CODEOWNERS and git history) |
|---|---|
| | |

## Hotspots

<The most-changed and most-depended-on files: where the developer's real work will likely be.>
