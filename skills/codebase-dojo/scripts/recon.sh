#!/usr/bin/env bash
# recon.sh - read-only survey of a repository for the codebase-dojo skill.
#
# Usage: bash recon.sh [repo-path] [focus-path ...]
#   repo-path    any directory inside the repository (default: the current directory)
#   focus-path   optional paths relative to the repository root, e.g. `services/api packages/shared`; files, tests,
#                entry points, hotspots, signals and sizes are then limited to them (stack, commands, CI and docs are not)
#
# Prints facts the agent uses to plan the walkthrough: stack, layout, commands, CI steps, docs, tests, entry points,
# churn hotspots, side-effect signals and conventions. It never modifies the repository and never runs project code.
# Portable across GNU and BSD/macOS userlands (bash 3.2+); works without git (with no history).

set -u

root="${1:-.}"
[ $# -gt 0 ] && shift
cd "$root" 2>/dev/null || { echo "recon: cannot cd to $root" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }
section() { printf '\n## %s\n' "$1"; }
cap() { head -n "${1:-30}"; }
count() { grep -c . || true; }

# Commits touching more files than this are imports, renames or reformatting: they say nothing about where work happens.
BULK=50

# Paths that are rarely worth an onboarding mission: lockfiles, vendored and generated code, build output, binaries.
NOISE='(^|/)(node_modules|vendor|third_party|dist|build|out|target|\.next|\.nuxt|coverage|__pycache__|\.venv|venv|Pods|\.gradle|\.idea)/|(\.lock|-lock\.json|lock\.yaml|\.min\.(js|css)|\.map|\.snap|\.svg|\.png|\.jpe?g|\.gif|\.ico|\.webp|\.pdf|\.woff2?|\.ttf|\.eot|\.zip|\.gz|\.jar|\.dll|\.so|\.dylib|\.exe|\.bin|\.parquet|\.csv|\.pb\.go|_pb2\.py|\.g\.dart|\.generated\.[a-z]+)$|(^|/)(go\.sum|Cargo\.lock|poetry\.lock|Gemfile\.lock|composer\.lock|mix\.lock)$'
CODE='\.(js|jsx|ts|tsx|mjs|cjs|vue|svelte|py|rb|go|rs|java|kt|kts|scala|cs|fs|php|ex|exs|erl|swift|m|mm|c|cc|cpp|h|hpp|dart|lua|clj|hs|ml|sql|sh|ps1)$'
TESTS='(^|/)(tests?|__tests__|spec|specs|e2e|integration|cypress|playwright)/|(^|/)(test_[^/]+\.py|[^/]+_test\.(py|go|exs|rb|dart|cc|cpp)|[^/]+\.(test|spec)\.[cm]?[jt]sx?|[^/]+_spec\.rb|[^/]+Tests?\.(java|kt|cs|swift|scala))$'

in_git=0
if have git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  in_git=1
  cd "$(git rev-parse --show-toplevel)" || exit 1
fi

# Focus paths -> a regex over repo-relative paths, and git pathspecs.
SCOPE_RE=''
if [ $# -gt 0 ]; then
  for p in "$@"; do
    p="$(printf '%s' "$p" | sed 's|^\./||; s|/*$||')"
    [ -z "$p" ] && continue
    esc="$(printf '%s' "$p" | sed 's/[][\.*^$()+?{}|]/\\&/g')"
    SCOPE_RE="${SCOPE_RE:+$SCOPE_RE|}$esc"
  done
  [ -n "$SCOPE_RE" ] && SCOPE_RE="^($SCOPE_RE)(/|$)"
fi
in_scope() { if [ -n "$SCOPE_RE" ]; then grep -E "$SCOPE_RE"; else cat; fi; }
FOCUS=("$@")   # only expanded when SCOPE_RE is set, so never empty under set -u (bash 3.2 safe)

list_files() {
  if [ "$in_git" = 1 ]; then
    git ls-files 2>/dev/null
  else
    find . -type f \
      -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/target/*' \
      -not -path '*/dist/*' -not -path '*/build/*' -not -path '*/.venv/*' -not -path '*/__pycache__/*' 2>/dev/null |
      sed 's|^\./||'
  fi
}

ALL="$(list_files | grep -Ev "$NOISE")"
all() { printf '%s\n' "$ALL" | grep -v '^$'; }
FILES="$(all | in_scope)"
files() { printf '%s\n' "$FILES" | grep -v '^$'; }

# grep -c over the in-scope files of a kind, printed as "count path", most first. Works with or without git.
hits() { # $1 = file filter regex, $2 = pattern, $3 = extra grep flags
  files | grep -E "$1" | grep -Ev "$TESTS" | tr '\n' '\0' |
    xargs -0 grep -I -c -E ${3:-} "$2" /dev/null 2>/dev/null |
    awk '{ n = match($0, /:[0-9]+$/); if (n) { c = substr($0, n + 1); if (c > 0) print c " " substr($0, 1, n - 1) } }' |
    sort -rn
}

echo "# Recon: $(basename "$(pwd)")"
echo "path: $(pwd)"
[ -n "$SCOPE_RE" ] && echo "focus: ${FOCUS[*]}"

# --- Overview -------------------------------------------------------------------------------------------------------
section "Overview"
echo "source files (excluding vendored/generated/binary): $(all | wc -l | tr -d ' ')"
[ -n "$SCOPE_RE" ] && echo "  of which in focus: $(files | wc -l | tr -d ' ')"
if [ "$in_git" = 1 ]; then
  echo "branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  echo "head: $(git log -1 --format='%h %ad %s' --date=short 2>/dev/null)"
  echo "first commit: $(git log --reverse --format='%ad' --date=short 2>/dev/null | head -n 1)"
  echo "commits: $(git rev-list --count HEAD 2>/dev/null) total; last 30/90/365 days:" \
    "$(git rev-list --count --since='30 days ago' HEAD 2>/dev/null)/$(git rev-list --count --since='90 days ago' HEAD 2>/dev/null)/$(git rev-list --count --since='365 days ago' HEAD 2>/dev/null)"
  echo "authors: $(git shortlog -sn HEAD </dev/null 2>/dev/null | wc -l | tr -d ' ')"
  echo "modified tracked files: $(git status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')" \
    "(untracked: $(git status --porcelain 2>/dev/null | grep -c '^??' || true))"
else
  echo "not a git repository: history, churn and authorship sections are skipped"
fi

# --- Languages ------------------------------------------------------------------------------------------------------
section "Languages (files by extension)"
files | awk -F/ '{print $NF}' | grep '\.' | awk -F. '{print "." tolower($NF)}' | sort | uniq -c | sort -rn | cap 15

# --- Layout ---------------------------------------------------------------------------------------------------------
section "Top-level layout (files per entry)"
all | awk -F/ 'NF > 1 { print $1 "/" } NF == 1 { print $1 }' | sort | uniq -c | sort -rn | cap 40

# --- Manifests ------------------------------------------------------------------------------------------------------
section "Manifests, build, tooling and environment files"
MANIFESTS='(^|/)(package\.json|deno\.jsonc?|tsconfig\.json|Cargo\.toml|go\.mod|go\.work|pyproject\.toml|setup\.py|setup\.cfg|requirements[^/]*\.txt|Pipfile|environment\.ya?ml|Gemfile|mix\.exs|rebar\.config|pom\.xml|build\.gradle(\.kts)?|settings\.gradle(\.kts)?|build\.sbt|[^/]+\.csproj|[^/]+\.sln|composer\.json|pubspec\.yaml|Package\.swift|Podfile|CMakeLists\.txt|meson\.build|Makefile|GNUmakefile|justfile|Justfile|Taskfile\.ya?ml|Rakefile|Dockerfile[^/]*|docker-compose[^/]*\.ya?ml|compose\.ya?ml|Procfile|devcontainer\.json|flake\.nix|shell\.nix|turbo\.json|nx\.json|lerna\.json|pnpm-workspace\.yaml|\.tool-versions|\.nvmrc|\.node-version|\.python-version|\.ruby-version|rust-toolchain(\.toml)?|[^/]+\.tf|serverless\.ya?ml|vercel\.json|netlify\.toml|fly\.toml|app\.ya?ml|wrangler\.toml|\.env\.[a-z]+|\.env\.example|[^/]+\.env\.example)$|(^|/)\.vscode/(launch|tasks)\.json$|(^|/)\.claude/launch\.json$'
m="$(all | grep -E "$MANIFESTS" | grep -Ev '(^|/)(test|tests|fixtures|examples?|samples?)/')"
n="$(printf '%s\n' "$m" | count)"
printf '%s\n' "$m" | awk -F/ '{ print NF - 1, $0 }' | sort -n | cut -d' ' -f2- | cap 40
[ "$n" -gt 40 ] && echo "... and $((n - 40)) more"
if [ -f .gitignore ]; then
  echo "local-only state (.gitignore): $(grep -Ev '^[[:space:]]*(#|$)' .gitignore | cap 25 | tr '\n' ' ')"
fi

# --- Commands -------------------------------------------------------------------------------------------------------
section "Commands the project defines"
pkgs="$(all | grep -E '(^|/)package\.json$' | awk -F/ '{ print NF, $0 }' | sort -n | cut -d' ' -f2- | head -n 6)"
for p in $pkgs; do
  if have node; then
    out="$(node -e 'const s=require(process.argv[1]).scripts||{};for(const[k,v]of Object.entries(s))console.log("  "+k+": "+v)' "./$p" 2>/dev/null)"
  elif have python3; then
    out="$(python3 -I -c 'import json,sys
for k,v in (json.load(open(sys.argv[1])).get("scripts") or {}).items(): print("  "+k+": "+v)' "$p" 2>/dev/null)"
  else
    out="$(sed -n '/"scripts"/,/}/p' "$p" | sed '1d;$d')"
  fi
  [ -n "$out" ] && { echo "$p scripts:"; printf '%s\n' "$out" | cap 25; }
done
for mk in Makefile GNUmakefile; do
  [ -f "$mk" ] && { echo "$mk targets:"; grep -E '^[A-Za-z0-9][A-Za-z0-9_./-]*:([^=]|$)' "$mk" | cut -d: -f1 | sort -u | tr '\n' ' ' | fold -w 110; echo; }
done
for jf in justfile Justfile .justfile; do
  [ -f "$jf" ] && { echo "$jf recipes:"; grep -E '^@?[A-Za-z0-9_-]+( [^:=]*)?:([^=]|$)' "$jf" | cut -d: -f1 | tr '\n' ' ' | fold -w 110; echo; }
done
for tf in Taskfile.yml Taskfile.yaml; do
  [ -f "$tf" ] && { echo "$tf tasks:"; sed -n '/^tasks:/,$p' "$tf" | grep -E '^  [A-Za-z0-9_:-]+:' | tr -d ' :' | tr '\n' ' ' | fold -w 110; echo; }
done
if [ -f Cargo.toml ] && grep -q '^\[workspace\]' Cargo.toml; then
  echo "Cargo workspace members:"
  awk '/^members[[:space:]]*=/ { on = 1 } on { print; if ($0 ~ /\]/) exit }' Cargo.toml |
    sed 's/members[[:space:]]*=//' | tr -d '[]",' | tr -s ' \t\n' ' ' | fold -w 110; echo
fi
if [ -f pyproject.toml ]; then
  sc="$(sed -n '/^\[\(project\.scripts\|tool\.poetry\.scripts\)\]/,/^\[/p' pyproject.toml | grep '=' )"
  [ -n "$sc" ] && { echo "pyproject scripts:"; printf '%s\n' "$sc" | sed 's/^/  /'; }
fi
[ -f manage.py ] && echo "Django: manage.py present (python manage.py runserver / test)"
[ -f bin/rails ] && echo "Rails: bin/rails present (bin/rails server / test, bin/dev)"
[ -f artisan ] && echo "Laravel: artisan present (php artisan serve / test)"
echo "(names only: read what a command does before running it; dev/start scripts can log in, sync or send)"

# --- CI ------------------------------------------------------------------------------------------------------------
section "CI: what actually runs"
ci="$(all | grep -E '^(\.github/workflows/[^/]+\.ya?ml|\.gitlab-ci\.yml|\.circleci/config\.yml|Jenkinsfile|azure-pipelines\.yml|bitbucket-pipelines\.yml|\.buildkite/[^/]+|\.travis\.yml|\.drone\.yml|\.woodpecker\.ya?ml)$')"
if [ -z "$ci" ]; then
  echo "no CI config found: nothing enforces lint, format or tests on a PR"
else
  for f in $ci; do
    echo "$f:"
    awk '
      inblock {
        if ($0 ~ /^[[:space:]]*$/) next
        match($0, /^[[:space:]]*/)
        if (RLENGTH > ind) { l = $0; sub(/^[[:space:]]+/, "", l); print "      " l; next }
        inblock = 0
      }
      /^[[:space:]]*(-[[:space:]]+)?(run|script|command):[[:space:]]*[|>][-+]?[[:space:]]*$/ {
        match($0, /^[[:space:]]*/); ind = RLENGTH; inblock = 1; next
      }
      /^[[:space:]]*(-[[:space:]]+)?(run|command):/ {
        l = $0; sub(/^[[:space:]]*(-[[:space:]]+)?(run|command):[[:space:]]*/, "", l); if (l != "") print "    $ " l
      }
      /^[[:space:]]*(-[[:space:]]+)?uses:/ {
        l = $0; sub(/^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*/, "", l); print "    uses " l
      }
    ' "$f" | cap 30
  done | cap 90
fi

# --- Docs ---------------------------------------------------------------------------------------------------------
section "Docs and agent instructions"
all | grep -Ei '(^|/)(readme|contributing|architecture|design|development|developing|hacking|setup|install|onboarding|agents|claude|gemini|copilot-instructions|conventions|style ?guide|security|changelog)[^/]*\.(md|mdx|rst|txt|adoc)$|(^|/)\.cursorrules$|(^|/)\.cursor/rules/|(^|/)codeowners$|(^|/)pull_request_template\.md$' |
  awk -F/ '{ print NF - 1, $0 }' | sort -n | cut -d' ' -f2- | cap 30
d="$(all | grep -Ei '^(docs?|documentation|wiki|adr|adrs|decisions)/.*\.(md|mdx|rst|adoc)$')"
dn="$(printf '%s\n' "$d" | count)"
[ "$dn" -gt 0 ] && { echo "docs/ tree ($dn files):"; printf '%s\n' "$d" | cap 20 | sed 's/^/  /'; }

# --- Tests --------------------------------------------------------------------------------------------------------
section "Tests"
t="$(files | grep -E "$TESTS")"
tn="$(printf '%s\n' "$t" | count)"
echo "test files: $tn"
if [ "$tn" -gt 0 ]; then
  echo "where they live:"
  printf '%s\n' "$t" | awk -F/ '{ if (NF > 2) print $1 "/" $2 "/"; else if (NF == 2) print $1 "/"; else print "./" }' |
    sort | uniq -c | sort -rn | cap 12
fi
inline="$(hits '\.rs$' '#\[(cfg\(test\)|test)\]' | count)"
[ "$inline" -gt 0 ] && echo "rust files with inline #[test]/#[cfg(test)]: $inline"
doct="$(hits '\.py$' '^[[:space:]]*>>> ' | count)"
[ "$doct" -gt 0 ] && echo "python files with doctests: $doct"
files | grep -Ei '(^|/)(jest|vitest|playwright|cypress|karma)\.config\.[a-z]+$|(^|/)(pytest\.ini|tox\.ini|conftest\.py|phpunit\.xml(\.dist)?|\.rspec|\.mocharc[^/]*)$' | cap 10
# Areas with code but no tests are worth knowing before promising "a test goes green".
printf '%s\n' "$FILES" | grep -E "$CODE" | awk -F/ 'NF > 1 { print $1 "/" (NF > 2 ? $2 "/" : "") }' | sort -u |
  while read -r area; do
    printf '%s\n' "$t" | grep -q "^$area" || hits "^$area.*\.rs$" '#\[(cfg\(test\)|test)\]' | grep -q . ||
      echo "no tests found under: $area"
  done | cap 10

# --- Entry points -------------------------------------------------------------------------------------------------
section "Entry point candidates"
ENTRY='(^|/)(main\.(go|rs|py|c|cc|cpp|kt|swift|dart|[cm]?[jt]sx?)|__main__\.py|manage\.py|wsgi\.py|asgi\.py|app\.(py|rb|[cm]?[jt]sx?)|server\.([cm]?[jt]s|py|go)|index\.([cm]?[jt]sx?)|App\.(tsx|jsx|vue|svelte|swift|kt)|app\.(vue|svelte)|\+page\.svelte|\+layout\.svelte|layout\.tsx|page\.tsx|_app\.[jt]sx|Program\.cs|Startup\.cs|[A-Za-z]+Application\.(java|kt)|AppDelegate\.swift|MainActivity\.(kt|java)|lib\.rs|routes\.rb|router\.ex|application\.ex|web\.php|api\.php|urls\.py|routes\.py|router\.[cm]?[jt]s|routes\.[cm]?[jt]s)$|(^|/)cmd/[^/]+/main\.go$|(^|/)src/bin/[^/]+\.rs$|(^|/)bin/[^/.]+$|(^|/)examples/[^/]+\.(rs|go|py|[cm]?[jt]s)$'
files | grep -E "$ENTRY" | grep -Ev "$TESTS" | awk -F/ '{ print NF - 1, $0 }' | sort -n | cut -d' ' -f2- | cap 40

# --- Side effects -------------------------------------------------------------------------------------------------
section "Side-effect signals (files to read before running anything; tests excluded)"
signal() { # $1 label, $2 file filter, $3 pattern, $4 grep flags
  out="$(hits "$2" "$3" "${4:-}" | cap 6)"
  [ -n "$out" ] && { echo "$1:"; printf '%s\n' "$out" | sed 's/^/  /'; }
}
signal "outbound network" "$CODE" 'reqwest|hyper::Client|ureq::|tungstenite|axios|fetch\(|XMLHttpRequest|new WebSocket|requests\.(get|post|put|delete|Session)|httpx\.|aiohttp|urllib\.request|websockets?\.connect|http\.(Get|Post|NewRequest)|HttpClient|OkHttp|Retrofit|RestTemplate|WebClient|Net::HTTP|Faraday|HTTParty|HTTPoison|Finch\.|Req\.(get|post|request)|Tesla\.|Guzzle|curl_exec|URLSession'
signal "processes and shell" "$CODE" 'Command::new|std::process::|subprocess|os\.system|child_process|execSync|spawnSync|exec\.Command|Runtime\.getRuntime|ProcessBuilder|System\.cmd|Port\.open|Process\.Start|Start-Process'
signal "money, messaging, orders" "$CODE" 'stripe|braintree|paypal|razorpay|adyen|plaid|twilio|sendgrid|mailgun|postmark|nodemailer|smtp|actionmailer|swoosh|ses\.send|sns\.publish|place_?order|submit_?order|payout|refund' -i
signal "deploy, publish, destructive" '\.(sh|bash|ps1|ya?ml|toml|json|mk)$|(^|/)(Makefile|justfile|Justfile|Taskfile\.ya?ml|Dockerfile[^/]*)$' 'kubectl|helm (install|upgrade)|terraform (apply|destroy)|(^|[^A-Za-z_-])(aws|az|gcloud) [a-z]|docker push|npm publish|cargo publish|twine upload|gh release|fly deploy|vercel --prod|DROP (TABLE|DATABASE)|TRUNCATE|rm -rf|Register-ScheduledTask|schtasks|systemctl|crontab'
envs="$(files | grep -E "$CODE" | grep -Ev "$TESTS" | tr '\n' '\0' |
  xargs -0 grep -h -o -E 'env::var(_os)?\("[A-Z][A-Z0-9_]+|env!\("[A-Z][A-Z0-9_]+|process\.env\.[A-Z][A-Z0-9_]+|process\.env\[.[A-Z][A-Z0-9_]+|import\.meta\.env\.[A-Z][A-Z0-9_]+|os\.environ(\.get)?[[(].[A-Z][A-Z0-9_]+|os\.getenv\(.[A-Z][A-Z0-9_]+|os\.Getenv\("[A-Z][A-Z0-9_]+|ENV(\.fetch\(|\[).[A-Z][A-Z0-9_]+|System\.(get_env|fetch_env!?)\("[A-Z][A-Z0-9_]+|getenv\("[A-Z][A-Z0-9_]+|GetEnvironmentVariable\("[A-Z][A-Z0-9_]+|\$env:[A-Z][A-Z0-9_]+' 2>/dev/null |
  grep -o -E '[A-Z][A-Z0-9_]+$' | sort | uniq -c | sort -rn | awk '{ print $2 }' | cap 30 | tr '\n' ' ')"
