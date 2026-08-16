# Fresh Normalization Experiment

Status: next controlled derivation experiment, revised 2026-08-15

## Purpose

Compare two legitimate directed normalizations of a runtime fresh scope across
conjunction followed by disjunction:

- retain one factored `WorkFresh` around the resulting choice;
- distribute copies of the same `WorkFresh` marker into both branches.

The experiment must determine how those alternatives affect source trees,
decomposition contexts, refocused machines, and the presentation diagram. It
must not decide the result by appealing to the current production machine.

## Settled Premises

This experiment does not reopen fresh allocation.

Source and runtime variables are different syntactic classes:

```text
x    lexical variable bound in a source goal
u    logical variable allocated into a runtime tree
```

Allocation occurs exactly once:

```text
Work(FreshGoal(x*, g, tag), state)
  -> WorkFresh(u*, Work(g[u*/x*], state'), tag)
```

The allocation rule chooses `u*`, substitutes through the exposed body, and
replaces the lexical binder with the runtime unary node that records where the
logical variables were introduced.

Every later occurrence of:

```text
WorkFresh(u*, W, tag)
```

denotes those same allocated variables and the same introduction event.
Copying this node is structural distribution, not another allocation. A test
must fail if a distributive rule chooses new `u` identifiers or changes the
provenance tag.

The answer/frontier ownership account is also settled:

- `WorkFresh` represents scope still contained in unfinished `W`.
- `FrontierFresh` preserves one already allocated scope around an `F` subtree
  containing all affected committed answers and remaining work. It does not
  allocate variables.
- `AnswerFresh` records that one answer escaped a branch-local work subtree
  that introduced the named logical variables.

Repeated `AnswerFresh(u*, ..., tag)` on several escaped answers is repeated
ownership evidence for one allocation. It is not repeated allocation.

Tree nesting closes scope. No explicit closing marker, sentinel, or bounded
linear scope segment is a candidate in this experiment.

## Primary Witness

Start from the reachable runtime shape:

```text
Conj(
  WorkFresh(u, Returned(state), fresh-tag),
  DisjGoal(g1, g2))
```

This can arise after a lexical fresh goal allocates `u`, its first conjunct
returns, and a disjunctive continuation remains.

Use two enclosing cases:

```text
global witness:
  More(primary-witness)

branch-local witness:
  More(DisjL(primary-witness, Woutside))
```

The global witness tests whether the scope can remain one enclosing frontier
subtree. The branch-local witness prevents an implementation from treating a
local scope as if it owned `Woutside`.

## Candidate F: Factored Scope

The factored normalization retains one runtime binder:

```text
Conj(
  WorkFresh(u, Returned(state), tag),
  DisjGoal(g1, g2))

  ->

WorkFresh(u,
  DisjL(
    Work(g1, state),
    Work(g2, state)),
  tag)
```

For the global witness, this can evolve toward:

```text
FrontierFresh(u,
  Emit(A1,
    Last(A2)),
  tag)
```

For the branch-local witness, the `WorkFresh` remains within the active outer
branch. Answers crossing that outer branch boundary receive
`AnswerFresh(u, ..., tag)` while `Woutside` remains unowned by `u`.

Expected control character:

- one fresh scope node remains outside the choice;
- a decomposed late machine can retain one fresh frame around branch control;
- the source tree preserves the original allocation site as one frontier
  scope node.

## Candidate D: Distributed Scope

The distributed normalization copies the already allocated marker:

```text
Conj(
  WorkFresh(u, Returned(state), tag),
  DisjGoal(g1, g2))

  ->

DisjL(
  WorkFresh(u, Work(g1, state), tag),
  WorkFresh(u, Work(g2, state), tag))
```

Both copies must contain exactly the same `u` and `tag`. There is still one
allocation transition in the trace.

Expected control character:

- the fresh scope is materialized separately in each branch;
- focused branch contexts may each contain a fresh frame;
- answers can acquire repeated `AnswerFresh` ownership as branches cross the
  frontier;
- the shape resembles early distribution of pending control.

## Do Not Presuppose Early Equals Distributed

The resemblance motivates a hypothesis, not an identification:

```text
factored fresh scope     possibly corresponds to late/shared control
distributed fresh scope possibly corresponds to early/distributed control
```

Initially model fresh normalization and hoist policy as separate axes:

```text
fresh-normalization in {factored, distributed}
hoist-policy       in {early, late}
```

Construct the applicable 2-by-2 policy fiber. Mechanical decomposition and
refocusing should reveal whether two combinations coincide, become
unreachable, or remain genuinely distinct.

Scheduler policy remains another axis at the search node. At least one delay
witness should exercise the fresh-normalization alternatives under rail
rotation so copied ownership is not accidentally lost while branches swap.

## Location In The Presentation Diagram

The source fresh goal, `WorkFresh`, and conjunction already belong to `core`.
The normalization choice first becomes meaningful when disjunction is added.
Therefore:

