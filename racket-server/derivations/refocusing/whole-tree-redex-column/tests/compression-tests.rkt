#lang racket

(require racket/list
         racket/runtime-path
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "../compressed.rkt"
         "../compression-spec.rkt"
         "../kernel-toy.rkt"
         "../machine.rkt"
         "../machine-spec.rkt"
         (prefix-in corpus:
                    "../../whole-tree-pipeline-pilot/corpus.rkt"))

(provide compression-tests)

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
           (state unit)))))

(define expected-labels
  '((expose-frontier-fresh core)
    (finish-success core)
    (finish-failure core)
    (force-delay delay)
    (commit-choice-answer disj)
    (commit-right-choice-answer search-join)
    (work-succeed core)
    (work-fail core)
    (work-put core)
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

(define nested-partition
  '((transition-span (allocate-fresh core) (expose-frontier-fresh core))
    (transition-span (expand-disjunction disj))
    (transition-span (allocate-fresh core))
    (transition-span (expand-disjunction disj))
    (transition-span (work-put core)
                     (expose-choice-through-work-fresh disj))
    (transition-span (reassociate-left-result disj))
    (transition-span (commit-choice-answer disj))
    (transition-span (work-put core) (commit-choice-answer disj))
    (transition-span (work-put core) (finish-success core))))

(define rail-partition
  '((transition-span (expand-disjunction disj))
    (transition-span (suspend-goal delay)
                     (rail-enter-right search-join))
    (transition-span (force-delay delay))
    (transition-span (suspend-goal delay)
                     (rail-return-left search-join))
    (transition-span (force-delay delay))
    (transition-span (work-put core) (commit-choice-answer disj))
    (transition-span (work-put core) (finish-success core))))

(define late-partition
  '((transition-span (expand-conjunction core))
    (transition-span (expand-disjunction disj))
    (transition-span (work-put core) (late-distribute-settled disj))
    (transition-span (work-succeed core) (commit-choice-answer disj))
    (transition-span (work-put core) (conj-return core))
    (transition-span (work-succeed core) (finish-success core))))

(define right-partition
  '((transition-span (expand-conjunction core))
    (transition-span (expand-conjunction core))
    (transition-span (allocate-fresh core))
    (transition-span (work-put core) (conj-return core))
    (transition-span (expand-disjunction disj))
    (transition-span (suspend-goal delay)
                     (rail-enter-right search-join))
    (transition-span (bubble-delay-through-fresh delay))
    (transition-span (bubble-delay-through-conj delay))
    (transition-span (force-delay delay))
    (transition-span (work-put core)
                     (expose-choice-through-work-fresh search-join))
    (transition-span (late-distribute-right-settled search-join))
    (transition-span (work-succeed core)
                     (commit-right-choice-answer search-join))
    (transition-span (work-put core)
                     (conj-return core)
                     (expose-frontier-fresh core))
    (transition-span (work-succeed core) (finish-success core))))

(define (unique-result who results)
  (match results
    [(list result) result]
    [_ (error who "expected one result, received ~e" results)]))

(define (initial-b frontier)
  (unique-result
   'initial-b
   (judgment-holds (initial-compressed/direct ,frontier B) B)))

(define (initial-m frontier)
  (term (initial-M ,frontier)))

(define (decode-b compressed)
  (unique-result
   'decode-b
   (judgment-holds (decode-BM ,compressed M) M)))

(define (b-successors compressed)
  (judgment-holds
   (compressed-step/direct ,compressed Span B_1)
   (Span B_1)))

(define (b-spec-successors compressed)
  (judgment-holds
   (compressed-step/spec ,compressed Span M_1)
   (Span M_1)))

(define (m-successors machine)
  (judgment-holds
   (machine-step/direct ,machine ell M_1)
   (ell M_1)))

