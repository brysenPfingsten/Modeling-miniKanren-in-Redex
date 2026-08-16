# P[K] back-half arrow contracts

The back half contains transition compression and fixed-point promotion for
both `Ktoy` and `Kmk`.  Each transformation has two independently stated
Redex presentations: a compositional specification built from the preceding
stage and a direct artifact that repeats the transformed control equations.

## Marked machine to compressed machine

The public compressed grammar retains only operationally distinct modes:

```text
B ::= BRun(NW,WF)
    | BSettled(SR,WF)
    | BDead(WF)
    | BDelay(W,WF)
    | BFinal(T,FF)
```

These modes are grammatical refinements, not W/F tags.  Their contexts are
the same full actual-hole BF/LF/WF families used by the source, decomposition,
and marked-machine stages.  The private `BQ` grammar names derivation program
points and is not part of the machine theorem domain.

Every direct compressed transition carries a canonical nonempty certificate:

```text
B -- transition-span(ell1,...,elln) --> B'
```

`symbolic-path/direct/K` is the independent direct presentation.  Its
`BQGoal(g,kst,WF)` dispatcher handles every goal constructor.  Only atomic
goals invoke `kernel-step/K`; structural fresh, conjunction, disjunction, and
suspension clauses are shared control equations.  A kernel edge retains the
exact dynamic `kell = (kernel kname core)` as the first label in its span.

`compressed-step/spec/K` is separately handwritten as a canonical exact
machine corridor.  It decodes a B state, takes one exact M edge, and consumes
the statically required second and optional third edges.  Thus every span has
one, two, or three labels and no empty compressed edge exists.  The corridor
rules express two fusions explicitly:

- a kernel producer consumes its success/failure control followup;
- an unfinished producer consumes a following root-WorkFresh exposure when
  the resulting full context is BF.

The specification never derives a span by consulting the direct symbolic
path.  Conversely, the direct schema does not call a machine step, decoder,
replayer, source step, contractum, or refocuser.

The executable square is:

```text
decode-BM/K(B) = M
B --Span-->direct B'
decode-BM/K(B') = M'
M --labels(Span)-->exact M'
--------------------------------
compression-step-square/K(B,Span,B',M,M')
```

`compression-steps-square/K` concatenates these certificates, and
`reachable-compression-correspondence/K` restricts the iterated claim to the
well-formed root image.

## Compressed small step to promoted big step

The finite specification is the strict reflexive-transitive closure of the
direct compressed relation:

```text
BFinal(T,FF) ==>spec [] FinalResult(T,FF)
B --Span--> B'    B' ==>spec Spans O
-------------------------------------
B ==>spec Span::Spans O
```

`Spans` therefore records the exact ordered partition of the compressed
trace.  Root entry first obtains the initial compressed state.

The independent `evaluate-query/direct/K` judgment promotes the compressed
control equations into one syntax-directed fixed point.  It extends the
source instance directly, not the compressed or marked-machine language, and
does not call either operational relation.  Its five public entries are:

```text
big-run/direct/K
big-settled/direct/K
big-dead/direct/K
big-delay/direct/K
big-final/direct/K
```

`promote/direct/K` dispatches from each public B constructor, while
`big-step/direct/K` starts from a well-formed F root.  Atomic `EQGoal` clauses
call `kernel-step/K`; all remaining fixed-point clauses are the shared
BF/LF/WF control equations.  In particular, a settled choice beneath a local
fresh frame produces the explicit pair of descendants carrying the same
introduction marker before later reassociation or commitment proceeds.

Three executable correspondence judgments expose the promotion laws:

- `big-step-square/K` compares finite closure with direct promotion;
- `big-step-unfold-square/K` records the one-compressed-step unfold law and
  its remaining ordered certificate;
- `root-big-step-square/K` compares the two root entries.

## Executable claims in this checkpoint

- The same direct/spec compression square and exact-label replay checks run
  for both kernels on every reachable witness suffix.
- Concatenated spans are exactly the marked-machine trace partition, and final
  decoded/read-back states agree.
- The selected nested `Ktoy` witness retains its canonical span partition,
  including `expose-choice-through-work-fresh` as an explicit label.
- All seven `Kmk` atomic labels occur as exact tagged `kell` values in spans.
- Generated raw `BQ` and `EQ` queries have exactly one derivation in each
  precise instance; generated public B terms have one decoder and one direct
  promoted result.
- Reachable well-formed witnesses exercise all five public B modes in both
  kernels.
- Finite closure, direct promotion, the one-step unfold square, and root-entry
  square agree for every reachable witness suffix/root.
- Mixed-kernel B states are rejected by the opposite precise grammar.

These checks are bounded executable evidence, not universal mechanized
proofs.  The inductive big-step judgments deliberately make only a finite
termination claim.  They do not classify divergence or establish equality of
infinite observations.  Nonempty spans rule out infinite sequences of empty
compressed moves, but a divergence theorem would still require a coinductive
judgment or step-indexed observation prefixes plus a separate progress/rank
argument for any zero-step comparison introduced by later erasure stages.
