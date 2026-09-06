# Guarded strictness audit prompt

Status: active semantic audit. This document is not a claim that the current
Redex calculus, the direct interpreter, or the candidate compact machine has
already been proved correct. Do not change production semantics merely to make
an existing commuting diagram continue to commute.

## Intended semantic hypothesis

Treat the guarded discipline, rather than the existing reduction semantics or
candidate machine, as the hypothesis under test.

> **ONLY `Delay` creates suspended computation.**
>
> Not disjunction. Not “dormancy.” Not the machine implementation. Not
> fairness.

Mature search is eager. Suspend is lazy. On `Delay`, swap.

```text
Search ::= Empty(next)
         | One(state)
         | Yield(state, Search)
         | Delay(Unit -> Search)
```

```text
eval(g1 ∨ g2, state)
  = mplus(eval(g1, state),
          eval(g2, state))

mplus(Empty(_), right)       = right
mplus(One(state), right)     = Yield(state, right)
mplus(Yield(state,left),right)= Yield(state, mplus(left,right))
mplus(Delay(resume), right)  = Delay(lambda ().
                                           mplus(right,resume()))
```

The critical productivity property is:

> For every guarded goal `g` and state `state`, `eval(g,state)` performs only
> finitely much work before producing one outer search constructor:
> `Empty(next)`, `One(state')`, `Yield(state',search)`, or `Delay(resume)`.

Equivalently, for guarded goals, evaluation between semantic suspensions is
eager and finite. Every potentially infinite recursive cycle encounters an
explicit `suspend` before making the next recursive cycle. Relation-entry
suspension, if desired, must remain an explicit source/adapter policy; relcall
expansion alone implies neither suspension nor fairness.

Pure work that precedes a `Delay` should not be postponed. For example, if

```text
g2 = p ∧ q ∧ suspend h
```

where `p` and `q` are finite pure computations, evaluating `g2` must execute
`p`, then `q`, and then expose `Delay(resume-h)`. It must not package all of
`g2` as a dormant job before executing `p` and `q`.

## Sources of authority

Do not assume any one of these is authoritative in advance:

```text
intended miniKanren behavior
          <->
direct functional interpreter
          <->
reduction semantics
          <->
abstract machine
```

If the current N/whole-tree reduction semantics disagrees with the clean
guarded interpreter, the reduction semantics may be wrong. If the compact
machine disagrees, the machine may be wrong. Conversely, a mismatch may reveal
that the interpreter encoded the wrong scheduler. Determine which by a
discriminating trace, not by preserving an existing artifact.

The litmus question for every purported representation transformation is:

> Does this transformation postpone computation that the source semantics
> performs before its next `Delay`?

If yes, it is not merely representation change.

## Three possible provenances for `Job`

Keep these possibilities distinct.

1. **Disjunction non-strictness.** `g1 ∨ g2` itself suspends `g2`. This makes
   disjunction another suspension construct. Reject this as the intended
   guarded semantics unless explicitly reconsidered.

2. **Delay only.** A `Job` represents a resumption already beneath an actual
   semantic `Delay`:

   ```text
   Delay(lambda ().eval(g,state,...))
                     |
                     | defunctionalize
                     v
                Job(g,state,...)
   ```

   This is the current target hypothesis.

3. **Machine staging.** An implementation postpones pure work that the direct
   semantics performs before reaching `Delay`. This is a real scheduling and
   evaluation-order transformation, not CPS, defunctionalization,
   registerization, trampolining, or representation-only fusion. Do not assume
   it is valid merely because purity may preserve completed answers. The
   intended account currently rejects this behavior; reconsider it only with
   an explicit new semantic choice and theorem.

The candidate rule

```text
Eval(g1 ∨ g2,state,kappa,chi,pi)
  -> Eval(g1,state,kappa,
          InLeft(JobNode(Job(g2,state,kappa)),chi),pi)
```

therefore requires renewed justification: it turns an arbitrary untouched
right goal into schedulable work, even when that goal has finite pure work
before its first `Delay`.

The slogan may survive:

```text
CEK-ish evaluator
+ oriented scheduler zipper
+ monotone output continuation
```

but the scheduler may need to schedule **search computations/resumptions**, not
arbitrary raw goals. The central question is not only whether an oriented
zipper emerges, but what it is a zipper *of*.

## First discriminating witness

Use:

```text
success(A) ∨ (p ∧ q ∧ suspend h)
```

The guarded eager interpreter must do:

