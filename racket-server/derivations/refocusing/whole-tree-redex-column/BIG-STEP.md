# Fixed-point promotion in Redex

This checkpoint makes the final marked-column arrow

```text
B_marked -> B_downarrow
```

visible as two independently executable Redex presentations.

## Shared result grammar

`big-step-language.rkt` adds only the category-specific result

```text
FinalResult(T, FF)
```

where `T` is `Done` or `Last(A)` and `FF` is an actual-hole `F -> F`
context.  The result has no W/F tag or compatibility field.  Its readback is
ordinary context filling.

The shared language repeats the residual `B` and certificate grammars only so
the closure specification can state its input and witness.  It extends the
source grammar directly; the direct promoted module has no operational import
from compression, the exact machine, refocusing, decomposition, or the source
relation.

## Closure specification

`compressed-big-step/spec` is the strict driver expressed as an inductive
Redex judgment:

```text
BFinal(T, FF)  ⇓spec[()]  FinalResult(T, FF)

B --Span--> B'    B' ⇓spec[Spans] O
-----------------------------------
B ⇓spec[Span :: Spans] O
```

The complete ordered macro-span list remains an output.  Consequently the
specification witnesses not only the final observation but the precise
small-step derivation being promoted.  `big-step/spec` composes this driver
with compressed initialization from a well-formed root.  The `*-result/spec`
judgments are explicit certificate-erasing projections for clients that need
only `O`.

## Direct promoted artifact

`big-step.rkt` is the fixed point obtained by inlining the strict driver and
the direct compressed clauses, distributing recursive calls into their
branches, and replacing recurrent compositions with five mode judgments:

```text
big-run/direct(NW, WF, O)
big-settled/direct(SR, WF, O)
big-dead/direct(WF, O)
big-delay/direct(W, WF, O)
big-final/direct(T, FF, O)
```

`NW` is unfinished work, so the running entry cannot also encode a settled,
dead, or delayed residual phase.  `EQFresh` is indexed by `WF+`, because a
fresh node immediately below `More` is handled by frontier exposure rather
than branch-local traversal.

Redex does not permit forward references among separately declared mutually
recursive judgments.  The private `EQ` grammar therefore names derivation
program points for one self-recursive `evaluate-query/direct` judgment.  `EQ`
terms are not semantic states: they carry no labels, spans, cached data, or
sort tag, and arbitrary generated `EQ` queries have at most one raw
derivation.

`promote/direct` is the explicit, nonrecursive `B -> O` translation that
dispatches the five `B` constructors to their corresponding mode entry.
`big-step/direct` separately enters the fixed point from `F`; it accumulates
frontier prefixes directly and never constructs a `B` state.

## Executable arrow laws

`big-step-correspondence.rkt` exposes three judgments:

- `big-step-square(B, Spans, O)` requires both the certified strict-driver
  derivation and the direct promoted derivation.
- `big-step-unfold-square(B, Span, B', Spans, O)` records that removing one
  small step removes exactly the first certificate while preserving the
  direct outcome.
- `root-big-step-square(F, Spans, O)` compares root initialization-plus-driver
  with direct root entry.

The tests compare complete result sets in both directions for every suffix of
the witness executions.  They also check exact certificate lists, raw proof
uniqueness, all five mode entries and their `promote/direct` bridge, one-step
unfolding, prefixed frontier readback, malformed-root rejection, 500 generated
well-formed roots, 1,000 generated private queries, and 1,000 generated `B`
states.

## Divergence boundary

These inductive judgments establish equivalence when a finite result
derivation exists.  Failure to derive a result does not distinguish divergence
from a stuck or ill-formed term.  Nonempty compression spans rule out infinite
zero-step administrative stuttering, but they do not prove termination or a
coinductive divergence theorem.  Once relation calls are added, a
divergence-sensitive observational claim will need an infinite-trace,
coinductive, or step-indexed semantics in addition to this finite big-step
square.
