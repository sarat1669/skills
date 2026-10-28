# Finding touchpoints

How to find the places a developer will touch first, and how to rank them. Use this during Phase 1 (recon) and
Phase 2 (planning the route).

## Contents

- [What a touchpoint is](#what-a-touchpoint-is)
- [Ranking candidates](#ranking-candidates)
- [Churn, centrality and ownership commands](#churn-centrality-and-ownership-commands)
- [Tracing the spine](#tracing-the-spine)
- [Where things live, by stack](#where-things-live-by-stack)
- [Grep patterns for entry points and routes](#grep-patterns-for-entry-points-and-routes)
- [Layer checklist](#layer-checklist)

## What a touchpoint is

A touchpoint is a place in the code where a small change teaches something about how the system works and produces a
result the developer can see. A good one sits on a path real requests or jobs take, so it isn't dead code.

## Ranking candidates

Score each candidate location roughly on these factors and prefer the highest:

| Factor | Ask | Evidence |
|---|---|---|
| On the spine | Does the chosen flow pass through it? | Your trace |
| In focus | Is it in the area the developer will own? | Phase 0 answer |
| Active | Do people change it often? | Churn (recon "Hotspots", "Active areas") |
| Central | Do many modules depend on it? | Fan-in counts below |
| Observable | Can the effect be seen quickly? | A screen, CLI output, response, or test |
| Safe | Does it avoid real side effects? | Danger-zone notes |
| Small | Can one concept be taught in 1 to 10 lines? | Your read of the code |

A file with high churn and high fan-in is where the developer's real work will be, but it is often too big to start
in. Approach it in the middle of the route, after they've walked the flow that leads into it.

Churn only counts when history is real. Recon excludes commits that touch more than 50 files and lists them. If most
of the focus area arrived in those, or the repo is only weeks old, rank on the other factors instead.

The largest files from recon are often "god objects". Point them out in the map, but don't start missions there.
Find the smaller module they delegate to.

## Churn, centrality and ownership commands

Recon prints churn already. These are for digging further. All of them are read-only.

```bash
# Churn within an area
git log --since='6 months ago' --no-merges --format= --name-only -- <dir> | grep -v '^$' | sort | uniq -c | sort -rn | head -20

# Files that change together (coupling): files committed alongside a given file
git log --format=%H -n 300 -- <file> | while read -r c; do git show --name-only --format= "$c"; done |
  grep -v '^$' | grep -vxF '<file>' | sort | uniq -c | sort -rn | head -15

# Owners and experts for an area
git shortlog -sn --no-merges HEAD -- <dir> </dev/null | head -5
cat CODEOWNERS .github/CODEOWNERS docs/CODEOWNERS 2>/dev/null | grep -v '^#' | grep -v '^$'

# Why a line is the way it is
git log -L '/<function name>/,+20:<file>' -n 3
```

Fan-in, meaning which internal modules are imported the most, varies by language:

```bash
# JS/TS: most imported relative or aliased modules
git grep -h -o -E "from ['\"](\.{1,2}/|@/|~/|src/)[^'\"]+['\"]" -- '*.ts' '*.tsx' '*.js' '*.jsx' '*.vue' '*.svelte' |
  sed -E "s/from ['\"]//; s/['\"]$//; s#^(\.\./)+##; s#^\./##" | sort | uniq -c | sort -rn | head -20

# Python
git grep -h -o -E '^(from|import) [A-Za-z_][A-Za-z0-9_.]*' -- '*.py' | awk '{print $2}' | sort | uniq -c | sort -rn | head -20

# Go: use the module path from go.mod
mod=$(awk '/^module/{print $2}' go.mod); git grep -h -o -E "\"$mod/[^\"]+\"" -- '*.go' | sort | uniq -c | sort -rn | head -20

# Rust: modules referenced within a crate and across workspace crates (`use` or inline paths)
crates=$(git ls-files '*Cargo.toml' | tr '\n' '\0' | xargs -0 sed -n 's/^name *= *"\([^"]*\)".*/\1/p' | tr '-' '_' | paste -sd'|' -)
git grep -h -o -E "(crate|super|$crates)::[a-z_][a-z0-9_]*" -- '*.rs' | sort | uniq -c | sort -rn | head -20

# Java/Kotlin: use your base package
git grep -h -o -E '^import [a-z0-9_.]+\.[A-Z][A-Za-z0-9]*' -- '*.java' '*.kt' | grep '<base.package>' |
  sort | uniq -c | sort -rn | head -20

# Ruby (Rails autoloads, so count constant references instead)
git grep -h -o -E '\b[A-Z][A-Za-z]+(::[A-Z][A-Za-z]+)*\.(find|where|create|new|call|perform)' -- '*.rb' |
  sed -E 's/\.[a-z]+$//' | sort | uniq -c | sort -rn | head -20

# Elixir
git grep -h -o -E '(alias|import) [A-Z][A-Za-z.]*[A-Za-z]' -- '*.ex' '*.exs' | awk '{print $2}' | sort | uniq -c | sort -rn | head -20
```

## Tracing the spine

1. Start from something a user does: a page and a button, a CLI command, an API endpoint, a scheduled job or a queue
   message.
2. Find the entry point. Grep for the visible text (button label, CLI help text, route path, error message). Grepping
   for what you can see is also the first technique to teach the developer.
3. Follow each call inward and record `file:line` for each hop: route registration, then the handler or controller,
   then validation, then the domain or service function, then the persistence call or outbound client, then the
   response or render.
4. Note where the flow crosses a boundary (process, network, package or language), where errors are handled, and
   where it is tested.
5. Check you can trigger it locally and see the result. If you can't, pick another flow or use its tests as the
   observable part.

Write the spine in the map as a numbered list of hops. Most missions will live on these hops.

## Where things live, by stack

Treat these as starting points to confirm. Every repo bends its framework's conventions.

| Stack | Entry and bootstrap | Routing and dispatch | Logic | Data | Tests | Typical commands |
|---|---|---|---|---|---|---|
| React or Vite SPA | `src/main.tsx`, `index.html` | `App.tsx`, router config | hooks, `src/lib`, stores | API client, `fetch` wrappers | `*.test.tsx`, Vitest, Jest | `npm run dev`, `npm test` |
| Next.js | `app/layout.tsx` or `pages/_app.tsx` | `app/**/page.tsx`, `app/api/**/route.ts` | server actions, `lib/` | Prisma or Drizzle schema, `db/` | Jest, Vitest, Playwright | `npm run dev` |
| SvelteKit or Svelte | `src/routes/+layout.svelte`, `src/main.ts` | `src/routes/**/+page.svelte`, `+server.ts` | `src/lib` | `+page.server.ts` load functions | Vitest, Playwright | `npm run dev`, `npm run check` |
| Vue or Nuxt | `main.ts`, `app.vue` | `router/`, `pages/` | composables, stores (Pinia) | `server/api/` | Vitest | `npm run dev` |
| Express, Fastify or Nest | `server.ts`, `app.ts`, `main.ts` | `routes/`, `*.controller.ts` | `services/`, `*.service.ts` | `models/`, ORM entities, migrations | Jest, Supertest | `npm run dev` |
| Django | `manage.py`, `settings.py` | `urls.py` | `views.py`, `services.py`, forms, serializers | `models.py`, `migrations/` | `tests.py`, pytest-django | `python manage.py runserver` |
| FastAPI or Flask | `main.py`, `app.py`, `create_app()` | `APIRouter`, `@app.route` | `services/`, `crud/` | SQLAlchemy models, Alembic, Pydantic schemas | pytest, `conftest.py` | `uvicorn app.main:app --reload` |
| Python CLI or library | `__main__.py`, `[project.scripts]` | click, typer or argparse commands | package modules | n/a | pytest | `python -m <pkg>` |
| Go service | `cmd/<name>/main.go` | `http.HandleFunc`, chi, gin or echo router | `internal/<domain>/` | `internal/store/`, sqlc, `migrations/` | `*_test.go` | `go run ./cmd/<name>`, `go test ./...` |
| Rust | `src/main.rs`, `src/bin/`, workspace `crates/` | clap commands, axum or actix routers | `lib.rs` module tree | sqlx or diesel, `migrations/` | `#[cfg(test)]` inline, `tests/` | `cargo run -p <crate>`, `cargo test -p <crate>` |
| Spring Boot (Java, Kotlin) | `*Application.java` | `@RestController`, `@RequestMapping` | `@Service` | `@Entity`, repositories, Flyway or Liquibase | `src/test/`, JUnit | `./gradlew bootRun`, `./mvnw test` |
| .NET | `Program.cs` | controllers, minimal API `Map*` | services | EF Core `DbContext`, migrations | `*.Tests` projects | `dotnet run`, `dotnet test` |
| Rails | `config/application.rb` | `config/routes.rb` | `app/controllers`, `app/services`, jobs | `app/models`, `db/schema.rb`, `db/migrate` | `spec/` or `test/` | `bin/dev`, `bin/rails test`, `bundle exec rspec` |
| Phoenix (Elixir) | `application.ex` | `lib/*_web/router.ex` | contexts in `lib/<app>/` | Ecto schemas, `priv/repo/migrations` | `test/`, ExUnit | `mix phx.server`, `mix test` |
| Laravel | `public/index.php`, `bootstrap/app.php` | `routes/web.php`, `routes/api.php` | `app/Http/Controllers`, `app/Services` | `app/Models`, `database/migrations` | `tests/`, PHPUnit or Pest | `php artisan serve`, `php artisan test` |
| iOS (SwiftUI) | `@main App` | `NavigationStack`, coordinators | ViewModels | Core Data, SwiftData, networking layer | XCTest | Xcode run, `xcodebuild test` |
| Android | `AndroidManifest.xml`, `MainActivity` | Navigation graph, Compose `NavHost` | ViewModels, use cases | Room, Retrofit | `src/test`, `src/androidTest` | `./gradlew installDebug`, `./gradlew test` |
| Flutter | `lib/main.dart` | `GoRouter` or `Navigator` | blocs, providers, notifiers | repositories | `test/` | `flutter run`, `flutter test` |
| React Native | `index.js`, `App.tsx` | React Navigation | hooks, stores | API clients | Jest | `npx expo start` |
| Terraform | root `main.tf` | `modules/` | variables and locals | state (never touch) | `terraform validate`, tflint | `terraform plan` only |
| Data pipelines | DAG files (Airflow, Dagster, Prefect), dbt `models/` | schedules, assets | transforms | warehouse tables | dbt tests, pytest | `dbt build --select` on a dev target |

## Grep patterns for entry points and routes

```bash
git grep -n -E 'listen\(|createServer|app\.(get|post|put|delete|use)\(|router\.(get|post)|@(Get|Post|Controller)\(' -- '*.ts' '*.js'
git grep -n -E '@app\.(get|post|route)|APIRouter\(|path\(|urlpatterns|@click\.command|typer\.Typer|argparse' -- '*.py'
git grep -n -E 'func main\(|HandleFunc|\.(GET|POST|Handle)\(' -- '*.go'
git grep -n -E 'fn main\(|#\[tokio::main\]|Router::new|\.route\(|#\[derive\(.*Parser' -- '*.rs'
git grep -n -E '@SpringBootApplication|@(Rest)?Controller|@(Get|Post|Request)Mapping' -- '*.java' '*.kt'
git grep -n -E '^\s*(get|post|resources?|namespace|scope) ' -- config/routes.rb
git grep -n -E 'scope "|pipe_through|(get|post|live) "' -- '*router.ex'
```

## Layer checklist

By the end of a standard or deep route, the developer should have touched or at least traced each layer that exists
in the repo. Mark each one in the progress file as you go:

- [ ] Setup and the local dev loop (run, hot reload, a single test)
- [ ] User-visible surface (UI, CLI output, API response, docs site)
- [ ] Entry and routing or dispatch
- [ ] Domain or business logic
- [ ] Data model and persistence (schema, migrations, queries)
- [ ] External boundaries (clients for other services, queues), using fakes
- [ ] Tests (unit, plus how integration or e2e tests are run)
- [ ] Config, env vars and feature flags
- [ ] Errors, logging and observability
- [ ] Cross-cutting concerns (auth, permissions, i18n, caching), whichever exist
- [ ] Build, CI and release (what runs on a PR, how it ships)
