#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in production:
                    "../../../../src/search-lattice/reduction-relations/core-red.rkt")
         (prefix-in concrete-d:
                    "../../whole-tree-redex-column/decomposition.rkt")
         (prefix-in concrete-s:
                    "../../whole-tree-redex-column/source.rkt")
         (prefix-in kernel-corpus: "../corpus/kernel-cases.rkt")
         (prefix-in corpus: "../corpus/scenarios.rkt")
         (prefix-in mk-k:
                    "../reference/marked/mk/kernel.rkt")
         (prefix-in toy-d:
                    "../reference/marked/toy/decomposition.rkt")
         (prefix-in toy-l:
                    "../reference/marked/toy/labels.rkt")
         (prefix-in toy-lang:
                    "../reference/marked/toy/language.rkt")
         (prefix-in toy-s:
                    "../reference/marked/toy/source.rkt")
         (prefix-in toy-wf:
                    "../reference/marked/toy/wf.rkt"))

(provide temporary-oracle-parity-tests)

;; These tests deliberately retain the temporary dependencies that the
;; intrinsic P[K] suite rejects.  They compare the canonical parameterized
;; column with the frozen concrete oracle and the production kernel until the
;; consolidation checkpoints make those comparisons obsolete.

(define witness-trees
  (list
   (term
    (toy-s:initial-tree/toy
     ,corpus:nested-scope-witness-goal))
   (term
    (toy-s:initial-tree/toy
     ,corpus:late-hoist-witness-goal))
   (term
    (toy-s:initial-tree/toy
     ,corpus:rail-turn-witness-goal))
   (term
    (toy-s:initial-tree/toy
     ,corpus:right-active-fresh-witness-goal))))

(define (concrete-source-successors frontier)
  (for/list
      ([named
        (in-list
         (apply-reduction-relation/tag-with-names
          concrete-s:source-red
          frontier))])
    (match-define (list name next) named)
    (list (term (concrete-s:redex-name->label ,(~a name))) next)))

(define (toy-source-successors frontier)
  (for/list
      ([named
        (in-list
         (apply-reduction-relation/tag-with-names
          toy-s:source-red/toy
          frontier))])
    (match-define (list name next) named)
    (list
     (term
      (toy-l:label->legacy/toy
       (toy-l:redex-name->label/toy ,(~a name))))
     next)))

(define (toy-decompositions frontier)
  (judgment-holds (toy-d:decompose/toy ,frontier D) D))

(define (concrete-decompositions frontier)
  (judgment-holds (concrete-d:decompose/redex ,frontier D) D))

(define (toy-label->concrete label)
  (term (toy-l:label->legacy/toy ,label)))

(define (translate-toy-contract contractum)
  (match contractum
    [`(ContractWork ,label ,work ,context)
     `(ContractWork ,(toy-label->concrete label) ,work ,context)]
    [`(ContractFrontier ,label ,frontier ,context)
     `(ContractFrontier
       ,(toy-label->concrete label)
       ,frontier
       ,context)]))

(define (toy-contractions decomposition)
  (for/list
      ([contractum
        (in-list
         (judgment-holds
          (toy-d:contract/toy ,decomposition C)
          C))])
    (translate-toy-contract contractum)))

(define (concrete-contractions decomposition)
  (judgment-holds
   (concrete-d:contract/redex ,decomposition C)
   C))

(define (toy-spec-successors decomposition)
  (for/list
      ([successor
        (in-list
         (judgment-holds
          (toy-d:decomposed-step/spec/toy
           ,decomposition
           ell
           D_next)
          (ell D_next)))])
    (match-define (list label next) successor)
    (list (toy-label->concrete label) next)))

(define (toy-direct-successors decomposition)
  (for/list
      ([named
        (in-list
         (apply-reduction-relation/tag-with-names
          toy-d:decomposed-red/direct/toy
          decomposition))])
    (match-define (list name next) named)
    (list
     (toy-label->concrete
      (term (toy-l:redex-name->label/toy ,(~a name))))
     next)))

