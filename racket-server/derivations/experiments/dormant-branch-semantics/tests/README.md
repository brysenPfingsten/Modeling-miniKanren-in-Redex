# Dormant-branch source and derivation tests

This subtree mirrors the semantic architecture instead of the historical order
in which the implementation was assembled. The local `all.rkt` exports the
native source suite `SEARCH-LATTICE-SEMANTICS`; the account's
[root aggregate](../all.rkt) combines it with the functional/source/machine
and strict/dormant comparison checks. The experiments aggregate invokes that
whole account, rather than placing its source laws among application tests.

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
- [The early-distribution tests](../../early-conjunction-distribution/tests.rkt)
  live with their own source in the sibling experiment. The experiments gate
  invokes that comparison separately. It distributes conjunction before
  machine derivation, retains common `DisjR` syntax, and lets distributed rail
  add only scheduling.

`support.rkt` contains only helpers shared by multiple semantic owners. Expected
rule inventories and feature-specific witnesses remain visible in the suites
that own them.

## Feature shape

Delay and disjunction are additive feature extensions of core. Search is their
literal semilattice join: the language/relation union adds no constructor,
frame, or rule. Relcall is a separate overlay rooted in delay; search-relcall is
the union of relcall and search, while rail-relcall is the union of relcall and
the rail fiber.

Static topology evidence also checks the implementation arrows: native
search consumes assembled disjunction plus the delay delta, rail lifts assembled
search plus its local delta, and rail-relcall lifts assembled search-relcall
plus that delta under `Γ`. The experiment-only raw seam is now local to
[`early-conjunction-distribution/reduction-relations/factored-search-base.rkt`](../../early-conjunction-distribution/reduction-relations/factored-search-base.rkt).

## Derivation and comparison checks

The top-level `functional-tests.rkt`, `functional-source-tests.rkt`, and
`source-tests.rkt` exercise the direct/CPS/data-machine route, structural
readback, and its stated native-source fragment. `orientation-tests.rkt`
checks the native Railroad/Flip map. `barriers-tests.rkt` and
`strict-policy-tests.rkt` preserve strictness and observation discrepancies.
The property/support fixtures and `redex-fresh-scope-witness.rkt` are owned
here because their subject is this source's allocation and demand policy.
`picture-tests.rkt` checks its direct work-tree inspection; older rendering
properties continue to use the earlier source-local picture provider.

Neutral generators and runtime observations are imported from
[`derivations/test-support/`](../../../test-support/README.md). Those helpers
contain no dormant evaluator. Current GUI/compiler/API tests remain central.

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

Run the complete account or only its native source subtree with:

```sh
racket -y -l raco -- test racket-server/derivations/experiments/dormant-branch-semantics/all.rkt
racket -y -l raco -- test racket-server/derivations/experiments/dormant-branch-semantics/tests/all.rkt
```

Every leaf suite also has a `module+ test` entrypoint, so its documented path is
a focused gate. The application, compiler, runtime, HTTP, renderer, and
frontend lanes remain outside this subtree and are listed in
[TEST-LANES.md](../../../../tests/TEST-LANES.md).

Run the relocated distribution comparison directly with:

```sh
racket -y -l raco -- test racket-server/derivations/experiments/early-conjunction-distribution/tests.rkt
```
