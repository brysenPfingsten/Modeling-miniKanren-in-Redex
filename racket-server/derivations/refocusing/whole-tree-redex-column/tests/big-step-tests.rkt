#lang racket

(require racket/list
         racket/runtime-path
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "../big-step-language.rkt"
         "../big-step-correspondence.rkt"
         "../big-step-spec.rkt"
         "../big-step.rkt"
         "../compressed.rkt"
         "../kernel-toy.rkt"
         (prefix-in corpus:
                    "../../whole-tree-pipeline-pilot/corpus.rkt"))

(provide big-step-tests)

(define outside-work
  '(Work (put (sym "outside") (label "outside")) (state unit)))

(define witness-trees
  (list corpus:nested-scope-witness-tree
        corpus:late-hoist-witness-tree
        corpus:rail-turn-witness-tree
        corpus:right-active-fresh-witness-tree
        '(More (Work (fail (label "fail")) (state unit)))
        '(More Dead)
        `(More
          (DisjL
           (Work
            (fresh (x:q)
                   (fail (label "local-failure"))
                   (label "local-fresh"))
            (state unit))
           ,outside-work))
        '(More (Conj Dead (succeed (label "continue"))))
        `(More (DisjL Dead ,outside-work))
        `(More (DisjR ,outside-work Dead))
        `(More
          (DisjR
           ,outside-work
           (DisjL
            (Returned (state (sym "inside")))
            (Work (put (sym "later") (label "later")) (state unit)))))
        '(More
          (Work
           (suspend (put (sym "later") (label "later"))
                    (label "delay"))
           (state unit)))
        `(More
          (WorkFresh
           (u:0)
           (DisjL (Returned (state (sym "inside"))) ,outside-work)
           (label "root-scope")))
        '(Emit
          (Answer (state (sym "before")))
          (FrontierFresh
           (u:0)
           (Forced Done)
           (label "scope")))))

(define (unique-result who results)
  (match results
    [(list result) result]
    [_ (error who "expected one result, received ~e" results)]))

(define (initial-b frontier)
  (unique-result
   'initial-b
   (judgment-holds (initial-compressed/direct ,frontier B) B)))

(define (b-successors compressed)
  (judgment-holds
   (compressed-step/direct ,compressed Span B_1)
   (Span B_1)))

(define (trace-b initial [limit 256] [states (list initial)])
  (match (b-successors initial)
    ['() (reverse states)]
    [(list (list _span next))
     (unless (positive? limit)
       (error 'trace-b "step cap reached"))
     (trace-b next (sub1 limit) (cons next states))]
    [other (error 'trace-b "nondeterministic compressed step: ~e" other)]))

(define (spec-results compressed)
  (for/list ([certified
              (in-list
               (judgment-holds
                (compressed-big-step/spec ,compressed Spans O)
                (Spans O)))])
    (second certified)))

(define (spec-certified-results compressed)
  (judgment-holds
   (compressed-big-step/spec ,compressed Spans O)
   (Spans O)))

(define (direct-results compressed)
  (judgment-holds (promote/direct ,compressed O) O))

(define (direct-mode-results compressed)
  (match compressed
    [`(BRun ,work ,context)
     (judgment-holds (big-run/direct ,work ,context O) O)]
    [`(BSettled ,result ,context)
     (judgment-holds (big-settled/direct ,result ,context O) O)]
    [`(BDead ,context)
     (judgment-holds (big-dead/direct ,context O) O)]
    [`(BDelay ,work ,context)
     (judgment-holds (big-delay/direct ,work ,context O) O)]
    [`(BFinal ,terminal ,context)
     (judgment-holds (big-final/direct ,terminal ,context O) O)]))

