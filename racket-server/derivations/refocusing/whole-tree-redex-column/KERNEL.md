# Kernel parameter boundary `P[K]`

`kernel-interface.rkt` states the Redex-visible protocol for atomic goal
evaluation.  A kernel step consumes an atomic goal and an opaque state and
produces exactly one of:

```text
KernelSuccess(state)  with  kernel(kernel-rule-name, core)
KernelFailure         with  kernel(kernel-rule-name, core)
```

The control column may distinguish success from failure.  It may carry the
successful state and the exact label, but it must not inspect either one.
Kernel labels remain visible so source/decomposition/refocusing equality and
compressed span certificates do not erase distinctions made by a kernel.

The other parameter operations are:

```text
kernel-initial-state/K
kernel-fresh/K          : lexical-names x used-marker-support -> introduction
kernel-substitute/K     : goal x lexical-substitution -> goal
kernel-open-fresh/K     : composition of the preceding two
wf-atomic-goal/K
wf-state-at/K           : state x ambient-marker-scope
kernel-observe/K        : query-introduction x state -> reified values
```

`freeze` and `resume` are not parameter hooks.  Both operations traverse
`WorkFresh` and build `AnswerFresh` or `Work`; that is shared control syntax
over an opaque state.  The generic column should move those definitions out of
`kernel-toy.rkt` when it is parameterized.

## `Kmk`

`kernel-mk.rkt` is the isolated c-free miniKanren instantiation.  Its state is

```text
state(substitution, disequalities, unification-trail, provenance-tag)
```

and deliberately has no cached `c`.  It reuses the existing refocusing
kernel's fresh-name, substitution, unification, disequality, and reification
operations.  Atomic rule choice remains a Redex judgment with the exact rule
family:

```text
succeed
fail
unify-success
unify-violates-disequality
unify-fail
disequality-success
disequality-fail
```

State and answer well-formedness are indexed by the ambient logical-variable
scope represented by source markers.  This is not a runtime sort or cached
field.

Canonical miniKanren input is closed by its outer query `fresh`.  The adapter
translates canonical `existential/conjunction/disjunction` constructors to the
column's `fresh/conj/disj` vocabulary.  Evaluating that outer source fresh
allocates even unused query variables; the resulting top `WorkFresh` then
becomes `FrontierFresh`.  Consequently the root scope is marker-owned and the
semantic root remains an `F`, with no configuration envelope or hidden scope
cache.

## Deliberate integration boundary

These files do not claim that the existing toy column is already generic.  It
is not: the current language fixes `(state p)`, puts toy atomic forms directly
in `g`, and fixes the complete label alphabet to `work-succeed`, `work-fail`,
and `work-put`.  Source, decomposition, compression, and promoted big-step
artifacts all contain corresponding direct clauses.

The next change must be one coherent genericization checkpoint:

1. Split structural control goals from the kernel-owned atomic-goal
   nonterminal and make state opaque in the common grammar.
2. Replace the three toy leaf clauses at every direct/specification stage with
   a generated or extended `kernel-step/K` clause while retaining independent
   Redex presentations for each arrow.
3. Generalize the label grammar and compression's producer-followup class to
   `kernel(kname, core)`.
4. Keep `freeze`/`resume` and marker-indexed answer/work well-formedness in the
   common control layer.
5. Run the complete arrow suite twice, with separate Ktoy and Kmk grammars, so
   mixed kernel goal/state terms are rejected by grammar rather than a dynamic
   compatibility check.

Focused tests in `tests/kernel-parameter-tests.rkt` currently establish the
protocol shape, all seven Kmk atomic labels and outcomes, c-freedom, fresh
opening and capture avoidance, canonical outer-fresh translation,
marker-indexed state/answer well-formedness, successful-step preservation, and
query observation.  They also compare every atomic outcome, state update, and
rule name against the production core Redex relation after restoring ambient
`c` only at that test boundary.  Full-source and every-arrow conformance remain
explicitly pending until the genericization checkpoint above.
