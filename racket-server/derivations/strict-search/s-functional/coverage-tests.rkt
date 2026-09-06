#lang racket

(require rackunit racket/runtime-path
         "../test-support/witnesses.rkt"
         (only-in "03-data.rkt" KDone)
         (only-in "../test-support/frontiers.rkt" pending?)
         (prefix-in corpus: "../test-support/corpus.rkt")
         (prefix-in m: "04-machine.rkt"))

(provide coverage-witnesses)

;; Read the declared families so adding a data constructor without a witness
;; fails coverage. These are expected tags, not values injected into a run.
(define-runtime-path data-module "03-data.rkt")
(define expected-constructors
  (call-with-input-file data-module
    (lambda (input)
      (read-line input) ; #lang; the remaining module forms are ordinary data.
      (for/seteq ([form (in-port read input)]
                  #:when (match form [`(struct ,_ ,_ ,_ ...) #t] [_ #f]))
        (match form
          [`(struct ,name ,_ ,_ ...)
           (string->symbol (format "struct:~a" name))])))))

(define expected-pcs (list->seteq (map first m:signatures)))

;; Both sets are accumulated across many configurations and reused by the
;; coverage comparisons. Sibling/resumption fields are traversed recursively;
;; checking only the active continuation would miss stored closure families.
(define (collect-constructors! value seen)
  (match value
    [(? struct?)
     (define fields (struct->vector value))
     (set-add! seen (vector-ref fields 0))
     (for ([field (in-vector fields 1)]) (collect-constructors! field seen))]
    [(cons first rest)
     (collect-constructors! first seen)
     (collect-constructors! rest seen)]
    [(? vector?)
     (for ([field (in-vector value)]) (collect-constructors! field seen))]
    [_ (void)]))

(define (collect-trace! current pcs constructors [fuel 100000])
  (collect-constructors! current constructors)
  (match current
    [(m:Halted value) value]
    [(m:Call pc _)
     (when (zero? fuel) (error 'collect-trace! "coverage witness exhausted fuel"))
     (set-add! pcs pc)
     (collect-trace! (m:step current) pcs constructors (sub1 fuel))]))

(define (collect-boundaries! frontier pcs constructors [fuel 1000])
  ;; Cover the collect-all entry both on the initial partial result and on
  ;; every partially observed result. Only the latter exercises rebuilding
  ;; already existing Forced history with KCollectHistory.
  (collect-trace! (m:Call 'collect/d (list frontier (KDone))) pcs constructors)
  ;; Every public resume-once starts a new advance/d computation with KDone.
  ;; This includes a final no-op on the completed frontier; Emit and Forced
  ;; prefixes are still traversed and rebuilt on that terminal call.
  (define next
    (collect-trace! (m:Call 'advance/d (list frontier (KDone))) pcs constructors))
  (if (pending? frontier)
      (begin
        (when (zero? fuel) (error 'collect-boundaries! "exposed boundary fuel exhausted"))
        (collect-boundaries! next pcs constructors (sub1 fuel)))
      (check-equal? next frontier "terminal resume-once preserves the complete frontier")))

(define (collect-witness! w pcs constructors)
  (define initial-frontier
    (collect-trace!
     (m:initial (witness-goal w) #:owners (witness-owners w)
                 #:state (witness-state w))
     pcs constructors))
  (collect-boundaries! initial-frontier pcs constructors))

(define (check-complete pcs constructors)
  (check-equal? (set-subtract expected-pcs pcs) (seteq)
                "every machine PC has executed")
  (check-true (subset? pcs expected-pcs)
              "executed PCs agree with the generated signature inventory")
  (check-equal? (set-subtract expected-constructors constructors) (seteq)
                "every declared continuation, resumption, outcome, and handler occurs"))

(module+ test
  (check-equal? (set-count expected-pcs) 13)
  (check-equal? (set-count expected-constructors) 27)
  (define pcs (mutable-seteq))
  (define constructors (mutable-seteq))
  ;; First establish that the small discriminating set covers every family.
  ;; These are the cases needed by the per-transition correspondence gate.
  (for ([w (in-list validation-witnesses)])
    (collect-witness! w pcs constructors))
  (check-complete pcs constructors)
  ;; Then inspect all additional corpus configurations, including the basic
  ;; run's first partial frontier, every one-boundary resumption, and explicit
  ;; collection from both unobserved and partially observed frontiers.
  (for ([goal (in-list corpus:search-corpus)] [index (in-naturals)])
    (collect-witness!
     (witness index goal '(Owners) '(state () () () (label "initial"))
              "Existing shared no-relcall search corpus")
     pcs constructors))
  (check-complete pcs constructors))
