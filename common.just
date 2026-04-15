# Monorepo-aware justfile (uv workspace)
# ======================================================================
# Config (overridable via env/.env)
# ======================================================================

MODE := env("MODE", "dev") # dev | debug | ci
VERBOSE := env("VERBOSE", "0") # 0 | 1#

# ----------------------------------------------------------------------
# Config (overridable via env/.env)
# ----------------------------------------------------------------------

MODE := env("MODE", "dev") # dev | debug | ci
VERBOSE := env("VERBOSE", "0") # 0 | 1

PYTEST_CONFIG := ROOT_DIR + "/pyproject.toml"
IMPORTLINTER_CONFIG := ROOT_DIR + "/import-linter.toml"

REPO_CACHE_DIR := ROOT_DIR + "/.cache"
UV_CACHE_DIR := REPO_CACHE_DIR + "/uv"
RUFF_CACHE_DIR := REPO_CACHE_DIR + "/ruff"

# uv workspace sync mode:
# - all: install all workspace members into the root venv
# - one: install just the selected PACKAGE member
UV_SYNC_MODE := env("UV_SYNC_MODE", "all")    # all | one

# PACKAGE is intentionally empty by default.
# It is required when UV_SYNC_MODE=one.
PACKAGE := env("PACKAGE", file_stem(ROOT_DIR))

JSCPD := "npx --yes jscpd@4.0"

WILY_CACHE := ROOT_DIR + "/.wily"
WILY_CONFIG := ROOT_DIR + "/wily.cfg"

# uv mode-sensitive flags
UV_SYNC_FLAGS := if MODE == "ci" {
  "--locked"
} else {
  ""
}

UV_RUN_FLAGS := if MODE == "ci" {
  "--locked --no-sync"
} else {
  ""
}

UV := "uv"
UV_RUN := UV + " --cache-dir " + UV_CACHE_DIR + " run " + UV_RUN_FLAGS + " --"

# ======================================================================
# pytest options
# ======================================================================

PYTEST_DEV_WORKERS := env("PYTEST_DEV_WORKERS", "auto")
PYTEST_DEV_DIST := env("PYTEST_DEV_DIST", "loadscope")
PYTEST_DEV_THRESHOLD := env("PYTEST_DEV_THRESHOLD", "80")

PYTEST_QUIET_OPTS := "-q --tb=short -r fE --show-capture=no -o log_cli=false"
PYTEST_DEBUG_OPTS := "-vv --tb=long -l --show-capture=all -o log_cli=true"
PYTEST_LOG_OPTS := "-q --tb=short -r fE --show-capture=no -o log_cli=true --log-cli-level=INFO"
PYTEST_FAST_EXPR := "-m 'not slow' --durations=25 --durations-min=0.2 --fast-call-budget=0.25 --fast-total-budget=0.50" # --enforce-fast-budget
PYTEST_FAILING_OPTS := "--lf"

# ======================================================================
# Meta / Defaults
# ======================================================================
[private]
shared-default:
  @just help

# List available recipes; also the default entry point
help:
  @just _log_start help
  @just --list --unsorted --list-prefix "  "
  @just _log_end help

