#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/run_search_lattice_checkpoint.sh [--recursive]

Run the standard search-lattice checkpoint gate from the repository root.

  --recursive  Also run the redundant recursive-discovery wiring audit under
               a third fresh compiled root. This is not part of the canonical
               semantic count.
EOF
}

recursive_mode=no
case "$#" in
  0)
    ;;
  1)
    case "$1" in
      --recursive)
        recursive_mode=yes
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
current_root="$(pwd -P)"
if ! git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "error: the checkpoint runner must be invoked from a Git worktree" >&2
  exit 2
fi
git_root="$(cd "$git_root" && pwd -P)"

if [[ "$current_root" != "$git_root" ]] || [[ "$git_root" != "$script_root" ]]; then
  echo "error: invoke scripts/run_search_lattice_checkpoint.sh from the repository root" >&2
  echo "expected: $script_root" >&2
  echo "current:  $current_root" >&2
  exit 2
fi

derivation_dir="racket-server/derivations/search-lattice"
canonical_aggregate="$derivation_dir/tests/all.rkt"
production_aggregate="racket-server/tests/search-lattice/all.rkt"

for required_path in "$canonical_aggregate" "$production_aggregate"; do
  if [[ ! -f "$required_path" ]]; then
    echo "error: required checkpoint input does not exist: $required_path" >&2
    exit 2
  fi
done

report_root="$(mktemp -d "${TMPDIR:-/tmp}/search-lattice-checkpoint-reports.XXXXXX")"
cleanup_reports() {
  rm -rf -- "$report_root"
}
trap cleanup_reports EXIT

snapshot_git_state() {
  local prefix="$1"
  git diff --binary --no-ext-diff > "$prefix.worktree.diff"
  git diff --cached --binary --no-ext-diff > "$prefix.index.diff"
  git status --porcelain=v1 --untracked-files=no > "$prefix.status"
}

snapshot_git_state "$report_root/before"

last_lane_status=not-run
last_lane_elapsed=not-run
run_lane() {
  local lane_name="$1"
  local output_path="$2"
  shift 2
  local started_at
  local finished_at
  local pipeline_status
  local command_status
  local tee_status

  echo
  echo "== $lane_name =="
  started_at="$(date +%s)"
  set +e
  "$@" 2>&1 | tee "$output_path"
  pipeline_status=("${PIPESTATUS[@]}")
  set -e
  finished_at="$(date +%s)"

  command_status="${pipeline_status[0]}"
  tee_status="${pipeline_status[1]}"
  last_lane_status="$command_status"
  if [[ "$command_status" -eq 0 && "$tee_status" -ne 0 ]]; then
    last_lane_status="$tee_status"
  fi
  last_lane_elapsed="$((finished_at - started_at))"
  echo "lane-result: exit=$last_lane_status elapsed=${last_lane_elapsed}s"

  if [[ "$last_lane_status" -ne 0 ]]; then
    echo "error: checkpoint runner stopped after the first failing lane: $lane_name" >&2
    exit "$last_lane_status"
  fi
}

extract_test_count() {
  awk '
    /^[[:space:]]*[0-9]+ tests? passed[[:space:]]*$/ {
      line = $0
    }
    END {
      if (line == "") {
        exit 1
      }
      sub(/^[[:space:]]*/, "", line)
      split(line, fields, /[[:space:]]+/)
      print fields[1]
    }
  ' "$1"
}

derivation_compiled_root="$(mktemp -d "${TMPDIR:-/tmp}/search-lattice-derivations-compiled.XXXXXX")"
echo "Derivation compiled root: $derivation_compiled_root"

canonical_log="$report_root/canonical.log"
run_lane \
  "canonical derivation aggregate" \
  "$canonical_log" \
  env PLTCOMPILEDROOTS="$derivation_compiled_root" \
  raco test "$canonical_aggregate"
canonical_status="$last_lane_status"
canonical_elapsed="$last_lane_elapsed"
if ! canonical_count="$(extract_test_count "$canonical_log")"; then
  echo "error: could not read the canonical derivation test count" >&2
  exit 1
fi

derivation_modules=()
while IFS= read -r module_path; do
  derivation_modules+=("$module_path")
done < <(rg --files -g '*.rkt' "$derivation_dir" | LC_ALL=C sort)
compile_module_count="${#derivation_modules[@]}"
if [[ "$compile_module_count" -eq 0 ]]; then
  echo "error: the derivation compile sweep found no .rkt modules" >&2
  exit 1
fi

