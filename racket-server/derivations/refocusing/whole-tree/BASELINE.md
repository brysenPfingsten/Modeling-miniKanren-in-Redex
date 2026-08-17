# Whole-tree Phase 0 baseline

This note freezes the read-only evidence collected on 2026-08-17 before
canonical consolidation began.  It describes the state at the grammatical
marked-column checkpoint `7de07fb`; later commits on the research branch do
not revise these counts or retroactively change this baseline.

The file-by-file retention and retirement decisions are maintained in
[`RETENTION.md`](RETENTION.md).  This note records state and test evidence,
not a second disposition ledger.

## Worktrees and refs

At Phase 0 exactly two worktrees were registered:

| Worktree | Branch and full HEAD | Phase 0 status |
|---|---|---|
| `/Users/jhemann/Code/Modeling-miniKanren-in-Redex` | `language-refactor` at `27c5520022d0726f95a6be196b07bf8034196c6f` | Dirty: six unstaged tracked files and seven untracked files; no staged changes. |
| `/Users/jhemann/.codex/worktrees/91c0/Modeling-miniKanren-in-Redex` | `codex/whole-tree-redex-column` at `7de07fb56d49681321926b37976fd24d87987fe9` | Clean. |

The pilot ancestry was strictly linear:

```text
origin/language-refactor
  999b25c09b9676c58144cdb1f212d73ec5156e30
    -> a6d009a  Add model-backed miniKanren runner library
    -> 27c5520  Checkpoint whole-tree refocusing spike
         -> 6 commits
         -> 39b985320aca3b4b3d3a67debc1270de95c79e45
              Document the whole-tree pipeline verdict
              -> 12 commits
              -> 7de07fb56d49681321926b37976fd24d87987fe9
                   Make focus selection wholly grammatical
```

The corresponding left/right commit counts were `0/6` from `27c5520` to
`39b9853`, `0/12` from `39b9853` to `7de07fb`, and `0/18` from `27c5520` to
`7de07fb`.

Both experimental refs were local-only at the baseline:

- `codex/whole-tree-pipeline-pilot` at `39b9853`;
- `codex/whole-tree-redex-column` at `7de07fb`.

A read-only remote query returned no branch of either name.  The same query
showed that Brysen's live `main` was
`5af39d84d64bc960fa2255467c0249e72505aa67`, while both the local `main` and
the local remote-tracking ref `origin/main` were still
`73ba2bb099c50a72a10eaab6fb507e1f0728fe82`.  No fetch was performed, so the
stale local ref was not advanced during baseline collection.

## Research gates at `7de07fb`

| Artifact | Command | Phase 0 result |
|---|---|---:|
| Concrete Redex marked column | `racket -y racket-server/derivations/refocusing/whole-tree-redex-column/tests/run.rkt` | 70/70 |
| Parameterized `P[Ktoy]` / `P[Kmk]` marked column | `racket -y racket-server/derivations/refocusing/whole-tree-redex-column/pk/tests/run.rkt` | 47/47 |
| Handwritten vertical pipeline pilot | `racket -y racket-server/derivations/refocusing/whole-tree-pipeline-pilot/tests/run.rkt` | 44/44 |
| Broad frozen whole-tree spike | `racket -y racket-server/derivations/refocusing/whole-tree-spike/run.rkt` | 16/16 |

The canonical marked transcript also regenerated with a byte-identical diff:

```sh
racket -y racket-server/derivations/refocusing/whole-tree-redex-column/pk/export-traces.rkt \
  | diff - racket-server/derivations/refocusing/whole-tree-redex-column/pk/TRACES.md
```

The command exited successfully with no output.  These are the immutable
`7de07fb` results.  Tests added by later consolidation checkpoints have their
own checkpoint counts and are not included here.

## Production-focused baseline

The production checkout was tested in place without changing its dirty state.
The passing focused results were:

- `raco test racket-server/tests/search-lattice-tests.rkt`: 25/25;
- `raco test racket-server/tests/determinism-overlap-tests.rkt`: 4/4;
- `raco test racket-server/tests/stabilization-gates-tests.rkt`: exit 0
  (RackUnit reported three successes and no failures or errors);
- `raco test racket-server/tests/property-core.rkt`: exit 0;
- `racket -y racket-server/derivations/refocusing/tests/run.rkt`: 7/7 on
  the dirty worktree's vocabulary/`rail-late` bridge repair;
- `npm --prefix frontend test`: 37/37.

The 7/7 refocusing result belongs to the uncommitted repaired worktree, not to
an assertion that clean `27c5520` already contained those bridge renames.

The following failures were classified as environmental baseline failures:

- `raco test racket-server/tests/test-all-headless.rkt` stopped because the
  local Racket installation could not resolve `hosted-minikanren`;
- `raco test racket-server/tests/property-non-core.rkt` completed four tests
  successfully and then encountered the same missing collection;
- `raco test racket-server/tests/model-example-matrix-tests.rkt` reported one
  success and one failure because example initialization encountered the same
  missing collection;
- the isolated program-runner suite reported zero successes, one failure, and
  five errors, all downstream of the missing collection;
- the isolated miniKanren-library suite stopped at the same missing
  collection.

The environment was Racket 9.3 CS, and `raco pkg show hosted-minikanren`
reported no installation-wide or user-specific package.  The repository
Dockerfile installs that package, but Phase 0 deliberately did not mutate the
local package environment.  The GUI `test-all.rkt` lane was not run because it
invokes `rackunit/gui` and `test/gui`; this is recorded as not run, not as a
pass or failure.

## Dirty production summary and no-change boundary

The six tracked modifications comprised the root/semantics reading-order
documents, the older refocusing note and two bridge modules, and the production
core language.  The seven untracked files comprised two research-direction
documents, one byte-identical Emacs autosave, and the four-file superseded
`stream-spike` oracle.  The autosave and working `NOTES.md` had the same size
and SHA-256 digest; no unique text existed only in the autosave.

See [`RETENTION.md`](RETENTION.md) for the semantic classification, canonical
destinations, and retirement gates for this WIP and the older research lanes.

Phase 0 did not edit, stage, stash, switch, reset, clean, delete, or create a
ref in the production worktree.  It did not install dependencies or fetch the
remote.  Post-test status, diffstat, untracked paths, and recorded untracked
file hashes matched the pre-test snapshot.  The production worktree is outside
the canonical-consolidation mutation boundary until the marked/lean Q and
naturality acceptance work is complete.
