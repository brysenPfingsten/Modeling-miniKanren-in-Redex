# Earlier numeric functional derivation of strict Search

This is the numbered numeric comparison checkpoint. Start current S work with
[retained-scope/](../retained-scope/README.md), which has its own source,
interpreter, and corresponding machines.

This local experiment starts again from the strict direct interpreter and
makes the A7–A9 style transformations inspectable. The result has **seven
control points, thirteen evaluation/readback continuation constructors, one
conjunction-continuation constructor, and three Delay-resumption constructors**.
It preserves eager operand evaluation and eager `Yield` tails.

The earlier strict functional machine is recovered by erasing two concrete
administrative cases: conjunction-continuation application and the final
return-to-halt transition. Its eager merge frames survive. No online scheduler,
arbitrary dormant goal, or eager-work fusion is introduced.

## The steps

| File | Transformation |
| --- | --- |
| [direct-interpreter.rkt](../../functional-search/direct-interpreter.rkt) | The strict direct source, with native functional kernel outcomes. |
| [01-anf.rkt](01-anf.rkt) | Name the direct interpreter's control results in evaluation order, including explicit forcing. |
| [02-cps.rkt](02-cps.rkt) | CPS-convert evaluation, merge, bind, forcing, and readback. Delay resumptions now accept their return continuation. |
| [03-data.rkt](03-data.rkt), [03-defunc.rkt](03-defunc.rkt) | Replace labeled lambdas by records and their applications by three apply functions: `return/d`, `continue/d`, and `force/d`. |
| [04-machine.rkt](04-machine.rkt) | Mechanically reify each defunctionalized tail call as a `Call(pc, operands)` transition. |
| [05-registers.rkt](05-registers.rkt) | Mechanically turn those tail-call arguments into assignments to four operand registers and a PC. |

The first two transformations and lambda-to-record replacement are written
out as separate programs. The machine and register dispatcher are generated
from the actual `03-defunc.rkt` function bodies by [derive.rkt](derive.rkt).
They do not copy or call the previous strict machine's transition function.
The generator handles a deliberately restricted tail fragment and rejects
references to control functions in non-tail positions; it is not a general
Racket compiler.

```sh
racket racket-server/derivations/strict-search/a7-a9/derive.rkt
racket racket-server/derivations/strict-search/a7-a9/derive.rkt --check
raco test racket-server/derivations/strict-search/a7-a9/all.rkt
racket racket-server/derivations/strict-search/a7-a9/show.rkt
```

Regeneration writes only the two generated files in this directory. `--check`
compares their full text with the derivation without writing. The parent
strict aggregate includes this directory's tests; the focused gate above
also checks these independently inspectable stages on their own.

## Native atomic outcomes

The kernel has the direct-style interface `K(goal, state) → Outcome`, and
an `Atom` callback has interface `state → Outcome`. An Outcome is a function
that selects a nullary failure handler or a success handler receiving the
computed state. `failure-outcome` and `success-outcome` produce these functions
directly. There is no intermediate `#f`/`State` result or adapter.

The ANF stage makes the eager boundary explicit:

```racket
(define outcome (K atomic state))
(define search (outcome (lambda () (Empty (State-next state))) One))
```

Both steps finish before evaluation continues. CPS then calls `k` with
`search`; defunctionalization calls `return/d` with the same value. Outcome
selection is part of the atomic primitive boundary, and its selector
handlers construct Search values without recursive control calls.

This derivation defunctionalizes the search control and Delay resumptions.
It leaves the parameterized kernel and its native functional outcomes at the
host primitive boundary throughout the sequence. It does not claim to
defunctionalize a closed kernel implementation, and it introduces no outcome
records or runtime conversion in the machine or registers.

## The calling-convention change that matters

The direct resumption has type `() → Search`. In the CPS stage it has type
`(Search → Result) → Result`. For example the delayed merge becomes:

```racket
(Delay
  (lambda (k*)                          ; R1
    (force/k rest K
      (lambda (forced)                  ; C7
        (merge/k right forced K k*)))))
```

`force/k` applies its resumption to the supplied continuation in tail
position. There is no nullary `(rest)` call followed by host-return work in
the CPS control layer. Defunctionalization gives:

```text
RMerge(right, rest)
force/d(RMerge(right, rest), K, k)
    → force/d(rest, K, KMergeForced(right, k))
return/d(forced, K, KMergeForced(right, k))
    → merge/d(right, forced, K, k)
```

The `KMergeForced` frame now has an explicit C7 lambda origin. C8 and C11
explain the corresponding bind and observer force frames in exactly the
same way. Continuations govern return control; the surrounding `Delay`
constructor alone marks object-language suspension.

## Where the records come from

All labels below occur at their lambda sites in `02-cps.rkt`. The run's
kernel `K` is invariant: it is hoisted out of closure records and passed as
an explicit control argument. The remaining captured values are the fields.

