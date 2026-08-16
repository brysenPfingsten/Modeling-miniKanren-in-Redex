# Whole-tree source-to-fixed-point pipeline pilot

Status: completed vertical-depth research pilot, 2026-08-16

This directory is a sibling of
[`../whole-tree-spike/`](../whole-tree-spike/), not a continuation inside that
spike and not a production search-lattice rearchitecture.  The broad spike
explored the source-design space.  This pilot freezes one representative cell
and carries its marked source calculus through indexed decomposition, exact
refocusing, symbolic transition compression, and fixed-point promotion.

## Research question and result

The pilot asks:

> If one representative whole-tree source calculus is frozen first, can its
> zipper and machine structure be derived, compressed, and promoted without
> reintroducing an answer-stream representation, reified phase tags, or an
> assumed production machine?

For the selected cell, the executable answer is **yes**.

The source/decomposition and source/refocusing comparisons preserve every
intermediate tree, rule name, and rule owner.  The compressed machine partitions
the exact marked trace into nonempty ordered spans, and replay of every span
reaches the identical exact-machine state.  Fixed-point promotion then removes
the compressed state and transport constructors from the recursive evaluator
while preserving the result of the strict marked driver on direct roots and
reachable residual states.

The adoption verdict is nevertheless **conditional**.  This is strong evidence
that the architecture is worth carrying into additional representative cells.
It is not evidence for replacing the production lattice wholesale.  The result
is one vertical slice, backed by executable correspondence tests rather than a
proof over all grammar-generated terms, and it does not yet include relation
calls or the full logic-state language.

## Selected cell and boundary

The frozen cell is:

- the full delay/disjunction search carrier;
- late conjunction hoisting;
- factored fresh scope;
- rail/flip-flop scheduling, including right-active `DisjR`;
- no relation-call overlay.

There are no policy switches inside the pilot.  The initial commit is
`9351a71`; every tracked change from the parent checkpoint `27c5520` through
the final implementation checkpoint `c848679` is below
`whole-tree-pipeline-pilot/`.  Production lattice modules are unchanged.

The derivation remains marked throughout.  Numeric or cached scope `c`, a
fresh-marker-erasure quotient, and a later stuttering quotient are comparison
experiments, not prerequisites.  No stage adds an answer register, observation
register, scheduler register, or reified `W`/`F` field.

## Frozen source calculus

The executable source is documented in [SOURCE.md](SOURCE.md) and implemented
by [language.rkt](language.rkt) and [source.rkt](source.rkt).  Its essential
stratification is:

```text
A ::= Answer(state)
    | AnswerFresh(intro, A, tag)

S ::= Returned(state)
    | WorkFresh(intro, S, tag)

W ::= Work(goal, state)
    | Returned(state)
    | Dead
    | WorkFresh(intro, W, tag)
    | Conj(W, goal)
    | PendingDelay(W)
    | DisjL(W, W)
    | DisjR(W, W)

F ::= More(W)
    | Done
    | Last(A)
    | FrontierFresh(intro, F, tag)
    | Emit(A, F)
    | Forced(F)
```

`W` is unfinished internal work and `F` is the whole/frontier root.  `S` is a
derived grammatical subset, not a constructor or runtime tag.  The intended
description is **sorts implicit in the grammar, with no reified sort tags**.
For example, `Emit`, `FrontierFresh`, and `Forced` cannot inhabit `W`, and
runnable work cannot inhabit an answer.

### Resolved fresh boundary

The source distinguishes two operational situations rather than asserting a
general scope-distribution equation.

A `WorkFresh` immediately beneath `More` owns the entire remaining computation,
so it crosses the work/frontier boundary as one marker:

```text
More(
  WorkFresh(u, DisjL(S, W), tag))

  -- expose-frontier-fresh/core -->

FrontierFresh(
  u,
  More(DisjL(S, W)),
  tag)
```

After the active branch commits, that same frontier marker encloses the answer
and the residual:

