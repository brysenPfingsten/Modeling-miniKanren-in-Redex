#lang racket

(require redex/reduction-semantics
         (only-in "./refocused.rkt"
                  refocused-step/direct/s)
         "./machine.rkt")

(provide ZM-corresponds/s
         machine-step/spec/s
         ZM-step-square/s)

(check-redundancy #t)

(define-judgment-form
  core-s-machine-lang
  #:contract (ZM-corresponds/s Z M)
  #:mode (ZM-corresponds/s I O)

  [(where M (encode-ZM/s Z))
   ---------------------------------------------------- "structural Z/M correspondence/S"
   (ZM-corresponds/s Z M)])

;; Compositional specification: transport one direct Z edge across the explicit
;; codec.  The direct machine artifact is independently stated in machine.rkt.
(define-judgment-form
  core-s-machine-lang
  #:contract (machine-step/spec/s M RuleName M)
  #:mode (machine-step/spec/s I O O)

  [(where Z_0 (decode-MZ/s M_0))
   (refocused-step/direct/s Z_0 RuleName Z_1)
   (where M_1 (encode-ZM/s Z_1))
   ---------------------------------------------------- "transported exact machine step/S"
   (machine-step/spec/s M_0 RuleName M_1)])

(define-judgment-form
  core-s-machine-lang
  #:contract (ZM-step-square/s Z RuleName Z M M)
  #:mode (ZM-step-square/s I O O O O)

  [(where M_0 (encode-ZM/s Z_0))
   (refocused-step/direct/s Z_0 RuleName Z_1)
   (where M_1 (encode-ZM/s Z_1))
   (machine-step/direct/s M_0 RuleName M_1)
   ---------------------------------------------------- "exact labeled Z/M square/S"
   (ZM-step-square/s Z_0 RuleName Z_1 M_0 M_1)])

(module+ test
  (require rackunit)

  (define sigma/s
    (term (state () () () (label "state"))))

  (define z/s
    (term
     (ZWork
      (Work (Owners) (succeed (label "yes")) ,sigma/s)
      (More hole))))

  (define machine/s
    (term (encode-ZM/s ,z/s)))

  (define direct-results/s
    (judgment-holds
     (machine-step/direct/s
      ,machine/s
      RuleName
      M_next)
     (RuleName M_next)))

  (define spec-results/s
    (judgment-holds
     (machine-step/spec/s
      ,machine/s
      RuleName
      M_next)
     (RuleName M_next)))

  (check-equal?
   (length
    (build-derivations
     (machine-step/direct/s
      ,machine/s
      RuleName
      M_next)))
   1)
  (check-equal?
   (length
    (build-derivations
     (machine-step/spec/s
      ,machine/s
      RuleName
      M_next)))
   1)
  (check-equal?
   (length
    (build-derivations
     (ZM-step-square/s
      ,z/s
      RuleName
      Z_next
      M_0
      M_1)))
   1)
  (check-equal? direct-results/s spec-results/s)
  (check-equal?
   (judgment-holds
    (ZM-corresponds/s ,z/s M)
    M)
   (list machine/s)))
