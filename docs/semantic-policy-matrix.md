# Research and application policy boundary

The [strict-search README](../racket-server/derivations/strict-search/README.md)
is the authoritative research inventory: implementations, generators,
correspondence checks, established coordinates, and remaining obligations.
The [correction log](../racket-server/derivations/strict-search/CORRECTIONS.md)
records why the selected account makes its semantic distinctions.

| Account | Current role | Operational policy |
| --- | --- | --- |
| [Retained scope](../racket-server/derivations/strict-search/retained-scope/README.md) | Selected S interpreter and corresponding functional/syntactic machines | Strict disjunction, eager Yield tails and bind, explicit Search/Frontier commitment; only Delay suspends |
| [S/E/N matrix](../racket-server/derivations/strict-search/matrix/README.md) | Native retained-scope representation and feature machinery through Big; checkpoint source/machine transition checks connect it to selected S | Same strict Search/rail evaluation; S retains introductions on active work, E/N carry the corresponding support in states |
| [Production search lattice](../racket-server/src/search-lattice/SEMILATTICE.md) | Live compiler, API, GUI and library runtime | Dormant-right / online disjunction with DFS, flip and rail schedulers and relation calls |

Branch evaluation and scheduler are separate choices. The production Search
join is neutral among its scheduler fibers but already inherits dormant-right
evaluation. Strict Search/rail instead has an explicit `mplus-delay`
interaction. Its DFS/flip and relation-call coordinates are not implemented.

## The GUI boundary

[`search-runtime.rkt`](../racket-server/src/search-runtime.rkt) selects the
production relation and well-formedness checker. The compiler emits its
configuration language, and
[`picture.rkt`](../racket-server/src/search-lattice/picture.rkt) renders it.
The research matrix alignment does not change any of those operational modules.
Connecting the selected account to the GUI will require aligning initial
configurations, supported goals, named stepping, and Frontier rendering.

## Observation is part of the claim

Strict evaluation performs the finite right operand's work before committing
a left answer. The online runtime can commit the left answer first.
[`policy-tests.rkt`](../racket-server/derivations/strict-search/policy-tests.rkt)
keeps one direct witness of this work-order difference despite equal completed
Frontiers. It does not establish a fusion theorem.

A strict-to-online bridge would require an explicit observation and hypotheses
including guardedness and a pure deterministic kernel. Without guardedness,
`success(A) ∨ Ω` distinguishes even answer prefixes. Finite completed
Frontiers, productive streams, and eventual answer sets require different
claims; source-relative pipeline correctness does not identify them.

The retained-scope S/E/N connection and future GUI integration do not depend
on proving or adopting an online fusion optimization. The native matrix
connection does not supply separately derived E/N functional interpreters or
register programs.
