#lang racket

(require racket/list
         redex/reduction-semantics)

(provide canonical-u-support/host
         fresh-intro/from-datum/host
         fresh-intro/separated/host)

;; This module is deliberately below every derivation stage.  It computes
;; only the logical-variable support of ordinary Racket data and makes the
;; same variables-not-in choice used by the production semantics.  It knows
;; nothing about D, Z, M, B, contractions, or transitions.
(define (u-symbol? datum)
  (and (symbol? datum)
       (regexp-match? #rx"^u:" (symbol->string datum))))

(define (collect-u-symbols datum [acc '()])
  (match datum
    ['() acc]
    [(? u-symbol? u)
     (if (member u acc) acc (cons u acc))]
    [(cons a d)
     (collect-u-symbols a (collect-u-symbols d acc))]
    [_ acc]))

(define (canonical-u-support/host datum)
  (sort (collect-u-symbols datum)
        string<?
        #:key symbol->string))

(define (fresh-intro/from-datum/host datum binders)
  (variables-not-in
   (canonical-u-support/host datum)
   (make-list (length binders) 'u:0)))

(define (fresh-intro/separated/host work-focus work binders)
  (fresh-intro/from-datum/host
   (list work-focus work)
   binders))

(module+ test
  (require rackunit)

  (check-equal?
   (canonical-u-support/host
    '(More
      (Conj
       (Owners (Owner (u:2 u:0) (label "outer")))
       (Work (Owners (Owner (u:2) (label "inner")))
             (u:1 =? u:0 (label "goal"))
             (state () () () (label "state")))
       (succeed (label "right")))))
   '(u:0 u:1 u:2))

  (check-equal?
   (fresh-intro/separated/host
    '(More
      (Conj
       (Owners (Owner (u:0) (label "outer")))
       hole
       (u:2 =? u:2 (label "right"))))
    '(Work
      (Owners)
      (∃ (x:q x:r) (succeed (label "body")) (label "fresh"))
      (state () () () (label "state")))
    '(x:q x:r))
   '(u:1 u:3)))
