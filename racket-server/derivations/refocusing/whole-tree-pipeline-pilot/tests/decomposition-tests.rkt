#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "../corpus.rkt"
         "../language.rkt"
         (prefix-in derived: "../decomposition.rkt")
         (prefix-in source: "../source.rkt"))

(provide decomposition-tests)

(define witness-trees
  (list nested-scope-witness-tree
        late-hoist-witness-tree
        rail-turn-witness-tree
        right-active-fresh-witness-tree))

(define (source-trace-trees initial)
  (define-values (_steps _final status trees)
    (source:source-trace initial))
  (check-equal? status 'value)
  trees)

(define (check-context-index decomposition-result [label #f])
  (match decomposition-result
    [(derived:DecWork focus context)
     (check-true (work-in-language? focus) label)
     (check-true (derived:wf-context-in-language? context) label)]
    [(derived:DecFrontier focus context)
     (check-true (frontier-in-language? focus) label)
     (check-true (derived:ff-context-in-language? context) label)]))

(define (check-step-agreement tree [label #f])
  (match* ((source:source-step tree)
           (derived:derived-source-step tree))
    [(#f #f) (void)]
    [((source:transition source-name source-owner source-next)
      (derived:derived-transition derived-name derived-owner derived-next))
     (check-equal? derived-name source-name label)
     (check-equal? derived-owner source-owner label)
     (check-equal? derived-next source-next label)]
    [(source-result derived-result)
     (fail-check
      (format "source/derived mismatch for ~a: ~e versus ~e"
              label
              source-result
              derived-result))]))

(define returned-answer
  '(Returned (state (sym "inside"))))
(define inner-alternate
  '(Work (put (sym "later") (label "later")) (state unit)))
(define outside-work
  '(Work (put (sym "outside") (label "outside")) (state unit)))
(define fresh-tag
  '(label "branch-fresh"))
(define left-factored-choice
  `(WorkFresh (u:0)
              (DisjL ,returned-answer ,inner-alternate)
              ,fresh-tag))
(define right-factored-choice
  `(WorkFresh (u:0)
              (DisjR ,inner-alternate ,returned-answer)
              ,fresh-tag))

(define remaining-rule-cases
  (list
   (list "work-fail"
         '(More (Work (fail (label "fail")) (state unit))))
   (list "finish-failure"
         '(More Dead))
   (list "erase-dead-fresh"
         `(More
           (DisjL
            (WorkFresh (u:0) Dead ,fresh-tag)
            ,outside-work)))
   (list "conj-fail"
         '(More (Conj Dead (succeed (label "continue")))))
   (list "skip-left-failure"
         `(More (DisjL Dead ,outside-work)))
   (list "skip-right-failure"
         `(More (DisjR ,outside-work Dead)))
   (list "reassociate-right-result"
         `(More
           (DisjR
            ,outside-work
            (DisjL ,returned-answer ,inner-alternate))))))

(define decomposition-tests
  (test-suite
   "whole-tree pipeline pilot: indexed decomposition"

   (test-case
    "the context grammar carries its W/F indices"
    (check-true (derived:ww-context-in-language? 'ww-hole))
    (check-true
     (derived:ww-context-in-language?
      `(ww-disj-left
        ,outside-work
        (ww-fresh (u:0) ,fresh-tag ww-hole))))
    (check-true
     (derived:ff-context-in-language?
      '(ff-forced
        (ff-emit (Answer (state (sym "answer"))) ff-hole))))
    (check-true
     (derived:wf-context-in-language?
      `(wf-more
        (ww-conj (succeed (label "continue")) ww-hole)
        (ff-frontier-fresh (u:0) ,fresh-tag ff-hole))))
    (check-false (derived:ww-context-in-language? 'ff-hole))
    (check-false (derived:ff-context-in-language? 'ww-hole))
    (check-false
     (derived:wf-context-in-language?
      '(wf-more ff-hole ww-hole))))

   (test-case
    "plug inverts decomposition on every frozen source trace state"
    (for ([initial (in-list witness-trees)])
      (for ([tree (in-list (source-trace-trees initial))]
            [index (in-naturals)])
        (define decomposition-result
          (derived:decompose tree))
        (check-context-index decomposition-result
                             (format "~s state ~a" initial index))
        (check-equal? (derived:plug decomposition-result)
                      tree
                      (format "~s state ~a" initial index)))))

   (test-case
    "derived contraction agrees exactly with every frozen source step"
    (for ([initial (in-list witness-trees)])
      (for ([tree (in-list (source-trace-trees initial))]
            [index (in-naturals)])
        (check-step-agreement tree
                              (format "~s state ~a" initial index)))))

   (test-case
    "the remaining failure and right-reassociation rules agree exactly"
    (for ([entry (in-list remaining-rule-cases)])
      (match-define (list expected-name tree) entry)
      (define source-result
        (source:source-step tree))
      (define derived-result
        (derived:derived-source-step tree))
      (check-equal? (source:transition-name source-result) expected-name)
      (check-equal? (derived:derived-transition-name derived-result)
                    expected-name)
      (check-step-agreement tree expected-name)))

   (test-case
    "frontier exposure has priority for a factored fresh choice"
    (define tree
      `(Forced (More ,left-factored-choice)))
    (define decomposition-result
      (derived:decompose tree))
    (check-equal?
     decomposition-result
     (derived:DecWork
      left-factored-choice
      '(wf-more ww-hole (ff-forced ff-hole))))
    (check-equal? (vector-length (struct->vector decomposition-result)) 3)
    (define contraction-result
      (derived:contract decomposition-result))
    (check-equal?
     contraction-result
     (derived:ContractFrontier
      "expose-frontier-fresh"
      'core
      `(FrontierFresh
        (u:0)
        (More (DisjL ,returned-answer ,inner-alternate))
        ,fresh-tag)
      '(ff-forced ff-hole)))
    (check-equal? (vector-length (struct->vector contraction-result)) 5)
    (check-equal?
     (derived:plug-contract contraction-result)
     `(Forced
       (FrontierFresh
        (u:0)
        (More (DisjL ,returned-answer ,inner-alternate))
        ,fresh-tag))))

   (test-case
    "branch-local exposure focuses the entire left-oriented WorkFresh"
    (define tree
      `(More (DisjL ,left-factored-choice ,outside-work)))
    (define decomposition-result
      (derived:decompose tree))
    (check-equal?
     decomposition-result
     (derived:DecWork
      left-factored-choice
      `(wf-more
        (ww-disj-left ,outside-work ww-hole)
        ff-hole)))
    ;; In particular, the focus is not Returned with fresh/disjunction frames.
    (check-equal? (derived:DecWork-focus decomposition-result)
                  left-factored-choice)
    (define contraction-result
      (derived:contract decomposition-result))
    (check-equal?
     contraction-result
     (derived:ContractWork
      "expose-choice-through-work-fresh"
      'disj
      `(DisjL
        (WorkFresh (u:0) ,returned-answer ,fresh-tag)
        (WorkFresh (u:0) ,inner-alternate ,fresh-tag))
      `(wf-more
        (ww-disj-left ,outside-work ww-hole)
        ff-hole)))
    (check-equal? (derived:plug-contract contraction-result)
                  (source:transition-next (source:source-step tree))))

   (test-case
    "right-active branch-local exposure retains search-join ownership"
    (define tree
      `(More (DisjR ,outside-work ,right-factored-choice)))
    (define decomposition-result
      (derived:decompose tree))
    (check-equal?
     decomposition-result
     (derived:DecWork
      right-factored-choice
      `(wf-more
        (ww-disj-right ,outside-work ww-hole)
        ff-hole)))
    (define contraction-result
      (derived:contract decomposition-result))
    (check-equal?
     (derived:ContractWork-name contraction-result)
     "expose-choice-through-work-fresh")
    (check-equal?
     (derived:ContractWork-owner contraction-result)
     'search-join)
    (check-equal?
     (derived:ContractWork-replacement contraction-result)
     `(DisjR
       (WorkFresh (u:0) ,inner-alternate ,fresh-tag)
       (WorkFresh (u:0) ,returned-answer ,fresh-tag)))
    (check-equal? (derived:plug-contract contraction-result)
                  (source:transition-next (source:source-step tree))))

   (test-case
    "frontier terminals use DecFrontier without a sort field"
    (define tree
      '(FrontierFresh
        (u:0)
        (Forced (Last (Answer (state u:0))))
        (label "frontier")))
    (define decomposition-result
      (derived:decompose tree))
    (check-equal?
     decomposition-result
     (derived:DecFrontier
      '(Last (Answer (state u:0)))
      '(ff-forced
        (ff-frontier-fresh
         (u:0)
         (label "frontier")
         ff-hole))))
    (check-equal? (vector-length (struct->vector decomposition-result)) 3)
    (check-false (derived:contract decomposition-result))
    (check-false (derived:derived-source-step tree))
    (check-equal? (derived:plug decomposition-result) tree))

   (test-case
    "fresh allocation is recovered from the indexed context"
    (define tree
      '(FrontierFresh
        (u:0)
        (More
         (DisjL
          (Work
           (fresh (x:q)
                  (put x:q (label "answer"))
                  (label "inner-fresh"))
           (state unit))
          (Work (put u:1 (label "outside")) (state unit))))
        (label "outer-fresh")))
    (define expected
      (source:source-step tree))
    (define actual
      (derived:derived-source-step tree))
    (check-equal? (derived:derived-transition-name actual)
                  "allocate-fresh")
    ;; Both u:0 in FFCtx and u:1 in WWCtx are visible, so u:2 is chosen.
    (check-match
     (derived:derived-transition-next actual)
     `(FrontierFresh
       (u:0)
       (More
        (DisjL
         (WorkFresh (u:2) ,_inner (label "inner-fresh"))
         ,_outside))
       (label "outer-fresh")))
    (check-equal? (derived:derived-transition-name actual)
                  (source:transition-name expected))
    (check-equal? (derived:derived-transition-owner actual)
                  (source:transition-owner expected))
    (check-equal? (derived:derived-transition-next actual)
                  (source:transition-next expected)))))

(module+ test
  (run-tests decomposition-tests))
