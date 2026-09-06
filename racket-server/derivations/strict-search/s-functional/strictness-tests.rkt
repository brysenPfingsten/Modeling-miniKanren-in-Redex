#lang racket

(require rackunit redex/reduction-semantics
         "../test-support/witnesses.rkt" "../shared/kernel-equations.rkt"
         (only-in "partial-oracle.rkt" [partial-shape frontier-shape] search->partial)
         (prefix-in d: "00-direct.rkt")
         (prefix-in a: "01-anf.rkt")
         (prefix-in c: "02-cps.rkt")
         (prefix-in s: "../matrix/source-s.rkt")
         (prefix-in corpus: "../test-support/corpus.rkt"))

(provide frontier-shape source-atomic-work check-strict-runner)

;; Select the actual redex using the independent source language's strict C
;; contexts. A dormant eval under Delay is not a match. Work is read from the
;; configuration BEFORE the source's named eval-atom transition, so a test
;; observer in any functional implementation cannot manufacture the oracle.
(define source-atomic-focus
  (term-match/single s:StrictS
    [(in-hole C (eval owners a σ)) (list (term a) (term σ))]))

(define (source-atomic-work initial)
  (define steps (s:s-trace initial))
  (for/list ([before (in-list (cons initial (map second steps)))]
             [step (in-list steps)]
             #:when (equal? (first step) "eval-atom"))
    (source-atomic-focus before)))

(define (observe-work compute)
  (define reversed '())
  (define result
    (parameterize ([current-atomic-observer
                    (lambda (atom incoming)
                      (set! reversed (cons (list atom incoming) reversed)))])
      (compute)))
  (values result (reverse reversed)))

(define (check-one run collect-all goal owners state)
  (define initial `(eval ,owners ,goal ,state))
  (define-values (frontier eager-work)
    (observe-work (lambda () (run goal #:owners owners #:state state))))
  (check-equal? eager-work (source-atomic-work initial)
                "atomic work before the first partial frontier returns")
  (check-equal? (frontier-shape frontier)
                (frontier-shape (search->partial (s:s-run initial)))
                "exact eager frontier except for unforced Delay bodies")
  (define-values (observed all-work)
    (observe-work (lambda () (collect-all (run goal #:owners owners #:state state)))))
  (check-equal? all-work (source-atomic-work `(render ,initial))
                "atomic work including every forced resumption")
  (check-equal? observed (s:s-run `(render ,initial))
                "exact S observation before allocation projection"))

(define (named-witness name)
  (or (findf (lambda (w) (eq? (witness-name w) name)) witnesses)
      (error 'named-witness "missing fixture: ~a" name)))

(define (run-witness run collect-all name)
  (define w (named-witness name))
  (collect-all
   (run (witness-goal w) #:owners (witness-owners w) #:state (witness-state w))))

;; These literal expectations inspect the structural allocation information
;; that answer-only or S->N checks would erase. They do not invoke any other
;; evaluator to obtain expected provenance or names.
(define (ownership-shape observation)
  (match observation
    [`(Done ,owners) `(Done ,owners)]
    [`(Last ,owners (Answer ,local ,_)) `(Last ,owners (Answer ,local))]
    [`(Emit ,owners (Answer ,local ,_) ,rest)
     `(Emit ,owners (Answer ,local) ,(ownership-shape rest))]
    [`(Forced ,owners ,rest) `(Forced ,owners ,(ownership-shape rest))]))

(define exact-ownership
  '((empty-binder
     (Last (Owners) (Answer (Owners (Owner () (label "empty-fresh"))))))
    (unused-binder
     (Last (Owners) (Answer (Owners (Owner (u:0 u:1) (label "multi"))))))
    (shadowed-binder
     (Last (Owners)
           (Answer (Owners (Owner (u:0) (label "outer-fresh"))
                           (Owner (u:1) (label "inner-fresh"))))))
    (shared-outer
     (Emit (Owners (Owner (u:0) (label "shared"))) (Answer (Owners))
           (Last (Owners) (Answer (Owners)))))
    (sibling-reuse
     (Emit (Owners) (Answer (Owners (Owner (u:0) (label "left-owner"))))
           (Last (Owners) (Answer (Owners (Owner (u:0) (label "right-owner")))))))
    (answer-local-continuation
     (Emit (Owners)
           (Answer (Owners (Owner (u:0 u:1) (label "left-two"))
                           (Owner (u:2) (label "later-owner"))))
           (Last (Owners)
                 (Answer (Owners (Owner (u:0) (label "right-one"))
                                 (Owner (u:1) (label "later-owner")))))))
    (allocated-failure (Done (Owners (Owner (u:0) (label "failed-owner")))))
    (failed-sibling
     (Last (Owners) (Answer (Owners (Owner (u:0) (label "surviving-owner"))))))
    (allocation-across-delay
     (Forced (Owners (Owner (u:0) (label "outer-owner")))
             (Last (Owners) (Answer (Owners (Owner (u:1) (label "inner-owner")))))))
    (delayed-sibling-capture
     (Forced (Owners (Owner (u:0) (label "shared-owner")))
             (Emit (Owners) (Answer (Owners (Owner (u:1 u:2) (label "eager-owner"))))
                   (Last (Owners)
                         (Answer (Owners (Owner (u:1) (label "delayed-owner"))))))))
    (eager-bind-residual
     (Emit (Owners)
           (Answer (Owners (Owner (u:0) (label "fresh-A"))
                           (Owner (u:1) (label "later-fresh"))))
           (Last (Owners)
                 (Answer (Owners (Owner (u:0) (label "fresh-B"))
                                 (Owner (u:1) (label "later-fresh")))))))
    (nested-rail
     (Forced (Owners)
             (Forced (Owners)
                     (Forced (Owners)
                             (Forced (Owners)
                                     (Emit (Owners)
                                           (Answer (Owners (Owner (u:0) (label "fresh-A"))))
                                           (Emit (Owners)
                                                 (Answer (Owners (Owner (u:0) (label "fresh-B"))))
                                                 (Last (Owners)
                                                       (Answer (Owners (Owner (u:0) (label "fresh-C"))))))))))))
    (sparse-inherited-ancestry
     (Last (Owners)
           (Answer (Owners (Owner (u:9 u:2) (label "outer-pair"))
                           (Owner (u:7) (label "unused-ancestor"))
                           (Owner (u:0) (label "fresh"))))))
    (inherited-state-and-trail
     (Last (Owners)
           (Answer (Owners (Owner (u:9 u:2) (label "sparse"))
                           (Owner (u:0) (label "new-owner"))))))))

(define (answer-states observation)
  (match observation
    [`(Done ,_) '()]
    [`(Last ,_ (Answer ,_ ,state)) (list state)]
    [`(Emit ,_ (Answer ,_ ,state) ,rest) (cons state (answer-states rest))]
    [`(Forced ,_ ,rest) (answer-states rest)]))

(define (work-labels run name #:collect-all [collect-all #f])
  (define w (named-witness name))
  (define-values (_result work)
    (observe-work
     (lambda ()
       (define frontier
         (run (witness-goal w) #:owners (witness-owners w) #:state (witness-state w)))
       (if collect-all (collect-all frontier) frontier))))
  (map (lambda (event) (last (first event))) work))

(define (check-exact-discriminants run collect-all)
  (for ([entry (in-list exact-ownership)])
    (match-define (list name expected) entry)
    (check-equal? (ownership-shape (run-witness run collect-all name)) expected
                  (format "literal ownership: ~a" name)))
  (check-equal?
   (map second (answer-states (run-witness run collect-all 'answer-local-continuation)))
   '(((u:2 (nat 9)) (u:1 (sym "A")))
     ((u:1 (nat 9)) (u:0 (sym "B")))))
  (check-equal?
   (map second (answer-states (run-witness run collect-all 'delayed-sibling-capture)))
   '(((u:2 u:0)) ((u:1 u:0))))
  (check-equal?
   (map second (answer-states (run-witness run collect-all 'nested-rail)))
   '(((u:0 (sym "A"))) ((u:0 (sym "B"))) ((u:0 (sym "C")))))
  (check-equal?
   (answer-states (run-witness run collect-all 'inherited-state-and-trail))
   '((state ((u:0 (sym "A")) (u:2 (sym "A")) (u:9 u:2))
            ((u:0 (sym "other")) (u:9 (sym "avoid")))
            ((u:9 =? u:2 (label "alias")) (u:2 =? (sym "A") (label "value"))
             (u:0 =? u:9 (label "new-alias")))
            (label "replay"))))
  ;; These are eager-boundary checks: full observations alone would accept
  ;; an online implementation that performs continuation work after emit.
  (check-equal? (work-labels run 'eager-bind-residual)
                '((label "A") (label "B") (label "later") (label "later")))
  (check-equal? (work-labels run 'nested-rail) '())
  (check-equal? (work-labels run 'allocation-across-delay)
                '((label "outer-value")))
  (check-equal? (work-labels run 'allocation-across-delay #:collect-all collect-all)
                '((label "outer-value") (label "inner-alias")))
  (check-equal? (work-labels run 'delayed-sibling-capture)
                '((label "eager-alias")))
  (check-equal? (work-labels run 'delayed-sibling-capture #:collect-all collect-all)
                '((label "eager-alias") (label "delayed-alias"))))

(define (check-strict-runner label run collect-all)
  (test-case (format "~a: literal S allocation and strictness witnesses" label)
    (check-exact-discriminants run collect-all))
  (for ([w (in-list validation-witnesses)])
    (test-case (format "~a: independent strict work ~a" label (witness-name w))
      (check-one run collect-all (witness-goal w) (witness-owners w) (witness-state w))))
  (for ([goal (in-list corpus:search-corpus)] [index (in-naturals)])
    (test-case (format "~a: independent strict corpus work ~a" label index)
      (check-one run collect-all goal '(Owners) '(state () () () (label "initial"))))))

(module+ test
  (check-strict-runner 'direct d:run d:collect-all)
  (check-strict-runner 'anf a:run a:collect-all)
  (check-strict-runner 'cps c:run c:collect-all))
