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

;; This polynomial interpretation is context-monotone.  WorkFresh doubles its
;; child's rank; choice contributes 2 and delay contributes 1.  Consequently:
;;
;;   WF(Disj(l,r)) = 5 + 2L + 2R > 4 + 2L + 2R = Disj(WF(l),WF(r))
;;   WF(Delay(w))  = 3 + 2W      > 2 + 2W      = Delay(WF(w))
;;
;; erasing a dead marker and exposing one at More also strictly decrease.
;; Unlike the former subtree-size sum, these inequalities remain strict below
;; another WorkFresh because every enclosing interpretation is monotone.
(define (fresh-marker-rank datum)
  (match datum
    [`(WorkFresh ,_intro ,inner ,_tag)
     (add1 (* 2 (fresh-marker-rank inner)))]
    [`(PendingDelay ,inner)
     (add1 (fresh-marker-rank inner))]
    [`(DisjL ,left ,right)
     (+ 2
        (fresh-marker-rank left)
        (fresh-marker-rank right))]
    [`(DisjR ,left ,right)
     (+ 2
        (fresh-marker-rank left)
        (fresh-marker-rank right))]
    [(cons first rest)
     (+ (fresh-marker-rank first)
        (fresh-marker-rank rest))]
    [_ 0]))