| Site | Record and fields | Pending work |
| --- | --- | --- |
| C0 | `KDone()` | Return the result to the caller. |
| C1 | `KConj(right,k)` | Bind the left Search to the right goal. |
| C2 | `KDisjLeft(right,state,k)` | Evaluate the right operand in the original state. |
| C3 | `KDisjRight(left,k)` | Merge with the already-mature left Search. |
| C4 | `KYield(state,k)` | Rebuild an eager Yield after its tail finishes. |
| C5 | `KBindHead(rest,continue,k)` | Evaluate the recursive bind residual. |
| C6 | `KBindTail(head,k)` | Merge the already-computed head with the residual. |
| C7 | `KMergeForced(right,k)` | Merge after an actual resumption returns. |
| C8 | `KBindForced(continue,k)` | Bind after an actual resumption returns. |
| C9 | `KRun(k)` | Render the mature Search. |
| C10 | `KEmit(state,k)` | Build an exact Emit after rendering its tail. |
| C11 | `KRenderForced(k)` | Render a resumed Search under a pending Forced. |
| C12 | `KForced(k)` | Build that Forced observation. |
| G0 | `GRight(goal)` | The conjunction function from state and continuation to result. |
| R0 | `REval(goal,state)` | Resume an explicit Suspend. |
| R1 | `RMerge(right,rest)` | Resume a merge with the mature right Search retained. |
| R2 | `RBind(rest,continue)` | Resume a bind with its conjunction function retained. |

G0's application produces the seventh control point, `continue/d`. The
previous machine had already combined that application with evaluation of
its stored goal. Thus even before registerization this new derivation exposes
a small, independently justified administrative contraction.

Nested choice orientation is retained by `RMerge` and its mature Search
payload. A separate `Q/χ` scheduler zipper does not emerge from these steps.
Obtaining one would require a further representation derivation. Likewise,
discarding C3/C6 or replacing their pending eager work with arbitrary delayed
jobs would require the separate semantic fusion argument.

## Registers and correspondence

Register assignments follow function argument order literally:

| PC | r0 | r1 | r2 | r3 |
| --- | --- | --- | --- | --- |
| eval/d | goal | state | K | k |
| merge/d | left Search | right Search | K | k |
| bind/d | Search | GRight | K | k |
| continue/d | GRight | state | K | k |
| force/d | resumption | K | k | unused |
| render/d | Search | K | k | unused |
| return/d | value | K | k | unused |
| halt | result | unused | unused | unused |

The positional layout deliberately shows the direct registerization result;
there has been no register-allocation optimization. `jump!` evaluates all
operands before assignment and clears unused registers. A private bank per
run permits interleaving. The tail-recursive PC loop is the host trampoline;
it creates no object-language Delay and no additional bounce closure.

For `((A ∨ B) ∨ (p ∧ q))`, the executed `show.rkt` witness includes:

| Step | PC | Active work | Retained left chunk |
| --- | --- | --- | --- |
| 8 | eval/d | right conjunction | A, B |
| 9 | eval/d | p | A, B |
| 11 | bind/d | bind the p result to q | A, B |
| 12 | continue/d | apply GRight(q) | A, B |
| 13 | eval/d | q | A, B |
| 15 | merge/d | merge A/B with the q result | Both are now operands |

The result is `Emit(A, Emit(B, Last(q)))`. The nested rail witness separately
retains four `Forced` markers followed by `Emit(A, Emit(B, Last(C)))`.

[correspondence.rkt](correspondence.rkt) structurally maps the newly derived
data into the previous strict functional machine and hence into `Rstrict`.
Every generated register dispatch is exactly one generated machine edge.
Every machine edge is an edge of the earlier functional machine except
`continue/d` and final return-to-halt, which have equal decoded endpoints.
These cases are classified by control, not by term inequality.

At the source boundary, eval/merge/bind/force/render are semantic contractions;
continue/return preserve the source term. The tests independently check the
corresponding refocused contraction and its plugged result. Administrative
return chains consume the finite continuation; continue immediately enters
eval; final return halts. A genuine Fresh self-loop remains semantic.

## Evidence and limits

The local aggregate passed **361 tests on Racket 9.3**: 174 finite goals
across all five derived stages, exact atomic-work order and incoming States,
eager Search boundaries, every intermediate register/machine/source/refocus
square, all thirteen continuation families and seven control points,
resumption calling conventions and reuse, retained eager chunks, custom
kernels, lexical Fresh capture across suspension, interleaved banks, and
bounded unguarded divergence. Native Outcome production and selection remain
eager; raw legacy kernel and Atom returns are rejected without conversion.
Generated-file
reproducibility is part of the same gate. `show.rkt` exposes a concrete trace
where the mature A/B chunk is retained while p and q run on the right.

This is a finite executable derivation checkpoint, not a mechanized general
adequacy or stream theorem. Kernel operations and Fresh body procedures stay
at the host primitive boundary; this does not yet produce a closed ParentheC
or C program. Relation calls are excluded. Literal intermediate equality uses
stable callback objects; arbitrary procedure extensionality is not decided.
Separate rendering of a defunctionalized Search must use its original kernel
environment. Raw Search constructors are shared data, but the direct, CPS,
and defunctionalized resumption payload conventions must not be mixed.

Only the generated machine/register runners use a transition budget. The
direct, ANF, CPS, and defunctionalized functions remain unbounded semantic
programs. Budget exhaustion retains a live configuration and does not return
Empty, Done, or a successful result; it cannot interrupt a diverging host
kernel or Fresh callback.
