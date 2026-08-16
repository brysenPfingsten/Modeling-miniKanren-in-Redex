# Fixed-point-promoted evaluator

Status: checkpoint 5 of the whole-tree pipeline pilot, 2026-08-16

This checkpoint fuses the strict driver of the checkpoint-4 compressed machine
with its direct transition clauses.  The result is a big-step abstract machine:
five mutually tail-recursive functions directly evaluate the arguments of the
five compressed modes.  They do not construct a compressed state, marked span,
transition, decomposition, or contraction on the recursive path.

The transformation is lightweight fusion by fixed-point promotion in the
sense used by Danvy and Millikin for the equivalence of small-step machines
with a driver loop and big-step, tail-recursive abstract machines.  Refocusing
and symbolic compression have already supplied the small-step machine; this
checkpoint inlines its strict driver, distributes the driver into every
clause, simplifies known constructors, and promotes the resulting compositions
to recursive functions.

## Result space

The evaluator returns only:

```text
PromotedOutcome ::= PromotedFinal(T, FFCtx)
                  | PromotedStuck(W, WFCtx)

T ::= Done | Last(A)
```

The constructors encode the distinct result categories in their fields.  They
do not carry a `W`/`F` tag, status field, scheduler register, cached scope,
answer register, trace accumulator, or observation register.  A final outcome
is distinguished from a stuck work outcome by its constructor.

`fixed-point-readback` is observational:

```text
readback(PromotedFinal(T, KFF)) = plug-ff(T, KFF)
readback(PromotedStuck(W, KWF)) = plug-wf(W, KWF)
```

Neither plug function is called during evaluation.

## Driver before fusion

The strict checkpoint-4 driver used as the test-only specification is:

```text
drive(CFinal(T, KFF)) = PromotedFinal(T, KFF)

compressed-step(C) = #f
-----------------------------------------
drive(C) = erase-stuck(C)

compressed-step(C) = compressed-transition(span, C')
------------------------------------------------------
drive(C) = drive(C')
```

`span` is inspected by the test oracle and is nonempty, but it is erased from
the result.  Checkpoint 4 has already proved that these spans partition the
exact marked trace.  Erasing transport evidence here therefore happens after,
not instead of, the marked-machine derivation.

For the five compressed constructors, form these compositions:

```text
DR(W, K) = drive(CRun(W, K))
DS(R, K) = drive(CSettled(R, K))
DD(K)    = drive(CDead(K))
DL(W, K) = drive(CDelay(W, K))
DF(T, K) = drive(CFinal(T, K))
```

Inline `compressed-step` into each composition.  Distribute `drive` into the
result clauses and simplify every known next constructor:

```text
drive(compressed-transition(span, CRun(W, K)))
  = DR(W, K)

drive(compressed-transition(span, CSettled(R, K)))
  = DS(R, K)

drive(compressed-transition(span, CDead(K)))
  = DD(K)

drive(compressed-transition(span, CDelay(W, K)))
  = DL(W, K)

drive(compressed-transition(span, CFinal(T, K)))
  = DF(T, K)
```

Promoting these five compositions to their own fixed points yields the private
functions `run`, `settled`, `dead`, `delay`, and `final`.  Their public entry
functions are `fixed-run`, `fixed-settled`, `fixed-dead`, `fixed-delay`, and
`fixed-final`.  Public validation happens once at entry; recursive calls go
directly among the private functions.

## Constructor-erased syntactic dispatch

Checkpoint 4 used `residual-work` to choose a residual constructor and
`after-unfinished` to account for More-boundary priority.  Distributing the
driver through those two helper results gives:

```text
continue-work(Dead, K)             = DD(K)
continue-work(PendingDelay(W), K)  = DL(W, K)
continue-work(R, K)                = DS(R, K)
continue-work(W, K)                = DR(W, K), otherwise
```

and, at `wf-more(ww-hole, KFF)`:

```text
continue-unfinished(WorkFresh(i, W, t), wf-more(ww-hole, KFF))
  = continue-work(W,
                  wf-more(ww-hole,
                          ff-frontier-fresh(i, t, KFF)))
```

