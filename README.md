# Modeling-miniKanren-in-Redex

The visualizer offers a **Strict scheduler lattice** with No Interleave,
Flip-Flop, and Railroad, plus the **Strict reference (Flip)** view of the
[S/E/N research matrix](racket-server/derivations/strict-search/matrix/README.md).
It defaults to Railroad. All choices use strict matrix reduction semantics
and retain their actual configurations in session history. Both operands and
bind residuals mature before commitment; only Delay suspends work.

## **Docker Setup**

Follow the steps below to clone this repository, set up Docker, and run the application.

### **Prerequisites**
Before you begin, ensure you have the following installed:

- **[Docker](https://docs.docker.com/get-docker/)** – to run containers
- **[Docker Compose](https://docs.docker.com/compose/install/)** – to manage multi-container applications

---

## **Installation and Setup**

Open a terminal and run:
```sh
git clone https://github.com/brysenPfingsten/Modeling-miniKanren-in-Redex.git
cd Modeling-miniKanren-in-Redex
docker login
docker compose -f docker-compose.dev.yml up --build
```
Finally, visit [localhost:5173](http://localhost:5173).

### Docker Compose Notes

- `docker-compose.dev.yml` is the supported dev stack (`frontend` on `5173`, backend servlet on `5000`).
- In the dev frontend container, API calls are expected to go through the Vite proxy (`/api -> racket-server:5000`).
- `docker-compose.yaml` binds frontend on `8080`; if that port is in use, startup will fail with an "address already in use" error.

## **Test Lanes**

Use the [test-lane inventory](racket-server/tests/TEST-LANES.md) for focused
commands and evidence boundaries. Run from the repository root with the
installed Racket dependencies and an isolated compiled root:

```sh
export PLTCOMPILEDROOTS=/private/tmp/full-strict-checks:
```

### **1) App/API and native rendering**

```sh
racket -y -l raco -- test racket-server/tests/test-app.rkt racket-server/tests/search-runtime-tests.rkt
racket -y -l raco -- test racket-server/tests/visible-contract-tests.rkt racket-server/tests/search-picture-tests.rkt
racket -y racket-server/tests/ui-payload-smoke.rkt
```

These gates check native lattice and strict steps, paused versus completed
Frontiers, exact history, candidate versus committed answers, source/state
highlighting, and retained common/private introductions.

### **2) Compiler profiles and source modes**

```sh
racket -y -l raco -- test racket-server/tests/test-transpiler.rkt racket-server/tests/example-compat-tests.rkt
racket -y -l raco -- test racket-server/tests/model-example-matrix-tests.rkt
```

The profile gate exercises twelve combinations: two conjunction associations,
two disjunction associations, and three delay placements. A finite relation
program follows the same named strict S transitions through direct sessions
and HTTP, including its rendered micro form. These twelve profiles are
distinct from the twelve call-free S/E/N feature cells.

### **3) Automatic consumer and library**

```sh
racket -y -l raco -- test racket-server/tests/program-runner-tests.rkt
racket -y -l raco -- test racket-server/tests/minikanren-library-tests.rkt
```

The driver checks cover completed Frontier boundaries, answer limits, retained
surplus answers, step caps, host reification, and explicit lattice scheduler
selection. Direct APIs default to Strict Search; the GUI explicitly selects
its lattice default.

### **4) Strict derivations and representation matrix**

```sh
racket -y -l raco -- test racket-server/derivations/strict-search/all.rkt
```

Covers the retained-scope interpreter, corresponding machines, registerization
and first compression, plus twelve native call-free S/E/N feature cells and
three full relation-program cells through source, data stages and finite Big.
Start with the [strict derivation guide](racket-server/derivations/strict-search/README.md)
for artifact roles, configuration-level evidence and remaining proofs.

### **5) Frontend and aggregate status**

```sh
npm --prefix frontend test
npm --prefix frontend run lint
npm --prefix frontend run build
```

`racket-server/tests/test-all-headless.rkt` aggregates strict research, native
lattice source suites, and application gates. The lattice aggregate also
includes the separate [distribution comparison](racket-server/derivations/distributed-search/README.md).
Source-relative lattice checks do not establish
strict-interpreter correspondence. See the test-lane inventory for the latest
completed validation and any checks still running.

## **Backend Init Contract**

The GUI/API boundary selects each run structurally.

`POST /api/post/init` accepts:

- `text`
- `sourceMode` = `"mini"` or `"micro"`
- optional `compileProfile` when `sourceMode = "mini"`
- optional `searchStrategy`, either:
  - `{ "scheduler": "rail" }` for the strict scheduler lattice, with `"dfs"`, `"flip"`, or `"rail"`
  - `{ "model": "strict" }` for the existing strict reference (Flip)

Omitting the selection uses Strict Search at the API/library boundary. The GUI
defaults to Strict scheduler lattice and explicitly sends `{ "scheduler": "rail" }`.
The reference is not a fourth scheduler. Switching views
preserves the chosen lattice scheduler and source settings; runtime and
compilation controls freeze during execution.

`compileProfile` controls conjunction/disjunction association and explicit
delay placement independently of runtime scheduling. Both families share
compiled goals, relation definitions, HTML source IDs, and query metadata.
Every choice initializes the same strict configuration:

```text
(program Γ (commit (eval (Owners) query-goal initial-state)))
```

The backend checks the selected grammar and well-formedness and records its
named reductions. No running configuration is converted between families.
Relation expansion adds no implicit Delay.

Payload status distinguishes `running`, `paused`, `complete`, and `stuck`.
At a paused `More(Delay(...))` Frontier, the next manual step records public
`advance` before its source contractions, for every scheduler. Internal
`force-delay` remains a reduction. Completed payloads retain Done/Last. GUI stepping
ignores the source `run n` limit; automatic consumption is a library operation.

## **Direct Library Surface**

If you want to run programs without the site, import
`racket-server/src/minikanren.rkt` and call `run-source` or
`run-source->answers` directly.

```racket
#lang racket

(require (file "racket-server/src/minikanren.rkt"))

(run-source->answers
 "(defrel (same x y)
    (== x y))
  (run* (q)
    (same q 'cat))")
;; => '(#hasheq((sym . "cat")))
```

The automatic adapter accepts the same source and compilation settings as the app,
plus consumption limits:

- `#:source-mode` (`"mini"` or `"micro"`)
- `#:compile-profile` for mini source
- `#:search-strategy`: `(strict-search)` by default, or
  `(search-strategy "dfs")`, `(search-strategy "flip")`, `(search-strategy "rail")`
- `#:step-cap` to bound diverging programs
- `#:answer-limit` to stop at a completed Frontier boundary with enough answers

The adapter saves the selected family's native configuration. Automatic answer
limits live in `minikanren.rkt` as a driver policy. For a positive limit the
driver reaches the next exposed Delay or terminal Frontier before testing the count;
in Strict Search this finishes eager evaluation and the entire commitment.
It leaves the next exposed Delay unforced and also stops on completion with
fewer answers. A zero limit returns immediately without stepping.
For lattice execution this intentionally continues past committed answers;
an unguarded residual can prevent reaching the next Delay and exhaust the step cap.

Returned answer lists contain at most the requested number. The saved
configuration and its picture retain the whole Frontier, including any surplus
answers in the final round. Manual session stepping, including the GUI, does
not enforce an answer limit. Source `run n` metadata does not limit that manual
execution; the Racket `run` binding below passes `n` to the automatic driver.

`minikanren.rkt` also provides `defrel`, `run`, and `run*` bindings for the mini
surface syntax, backed by this project's modeled Redex semantics.

`run*` runs the modeled search to completion and returns reified answers.
`run n ...` returns the first `n` answers after finishing the first round that
has accumulated enough. It leaves the next exposed Delay unforced and never
stops partway through commitment.

```racket
#lang racket

(require (file "racket-server/src/minikanren.rkt"))

(defrel (same x y)
  (== x y))

(run* (q)
  (same q 'cat))
;; => '(cat)

(run 2 (q)
  (conde
    [(== q 'a)]
    [(== q 'b)]
    [(== q 'c)]))
;; => '(a b)
```

Important limitation:
- relation definitions are tracked per file/module, so keep the `defrel`s and
  the corresponding `run`/`run*` in the same source file unless you use an
  explicit evaluator object

For initialization, individual steps, and history without automatic consumption,
use `racket-server/src/program-runner.rkt`: `open-source` or `open-forms`, followed
by `model-session-step`, `model-session-back`, or `model-session-reset`.
`minikanren.rkt` also re-exports this session API; its automatic driver uses the
same public operations as the GUI.

## **Semantics Reading Order**

If you are studying the repo as a semantics artifact, use this order:

1. [Semantics organization](docs/semantics-ladder.md): independent compiler,
   representation, feature and derivation-stage choices; application flow.
2. [Strict-search guide](racket-server/derivations/strict-search/README.md) and
   [correction log](racket-server/derivations/strict-search/CORRECTIONS.md):
   current inventory and why its semantic boundaries matter.
3. [Retained scope](racket-server/derivations/strict-search/retained-scope/README.md):
   source/interpreter, CPS, defunctionalization, machine maps, registers and
   prescribed compression spans.
4. [S/E/N matrix](racket-server/derivations/strict-search/matrix/README.md):
   native feature and full relation cells, allocation maps, data stages and Big.
5. [Policy boundary](docs/semantic-policy-matrix.md) and
   [distributed source](racket-server/derivations/distributed-search/README.md):
   retained alternatives and their distinct observations.

## **Current Runtime Surface**

The default GUI executes strict Railroad from
[`matrix/scheduler-source.rkt`](racket-server/derivations/strict-search/matrix/scheduler-source.rkt).
No Interleave changes the strict delayed-merge scheduling rule. Flip-Flop
reuses the existing strict source, and Railroad adds `mplusR` and eager
`YieldR` to retain branch orientation. These runtime choices remain separate
from the twelve compiler profiles.

The separate Strict reference (Flip) view executes the same full S source as
Flip-Flop in
[`matrix/full-source.rkt`](racket-server/derivations/strict-search/matrix/full-source.rkt).
The historical name “Search/rail” in strict derivation documents refers to
that strict Search feature, not the oriented Railroad scheduler. E/N have
native source, data-machine and finite Big implementations and structural
maps; there is currently no S/E/N GUI selector.

All GUI schedulers mature both disjunction operands and eager Search tails
and bind residuals before commitment; only Delay suspends. A right-oriented
merge matures its right operand first, preserving the order represented by
its orientation. Commitment separates active candidates from settled answers.
Public advancement preserves the answer prefix and crosses one exposed
Delay. No dormant-right conversion or strict-to-online fusion is part of
this application connection.

Full first-order relation definitions, calls, recursion and mutual recursion
are implemented in S/E/N. Γ remains explicit in source programs and data
frames, including pending calls and resumptions. The selected functional S
derivation carries it through its generated machine, registers and existing
compression. General correspondence and productive-stream proofs remain open.

S allocation reads the Owner groups on the active computation's world path.
Common groups reach both branches; answer-private groups stay with their
answer. Empty and unused groups remain meaningful. S states contain only
substitution, disequalities, trail and tag; a cumulative Support field belongs
to E, and a numeric supply to N. Numeric-looking variable labels in the GUI
do not change its S representation.

The earlier online schedulers in `src/search-lattice/` remain executable
comparison sources with their own source-relative laws. They no longer
provide the GUI runtime. The new strict S scheduler extension has a checked
Railroad-to-Flip orientation map; separate E/N scheduler rows, downstream
derivations and universal correspondence proofs remain open.

The distribution experiment lives
beside the strict matrix work in
[`racket-server/derivations/distributed-search/`](racket-server/derivations/distributed-search/README.md).
It explores distributing conjunction over choice in the older online source
before machine derivation. Nested rails expose an observable answer-order
difference from the factored source, so this is a semantic alternative to
investigate, not a representation-only rewrite. The move adds no strict
correspondence, GUI policy, matrix cell, or A7/A9 integration.

That retained experiment has a common distributed-search carrier with `DisjR` and the
right-active normalization/closure rules, while distributed rail adds only its
two scheduler transitions. Its experiment-only raw seam lives with its consumer in
[`distributed-search/reduction-relations/factored-search-base.rkt`](racket-server/derivations/distributed-search/reduction-relations/factored-search-base.rkt).
Its dedicated [tests](racket-server/derivations/distributed-search/tests.rkt)
remain referenced by the older semantic aggregate; this preserves the existing
comparison gate rather than adding integration with the strict derivation.

## **Orientation (Minimal)**

Use this if you are jumping in with no project history:

| Location | Responsibility |
| --- | --- |
| [src/transpiler/](racket-server/src/transpiler/) | Parse mini/micro, apply compilation profile, preserve source IDs, initialize the strict program carrier |
| [src/search-lattice/](racket-server/src/search-lattice/SEMILATTICE.md) | Earlier online DFS, Flip, and Railroad sources retained for comparison |
| [matrix/full-source.rkt](racket-server/derivations/strict-search/matrix/full-source.rkt) | Native full S/E/N reduction relations |
| [matrix/scheduler-source.rkt](racket-server/derivations/strict-search/matrix/scheduler-source.rkt) | Strict S scheduler variations and native Railroad orientation used by the GUI |
| [shared/wf.rkt](racket-server/derivations/strict-search/shared/wf.rkt) | Strict representation-specific scope, store and relation checks |
| [src/search-runtime.rkt](racket-server/src/search-runtime.rkt) | Select strict scheduler relations and WF; inspect status and public boundaries |
| [src/program-runner.rkt](racket-server/src/program-runner.rkt) | Manual session, exact configuration history and back/reset |
| [src/app.rkt](racket-server/src/app.rkt) | HTTP/API boundary and source conversion |
| [src/search-picture.rkt](racket-server/src/search-picture.rkt) | Project strict scheduler terms with branch orientation, owner annotations, candidates and committed answers; also inspect historical trees |
| [src/minikanren.rkt](racket-server/src/minikanren.rkt) | Automatic consumer and run/run* library interfaces |
| [Frontend examples](frontend/src/utils/example_programs.js) | Source-of-truth example programs, read by compiler and integration tests |

Focused source-mode and profile integration command:

```sh
racket -y -l raco -- test racket-server/tests/example-compat-tests.rkt racket-server/tests/model-example-matrix-tests.rkt
```

## **Configuration**

The Docker images expect an amd64 platform. Users on Apple Silicon or other arm64 based architectures,
will need to rely on emulation. This build is known to build and works under QEMU.

## **Issues**

### `Error reading from ~a`

When building with Docker on an Apple Silicon machine, some users encounter an error like the following:

```
Error: error reading from ~a
("petite")
Aborted
```


Here is a minimal test that should produce the same error:

```
$ docker run -it --platform linux/amd64 racket/racket:latest sh -c "uname -m; racket"
x86_64
Error: error reading from ~a
("petite")
Aborted
```

To resolve this, open Docker.app and under Settings > General >
Virtual Machine Options, make sure you have un-checked `Use Rosetta
for x86_64/amd64 emulation on Apple Silicon`, and have selected QEMU as the VMM.
