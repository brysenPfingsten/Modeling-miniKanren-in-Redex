#lang racket

(require redex/reduction-semantics
         "../control-language.rkt")

(provide pk-mk-lang
         canonical-goal-in-language?/mk
         goal-in-language?/mk
         work-in-language?/mk
         frontier-in-language?/mk
         label-in-language?/mk)

(check-redundancy #t)

(define-extended-language pk-mk-lang
  pk-control-lang
  [pt (sym string)
      (nat number)
      boolean
      (str string)
      empty]
  [t x u pt (t : t)]
  [sub ((u_!_ t) ...)]
  [dis ((t t) ...)]
  [eq (t =? t tag)]
  [trail (eq ...)]
  [kst (state sub dis trail tag)]
  [katom (succeed tag)
         (fail tag)
         (t =? t tag)
         (t != t tag)]
  [kname succeed
         fail
         unify-success
         unify-violates-disequality
         unify-fail
         disequality-success
         disequality-fail]

  ;; The adapter is outside the shared carrier; P[K] itself uses g.
  [cg (succeed tag)
      (fail tag)
      (t =? t tag)
      (t != t tag)
      (∃ lexical cg tag)
      (cg ∧ cg tag)
      (cg ∨ cg tag)
      (suspend cg tag)]
  [observation (t ...)])

(define (canonical-goal-in-language?/mk term)
  (redex-match? pk-mk-lang cg term))

(define (goal-in-language?/mk term)
  (redex-match? pk-mk-lang g term))

(define (work-in-language?/mk term)
  (redex-match? pk-mk-lang W term))

(define (frontier-in-language?/mk term)
  (redex-match? pk-mk-lang F term))

(define (label-in-language?/mk term)
  (redex-match? pk-mk-lang ell term))
