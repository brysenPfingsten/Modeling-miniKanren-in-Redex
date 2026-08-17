# Intrinsic observations for the marked column

This checkpoint defines observations as derived views of the marked whole
frontier.  It does not add an answer-stream zipper, an `obs` field, a W/F sort
tag, or a second source semantics.  The source relation remains the named
Redex relation over `F`; every view below is a Redex judgment or metafunction.

## Grammatical frontier factorization

The observation language adds one result category:

```text
FTail ::= More(W) | Done | Last(A)
```

The already-derived `FF` context is the maximal completed frontier prefix.
The single raw rule

```text
frontier-split((in-hole FF FTail), FF, FTail)
```

therefore exposes a grammar-induced factorization, rather than an ordered
host-language traversal.  Randomized structural generation checks that every
sampled `F` has exactly one raw derivation.  `restore-frontier` is its inverse:

```text
frontier-split(F, FF, FTail)
implies restore-frontier(FF, FTail) = F.
```

The residual observation is the complete `FTail`.  In particular it preserves
`More(W)` rather than discarding unfinished work.

## Public views

Replace `K` by `toy` or `mk` unless noted otherwise:

```text
frontier-split/K          : F x FF x FTail judgment
restore-frontier/K        : FF x FTail -> F
frontier-prefix-events/K  : F -> (FrontierEvent ...)
answer-payloads/K         : F -> (A ...)
answer-states/K           : F -> (kst ...)
scoped-answers/K          : F -> (ScopedAnswer ...)
forced-events/K           : F -> (ForcedEvent ...)
residual/K                : F -> FTail
query-answers/mk           : F x intro -> (observation ...)  ; Kmk only
trace-labels/K             : Trace -> Labels
```

`answer-payloads/K` preserves the marked `A` values.  `answer-states/K` strips
their `AnswerFresh` wrappers and deliberately returns raw kernel states; it is
not a user-answer API.  `query-answers/mk` is that API for Kmk: it applies
`kernel-observe/mk` to each answer state at the caller's explicit query
`intro`.  Ownership wrappers do not silently enlarge that query.

`scoped-answers/K` retains lexical ownership as an ordered list of
`(Owner intro tag)` records.  An owner enclosing the whole frontier applies to
every answer under it; an `AnswerFresh` owner applies only to that answer.
This makes the boundary/local fresh distinction observable without changing
the operational grammar.

`frontier-prefix-events/K` reports `FrontierFreshEvent`, `EmitEvent`, and
`ForcedEvent` from outermost to innermost, which is creation order.  It omits
the changing `More`, `Done`, and `Last` tail sentinels.  Consequently prefix
monotonicity is an exact list-prefix law even while the residual changes.

A `Forced` wrapper is persistent evidence that one `force-delay` rule fired at
that position.  It records the count and order of forcing relative to fresh and
answer events.  It does **not** identify the originating `suspend` tag; pending
work itself remains represented by `PendingDelay(W)`.

## Trace views

The only scalar cost in this checkpoint is exact unit rule cost:

```text
rule-cost/K(labels) = length(labels)
force-count/K(labels) = number of (force-delay delay) labels
```

The exact ordered labels remain the primary evidence.  There is no weighted
cost model, and forcing is a separate observation rather than a second cost.
`trace-labels/K` projects that evidence directly from `Trace`; clients do not
maintain a parallel host-language label list.

Allocation observations have the shape:

```text
AllocateEvent(tag, lexical, intro)
```

`allocation-edge/K` repeats the genuine source allocation rule's
whole-frontier support and `kernel-open-fresh/K` premises.  Thus it reflects an
actual allocation edge rather than accepting a matching label and shape.
`allocation-events/K` mirrors those same premises while folding a trace;
permissive `Trace` syntax alone cannot manufacture an allocation event.

Counts are dynamic rule occurrences, not static syntax counts.  In particular:

- `fresh ()` produces one allocation event with empty `lexical` and `intro`;
- introduced `u` names are fresh only against live whole-frontier marker
  support; and
- a name may be reused after the marker carrying it has been erased.

Copying a marker in `expose-choice-through-work-fresh` is therefore not an
allocation.

## Executable laws

For every genuine one-step successor encountered by randomized structural
generation in both kernel instances, and for every edge in the fixed traces,
the intrinsic suite checks:

- frontier events, query/raw answers, and scoped answers grow monotonically;
- `frontier-delta` is exactly one event for frontier-fresh exposure, answer
  commitment, or delay forcing, and empty for every other rule;
- answer count grows exactly on the two commitment rules or final success;
- `Forced` count grows exactly on `force-delay`;
- unit cost is the exact label-span length; and
- dynamic allocation events agree with genuine allocation-rule occurrences.

The allocation check counts raw `allocation-edge/K` proof trees as well as
their projected results, so duplicate derivations cannot be hidden by equal
event payloads.

For every reachable source frontier in representative Ktoy and Kmk traces,
the suite constructs D, Z, M, and B states and checks that each stage's public
readback has exactly the same observations.  A terminating direct big-step
result is checked against the final source frontier as well.  These are
finite-trace preservation checks; they do not prove termination, characterize
divergence, or add the deferred relation-call overlay.

The Q maps, marker/history erasure, anti-stuttering ranks, feature-lattice
naturality, and any weighted performance model remain separate later work.
