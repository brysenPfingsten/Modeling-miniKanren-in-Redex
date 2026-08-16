#lang racket

(require redex/reduction-semantics)

(provide redex-column-source-lang
         goal-in-language?
         work-in-language?
         frontier-in-language?
         value-in-language?
         answer-in-language?
         label-in-language?)

(check-redundancy #t)

;; W and F are different grammatical categories, not runtime tags.  The
;; context nonterminals below are actual Redex contexts containing holes.  They
;; form an indexed inductive family:
;;
;;   WW     : W -> W
;;   WFrame : W -> W, exactly one frame
;;   NFWW   : W -> W, with a first non-fresh frame
;;   FF     : F -> F
;;   BF     : W -> F, with the hole immediately below More
;;   LF     : W -> F, with a first non-fresh frame below More
;;   WF     : W -> F, the disjoint union of BF and LF
;;
;; BF and LF make the priority boundary explicit as complete contexts.  A
;; WorkFresh in BF owns all residual work and must be exposed at the frontier;
;; a WorkFresh in LF is branch-local because a Conj/Disj frame already lies
;; between it and More.  WW still admits WorkFresh below that first local
;; frame.  These are grammar indices and refinements, not runtime tags.
(define-language redex-column-source-lang
  [p (sym string)
     (nat number)
     boolean
     (str string)
     unit
     x
     u
     (p : p)]
  [st (state p)]
  [x (variable-prefix x:)]
  [u (variable-prefix u:)]
  [lexical (x ...)]
  [intro (u ...)]
  [tag (label string)]

  [g (succeed tag)
     (fail tag)
     (put p tag)
     (fresh lexical g tag)
     (conj g g tag)
     (disj g g tag)
     (suspend g tag)]

  [A (Answer st)
     (AnswerFresh intro A tag)]

  ;; Settled success is a derived grammatical subset of W.
  [S (Returned st)
     (WorkFresh intro S tag)]

  [SC (DisjL S W)
      (DisjR W S)]

  [W (Work g st)
     (Returned st)
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

  [owner core delay disj search-join]
  [rn expose-frontier-fresh
      finish-success
      finish-failure
      force-delay
      commit-choice-answer
      commit-right-choice-answer
      work-succeed
      work-fail
      work-put
      allocate-fresh
      expand-conjunction
      expand-disjunction
      suspend-goal
      expose-choice-through-work-fresh
      erase-dead-fresh
      bubble-delay-through-fresh
      conj-return
      conj-fail
      bubble-delay-through-conj
      late-distribute-settled
      late-distribute-right-settled
      skip-left-failure
      rail-enter-right
      reassociate-left-result
      skip-right-failure
      rail-return-left
      reassociate-right-result]
  ;; Owner provenance is indexed by rule name.  Enumerating the valid pairs
  ;; keeps the other 80 name/owner combinations outside the language.
  [ell (expose-frontier-fresh core)
       (finish-success core)
       (finish-failure core)
       (force-delay delay)
       (commit-choice-answer disj)
       (commit-right-choice-answer search-join)
       (work-succeed core)
       (work-fail core)
       (work-put core)
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
  [WF BF LF])

(define (goal-in-language? term)
  (redex-match? redex-column-source-lang g term))

(define (work-in-language? term)
  (redex-match? redex-column-source-lang W term))

(define (frontier-in-language? term)
  (redex-match? redex-column-source-lang F term))

(define (value-in-language? term)
  (redex-match? redex-column-source-lang V term))

(define (answer-in-language? term)
  (redex-match? redex-column-source-lang A term))

(define (label-in-language? term)
  (redex-match? redex-column-source-lang ell term))