# Print runtime configuration (paths + tool binaries)
env:
  @just _log_start env
  @bash -euo pipefail -c '\
    print_kv() { printf "%-24s %s\n" "$1" "$2"; }; \
    print_section() { printf "\n[%s]\n" "$1"; }; \
    show_cmd() { \
      label="$1"; shift; \
      if command -v "$1" >/dev/null 2>&1; then \
        resolved="$(command -v "$1")"; \
        version="$("$@" 2>/dev/null | head -n 1 || true)"; \
        print_kv "$label" "$resolved"; \
        if [ -n "$version" ]; then \
          print_kv "$label version" "$version"; \
        fi; \
      else \
        print_kv "$label" "not found on PATH"; \
      fi; \
    }; \
    show_uv_run_tool() { \
      label="$1"; shift; \
      tool="$1"; shift; \
      set +e; \
      out="$({{UV_RUN}} "$tool" "$@" 2>/dev/null | head -n 1)"; \
      status=$?; \
      set -e; \
      if [ "$status" -eq 0 ] && [ -n "$out" ]; then \
        print_kv "$label" "$out"; \
      else \
        print_kv "$label" "unavailable in project environment"; \
      fi; \
    }; \
    \
    print_section "mode"; \
    print_kv "MODE" "{{MODE}}"; \
    print_kv "VERBOSE" "{{VERBOSE}}"; \
    print_kv "UV_SYNC_MODE" "{{UV_SYNC_MODE}}"; \
    print_kv "UV_SYNC_FLAGS" "{{UV_SYNC_FLAGS}}"; \
    print_kv "UV_RUN_FLAGS" "{{UV_RUN_FLAGS}}"; \
    print_kv "PACKAGE" "{{PACKAGE}}"; \
    \
    print_section "paths"; \
    print_kv "ROOT_DIR" "{{ROOT_DIR}}"; \
    print_kv "PKG_DIR" "{{PKG_DIR}}"; \
    print_kv "PYTEST_CONFIG" "{{PYTEST_CONFIG}}"; \
    print_kv "IMPORTLINTER_CONFIG" "{{IMPORTLINTER_CONFIG}}"; \
    print_kv "REPO_CACHE_DIR" "{{REPO_CACHE_DIR}}"; \
    print_kv "UV_CACHE_DIR" "{{UV_CACHE_DIR}}"; \
    print_kv "RUFF_CACHE_DIR" "{{RUFF_CACHE_DIR}}"; \
    print_kv "WILY_CACHE" "{{WILY_CACHE}}"; \
    print_kv "WILY_CONFIG" "{{WILY_CONFIG}}"; \
    \
    print_section "command templates"; \
    print_kv "UV" "{{UV}}"; \
    print_kv "UV_RUN" "{{UV_RUN}}"; \
    print_kv "JSCPD" "{{JSCPD}}"; \
    \
    print_section "host tools"; \
    show_cmd "bash" bash --version; \
    show_cmd "uv" {{UV}} --version; \
    show_cmd "python3" python3 --version; \
    show_cmd "git" git --version; \
    show_cmd "node" node --version; \
    show_cmd "npx" npx --version; \
    show_cmd "trufflehog" trufflehog --version; \
    \
    print_section "project environment tools (via uv run)"; \
    show_uv_run_tool "python" python --version; \
    show_uv_run_tool "pytest" pytest --version; \
    show_uv_run_tool "ruff" ruff --version; \
    show_uv_run_tool "ty" ty --version; \
    show_uv_run_tool "import-linter" import-linter --help; \
    show_uv_run_tool "vulture" vulture --help; \
    show_uv_run_tool "radon" radon --help; \
    show_uv_run_tool "pip-audit" pip-audit --help; \
    show_uv_run_tool "showcov" showcov --help; \
    show_uv_run_tool "mkdocs" mkdocs --version; \
    \
    print_section "pytest settings"; \
    print_kv "PYTEST_DEV_WORKERS" "{{PYTEST_DEV_WORKERS}}"; \
    print_kv "PYTEST_DEV_DIST" "{{PYTEST_DEV_DIST}}"; \
    print_kv "PYTEST_DEV_THRESHOLD" "{{PYTEST_DEV_THRESHOLD}}"; \
    print_kv "PYTEST_QUIET_OPTS" "{{PYTEST_QUIET_OPTS}}"; \
    print_kv "PYTEST_LOG_OPTS" "{{PYTEST_LOG_OPTS}}"; \
    print_kv "PYTEST_DEBUG_OPTS" "{{PYTEST_DEBUG_OPTS}}"; \
    print_kv "PYTEST_FAST_EXPR" "{{PYTEST_FAST_EXPR}}"; \
    print_kv "PYTEST_FAILING_OPTS" "{{PYTEST_FAILING_OPTS}}"; \
    \
    print_section "discovered source dirs"; \
    just _list_src_dirs || true; \
    \
    print_section "discovered test dirs"; \
    just _list_test_dirs || true; \
  '
  @just _log_end env

# ----------------------------------------------------------------------
# Logging helpers
# ----------------------------------------------------------------------

[private]
_log_start NAME:
  @bash -euo pipefail -c 'if [ "{{VERBOSE}}" != "0" ]; then printf "\n=== START: %s ===\n" "{{NAME}}"; fi'

[private]
_log_end NAME:
  @bash -euo pipefail -c 'if [ "{{VERBOSE}}" != "0" ]; then printf "=== END: %s ===\n\n" "{{NAME}}"; fi'

[private]
_cache_dirs:
  @mkdir -p {{REPO_CACHE_DIR}} {{UV_CACHE_DIR}} {{RUFF_CACHE_DIR}}

[private]
_color_echo_ok NAME:
  @bash -euo pipefail -c '\
    if [ -t 1 ]; then \
      printf "\033[1;32m✓ %s\033[0m\n" "$1"; \
    else \
      printf "[ok] %s\n" "$1"; \
    fi' -- "{{NAME}}"

[private]
_color_echo_fail NAME:
  @bash -euo pipefail -c '\
    if [ -t 1 ]; then \
      printf "\033[1;31m✗ %s\033[0m\n" "$1"; \
    else \
      printf "[fail] %s\n" "$1"; \
    fi' -- "{{NAME}}"

