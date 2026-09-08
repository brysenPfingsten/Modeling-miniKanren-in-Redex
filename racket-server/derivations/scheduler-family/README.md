# Earlier dormant-branch semantics: functional and source correspondence

This checkpoint connects the dormant-branch interpreter family's generated
machine to independently stated source equations and evaluation contexts.
It investigates the earlier dormant-branch semantics. The current GUI uses
the separate [strict S scheduler sources](../strict-search/matrix/scheduler-source.rkt).

The interpreter is a demand variation of the
[retained-scope strict interpreter](../strict-search/retained-scope/interpreter.rkt).
Unselected merge operands, Yield tails, and recursive bind residuals remain
computations. Atomic kernels and relation expansion remain eager. Common
Owners, answer-private introductions, exact ancestry, and the Search/Frontier
commitment boundary remain explicit.

Suppressing ownership parameters, representative equations are:

```text
eval(g OR h, state) = plus(eval(g,state), lambda().eval(h,state))
plus(One(s),r)      = Yield(s,r)
plus(Yield(s,t),r)  = Yield(s, lambda().plus(t(),r))
bind(Yield(s,t),f)  = plus(f(s), lambda().bind(t(),f))

DFS:  plus(Delay(d),r) = Delay(lambda().plus(d(),r))
Flip: plus(Delay(d),r) = Delay(lambda().plus(r(),d))
```

The actual computation procedures receive local Owners and inherited support.
Railroad retains positions through a right-active merge and a right-positioned
Yield. These demand choices change the strict starting equations; they are
not CPS conversion or a proved strict-to-online fusion.

Commitment demands a computational Yield tail beneath an emitted prefix.
It creates no Forced node for that demand. A real Delay ends the public round;
advancement crosses it. Done and Last remain distinct terminal forms, and
unary `More(Delay(...))` retains unfinished Frontier work.

```text
Direct interpreter -> CPS -> defunctionalized program -> generated machine
                                                              ^
                                                              |
                                      structural readback; 0/1 source steps
                                                              |
                                                              v
                                   Independent source equations and contexts
```

| Artifact | Responsibility |
| --- | --- |
| [interpreter.rkt](interpreter.rkt), [cps.rkt](cps.rkt) | Direct and CPS equations with actual computation closures |
| [data.rkt](data.rkt), [defunc.rkt](defunc.rkt) | Explicit continuations, resumptions, and native data outcomes |
| [derive.rkt](derive.rkt), [machine.rkt](machine.rkt) | Checked tail-call transformation and generated thirteen-control dispatch |
| [source.rkt](source.rkt) | Grammars, contexts, named contractions, decomposition/plugging, public advance, and source orientation erasure |
| [functional-source.rkt](functional-source.rkt) | Structural machine decoder, prescribed zero-or-one source steps, and administrative rank |
| [functional-tests.rkt](functional-tests.rkt) | Functional stages, finite consumers, work order, scope, and control/constructor coverage |
| [functional-source-tests.rkt](functional-source-tests.rkt) | Configuration transitions, public boundaries, full calls, and decoder invariant checks |

The source base admits only left-active merge. Railroad extends it with
`mplusR` and `YieldR`; the base grammar rejects those constructors even inside
delayed computations. There is no evaluation context beneath a Yield tail,
Delay, or Frontier More. Source configurations retain `(program policy Gamma
observation)` explicitly; decomposition returns data frames.

`machine->source` is indexed by policy and validates stored policies, relation
environments, and captured ancestry against structural context. It never
executes a resumption, kernel, or machine step. Each machine step maps to a
prescribed singleton source label or an empty administrative span. Tests step
that exact span and compare configurations; they do not search forward for a
matching result. The administrative rank counts pending return reconstruction,
atomic outcome dispatch, and finite resumption paths, and decreases on every
checked empty span.

The decoder covers initialization, internal computation demand, commitment,
halted Frontiers, and single public advancement. It deliberately rejects
`collect/d` and `KCollect`: the source has public advance but no repeated
collection driver. Functional tests independently compare finite collection.
This checkpoint does not claim a second independently generated refocused
machine or a correspondence to the earlier native lattice.

Run from the repository root:

```sh
racket -y -l raco -- test racket-server/derivations/scheduler-family/functional-tests.rkt racket-server/derivations/scheduler-family/functional-source-tests.rkt
racket racket-server/derivations/scheduler-family/derive.rkt --check
```

The finite corpus covers all three policies, retained-scope witnesses, pending
bind, full and mutual relation calls, bounded productive and unguarded runs,
all 24 source labels, and all 12 machine controls in the decoder's domain.
The functional gate separately covers the thirteenth collection control.
Universal adequacy, transformation correctness, source/native correspondence,
and coinductive observation theorems remain open.
