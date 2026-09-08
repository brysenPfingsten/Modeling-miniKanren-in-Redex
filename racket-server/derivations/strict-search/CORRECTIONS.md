# Corrections and retained lessons

This log records the questions that changed the account and the small
maintained witnesses that make the answers inspectable. The
[research guide](README.md) owns current implementation and proof status.

| Mistaken assumption or question | Correction | Current witness |
| --- | --- | --- |
| Are S introductions just decorations on returned answers? | Introductions supply allocation support while computation runs. Unused and empty introduction groups matter; common ancestry and an answer's private ancestry have different descendants. Internal force retains the removed Delay's groups on active computation before fresh allocation. E/N keep the same allocation world in their states and need no identity prefix phase. | `unused-binder`, `shared-outer`, `sibling-reuse`, `delayed-sibling-capture`, and `sparse-inherited-ancestry` in [witnesses.rkt](test-support/witnesses.rkt); owner lifting in [source-tests.rkt](retained-scope/source-tests.rkt) and [checkpoint S/E/N transitions](matrix/retained-scope-tests.rkt) |
| Can completion always be encoded as an emitted answer followed by empty work? | `Done` retains terminal failure/allocation structure; `Last` records a terminal answer. `Last(A)` and `Emit(A,Done)` are structurally distinct even when their answer lists agree. Exact Frontier structure includes failed worlds and empty introduction groups. | Terminal-form assertions in [constructor-tests.rkt](constructor-tests.rkt); `allocated-failure`, `failed-sibling`, and `nested-rail` in [witnesses.rkt](test-support/witnesses.rkt); exact boundaries in [interpreter-tests.rkt](retained-scope/interpreter-tests.rkt) |
| Does a successful active Search candidate already justify settled output? | Pending bind can fail or suspend. `Yield` is active Search; only commitment builds Frontier answers. Unary `More(Delay(...))` retains unfinished Frontier work. | `intermediate-success-then-failure` and `delayed-continuation-schedule` in [witnesses.rkt](test-support/witnesses.rkt); phase rejection in [machine-correspondence-tests.rkt](retained-scope/machine-correspondence-tests.rkt) |
| Can matching completed answers justify dormant-right scheduling? | Strict disjunction matures both operands left to right; eager bind processes the continuation and residual before commitment. Delaying right-hand work changes the operation order even when completed output agrees. | `strict-sibling-maturation` and `eager-bind-residual` in [witnesses.rkt](test-support/witnesses.rkt); [policy-tests.rkt](policy-tests.rkt) compares strict work order with the earlier dormant-branch semantics |
| Are all suspensions interchangeable thunks, including the host trampoline? | `REval`, `RMerge`, and `RBind` retain specific pending computation. Saved right Search and nested choice orientation matter. Only object-language Delay suspends that work; host tail-call dispatch is administrative. | `bind-delayed-left`, `delayed-sibling-capture`, and `nested-rail` in [witnesses.rkt](test-support/witnesses.rkt); [data.rkt](retained-scope/data.rkt), [administrative rank](retained-scope/administration.rkt), and [register span checks](retained-scope/register-compression-tests.rkt) |
| Must the interpreter be the fixed starting point for the derivation? | The syntactic machine helped reconstruct the retained-scope interpreter and its resumption interface. Forward CPS, defunctionalization, and machine generation then checked the connection through explicit configurations and prescribed steps. | [source-to-interpreter reading path](retained-scope/README.md#inspectable-path-from-syntax-to-interpreter), [show-machines.rkt](retained-scope/show-machines.rkt), and [configuration checks](retained-scope/machine-correspondence-tests.rkt) |
| Must relation calls introduce Delay or rely on hidden host recursion? | First-order named calls expand eagerly. Suspension belongs to explicit compiled syntax. Γ is retained in program terms, pending goal captures, data frames and resumptions; recursive calls do not change strict operand order. | [Full source/stage checks](matrix/full-tests.rkt), [functional relation checks](retained-scope/relation-tests.rkt), and [finite Big relation checks](matrix/big/full-tests.rkt) |
| Should run n stop as soon as an answer head becomes visible? | Positive limits wait for the next exposed Delay or terminal Frontier. Strict execution finishes its eager round and commitment; lattice execution can continue after emitting enough answers, even if an unguarded residual prevents reaching the boundary. The result is a prefix of the saved Frontier; manual stepping ignores the limit. | [Automatic driver checks](../../tests/program-runner-tests.rkt) and [manual API boundaries](../../tests/test-app.rkt) |
| Can normalized-tree positions identify original source occurrences? | Lowering a multi-clause `conde` adds operators and reassociation moves them. Source IDs must precede lowering; generated operators inherit their enclosing source form, while repeated source leaves remain distinct. | Source-attribution cases across all twelve compiler profiles in [test-transpiler.rkt](../../tests/test-transpiler.rkt) |
| Does the strict correspondence supersede the GUI's three runtime choices? | No Interleave, Flip-Flop, and Railroad remain essential lattice schedulers, separate from compiler association and Delay placement. DFS/Flip use `DisjL`; Railroad adds `DisjR`. Strict Search is a separate view. Sharing goal compilation, source IDs, history machinery, and a renderer does not equate their native source semantics. | Runtime-family selection in [search-runtime.rkt](../../src/search-runtime.rkt), native initialization in [canonical.rkt](../../src/transpiler/canonical.rkt), and [runtime/application checks](../../tests/search-runtime-tests.rkt) |

## Retired and deferred results

The neighboring [distributed-search experiment](../distributed-search/README.md)
remains executable as a separate policy investigation. Distributing pending
conjunction through nested choice changes both answer-state order and the
first-answer Delay boundary in its [finite witness](../distributed-search/tests.rkt).
It is therefore not a representation stage of this strict derivation, and its
relocation does not integrate it into the matrix or functional pipeline.

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
  compare it with retained scope are retired. The native matrix now carries
  retained scope through S/E/N source, stage, and finite Big equations;
  its earlier syntactic prefix phase and frames have been removed. History:
  `racket-server/derivations/strict-search/s-functional/` and
  `racket-server/derivations/strict-search/retained-scope/source.rkt`
  (`erase-prefixes`) at `0a3a075`.
- **Host-procedure fresh and recursion diagnostics:** the older host Fresh Ω
  examples and their proof-search-exhaustion diagnostics remain deferred;
  their host-procedure domain is not the selected lexical goal syntax.
  First-order relation calls, recursion and mutual recursion are now
  implemented separately in the [full source](matrix/full-source.rkt) and
  [functional derivation](retained-scope/relations.rkt). Their checks include
  bounded productive prefixes and unguarded divergence, not a general stream
  theorem or recovery of those older host-procedure results. History:
  `racket-server/derivations/functional-search/direct-interpreter.rkt`,
  `racket-server/derivations/strict-search/tests.rkt`, and
  `racket-server/derivations/strict-search/big-step-spec.rkt` at `0a3a075`.
- **Older numeric Big certificates:** source-specific proof-search results,
  R/B/M certificates, and their exhausted-search distinction are deferred.
  History: `racket-server/derivations/strict-search/big-step.rkt`,
  `big-step-spec.rkt`, and their tests at `0a3a075`.
  The maintained [native matrix Big](matrix/big/README.md) retains its own
  independent judgments, fixed-point equations, and recursive S/E/N
  certificates for the aligned retained-scope sources. These finite judgments
  do not establish productivity or recover the older numeric proof-search
  exhaustion results.
- **Old refocusing playground:** memoized-`c` reconstruction and erase/restore
  results over the earlier FreshenedTree/rail-fused carrier remain historical.
  History: `racket-server/derivations/refocusing/` at `0a3a075`. The maintained
  [stage machinery](shared/stages/schema.rkt) is the current derivation surface;
  it does not claim those carrier-specific results.

The retired functional routes above remain in Git history. The default GUI
now runs native lattice Railroad, retaining No Interleave and Flip-Flop.
Strict Search is a separate GUI view and the default API/library selection.
Its explicit initialization, commitment, public advancement and halted
Frontiers remain unchanged. Lattice histories instead retain their native
`(Γ F)` source and public `force-delay` reduction.
The [current picture projection](../../src/search-picture.rkt) reads both
native syntaxes directly, preserving candidates, Done/Last, and Owner groups.
Automatic consumption lives in
[minikanren.rkt](../../src/minikanren.rkt), separate from manual session control.

The historical strict “Search/rail” name does not identify its equations with
the oriented Railroad carrier. Partial interpreter correspondence is an
accepted application boundary. The lattice source also remains a real
dependency of the independent distributed experiment. Keeping these sources
executable supplies no online-fusion theorem; that requires its own
observation and hypotheses.
