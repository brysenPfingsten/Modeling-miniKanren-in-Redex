#lang racket

(require redex/reduction-semantics
         "../../core/n/language.rkt")

(provide delay-n-oracle-lang)

(check-redundancy #t)

;; Direct numeric Delay carrier.  Delay wrappers carry no copied next counter;
;; the active state or terminal summary remains the only allocation supply.
(define-extended-language delay-n-oracle-lang core-n-oracle-lang
  [g ....
     (suspend g tag)]
  [W ....
     (PendingDelay W)]
  [F ....
     (Forced F)]

  [SpineContext ....
                (Forced SpineContext)])
