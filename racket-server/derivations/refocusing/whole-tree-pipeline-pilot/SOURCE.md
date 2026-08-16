# Frozen Source Calculus

Status: checkpoint 1 of the whole-tree pipeline pilot, 2026-08-16

This directory is a vertical-depth sibling of `../whole-tree-spike/`. It freezes
one source cell before deriving any decomposition or machine:

- full delay/disjunction search carrier;
- late conjunction hoisting;
- rail scheduling with explicit left- and right-active choices;
- factored fresh scope with one explicit exposure rule;
- no relation-call overlay.

There are no policy switches in this artifact. The source implementation does
not import or invoke the spike's decomposition, contraction, refocusing, or
machine functions. The test layer uses the spike only as a one-way trace oracle;
it is not an implementation dependency of the pilot source relation.

## Stratified Source Grammar

The important part of the executable grammar in `language.rkt` is:

```text
G ::= Succeed(tag)
    | Fail(tag)
    | Put(payload, tag)
    | FreshGoal(x*, G, tag)
    | ConjGoal(G, G, tag)
    | DisjGoal(G, G, tag)
    | Suspend(G, tag)

A ::= Answer(state)
    | AnswerFresh(u*, A, tag)

S ::= Returned(state)
    | WorkFresh(u*, S, tag)

W ::= Work(G, state)
    | Returned(state)
    | Dead
    | WorkFresh(u*, W, tag)
    | Conj(W, G)
    | PendingDelay(W)
    | DisjL(W, W)
    | DisjR(W, W)

F ::= More(W)
    | Done
    | Last(A)
    | FrontierFresh(u*, F, tag)
    | Emit(A, F)
    | Forced(F)

V ::= Done
    | Last(A)
    | FrontierFresh(u*, V, tag)
    | Emit(A, V)
    | Forced(V)
```

`S` is a grammatical subset used to state rules about settled success. It is
not a constructor and does not occur as a sort tag in a term.

This is a stratified grammar: unfinished work has category `W`, while a whole
frontier has root category `F`. The intended description is **sorts implicit in
the grammar, with no reified sort tags**. In particular, `Emit`, `Forced`, and
`FrontierFresh` cannot occur inside `W`, and runnable work cannot occur inside
an answer.

Every `F` has exactly one rightward terminal: `More(W)`, `Done`, or `Last(A)`.
The other frontier nodes form an immutable prefix around that terminal.

## Directed Focus

The source relation is `F -> F`. Its deterministic direction is part of the
frozen source semantics:

- descend through the child of `Emit`, `FrontierFresh`, and `Forced`;
- at `More`, perform a frontier-boundary rule before descending into `W`;
- descend through the left child of `Conj`;
- descend through the active child of `DisjL` or `DisjR`;
- descend through `WorkFresh` except when a boundary rule applies;
- do not descend through `PendingDelay` until the delay has moved to `More` and
  become `Forced`.

`source.rkt` implements this direction by direct recursive source rewriting.
It does not create a decomposition or a continuation data structure. Indexed
context families are intentionally a later derivation artifact.

## Fresh Allocation And Ownership

Lexical variables `x` and allocated logical variables `u` are distinct syntax.
Allocation occurs only in:

```text
Work(FreshGoal(x*, g, tag), state)
  -> WorkFresh(u*, Work(g[u*/x*], state), tag)
```

This rule is named `allocate-fresh`. It chooses globally unused `u*`, performs
capture-avoiding substitution through the body, and leaves the opaque state
unchanged. Later occurrences of the same `u*` and tag are provenance markers;
they do not allocate again.

A `WorkFresh` immediately below `More` crosses the unfinished/frontier phase
boundary before its child is evaluated:

```text
More(WorkFresh(u*, W, tag))
  -> FrontierFresh(u*, More(W), tag)
```

This `expose-frontier-fresh` rule preserves one wrapper around all of the
affected committed answers and residual work.

### The frozen factored-choice rule

Let `S` be a settled active success. The only rule that exposes a choice through
unfinished fresh scope is named exactly
`expose-choice-through-work-fresh`:

```text
WorkFresh(u*, DisjL(S, W), tag)
  -> DisjL(WorkFresh(u*, S, tag),
           WorkFresh(u*, W, tag))

WorkFresh(u*, DisjR(W, S), tag)
  -> DisjR(WorkFresh(u*, W, tag),
           WorkFresh(u*, S, tag))
```

Both descendants receive the identical already allocated `u*` and provenance
tag. The rule is enabled only after the active branch settles. It is **not** a
general equation that distributes fresh scope through every choice, and it is
not an allocation rule.

This exact operational boundary resolves the nested branch-local case. Before
the rule, one `WorkFresh` remains factored around the inner choice. A unary
wrapper cannot remain single after that choice is reassociated to expose an
answer while also excluding an outside alternative from its ownership.
Therefore the named step copies the marker onto the settled branch and its
inner residual. Generic reassociation and commitment then proceed as their own
later source steps.

The golden nested witness makes both ownership boundaries explicit:

```text
FrontierFresh(u:0,
  More(
    DisjL(
      WorkFresh(u:1, DisjL(S, W), branch-tag),
      W2)),
  outer-tag)

  -- expose-choice-through-work-fresh -->

FrontierFresh(u:0,
  More(
    DisjL(
      DisjL(
        WorkFresh(u:1, S, branch-tag),
        WorkFresh(u:1, W, branch-tag)),
      W2)),
  outer-tag)
```