[private]
_color_echo_warn MSG:
  @bash -euo pipefail -c '\
    if [ -t 2 ]; then \
      printf "\033[1;33m[warn]\033[0m %s\n" "$1" >&2; \
    else \
      printf "[warn] %s\n" "$1" >&2; \
    fi' -- "{{MSG}}"

# Quiet on success, print diagnostics on failure.
[private]
_lint_quiet NAME CHECK_CMD RUN_CMD HINT:
  @bash -euo pipefail -c '\
    name="$1"; \
    check_cmd="$2"; \
    run_cmd="$3"; \
    hint="$4"; \
    if ! bash -lc "$check_cmd" >/dev/null 2>&1; then \
      echo "[$name] ERROR: $hint" >&2; \
      exit 1; \
    fi; \
    set +e; \
    output="$(bash -lc "$run_cmd" 2>&1)"; \
    status=$?; \
    set -e; \
    if [ "$status" -ne 0 ]; then \
      echo "[$name] FAILED" >&2; \
      if [ -n "$output" ]; then \
        printf "\n%s\n" "$output" >&2; \
      fi; \
      exit "$status"; \
    fi \
  ' -- "{{NAME}}" {{quote(CHECK_CMD)}} {{quote(RUN_CMD)}} {{quote(HINT)}}

# Strict runner with verbose start/end logging
[private]
_run NAME CMD:
  @bash -euo pipefail -c '\
    if [ "{{VERBOSE}}" != "0" ]; then printf "\n=== START: %s ===\n" "$1"; fi; \
    bash -lc "$2"; \
    if [ "{{VERBOSE}}" != "0" ]; then printf "=== END: %s ===\n\n" "$1"; fi' -- "{{NAME}}" {{quote(CMD)}}

# Soft runner: brief on success, verbose on failure, continue after non-zero
[private]
_run_soft NAME CMD:
  @bash -euo pipefail -c '\
    name="$1"; cmd="$2"; \
    set +e; out="$(bash -lc "$cmd" 2>&1)"; status=$?; set -e; \
    if [ $status -eq 0 ]; then \
      if [ -t 1 ]; then \
        printf "\033[1;32m✓ %s\033[0m\n" "$name"; \
      else \
        printf "[ok] %s\n" "$name"; \
      fi; \
    else \
      if [ -t 1 ]; then \
        printf "\033[1;31m✗ %s\033[0m\n" "$name"; \
      else \
        printf "[fail] %s\n" "$name"; \
      fi; \
      printf "%s\n" "$out"; \
      if [ -t 2 ]; then \
        printf "\033[1;33m[warn]\033[0m continuing after failure in %s\n" "$name" >&2; \
      else \
        printf "[warn] continuing after failure in %s\n" "$name" >&2; \
      fi; \
    fi' -- "{{NAME}}" {{quote(CMD)}}

# ----------------------------------------------------------------------
# Workspace path discovery
# ----------------------------------------------------------------------

[private]
_list_package_dirs:
  @bash -euo pipefail -c '\
    if [ -d "{{PKG_DIR}}" ]; then \
      find "{{PKG_DIR}}" -mindepth 1 -maxdepth 1 -type d | sort; \
    fi'

[private]
_list_src_dirs:
  @bash -euo pipefail -c '\
    if [ -d "{{ROOT_DIR}}/src" ]; then printf "  %s\n" "{{ROOT_DIR}}/src"; fi; \
    if [ -d "{{PKG_DIR}}" ]; then \
      while IFS= read -r d; do \
        if [ -d "$d/src" ]; then printf "  %s\n" "$d/src"; fi; \
      done < <(find "{{PKG_DIR}}" -mindepth 1 -maxdepth 1 -type d | sort); \
    fi'

[private]
_list_test_dirs:
  @bash -euo pipefail -c '\
    if [ -d "{{ROOT_DIR}}/tests" ]; then printf "  %s\n" "{{ROOT_DIR}}/tests"; fi; \
    if [ -d "{{PKG_DIR}}" ]; then \
      while IFS= read -r d; do \
        if [ -d "$d/tests" ]; then printf "  %s\n" "$d/tests"; fi; \
      done < <(find "{{PKG_DIR}}" -mindepth 1 -maxdepth 1 -type d | sort); \
    fi'

