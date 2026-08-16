# Indexed Decomposition And Contraction

Status: checkpoint 2 of the whole-tree pipeline pilot, 2026-08-16

This checkpoint derives an indexed context structure, decomposition, plugging,
and contraction from the marked source calculus frozen in `SOURCE.md`. It does
not import or call the frozen source stepper. The source reducer remains an
oracle used only by the test layer.

The derived step still has the marked source's one-step granularity. It is not
yet the refocused machine, a compressed transition system, or a fixed-point
machine.

## Indexed Context Families

The executable grammar in `decomposition.rkt` adds three context families:

```text
WWCtx ::= ww-hole
        | ww-fresh(intro, tag, WWCtx)
        | ww-conj(goal, WWCtx)
        | ww-disj-left(right-work, WWCtx)
        | ww-disj-right(left-work, WWCtx)

FFCtx ::= ff-hole
        | ff-frontier-fresh(intro, tag, FFCtx)
        | ff-emit(answer, FFCtx)
        | ff-forced(FFCtx)

WFCtx ::= wf-more(WWCtx, FFCtx)
```

These are one indexed inductive structure:

```text
WWCtx : W -> W
WFCtx : W -> F
FFCtx : F -> F
```

The indices are the grammatical input and output categories. They are not
runtime fields. `WFCtx` records the unique composition of an inner `W -> W`
path, the `More` bridge, and an outer `F -> F` path.

Constructors are stored nearest frame first. For example:

```text
wf-more(
  ww-disj-left(W2, ww-fresh(u*, tag, ww-hole)),
  ff-forced(ff-emit(A, ff-hole)))
```

means that the focused work first receives its fresh wrapper, then becomes the
left branch beside `W2`, crosses `More`, and is finally wrapped by `Emit` and
`Forced` on the path to the root.

There is deliberately no:

- generic unindexed frame list;
- explicit `W` or `F` field;
- dynamic sort-compatibility predicate;
- answer or observation register;
- cached scope `c`.

## Decomposition Results

The two result constructors encode the genuinely different focus shapes:

```text
DecWork(focus: W, context: WFCtx)
DecFrontier(focus: F, context: FFCtx)
```

Reachable `DecFrontier` foci are `Done` and `Last(A)`. Frontier prefixes are
decomposed into `FFCtx`; they are not treated as terminal foci.

Contraction likewise distinguishes the category of its replacement:

```text
ContractWork(name, owner, replacement: W, context: WFCtx)
ContractFrontier(name, owner, replacement: F, context: FFCtx)
```

The constructor determines the replacement/context categories. No separate
result sort is stored or checked.

## Plugging

There are three category-specific plugging functions:

```text
plug-ww : W x WWCtx -> W
plug-wf : W x WFCtx -> F
plug-ff : F x FFCtx -> F
```

`plug` accepts a complete `DecWork` or `DecFrontier` value, while
`plug-contract` accepts a complete `ContractWork` or `ContractFrontier`. Thus a
caller never supplies an arbitrary focus/context pair to a generic plugger.

For every state in every frozen source trace, the tests check:

```text
plug(decompose(F)) = F
```

They also check that every produced context belongs to the Redex nonterminal
selected by its result constructor.

## Focus Selection

Decomposition follows the deterministic direction already fixed by the source.
It focuses the complete source redex for each named rule, rather than always
descending to the smallest leaf and recovering a rule by inspecting unrelated
frames.

Examples of compound `W` foci include:

```text
WorkFresh(u*, Dead, tag)
WorkFresh(u*, PendingDelay(W), tag)
Conj(S, goal)
Conj(DisjL(S, W), goal)
DisjL(PendingDelay(W1), W2)
DisjR(W1, DisjL(S, W2))
```

This choice preserves a one-to-one correspondence between a decomposition,
one contraction, and one marked source transition.

### Fresh choice exposure

The branch-local factored forms:

```text
WorkFresh(u*, DisjL(S, W), tag)
WorkFresh(u*, DisjR(W, S), tag)
```

are each focused as the entire `WorkFresh` node. Decomposition does not focus
`S` with separate fresh and choice frames. Their contractions are the frozen
left- and right-active `expose-choice-through-work-fresh` rules, including the
original owner and identical copies of `u*` and `tag`.

The same syntactic `WorkFresh` immediately below `More` has a different indexed
context shape:

```text
wf-more(ww-hole, FFCtx)
```

At that shape, contraction applies `expose-frontier-fresh` before considering
the child's choice. This is not a dynamic sort test. It is the source's frozen
frontier-boundary priority, witnessed by the `W -> F` context constructor.

The tests contrast these cases directly:

```text
Forced(More(WorkFresh(u*, DisjL(S, W), tag)))
  -> expose-frontier-fresh

More(DisjL(WorkFresh(u*, DisjL(S, W), tag), Woutside))
  -> expose-choice-through-work-fresh
```

They also check the right-active case and require its `search-join` owner.

## Independent Contraction

`contract` implements the marked rules over `DecWork` and `DecFrontier`. It
does not call `source-step`, the spike's contract function, or any machine.

Only the six rules owned by the `More` boundary consume `wf-more` and return a
`ContractFrontier`:

- `expose-frontier-fresh`;
- `finish-success`;
- `finish-failure`;
- `force-delay`;
- `commit-choice-answer`;
- `commit-right-choice-answer`.

Every other contraction returns `ContractWork` with the same `WFCtx`.
`DecFrontier` does not contract.

Fresh allocation reconstructs the globally used logical-variable set from the
focused work and its indexed context. It therefore needs neither a cached `c`
nor a plug-and-rescan of an independently represented source tree. A targeted
test places used variables in both the `WWCtx` and `FFCtx` portions and requires
the derived allocator to choose the same next variable as the frozen source.

## Lockstep Evidence

`derived-source-step` performs:

```text
F
  -> decompose(F)
  -> contract(decomposition)
  -> plug-contract(contraction)
  -> F'
```

It owns its own `derived-transition` result and has no runtime dependency on the
frozen source reducer. Tests use `source-step` only from the oracle side and
compare, at every state of all representative traces:

- rule name;
- rule owner;
- complete next source tree;
- terminal absence of a step.

The representative traces cover nested frontier/branch-local fresh scope,
late hoisting, both rail turns, and right-active fresh exposure.

Run both checkpoint suites with:

```bash
racket -y racket-server/derivations/refocusing/whole-tree-pipeline-pilot/tests/run.rkt
```

At this checkpoint the aggregate runner reports eighteen passing test cases:
nine frozen-source cases and nine indexed-decomposition cases. In addition to
the representative traces, the latter exercise the remaining failure and
right-reassociation rules individually.

## Checkpoint Boundary

This checkpoint establishes decomposition and contraction only. It intentionally
does not yet provide:

- a refocused state transition that reuses the retained context without
  rebuilding the whole tree;
- transition compression or a stuttering relation;
- fixed-point promotion;
- numeric/cached `c` restoration or fresh-marker erasure;
- a production-lattice representation claim.

Those later stages must consume the indexed constructors here and preserve the
marked-source lockstep established by this checkpoint.
