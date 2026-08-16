# Whole-Tree Delay/Disjunction Refocusing Spike

Status: executable research spike, 2026-08-15

This directory tests the source-first proposal described in
[`../DIRECTION.md`](../DIRECTION.md). It does not modify the production search
lattice.

## Question

The spike asks:

> If the source is a directed whole-tree calculus with a structurally distinct
> committed frontier, do decomposition and refocusing produce a useful
> delay/disjunction machine without first assuming `obs`, `answers + cfg`, or
> an answer-stream zipper?

For the pure control fragment implemented here, the answer is **yes**.

The whole-tree calculus represents the committed answer prefix and its
intervening scope/delay evidence directly in the frontier.
Decomposition turns the already-traversed portion of that frontier
into source-derived context frames, and refocusing reuses those frames
as machine state. The resulting machine is therefore zipper-shaped in
exactly the expected sense: its context stack is the defunctionalized
representation of the source frontier, not an external observation
list or independently postulated answer register.


An earlier draft of this report incorrectly treated repeated
`AnswerFresh(u, ...)` nodes as a possible reason to add a bounded frontier-scope
segment with a closing marker. That alternative has been removed. Repetition
is ownership evidence for the same already allocated logical variable after
several answers escape a branch-local subtree. Tree nesting already closes the
scope.

## Scope

The implemented fragment contains:

- success and failure
- an opaque state-producing atom, `put`
- lexical fresh binders, logical-variable allocation, capture-avoiding body
  substitution, and runtime introduction provenance
- conjunction
- disjunction
- suspension and delay forcing
- DFS and rail-style delay/disjunction scheduling
- early and late conjunction/disjunction policies
- committed answer, scope, and forced-delay frontier nodes

`put` deliberately stands in for local logic-state effects. Unification,
disequality, reification, and relation calls are not part of this spike. The
fresh rule does implement the relevant lexical-to-logical allocation and body
substitution boundary; the opaque state itself is unchanged by allocation in
this c-free control model.

## Presentation Diagram

The spike implements four carrier presentations:

```text
                 search
                 /    \
              delay  disj
                 \    /
                  core
```

Each `presentation` value carries executable counterparts of:

```text
< G, T, V, C, WF, ->, O >
```

Specifically, it contains goal-, tree-, value-, and context-language
predicates; a well-formedness predicate; a directed reducer; observations; and
a rule-ownership table.

The grammar ownership is:

- `core` owns `Work`, `Returned`, `Dead`, `WorkFresh`, `Conj`, `More`, `Done`,
  `Last`, ordinary `Answer`, and provisionally `FrontierFresh`.
- `delay` adds source `suspend`, runtime `PendingDelay`, frontier `Forced`, and
  its context frame.
- `disj` adds source `disj`, left-active runtime `DisjL`, `Emit`,
  `AnswerFresh`, and the choice and `emit-frame` context forms.
- `search` is the delay/disjunction union plus right-active `DisjR` and its
  frame.

`DisjR` is intentionally join-owned support syntax. Neither delay alone nor
disjunction alone needs a right-active branch. Their combination needs it when
rail scheduling crosses a pending delay:

```text
DisjL(PendingDelay(W1), W2)
  -> PendingDelay(DisjR(W1, W2))
```

The corresponding return move is:

```text
DisjR(W1, PendingDelay(W2))
  -> PendingDelay(DisjL(W1, W2))
```

DFS shares the combined carrier but carries the pending delay outward without
changing orientation, so `DisjR` remains unreachable in ordinary left-first
DFS traces.

## Source Tree

The executable grammar follows this schema:

```text
G ::= ...
    | FreshGoal(x*, G, tag)  ; lexical binders

Acore ::= Answer(state)

Adisj ::= Acore
        | AnswerFresh(intro, Adisj, tag)

W ::= Work(goal, state)
    | Returned(state)
    | Dead
    | WorkFresh(intro, W, tag)
    | PendingDelay(W)
    | Conj(W, goal)
    | DisjL(W, W)
    | DisjR(W, W)          ; search join only

F ::= More(W)
    | Done
    | Last(A)
    | FrontierFresh(intro, F, tag)
    | Emit(A, F)           ; disj and search only
    | Forced(F)            ; delay and search only

V ::= Done
    | Last(A)
    | FrontierFresh(intro, V, tag)
    | Emit(A, V)           ; disj and search only
    | Forced(V)            ; delay and search only
```