All other `continue-unfinished` cases tail-call `continue-work` unchanged.

The implementation retains these two constructor-erased syntactic dispatch
helpers because they avoid duplicating the same W-shape case analysis.  They
are not a generic next-state driver: neither accepts a compressed-state sum,
neither calls a step function, and neither constructs a mode or transport
value.  Each branch tail-calls one of the five direct functions.

## Direct control equations

The promoted functions are the checkpoint-4 symbolic clauses with marks and
state constructors erased:

- `run` honors More-boundary priority, handles an atomic `Work`, or descends
  through the active child while extending the appropriate `WWCtx`.
- `settled` crosses success frames directly.  At a fresh, conjunction, or
  choice rule it constructs only the source contractum and tail-calls the
  next direct function.  At `ww-hole`, it commits an answer or calls `final`.
- `dead` removes fresh and conjunction frames, selects a disjunction
  alternate, or calls `final(Done, KFF)` at More.
- `delay` bubbles through fresh and conjunction, performs both rail turns,
  or forces at More and calls the direct work dispatcher under `ff-forced`.
- `final` constructs `PromotedFinal` and does not recurse.

Representative fused equations are:

```text
run(Work(succeed(t), st), K)
  = settled(Returned(st), K)

run(Work(suspend(g, t), st), K)
  = delay(Work(g, st), K)

settled(S, wf-more(ww-conj(g, KWW), KFF))
  = continue-unfinished(resume-success(S, g),
                        wf-more(KWW, KFF))

dead(wf-more(ww-disj-left(W, KWW), KFF))
  = continue-work(W, wf-more(KWW, KFF))

delay(W, wf-more(ww-disj-left(W2, KWW), KFF))
  = delay(DisjR(W, W2), wf-more(KWW, KFF))

delay(W, wf-more(ww-hole, KFF))
  = continue-work(W, wf-more(ww-hole, ff-forced(KFF)))
```

Every recursive call in these equations is in tail position.  The recursive
path constructs source terms and indexed contexts when a rule requires them,
but no `CRun`-family value, marked transport value, decomposition, contraction,
or promoted outcome is constructed between calls.  `PromotedFinal` and
`PromotedStuck` occur only at base outcomes.

## Direct frontier entry

`fixed-point-evaluate` validates the frozen source invariant and descends the
root frontier itself:

```text
entry(Emit(A, F), K)              = entry(F, ff-emit(A, K))
entry(FrontierFresh(i, F, t), K)  = entry(F, ff-frontier-fresh(i, t, K))
entry(Forced(F), K)               = entry(F, ff-forced(K))
entry(More(W), K)                 = continue-work(W, wf-more(ww-hole, K))
entry(Done, K)                    = final(Done, K)
entry(Last(A), K)                 = final(Last(A), K)
```

It does not call root decomposition or compressed initialization.

## Executable correspondence

`tests/fixed-point-tests.rkt` keeps checkpoint-4 operations in a test-only
oracle and checks:

1. every reachable compressed suffix state is equal to its corresponding
   promoted mode entry after the strict marked driver finishes;
2. every reachable state satisfies the one-step unfold equation: a promoted
   result equals the promoted result of its marked compressed successor;
3. the witness and directed-rule corpus reaches all five entries;
4. direct entry, final readback, and source observation agree with the marked
   compressed and frozen source stages;
5. only the two category-specific promoted result constructors remain;
6. the module contains no prior-stage operational import, call, state,
   transport, decomposition, or contraction constructor; and
7. a 10,000-delay finite witness completes with the expected 10,000 retained
   `ff-forced` frames, exercising proper tail calls.

Run this checkpoint alone with:

```sh
raco test racket-server/derivations/refocusing/whole-tree-pipeline-pilot/tests/fixed-point-tests.rkt
```

Run the complete vertical pilot with:

```sh
racket -y racket-server/derivations/refocusing/whole-tree-pipeline-pilot/tests/run.rkt
```

Numeric or cached scope, fresh-marker erasure, and a later stuttering quotient
remain comparison experiments.  None is a prerequisite of this marked
source-to-promoted derivation.