# Resolve test directories from user selections.
# Accepts:
#   root          -> {{ROOT_DIR}}/tests
#   exact dir     -> packages/<name>/tests
#   suffix        -> packages/bvp-<suffix>/tests (fallback compatibility)
[private]
_resolve_test_selection *selection:
  #!/usr/bin/env bash
  set -euo pipefail

  if [ "$#" -eq 0 ]; then
    just _list_test_dirs
    exit 0
  fi

  mapfile -t pkg_dirs < <(just _list_package_dirs)

  for part in "$@"; do
    if [ "$part" = "root" ]; then
      path="{{ROOT_DIR}}/tests"
      if [ -d "$path" ]; then
        printf '%s\n' "$path"
        continue
      fi
      echo "[test] ERROR: root tests not found: $path" >&2
      exit 2
    fi

    found=""
    for pkg_dir in "${pkg_dirs[@]}"; do
      base="$(basename "$pkg_dir")"
      if [ "$base" = "$part" ] || [ "$base" = "bvp-$part" ]; then
        candidate="$pkg_dir/tests"
        if [ -d "$candidate" ]; then
          found="$candidate"
          break
        fi
      fi
    done

    if [ -z "$found" ]; then
      echo "[test] ERROR: no package test path matched selection: $part" >&2
      exit 2
    fi

    printf '%s\n' "$found"
  done

# ======================================================================
# Bootstrap
# ======================================================================

# Refresh .venv via `uv sync`
setup:
  @just _log_start setup
  @just _cache_dirs
  @bash -euo pipefail -c '\
    case "{{UV_SYNC_MODE}}" in \
      all) \
        {{UV}} --cache-dir {{UV_CACHE_DIR}} sync {{UV_SYNC_FLAGS}} --all-packages ;; \
      one) \
        if [ -z "{{PACKAGE}}" ]; then \
          echo "[setup] ERROR: PACKAGE is required when UV_SYNC_MODE=one" >&2; \
          exit 2; \
        fi; \
        {{UV}} --cache-dir {{UV_CACHE_DIR}} sync {{UV_SYNC_FLAGS}} --package "{{PACKAGE}}" ;; \
      *) \
        echo "[setup] ERROR: invalid UV_SYNC_MODE={{UV_SYNC_MODE}} (expected: all|one)" >&2; \
        exit 2 ;; \
    esac'
  @just _log_end setup

# ======================================================================
# lint / format / type-check
# ======================================================================

# Lint with `ruff check` and auto-fix where possible; use --no-fix to check only.
[group('code quality')]
[arg("no_fix", long, value="true")]
lint no_fix="false":
  @just _log_start lint
  @just _cache_dirs
  @bash -euo pipefail -c '\
    mapfile -t src_dirs < <(just _list_src_dirs); \
    mapfile -t test_dirs < <(just _list_test_dirs); \
    paths=("${src_dirs[@]}" "${test_dirs[@]}"); \
    if [ "${#paths[@]}" -eq 0 ]; then \
      echo "[lint] skipping: no source or test directories found"; \
      exit 0; \
    fi; \
    run_cmd="{{UV_RUN}} ruff check --cache-dir {{RUFF_CACHE_DIR}}"; \
    if [ "{{no_fix}}" = "true" ]; then \
      run_cmd="$run_cmd --no-fix"; \
    else \
      run_cmd="$run_cmd --fix"; \
    fi; \
    for p in "${paths[@]}"; do run_cmd="$run_cmd \"$p\""; done; \
    just _lint_quiet \
      lint \
      "{{UV_RUN}} ruff --version" \
      "$run_cmd" \
      "ruff not available in the project environment; add it to dev dependencies and run just setup" \
  '
  @just _log_end lint

# Format with `ruff format`; use --check to verify formatting only.
[group('code quality')]
[arg("check", long, value="true")]
format check="false":
  @just _log_start format
  @just _cache_dirs
  @bash -euo pipefail -c '\
    mapfile -t src_dirs < <(just _list_src_dirs); \
    mapfile -t test_dirs < <(just _list_test_dirs); \
    paths=("${src_dirs[@]}" "${test_dirs[@]}"); \
    if [ "${#paths[@]}" -eq 0 ]; then \
      echo "[format] skipping: no source or test directories found"; \
      exit 0; \
    fi; \
    run_cmd="{{UV_RUN}} ruff format --cache-dir {{RUFF_CACHE_DIR}}"; \
    if [ "{{check}}" = "true" ]; then \
      run_cmd="$run_cmd --check"; \
    fi; \
    for p in "${paths[@]}"; do run_cmd="$run_cmd \"$p\""; done; \
    just _lint_quiet \
      format \
      "{{UV_RUN}} ruff --version" \
      "$run_cmd" \
      "ruff not available in the project environment; add it to dev dependencies and run just setup" \
  '
  @just _log_end format

