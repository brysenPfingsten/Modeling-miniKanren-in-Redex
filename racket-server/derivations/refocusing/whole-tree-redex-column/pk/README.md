# P[K]: kernel-parametric marked column

This subtree rebuilds the marked vertical pipeline as one family of Redex
artifacts parameterized by an atomic kernel.  The committed parent directory
remains the frozen `Ktoy` oracle; no parent artifact is imported as an
implementation shortcut by this subtree's generic schemas.

The architecture has three layers:

1. `control-language.rkt` is a non-operational template.  It owns the search
   carrier, full actual-hole contexts, labels, and phase refinements, while
   leaving `katom`, `kst`, and `kname` abstract.
2. `*-schema.rkt` modules are syntax builders.  Redex language identifiers are
   compile-time bindings, so a Racket function cannot build these relations at
   runtime.  Each schema is handwritten once and instantiated in a precise
   target language.
3. `toy/` and `mk/` replace every abstract leaf before defining operational
   artifacts.  The template itself is never used as a theorem language.

This makes mixed-kernel terms unrepresentable in each instance.  Tests reject
them at both `F` and `D`, rather than attaching a kernel tag to runtime states.

## Shared carrier

The source grammar remains stratified by construction:

```text
W ::= Work(g, kst) | Returned(kst) | Dead | WorkFresh(...) | ...
F ::= More(W) | Done | Last(A) | FrontierFresh(...) | Emit(...) | Forced(...)
```

The full contexts are the revised BF/LF presentation:

```text
BF ::= More(hole) | frontier wrappers around BF
LF ::= More(NFWW) | frontier wrappers around LF
WF ::= BF | LF
```

`BF` places the hole directly below `More`; `LF` contains a first `Conj` or
`Disj` frame below `More`.  `WW`, `WFrame`, and `FF` remain as derived
actual-hole families.  No source, decomposition, or machine value contains a
reified W/F sort field.

Later stages inherit one central phase grammar:

```text
T  ::= Done | Last(A)
SR ::= S | SC
R  ::= SR | Dead | PendingDelay(W)
U  ::= NW | Dead | PendingDelay(W) | SC
NR ::= Work(g,kst) | Conj(W,g) | DisjL(U,W) | DisjR(W,U)
NW ::= NR | WorkFresh(intro,U,tag)
NF ::= the positive non-WorkFresh outer constructors of W
```

In particular, `NR` contains `Work(g,kst)`, not merely atomic goals; structural
goals must be legal inputs to compressed running states.

## Kernel boundary

Each kernel supplies only:

```text
kernel-step/K          : katom x kst -> kresult x kell
kernel-initial-state/K : -> kst
kernel-open-fresh/K    : lexical x g x intro -> OpenedFresh(intro,g)
wf-atomic/K            : katom x lexical x intro
wf-state-at/K          : kst x intro
```

The shared control schema owns whole-frontier marker support,
`control-resume/K`, `control-freeze/K`, recursive goal/work/frontier
well-formedness, and all search rules.  Fresh support is globally collected
from the complete `F`; sibling marker identities are therefore unavailable to
a later allocation.  This is a frozen marked-column choice, not an open
semantic fork.

`Ktoy` has three atomic labels.  `Kmk` has seven and uses a c-free state with
substitution, disequality store, unification history, and provenance.

## Labels

Labels are semantic data, not reconstructed from two evaluators:

```text
ell ::= cell-ell | (kernel kname core)
```

`cell-ell` enumerates the 25 non-atomic rule/owner pairs.  A kernel step always
returns the tagged second form.  Redex `computed-name` renders the exact label
on an operational edge.

`toy/labels.rkt` contains an explicit executable translation between tagged
toy labels and the committed 28-label family.  `mk/labels.rkt` retains all
seven distinct atomic labels:

```text
succeed, fail, unify-success, unify-violates-disequality, unify-fail,
disequality-success, disequality-fail
```

## Stage API

Replace `K` below with `toy` or `mk`:

```text
K/language.rkt
  pk-K-lang

K/kernel.rkt
  kernel-step/K, kernel-initial-state/K, kernel-open-fresh/K
  whole-marker-support/K, control-resume/K, control-freeze/K

K/wf.rkt
  wf-goal/K, wf-answer-at/K, wf-work-at/K, wf-frontier-at/K
  wf-frontier/K

K/labels.rkt
  label->redex-name/K, redex-name->label/K

K/source.rkt
  initial-tree/K, source-step/K, source-red/K

K/decomposition.rkt
  pk-K-decomposition-lang
  decompose/K, contract/K, plug-D/K, plug-C/K, contract-label/K
  decomposed-step/spec/K, decomposed-step/direct/K
  decomposed-red/direct/K
```

Consumers may import both instances with prefixes; no conventional unqualified
alias modules are needed.

The executable arrow contracts are described stage by stage in
[`FRONT-HALF.md`](./FRONT-HALF.md), [`MIDDLE.md`](./MIDDLE.md), and
[`BACK-HALF.md`](./BACK-HALF.md).

## Focused checks

```sh
raco test racket-server/derivations/refocusing/whole-tree-redex-column/pk/tests/front-half-tests.rkt
raco test racket-server/derivations/refocusing/whole-tree-redex-column/pk/tests/middle-tests.rkt
raco test racket-server/derivations/refocusing/whole-tree-redex-column/pk/tests/back-half-tests.rkt
racket racket-server/derivations/refocusing/whole-tree-redex-column/pk/tests/run.rkt
```

The front-half suite executes the same generated source/decomposition arrow
laws for both kernels, compares every reachable representative `Ktoy` source
and decomposition step to the committed oracle after explicit label
translation, checks all seven `Kmk` atomic labels, follows a compound `Kmk`
trace, tests global support and marker-indexed well-formedness, and rejects
mixed-kernel `F` and `D` terms.

The middle and back-half suites apply the same generated laws to both kernels:
refocus/direct versus plug-and-redecompose, Z/M codec and labeled bisimulation,
canonical nonempty compression spans with exact replay, and finite promoted
big-step versus strict compressed closure.  The aggregate runner executes all
three suites.
