#lang racket

(require rackunit
         rackunit/text-ui
         "../corpus.rkt"
         "../language.rkt"
         (prefix-in derived: "../decomposition.rkt")
         (prefix-in machine: "../refocused.rkt")
         (prefix-in source: "../source.rkt"))

(provide refocused-tests)

(define witness-trees
  (list nested-scope-witness-tree
        late-hoist-witness-tree
        rail-turn-witness-tree
        right-active-fresh-witness-tree))

(define returned-answer
  '(Returned (state (sym "inside"))))
(define inner-alternate
  '(Work (put (sym "later") (label "later")) (state unit)))
(define outside-work
  '(Work (put (sym "outside") (label "outside")) (state unit)))
(define fresh-tag
  '(label "branch-fresh"))

(define remaining-rule-trees
  (list
   '(More (Work (fail (label "fail")) (state unit)))
   '(More Dead)
   `(More
     (DisjL
      (WorkFresh (u:0) Dead ,fresh-tag)
      ,outside-work))
   '(More (Conj Dead (succeed (label "continue"))))
   `(More (DisjL Dead ,outside-work))
   `(More (DisjR ,outside-work Dead))
   `(More
     (DisjR
      ,outside-work
      (DisjL ,returned-answer ,inner-alternate)))))

(define all-initial-trees
  (append witness-trees remaining-rule-trees))

(define (machine-state? candidate)
  (or (derived:DecWork? candidate)
      (derived:DecFrontier? candidate)))

(define (check-state-index state [label #f])
  (match state
    [(derived:DecWork focus context)
     (check-true (work-in-language? focus) label)
     (check-true (derived:wf-context-in-language? context) label)]
    [(derived:DecFrontier focus context)
     (check-true (frontier-in-language? focus) label)
     (check-true (derived:ff-context-in-language? context) label)]))

(define (check-lockstep tree state [limit 256] [index 0])
  (define label
    (format "state ~a of ~s" index tree))
  (check-true (positive? limit) label)
  (check-true (machine-state? state) label)
  (check-state-index state label)
  (check-equal? (machine:readback state) tree label)
  (match* ((source:source-step tree)
           (machine:machine-step state))
    [(#f #f) (void)]
    [((source:transition source-name source-owner source-next)
      (machine:machine-transition machine-name machine-owner machine-next))
     (check-equal? machine-name source-name label)
     (check-equal? machine-owner source-owner label)
     (check-true (machine-state? machine-next) label)
     (check-equal? (machine:readback machine-next) source-next label)
     (check-lockstep source-next machine-next (sub1 limit) (add1 index))]
    [(source-result machine-result)
     (fail-check
      (format "source/refocused mismatch at ~a: ~e versus ~e"
              label
              source-result
              machine-result))]))

(define (check-refocus-oracle state [limit 256] [index 0])
  (check-true (positive? limit))
  (match (derived:contract state)
    [#f (void)]
    [contraction-result
     (define next
       (machine:refocus-contract contraction-result))
     (define reconstructed
       (derived:plug-contract contraction-result))
     (check-equal?
      (machine:readback next)
      reconstructed
      (format "refocus readback at state ~a" index))
     (check-equal?
      next
      (derived:decompose reconstructed)
      (format "refocus/root-decompose oracle at state ~a" index))
     (check-refocus-oracle next (sub1 limit) (add1 index))]))

(define refocused-tests
  (test-suite
   "whole-tree pipeline pilot: exact refocused machine"

   (test-case
    "initial decomposition and readback preserve every initial tree"
    (for ([tree (in-list all-initial-trees)])
      (define state
        (machine:initial-machine tree))
      (check-true (machine-state? state))
      (check-equal? (machine:readback state) tree)))

   (test-case
    "machine transitions are in exact one-rule source lockstep"
    (for ([tree (in-list all-initial-trees)])
      (check-lockstep tree (machine:initial-machine tree))))

   (test-case
    "complete marked traces and every readback tree agree"
    (for ([tree (in-list witness-trees)])
      (define-values (source-steps source-final source-status source-trees)
        (source:source-trace tree))
      (define-values (machine-steps machine-final machine-status states)
        (machine:machine-trace (machine:initial-machine tree)))
      (check-equal? machine-steps source-steps)
      (check-equal? machine-status source-status)
      (check-equal? (machine:readback machine-final) source-final)
      (check-equal? (map machine:readback states) source-trees)
      (for ([state (in-list states)])
        (check-true (machine-state? state)))))

   (test-case
    "direct refocusing equals root decomposition as a test-only oracle"
    (for ([tree (in-list all-initial-trees)])
      (check-refocus-oracle (machine:initial-machine tree))))

   (test-case
    "allocation at More refocuses to boundary exposure before inner work"
    (define tree
      '(More
        (Work
         (fresh (x:q)
                (put x:q (label "answer"))
                (label "fresh"))
         (state unit))))
    (define initial
      (machine:initial-machine tree))
    (define allocation
      (machine:machine-step initial))
    (check-match
     allocation
     (machine:machine-transition
      "allocate-fresh"
      'core
      (derived:DecWork
       `(WorkFresh (u:0) ,_inner (label "fresh"))
       '(wf-more ww-hole ff-hole))))
    (define after-allocation
      (machine:machine-transition-next allocation))
    ;; If refocusing had merely descended into the contractum, this focus
    ;; would be its inner Work rather than the complete WorkFresh.
    (check-match
     after-allocation
     (derived:DecWork
      `(WorkFresh (u:0) (Work ,_goal (state unit)) (label "fresh"))
      '(wf-more ww-hole ff-hole)))
    (define exposure
      (machine:machine-step after-allocation))
    (check-equal? (machine:machine-transition-name exposure)
                  "expose-frontier-fresh")
    (check-equal? (machine:machine-transition-owner exposure) 'core)
    (check-match
     (machine:readback (machine:machine-transition-next exposure))
     `(FrontierFresh
       (u:0)
       (More (Work ,_goal (state unit)))
       (label "fresh"))))

   (test-case
    "DecFrontier is the exact final state and carries no sort field"
    (define tree
      '(FrontierFresh
        (u:0)
        (Forced (Last (Answer (state u:0))))
        (label "frontier")))
    (define state
      (machine:initial-machine tree))
    (check-match state (derived:DecFrontier _focus _context))
    (check-equal? (vector-length (struct->vector state)) 3)
    (check-equal? (machine:readback state) tree)
    (check-false (machine:machine-step state)))))

(module+ test
  (run-tests refocused-tests))