# Typecheck with `ty`
[group('code quality')]
typecheck:
  @just _log_start typecheck
  @bash -euo pipefail -c '\
    mapfile -t src_dirs < <(just _list_src_dirs); \
    mapfile -t test_dirs < <(just _list_test_dirs); \
    paths=("${src_dirs[@]}" "${test_dirs[@]}"); \
    if [ "${#paths[@]}" -eq 0 ]; then \
      echo "[typecheck] skipping: no source or test directories found"; \
      exit 0; \
    fi; \
    run_cmd="{{UV_RUN}} ty check"; \
    for p in "${paths[@]}"; do run_cmd="$run_cmd \"$p\""; done; \
    just _lint_quiet \
      typecheck \
      "{{UV_RUN}} ty --version" \
      "$run_cmd" \
      "ty not available in the project environment; add it to dev dependencies and run just setup" \
  '
  @just _log_end typecheck

# Lint import architecture (Import Linter)
[group('code quality')]
lint-imports:
  @just _log_start lint-imports
  @just _lint_quiet \
    lint-imports \
    "{{UV_RUN}} import-linter --help" \
    "{{UV_RUN}} import-linter --verbose --config {{IMPORTLINTER_CONFIG}}" \
    "import-linter not available in the project environment; add it to dev dependencies and run just setup"
  @just _log_end lint-imports

# Enforce explicit umbrella public API contract
[group('code quality')]
public-api:
  @just _log_start public-api
  @just _lint_quiet \
    public-api \
    "{{UV_RUN}} python --version" \
    "{{UV_RUN}} python scripts/check_public_api.py" \
    "python runtime not available in the project environment; run just setup"
  @just _log_end public-api

# Dead-code scan
[group('code quality')]
dead-code:
  @just _log_start dead-code
  @bash -euo pipefail -c '\
    mapfile -t src_dirs < <(just _list_src_dirs); \
    mapfile -t test_dirs < <(just _list_test_dirs); \
    paths=("${src_dirs[@]}" "${test_dirs[@]}"); \
    if [ "${#paths[@]}" -eq 0 ]; then \
      echo "[dead-code] skipping: no source or test directories found"; \
      exit 0; \
    fi; \
    run_cmd="{{UV_RUN}} vulture --min-confidence 61"; \
    for p in "${paths[@]}"; do run_cmd="$run_cmd \"$p\""; done; \
    just _lint_quiet \
      dead-code \
      "{{UV_RUN}} vulture --help" \
      "$run_cmd" \
      "vulture not available in the project environment; add it to dev dependencies and run just setup" \
  '
  @just _log_end dead-code

# Generate complexity report; use --raw for raw metrics or --strict to fail above threshold.
[group('code quality')]
[arg("raw", long, value="true")]
[arg("strict", long, value="true")]
complexity raw="false" strict="false" MIN_COMPLEXITY="11":
  @just _log_start complexity
  @bash -euo pipefail -c '\
    mapfile -t src_dirs < <(just _list_src_dirs); \
    if [ "${#src_dirs[@]}" -eq 0 ]; then \
      echo "[complexity] skipping: no source directories found"; \
      exit 0; \
    fi; \
    if [ "{{raw}}" = "true" ] && [ "{{strict}}" = "true" ]; then \
      echo "[complexity] ERROR: choose at most one of --raw or --strict" >&2; \
      exit 2; \
    fi; \
    base_check="{{UV_RUN}} radon --help"; \
    if [ "{{raw}}" = "true" ]; then \
      run_cmd="{{UV_RUN}} radon raw"; \
      for p in "${src_dirs[@]}"; do run_cmd="$run_cmd \"$p\""; done; \
      just _lint_quiet \
        complexity \
        "$base_check" \
        "$run_cmd" \
        "radon not available in the project environment; add it to dev dependencies and run just setup"; \
    elif [ "{{strict}}" = "true" ]; then \
      if ! bash -lc "$base_check" >/dev/null 2>&1; then \
        echo "[complexity] ERROR: radon not available in the project environment; add it to dev dependencies and run just setup" >&2; \
        exit 1; \
      fi; \
      run_cmd="{{UV_RUN}} radon cc -s -n {{MIN_COMPLEXITY}}"; \
      for p in "${src_dirs[@]}"; do run_cmd="$run_cmd \"$p\""; done; \
      set +e; \
      output="$(bash -lc "$run_cmd" 2>&1)"; \
      status=$?; \
      set -e; \
      if [ "$status" -ne 0 ]; then \
        echo "[complexity] FAILED" >&2; \
        [ -n "$output" ] && printf "\n%s\n" "$output" >&2; \
        exit "$status"; \
      fi; \
      if [ -n "$output" ]; then \
        echo "[complexity] FAILED: blocks at or above complexity threshold {{MIN_COMPLEXITY}}" >&2; \
        printf "\n%s\n" "$output" >&2; \
        exit 1; \
      fi; \
    else \
      run_cmd="{{UV_RUN}} radon cc -s -a"; \
      for p in "${src_dirs[@]}"; do run_cmd="$run_cmd \"$p\""; done; \
      bash -lc "$run_cmd"; \
    fi'
  @just _log_end complexity