compile_helper="$report_root/compile-all.rkt"
printf '%s\n' \
  '#lang racket/base' \
  '' \
  '(require compiler/compilation-path' \
  '         compiler/compile-file' \
  '         racket/file' \
  '         racket/match' \
  '         syntax/modread)' \
  '' \
  '(match (vector->list (current-command-line-arguments))' \
  '  [(cons root-string source-strings)' \
  '   (define root (path->complete-path root-string))' \
  '   (define source-count (length source-strings))' \
  '   (define compile-namespace (make-base-namespace))' \
  '   (define compiled-count' \
  '     (parameterize ([current-namespace compile-namespace])' \
  '       (for/sum ([source-string (in-list source-strings)]' \
  '                 [module-index (in-naturals 1)])' \
  '         (define source (path->complete-path source-string))' \
  '         (define destination' \
  '           (get-compilation-bytecode-file' \
  '            source' \
  '            #:roots (list root)' \
  '            #:default-root root))' \
  '         (make-parent-directory* destination)' \
  '         (printf "[~a/~a] compile-file ~a\n"' \
  '                 module-index source-count source-string)' \
  '         (with-module-reading-parameterization' \
  '          (lambda ()' \
  '            (compile-file source destination)))' \
  '         (unless (file-exists? destination)' \
  '           (raise-user-error' \
  '            (format "compile target was not created: ~a" destination)))' \
  '         1)))' \
  '   (unless (= compiled-count source-count)' \
  '     (raise-user-error "not every discovered module was compiled"))' \
  '   (printf "compiled-targets=~a\n" compiled-count)]' \
  '  [_ (raise-user-error "expected a compiled root and at least one module")])' \
  > "$compile_helper"

compile_log="$report_root/compile.log"
run_lane \
  "compile-only derivation module sweep ($compile_module_count modules)" \
  "$compile_log" \
  env PLTCOMPILEDROOTS="$derivation_compiled_root:" \
  racket "$compile_helper" \
  "$derivation_compiled_root" \
  "${derivation_modules[@]}"
compile_status="$last_lane_status"
compile_elapsed="$last_lane_elapsed"
compiled_target_count="$(awk -F= '/^compiled-targets=[0-9]+$/ { count = $2 } END { print count }' "$compile_log")"
if [[ "$compiled_target_count" != "$compile_module_count" ]]; then
  echo "error: compile-only sweep did not report every discovered module" >&2
  exit 1
fi

production_compiled_root="$(mktemp -d "${TMPDIR:-/tmp}/search-lattice-production-compiled.XXXXXX")"
echo "Production compiled root: $production_compiled_root"

production_log="$report_root/production.log"
run_lane \
  "independent production search-lattice aggregate" \
  "$production_log" \
  env PLTCOMPILEDROOTS="$production_compiled_root" \
  raco test "$production_aggregate"
production_status="$last_lane_status"
production_elapsed="$last_lane_elapsed"
if ! production_count="$(extract_test_count "$production_log")"; then
  echo "error: could not read the production test count" >&2
  exit 1
fi

recursive_compiled_root=not-run
recursive_status=not-run
recursive_elapsed=not-run
recursive_count=not-run
if [[ "$recursive_mode" == yes ]]; then
  recursive_compiled_root="$(mktemp -d "${TMPDIR:-/tmp}/search-lattice-recursive-compiled.XXXXXX")"
  echo "Recursive-discovery compiled root: $recursive_compiled_root"
  recursive_log="$report_root/recursive.log"
  run_lane \
    "REDUNDANT recursive discovery audit (not the canonical aggregate)" \
    "$recursive_log" \
    env PLTCOMPILEDROOTS="$recursive_compiled_root" \
    raco test -x "$derivation_dir"
  recursive_status="$last_lane_status"
  recursive_elapsed="$last_lane_elapsed"
  if ! recursive_count="$(extract_test_count "$recursive_log")"; then
    echo "error: could not read the redundant recursive-discovery test count" >&2
    exit 1
  fi
fi

diff_log="$report_root/diff-check.log"
run_lane "git diff --check" "$diff_log" git diff --check
diff_status="$last_lane_status"
diff_elapsed="$last_lane_elapsed"

snapshot_git_state "$report_root/after"
worktree_changed=no
for snapshot_part in worktree.diff index.diff status; do
  if ! cmp -s \
    "$report_root/before.$snapshot_part" \
    "$report_root/after.$snapshot_part"; then
    worktree_changed=yes
  fi
done

if [[ "$worktree_changed" == yes ]]; then
  echo >&2
  echo "error: testing changed tracked or staged repository state" >&2
  echo "tracked/staged worktree changed during testing: yes" >&2
  echo "tracked/staged status before:" >&2
  sed 's/^/  /' "$report_root/before.status" >&2
  echo "tracked/staged status after:" >&2
  sed 's/^/  /' "$report_root/after.status" >&2
  exit 1
fi

echo
echo "== Search-lattice checkpoint summary =="
echo "canonical derivation: exit=$canonical_status elapsed=${canonical_elapsed}s tests=$canonical_count"
echo "compile-only sweep: exit=$compile_status elapsed=${compile_elapsed}s modules=$compiled_target_count"
echo "independent production: exit=$production_status elapsed=${production_elapsed}s tests=$production_count"
if [[ "$recursive_mode" == yes ]]; then
  echo "redundant recursive discovery: exit=$recursive_status elapsed=${recursive_elapsed}s reported-repeated-tests=$recursive_count"
fi
echo "git diff --check: exit=$diff_status elapsed=${diff_elapsed}s"
echo "derivation compiled root: $derivation_compiled_root"
echo "production compiled root: $production_compiled_root"
if [[ "$recursive_mode" == yes ]]; then
  echo "recursive-discovery compiled root: $recursive_compiled_root"
fi
echo "tracked/staged worktree changed during testing: $worktree_changed"