```text
FrontierFresh(
  u,
  Emit(freeze(S), More(W)),
  tag)
```

A branch-local fresh marker has a different ownership boundary.  Once its
active branch has settled, the named rule copies the already allocated
introduction marker onto exactly the two descendants it owns:

```text
WorkFresh(u, DisjL(S, W), tag)

  -- expose-choice-through-work-fresh/disj -->

DisjL(
  WorkFresh(u, S, tag),
  WorkFresh(u, W, tag))
```

The right-active form is symmetric and retains owner `search-join`:

```text
WorkFresh(u, DisjR(W, S), tag)

  -- expose-choice-through-work-fresh/search-join -->

DisjR(
  WorkFresh(u, W, tag),
  WorkFresh(u, S, tag))
```

This step does not allocate again.  It retains the identical introduction list
and provenance tag in both descendants.  An outside alternative remains
outside both markers.  Ordinary reassociation, late distribution, commitment,
and rail rules remain separate marked source transitions.

The source suite checks exact golden trees for the nested ownership witness,
including the fact that the outer frontier marker owns all three residual
pieces while the inner marker owns only the two inner descendants.  The four
representative pilot traces also conform one way to the broad spike oracle;
the test boundary normalizes only the spike's historical names for this fresh
exposure rule.

## Indexed decomposition and exact refocusing

[DECOMPOSITION.md](DECOMPOSITION.md) derives three context families.  They are
one indexed inductive structure whose indices are the grammatical input and
output categories:

| Family | Index | Constructors, nearest frame first |
| --- | --- | --- |
| `WWCtx` | `W -> W` | `ww-hole`, `ww-fresh`, `ww-conj`, `ww-disj-left`, `ww-disj-right` |
| `WFCtx` | `W -> F` | `wf-more(WWCtx, FFCtx)` |
| `FFCtx` | `F -> F` | `ff-hole`, `ff-frontier-fresh`, `ff-emit`, `ff-forced` |

Compatibility is encoded by these grammars and by category-specific result
constructors.  There is no generic frame list and no separate dynamic sort
compatibility predicate.

The state/result vocabulary evolves as follows:

| Stage | Executable forms | What remains explicit |
| --- | --- | --- |
| Source | one root `F`, with internal `W` | complete marked whole tree |
| Decomposition | `DecWork(W,WFCtx)` or `DecFrontier(F,FFCtx)` | focus plus derived indexed context |
| Contraction | `ContractWork(name,owner,W,WFCtx)` or `ContractFrontier(name,owner,F,FFCtx)` | one marked replacement with its retained context |
| Exact refocusing | the same `DecWork` or `DecFrontier` forms | one source contraction per transition |
| Compression | `CRun`, `CSettled`, `CDead`, `CDelay`, `CFinal` | only residual dispatch modes plus marked transition spans |
| Promotion | `PromotedFinal(T,FFCtx)` or `PromotedStuck(W,WFCtx)` | category-specific outcomes only; no recursive machine-state construction |

`DecWork` and `DecFrontier` are distinct because they contain genuinely
different focus/context shapes.  Exact refocusing retains no additional state
constructors: success, failure, delay, choice orientation, and fresh scope are
already represented by source syntax and indexed contexts.

### Reconstruction and one-step correspondence

For every state in every frozen source trace, checkpoint 2 checks:

```text
plug(decompose(F)) = F
```

Its independent contraction is in exact source lockstep:

```text
source-step(F) = transition(name, owner, F')

contract(decompose(F)) = C
plug-contract(C) = F'
marks(C) = (name, owner)
```

[REFOCUSED.md](REFOCUSED.md) derives the zipper search from decomposition.
Root decomposition is used only for entry.  A machine move contracts its
current focus and refocuses the replacement through the retained context:

```text
readback(initial-machine(F)) = F

source-step(F) = transition(name, owner, F')
machine-step(M) = machine-transition(name, owner, M')
readback(M) = F
----------------------------------------------------
readback(M') = F'
```

