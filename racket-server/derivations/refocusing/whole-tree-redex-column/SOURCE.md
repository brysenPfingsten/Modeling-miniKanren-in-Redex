# Marked source artifact `R_m`

`language.rkt` defines the stratified source grammar and actual-hole context
families.  `source.rkt` defines the complete named `reduction-relation`; it
does not wrap a Racket step function.  The active path is selected by the
grammar:

| Context | Index | Purpose |
| --- | --- | --- |
| `WW` | W -> W | local active-work path |
| `WFrame` | W -> W | exactly one local work frame |
| `NFWW` | W -> W | path whose first frame is conjunction or disjunction |
| `FF` | F -> F | committed frontier prefix |
| `BF` | W -> F | hole immediately below `More`, under an `FF` prefix |
| `LF` | W -> F | branch-local path with a first non-fresh frame below `More` |
| `WF` | W -> F | disjoint union of `BF` and `LF` |

The priority distinction is now a partition of complete W-to-F contexts,
rather than a split pair of work and frontier contexts.  A `WorkFresh` in
`BF` owns the whole residual computation and selects
`expose-frontier-fresh`.  A `WorkFresh` in `LF` has a conjunction or active
disjunction frame between it and `More`, so
`expose-choice-through-work-fresh` copies the existing introduction marker to
the two descendants.  `BF` and `LF` are disjoint, and every `WF` belongs to
exactly one of them.

Every rule name has the form `source-name/owner`; `redex-name->label` and
`label->redex-name` are inverse Redex metafunctions over the finite label
grammar.  Rule selection remains in Redex.  `kernel-toy.rkt` supplies only
fresh-name choice, lexical substitution, state update, success resumption,
answer freezing, and well-formedness judgments.

The source suite checks:

- grammar stratification and context-family membership,
- executable toy-kernel well-formedness,
- the complete label/name bijection,
- deterministic closure on bounded Redex-generated well-formed terms,
- exact named successor equality with the frozen pilot oracle, and
- complete representative traces, including both fresh-exposure cases.

The oracle dependency occurs only in tests.
