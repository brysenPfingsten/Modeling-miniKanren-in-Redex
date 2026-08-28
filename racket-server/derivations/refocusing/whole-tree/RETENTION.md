# Whole-tree retention and retirement ledger

This ledger prevents consolidation from silently losing a rule, law,
counterexample, trace, or explanatory decision.  Git history preserves old
implementations, but an executable directory is removed from current `HEAD`
only after its unique evidence has a named canonical destination and the exact
deletion list has been approved.

The current derivation account and witness transcript remain authoritative
during the transition:

- [`../whole-tree-redex-column/REPORT.md`](../whole-tree-redex-column/REPORT.md)
- [`reference/marked/README.md`](reference/marked/README.md)
- [`reference/marked/TRACES.md`](reference/marked/TRACES.md)

## Artifact dispositions

| Artifact | Disposition and retirement gate |
|---|---|
| [`whole-tree-spike/`](../whole-tree-spike/) | Broad source-design survey only. Harvest its feature-cell survey, `Last`/`Emit` distinction, fresh normalization and ownership analysis, force/committed-prefix observations, cache experiments, and any unique counterexample. Retire the executable after each retained item has a canonical document, scenario, or test and the marked reference remains green. |
| [`whole-tree-pipeline-pilot/`](../whole-tree-pipeline-pilot/) | Handwritten behavioral oracle for the first complete vertical pipeline. Its four source goals have moved to the constructor-neutral canonical corpus; its remaining arrow laws, span witnesses, and prose must be checked off before removal. Retire after `P[Ktoy]` parity and byte-identical canonical traces are recorded without an inbound pilot dependency. |
| [`whole-tree-redex-column/`](../whole-tree-redex-column/) | Concrete Ktoy Redex oracle. Retain temporarily for exact labeled parity of source, decomposition, refocusing, machine, compression, and finite big step. Retire after those parity checks live outside the sole marked reference and all unique laws have moved. |
| [`reference/marked/`](reference/marked/README.md) | Sole temporary marked reference, moved once from the concrete-column subtree. Retain through independent lean, reference Q, and modular-family validation. Retire only when every criterion in [`README.md`](README.md) is satisfied by the modular marked instantiation. |
| [`reference/lean/`](reference/lean/README.md) | Independent lean reference.  Its source grammar, WF, Ktoy/Kmk kernels, 20 control rules, and exact 23/27 source inventories are executable.  Retain through the later lean `D/Z/M/B/Big`, reference-Q, and modular-family validation; the present source checkpoint is not a complete derivation. |
| [`q/reference/`](q/reference/README.md) | Marked-to-lean source correspondence.  Retain its explicit constructor map, five ranked stutters, alpha-aware allocation law, and rule-complete bounded named-successor witnesses.  Extend it stage by stage only after each independent lean stage exists; do not use it to manufacture either reference. |
| [`premachine/`](../premachine/) | Older derivation evidence. Harvest only unique state-shape or transition-correspondence cases; otherwise retire after the canonical machine codec and bisimulation suite subsume it. |
| [`zipper/`](../zipper/) | Older zipper derivation evidence, not a source representation. Harvest any unique plug/context law; retire when grammatical decomposition and refocusing cover it. Do not reintroduce an answer-stream zipper into the source calculus. |
| [`cfree/`](../cfree/) | Earlier c-free experiment. Transfer unique cache-insensitivity examples and state translations to the lean/cache bridge corpus; retire after the canonical c verdict and bridge laws subsume it. |
| [`bridge/`](../bridge/) | Earlier bridge/correspondence cases. Preserve unique selected-cell translations and observations, including useful worktree-only renaming notes; retire after explicit Q/cache/production bridge tests cover them. |
| [`shared/kernel.rkt`](../shared/kernel.rkt) | Retain as an approved atomic `Kmk` primitive while it has consumers. Search control must not move into it. Relocate to a neutral kernel home only if marked, lean, family, and production genuinely share the same operations; delete only after all consumers migrate. |
| [`shared/configs.rkt`](../shared/configs.rkt) | Inventory with the older refocusing lane. Retain only configurations still used by a live test or a unique correspondence witness. |
| [`NOTES.md`](../NOTES.md) | Working derivation history. Move durable decisions into the canonical README, decision record, rule tables, or regression explanations. Retire or reduce it only after every still-current claim has a destination. |
| untracked `stream-spike/` in the production worktree | Superseded as a source-language proposal. Preserve only unique projection, committed-prefix, force/cost, or cache observations. Do not add it as another canonical semantics. Remove it from the dirty worktree only after inventory and explicit approval. |

