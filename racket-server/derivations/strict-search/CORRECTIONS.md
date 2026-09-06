# Corrections and retained lessons

This log records the questions that changed the account and the small
maintained witnesses that make the answers inspectable. The
[research guide](README.md) owns current implementation and proof status.

| Mistaken assumption or question | Correction | Current witness |
| --- | --- | --- |
| Are S introductions just decorations on returned answers? | Introductions supply allocation support while computation runs. Unused and empty introduction groups matter; common ancestry and an answer's private ancestry have different descendants. Internal force retains the removed Delay's groups on active computation before fresh allocation. | `unused-binder`, `shared-outer`, `sibling-reuse`, `delayed-sibling-capture`, and `sparse-inherited-ancestry` in [witnesses.rkt](test-support/witnesses.rkt); owner lifting in [source-tests.rkt](retained-scope/source-tests.rkt) and [show.rkt](retained-scope/show.rkt) |
| Can completion always be encoded as an emitted answer followed by empty work? | `Done` retains terminal failure/allocation structure; `Last` records a terminal answer. `Last(A)` and `Emit(A,Done)` are structurally distinct even when their answer lists agree. Exact Frontier structure includes failed worlds and empty introduction groups. | Terminal-form assertions in [constructor-tests.rkt](constructor-tests.rkt); `allocated-failure`, `failed-sibling`, and `nested-rail` in [witnesses.rkt](test-support/witnesses.rkt); exact boundaries in [interpreter-tests.rkt](retained-scope/interpreter-tests.rkt) |
| Does a successful active Search candidate already justify settled output? | Pending bind can fail or suspend. `Yield` is active Search; only commitment builds Frontier answers. Unary `More(Delay(...))` retains unfinished Frontier work. | `intermediate-success-then-failure` and `delayed-continuation-schedule` in [witnesses.rkt](test-support/witnesses.rkt); phase rejection in [machine-correspondence-tests.rkt](retained-scope/machine-correspondence-tests.rkt) |
| Can matching completed answers justify dormant-right scheduling? | Strict disjunction matures both operands left to right; eager bind processes the continuation and residual before commitment. Delaying right-hand work changes the operation order even when completed output agrees. | `strict-sibling-maturation` and `eager-bind-residual` in [witnesses.rkt](test-support/witnesses.rkt); [policy-tests.rkt](policy-tests.rkt) compares strict and live online work order |
| Are all suspensions interchangeable thunks, including the host trampoline? | `REval`, `RMerge`, and `RBind` retain specific pending computation. Saved right Search and nested choice orientation matter. Only object-language Delay suspends that work; host tail-call dispatch is administrative. | `bind-delayed-left`, `delayed-sibling-capture`, and `nested-rail` in [witnesses.rkt](test-support/witnesses.rkt); [data.rkt](retained-scope/data.rkt), [administrative rank](retained-scope/administration.rkt), and [register span checks](retained-scope/register-compression-tests.rkt) |
| Must the interpreter be the fixed starting point for the derivation? | The syntactic machine helped reconstruct the retained-scope interpreter and its resumption interface. Forward CPS, defunctionalization, and machine generation then checked the connection through explicit configurations and prescribed steps. | [source-to-interpreter reading path](retained-scope/README.md#inspectable-path-from-syntax-to-interpreter), [show-machines.rkt](retained-scope/show-machines.rkt), and [configuration checks](retained-scope/machine-correspondence-tests.rkt) |

## Retired and deferred results

Checkpoint commit `0a3a075` preserves the pre-cleanup implementation, tests,
generators, and documentation. Historical locations below are plain Git paths
at that commit, not links to maintained files. Removing their comparison
suites deliberately reduces coverage; the retained gates do not inherit
every theorem statement or witness from those routes.

- **Older numeric functional, denotational, and a7–a9 routes:** their distinct
  presentations are retired after keeping the current control, allocation,
  phase, work-order, and generator assertions in the selected account.
  History: `racket-server/derivations/functional-search/`, the numeric modules
  directly under `racket-server/derivations/strict-search/`, and its
  `denotational/` and `a7-a9/` directories at `0a3a075`.
- **Explicit-prefix S functional route and ownership-erasure bridge:** the
  parallel interpreter-to-register pipeline and tests that existed only to
  compare it with retained scope are retired. The native matrix's prefix
  equations remain live pending S/E/N alignment. History:
  `racket-server/derivations/strict-search/s-functional/` and
  `racket-server/derivations/strict-search/retained-scope/source.rkt`
  (`erase-prefixes`) at `0a3a075`.
- **Productive recursion and host Fresh Ω:** the host-procedure examples and
  bounded divergence/proof-search-exhaustion diagnostics do not fit the
  selected first-order lexical goal domain. They are deferred without adding
  relation calls or recursive host bodies. History:
  `racket-server/derivations/functional-search/direct-interpreter.rkt`,
  `racket-server/derivations/strict-search/tests.rkt`, and
  `racket-server/derivations/strict-search/big-step-spec.rkt` at `0a3a075`.
- **Older numeric Big certificates:** source-specific proof-search results,
  R/B/M certificates, and their exhausted-search distinction are deferred.
  History: `racket-server/derivations/strict-search/big-step.rkt`,
  `big-step-spec.rkt`, and their tests at `0a3a075`.
  The maintained [native matrix Big](matrix/big/README.md) retains its own
  independent judgments, fixed-point equations, and recursive S/E/N
  certificates. Neither result establishes retained-scope Big or productivity.
- **Old refocusing playground:** memoized-`c` reconstruction and erase/restore
  results over the earlier FreshenedTree/rail-fused carrier remain historical.
  History: `racket-server/derivations/refocusing/` at `0a3a075`. The maintained
  [stage machinery](shared/stages/schema.rkt) is the current derivation surface;
  it does not claim those carrier-specific results.

No retired executable route is kept as an archive or compatibility shim.
The GUI's live online runtime remains a separate application dependency.
Integrating the selected account needs an explicit operation and observation
interface. Proving the online policy an equivalent optimization would require
a separate fusion argument; that claim is not a prerequisite for integration.
