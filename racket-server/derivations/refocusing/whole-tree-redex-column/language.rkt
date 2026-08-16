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
;;   WW   : W -> W
;;   FF   : F -> F
;;   WF   : W -> F
;;   WF+  : W -> F, with at least one non-fresh W frame below More
;;
;; TopW deliberately omits WorkFresh as its first frame.  Consequently no
;; local rule can descend through a WorkFresh immediately below More; the
;; frontier exposure rule has grammatical priority there.  WW still admits
;; WorkFresh below a Conj/Disj frame, which is exactly the branch-local case.
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
  [ell (rn owner)]

  [WW hole
      (WorkFresh intro WW tag)
      (Conj WW g)
      (DisjL WW W)
      (DisjR W WW)]
  [TopW hole
        (Conj WW g)
        (DisjL WW W)
        (DisjR W WW)]
  [TopW+ (Conj WW g)
         (DisjL WW W)
         (DisjR W WW)]
  [FF hole
      (FrontierFresh intro FF tag)
      (Emit A FF)
      (Forced FF)]
  [WF (More TopW)
      (FrontierFresh intro WF tag)
      (Emit A WF)
      (Forced WF)]
  [WF+ (More TopW+)
       (FrontierFresh intro WF+ tag)
       (Emit A WF+)
       (Forced WF+)])

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
