#lang racket

(provide fresh-stutter-labels
         fresh-stutter-label?
         visible-source-labels
         alpha-normal-form
         alpha-equivalent?
         fresh-marker-rank)

;; These are exactly the marked rules whose endpoints become equal after
;; fresh-ownership erasure.  They are source evidence, not lean transitions.
(define fresh-stutter-labels
  '((expose-frontier-fresh core)
    (expose-choice-through-work-fresh disj)
    (expose-choice-through-work-fresh search-join)
    (erase-dead-fresh core)
    (bubble-delay-through-fresh delay)))

(define (fresh-stutter-label? label)
  (and (member label fresh-stutter-labels) #t))

(define (visible-source-labels labels)
  (filter (lambda (label)
            (not (fresh-stutter-label? label)))
          labels))

(define (u-symbol? value)
  (and (symbol? value)
       (regexp-match? #rx"^u:" (symbol->string value))))

(define (canonical-u next)
  (string->symbol (format "u:a~a" next)))

;; Canonicalize logical variables by first occurrence.  The source Q law uses
;; this only after structural fresh-marker erasure; tags, lexical variables,
;; constructors, and kernel data retain their literal identity.
(define (alpha-normalize/at datum environment next)
  (match datum
    [(? u-symbol? name)
     (match (assq name environment)
       [(cons _ canonical)
        (values canonical environment next)]
       [#f
        (define canonical (canonical-u next))
        (values canonical
                (cons (cons name canonical) environment)
                (add1 next))])]
    [(cons first rest)
     (define-values (first* environment* next*)
       (alpha-normalize/at first environment next))
     (define-values (rest* environment** next**)
       (alpha-normalize/at rest environment* next*))
     (values (cons first* rest*) environment** next**)]
    [_ (values datum environment next)]))

(define (alpha-normal-form datum)
  (define-values (normalized _environment _next)
    (alpha-normalize/at datum '() 0))
  normalized)

(define (alpha-equivalent? left right)
  (equal? (alpha-normal-form left)
          (alpha-normal-form right)))

;; Size is used only to give every WorkFresh crossing a strictly positive,
;; super-additive weight.  Base 3 makes distributing one marker across a
;; binary choice strictly decrease the total even when both branches are
;; leaves.
(define (work-size work)
  (match work
    [`(Work ,_goal ,_state) 1]
    [`(Returned ,_state) 1]
    ['Dead 1]
    [`(WorkFresh ,_intro ,inner ,_tag)
     (add1 (work-size inner))]
    [`(Conj ,inner ,_goal)
     (add1 (work-size inner))]
    [`(PendingDelay ,inner)
     (add1 (work-size inner))]
    [`(DisjL ,left ,right)
     (+ 1 (work-size left) (work-size right))]
    [`(DisjR ,left ,right)
     (+ 1 (work-size left) (work-size right))]
    [_ (raise-argument-error 'work-size "marked work term" work)]))

(define (fresh-marker-rank datum)
  (match datum
    [`(WorkFresh ,_intro ,inner ,_tag)
     (+ (expt 3 (work-size inner))
        (fresh-marker-rank inner))]
    [(cons first rest)
     (+ (fresh-marker-rank first)
        (fresh-marker-rank rest))]
    [_ 0]))
