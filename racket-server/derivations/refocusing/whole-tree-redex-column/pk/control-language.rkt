#lang racket

(require redex/reduction-semantics)

(provide pk-control-lang)

(check-redundancy #t)

;; P[K]'s shared carrier is deliberately not an operational language.  Its
;; three kernel leaves are abstract, and each thin instance replaces them with
;; precise productions before defining a relation or stating an arrow law.
;; Consequently `any` cannot admit a mixed-kernel term in a theorem language.
(define-language pk-control-lang
  [katom any]
  [kst any]
  [kname variable-not-otherwise-mentioned]

  [x (variable-prefix x:)]
  [u (variable-prefix u:)]
  [lexical (x ...)]
  [intro (u ...)]
  [bindings ((x u) ...)]
  [tag (label string)]

  [g katom
     (fresh lexical g tag)
     (conj g g tag)
     (disj g g tag)
     (suspend g tag)]

  [A (Answer kst)
     (AnswerFresh intro A tag)]

  ;; Settled success is a derived grammatical subset of W.
  [S (Returned kst)
     (WorkFresh intro S tag)]
  [SC (DisjL S W)
      (DisjR W S)]

  [W (Work g kst)
     (Returned kst)
     Dead
     (WorkFresh intro W tag)
     (Conj W g)
     (PendingDelay W)
     (DisjL W W)
     (DisjR W W)]

  [F (More W)
     Done
     (Last A)
     (FrontierFresh intro F tag)
     (Emit A F)
     (Forced F)]
  [V Done
     (Last A)
     (FrontierFresh intro V tag)
     (Emit A V)
     (Forced V)]

  [kresult (KernelSuccess kst)
           KernelFailure]
  [fresh-result (OpenedFresh intro g)]

  [owner core delay disj search-join]
  ;; These are exactly the non-atomic rules of the selected source cell.  A
  ;; kernel step has the separately tagged shape `(kernel kname core)`.
  [cell-ell (expose-frontier-fresh core)
            (finish-success core)
            (finish-failure core)
            (force-delay delay)
            (commit-choice-answer disj)
            (commit-right-choice-answer search-join)
            (allocate-fresh core)
            (expand-conjunction core)
            (expand-disjunction disj)
            (suspend-goal delay)
            (expose-choice-through-work-fresh disj)
            (expose-choice-through-work-fresh search-join)
            (erase-dead-fresh core)
            (bubble-delay-through-fresh delay)
            (conj-return core)
            (conj-fail core)
            (bubble-delay-through-conj delay)
            (late-distribute-settled disj)
            (late-distribute-right-settled search-join)
            (skip-left-failure disj)
            (rail-enter-right search-join)
            (reassociate-left-result disj)
            (skip-right-failure search-join)
            (rail-return-left search-join)
            (reassociate-right-result search-join)]
  [kell (kernel kname core)]
  [ell cell-ell kell]
  [ProducerFollowup kell
                    (suspend-goal delay)]

  ;; Actual-hole indexed context families.
  [WW hole
      (WorkFresh intro WW tag)
      (Conj WW g)
      (DisjL WW W)
      (DisjR W WW)]
  [WFrame (WorkFresh intro hole tag)
          (Conj hole g)
          (DisjL hole W)
          (DisjR W hole)]
  [NFWW (Conj WW g)
        (DisjL WW W)
        (DisjR W WW)]
  [FF hole
      (FrontierFresh intro FF tag)
      (Emit A FF)
      (Forced FF)]
  [BF (More hole)
      (FrontierFresh intro BF tag)
      (Emit A BF)
      (Forced BF)]
  [LF (More NFWW)
      (FrontierFresh intro LF tag)
      (Emit A LF)
      (Forced LF)]
  [WF BF LF]

  ;; Shared phase refinements.  They are grammar indices used by later
  ;; transformations, never reified state fields.
  [T Done (Last A)]
  [SR S SC]
  [R SR Dead (PendingDelay W)]
  [U NW Dead (PendingDelay W) SC]
  [NR (Work g kst)
      (Conj W g)
      (DisjL U W)
      (DisjR W U)]
  [NW NR
      (WorkFresh intro U tag)]
  ;; Positive outer-constructor complement of WorkFresh.
  [NF (Work g kst)
      (Returned kst)
      Dead
      (Conj W g)
      (PendingDelay W)
      (DisjL W W)
      (DisjR W W)])