```text
Rcore/factored = Rcore/distributed
Rdelay/factored = Rdelay/distributed

             same Rdisj carrier
              /             \
Rdisj,factored               Rdisj,distributed

            same Rsearch carrier
              /              \
Rsearch,factored              Rsearch,distributed
```

This should be represented as a policy or equation-theory fiber over the
shared disjunction/search carrier, not as duplicated goal/runtime grammars.
The interaction rule is owned by the disjunction extension's interaction with
inherited fresh/conjunction structure. Search inherits it and adds only its
delay/scheduler interactions.

For every unaffected parent trace, both variants must embed the parent
transition unchanged. The variants may differ only once the witness shape is
present.

## Presentation Components To Transform

For each applicable feature node `i` and normalization `n`, construct the
complete presentation:

```text
R(i,n) = <G, T, V, C(n), WF, ->(n), O>
```

The carrier languages and basic WF should initially be shared. The experiment
must make explicit any difference in:

- selected decomposition contexts;
- normalization redexes and rule ownership;
- reachable tree forms;
- operational observations;
- source-to-source relation between the two variants.

Then carry both through the syntactic pipeline:

```text
R(i,n)
  -> D(i,n)
  -> Z(i,n)
  -> M0(i,n)
```

Do not compare only the source endpoints. At each pass check:

```text
Phi(embed(parent-state)) ~= embed(Phi(parent-state))
```

and compare factored versus distributed presentations with a separate
representation relation. If one candidate uses an extra distribution or
reassociation transition, allow a stated weak/stuttering correspondence
rather than silently compressing it.

Cached-`c` restoration and big-step compression remain later passes. They
should receive both machine candidates if both survive this experiment.

## Required Observations

Add observations that retain enough scope information to avoid confusing
allocation identity with answer equality.

### Allocation events

Record, or reconstruct unambiguously from each trace:

```text
allocate(tag, x*, u*)
```

Both candidates must have exactly one such event for the witness.

### Scoped answers

For each committed answer, compute:

```text
<answer-state, owning (u*, tag) introductions>
```

Ownership comes from both:

- enclosing `FrontierFresh` nodes;
- `AnswerFresh` nodes inside the emitted payload.

The factored and distributed candidates must produce equal ordered scoped
answers, not merely equal unscoped states.

### Operational tree events

Retain:

- allocation and substitution;
- fresh-marker distribution;
- answer escape from a branch-local scope;
- `FrontierFresh` exposure;
- delay forcing and rail turns;
- early/late conjunction/disjunction transitions.

### Alpha-renaming

Comparisons should tolerate a consistent alpha-renaming of freshly allocated
logical variables, but they must reject a distributed candidate that maps one
source allocation to two distinct logical variables.

## Required Corpus

At minimum test:

1. One lexical fresh goal followed by one successful continuation.
2. The global primary witness with two answers.
3. The branch-local primary witness plus `Woutside`.
4. Nested lexical fresh with shadowing.
5. A failed first branch and a successful second branch.
6. A delayed first branch under DFS.
7. Delayed-left and delayed-right rail turns.
8. The cross-product of factored/distributed and early/late on the primary
   witness.
9. Nested choices requiring explicit reassociation before commitment.

For copied markers, assert syntactically that every copy contains the same
allocated `u*` and provenance tag. Also assert that the trace contains one and
only one allocation rule firing for the source fresh goal.

## Evaluation Questions

The retrospective report should answer:

1. Which source candidate preserves the tree scope most directly?
2. Which contexts and frames arise mechanically from each candidate?
3. Does factored/distributed coincide with late/early, or are they independent
   axes?
4. Does either variant require special-purpose machine state not derivable
   from source contexts?
5. Can one machine simulate the other by distributing or factoring fresh
   frames while preserving allocation identity?
6. Which candidate composes more uniformly with delay, rail scheduling, and
   the additive feature embeddings?
7. Is one candidate a useful source calculus while the other is better viewed
   as a later normalization or machine optimization?

The current expectation is that the factored form is the cleaner source
account because it retains one tree binder at the allocation site. The
distributed form remains a serious candidate because it may be the canonical
early normalization. The experiment should confirm, refine, or reject that
expectation mechanically.

## Decision Rule

Prefer the factored form as the default source rule if it:

- preserves one source allocation node;
- derives a machine without ad hoc scope state;
- embeds uniformly across the feature diagram;
- relates to the distributed machine by an explicit, simple distribution
  relation;
- preserves all intermediate scheduling evidence.

Retain both as policy variants if their mechanically derived machines organize
control differently in a semantically informative way. Do not force them into
one machine merely because their scoped answers agree.

Reject any candidate that:

- allocates during marker copying;
- changes `u*` or provenance while distributing;
- lets branch-local ownership cover `Woutside`;
- requires a closing marker solely because the frontier was flattened;
- validates itself only by final unscoped answer equality.