(define (direct-proof-count compressed)
  (match compressed
    [`(BRun ,work ,context)
     (length (build-derivations (big-run/direct ,work ,context O)))]
    [`(BSettled ,result ,context)
     (length
      (build-derivations
       (big-settled/direct ,result ,context O)))]
    [`(BDead ,context)
     (length (build-derivations (big-dead/direct ,context O)))]
    [`(BDelay ,work ,context)
     (length
      (build-derivations (big-delay/direct ,work ,context O)))]
    [`(BFinal ,terminal ,context)
     (length
      (build-derivations (big-final/direct ,terminal ,context O)))]))

(define (span-trace compressed [limit 256])
  (match (b-successors compressed)
    ['() '()]
    [(list (list span next))
     (unless (positive? limit)
       (error 'span-trace "step cap reached"))
     (cons span (span-trace next (sub1 limit)))]
    [other
     (error 'span-trace "nondeterministic compressed step: ~e" other)]))

(define (mode-name compressed)
  (match compressed
    [`(BRun ,_ ,_) 'run]
    [`(BSettled ,_ ,_) 'settled]
    [`(BDead ,_) 'dead]
    [`(BDelay ,_ ,_) 'delay]
    [`(BFinal ,_ ,_) 'final]))

(define (root-equation-holds? frontier)
  (with-handlers ([exn:fail? (lambda (_exception) #f)])
    (equal?
     (judgment-holds (big-step/direct ,frontier O) O)
     (for/list ([certified
                 (in-list
                  (judgment-holds
                   (big-step/spec ,frontier Spans O)
                   (Spans O)))])
       (second certified)))))

(define-runtime-path direct-module "../big-step.rkt")

(define big-step-tests
  (test-suite
   "whole-tree Redex column: small-step to promoted big-step"

   (test-case
    "the strict compressed driver and direct promoted modes coincide on every reachable suffix"
    (for ([frontier (in-list witness-trees)])
      (for ([compressed (in-list (trace-b (initial-b frontier)))])
        (define spec* (spec-results compressed))
        (define direct* (direct-results compressed))
        (check-equal? (length spec*) 1 (format "spec ~e" compressed))
        (check-equal? direct* spec* (format "direct ~e" compressed))
        (check-equal? direct*
                      (direct-mode-results compressed)
                      (format "mode bridge ~e" compressed))
        (check-equal?
         (spec-certified-results compressed)
         (list (list (span-trace compressed) (first direct*)))
         (format "certificate ~e" compressed))
        (check-equal?
         (judgment-holds
          (big-step-square ,compressed Spans O)
          (Spans O))
         (spec-certified-results compressed)
         (format "square ~e" compressed))
        (check-equal?
         (length
          (build-derivations
           (compressed-big-step/spec ,compressed Spans O)))
         1
         (format "raw spec proof ~e" compressed))
        (check-equal?
         (length
          (build-derivations (promote/direct ,compressed O)))
         1
         (format "raw bridge proof ~e" compressed))
        (check-equal? (direct-proof-count compressed)
                      1
                      (format "raw direct proof ~e" compressed)))))

   (test-case
    "the promoted evaluator satisfies the one-step unfold law in both directions"
    (for ([frontier (in-list witness-trees)])
      (for ([compressed (in-list (trace-b (initial-b frontier)))])
        (match (b-successors compressed)
          ['()
           (check-match compressed `(BFinal ,_ ,_))]
          [(list (list _span next))
           (define certified
             (first (spec-certified-results compressed)))
           (match-define (list (cons span remaining) outcome) certified)
           (check-equal? (direct-results compressed)
                         (direct-results next)
                         (format "~e" compressed))
           (check-equal?
            (judgment-holds
             (big-step-unfold-square
              ,compressed Span B_1 Spans O)
             (Span B_1 Spans O))
            (list (list span next remaining outcome)))]
          [other
           (fail-check
            (format "unexpected compressed successors: ~e" other))]))))

   (test-case
    "all five residual modes occur and retain their category-specific entries"
    (define modes
      (remove-duplicates
       (append*
        (for/list ([frontier (in-list witness-trees)])
          (map mode-name (trace-b (initial-b frontier)))))))
    (for ([expected (in-list '(run settled dead delay final))])
      (check-not-false (member expected modes))))

   (test-case
    "direct root entry equals the closure specification and preserves observations"
    (for ([frontier (in-list witness-trees)])
      (define certified*
        (judgment-holds
         (big-step/spec ,frontier Spans O)
         (Spans O)))
      (define spec* (map second certified*))
      (define direct* (judgment-holds (big-step/direct ,frontier O) O))
      (define final-compressed
        (last (trace-b (initial-b frontier))))
      (check-equal? direct* spec* (format "~e" frontier))
      (check-equal? (length direct*) 1)
      (check-equal?
       (first (first certified*))
       (span-trace (initial-b frontier)))
      (check-equal?
       (judgment-holds
        (root-big-step-square ,frontier Spans O)
        (Spans O))
       certified*)
      (check-equal?
       (term (big-step-readback ,(first direct*)))
       (term (compressed-readback ,final-compressed)))))

   (test-case
    "frontier prefixes are accumulated directly in the F-to-F result context"
    (define frontier (last witness-trees))
    (define result
      (unique-result
       'prefixed-result
       (judgment-holds (big-step/direct ,frontier O) O)))
    (check-equal?
     result
     (term
      (FinalResult
       Done
       (Emit
        (Answer (state (sym "before")))
        (FrontierFresh
         (u:0)
         (Forced hole)
         (label "scope"))))))
    (check-equal? (term (big-step-readback ,result)) frontier))

   (test-case
    "well-formed root premises reject duplicate source binders"
    (define malformed
      '(More
        (Work
         (fresh (x:q x:q)
                (succeed (label "body"))
                (label "duplicate"))
         (state unit))))
    (check-false (judgment-holds (wf-frontier/toy ,malformed)))
    (check-equal?
     (judgment-holds (big-step/spec ,malformed Spans O) (Spans O))
     '())
    (check-equal? (judgment-holds (big-step/direct ,malformed O) O) '()))

   (test-case
    "bounded generated well-formed roots satisfy the finite big-step equivalence"
    (redex-check
     redex-column-big-step-direct-lang
     F
     (or (not (judgment-holds (wf-frontier/toy F)))
         (root-equation-holds? (term F)))
     #:attempts 500)
    (redex-check
     redex-column-big-step-direct-lang
     EQ
     (<= (length
          (build-derivations (evaluate-query/direct EQ O)))
         1)
     #:attempts 1000)
    (redex-check
     redex-column-big-step-direct-lang
     B
     (<= (length
          (build-derivations (promote/direct B O)))
         1)
     #:attempts 1000))

   (test-case
    "the direct recursive artifact has no earlier-stage operational dependency"
    (define module-text (file->string direct-module))
    (check-false (regexp-match? #rx"compressed[.]rkt\"" module-text))
    (check-false
     (regexp-match?
      #rx"[(](compressed-step|machine-step|source-step|decompose|contract|refocus)"
      module-text))
    (check-false
     (regexp-match? #rx"[(](match|cond|if|for/)" module-text)))))

(module+ test
  (run-tests big-step-tests))