The stronger test-only refocusing oracle is:

```text
readback(refocus-contract(C)) = plug-contract(C)

refocus-contract(C) = decompose(plug-contract(C))
```

The implementation does not establish those equations by calling the
right-hand sides.  In particular, More-boundary priority is built into the
down/up refocusing equations: allocation at `More` refocuses to the complete
new `WorkFresh`, making `expose-frontier-fresh` the next exact step before any
descent into its child.

## Symbolic transition compression

[COMPRESSION.md](COMPRESSION.md) and [compressed.rkt](compressed.rkt) inline
paths through the exact refocusing call graph while the next contraction is
determined by visible constructors and retained context.  Compression stops
at a recursive dispatch component or before inspecting arbitrary unknown work,
goal, or context-tail data.  It is a direct symbolic relation, not a loop that
runs `machine-step` until a predicate holds.

The residual modes are:

| Mode | Payload/index | Operational role |
| --- | --- | --- |
| `CRun(W,WFCtx)` | unfinished work | downward work dispatch |
| `CSettled(R,WFCtx)` | success or settled choice | upward result dispatch |
| `CDead(WFCtx)` | failure context | failure propagation |
| `CDelay(W,WFCtx)` | delayed work | delay propagation and rail turns |
| `CFinal(T,FFCtx)` | `Done` or `Last(A)` | final frontier |

These are the four recursive dispatch strongly connected components and one
final form left by transition compression.  They are operational modes, not a
stored W/F tag.

Every compressed transition contains a nonempty `transition-span` of ordered
`rule-mark(name,owner)` values.  Decoding is observational:

```text
decode(CRun(W,K))       = refocus-work(W,K)
decode(CSettled(R,K))   = refocus-work(R,K)
decode(CDead(K))        = refocus-work(Dead,K)
decode(CDelay(W,K))     = refocus-work(PendingDelay(W),K)
decode(CFinal(T,KF))    = refocus-frontier(T,KF)
```

Each reachable macro move satisfies exact marked replay:

```text
C --[m1 ... mn]--> C'
decode(C) --m1--> ... --mn--> M'
--------------------------------
decode(C') = M'
```

Over a complete run:

```text
concat(compressed spans) = exact marked trace
decode(compressed final) = exact final machine
compressed status        = exact status
```

Names and owners are compared at every replay step.  No administrative event
is silently discarded.

### Exact representative partitions

The following are the live partitions.  Slash notation is
`rule-name/owner`; brackets delimit one compressed transition.

Nested fresh, 13 exact steps in 9 spans:

```text
[allocate-fresh/core, expose-frontier-fresh/core]
[expand-disjunction/disj]
[allocate-fresh/core]
[expand-disjunction/disj]
[work-put/core, expose-choice-through-work-fresh/disj]
[reassociate-left-result/disj]
[commit-choice-answer/disj]
[work-put/core, commit-choice-answer/disj]
[work-put/core, finish-success/core]
```

Late hoist, 10 exact steps in 6 spans:

```text
[expand-conjunction/core]
[expand-disjunction/disj]
[work-put/core, late-distribute-settled/disj]
[work-succeed/core, commit-choice-answer/disj]
[work-put/core, conj-return/core]
[work-succeed/core, finish-success/core]
```

Rail turn, 11 exact steps in 7 spans:

```text
[expand-disjunction/disj]
[suspend-goal/delay, rail-enter-right/search-join]
[force-delay/delay]
[suspend-goal/delay, rail-return-left/search-join]
[force-delay/delay]
[work-put/core, commit-choice-answer/disj]
[work-put/core, finish-success/core]
```

Right-active fresh, 21 exact steps in 14 spans:

