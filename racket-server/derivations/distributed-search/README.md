# Eager conjunction distribution experiment

This is a separate operational-policy experiment, beside
[the strict Search derivations](../strict-search/README.md). It is **not a
matrix row, an A7–A9 transformation stage, or a GUI backend**. Its implemented
artifacts are Redex languages, reduction relations, scheduler variants, and
tests; it has no independently derived functional interpreter or machine
correspondence.

The question belongs at the source-semantics level: should pending conjunction
remain outside a choice until a candidate is available, or be distributed into
its branches before they run?

```text
Conj(Choice(left, right), g)
    → Choice(Conj(left, g), Conj(right, g))
```

The named rules are `distribute-choice` and `distribute-right-choice`.
The `Early*` contexts require this distribution before ordinary work or
scheduling beneath the conjunction. This is eager distribution of pending
conjunction, **not the strict evaluation of both disjunction operands** used
by the current interpreter. Both the experiment and its factored comparison
use the work-tree carrier of the earlier dormant-branch semantics.

## Why keep it separate

Distribution changes observable scheduling on a finite nested-choice witness:

```text
((A ∨ B) ∨ C) ∧ suspend(succeed)
```

Here A, B, and C are successful equality goals with distinct work-trail
labels, so their answer states can be distinguished.

| Presentation | Answer-state order | Public forces before first answer |
| --- | --- | --- |
| Current strict source | A, B, C | 2 |
| Earlier dormant-branch semantics, factored rail | A, B, C | 2 |
| Earlier dormant-branch semantics, distributed rail | C, A, B | 3 |

[The executable checks](tests.rkt) retain this counterexample alongside the
presentation-specific transitions, allocation ownership, carrier closure,
and scheduler witnesses. Agreement between strict and dormant-branch factored execution
on this witness does not establish their general equivalence.

This result makes distribution interesting as a different search policy.
It rules out treating this rule as an administrative representation change
preserving the current ordered Frontiers. Any future interpreter, refocusing,
or register derivation for this policy must start from its own stated
semantics. No integration or equivalence with the strict pipeline is claimed.

## Files and dependencies

- [all.rkt](all.rkt) exports the experimental languages and relations.
- [languages/](languages/) defines the distribution focus contexts and the
  experiment's common right-active `DisjR` carrier.
- [reduction-relations/](reduction-relations/) assembles disjunction, search,
  DFS, flip, rail, and relation-call variants. Distributed rail adds the two
  scheduler transitions to the common distributed-search carrier.
- [factored-search-base.rkt](reduction-relations/factored-search-base.rkt)
  assembles inherited raw rules for re-closing under `Early*`. This seam is
  used only by the experiment and moved here with it.
- [tests.rkt](tests.rkt) is the standalone comparison suite.

The experiment still reuses the earlier dormant-branch languages, kernels, owner operations,
well-formedness predicates, and scheduler rules under
[src/search-lattice/](../../src/search-lattice/). Those imports are real
dependencies, not copied implementations or compatibility aliases. The GUI,
strict matrix, and retained-scope machine providers do not import this
experiment. Older cross-cutting tests continue to compare its relations.

Run from the repository root:

```sh
raco test racket-server/derivations/distributed-search/tests.rkt
```
