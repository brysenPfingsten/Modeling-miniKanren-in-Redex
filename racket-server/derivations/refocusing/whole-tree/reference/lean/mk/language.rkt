#lang racket

(require redex/reduction-semantics
         "../control-language.rkt")

(provide lean-mk-lang
         canonical-goal-in-language?/lean-mk
         goal-in-language?/lean-mk
         work-in-language?/lean-mk
         frontier-in-language?/lean-mk
         label-in-language?/lean-mk)

(check-redundancy #t)

(define-extended-language lean-mk-lang
  lean-control-lang
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

  [cg (succeed tag)
      (fail tag)
      (t =? t tag)
      (t != t tag)
      (∃ lexical cg tag)
      (cg ∧ cg tag)
      (cg ∨ cg tag)
      (suspend cg tag)]
  [observation (t ...)])

(define (canonical-goal-in-language?/lean-mk datum)
  (redex-match? lean-mk-lang cg datum))

(define (goal-in-language?/lean-mk datum)
  (redex-match? lean-mk-lang g datum))

(define (work-in-language?/lean-mk datum)
  (redex-match? lean-mk-lang W datum))

(define (frontier-in-language?/lean-mk datum)
  (redex-match? lean-mk-lang F datum))

(define (label-in-language?/lean-mk datum)
  (redex-match? lean-mk-lang ell datum))
