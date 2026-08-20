#lang racket

(require redex/reduction-semantics
         "./languages/search-relcall-lang.rkt")

(provide structural-owner-record-occurrence-count
         structural-introduced-name-occurrence-count
         structural-answer-count
         structural-forced-count)

;; These observations count explicit syntax only. They are intentionally
;; independent of well-formedness: WF establishes ownership, while an
;; observation merely reports constructor occurrences in the term supplied.
;; Owners is a structural container, not an observed occurrence of its own.
(define (constructor-count datum constructor [count 0])
  (match datum
    ['() count]
    [(cons (? symbol? head) tail)
     (constructor-count
      tail
      constructor
      (if (eq? head constructor) (add1 count) count))]
    [(cons a d)
     (constructor-count
      a
      constructor
      (constructor-count d constructor count))]
    [_ count]))

(define (introduced-name-occurrence-count datum [count 0])
  (match datum
    ['() count]
    [`(Owner ,(? list? intro) ,_)
     (+ (length intro) count)]
    [(cons a d)
     (introduced-name-occurrence-count
      a
      (introduced-name-occurrence-count d count))]
    [_ count]))

(define-metafunction search-relcall-lang
  structural-owner-record-occurrence-count : any -> number
  [(structural-owner-record-occurrence-count any)
   ,(constructor-count (term any) 'Owner)])

(define-metafunction search-relcall-lang
  structural-introduced-name-occurrence-count : any -> number
  [(structural-introduced-name-occurrence-count any)
   ,(introduced-name-occurrence-count (term any))])

(define-metafunction search-relcall-lang
  structural-answer-count : any -> number
  [(structural-answer-count any)
   ,(constructor-count (term any) 'Answer)])

(define-metafunction search-relcall-lang
  structural-forced-count : any -> number
  [(structural-forced-count any)
   ,(constructor-count (term any) 'Forced)])

(module+ test
  (define example
    (term
     (()
      (Forced
       (Owners (Owner (u:0) (label "forced-owner")))
       (Emit
        (Owners (Owner () (label "emit-owner")))
        (Answer
         (Owners (Owner (u:1 u:2) (label "answer-owner")))
         (state () () () (label "answer")))
        (More
         (Returned
          (Owners (Owner (u:3) (label "returned-owner")))
          (state () () () (label "returned")))))))))
  (test-equal
   (term (structural-owner-record-occurrence-count ,example))
   4)
  (test-equal
   (term (structural-introduced-name-occurrence-count ,example))
   4)
  (test-equal (term (structural-answer-count ,example)) 1)
  (test-equal (term (structural-forced-count ,example)) 1))