# Duplication detection
[group('code quality')]
dup:
  @just _log_start dup
  @bash -euo pipefail -c '\
    mapfile -t src_dirs < <(just _list_src_dirs); \
    mapfile -t test_dirs < <(just _list_test_dirs); \
    patterns=(); \
    for p in "${src_dirs[@]}"; do patterns+=(--pattern "$p/**/*.py"); done; \
    for p in "${test_dirs[@]}"; do patterns+=(--pattern "$p/**/*.py"); done; \
    if [ "${#patterns[@]}" -eq 0 ]; then \
      echo "[dup] skipping: no source or test directories found"; \
      exit 0; \
    fi; \
    run_cmd="npx --yes jscpd@4.0"; \
    for arg in "${patterns[@]}"; do \
      run_cmd="$run_cmd $(printf "%q" "$arg")"; \
    done; \
    run_cmd="$run_cmd --reporters console"; \
    just _lint_quiet \
      dup \
      "npx --yes jscpd@4.0 --version" \
      "$run_cmd" \
      "jscpd not found; install node/npx correctly" \
  '
  @just _log_end dup

# ======================================================================
# Security / supply chain
# ======================================================================

# Secret scan with trufflehog (report-only; does not fail if tool missing)
[group('security')]
sec-secrets:
  @just _log_start sec-secrets
  @bash -euo pipefail -c '\
    if command -v trufflehog >/dev/null 2>&1; then \
      tmp_file="$(mktemp)"; \
      printf ".venv\nbuild\ndist\n.cache\n" > "$tmp_file"; \
      trufflehog filesystem . --exclude-paths "$tmp_file"; \
      rm -f "$tmp_file"; \
    else \
      echo "[sec-secrets] skipping: trufflehog not found on PATH"; \
    fi'
  @just _log_end sec-secrets

# Dependency scan with pip-audit
[group('security')]
sec-deps:
  @just _log_start sec-deps
  @just _lint_quiet \
    sec-deps \
    "{{UV_RUN}} pip-audit --help" \
    "{{UV_RUN}} pip-audit" \
    "pip-audit not available in the project environment; add it to dev dependencies and run just setup"
  @just _log_end sec-deps

# ======================================================================
# Testing
# ======================================================================

