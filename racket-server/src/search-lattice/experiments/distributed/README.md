# Distributed presentation experiment

This directory contains the isolated eager-distribution presentation. It is not
part of the production strategy registry and contributes no grammar or rule to
the factored source.

The experiment reuses the owner-annotated production carrier, including the
explicit `(Owners owner ...)` stack representation. Its `Early*`
context categories enforce the invariant that a choice directly beneath
`Conj` is distributed before ordinary branch work proceeds. Its additional
named rules are:

```text
distribute-choice
distribute-right-choice
```

The experiment also assembles DFS, flip, rail, and the delayed-rooted relcall
overlay over that presentation. Unlike production, this retained experiment
keeps `DisjR`, its five right-active closure clauses, and
`distribute-right-choice` on the common distributed-search carrier. Distributed
DFS and flip inherit that carrier; distributed rail adds only the two scheduler
transitions. Those modules are experiment-local, and production continues to
expose only factored DFS, flip, and rail with the stricter production carrier
split.

The distributed rail relation mechanically re-closes inherited structural
rules on the common distributed-search carrier. The named-rule inventory,
rather than textual module size, is the ownership boundary: relative to
distributed search, rail adds only `rail-enter-right` and `rail-return-left`.

Eager distribution must regroup the inherited raw rules beneath its `Early*`
focus grammar. The local `reduction-relations/search-join-base-red.rkt` and the
raw production seam it consumes are retained for that purpose only. Production
`search-red` composes its immediate delay/disjunction predecessors directly and
does not import either experimental seam.

The focused suite is:

```sh
PLTUSERHOME=/tmp/decorated-lattice-plt \
PLTCOMPILEDROOTS=/tmp/decorated-lattice-compiled \
  raco test racket-server/tests/search-lattice/experiments/distributed-tests.rkt
```

It checks exact presentation-specific steps, owner movement, scheduler order,
relcall lifting, carrier/WF closure, and raw proof uniqueness. The experiment
does not claim a surfaced policy or a naturality result.
