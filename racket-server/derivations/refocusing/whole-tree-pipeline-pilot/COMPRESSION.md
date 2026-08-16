# Symbolic transition compression

Status: checkpoint 4 of the whole-tree pipeline pilot, 2026-08-16

This checkpoint symbolically composes the exact refocused transition system
from `refocused.rkt`.  A compressed move retains the nonempty, ordered sequence
of frozen source marks that it represents, but it need not stop after every
single source contraction.

`compressed.rkt` is a direct transition system.  Its transition clauses do not
call `source-step`, `contract`, `refocus-contract`, or `machine-step`, and they
do not run an exact step repeatedly until a predicate becomes true.  The pure
fresh-allocation kernel is stated locally.  The frozen source and exact machine
are oracles only in `tests/compression-tests.rkt`.

## Residual state space

The refocusing call graph leaves four recursive dispatch strongly connected
components and one final form:

```text
Compressed ::= CRun(W, WFCtx)
             | CSettled(R, WFCtx)
             | CDead(WFCtx)
             | CDelay(W, WFCtx)
             | CFinal(T, FFCtx)

R ::= S | DisjL(S, W) | DisjR(W, S)
T ::= Done | Last(A)
```

- `CRun` is downward work dispatch.
- `CSettled` is upward success and settled-choice dispatch.
- `CDead` is failure propagation.
- `CDelay` is delay propagation, including the rail/flip-flop turns.
- `CFinal` retains a terminal frontier and its surrounding frontier context.

There is no running-frontier mode.  `Emit`, `FrontierFresh`, and `Forced`
prefixes are retained in `FFCtx`, so a boundary contraction either enters one
of the four work dispatchers or constructs `CFinal`.

These constructors are the operational modes that remain after compression;
they are not a `W`/`F` field.  The term and context categories are implicit in
their constructor signatures and in the checkpoint-2 indexed context grammar.
There is no dynamic sort-compatibility predicate and no cached scope,
scheduler, answer, or observation register.

## Composition and stopping criterion

The exact machine has a downward dispatcher and upward resumption paths.  The
symbolic derivation inlines a path while the next contraction is determined by
the constructor and retained context already visible in the equation.  It
stops when either:

1. control returns to one of the four recursive dispatch components; or
2. the next rule discriminator is an arbitrary `W`, goal, or context tail.

In the second case, the datum is placed in the corresponding residual
constructor and inspected by the next compressed move.  Compression therefore
does not guess through unknown data and does not use an operational
"compressible state" predicate.

For example, an atomic success followed by a `ww-conj` frame has a statically
known `conj-return`, so both marks share a span.  Its resulting goal is unknown,
so the move stops in `CRun`.  A delay under `ww-disj-left` has a statically known
`rail-enter-right`; the result returns to the recursive delay dispatcher, so
the move stops in `CDelay` and `force-delay` belongs to the next span.

More-boundary priority is also composed symbolically.  A top-level allocation
produces an unfinished `WorkFresh` whose next rule must be
`expose-frontier-fresh`, giving:

```text
[ allocate-fresh/core, expose-frontier-fresh/core ]
```

The same allocation beneath a nonempty `WWCtx` stops after allocation because
the next source decision lies below retained work structure.

## Marked spans

Trace transport has three constructors:

```text
rule-mark(name, owner)
transition-span(mark, mark, ...)
compressed-transition(span, next)
```

`transition-span` rejects an empty mark list.  It preserves both the rule name
and owner in source order; compression never replaces a sequence with a new
unmarked macro-rule name.

The representative partitions include:

```text
nested fresh:
  [allocate-fresh, expose-frontier-fresh]
  [expand-disjunction]
  [allocate-fresh]
  [expand-disjunction]
  [work-put, expose-choice-through-work-fresh]
  [reassociate-left-result]
  [commit-choice-answer]
  [work-put, commit-choice-answer]
  [work-put, finish-success]

rail turn:
  [expand-disjunction]
  [suspend-goal, rail-enter-right]
  [force-delay]
  [suspend-goal, rail-return-left]
  [force-delay]
  [work-put, commit-choice-answer]
  [work-put, finish-success]

late hoist:
  [expand-conjunction]
  [expand-disjunction]
  [work-put, late-distribute-settled]
  [work-succeed, commit-choice-answer]
  [work-put, conj-return]
  [work-succeed, finish-success]
```

The executable golden partitions also record every owner.  In particular,
the fresh rules retain `core`, `disj`, or `search-join` as frozen, and both rail
turns retain `search-join`.

## Decoding and correspondence

`compressed->refocused` is a decoding function, not part of compressed
execution:

```text
decode(CRun(W, K))       = refocus-work(W, K)
decode(CSettled(R, K))   = refocus-work(R, K)
decode(CDead(K))         = refocus-work(Dead, K)
decode(CDelay(W, K))     = refocus-work(PendingDelay(W), K)
decode(CFinal(T, KF))    = refocus-frontier(T, KF)
```

For each reachable compressed move, the tests replay its marks one at a time
in the exact refocused machine and check the stronger endpoint equation:

```text
C --[m1 ... mn]--> C'
decode(C) --m1--> ... --mn--> M'
--------------------------------
decode(C') = M'
```

Replay compares each complete `rule-mark(name, owner)`, not only the number of
steps or the final tree.  Over complete traces, concatenating all span marks
must equal the exact marked trace, the final decoded state must be identical,
and the value/stuck status must agree.  This is a trace partition and exact
marker-identity result; it is not merely extensional answer agreement.

The suite also checks every reachable mode's WFCtx or FFCtx family, duplicate
source-name rejection at entry, both fresh-exposure owners, both rail turns,
and genuine two- and three-rule spans.

Run this checkpoint alone with:

```sh
raco test racket-server/derivations/refocusing/whole-tree-pipeline-pilot/tests/compression-tests.rkt
```

Run all pilot checkpoints through this stage with:

```sh
racket -y racket-server/derivations/refocusing/whole-tree-pipeline-pilot/tests/run.rkt
```

Fixed-point promotion is deliberately left to the next checkpoint.  Numeric or
cached scope, fresh-marker erasure, and any stuttering quotient remain later
comparison experiments rather than prerequisites of this marked machine.