```text
eval(success(A))             -> One(A)
eval(p ∧ q ∧ suspend h)      -> p; q; Delay(resume-h)
mplus(One(A),Delay(resume-h))-> Yield(A,Delay(resume-h))
```

The executable audit in `guarded-strictness-audit.rkt` records the current
production rail trace as:

```text
expand-disjunction
succeed
commit-choice-answer
expand-conjunction
unify-success                 ; p
conj-return
expand-conjunction
unify-success                 ; q
conj-return
suspend-goal
force-delay
succeed
finish-success
```

Thus the current whole-tree semantics commits `A` while the entire right goal
is still untouched `Work`. The direct interpreter instead logs `p,q` before it
returns `Yield(A,Delay(...))`. Both finish with the same finite frontier:

```text
Emit(A,Forced(Last(h)))
```

This is a trace/evaluation-order disconnect that completed-frontier equality
does not detect.

Follow with these witnesses:

```text
failure ∨ (p ∧ q ∧ suspend h)
suspend A ∨ (p ∧ q ∧ suspend B)
suspend^2 A ∨ (suspend B ∨ suspend C)
```

The last remains the nested-rail discriminator: hierarchical rail produces
`A,B,C`; flat enqueue-at-tail FIFO produces `B,A,C`.

## Redex lines to revisit

Do not destroy or rewrite any of these while auditing.

- Active production source, branch `codex/lattice-language-refactor-integration`
  at inspected commit `41b2851`: `racket-server/src/search-lattice/`.
  `expand-disjunction` creates `DisjL(active Work,dormant Work)`, and the
  `WorkPath` grammar reduces only the active child. `commit-choice-answer` can
  therefore occur before any right-sibling normalization.
- Production rail adds `DisjR` and the two rail turns. Production relcall
  expands directly and does not introduce suspension. These overlays were
  already provisional even though the lower production lattice was described
  as locked.
- The sibling matrix branch `codex/search-lattice-representation-composition`
  at inspected commit `a937fb9`
  carries S/E/N through core, Delay, Disjunction, and the policy-neutral Search
  join. It deliberately stops before rail fibers, `DisjR`, and relcall. Its N
  source inherits the same `DisjL(Work g1,Work g2)` active-path behavior, so
  representation commuting evidence does not answer this semantic question.
- The sibling marked branch `codex/whole-tree-redex-column` at inspected commit
  `229bb0c` gives exact
  Rmarked-to-Big correspondence for its source calculus. If the source
  scheduler is not the intended guarded semantics, the exact derivation may be
  perfectly correct about the wrong source behavior. Preserve it as evidence;
  do not rewrite it during this audit.
- The proposed registerized machine has not been implemented or proved. Treat
  it as a design candidate, not an oracle.

## Required separation of claims

Keep these observations separate:

- exact completed `Last`/`Done`/`Emit`/`Forced` readback;
- order of finite pure work before the next semantic `Delay`;
- rule-label and machine-state traces;
- finite prefix productivity under divergence;
- eventual-answer observations, which intentionally forget timing and exact
  delay counts;
- nested rail order and choice provenance;
- `Delay`: the current branch is unfinished;
- `Incomplete`: the current branch failed while a saved sibling remains;
- administrative CPS continuations and trampoline bounces, which are silent
  and are neither `Delay` nor `Incomplete`.

In particular, finite frontier agreement is evidence but not a strictness
theorem. A divergence-sensitive or prefix-visible account can distinguish the
eager interpreter from a machine that stages arbitrary right goals.

## Next derivation, in order

1. State guardedness as an explicit syntactic judgment or semantic domain
   condition, including the selected relation-entry suspension policy.
2. Freeze the direct strict interpreter and the discriminating traces as a
   small gold-standard oracle.
3. Construct a Redex presentation in which each disjunct performs finite eager
   work to its first Search observation before `mplus` operates. Keep it
   separate from production initially.
4. Compare that presentation with current N on strictness traces, finite exact
   frontiers, fresh allocation, conjunction, nested rail, and relcall.
5. Run CPS, defunctionalization, registerization, and trampolining mechanically
   from the strict interpreter. Inspect the machine actually obtained rather
   than targeting `Job/Q/chi/pi` constructors in advance.
6. Only then decide whether a scheduler zipper is needed, and whether its
   leaves are raw goals, evaluated Search observations, or genuine Delay
   resumptions.
7. If staging pure pre-Delay work is reconsidered, name it as a scheduling
   transformation and prove the chosen observation theorem separately.

Do not repair downstream stages until the source-level decision is explicit.
Do not discard the existing exact derivations: they remain valuable proofs of
correspondence to the semantics they were given.
