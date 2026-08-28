#lang racket

(require redex/reduction-semantics
         "../control-language.rkt")

(provide lean-toy-lang
         goal-in-language?/lean-toy
         work-in-language?/lean-toy
         frontier-in-language?/lean-toy
         label-in-language?/lean-toy)

(check-redundancy #t)

(define-extended-language lean-toy-lang
  lean-control-lang
  [tp (sym string)
      (nat number)
      boolean
      (str string)
      unit]
  [p tp x u (p : p)]
  [kst (state p)]
  [katom (succeed tag)
         (fail tag)
         (put p tag)]
  [kname work-succeed
         work-fail
         work-put])

(define (goal-in-language?/lean-toy datum)
  (redex-match? lean-toy-lang g datum))

(define (work-in-language?/lean-toy datum)
  (redex-match? lean-toy-lang W datum))

(define (frontier-in-language?/lean-toy datum)
  (redex-match? lean-toy-lang F datum))

(define (label-in-language?/lean-toy datum)
  (redex-match? lean-toy-lang ell datum))