# Run pytest for all or selected package test suites.
[group('testing')]
[arg("fail", long, value="true")]
[arg("fast", long, value="true")]
[arg("failing", long, value="true")]
[arg("dev", long, value="true")]
[arg("quiet", long, value="quiet")]
[arg("logs", long, value="logs")]
[arg("debug", long, value="debug")]
[doc("""
Run pytest for all or selected package test suites.

Selection:
  *selection  Package directory names to test (for example: bvp-cli, bvp-cs).
              For compatibility, suffixes also work (for example: cli, cs) if a
              package directory named bvp-<suffix> exists.
              Use `root` for repo-level tests.
              Omit selection to run root tests plus all package test suites.

Behavior:
  --fail      Return pytest's exit status. When false, test failures do not fail the recipe.
  --fast      Exclude tests marked `slow`.
  --failing   Run only tests that failed in the previous pytest run (`--lf`).
  --dev       Enable `--testmon`, disable coverage, and enable xdist only when the
              collected test count meets the configured threshold.
  --quiet     Compact pytest output.
  --logs      Compact output plus live logs.
  --debug     Verbose pytest output.

Notes:
  --quiet, --logs, and --debug are mutually exclusive.
  The recipe always uses the repo root pytest config file.
  In MODE=ci, uv commands run with --locked --no-sync.
""")]
test fail="true" fast="false" dev="false" quiet="" logs="" debug="" failing="false" *selection:
  #!/usr/bin/env bash
  set -euo pipefail

  mode_count=0
  [ -n "{{quiet}}" ] && mode_count=$((mode_count + 1))
  [ -n "{{logs}}" ] && mode_count=$((mode_count + 1))
  [ -n "{{debug}}" ] && mode_count=$((mode_count + 1))

  if [ "$mode_count" -gt 1 ]; then
    echo "[test] ERROR: choose at most one of --quiet, --logs, or --debug" >&2
    exit 2
  fi

  mode="default"
  [ -n "{{quiet}}" ] && mode="quiet"
  [ -n "{{logs}}" ] && mode="logs"
  [ -n "{{debug}}" ] && mode="debug"

  mode_flags=()
  case "$mode" in
    default) ;;
    quiet) mode_flags=({{PYTEST_QUIET_OPTS}}) ;;
    logs) mode_flags=({{PYTEST_LOG_OPTS}}) ;;
    debug) mode_flags=({{PYTEST_DEBUG_OPTS}}) ;;
  esac

  extra_flags=()
  if [ "{{fast}}" = "true" ]; then
    extra_flags+=({{PYTEST_FAST_EXPR}})
  fi
  if [ "{{failing}}" = "true" ]; then
    extra_flags+=({{PYTEST_FAILING_OPTS}})
  fi

  mapfile -t test_paths < <(just _resolve_test_selection {{selection}})

  if [ "${#test_paths[@]}" -eq 0 ]; then
    echo "[test] ERROR: no test paths resolved" >&2
    exit 2
  fi

  for path in "${test_paths[@]}"; do
    if [ ! -d "$path" ]; then
      echo "[test] ERROR: test path not found: $path" >&2
      exit 2
    fi
  done

  args=({{UV_RUN}} pytest -c "{{PYTEST_CONFIG}}")
  args+=("${mode_flags[@]}")
  args+=("${extra_flags[@]}")

  if [ "{{dev}}" = "true" ]; then
    args+=(--testmon --no-cov)

    collect_args=({{UV_RUN}} pytest -c "{{PYTEST_CONFIG}}" --collect-only -q)
    collect_args+=("${extra_flags[@]}")
    collect_args+=("${test_paths[@]}")

    set +e
    collect_out="$("${collect_args[@]}" 2>&1)"
    collect_status=$?
    set -e

    if [ "$collect_status" -ne 0 ] && [ "$collect_status" -ne 5 ]; then
      echo "[test] collection failed while deciding whether to use xdist" >&2
      echo "$collect_out" >&2
      exit "$collect_status"
    fi

    test_count="$(printf '%s\n' "$collect_out" | grep -Ec '::[^[:space:]]+$' || true)"

    if [ "${test_count:-0}" -ge "{{PYTEST_DEV_THRESHOLD}}" ]; then
      args+=(-n "{{PYTEST_DEV_WORKERS}}" --dist "{{PYTEST_DEV_DIST}}")
    fi
  fi

  args+=("${test_paths[@]}")

  printf '%s\n' "${args[*]}"
  set +e
  "${args[@]}"
  status=$?
  set -e

  if [ "{{fail}}" = "true" ]; then
    exit "$status"
  fi

[group('testing')]
test-fast *selection:
  @just test --fast {{selection}}

[group('testing')]
test-dev *selection:
  @just test --dev {{selection}}

[group('testing')]
test-failing *selection:
  @just test --failing {{selection}}

[group('testing')]
test-debug *selection:
  @just test --debug {{selection}}

# ======================================================================
# Test Quality
# ======================================================================

# Show coverage results; use --lines for uncovered-line detail.
[group('test quality')]
[arg("lines", long, value="true")]
cov lines="false":
  @just _log_start cov
  @bash -euo pipefail -c '\
    if {{UV_RUN}} showcov --help >/dev/null 2>&1; then \
      if [ "{{lines}}" = "true" ]; then \
        {{UV_RUN}} showcov report --lines --code --context 2; \
      else \
        {{UV_RUN}} showcov report --summary --no-lines --no-branches; \
      fi; \
    else \
      echo "[cov] skipping: showcov not found"; \
    fi'
  @just _log_end cov

# ======================================================================
# Documentation
# ======================================================================

# Build docs; use --serve to launch the local server.
# Use --open to open a browser after the server starts.
[group('documentation')]
[arg("serve", long, value="true")]
[arg("open", long, value="true")]
docs serve="false" open="false":
  @just _log_start docs
  @bash -euo pipefail -c '\
    if ! {{UV_RUN}} mkdocs --version >/dev/null 2>&1; then \
      echo "[docs] skipping: mkdocs not found"; \
      exit 0; \
    fi; \
    if [ "{{serve}}" = "true" ]; then \
      if [ "{{open}}" = "true" ]; then \
        if [ -t 1 ] && command -v python3 >/dev/null 2>&1; then \
          ( sleep 2; python3 -m webbrowser http://127.0.0.1:8000 >/dev/null 2>&1 || true ) & \
        else \
          echo "[docs] browser open requested, but environment is non-interactive or python3 is unavailable"; \
        fi; \
      fi; \
      {{UV_RUN}} mkdocs serve --livereload; \
    else \
      {{UV_RUN}} mkdocs build; \
    fi'
  @just _log_end docs

# ======================================================================
# Build, packaging, publishing
# ======================================================================

