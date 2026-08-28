#lang racket

(require redex/reduction-semantics)

(provide lean-control-lang)

(check-redundancy #t)

;; This is a non-operational carrier template.  Each precise instance replaces
;; katom, kst, and kname before defining a relation or judgment.
(define-language lean-control-lang
  [katom any]
  [kst any]
  [kname variable-not-otherwise-mentioned]

  [x (variable-prefix x:)]
  [u (variable-prefix u:)]
  [lexical (x ...)]
  [intro (u ...)]
  [tag (label string)]

  [g katom
     (fresh lexical g tag)
     (conj g g tag)
     (disj g g tag)
     (suspend g tag)]

  [A (Answer kst)]

  [S (Returned kst)]
  [SC (DisjL S W)
      (DisjR W S)]

  [W (Work g kst)
     (Returned kst)
     Dead
     (Conj W g)
     (PendingDelay W)
     (DisjL W W)
     (DisjR W W)]

  [F (More W)
     Done
     (Last A)
     (Emit A F)
     (Forced F)]
  [V Done
     (Last A)
     (Emit A V)
     (Forced V)]

  [kresult (KernelSuccess kst)
           KernelFailure]
  [fresh-result (OpenedFresh intro g)]

  [owner core delay disj search-join]
  [cell-ell (finish-success core)
            (finish-failure core)
            (force-delay delay)
            (commit-choice-answer disj)
            (commit-right-choice-answer search-join)
            (allocate-fresh core)
            (expand-conjunction core)
            (expand-disjunction disj)
            (suspend-goal delay)
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

  ;; Actual-hole context families.  WW follows the one active work path; WF
  ;; completes it to a frontier, and FF follows the immutable frontier prefix.
  [WW hole
      (Conj WW g)
      (DisjL WW W)
      (DisjR W WW)]
  [WFrame (Conj hole g)
          (DisjL hole W)
          (DisjR W hole)]
  [WF (More WW)
      (Emit A WF)
      (Forced WF)]
  [FF hole
      (Emit A FF)
      (Forced FF)])
