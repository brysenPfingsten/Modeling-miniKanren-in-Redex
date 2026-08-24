#lang racket

(require redex/reduction-semantics
         "../../core/e/language.rkt")

(provide delay-e-oracle-lang)

(check-redundancy #t)

;; Direct state-support Delay carrier.  Delay wrappers carry no duplicate
;; Support summary; the active world's state or terminal carrier remains the
;; sole supply witness.
(define-extended-language delay-e-oracle-lang core-e-oracle-lang
  [g ....
     (suspend g tag)]
  [W ....
     (PendingDelay W)]
  [F ....
     (Forced F)]

  [SpineContext ....
                (Forced SpineContext)])