```text
[expand-conjunction/core]
[expand-conjunction/core]
[allocate-fresh/core]
[work-put/core, conj-return/core]
[expand-disjunction/disj]
[suspend-goal/delay, rail-enter-right/search-join]
[bubble-delay-through-fresh/delay]
[bubble-delay-through-conj/delay]
[force-delay/delay]
[work-put/core, expose-choice-through-work-fresh/search-join]
[late-distribute-right-settled/search-join]
[work-succeed/core, commit-right-choice-answer/search-join]
[work-put/core, conj-return/core, expose-frontier-fresh/core]
[work-succeed/core, finish-success/core]
```

Thus compression makes the semantic choice visible rather than presupposing
it.  In both branch-local witnesses, `expose-choice-through-work-fresh` fuses
with the preceding `work-put`, while reassociation or late distribution remains
in the following span.  The nested root allocation fuses with
`expose-frontier-fresh`.  The right-active trace also has a distinct three-rule
span ending in frontier exposure.  All original names and owners remain in the
certificates.

## Fixed-point promotion

[FIXED-POINT.md](FIXED-POINT.md) and [fixed-point.rkt](fixed-point.rkt) fuse the
strict checkpoint-4 driver with the five direct compressed transition clauses.
For a compressed state `C`, define:

```text
DR(W,K) = drive(CRun(W,K))
DS(R,K) = drive(CSettled(R,K))
DD(K)   = drive(CDead(K))
DL(W,K) = drive(CDelay(W,K))
DF(T,K) = drive(CFinal(T,K))
```

Inlining `compressed-step`, distributing `drive` into every result clause,
and promoting these compositions to fixed points yields private tail-recursive
functions `run`, `settled`, `dead`, `delay`, and `final`.  Their mode mapping is
exact:

| Compressed mode | Promoted entry |
| --- | --- |
| `CRun(W,K)` | `fixed-run(W,K)` |
| `CSettled(R,K)` | `fixed-settled(R,K)` |
| `CDead(K)` | `fixed-dead(K)` |
| `CDelay(W,K)` | `fixed-delay(W,K)` |
| `CFinal(T,KF)` | `fixed-final(T,KF)` |

The fixed control graph, with syntactic helper dispatch shown explicitly, is:

```text
frontier-entry -> frontier-entry | continue-work | final

continue-work       -> run | settled | dead | delay
continue-unfinished -> continue-work

run     -> run | settled | dead | delay
settled -> run | settled | dead | delay | final
dead    -> run | settled | dead | delay | final
delay   -> run | settled | dead | delay
final   -> PromotedFinal
```

`run-local` and its atomic/fresh/conjunction/left-choice/right-choice helpers
perform constructor case analysis on behalf of `run`; they add no control
state and tail-call the same four recursive functions.  `PromotedStuck` is the
base result for a noncontracting work shape.  Every recursive edge above is in
tail position.

Promotion satisfies the strict-driver and one-step unfold equations on every
direct root and reachable compressed suffix state in the checked corpus:

```text
promote(C) = drive(C)

C --span--> C'
-----------------
promote(C) = promote(C')
```

At the root and result boundary:

```text
fixed-point-readback(fixed-point-evaluate(F))
  = compressed-readback(drive(initial-compressed(F)))
  = source-final(F)
```

The promoted recursive path does not import or call source, refocused, or
compressed operations.  It constructs no `CRun`-family value, `rule-mark`,
`transition-span`, transition, decomposition, or contraction.  It also has no
trace/status accumulator or production fuel.  Only `PromotedFinal` and
`PromotedStuck` remain as category-specific outcomes; `plug-ff` and `plug-wf`
are used only by observational readback.

The correspondence statement is deliberately restricted to direct root
entries and residual states reachable from the compressed machine.  It does
not assert the equation for arbitrary manually assembled, merely
grammar-shaped mode/context pairs.  Reachability carries the stronger phase
invariant without a dynamic compatibility predicate or reified phase tag.

## Witness metrics and observations

The four frozen traces contain 55 exact marked transitions and 36 compressed
transitions in total, a 19-transition or 34.5% reduction in transition count.
This is evidence of nontrivial symbolic composition, not a runtime benchmark.
The longest representative span has three marks.

