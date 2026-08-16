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

## From isolated prototype to the generic column

`kernel-interface.rkt`, `kernel-toy.rkt`, and `kernel-mk.rkt` remain the
isolated protocol prototype and its focused tests.  They established the
boundary before changing every artifact, but the original sibling modules in
this parent directory are intentionally still the concrete toy oracle: their
language fixes `(state p)`, their atomic goals occur directly in `g`, and
their three atomic labels are untagged.

The coherent genericization checkpoint is now complete in [`pk/`](pk/).  Its
[architecture guide](pk/README.md) records these changes:

1. Structural control goals are separated from kernel-owned atomic goals, and
   the common grammar treats kernel states opaquely.
2. Each source instance presents one genuine named leaf rule per kernel
   outcome and lifts those rules through `WF`.  Derived decomposition,
   refocusing, exact-machine, compression, and promoted-big-step artifacts
   invoke `kernel-step/K` only at an atomic leaf.  The specification and direct
   presentations remain independently stated.
3. Exact labels include `(kernel kname core)`, and compressed spans retain the
   dynamic kernel label as a nonempty certificate component.
4. Whole-frontier marker support, `control-freeze/K`, `control-resume/K`, and
   marker-indexed recursive well-formedness remain in the shared control
   layer.
5. Precise `Ktoy` and `Kmk` language extensions replace all abstract leaves
   before defining relations.  The complete arrow suite runs for both, and
   each grammar rejects the other kernel's goal/state terms without a runtime
   compatibility tag.

The isolated `tests/kernel-parameter-tests.rkt` still checks protocol shape,
all seven Kmk atomic labels and outcomes, c-freedom, capture-avoiding fresh
opening, canonical outer-fresh translation, marker-indexed well-formedness,
successful-step preservation, and query observation.  The parameterized
front-half suite additionally compares each Kmk atomic outcome and rule name
against the production core Redex relation, restoring ambient `c` only at
that test boundary; the full parameterized suite then exercises every arrow.

What remains is deliberately beyond this kernel checkpoint: the Q maps for
caching and erasure, feature-lattice conservative extension and naturality,
the `relcall` overlay, and a divergence-sensitive semantics.  The present
finite and bounded executable correspondence checks are not universal proofs
of those later claims.