# Build Python artifacts with `uv build`
[group('production')]
build:
  @just _log_start build
  @just _lint_quiet \
    build \
    "{{UV}} --version" \
    "{{UV}} --cache-dir {{UV_CACHE_DIR}} build" \
    "uv is not available on PATH"
  @just _log_end build

# Publish to PyPI using `uv publish`
[group('production')]
publish:
  @just _log_start publish
  @just _lint_quiet \
    publish \
    "{{UV}} --version" \
    "{{UV}} --cache-dir {{UV_CACHE_DIR}} publish" \
    "uv is not available on PATH"
  @just _log_end publish

# ======================================================================
# Cleaning / maintenance
# ======================================================================

# Remove build/test artifacts but keep caches and the virtual environment.
[group('cleaning')]
clean:
  #!/usr/bin/env bash
  set -euo pipefail
  just _log_start clean
  find . -name '__pycache__' -type d -prune -exec rm -rf '{}' +
  rm -rf .pytest_cache .mypy_cache .pytype || true
  rm -rf .coverage .coverage.* coverage.xml htmlcov || true
  rm -rf .import_linter_cache .ropefolder .ropeproject || true
  rm -rf dist build logs || true
  rm -rf .hypothesis mutants || true
  just _log_end clean

# Remove tool caches but keep build artifacts and the virtual environment.
[group('cleaning')]
clean-cache:
  #!/usr/bin/env bash
  set -euo pipefail
  just _log_start clean-cache
  if command -v {{UV}} >/dev/null 2>&1; then
    {{UV}} --cache-dir {{UV_CACHE_DIR}} cache prune || true
  fi
  rm -rf {{REPO_CACHE_DIR}} || true
  rm -rf {{WILY_CACHE}} || true
  just _log_end clean-cache

# Remove caches/build artifacts but keep the virtual environment.
[group('cleaning')]
clean-all: clean clean-cache
  @:

# Remove the virtual environment and other heavyweight local state.
[group('cleaning')]
distclean: clean-all
  #!/usr/bin/env bash
  set -euo pipefail
  just _log_start distclean
  rm -rf .venv || true
  just _log_end distclean

# Stash untracked (non-ignored) files (used by `scour`)
[group('cleaning')]
stash-untracked:
  @just _log_start stash-untracked
  @bash -euo pipefail -c '\
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
      msg="scour:untracked:$(date -u +%Y%m%dT%H%M%SZ)"; \
      if git ls-files --others --exclude-standard --directory --no-empty-directory | grep -q .; then \
        git ls-files --others --exclude-standard -z | xargs -0 git stash push -m "$msg" -- >/dev/null; \
        echo "Stashed untracked (non-ignored) files as: $msg"; \
      else \
        echo "No untracked (non-ignored) paths to stash."; \
      fi; \
    else \
      echo "[stash-untracked] not a git repository; skipping"; \
    fi'
  @just _log_end stash-untracked

# Remove git-ignored files/dirs while keeping .venv
[group('cleaning')]
scour:
  @just _log_start scour
  @just clean-all
  @just stash-untracked
  @bash -euo pipefail -c '\
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
      git clean -fXd -e .venv; \
    else \
      echo "[scour] not a git repository; skipping git clean"; \
    fi'
  @just _log_end scour

# ======================================================================
# Composite flows
# ======================================================================

[group('convenience')]
quality-fix:
  @just _log_start quality-fix
  @just _run_soft lint "just lint"
  @just _run_soft format "just format"
  @just _run_soft typecheck "just typecheck"
  @just _run_soft lint-imports "just lint-imports"
  @just _run_soft public-api "just public-api"
  @just _log_end quality-fix

[group('convenience')]
quality-check:
  @just _log_start quality-check
  @just _run_soft lint "just lint --no-fix"
  @just _run_soft format "just format --check"
  @just _run_soft typecheck "just typecheck"
  @just _run_soft lint-imports "just lint-imports"
  @just _run_soft public-api "just public-api"
  @just _log_end quality-check

# Run setup, auto-fixable checks, fast tests, and coverage.
[group('convenience')]
fix:
  @just _log_start fix
  @just _run_soft setup "just setup"
  @just quality-fix
  @just test --fast
  @just cov
  @just _log_end fix

# Run non-mutating checks, tests, and coverage.
[group('convenience')]
check:
  @just _log_start check
  @just quality-check
  @just test
  @just cov
  @just _log_end check

# CI-oriented flow: locked environment, non-mutating checks, tests, coverage.
[group('convenience')]
ci:
  @just _log_start ci
  @MODE=ci just setup
  @MODE=ci just quality-check
  @MODE=ci just test
  @MODE=ci just cov
  @just _log_end ci