| Witness | Exact | Compressed | Span lengths | Final frontier events | Scoped answers | Forced |
| --- | ---: | ---: | --- | --- | --- | ---: |
| Nested scope | 13 | 9 | `2,1,1,1,2,1,1,2,2` | outer fresh; emit; emit; last | `inner@[outer,branch]` twice; `outer@[outer]` | 0 |
| Late hoist | 10 | 6 | `1,1,2,2,2,2` | emit left; last right | left and right, unscoped | 0 |
| Rail turn | 11 | 7 | `1,2,1,2,1,2,2` | forced; forced; emit left; last right | left and right, unscoped | 2 |
| Right-active fresh | 21 | 14 | `1,1,1,2,1,2,1,1,1,2,1,2,3,2` | forced; emit scoped now; frontier fresh; last later | now and later both under the same fresh owner | 1 |

The exact final frontiers are:

```text
nested-scope =
  FrontierFresh((u:0),
    Emit(AnswerFresh((u:1), Answer(state(u:0 : u:1)), branch),
      Emit(AnswerFresh((u:1), Answer(state(u:0 : u:1)), branch),
        Last(Answer(state(u:0))))),
    outer)

late-hoist =
  Emit(Answer(state(left)),
    Last(Answer(state(right))))

rail-turn =
  Forced(Forced(
    Emit(Answer(state(left)),
      Last(Answer(state(right))))))

right-active-fresh =
  Forced(
    Emit(AnswerFresh((u:0), Answer(state(now)), fresh),
      FrontierFresh((u:0),
        Last(Answer(state(later))),
        fresh)))
```

For the nested result, the two inner answers each have owners
`outer(u:0), branch(u:1)`; the outside answer has only `outer(u:0)`.  For the
right-active result, both answers carry the same already allocated `u:0` and
fresh provenance, though the first is frozen as `AnswerFresh` and the residual
scope later crosses the boundary as `FrontierFresh`.  Fixed-point readback is
identical to each source final above.

## Checkpoints and validation

| Commit | Checkpoint | Added suite | Suite result | Aggregate after checkpoint |
| --- | --- | --- | ---: | ---: |
| `9351a71` | Frozen marked source | source | 9/9 | 9/9 |
| `3ca779b` | Indexed decomposition and contraction | decomposition | 9/9 | 18/18 |
| `716bac7` | Exact refocused machine | refocused | 6/6 | 24/24 |
| `47e0572` | Symbolic transition compression | compression | 10/10 | 34/34 |
| `c848679` | Fixed-point-promoted evaluator | fixed point | 10/10 | 44/44 |

The committed suites cover reconstruction, all exact source/refocusing steps,
certificate replay, span concatenation, every compressed mode, the strict
driver equation, every promoted entry, final observations, malformed entry
rejection, and a 10,000-delay proper-tail-call witness.  The coverage corpus
reaches all 27 frozen rule names and all 28 distinct `(name, owner)` pairs; the
extra pair is `expose-choice-through-work-fresh` under both `disj` and
`search-join`.

Independent generated audits also checked the intermediate stages:

- decomposition agreed with 18,737 generated source steps; separate generated
  checks covered 18,198 reconstructions, 5,520 indexed contractions, 10,000
  typed plug cases, and 20,000 source/derived well-formedness decisions;
- exact refocusing agreed on 10,000 generated one-step cases and 1,000 complete
  traces containing 19,948 transitions and all 27 rule names;
- compression accepted or rejected 960 generated terms plus four explicit
  malformed-name cases with exact domain parity, then replayed 2,717 macro
  moves containing 3,749 marks and all 28 rule/owner pairs.  Its observed span
  lengths were 1 mark 1,692 times, 2 marks 1,018 times, and 3 marks 7 times.

A separate generated promotion audit broadened the final-stage evidence:

