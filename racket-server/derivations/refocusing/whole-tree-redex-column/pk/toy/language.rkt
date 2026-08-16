#lang racket

(require redex/reduction-semantics
         "../control-language.rkt")

(provide pk-toy-lang
         goal-in-language?/toy
         work-in-language?/toy
         frontier-in-language?/toy
         decomposition-leaf-in-language?/toy
         label-in-language?/toy)

(check-redundancy #t)

(define-extended-language pk-toy-lang
  pk-control-lang
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

(define (goal-in-language?/toy term)
  (redex-match? pk-toy-lang g term))

(define (work-in-language?/toy term)
  (redex-match? pk-toy-lang W term))

(define (frontier-in-language?/toy term)
  (redex-match? pk-toy-lang F term))

(define (decomposition-leaf-in-language?/toy term)
  (or (redex-match? pk-toy-lang BR term)
      (redex-match? pk-toy-lang LFR term)
      (redex-match? pk-toy-lang LR term)
      (redex-match? pk-toy-lang T term)))

(define (label-in-language?/toy term)
  (redex-match? pk-toy-lang ell term))
