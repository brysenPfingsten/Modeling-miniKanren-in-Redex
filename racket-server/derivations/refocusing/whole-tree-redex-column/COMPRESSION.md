# Canonical marked transition compression

This checkpoint makes the arrow from the exact marked machine `M` to the
compressed marked machine `B` explicit in Redex.  It has two independent
presentations:

- `compression-spec.rkt` composes one, two, or three exact `M` steps according
  to a grammatical corridor policy.
- `compressed.rkt` states the transformed artifact directly as a symbolic
  Redex judgment over residual dispatch modes.

The direct artifact does not run the exact stepper until a stopping predicate
holds.  Its private `BQ` forms are derivation program points, not machine
states.  The public state grammar has exactly these constructors:

```text
BRun(NW, WF)      downward unfinished-work dispatcher
BSettled(SR, WF)  upward settled-result dispatcher
BDead(WF)         failure propagation dispatcher
BDelay(W, WF)     delay/rail propagation dispatcher
BFinal(T, FF)     terminal frontier
```

`NW` is the grammatical unfinished-work phase, disjoint from settled, dead,
and delayed dispatcher phases.  Putting that index directly in `BRun`
excludes phase-incoherent raw states without a runtime compatibility check.
Every running mode retains one complete
actual-hole `WF : W -> F` context.  Its disjoint subclasses distinguish a
boundary hole (`BF`) from a branch-local hole (`LF`); the latter has an
ordinary conjunction or choice frame below `More`.  Upward control pops the
unique innermost frame with patterns such as
`(in-hole WF (Conj hole g))` and
`(in-hole LF (WorkFresh intro hole tag))`.  There is no split `WW`/`FF`
continuation, sort field, compatibility flag, scheduler register, cached
ambient scope, or erased fresh marker.

## Translation and image

`decode-BM` is a Redex judgment from `B` to the exact machine.  It invokes only
the already-derived retained-context refocuser to locate the represented exact
control point, passing the complete `WF` context directly.  It is deliberately
a decoder, not an operational dependency of the direct compressed relation.

`reachable-compressed/via` and
`reachable-compression-correspondence` carry the complete ordered span prefix
from a well-formed source root.  The latter also carries the decoded exact
machine state.  These judgments identify the theorem domain without adding a
dynamic image tag to semantic states.  Raw grammar-shaped `B` terms outside
that reachable image are useful for clause checks but are not covered by the
progress claim.

## Canonical corridor specification

Every compressed label is a first-class, statically nonempty certificate:

```text
transition-span(ell_1, ..., ell_n), n >= 1
```

The specification partitions exact steps by these Redex grammatical classes:

| First exact label | Required continuation |
| --- | --- |
| atomic producer (`work-succeed`, `work-fail`, `work-put`, `suspend-goal`) | take the next exact edge |
| unfinished producer (`allocate-fresh`, expansions, conjunction return, late distribution) | take a following root `WorkFresh` exposure exactly when that exact state has the grammatical root-fresh shape |
| every other label | stop after one edge |

After a mandatory second edge, only an unfinished-producing label whose exact
successor is root-fresh extends the span to a third edge.  Thus the canonical
artifact has spans of length one through three.  This is not the extensional
quotient containing every possible nonempty exact path; that alternative
would be a different transition system and would erase the chosen symbolic
partition.

## Executable arrow laws

`compression-step-square` records the one-step commuting square:

```text
decode(B) --ell_1 ... ell_n-->M decode(B')
       B --transition-span(ell_1, ..., ell_n)-->B B'
```

Its premises separately require:

1. the direct `B` edge;
2. the independently composed exact-machine corridor;
3. exact, label-sensitive replay of the certificate; and
4. decoder agreement at both ends.

`compression-steps-square` composes those squares and retains every macro
boundary.  The tests check preservation and reflection as equality of complete
successor sets on every reachable state, raw derivation uniqueness, exact
label/owner replay, literal trace partitioning, all 28 valid marks, the four
golden witness partitions, and well-formed reachability.  A bounded
`redex-check` repeats the direct/specification comparison over generated whole
frontier terms.

The private `BQ` grammar is restricted to actual derivation program points:
nonfresh local dispatch uses `NR`, and fresh dispatch requires `LF`.  Bounded
generation therefore checks totality and uniqueness together--every generated
`BQ` has exactly one raw direct derivation--rather than merely checking that
there is at most one derivation.

The reduction relation `compressed-red/direct` is only the trace/visualization
projection.  The span-producing judgment is authoritative because ordinary
Redex rule names cannot themselves carry a dynamic one-to-three-label value.

## Claim boundary

Each macro edge contains at least one exact edge, so compression introduces no
empty administrative transition and cannot create infinite zero-step
stuttering.  The executable tests establish exact finite-path correspondence
for this no-`relcall` cell.  They are not a universal proof of termination or
a coinductive divergence theorem; those require a separate well-foundedness or
infinite-trace argument before the observational claim is extended to a
recursive-call carrier.