- 300 generated well-formed direct roots;
- 3,800 reachable compressed suffix states;
- 97,619 assertions;
- reachable mode counts of 2,362 `CRun`, 295 `CSettled`, 225 `CDead`, 618
  `CDelay`, and 300 `CFinal`;
- a longest generated run of 125 compressed transitions;
- rejection of 20 malformed roots and 12 malformed promoted-entry arguments;
- four finite 50,000-deep tail probes;
- a static audit finding no prior-stage operation, machine/transport
  constructor, or accumulator on the promoted recursive path.

This generated audit strengthens the reachable-state claim; it does not turn
it into an all-terms theorem.

## Reproduction and adjacent lanes

Run the complete pilot:

```sh
racket -y racket-server/derivations/refocusing/whole-tree-pipeline-pilot/tests/run.rkt
```

The final live result is:

```text
44 success(es) 0 failure(s) 0 error(s) 44 test(s) run
```

Run individual stages with:

```sh
raco test racket-server/derivations/refocusing/whole-tree-pipeline-pilot/tests/source-tests.rkt
raco test racket-server/derivations/refocusing/whole-tree-pipeline-pilot/tests/decomposition-tests.rkt
raco test racket-server/derivations/refocusing/whole-tree-pipeline-pilot/tests/refocused-tests.rkt
raco test racket-server/derivations/refocusing/whole-tree-pipeline-pilot/tests/compression-tests.rkt
raco test racket-server/derivations/refocusing/whole-tree-pipeline-pilot/tests/fixed-point-tests.rkt
```

The adjacent live lanes were also checked:

```sh
racket -y racket-server/derivations/refocusing/whole-tree-spike/run.rkt
npm --prefix frontend test
racket -y racket-server/derivations/refocusing/tests/run.rkt
raco test racket-server/tests/test-all-headless.rkt
```

Results on 2026-08-16:

- the existing whole-tree spike passes 16/16;
- the frontend passes 37/37;
- the legacy refocusing lane has a pre-existing compile failure:
  `red:rail-fused-red` is unbound at `bridge/current.rkt:113`;
- the headless lane cannot start its complete suite because the local Racket
  environment lacks the `hosted-minikanren` collection.

The last two are baseline/environment failures outside this sibling pilot.
They are not reported as green and were not repaired by this work.

Useful final repository checks are:

```sh
git diff --check 27c5520..HEAD
git diff --name-only 27c5520..HEAD
git status --short --branch
```

## Adoption decision and remaining work

The pilot supports broader **source-first, cell-by-cell adoption** for three
reasons:

1. The stratified grammar and indexed context families encode phase
   compatibility without runtime W/F tags or an independently postulated
   zipper.
2. Exact decomposition and refocusing preserve the marked source strongly
   enough that compression can be audited as a trace partition, including the
   delicate fresh-ownership and rail events.
3. Fixed-point promotion removes the derived transport machinery from the
   evaluator while retaining direct, properly tail-recursive control equations
   and category-specific outcomes.

Adoption should remain conditional on reproducing these results across other
policy cells and richer language layers.  In particular:

- early hoisting and the other scheduler cells still need corresponding
  vertical derivations;
- relation calls, unification, disequality, reification, and the complete
  logic-state effects are outside this pilot;
- allocation/substitution and well-formedness kernels are intentionally
  restated at independently executable stages, which is useful derivational
  evidence but a maintenance concern for broader engineering;
- the corpus and generated audit provide strong executable evidence, not a
  mechanized proof for every well-formed term and every manually assembled
  residual state;
- the measured transition-count reduction is not a time or allocation
  benchmark;
- cached numeric scope, fresh-marker erasure, and any stuttering quotient must
  be evaluated later against this primary marked route, not substituted for it.

The resulting recommendation is therefore to use this pipeline as the
reference method for the next representative cell, preserving the same
checkpoint and certificate discipline.  A production-lattice migration should
wait until multiple cells show that the same indexed structure and promoted
control equations survive without ad hoc state growth.
