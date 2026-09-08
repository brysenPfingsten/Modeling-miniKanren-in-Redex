# Earlier dormant-branch semantics: functional derivation

This checkpoint contains a direct interpreter family and its CPS,
defunctionalized, and generated data-machine forms. It investigates the
earlier dormant-branch semantics. The current GUI uses the separate
[strict S scheduler sources](../strict-search/matrix/scheduler-source.rkt).

The starting equations are a demand variation of the
[retained-scope strict interpreter](../strict-search/retained-scope/interpreter.rkt).
Atomic kernels and relation expansion remain eager; ownership, allocation
ancestry, and the Search/Frontier commitment distinction remain explicit.
Three demand sites change: the unselected merge operand, a Yield tail, and
the recursive residual of binding a Yield remain computations.

Suppressing ownership parameters, the base equations include:

```text
Search ::= Empty | One(state) | Yield(answer, computation) | Delay(computation)
computation ::= () -> Search

eval(g OR h, state) = plus(eval(g,state), lambda().eval(h,state))
plus(Empty,r)        = r()
plus(One(s),r)       = Yield(s,r)
plus(Yield(s,t),r)   = Yield(s, lambda().plus(t(),r))
bind(Yield(s,t),f)   = plus(f(s), lambda().bind(t(),f))

DFS:  plus(Delay(d),r) = Delay(lambda().plus(d(),r))
Flip: plus(Delay(d),r) = Delay(lambda().plus(r(),d))
```

The actual computation procedures receive local Owners and inherited support.
Both merge operands are computations; merge explicitly demands the selected
one. Railroad adds a right-active merge and `YieldR(residual,answer)` to
retain operand positions instead of swapping them. These are semantic demand
choices, not a CPS transformation or a proved strict-to-online fusion.

Commitment demands a Yield tail beneath the already committed prefix. It
creates no Forced node for that demand. Only an actual Delay marks a public
suspension. Done and Last retain distinct terminal shapes; unary
`More(Delay(...))` retains unfinished Frontier work. Direct `run` returns at
a Delay or terminal boundary; the derived machine also exposes intermediate
commitment and work.

```text
Direct interpreter -> CPS -> defunctionalized program -> generated data machine
                              continuations/resumptions     Call(pc, operands)
```

| Artifact | Responsibility |
| --- | --- |
| [interpreter.rkt](interpreter.rkt) | DFS, Flip, and Railroad equations, real computation closures, and public consumers |
| [cps.rkt](cps.rkt) | Explicit continuations for demand, bind, commitment, and resumption |
| [data.rkt](data.rkt), [defunc.rkt](defunc.rkt) | Closure and continuation records; native data kernel outcomes |
| [derive.rkt](derive.rkt), [machine.rkt](machine.rkt) | Checked tail-call transformation and its generated thirteen-control dispatch machine |
| [functional-tests.rkt](functional-tests.rkt) | Cross-stage Frontiers, resumption captures, work order, scope, calls, and constructor/control coverage |

Reachable generated-machine configurations contain data. Host dispatch creates
no object-language Delay. Tests inspect actual direct/CPS closures through an
optional observer; data execution does not consult that observer or a closure
description table. Kernel outcomes become data at defunctionalization without
a conversion adapter.

Run from the repository root:

```sh
racket -y -l raco -- test racket-server/derivations/scheduler-family/functional-tests.rkt
racket racket-server/derivations/scheduler-family/derive.rkt --check
```

The checks cover all three policies, retained-scope witnesses, full and mutual
relation calls, finite collection, bounded productive prefixes, and explicit
unguarded machine execution. They provide finite cross-stage evidence.
General transformation correctness, correspondence to an independently stated
source and the earlier native lattice, and infinite-behavior theorems are not
established at this checkpoint. This is not a derivation of the current strict
GUI schedulers or a compact `kappa / Q / pi` machine.
