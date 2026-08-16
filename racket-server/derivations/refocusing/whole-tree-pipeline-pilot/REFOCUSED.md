# Exact refocused machine

Status: checkpoint 3 of the whole-tree pipeline pilot, 2026-08-16

This checkpoint turns the indexed decomposition and contraction from
`decomposition.rkt` into an exact refocused machine.  It preserves every marked
source rule.  One machine transition contracts one source redex, retains its
indexed context, and finds the next decomposition without plugging a whole tree
or decomposing again from the root.

## State space

The machine state is exactly:

```text
Machine ::= DecWork(W, WFCtx)
          | DecFrontier(F, FFCtx)
```

These are the checkpoint-2 decomposition results, not new wrappers around
them.  Their grammatical input and output categories remain implicit in the
constructor and context family.  No state contains a `W`/`F` field and there is
no dynamic sort-compatibility condition.

`DecWork` is the running form, though a malformed-but-grammatical source shape
can also leave it stuck.  `DecFrontier` contains a terminal `Done` or `Last`
focus and is final.  Success, failure, delay, left/right scheduling, and fresh
scope are source syntax or context frames; none warrants another state
constructor at this exact stage.

`machine-transition(name, owner, next)` is transport between states.  It is not
a machine-state constructor.

## Entry and readback

Root decomposition is used only to enter the machine:

```text
initial-machine(F) = decompose(F)
```

Readback applies the context family selected by the state constructor:

```text
readback(DecWork(W, KWF))     = plug-wf(W, KWF)
readback(DecFrontier(F, KFF)) = plug-ff(F, KFF)
```

Readback is observational.  `machine-step` and the refocusing functions do not
call it.

## Work refocusing

Refocusing needs both a downward search and an upward resumption.  The derived
completed-work class is:

```text
R ::= S
    | Dead
    | PendingDelay(W)
    | DisjL(S, W)
    | DisjR(W, S)
```

This is a subset of the source `W` grammar, not a reified machine sort.

For a work contractum and its retained bridge:

```text
refocus-work(W, wf-more(KWW, KFF)) = search(W, KWW, KFF)
```

`search` uses the following priority:

1. If `KWW = ww-hole` and `W` is a More-boundary redex, focus `W` with
   `wf-more(ww-hole, KFF)`.
2. If `W` is a local work redex, focus it with the retained
   `wf-more(KWW, KFF)`.
3. If `W` belongs to `R`, resume it into the nearest `KWW` frame.
4. Otherwise descend through the active child, retaining exactly one new
   nearest-first `WWCtx` frame.

The downward equations are:

```text
search(WorkFresh(i, W, t), K, KF)
  = search(W, ww-fresh(i, t, K), KF)

search(Conj(W, g), K, KF)
  = search(W, ww-conj(g, K), KF)

search(DisjL(W1, W2), K, KF)
  = search(W1, ww-disj-left(W2, K), KF)

search(DisjR(W1, W2), K, KF)
  = search(W2, ww-disj-right(W1, K), KF)
```

Resumption rebuilds one source parent and searches again:

```text
resume(R, ww-hole, KF)
  = DecWork(R, wf-more(ww-hole, KF))

resume(R, ww-fresh(i, t, K), KF)
  = search(WorkFresh(i, R, t), K, KF)

resume(R, ww-conj(g, K), KF)
  = search(Conj(R, g), K, KF)

resume(R, ww-disj-left(W, K), KF)
  = search(DisjL(R, W), K, KF)

resume(R, ww-disj-right(W, K), KF)
  = search(DisjR(W, R), K, KF)
```

The first priority clause is essential.  `allocate-fresh` can produce
`WorkFresh(i, Work(...), t)` with no `WWCtx` frame.  The next source rule is
`expose-frontier-fresh`; descending into the inner `Work` would violate the
frozen source order.

## Frontier refocusing

Frontier refocusing traverses only the new contractum and extends the retained
frontier context:

```text
refocus-frontier(Emit(A, F), K)
  = refocus-frontier(F, ff-emit(A, K))

refocus-frontier(FrontierFresh(i, F, t), K)
  = refocus-frontier(F, ff-frontier-fresh(i, t, K))

refocus-frontier(Forced(F), K)
  = refocus-frontier(F, ff-forced(K))

refocus-frontier(More(W), K)
  = search(W, ww-hole, K)

refocus-frontier(Done, K)
  = DecFrontier(Done, K)

refocus-frontier(Last(A), K)
  = DecFrontier(Last(A), K)
```

`refocus-contract` selects `refocus-work` or `refocus-frontier` from the
`ContractWork` or `ContractFrontier` constructor.  That constructor already
encodes the replacement and context categories.

## Transition equation

```text
contract(M) = #f
--------------------------------
machine-step(M) = #f

contract(M) = ContractWork(n, o, W, K)
------------------------------------------------------
machine-step(M) = machine-transition(n, o,
                                     refocus-work(W, K))

contract(M) = ContractFrontier(n, o, F, K)
----------------------------------------------------------
machine-step(M) = machine-transition(n, o,
                                     refocus-frontier(F, K))
```

There is no silent machine step.  Rule names and owners are carried unchanged.

## Correspondence checked

The tests check the following strong form over every state in the four frozen
golden traces and the remaining directed-rule witnesses:

```text
readback(initial-machine(F)) = F

source-step(F) = transition(n, o, F')
machine-step(M) = machine-transition(n, o, M')
readback(M) = F
------------------------------------------------------
readback(M') = F'
```

Final and stuck results must also agree on the same step.  Thus the comparison
includes every rule name, owner, and intermediate tree, not only endpoints.

As a derivation oracle used only by the test layer, every actual contraction
also satisfies:

```text
readback(refocus-contract(C)) = plug-contract(C)

refocus-contract(C) = decompose(plug-contract(C))
```

The implementation of refocusing does not establish these equations by
calling either right-hand side.

Run all pilot checkpoints with:

```sh
racket -y racket-server/derivations/refocusing/whole-tree-pipeline-pilot/tests/run.rkt
```