(define (toy-trace-states initial [limit 256] [states (list initial)])
  (match (toy-source-successors initial)
    ['() (reverse states)]
    [(list (list _label next))
     (unless (positive? limit)
       (error 'toy-trace-states "step cap reached"))
     (toy-trace-states next (sub1 limit) (cons next states))]
    [other
     (error 'toy-trace-states "nondeterministic source: ~e" other)]))

(define all-toy-trace-states
  (remove-duplicates
   (append*
    (for/list ([initial (in-list witness-trees)])
      (toy-trace-states initial)))))

(define (mk-kernel-results atomic state)
  (judgment-holds
   (mk-k:kernel-step/mk ,atomic ,state kresult kell)
   (kresult kell)))

(define (restore-production-scope state ambient)
  (match state
    [`(state ,sub ,dis ,trail ,tag)
     `(state ,sub ,dis ,ambient ,trail ,tag)]))

(define (production-kernel-results atomic state ambient)
  (for/list
      ([named
        (in-list
         (apply-reduction-relation/tag-with-names
          production:local/base
          `(,atomic ,(restore-production-scope state ambient))))])
    (match-define (list name result) named)
    (list
     (match result
       [`(⊤ (state ,sub ,dis ,_cached-c ,trail ,tag))
        `(KernelSuccess (state ,sub ,dis ,trail ,tag))]
       ['(empty-tree) 'KernelFailure])
     `(kernel ,(string->symbol (~a name)) core))))

(define temporary-oracle-parity-tests
  (test-suite
   "temporary whole-tree oracle parity"

   (test-case
    "toy labels explicitly translate to the committed 28-label family"
    (define concrete-names
      '("expose-frontier-fresh/core"
        "finish-success/core"
        "finish-failure/core"
        "force-delay/delay"
        "commit-choice-answer/disj"
        "commit-right-choice-answer/search-join"
        "work-succeed/core"
        "work-fail/core"
        "work-put/core"
        "allocate-fresh/core"
        "expand-conjunction/core"
        "expand-disjunction/disj"
        "suspend-goal/delay"
        "expose-choice-through-work-fresh/disj"
        "expose-choice-through-work-fresh/search-join"
        "erase-dead-fresh/core"
        "bubble-delay-through-fresh/delay"
        "conj-return/core"
        "conj-fail/core"
        "bubble-delay-through-conj/delay"
        "late-distribute-settled/disj"
        "late-distribute-right-settled/search-join"
        "skip-left-failure/disj"
        "rail-enter-right/search-join"
        "reassociate-left-result/disj"
        "skip-right-failure/search-join"
        "rail-return-left/search-join"
        "reassociate-right-result/search-join"))
    (check-equal? (length concrete-names) 28)
    (for ([name (in-list concrete-names)])
      (define pk-label
        (term (toy-l:redex-name->label/toy ,name)))
      (define concrete-label
        (term (concrete-s:redex-name->label ,name)))
      (check-true (toy-lang:label-in-language?/toy pk-label))
      (check-equal?
       (term (toy-l:label->redex-name/toy ,pk-label))
       name)
      (check-equal?
       (toy-label->concrete pk-label)
       concrete-label)
      (check-equal?
       (term (toy-l:legacy->label/toy ,concrete-label))
       pk-label)))

   (test-case
    "P[Ktoy] source exactly preserves the committed oracle"
    (for ([initial (in-list witness-trees)])
      (let compare-trace ([frontier initial] [remaining 256])
        (check-true
         (judgment-holds (toy-wf:wf-frontier/toy ,frontier)))
        (check-equal?
         (toy-source-successors frontier)
         (concrete-source-successors frontier)
         (format "~e" frontier))
        (match (toy-source-successors frontier)
          ['() (void)]
          [(list (list _label next))
           (check-true (positive? remaining))
           (compare-trace next (sub1 remaining))]))))

   (test-case
    "P[Ktoy] decomposition and both D presentations preserve the oracle"
    (for ([frontier (in-list all-toy-trace-states)])
      (define toy-D* (toy-decompositions frontier))
      (define concrete-D* (concrete-decompositions frontier))
      (check-equal? toy-D* concrete-D* (format "~e" frontier))
      (check-equal? (length toy-D*) 1)
      (define decomposition (first toy-D*))
      (check-equal?
       (toy-contractions decomposition)
       (concrete-contractions decomposition)
       (format "~e" frontier))
      (check-equal?
       (toy-direct-successors decomposition)
       (toy-spec-successors decomposition)
       (format "~e" frontier))))

   (test-case
    "Kmk atomic judgments agree with the production kernel"
    (for ([case (in-list kernel-corpus:mk-kernel-cases)])
      (match-define (list atomic state ambient _expected-label) case)
      (check-equal?
       (mk-kernel-results atomic state)
       (production-kernel-results atomic state ambient))))))

(module+ test
  (run-tests temporary-oracle-parity-tests))
