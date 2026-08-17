#lang racket

(require racket/list
         racket/runtime-path
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "../toy/source.rkt"
         "../toy/wf.rkt"
         "../toy/machine.rkt"
         "../toy/machine-spec.rkt"
         "../toy/compressed.rkt"
         "../toy/compression-spec.rkt"
         "../toy/big-step-language.rkt"
         "../toy/big-step-spec.rkt"
         "../toy/big-step.rkt"
         "../toy/big-step-correspondence.rkt"
         "../mk/source.rkt"
         "../mk/wf.rkt"
         "../mk/machine.rkt"
         "../mk/machine-spec.rkt"
         "../mk/compressed.rkt"
         "../mk/compression-spec.rkt"
         "../mk/big-step-language.rkt"
         "../mk/big-step-spec.rkt"
         "../mk/big-step.rkt"
         "../mk/big-step-correspondence.rkt"
         "../mk/observations.rkt"
         (prefix-in corpus:
                    "../../../corpus/scenarios.rkt"))

(provide pk-back-half-tests)

(define toy-outside-work
  '(Work (put (sym "outside") (label "outside")) (state unit)))

(define nested-scope-witness-tree/toy
  (term
   (initial-tree/toy
    ,corpus:nested-scope-witness-goal)))

(define late-hoist-witness-tree/toy
  (term
   (initial-tree/toy
    ,corpus:late-hoist-witness-goal)))

(define rail-turn-witness-tree/toy
  (term
   (initial-tree/toy
    ,corpus:rail-turn-witness-goal)))

(define right-active-fresh-witness-tree/toy
  (term
   (initial-tree/toy
    ,corpus:right-active-fresh-witness-goal)))

;; This is the committed toy compression suite's twelve-root coverage corpus.
;; Keeping the corpus literal here makes the Ktoy oracle boundary inspectable;
;; the test-only translation below reuses its control shapes for Kmk.
(define toy-roots
  (list nested-scope-witness-tree/toy
        late-hoist-witness-tree/toy
        rail-turn-witness-tree/toy
        right-active-fresh-witness-tree/toy
        '(More (Work (fail (label "fail")) (state unit)))
        '(More Dead)
        `(More
          (DisjL
           (Work
            (fresh (x:q)
                   (fail (label "local-failure"))
                   (label "local-fresh"))
            (state unit))
           ,toy-outside-work))
        '(More (Conj Dead (succeed (label "continue"))))
        `(More (DisjL Dead ,toy-outside-work))
        `(More (DisjR ,toy-outside-work Dead))
        `(More
          (DisjR
           ,toy-outside-work
           (DisjL
            (Returned (state (sym "inside")))
            (Work (put (sym "later") (label "later"))
                  (state unit)))))
        '(More
          (Work
           (suspend (put (sym "later") (label "later"))
                    (label "delay"))
           (state unit)))))