(define (span-labels span)
  (match span
    [`(transition-span ,labels ...) labels]))

(define (trace-b initial [limit 256] [spans '()] [states (list initial)])
  (match (b-successors initial)
    ['() (values (reverse spans) (reverse states))]
    [(list (list span next))
     (unless (positive? limit)
       (error 'trace-b "step cap reached"))
     (trace-b next
              (sub1 limit)
              (cons span spans)
              (cons next states))]
    [other (error 'trace-b "nondeterministic compressed step: ~e" other)]))

(define (trace-m initial [limit 768] [labels '()] [states (list initial)])
  (match (m-successors initial)
    ['() (values (reverse labels) (reverse states))]
    [(list (list label next))
     (unless (positive? limit)
       (error 'trace-m "step cap reached"))
     (trace-m next
              (sub1 limit)
              (cons label labels)
              (cons next states))]
    [other (error 'trace-m "nondeterministic machine step: ~e" other)]))

(define (trace-for frontier)
  (trace-b (initial-b frontier)))

(define (mapped-direct-successors compressed)
  (for/list ([successor (in-list (b-successors compressed))])
    (match-define (list span next) successor)
    (list span (decode-b next))))

(define (compressed-arrow-holds? compressed [limit 256])
  (define direct* (b-successors compressed))
  (define agrees?
    (equal? (mapped-direct-successors compressed)
            (b-spec-successors compressed)))
  (and agrees?
       (match direct*
         ['() #t]
         [(list (list _span next))
          (and (positive? limit)
               (compressed-arrow-holds? next (sub1 limit)))]
         [_ #f])))

(define (root-arrow-holds? frontier)
  (with-handlers ([exn:fail? (lambda (_exception) #f)])
    (compressed-arrow-holds? (initial-b frontier))))

(define-runtime-path compressed-module "../compressed.rkt")

(define compression-tests
  (test-suite
   "whole-tree Redex column: canonical marked compression"

   (test-case
    "the compressed grammar has four running modes, one final mode, and nonempty spans"
    (for ([state
           (in-list
            (list
             (term
              (BRun (Work (succeed (label "ok")) (state unit))
                    (More hole)))
             (term (BSettled (Returned (state unit)) (More hole)))
             (term (BDead (More hole)))
             (term
              (BDelay (Work (succeed (label "ok")) (state unit))
                      (More hole)))
             (term (BFinal Done hole))))])
      (check-true (redex-match? redex-column-compressed-lang B state)))
    (check-false
     (redex-match? redex-column-compressed-lang Span '(transition-span)))
    (check-true
     (redex-match?
      redex-column-compressed-lang
      Span
      '(transition-span (work-succeed core))))
    ;; The running payload is indexed by the unfinished-work subset.  A
    ;; settled choice belongs in BSettled and is not an alternate raw BRun
    ;; representation of the same reachable phase.
    (define settled-choice
      '(DisjL
        (Returned (state unit))
        (Work (succeed (label "later")) (state unit))))
    (check-false
     (redex-match?
      redex-column-compressed-lang
      B
      `(BRun ,settled-choice ,(term (More hole)))))
    (check-true
     (redex-match?
      redex-column-compressed-lang
      B
      `(BSettled ,settled-choice ,(term (More hole))))))

   (test-case
    "every reachable direct edge is exactly the compositional corridor specification"
    (for ([frontier (in-list witness-trees)])
      (define-values (_spans states) (trace-for frontier))
      (check-equal? (decode-b (first states)) (initial-m frontier))
      (for ([compressed (in-list states)])
        (define direct* (b-successors compressed))
        (define spec* (b-spec-successors compressed))
        (check-equal? (mapped-direct-successors compressed)
                      spec*
                      (format "~e" compressed))
        (match direct*
          ['()
           (check-match compressed `(BFinal ,_ ,_))
           (check-equal? (m-successors (decode-b compressed)) '())]
          [(list (list span next))
           (define decoded (decode-b compressed))
           (define decoded-next (decode-b next))
           (check-equal?
            (judgment-holds
             (replay-span/exact ,decoded ,span M_1)
             M_1)
            (list decoded-next))
           (check-equal?
            (length
             (build-derivations
              (compressed-step/direct ,compressed Span B_1)))
            1)
           (check-equal?
            (judgment-holds
             (compression-step-square
              ,compressed Span B_1 M_0 M_1)
             (Span B_1 M_0 M_1))
            (list (list span next decoded decoded-next)))]
          [_ (fail-check (format "multiple direct edges from ~e" compressed))]))))

   (test-case
    "macro spans literally partition the exact marked-machine trace"
    (for ([frontier (in-list witness-trees)])
      (define-values (spans compressed-states) (trace-for frontier))
      (define-values (labels machine-states) (trace-m (initial-m frontier)))
      (check-equal? (append-map span-labels spans) labels)
      (check-equal? (decode-b (last compressed-states))
                    (last machine-states))
      (check-equal?
       (term (compressed-readback ,(last compressed-states)))
       (term (readback-M ,(last machine-states))))))

   (test-case
    "the four source witnesses retain the derived canonical partitions"
    (define-values (nested _) (trace-for corpus:nested-scope-witness-tree))
    (define-values (rail __) (trace-for corpus:rail-turn-witness-tree))
    (define-values (late ___) (trace-for corpus:late-hoist-witness-tree))
    (define-values (right ____) (trace-for corpus:right-active-fresh-witness-tree))
    (check-equal? nested nested-partition)
    (check-equal? rail rail-partition)
    (check-equal? late late-partition)
    (check-equal? right right-partition))

   (test-case
    "all 28 exact rule/owner marks remain first-class certificate data"
    (define observed
      (remove-duplicates
       (append*
        (for/list ([frontier (in-list witness-trees)])
          (define-values (spans _states) (trace-for frontier))
          (append-map span-labels spans)))))
    (check-equal? (length observed) 28)
    (for ([expected (in-list expected-labels)])
      (check-not-false (member expected observed) (format "~e" expected))))

   (test-case
    "reachability carries the exact prefix certificate and rejects malformed roots"
    (for ([frontier (in-list witness-trees)])
      (define-values (spans states) (trace-for frontier))
      (for ([compressed (in-list states)]
            [count (in-naturals)])
        (define prefix (take spans count))
        (define machine (decode-b compressed))
        (check-not-false
         (member
          (list prefix compressed)
          (judgment-holds
           (reachable-compressed/via ,frontier Spans B)
           (Spans B))))
        (check-not-false
         (member
          (list prefix compressed machine)
          (judgment-holds
           (reachable-compression-correspondence
            ,frontier Spans B M)
           (Spans B M))))))
    (define malformed
      '(More
        (Work
         (fresh (x:q x:q)
                (succeed (label "body"))
                (label "duplicate"))
         (state unit))))
    (check-false (judgment-holds (wf-frontier/toy ,malformed)))
    (check-equal?
     (judgment-holds (reachable-compressed/via ,malformed Spans B) (Spans B))
     '()))

   (test-case
    "bounded generated well-formed roots preserve and reflect every macro edge"
    (redex-check
     redex-column-compressed-lang
     F
     (or (not (judgment-holds (wf-frontier/toy F)))
         (root-arrow-holds? (term F)))
     #:attempts 500)
    (redex-check
     redex-column-compressed-lang
     B
     (<= (length
          (build-derivations
           (compressed-step/direct B Span B_1)))
         1)
     #:attempts 1000)
    (redex-check
     redex-column-compressed-lang
     BQ
     (<= (length
          (build-derivations
           (symbolic-path/direct BQ Path)))
         1)
     #:attempts 1000))

   (test-case
    "the direct artifact contains no exact-step replay or host control dispatcher"
    (define module-text (file->string compressed-module))
    (check-false (regexp-match? #rx"source[.]rkt\"" module-text))
    (check-false
     (regexp-match?
      #rx"[(](source-step|machine-step|replay-span|contract|refocus-direct)"
      module-text))
    (check-false (regexp-match? #rx"[(](match|cond|if|for/)" module-text)))))

(module+ test
  (run-tests compression-tests))