[ -n "$envs" ] && { echo "env vars read by code:"; printf '%s\n' "$envs" | fold -w 110 | sed 's/^/  /'; }

# --- History ------------------------------------------------------------------------------------------------------
if [ "$in_git" = 1 ]; then
  commits_since() { # $1 = --since value; prints "@<hash> <date> <subject>" headers, each followed by its files
    if [ -n "$SCOPE_RE" ]; then
      git log --full-history --since="$1" -n 2000 --no-merges --format='@%h %ad %s' --date=short --name-only \
        -- "${FOCUS[@]}" 2>/dev/null
    else
      git log --since="$1" -n 2000 --no-merges --format='@%h %ad %s' --date=short --name-only 2>/dev/null
    fi
  }
  by_size() { # $1 = files: the files of non-bulk commits; bulk: one line per bulk commit
    awk -v max="$BULK" -v mode="$1" '
      function flush() {
        if (h == "") return
        if (mode == "files" && n <= max) for (i = 1; i <= n; i++) print f[i]
        if (mode == "bulk" && n > max) print "  " n " files  " substr(h, 2)
        n = 0
      }
      /^@/ { flush(); h = $0; next }
      NF { f[++n] = $0 }
      END { flush() }'
  }

  year="$(commits_since '12 months ago')"
  [ -z "$year" ] && year="$(commits_since '100 years ago')"

  section "Hotspots: most-changed source files (last 12 months, bulk commits excluded)"
  hs="$(printf '%s\n' "$year" | by_size files | grep -Ev "$NOISE" | grep -E "$CODE" | sort | uniq -c | sort -rn | cap 25)"
  if [ -n "$hs" ]; then printf '%s\n' "$hs"; else echo "none: history is too thin to say where work happens"; fi
  bulk="$(printf '%s\n' "$year" | by_size bulk | cap 10)"
  [ -n "$bulk" ] && { echo "excluded bulk commits (> $BULK files: imports, renames, reformatting):"; printf '%s\n' "$bulk"; }

  section "Active areas: directories touched in the last 90 days (bulk commits excluded)"
  commits_since '90 days ago' | by_size files | grep -Ev "$NOISE" |
    awk -F/ '{ if (NF > 2) print $1 "/" $2 "/"; else if (NF == 2) print $1 "/"; else print "./" }' | sort | uniq -c | sort -rn | cap 15

  section "Recent commits (style and conventions)"
  printf '%s\n' "$year" | grep '^@' | sed 's/^@//' | cap 15

  section "Top authors (who to ask)"
  if [ -n "$SCOPE_RE" ]; then
    git shortlog -sn -n --no-merges HEAD -- "${FOCUS[@]}" </dev/null 2>/dev/null | cap 8
  else
    git shortlog -sn -n --no-merges HEAD </dev/null 2>/dev/null | cap 8
  fi
fi

# --- Size -----------------------------------------------------------------------------------------------------------
section "Largest source files (lines)"
files | grep -E "$CODE" | tr '\n' '\0' | xargs -0 wc -l 2>/dev/null | grep -Ev ' total$|^ *0$' | sort -rn | cap 12

# --- Markers ------------------------------------------------------------------------------------------------------
section "TODO / FIXME / HACK density (top files)"
td="$(hits "$CODE" '(TODO|FIXME|HACK)' | cap 10)"
if [ -n "$td" ]; then printf '%s\n' "$td"; else echo "none"; fi

echo
echo "(recon done: read-only; nothing was executed from the project)"