One `F` is one complete runtime configuration; `V` excludes the running
`More(W)` case. Source reduction is always `F -> F`.

Applying a source fresh goal is the sole logical-variable allocation rule:

```text
Work(FreshGoal(x*, g, tag), state)
  -> WorkFresh(u*, Work(g[u*/x*], state), tag)
```

The reducer chooses `u*` unused in the focused tree and its context, substitutes
through the body while respecting nested lexical shadowing, and installs one
runtime scope marker. Later copies of that marker preserve the same `u*` and
tag; they do not execute this rule again.

When that existing scope moves from unfinished `WorkFresh` work into the
frontier region, the core rule `expose-frontier-fresh` represents it with
`FrontierFresh`. This transition neither allocates variables nor substitutes
terms; it preserves the same introduction list and provenance tag around the
resulting frontier subtree.

The grammar directly enforces the central phase facts:

- `Last` contains the one answer produced directly by the terminal residual.
- `Emit` has one frozen `A` on the left and one remaining `F` on the right,
  and exists only at the disjunction and search nodes.
- No runnable `W` and no `Forced` marker can occur in an `A`.
- `Forced` occurs only on the frontier path.
- `PendingDelay` contains `W`, so it cannot contain a `Forced` node.
- Every `F` has exactly one rightward terminal: `More(W)`, `Done`, or
  `Last(A)`.
- `Emit`, `FrontierFresh`, and `Forced` form an immutable prefix around that
  terminal; reduction descends only into their child frontier.
- `Returned` remains WIP syntax; only frontier termination or disjunction
  promotion constructs `Answer`.

Representative traces finish as:

```text
zero answers:
  Done

one answer:
  Last(A)

one emitted answer followed by residual failure:
  Emit(A, Done)

two answers with forcing between them:
  Emit(A1, Forced(Last(A2)))

frontier fresh scope:
  FrontierFresh(u, Emit(A1, Last(A2)), tag)

branch-local fresh ownership:
  Emit(AnswerFresh(u, A1, tag),
    Emit(AnswerFresh(u, A2, tag),
      Last(...outside answer...)))
```

The last form prevents the branch-local variable from incorrectly owning later
answers from an outer alternative. Both `AnswerFresh` nodes refer to the same
allocation. This is the intended branch-local representation, not a fallback
for a missing delimiter.

## Directed Rules And Intermediate Evidence

The source reducer keeps administrative transitions explicit. It does not
silently flatten nested choices during answer commitment.

For example, a fresh scope local to an inner multi-answer branch first takes a
step analogous to:

```text
WorkFresh(u, DisjL(S, W), tag)
  -> DisjL(WorkFresh(u, S, tag),
           WorkFresh(u, W, tag))
```

Both copies contain the same already chosen `u` and provenance tag. The trace
contains no allocation transition at this step.

The current spike uses a context-sensitive combination: conjunction handoff
initially retains a factored `WorkFresh` around its continuation, while a
branch-local scoped choice distributes the stored marker when a settled inner
answer must be exposed without extending ownership to an outer alternative.
This is coherent on the present corpus, but it is not yet the controlled
factored-versus-distributed comparison. That comparison is the next experiment
specified in `FRESH-NORMALIZATION-EXPERIMENT.md`.

A settled nested left branch then reassociates one layer:

```text
DisjL(DisjL(S, W1), W2)
  -> DisjL(S, DisjL(W1, W2))
```

Core terminal results are direct residual outcomes:

```text
More(Returned(state))
  -> Last(Answer(state))

More(Dead)
  -> Done
```

Disjunction promotes a settled branch only while alternate work remains:

```text
More(DisjL(S, W))
  -> Emit(freeze(S), More(W))
```

Once constructed, an `Emit` is an immutable committed prefix. Decomposition
continues only into its right child, carrying `emit-frame(A)` so plugging
reconstructs the same constructor and left answer. There is deliberately no
rule:

```text
Emit(A, Done) -> Last(A)
```

Thus `Last(A)` and `Emit(A, Done)` have equal answer observations but remain
different whole-tree normal forms. The resulting equation is compositional:

```text
run(disj(success-producing-A, residual))
  = Emit(A, run(residual))
```

