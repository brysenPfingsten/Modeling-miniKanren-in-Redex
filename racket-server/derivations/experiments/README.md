# Alternative semantic accounts

The current strict semantics and its derivations live in
[retained-scope/](../retained-scope/README.md) and
[matrix/](../matrix/README.md). This directory keeps alternative accounts
executable without making them stages of that derivation or GUI backends.
Each account owns its source rules and the evidence principally about it.

| Account | What it investigates | Artifacts |
| --- | --- | --- |
| [Dormant-branch semantics](dormant-branch-semantics/README.md) | Deferred sibling and bind-residual work, with DFS, Flip, and oriented Railroad scheduling | Native source languages/reductions/WF, direct/CPS/data-machine derivation, structural maps, source laws, and strictness/allocation counterexamples |
| [Early conjunction distribution](early-conjunction-distribution/README.md) | Distributing pending conjunction into choices before ordinary branch work | Alternative languages/reductions and tests against the factored dormant source and selected strict witnesses |

The first account includes both the original work-tree source and a derived
computation presentation with its own stated correspondence domain. The second
reuses the dormant source's primitives and varies its distribution policy; it
does not have an independently derived interpreter or machine.

Shared semantic primitives belong to [shared/](../shared/README.md).
Neutral generators and validation helpers belong to
[test-support/](../test-support/README.md). Tests comparing a particular
experiment with strict execution stay with that experiment. Tests of the
live compiler, session, HTTP API, and GUI stay in
[`racket-server/tests/`](../../tests/TEST-LANES.md).

Run from the repository root:

```sh
racket -y -l raco -- test racket-server/derivations/all.rkt
racket -y -l raco -- test racket-server/derivations/experiments/all.rkt
racket -y -l raco -- test racket-server/tests/test-all-headless.rkt
```

The first gate covers only the current strict account. The second runs both
experiments and [cross-experiment architecture checks](architecture-tests.rkt).
The headless gate invokes both and the application suites. Passing an
experiment establishes only its stated checks; it does not supply a strict
interpreter correspondence, universal bisimulation, or productive-stream theorem.

The relocation preserves the accounts and their rules. Earlier paths remain
in the [correction log](../CORRECTIONS.md) where they identify Git history.
