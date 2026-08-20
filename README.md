# Modeling-miniKanren-in-Redex
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

Use the lane that matches what you are validating.

### **1) Headless lane (default CI/local smoke)**

```sh
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/test-all-headless.rkt
```

Includes the direct source-to-W/F compiler boundary, direct WF and generated
law checks, node and conservative edge suites, literal search-union evidence,
scheduler fibers (including rail's right-active carrier extension), the
isolated distributed presentation, fiber-specific progress, structural
ownership, and whole-frontier allocation. See
`racket-server/tests/TEST-LANES.md` for the exact suite inventory and focused
commands.

### **2) App/API regression lane**

```sh
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/test-app.rkt
PLTUSERHOME=/tmp/decorated-lattice-plt \
  racket racket-server/tests/ui-payload-smoke.rkt
```

### **3) Frontend lane**

```sh
npm --prefix frontend test
npm --prefix frontend run lint
npm --prefix frontend run build
```

### **4) Compiler×runtime matrix and API-flow lane**

Exercises one bounded representative miniKanren program across all 36
combinations of conjunction association, disjunction association, delay
placement, and scheduler. The same suite retains scheduler/example execution
through both direct and backend API paths, up to its configured step cap or
termination.

```sh
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/model-example-matrix-tests.rkt
```

## **Backend Init Contract**

The GUI/API boundary selects each run structurally.

`POST /api/post/init` accepts:
- `text`
- `sourceMode` = `"mini"` or `"micro"`
- optional `compileProfile` when `sourceMode = "mini"`
- `searchStrategy`, a JSON object with:
  - `scheduler` = `"dfs"`, `"flip"`, or `"rail"`

Default surfaced strategy:
- `scheduler = "rail"`

Execution notes:
- `compileProfile` controls source-to-micro compilation choices such as
  conjunction associativity, disjunction associativity, and delay placement.
- `searchStrategy` selects only the scheduler; the primary source relation is
  the factored source.
- The canonicalizing compiler emits the W/F-stratified `(Γ F)` production
  configuration directly, rooted at `More(Work(...))`. The backend checks the
  production language/WF judgment and then steps the selected scheduler's named
  Redex relation.

## **Direct Library Surface**

If you want to run programs without the site, import
`racket-server/src/program-runner.rkt` and call `run-source` or
`run-source->answers` directly.

```racket
#lang racket

(require (file "racket-server/src/program-runner.rkt"))

(run-source->answers
 "(defrel (same x y)
    (== x y))
  (run* (q)
    (same q 'cat))")
;; => '(#hasheq((sym . "cat")))
```

The runner accepts the same main knobs as the app boundary:
- `#:source-mode` (`"mini"` or `"micro"`)
- `#:compile-profile` for mini source
- `#:search-strategy`, for example `(search-strategy "rail")`
- `#:step-cap` to bound diverging programs

The exported runner configuration structs contain the internal W/F runtime
carrier. Source text and answer-returning entry points form the public boundary.

If you want something closer to the effect of `(require miniKanren)`, import
`racket-server/src/minikanren.rkt`. That module provides `defrel`, `run`, and
`run*` bindings for the mini surface syntax, but they are backed by this
project's modeled Redex semantics rather than `hosted-minikanren`.

`run*` runs the modeled search to completion and returns reified answers.
`run n ...` stops once `n` answers have been surfaced and reified, without
forcing the rest of the search to finish.

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

If you want the lower-level runner surface directly, use
`racket-server/src/program-runner.rkt`. It also exposes
`run-source->host-answers` and `run-forms->host-answers`.

## **Semantics Reading Order**

If you are studying the repo as a semantics artifact, use this order:

1. `docs/semantics-ladder.md`
   - primary repo-level overview
   - explains what the active runtime is and how the main axes fit together
2. `racket-server/src/search-lattice/SEMILATTICE.md`
   - carrier grammar, compositional contexts, rule ownership, and scheduler
     boundary
3. `racket-server/src/search-lattice/PICTURE-DESIGN-NOTES.md`
   - operational/extensional pictures and structural fresh ownership
4. `racket-server/src/search-lattice/wf/LAYERING-NOTES.md`
   - current direct WF schemas and public judgment names
5. `racket-server/tests/search-lattice/README.md`
   - mirrored node, edge, join, grammar, fiber, overlay, law, and experiment
     tests

## **Current Runtime Surface**

The active runtime path is the feature-based search lattice:

- languages: `racket-server/src/search-lattice/languages/*.rkt`
- well-formedness: `racket-server/src/search-lattice/wf/*.rkt`
- reducers: `racket-server/src/search-lattice/reduction-relations/*.rkt`
- strategy registry: `racket-server/src/search-runtime.rkt`
- structured strategy API: `racket-server/src/search-strategy.rkt`

The app/API boundary runs through that lattice directly.

The primary source semantics is the factored source. Delay and disjunction are
additive feature extensions, and search is their literal language/relation
union. DFS and flip operate on that search carrier. Rail remains a scheduler
fiber, but extends search with the right-active `DisjR` carrier and the rules
needed to close that carrier under rail execution. The
distributed presentation is retained separately under
`racket-server/src/search-lattice/experiments/distributed/` as an executable
experiment, not as a surfaced runtime policy.

That retained experiment is a deliberate exception to the production carrier
split: its common distributed-search carrier still includes `DisjR` and the
right-active normalization/closure rules, while distributed rail adds only its
two scheduler transitions. This historical experiment boundary does not widen
ordinary production search.

The production relation modules follow those immediate semantic predecessors:
search combines assembled disjunction with the delay deltas, rail lifts
assembled search plus its local delta, and rail-relcall lifts assembled
search-relcall plus that delta under `Γ`. A retained raw join seam serves only
the isolated distributed presentation.

Fresh scope is structural. Every work, answer, terminal, delay, and choice
constructor carries an explicitly tagged `Owners(...)` stack ordered
outermost-to-innermost. Each `Owner(intro, tag)` records one binder's ordered,
duplicate-free introductions; states contain substitution, disequality, trail,
and tag fields only. Allocated-name support is derived from the entire live
frontier, against which allocation chooses names deterministically; it is not a
stored owner field, cache, or counter.

## **Orientation (Minimal)**

Use this if you are jumping in with no project history:

- Surface input is parsed/transpiled by:
  - `racket-server/src/transpiler.rkt`
  - subsystem modules under `racket-server/src/transpiler/`
- The app boundary lives in:
  - `racket-server/src/app.rkt`
  - `racket-server/src/search-runtime.rkt`
  - `racket-server/src/search-strategy.rkt`
- Visible-tree production lives in:
  - `racket-server/src/search-lattice/picture.rkt`
  - `racket-server/src/search-lattice/answer-node.rkt`
- Internal search-lattice WF for the GUI/API boundary lives in:
  - `racket-server/src/search-lattice/wf/*.rkt`
- Frontend examples are source-of-truth in:
  - `frontend/src/utils/example_programs.js`
- Integration test auto-loads all frontend examples and checks source compatibility:
  - `racket-server/tests/example-compat-tests.rkt`

Fast validation command:

```sh
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/test-all-headless.rkt
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