(define empty-mk-state
  '(state () () () (label "s")))

;; A test adapter, not a semantic translation: `put` is replaced by an atomic
;; success and every toy payload state by the empty c-free Kmk state.  Thus the
;; exact same search-control shapes can witness the shared 25-label alphabet.
(define (toy-control-witness->mk datum)
  (match datum
    [`(state ,_payload) empty-mk-state]
    [`(put ,_payload ,tag) `(succeed ,tag)]
    [(cons first rest)
     (cons (toy-control-witness->mk first)
           (toy-control-witness->mk rest))]
    [_ datum]))

(define mk-control-roots
  (map toy-control-witness->mk toy-roots))

(define mk-goals
  (term
   ((succeed (label "succeed"))
    (fail (label "fail"))
    (empty =? empty (label "unify-success"))
    ((sym "a") =? (sym "b") (label "unify-fail"))
    ((sym "a") != (sym "b") (label "disequality-success"))
    (empty != empty (label "disequality-fail"))
    (conj
     (fail (label "left-fail"))
     (succeed (label "unreached"))
     (label "failed-conjunction"))
    (disj
     (fresh
      (x:q)
      (disj
       (succeed (label "nested-left"))
       (succeed (label "nested-right"))
       (label "nested-choice"))
      (label "nested-fresh"))
     (succeed (label "outer-right"))
     (label "outer-choice"))
    (fresh
     (x:q)
     (conj
      (x:q != (sym "a") (label "guard"))
      (x:q =? (sym "a") (label "violates"))
      (label "guard-then-bind"))
     (label "query"))
    (disj
     (suspend (fail (label "left")) (label "delay"))
     (succeed (label "right"))
     (label "rail")))))

(define mk-observation-root
  (term
   (initial-tree/mk
    (fresh
     (x:q)
     (disj
      (x:q =? (sym "cat") (label "cat"))
      (x:q =? (sym "dog") (label "dog"))
      (label "observation-choice"))
     (label "observation-query")))))

(define mk-roots
  (append
   (for/list ([goal (in-list mk-goals)])
     (term (initial-tree/mk ,goal)))
   (list mk-observation-root)))

(define toy-nested-partition
  '((transition-span
     (allocate-fresh core)
     (expose-frontier-fresh core))
    (transition-span (expand-disjunction disj))
    (transition-span (allocate-fresh core))
    (transition-span (expand-disjunction disj))
    (transition-span
     (kernel work-put core)
     (expose-choice-through-work-fresh disj))
    (transition-span (reassociate-left-result disj))
    (transition-span (commit-choice-answer disj))
    (transition-span
     (kernel work-put core)
     (commit-choice-answer disj))
    (transition-span
     (kernel work-put core)
     (finish-success core))))

(define toy-rail-partition
  '((transition-span (expand-disjunction disj))
    (transition-span
     (suspend-goal delay)
     (rail-enter-right search-join))
    (transition-span (force-delay delay))
    (transition-span
     (suspend-goal delay)
     (rail-return-left search-join))
    (transition-span (force-delay delay))
    (transition-span
     (kernel work-put core)
     (commit-choice-answer disj))
    (transition-span
     (kernel work-put core)
     (finish-success core))))

(define toy-late-partition
  '((transition-span (expand-conjunction core))
    (transition-span (expand-disjunction disj))
    (transition-span
     (kernel work-put core)
     (late-distribute-settled disj))
    (transition-span
     (kernel work-succeed core)
     (commit-choice-answer disj))
    (transition-span
     (kernel work-put core)
     (conj-return core))
    (transition-span
     (kernel work-succeed core)
     (finish-success core))))

(define toy-right-partition
  '((transition-span (expand-conjunction core))
    (transition-span (expand-conjunction core))
    (transition-span (allocate-fresh core))
    (transition-span
     (kernel work-put core)
     (conj-return core))
    (transition-span (expand-disjunction disj))
    (transition-span
     (suspend-goal delay)
     (rail-enter-right search-join))
    (transition-span (bubble-delay-through-fresh delay))
    (transition-span (bubble-delay-through-conj delay))
    (transition-span (force-delay delay))
    (transition-span
     (kernel work-put core)
     (expose-choice-through-work-fresh search-join))
    (transition-span
     (late-distribute-right-settled search-join))
    (transition-span
     (kernel work-succeed core)
     (commit-right-choice-answer search-join))
    (transition-span
     (kernel work-put core)
     (conj-return core)
     (expose-frontier-fresh core))
    (transition-span
     (kernel work-succeed core)
     (finish-success core))))

(define expected-toy-labels
  '((expose-frontier-fresh core)
    (finish-success core)
    (finish-failure core)
    (force-delay delay)
    (commit-choice-answer disj)
    (commit-right-choice-answer search-join)
    (kernel work-succeed core)
    (kernel work-fail core)
    (kernel work-put core)
    (allocate-fresh core)
    (expand-conjunction core)
    (expand-disjunction disj)
    (suspend-goal delay)
    (expose-choice-through-work-fresh disj)
    (expose-choice-through-work-fresh search-join)
    (erase-dead-fresh core)
    (bubble-delay-through-fresh delay)
    (conj-return core)
    (conj-fail core)
    (bubble-delay-through-conj delay)
    (late-distribute-settled disj)
    (late-distribute-right-settled search-join)
    (skip-left-failure disj)
    (rail-enter-right search-join)
    (reassociate-left-result disj)
    (skip-right-failure search-join)
    (rail-return-left search-join)
    (reassociate-right-result search-join)))

(define expected-shared-control-labels
  (filter (lambda (label)
            (match label
              [`(kernel ,_ core) #f]
              [_ #t]))
          expected-toy-labels))

(define expected-mk-kernel-labels
  '((kernel succeed core)
    (kernel fail core)
    (kernel unify-success core)
    (kernel unify-violates-disequality core)
    (kernel unify-fail core)
    (kernel disequality-success core)
    (kernel disequality-fail core)))

(define (unique-result who results)
  (match results
    [(list result) result]
    [_ (error who "expected one result, received ~e" results)]))

(define (span-labels span)
  (match span
    [`(transition-span ,labels ...) labels]))

(define (canonical-terms terms)
  (sort terms string<? #:key (lambda (value) (format "~s" value))))

(define (trace-states initial successors [limit 256]
                      [marks '()] [states (list initial)])
  (match (successors initial)
    ['() (values (reverse marks) (reverse states))]
    [(list (list mark next))
     (unless (positive? limit)
       (error 'trace-states "step cap reached"))
     (trace-states next
                   successors
                   (sub1 limit)
                   (cons mark marks)
                   (cons next states))]
    [other
     (error 'trace-states "nondeterministic step: ~e" other)]))

(define (check-compression-column
         roots initial-b initial-m b-successors spec-successors
         decode-b m-successors compression-square
         b-readback m-readback)
  (for ([frontier (in-list roots)])
    (define-values (spans b-states)
      (trace-states (initial-b frontier) b-successors))
    (define-values (labels m-states)
      (trace-states (initial-m frontier) m-successors 768))
    (check-equal? (decode-b (first b-states))
                  (first m-states)
                  (format "initial decode ~e" frontier))
    (for ([compressed (in-list b-states)])
      (define direct* (b-successors compressed))
      (define mapped*
        (for/list ([edge (in-list direct*)])
          (match-define (list span next) edge)
          (list span (decode-b next))))
      (define square*
        (for/list ([edge (in-list direct*)])
          (match-define (list span next) edge)
          (list span
                next
                (decode-b compressed)
                (decode-b next))))
      (check-equal? mapped*
                    (spec-successors compressed)
                    (format "compression specification ~e" compressed))
      (check-equal? (compression-square compressed)
                    square*
                    (format "compression square ~e" compressed)))
    (check-equal? (append-map span-labels spans) labels)
    (check-equal? (decode-b (last b-states)) (last m-states))
    (check-equal? (b-readback (last b-states))
                  (m-readback (last m-states)))))

(define (check-big-step-column
         roots initial-b b-successors spec-certified direct-results
         big-square big-unfold-square
         root-spec-certified root-direct-results root-square
         read-result b-readback)
  (for ([frontier (in-list roots)])
    (define-values (_root-spans states)
      (trace-states (initial-b frontier) b-successors))
    (for ([compressed (in-list states)])
      (define-values (suffix-spans _suffix-states)
        (trace-states compressed b-successors))
      (define certified* (spec-certified compressed))
      (define direct* (direct-results compressed))
      (check-equal? (length certified*) 1)
      (check-equal? direct* (map second certified*))
      (check-equal? (first certified*)
                    (list suffix-spans (first direct*)))
      (check-equal? (big-square compressed) certified*)
      (match (b-successors compressed)
        ['() (check-equal? (big-unfold-square compressed) '())]
        [(list (list span next))
         (check-equal?
          (big-unfold-square compressed)
          (list
           (list span next (rest suffix-spans) (first direct*))))]))
    (define root-certified* (root-spec-certified frontier))
    (define root-direct* (root-direct-results frontier))
    (check-equal? root-direct* (map second root-certified*))
    (check-equal? (length root-direct*) 1)
    (check-equal? (root-square frontier) root-certified*)
    (check-equal? (read-result (first root-direct*))
                  (b-readback (last states)))))

(define (reachable-modes roots initial-b b-successors)
  (sort
   (remove-duplicates
    (append-map
     (lambda (frontier)
       (define-values (_spans states)
         (trace-states (initial-b frontier) b-successors))
       (map car states))
     roots))
   symbol<?))

(define (reachable-labels roots initial-b b-successors)
  (remove-duplicates
   (append-map
    (lambda (frontier)
      (define-values (spans _states)
        (trace-states (initial-b frontier) b-successors))
      (append-map span-labels spans))
    roots)))

;; Toy wrappers.
(define (initial-b/toy frontier)
  (unique-result
   'initial-b/toy
   (judgment-holds (initial-compressed/direct/toy ,frontier B) B)))
(define (initial-m/toy frontier) (term (initial-M/toy ,frontier)))
(define (b-successors/toy compressed)
  (judgment-holds
   (compressed-step/direct/toy ,compressed Span B_1)
   (Span B_1)))
(define (b-spec-successors/toy compressed)
  (judgment-holds
   (compressed-step/spec/toy ,compressed Span M_1)
   (Span M_1)))
(define (compression-square/toy compressed)
  (judgment-holds
   (compression-step-square/toy ,compressed Span B_1 M_0 M_1)
   (Span B_1 M_0 M_1)))
(define (decode-b/toy compressed)
  (unique-result
   'decode-b/toy
   (judgment-holds (decode-BM/toy ,compressed M) M)))
(define (m-successors/toy machine)
  (judgment-holds
   (machine-step/direct/toy ,machine ell M_1)
   (ell M_1)))
(define (b-readback/toy compressed)
  (term (compressed-readback/toy ,compressed)))
(define (m-readback/toy machine) (term (readback-M/toy ,machine)))
(define (spec-certified/toy compressed)
  (judgment-holds
   (compressed-big-step/spec/toy ,compressed Spans O)
   (Spans O)))
(define (direct-results/toy compressed)
  (judgment-holds (promote/direct/toy ,compressed O) O))
(define (root-spec-certified/toy frontier)
  (judgment-holds (big-step/spec/toy ,frontier Spans O) (Spans O)))
(define (root-direct-results/toy frontier)
  (judgment-holds (big-step/direct/toy ,frontier O) O))
(define (read-result/toy result) (term (big-step-readback/toy ,result)))
(define (big-square/toy compressed)
  (judgment-holds
   (big-step-square/toy ,compressed Spans O)
   (Spans O)))
(define (big-unfold-square/toy compressed)
  (judgment-holds
   (big-step-unfold-square/toy ,compressed Span B_1 Spans O)
   (Span B_1 Spans O)))
(define (root-square/toy frontier)
  (judgment-holds
   (root-big-step-square/toy ,frontier Spans O)
   (Spans O)))

;; miniKanren wrappers.
(define (initial-b/mk frontier)
  (unique-result
   'initial-b/mk
   (judgment-holds (initial-compressed/direct/mk ,frontier B) B)))
(define (initial-m/mk frontier) (term (initial-M/mk ,frontier)))
(define (b-successors/mk compressed)
  (judgment-holds
   (compressed-step/direct/mk ,compressed Span B_1)
   (Span B_1)))
(define (b-spec-successors/mk compressed)
  (judgment-holds
   (compressed-step/spec/mk ,compressed Span M_1)
   (Span M_1)))
(define (compression-square/mk compressed)
  (judgment-holds
   (compression-step-square/mk ,compressed Span B_1 M_0 M_1)
   (Span B_1 M_0 M_1)))
(define (decode-b/mk compressed)
  (unique-result
   'decode-b/mk
   (judgment-holds (decode-BM/mk ,compressed M) M)))
(define (m-successors/mk machine)
  (judgment-holds
   (machine-step/direct/mk ,machine ell M_1)
   (ell M_1)))
(define (b-readback/mk compressed)
  (term (compressed-readback/mk ,compressed)))
(define (m-readback/mk machine) (term (readback-M/mk ,machine)))
(define (spec-certified/mk compressed)
  (judgment-holds
   (compressed-big-step/spec/mk ,compressed Spans O)
   (Spans O)))
(define (direct-results/mk compressed)
  (judgment-holds (promote/direct/mk ,compressed O) O))
(define (root-spec-certified/mk frontier)
  (judgment-holds (big-step/spec/mk ,frontier Spans O) (Spans O)))
(define (root-direct-results/mk frontier)
  (judgment-holds (big-step/direct/mk ,frontier O) O))
(define (read-result/mk result) (term (big-step-readback/mk ,result)))
(define (big-square/mk compressed)
  (judgment-holds
   (big-step-square/mk ,compressed Spans O)
   (Spans O)))
(define (big-unfold-square/mk compressed)
  (judgment-holds
   (big-step-unfold-square/mk ,compressed Span B_1 Spans O)
   (Span B_1 Spans O)))
(define (root-square/mk frontier)
  (judgment-holds
   (root-big-step-square/mk ,frontier Spans O)
   (Spans O)))

(define-runtime-path compressed-schema "../compressed-schema.rkt")
(define-runtime-path big-step-schema "../big-step-schema.rkt")

(define pk-back-half-tests
  (test-suite
   "whole-tree P[K]: compressed and promoted back half"

   (test-case
    "the same direct/spec compression square holds for Ktoy and Kmk"
    (check-compression-column
     toy-roots
     initial-b/toy initial-m/toy
     b-successors/toy b-spec-successors/toy
     decode-b/toy m-successors/toy compression-square/toy
     b-readback/toy m-readback/toy)
    (check-compression-column
     mk-roots
     initial-b/mk initial-m/mk
     b-successors/mk b-spec-successors/mk
     decode-b/mk m-successors/mk compression-square/mk
     b-readback/mk m-readback/mk))

   (test-case
    "the four toy witnesses retain their canonical tagged partitions"
    (define-values (nested _nested-states)
      (trace-states
       (initial-b/toy nested-scope-witness-tree/toy)
       b-successors/toy))
    (define-values (rail _rail-states)
      (trace-states
       (initial-b/toy rail-turn-witness-tree/toy)
       b-successors/toy))
    (define-values (late _late-states)
      (trace-states
       (initial-b/toy late-hoist-witness-tree/toy)
       b-successors/toy))
    (define-values (right _right-states)
      (trace-states
       (initial-b/toy right-active-fresh-witness-tree/toy)
       b-successors/toy))
    (check-equal? nested toy-nested-partition)
    (check-equal? rail toy-rail-partition)
    (check-equal? late toy-late-partition)
    (check-equal? right toy-right-partition))

   (test-case
    "the toy coverage corpus exercises all 28 exact tagged labels"
    (check-equal? (length expected-toy-labels) 28)
    (check-equal?
     (canonical-terms
      (reachable-labels toy-roots initial-b/toy b-successors/toy))
     (canonical-terms expected-toy-labels)))

   (test-case
    "the translated Kmk corpus exercises all 25 shared control labels"
    (for ([frontier (in-list mk-control-roots)])
      (check-true
       (judgment-holds (wf-frontier/mk ,frontier))
       (format "~e" frontier)))
    (define observed-shared
      (filter (lambda (label)
                (match label
                  [`(kernel ,_ core) #f]
                  [_ #t]))
              (reachable-labels
               mk-control-roots initial-b/mk b-successors/mk)))
    (check-equal? (length expected-shared-control-labels) 25)
    (check-equal?
     (canonical-terms observed-shared)
     (canonical-terms expected-shared-control-labels)))

   (test-case
    "every Kmk atomic rule remains an exact tagged span label"
    (define observed
      (remove-duplicates
       (append-map
        (lambda (frontier)
          (define-values (spans _states)
            (trace-states (initial-b/mk frontier) b-successors/mk))
          (filter
           (lambda (label)
             (match label [`(kernel ,_ core) #t] [_ #f]))
           (append-map span-labels spans)))
        mk-roots)))
    (for ([label (in-list expected-mk-kernel-labels)])
      (check-not-false (member label observed) (format "~e" label))))

   (test-case
    "Kmk terminal observations agree across spec, direct, and readback"
    (define expected
      '(((sym "cat")) ((sym "dog"))))
    (define spec* (root-spec-certified/mk mk-observation-root))
    (define direct* (root-direct-results/mk mk-observation-root))
    (check-equal? direct* (map second spec*))
    (check-equal?
     (map (lambda (result)
            (term
             (query-answers/mk
              (big-step-readback/mk ,result)
              (u:0))))
          direct*)
     (list expected))
    (check-equal?
     (for/list ([certified (in-list spec*)])
       (term
        (query-answers/mk
         (big-step-readback/mk ,(second certified))
         (u:0))))
     (list expected))
    (define-values (_spans states)
      (trace-states
       (initial-b/mk mk-observation-root)
       b-successors/mk))
    (check-equal?
     (term
      (query-answers/mk
       ,(b-readback/mk (last states))
       (u:0)))
     expected))

   (test-case
    "strict closure and independent promotion coincide for both kernels"
    (check-big-step-column
     toy-roots
     initial-b/toy b-successors/toy
     spec-certified/toy direct-results/toy
     big-square/toy big-unfold-square/toy
     root-spec-certified/toy root-direct-results/toy root-square/toy
     read-result/toy b-readback/toy)
    (check-big-step-column
     mk-roots
     initial-b/mk b-successors/mk
     spec-certified/mk direct-results/mk
     big-square/mk big-unfold-square/mk
     root-spec-certified/mk root-direct-results/mk root-square/mk
     read-result/mk b-readback/mk))

   (test-case
    "reachable witnesses exercise all five compressed control modes"
    (check-equal?
     (reachable-modes toy-roots initial-b/toy b-successors/toy)
     '(BDead BDelay BFinal BRun BSettled))
    (check-equal?
     (reachable-modes mk-roots initial-b/mk b-successors/mk)
     '(BDead BDelay BFinal BRun BSettled)))

   (test-case
    "kernel instance grammars reject mixed B states"
    (define toy-state
      (term
       (BRun
        (Work (succeed (label "toy")) (state unit))
        (More hole))))
    (define mk-state
      (term
       (BRun
        (Work
         (succeed (label "mk"))
         (state () () () (label "s")))
        (More hole))))
    (check-true (redex-match? pk-toy-compressed-lang B toy-state))
    (check-false (redex-match? pk-mk-compressed-lang B toy-state))
    (check-true (redex-match? pk-mk-compressed-lang B mk-state))
    (check-false (redex-match? pk-toy-compressed-lang B mk-state)))

   (test-case
    "private query grammars have total and unique raw derivations"
    (redex-check
     pk-toy-compressed-lang
     BQ
     (= (length
         (build-derivations
          (symbolic-path/direct/toy BQ Path)))
        1)
     #:attempts 500)
    (redex-check
     pk-mk-compressed-lang
     BQ
     (= (length
         (build-derivations
          (symbolic-path/direct/mk BQ Path)))
        1)
     #:attempts 500)
    (redex-check
     pk-toy-big-step-direct-lang
     EQ
     (= (length
         (build-derivations
          (evaluate-query/direct/toy EQ O)))
        1)
     #:attempts 500)
    (redex-check
     pk-mk-big-step-direct-lang
     EQ
     (= (length
         (build-derivations
          (evaluate-query/direct/mk EQ O)))
        1)
     #:attempts 500))

   (test-case
    "public B decoders and promoted entries are total on each grammar"
    (redex-check
     pk-toy-compression-spec-lang
     B
     (= (length (build-derivations (decode-BM/toy B M))) 1)
     #:attempts 500)
    (redex-check
     pk-mk-compression-spec-lang
     B
     (= (length (build-derivations (decode-BM/mk B M))) 1)
     #:attempts 500)
    (redex-check
     pk-toy-big-step-direct-lang
     B
     (= (length (build-derivations (promote/direct/toy B O))) 1)
     #:attempts 500)
    (redex-check
     pk-mk-big-step-direct-lang
     B
     (= (length (build-derivations (promote/direct/mk B O))) 1)
     #:attempts 500))

   (test-case
    "direct schemas contain no earlier-stage operational calls"
    (define compressed-text (file->string compressed-schema))
    (define big-step-text (file->string big-step-schema))
    (check-false
     (regexp-match?
      #rx"[(](source-step|machine-step|replay-span|contract|refocus)"
      compressed-text))
    (check-false
     (regexp-match?
      #rx"[(](compressed-step|machine-step|source-step|decompose|contract|refocus)"
      big-step-text)))))

(module+ test
  (run-tests pk-back-half-tests))
