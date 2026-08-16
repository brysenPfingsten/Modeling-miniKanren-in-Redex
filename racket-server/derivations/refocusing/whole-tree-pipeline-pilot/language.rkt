#lang racket

(require redex/reduction-semantics)

(provide pilot-source-lang
         goal-in-language?
         work-in-language?
         frontier-in-language?
         value-in-language?
         answer-in-language?)

(check-redundancy #t)

;; This is the one carrier selected for the vertical pipeline pilot.  The
;; unfinished-work and whole-frontier sorts are implicit in the grammar: W can
;; occur only below More (or another W constructor), while F is the root sort.
(define-language pilot-source-lang
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

  ;; S is a derived grammatical subset used to state the directed rules.  It
  ;; is not a reified sort tag in source terms.
  [S (Returned st)
     (WorkFresh intro S tag)]

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
     (Forced V)])

(define (goal-in-language? term)
  (redex-match? pilot-source-lang g term))

(define (work-in-language? term)
  (redex-match? pilot-source-lang W term))

(define (frontier-in-language? term)
  (redex-match? pilot-source-lang F term))

(define (value-in-language? term)
  (redex-match? pilot-source-lang V term))

(define (answer-in-language? term)
  (redex-match? pilot-source-lang A term))