The outer `u:0` wrapper owns `S`, `W`, and `W2`. The two identical `u:1`
markers own `S` and `W`, but neither encloses `W2`. After generic
reassociation and commitment, the two inner answers carry
`AnswerFresh(u:1, ..., branch-tag)` and the answer from `W2` does not.

## Remaining Source Rules

The other rules stay explicit so later passes can state exactly what they
compress.

### Core

```text
Work(Succeed(tag), state) -> Returned(state)
Work(Fail(tag), state)    -> Dead
Work(Put(p, tag), state)  -> Returned(State(p))

Work(ConjGoal(g1, g2, tag), state)
  -> Conj(Work(g1, state), g2)

Conj(S, g)    -> resume(S, g)
Conj(Dead, g) -> Dead
WorkFresh(u*, Dead, tag) -> Dead

More(Returned(state)) -> Last(Answer(state))
More(Dead)            -> Done
```

`resume` preserves every enclosing `WorkFresh` in `S` while replacing its
innermost `Returned(state)` with `Work(g, state)`. `freeze` performs the
corresponding phase change from `Returned`/`WorkFresh` to
`Answer`/`AnswerFresh` at answer commitment.

### Disjunction and late hoisting

```text
Work(DisjGoal(g1, g2, tag), state)
  -> DisjL(Work(g1, state), Work(g2, state))

Conj(DisjL(S, W), g)
  -> DisjL(resume(S, g), Conj(W, g))

Conj(DisjR(W, S), g)
  -> DisjR(Conj(W, g), resume(S, g))

DisjL(Choice(S, W), W2)
  -> DisjL(S, DisjL(W, W2))

DisjR(W2, Choice(W, S))
  -> DisjR(DisjR(W2, W), S)

More(DisjL(S, W)) -> Emit(freeze(S), More(W))
More(DisjR(W, S)) -> Emit(freeze(S), More(W))

DisjL(Dead, W) -> W
DisjR(W, Dead) -> W
```

Here `Choice(S,W)` abbreviates either orientation with active settled branch
`S` and alternate `W`. The two reassociation rules retain their explicit source
steps; the fresh exposure rule does not silently perform them. Likewise, late
hoisting waits for the active branch to settle before distributing the pending
conjunct.

Core produces `Last(A)` for a direct terminal answer. Disjunction produces
`Emit(A,F)` only while alternate work remains. There is deliberately no rule
collapsing `Emit(A,Done)` to `Last(A)`.

### Delay and rail scheduling

```text
Work(Suspend(g, tag), state)
  -> PendingDelay(Work(g, state))

WorkFresh(u*, PendingDelay(W), tag)
  -> PendingDelay(WorkFresh(u*, W, tag))

Conj(PendingDelay(W), g)
  -> PendingDelay(Conj(W, g))

DisjL(PendingDelay(W1), W2)
  -> PendingDelay(DisjR(W1, W2))

DisjR(W1, PendingDelay(W2))
  -> PendingDelay(DisjL(W1, W2))

More(PendingDelay(W))
  -> Forced(More(W))
```

`DisjR` records that the rail is advancing the right child without swapping the
two children. `rail-enter-right`, `rail-return-left`, and each `force-delay`
remain visible source events.

## Observations

The source artifact exposes three complementary observations:

- `frontier-events` retains `Emit`, `FrontierFresh`, `Forced`, and the terminal;
- `scoped-answers` returns each answer state with all owning introduction/tag
  pairs, combining enclosing `FrontierFresh` with nested `AnswerFresh`;
- `residual-tail` reports the one current work or terminal below the immutable
  frontier prefix.

The scoped observation deliberately distinguishes allocation identity from
plain answer equality. The golden tests require one allocation event per source
binder, identical marker copies at the exposure step, and exact ownership of
the inner versus outside answers.

## Executable Evidence

Run the standalone source suite with:

```bash
racket -y racket-server/derivations/refocusing/whole-tree-pipeline-pilot/tests/run.rkt
```

The suite freezes complete step-and-tree traces for:

- the nested outer-frontier/inner-branch-local fresh witness;
- both directions of a two-turn rail witness.

It also checks the right-active fresh exposure, late-only hoisting, allocation
counts, marker identity and provenance, scoped answers, grammar separation, the
absence of relation-call syntax, and agreement between the direct stepper and
the exported Redex relation. A one-way conformance check runs every
representative goal through the spike's selected late/rail semantics, renames
only its two old fresh-exposure rule labels to
`expose-choice-through-work-fresh`, and then requires identical rule owners,
complete tree sequences, final trees, and statuses. It performs no term
normalization and does not compare endpoints alone.

## Checkpoint Boundary

This checkpoint contains only the source grammar, direct `F -> F` relation,
observations, witnesses, and source tests. It intentionally contains no:

- decomposition result datatype;
- source-derived context-family grammar;
- refocusing function or machine;
- transition compression;
- fixed-point promotion;
- cached `c` or fresh-marker erasure experiment;
- representation claim about the production search lattice.

Those are subsequent derivation checkpoints and must treat this marked source
trace as the frozen reference.
