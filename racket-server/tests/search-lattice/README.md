# Search-lattice semantic tests

This subtree mirrors the semantic architecture instead of the historical order
in which the implementation was assembled. One root aggregate, `all.rkt`,
exports `SEARCH-LATTICE-SEMANTICS` to the comprehensive headless runner.

## Responsibility map

- `nodes/` owns one assembled language, reduction relation, and WF cell:
  `core`, the two additive feature extensions `delay` and `disjunction`, and
  the assembled `search` node.
- `edges/` owns claimed conservative embeddings between nodes:
  core to delay, core to disjunction, delay to search, and disjunction to
  search. An edge checks grammar inclusion, WF agreement on the source image,
  complete named-successor multisets, raw proof counts, and positive coverage.
- `join/` proves that search is the literal semilattice join of delay and
  disjunction: exact inherited syntax/rules, one shared core copy, and no new
  carrier syntax or rule.
- `grammar/` owns the compositional recursive focus grammar and raw context
  proof counts.
- `fibers/` owns DFS, flip, and rail as scheduler fibers over assembled search
  cells. Rail additionally owns its `DisjR` carrier extension, six
  right-active closure rules, and two scheduling transitions.
- `overlays/` owns relcall as an overlay rooted independently in the delayed
  language and its unions with search and rail.
- `laws/` owns crosscutting determinism, raw-proof uniqueness, WF
  preservation, tagged structural owner stacks, whole-frontier allocation, and
  frontier-observation laws.
- [The distributed-source tests](../../derivations/distributed-search/tests.rkt)
  live with their source under `derivations/distributed-search/`. This aggregate
  still references that existing comparison gate. The experiment distributes
  conjunction before machine derivation in the earlier dormant-branch semantics, retains
  common `DisjR` syntax, and lets distributed rail add only scheduling.

`support.rkt` contains only helpers shared by multiple semantic owners. Expected
rule inventories and feature-specific witnesses remain visible in the suites
that own them.

## Feature shape

Delay and disjunction are additive feature extensions of core. Search is their
literal semilattice join: the language/relation union adds no constructor,
frame, or rule. Relcall is a separate overlay rooted in delay; search-relcall is
the union of relcall and search, while rail-relcall is the union of relcall and
the rail fiber.

Static topology evidence also checks the implementation arrows: production
search consumes assembled disjunction plus the delay delta, rail lifts assembled
search plus its local delta, and rail-relcall lifts assembled search-relcall
plus that delta under `Γ`. The experiment-only raw seam is now local to
[`distributed-search/reduction-relations/factored-search-base.rkt`](../../derivations/distributed-search/reduction-relations/factored-search-base.rkt).

Source-level edge suites establish embedding, conservativity, and provenance.
They are not naturality tests. Naturality would require a second derivation
transformation available at multiple stages and a commuting square, which this
source-only test tree does not claim.

## Theorem boundaries

Keep these claims separate:

- a node suite establishes node-local grammar, WF, and named behavior;
- an edge suite establishes a claimed conservative feature embedding;
- the join suite establishes exact inherited syntax/rule provenance, one shared
  core copy, and absence of join-owned additions;
- a fiber suite establishes scheduler behavior, not feature extension;
- fiber suites use ordinary search/search-relcall WF for DFS and flip, and the
  larger rail/rail-relcall WF only for rail;
- the relcall suite establishes overlay composition, not an independent
  core-rooted feature;
- law suites state their own generated domains and check raw Redex proofs where
  uniqueness is claimed;
- the distributed source remains a separate semantic alternative: nested
  rails exhibit an observable answer-order difference. Its common right-active
  carrier is experiment-local, not evidence that ordinary search/DFS/flip
  admit `DisjR`. Keeping its existing gate is not strict correspondence or
  GUI, matrix, or A7/A9 integration.

## Running the tests

Run the complete semantic subtree with:

```sh
PLTUSERHOME=/tmp/decorated-lattice-plt \
PLTCOMPILEDROOTS=/tmp/decorated-lattice-compiled \
  raco test racket-server/tests/search-lattice/all.rkt
```

Every leaf suite also has a `module+ test` entrypoint, so its documented path is
a focused gate. The full production, compiler, runtime, HTTP, renderer, and
frontend lanes remain outside this subtree and are listed in
[`../TEST-LANES.md`](../TEST-LANES.md).

Run the relocated distribution comparison directly with:

```sh
racket -y -l raco -- test racket-server/derivations/distributed-search/tests.rkt
```