The executable payload observation follows:

```text
answers(Done)       = ()
answers(Last(A))    = (A)
answers(Emit(A, V)) = A :: answers(V)
```

`FrontierFresh` and `Forced` recurse into their child for this observation.
The spike also retains `extensional-answers`, which projects each payload to
its underlying state for corpus comparisons.

Delay movement is also explicit. A pending delay bubbles through fresh and
conjunction frames, crosses branch scheduling one layer at a time, and becomes
`Forced` only when it reaches `More`:

```text
More(PendingDelay(W))
  -> Forced(More(W))
```

Thus the source preserves the interleaving events that later transition
compression may choose to hide.

## Early And Late Policies

Early and late use the same search language, values, well-formedness, and
available context frames.

For the witness:

```text
conj(disj(g1, g2), h)
```

the early decomposer stops at the exposed conjunction/choice boundary. Its
next rule constructs:

```text
DisjL(Conj(W1, h), Conj(W2, h))
```

The late decomposer instead reaches the active `Work(g1, state)` with one
`conj-frame(h)` outside a `disj-left-frame(W2)`. The pending `h` therefore
exists once in the derived machine while `g1` runs. Only after that branch
returns does the late rule construct the continuation-bearing residual
choice.

The two policies produce the same answer sequence on the witness, but their
intermediate source trees, decompositions, and machine states differ exactly
at the expected conjunction/disjunction boundary.

This is evidence for retaining early/late as policy fibers over shared syntax.
It is not yet evidence that stream and multi-continuation natural semantics
must correspond to those policies.

## Decomposition And Refocusing

`decompose` follows the directed source contexts and returns:

```text
decomposition(sort, focus, context)
```

The source-derived frame vocabulary is:

```text
frontier frames:
  emit-frame(A)
  frontier-fresh-frame(intro, tag)
  forced-frame
  more-frame

work frames:
  fresh-frame(intro, tag)
  conj-frame(goal)
  disj-left-frame(W)
  disj-right-frame(W)
```

`more-frame`, `frontier-fresh-frame`, and the core work frames exist at core.
`emit-frame` appears only at disjunction/search, `forced-frame` only at
delay/search, and the right-active disjunction frame only at search.

Frames are stored innermost first. `plug` is their inverse, and the tests check
for every state in every corpus trace that:

```text
plug(decompose(F)) = F
```

The refocused state is only:

```text
refocused-machine(semantics, sort, focus, context)
```

It has no `obs`, answer list, answer register, residual stream, cached `c`, or
separate scheduler store. `machine-step` contracts the current focus and calls
`refocus` on the contractum and retained source context. It does not plug the
whole tree and decompose it from the root between transitions.

The tests compare every source and machine transition on the corpus:

- rule name agrees
- rule owner agrees
- reconstructing the next machine gives the next source tree
- final status and answer observation agree

### What happened to the zipper question

After one answer has been emitted, decomposition of:

```text
Emit(A, More(W))
```

necessarily reaches `W` with `emit-frame(A)` outside `more-frame`. This is a
zipper-shaped context because refocusing reifies source contexts.

The important distinction is provenance:

- The source calculus did not begin with a zipper or an external list.
- No special answer-stream data structure was added during contraction.
- The `emit-frame` is generated uniformly from the right-child context of the
  source `Emit` constructor.
- Replugging returns the exact whole source tree.

If the desired final machine should retain the complete tree while avoiding
even these frontier frames, that would require a different focusing boundary
or a machine with a direct pointer into persistent tree structure. It does not
fall out of ordinary syntactic refocusing. The current spike makes that design
choice visible rather than settling it by assumption.

## Diagram-Level Checks

The test suite checks the lower diagram rather than only the search endpoint:

- every node carries all seven presentation components;
- every core term embeds in core, delay, disj, and search;
- core and delay reject `Emit`, `AnswerFresh`, and `emit-frame`, while disj and
  search accept them;
- `Last` and direct terminal-success reduction belong to core and embed
  unchanged at every child;
- delay-only terms embed in search but not disj;
- disj-only terms embed in search but not delay;
- `DisjR` belongs only to search;
- complete core traces have identical transitions at every child node;
- complete delay traces are unchanged when embedded in search/DFS;
- complete disj traces are unchanged when embedded in search/DFS;
- rail crossing rules are recorded as `search-join` owned.