The committed-prefix/residual split, `Last`/`Emit` distinction, scoped-answer
ownership, ordered force evidence, unit exact-step cost, and dynamic allocation
laws have now moved to
[`reference/marked/OBSERVATIONS.md`](reference/marked/OBSERVATIONS.md), the
semantic-import-free [`corpus/observation-cases.rkt`](corpus/observation-cases.rkt),
the semantic-import-free
[`corpus/source-correspondence-cases.rkt`](corpus/source-correspondence-cases.rkt),
the source-stage [`q/reference/`](q/reference/README.md) laws, and the temporary
external-oracle parity suite.  This transfers the source representation laws;
it does not yet satisfy the older artifacts' remaining derived-stage,
feature-survey, cache, or naturality retirement gates.

## Production progress witnesses

These witnesses are durable regressions, not disposable spike examples.

1. **Nested branch-local fresh/choice.**  The control shape is approximately
   `fresh u (disj (fresh v (disj a b)) c)`.  The outer marker owns the full
   frontier; the inner marker is copied onto exactly `a` and `b`, never `c`.
   The current production lattice can reach a well-formed nonterminal scoped
   choice with no successor.  The accepted reference must produce `a`, `b`,
   and `c`; production reintegration must assert progress, allocation once per
   binder, copied marker identity, and no ownership leakage under every
   surfaced deterministic strategy.

2. **Right-active delayed/fresh/conjunction.**  A delayed-left choice rotates
   to the right while a fresh scope remains local below an outer conjunction.
   The current production rail relation can reach a well-formed nonterminal
   state with no successor because its right-active/rail context coverage is
   incomplete.  The canonical marked trace is retained in
   [`reference/marked/TRACES.md`](reference/marked/TRACES.md).
   Production reintegration must assert progress, the expected rail motion,
   force events, marker ownership, and the eventual answers.

## Resolved import direction

Below, `A -> B` means modules in `A` may require modules in `B`:

```text
corpus              -> no semantic module
reference/marked    -> neutral support, approved atomic kernels
reference/lean      -> neutral support, approved atomic kernels
q/reference         -> reference/marked, reference/lean
family              -> neutral support, approved atomic kernels
q/family            -> family
embeddings          -> family
bridges              -> references and/or family, production adapters
tests and traces     -> any layer they inspect
production src       -> never whole-tree
```

The two references may not import one another, Q, the family, bridges, tests,
or retired implementations.  The family may not import either reference.  A
semantic module may not import corpus fixtures, tests, or generated traces.
Only a kernel adapter may cross to an explicitly approved atomic production
kernel helper; no source-focus or search-control relation may cross that
boundary.

During consolidation, legacy parity and production-kernel comparison tests may
temporarily import both sides, but they live in `whole-tree/tests/`, outside
the intrinsic marked reference.  The current executable gate scans every
marked-reference Racket module and whitelists only intra-reference imports,
corpus data from tests/the trace exporter, and the two exact Kmk atomic-kernel
helpers from `mk/kernel.rkt`.  A resolved transitive import graph, including
compile-time phases, remains a required gate before reference retirement.

## Cleanliness invariants

- The production worktree is not switched, reset, cleaned, or modified during
  canonical spike acceptance; its dirty WIP is preserved for later triage.
- Canonical semantic changes remain on the canonical research branch until the
  acceptance decision is recorded.
- The canonical corpus contains ordinary data and has no semantic import.
- No compatibility aliases, W/F state tags, dynamic sort checks, or host rule
  dispatchers are introduced during consolidation.
- No obsolete directory is removed while it has an inbound canonical import or
  unique untransferred evidence.
- Every coherent checkpoint has a passing focused suite, a clean
  `git diff --check`, and byte-identical generated traces when trace-producing
  code changes.
- Cleanup is a separately reviewed operation with an exact deletion list; it
  is never bundled with a semantic change.
