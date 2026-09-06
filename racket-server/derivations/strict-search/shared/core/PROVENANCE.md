# Live representation providers: provenance

These are live shared grammar and kernel providers. The current strict
derivations use them through the shared grammars, kernel equations, allocation
operations, and well-formedness checks. Their preserved source history does
not designate them as an archived derivation or a cleanup target.

The three files in `shared/core/{s,e,n}/language.rkt` are byte-for-byte copies from this
repository at commit `a937fb96960959153e31db72c2875294c248f0d4` on
`codex/search-lattice-representation-composition`. Their original paths are
`racket-server/derivations/search-lattice/oracles/core/{s,e,n}/language.rkt`.
They retain the independently stated S/E/N variable/state languages,
allocation primitives, and first-order unification/disequality kernels.
The strict matrix imports their primitives, not dormant-right control rules.
No top-level license file was present at that revision; original contents and
comments are retained without relicensing.

| File | SHA-256 |
| --- | --- |
| `s/language.rkt` | `7d1cdb4e983a017c6bd44ac0e18d6e3fe74869f4eb56f71c6134aaeb7443a633` |
| `e/language.rkt` | `52ffdbd1258abfc0852ee2397aa1c9ffa80853827f94886c65afc52d7560b465` |
| `n/language.rkt` | `6e9e4b857a9964bf11c5421baedb728cb8526dd0b8546419da20621cf29cc9dc` |

[../kernel.rkt](../kernel.rkt) adapts the original binder-local substitution and least-unused
named allocation algorithms to the strict feature grammar. Atomic operations
invoke the preserved row-specific Redex kernels directly. State structure,
variable domains, grouped Owner provenance, failure summaries, and sparse
support addressing follow the selected `ARCHITECTURE-CONTRACT.md` at that
revision. The strict control calculus and its tests are new work.