This is executable evidence for a presentation diagram. It is not a formal
commuting-diagram proof, but it tests the intended componentwise embeddings at
the implemented nodes.

## Corpus And Tests

The corpus includes nineteen scenarios:

- simple success
- simple failure
- conjunction handoff
- two disjunction answers
- successful-left/failed-right disjunction
- failed-left disjunction erasure
- two failed disjunction branches
- frontier fresh direct success
- frontier fresh answers
- frontier fresh answer followed by residual failure
- one branch-local fresh answer
- a branch-local fresh subtree with two answers and an outer alternative
- nested lexical fresh allocation with shadowing
- a top-level delay
- an answer followed by a delayed answer
- delayed-left rail interleaving
- both rail turn directions
- failed-right erasure while the rail is advancing right
- the early/late conjunction-over-disjunction witness

Run the spike with:

```bash
racket -y racket-server/derivations/refocusing/whole-tree-spike/run.rkt
```

The suite currently has sixteen test cases and checks all intermediate source
and refocused-machine states, not only endpoints.

## What This Establishes

The spike supports the following provisional conclusions.

1. `More(W)`, `Done`, and `Last(A)` give every frontier exactly one explicit
   terminal for this control fragment.
2. Core direct success and disjunction promotion are genuinely different:
   core constructs `Last(A)`, while disjunction constructs `Emit(A,F)` only
   when residual work remains.
3. `Emit(A,F)` is an immutable prefix compatible with small-step delay and
   interleaving evidence; it need not be reinterpreted as a list plus residual
   configuration or collapsed when its residual becomes `Done`.
4. The three success phases (`succeed`, `Returned`, `Answer`) are operationally
   useful and prevent premature commitment under conjunction.
5. `Forced` belongs on the frontier path and `PendingDelay` belongs in WIP.
6. A right-active branch form is a natural join-owned addition for rail
   scheduling.
7. Early and late naturally derive different focused states over one shared
   carrier.
8. Ordinary refocusing does derive frontier context frames, but it does not
   require an external observation accumulator.
9. The lower additive feature structure can be carried through grammar,
   reduction, context, observation, and refocusing checks node by node.
10. Source `fresh` and runtime fresh markers now have the correct phase split:
   allocation and lexical substitution happen once, while later marker copies
   preserve logical-variable identity and provenance.
11. Repeated `AnswerFresh` evidence and one enclosing `FrontierFresh` are
    structurally appropriate for branch-local and frontier scopes
    respectively; no closing marker is needed.

That is enough to justify continuing this source-first line before changing
the production lattice.

## What Remains Open

The spike does **not** yet justify a production rearchitecture. The next
obligations are:

1. Replace `put` with the real c-free logic-state kernel and extend the tested
   context-derived allocation rule to the full state and substitution model.
2. Add lexical scope and identifier-ownership judgments, not merely the
   current structural/distinct-introduction checks.
3. Run the factored-versus-distributed `WorkFresh` experiment specified in
   `FRESH-NORMALIZATION-EXPERIMENT.md`, carrying both candidates through the
   presentation diagram, decomposition, and refocusing.
4. Extend nested conjunction/disjunction/delay coverage beyond the focused
   witnesses and add property-based generation of well-formed trees.
5. State and test a representation relation to the current
   `ScopedTree`/`ScopedShell`/`Deferred`/rail runtime. Do not identify the two
   syntaxes directly.
6. Separate the decomposed presentation, refocused presentation, and a later
   localized current-style c-free machine as distinct artifacts if the next
   pass changes state vocabulary or transition granularity.
7. Only after that, test cached-`c` restoration and transition compression.

Stream and multi-continuation interpreters remain separate future functional-
correspondence projects. Nothing in this spike treats them as projections from
the refocused machine.

## Files

- `languages.rkt`: the four Redex carrier languages and membership checks
- `main.rkt`: presentations, directed relations, observations, decomposition,
  contraction, refocusing, and the c-free machine
- `corpus.rkt`: control witnesses
- `tests.rkt`: structural, diagram, policy, trace, and correspondence checks
- `run.rkt`: test runner
- `FRESH-NORMALIZATION-EXPERIMENT.md`: next nodewise experiment comparing one
  factored runtime scope with copies of the same scope marker in both branches
