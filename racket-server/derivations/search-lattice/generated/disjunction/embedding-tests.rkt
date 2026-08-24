#lang racket

(require racket/list
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in core-source-s: "../core/source/s.rkt")
         (prefix-in core-source-e: "../core/source/e.rkt")
         (prefix-in core-source-n: "../core/source/n.rkt")
         (prefix-in disjunction-source-s: "source/s.rkt")
         (prefix-in disjunction-source-e: "source/e.rkt")
         (prefix-in disjunction-source-n: "source/n.rkt")
         (prefix-in core-stage-s: "../core/stages/s.rkt")
         (prefix-in core-stage-e: "../core/stages/e.rkt")
         (prefix-in core-stage-n: "../core/stages/n.rkt")
         (prefix-in disjunction-stage-s: "stages/s.rkt")
         (prefix-in disjunction-stage-e: "stages/e.rkt")
         (prefix-in disjunction-stage-n: "stages/n.rkt")
         (prefix-in core-corpus: "../core/stages/corpus.rkt")
         "corpus.rkt")

(provide GENERATED-DISJUNCTION-EMBEDDING-TESTS)

(define (canonical-top-level-proof-multiset proofs)
  (sort
   (for/list ([proof (in-list proofs)])
     (match (derivation-term proof)
       [(cons _judgment arguments) (cons 'judgment arguments)]))
   string<?
   #:key ~s))

(define (outputs proofs count)
  (for/list ([proof (in-list proofs)])
    (define values (take-right (derivation-term proof) count))
    (if (= count 1) (first values) values)))

(define (only who values)
  (match values
    [(list value) value]
    [_ (error who "expected one raw proof, received ~e" values)]))

(struct embedding-row
  (name
   core-corpus
   disjunction-corpus
   core-raw
   disjunction-raw
   J-R
   core-decompose
   disjunction-decompose
   J-D
   core-D-step
   disjunction-D-step
   core-refocus
   disjunction-refocus
   J-Z
   core-Z-step
   disjunction-Z-step
   core-machineize
   disjunction-machineize
   J-M
   core-M-step
   disjunction-M-step
   core-compress
   disjunction-compress
   J-B
   core-B-step
   disjunction-B-step
   core-promote
   disjunction-promote
   J-Big)
  #:transparent)

(define-syntax-rule
  (define-embedding-row
    row-id row-name core-corpus-id disjunction-corpus-id
    core-raw-id disjunction-raw-id J-R-id
    core-decompose-id disjunction-decompose-id J-D-id
    core-D-step-id disjunction-D-step-id
    core-refocus-id disjunction-refocus-id J-Z-id
    core-Z-step-id disjunction-Z-step-id
    core-machineize-id disjunction-machineize-id J-M-id
    core-M-step-id disjunction-M-step-id
    core-compress-id disjunction-compress-id J-B-id
    core-B-step-id disjunction-B-step-id
    core-promote-id disjunction-promote-id J-Big-id)
  (define row-id
    (embedding-row
     row-name core-corpus-id disjunction-corpus-id
     core-raw-id disjunction-raw-id J-R-id
     (lambda (source) (build-derivations (core-decompose-id ,source D)))
     (lambda (source) (build-derivations (disjunction-decompose-id ,source D)))
     J-D-id
     (lambda (D) (build-derivations (core-D-step-id ,D RuleName D_next)))
     (lambda (D) (build-derivations (disjunction-D-step-id ,D RuleName D_next)))
     (lambda (D) (term (core-refocus-id ,D)))
     (lambda (D) (term (disjunction-refocus-id ,D)))
     J-Z-id
     (lambda (Z) (build-derivations (core-Z-step-id ,Z RuleName Z_next)))
     (lambda (Z) (build-derivations (disjunction-Z-step-id ,Z RuleName Z_next)))
     (lambda (Z) (term (core-machineize-id ,Z)))
     (lambda (Z) (term (disjunction-machineize-id ,Z)))
     J-M-id
     (lambda (M) (build-derivations (core-M-step-id ,M RuleName M_next)))
     (lambda (M) (build-derivations (disjunction-M-step-id ,M RuleName M_next)))
     (lambda (M) (term (core-compress-id ,M)))
     (lambda (M) (term (disjunction-compress-id ,M)))
     J-B-id
     (lambda (B) (build-derivations (core-B-step-id ,B TransitionSpan B_next)))
     (lambda (B) (build-derivations (disjunction-B-step-id ,B TransitionSpan B_next)))
     (lambda (B) (build-derivations (core-promote-id ,B Big)))
     (lambda (B) (build-derivations (disjunction-promote-id ,B Big)))
     J-Big-id)))

(define-embedding-row
  ROW/S 'S core-corpus:CORE-CORPUS/S DISJUNCTION-CORPUS/S
  core-source-s:raw-successors/generated/s
  disjunction-source-s:raw-successors/generated/disjunction/s
  disjunction-source-s:J-core->disjunction/R/S
  core-stage-s:generated-stage-decompose/s
  disjunction-stage-s:disjunction/stage-extension/S/D-decompose
  disjunction-stage-s:J-core->disjunction/D/S
  core-stage-s:generated-stage-decomposed-step/s
  disjunction-stage-s:disjunction/stage-extension/S/D-step
  core-stage-s:generated-stage-refocus-phase/s
  disjunction-stage-s:disjunction/stage-extension/S/Z-refocus-phase
  disjunction-stage-s:J-core->disjunction/Z/S
  core-stage-s:generated-stage-refocused-step/direct/s
  disjunction-stage-s:disjunction/stage-extension/S/Z-step
  core-stage-s:generated-stage-machineize/s
  disjunction-stage-s:disjunction/stage-extension/S/M-machineize
  disjunction-stage-s:J-core->disjunction/M/S
  core-stage-s:generated-stage-machine-step/direct/s
  disjunction-stage-s:disjunction/stage-extension/S/M-step
  core-stage-s:generated-stage-compress/s
  disjunction-stage-s:disjunction/stage-extension/S/B-compress
  disjunction-stage-s:J-core->disjunction/B/S
  core-stage-s:generated-stage-compressed-step/direct/s
  disjunction-stage-s:disjunction/stage-extension/S/B-step
  core-stage-s:generated-stage-promote-B/direct/s
  disjunction-stage-s:disjunction/stage-extension/S/Big-promote
  disjunction-stage-s:J-core->disjunction/Big/S)

(define-embedding-row
  ROW/E 'E core-corpus:CORE-CORPUS/E DISJUNCTION-CORPUS/E
  core-source-e:raw-successors/generated/e
  disjunction-source-e:raw-successors/generated/disjunction/e
  disjunction-source-e:J-core->disjunction/R/E
  core-stage-e:generated-stage-decompose/e
  disjunction-stage-e:disjunction/stage-extension/E/D-decompose
  disjunction-stage-e:J-core->disjunction/D/E
  core-stage-e:generated-stage-decomposed-step/e
  disjunction-stage-e:disjunction/stage-extension/E/D-step
  core-stage-e:generated-stage-refocus-phase/e
  disjunction-stage-e:disjunction/stage-extension/E/Z-refocus-phase
  disjunction-stage-e:J-core->disjunction/Z/E
  core-stage-e:generated-stage-refocused-step/direct/e
  disjunction-stage-e:disjunction/stage-extension/E/Z-step
  core-stage-e:generated-stage-machineize/e
  disjunction-stage-e:disjunction/stage-extension/E/M-machineize
  disjunction-stage-e:J-core->disjunction/M/E
  core-stage-e:generated-stage-machine-step/direct/e
  disjunction-stage-e:disjunction/stage-extension/E/M-step
  core-stage-e:generated-stage-compress/e
  disjunction-stage-e:disjunction/stage-extension/E/B-compress
  disjunction-stage-e:J-core->disjunction/B/E
  core-stage-e:generated-stage-compressed-step/direct/e
  disjunction-stage-e:disjunction/stage-extension/E/B-step
  core-stage-e:generated-stage-promote-B/direct/e
  disjunction-stage-e:disjunction/stage-extension/E/Big-promote
  disjunction-stage-e:J-core->disjunction/Big/E)

(define-embedding-row
  ROW/N 'N core-corpus:CORE-CORPUS/N DISJUNCTION-CORPUS/N
  core-source-n:raw-successors/generated/n
  disjunction-source-n:raw-successors/generated/disjunction/n
  disjunction-source-n:J-core->disjunction/R/N
  core-stage-n:generated-stage-decompose/n
  disjunction-stage-n:disjunction/stage-extension/N/D-decompose
  disjunction-stage-n:J-core->disjunction/D/N
  core-stage-n:generated-stage-decomposed-step/n
  disjunction-stage-n:disjunction/stage-extension/N/D-step
  core-stage-n:generated-stage-refocus-phase/n
  disjunction-stage-n:disjunction/stage-extension/N/Z-refocus-phase
  disjunction-stage-n:J-core->disjunction/Z/N
  core-stage-n:generated-stage-refocused-step/direct/n
  disjunction-stage-n:disjunction/stage-extension/N/Z-step
  core-stage-n:generated-stage-machineize/n
  disjunction-stage-n:disjunction/stage-extension/N/M-machineize
  disjunction-stage-n:J-core->disjunction/M/N
  core-stage-n:generated-stage-machine-step/direct/n
  disjunction-stage-n:disjunction/stage-extension/N/M-step
  core-stage-n:generated-stage-compress/n
  disjunction-stage-n:disjunction/stage-extension/N/B-compress
  disjunction-stage-n:J-core->disjunction/B/N
  core-stage-n:generated-stage-compressed-step/direct/n
  disjunction-stage-n:disjunction/stage-extension/N/B-step
  core-stage-n:generated-stage-promote-B/direct/n
  disjunction-stage-n:disjunction/stage-extension/N/Big-promote
  disjunction-stage-n:J-core->disjunction/Big/N)

(define ROWS (list ROW/S ROW/E ROW/N))

(define (check-proof-multiset who core-proofs disjunction-proofs)
  (check-equal? (length core-proofs) (length disjunction-proofs)
                (~a who " multiplicity"))
  (check-equal? (canonical-top-level-proof-multiset core-proofs)
                (canonical-top-level-proof-multiset disjunction-proofs)
                (~a who " top-level proofs")))

(define (check-feature-chain row source)
  (check-equal? ((embedding-row-J-R row) source) source)
  (check-equal?
   (canonical-multiset ((embedding-row-core-raw row) source))
   (canonical-multiset ((embedding-row-disjunction-raw row) source)))

  (define core-D-proofs ((embedding-row-core-decompose row) source))
  (define disjunction-D-proofs
    ((embedding-row-disjunction-decompose row) ((embedding-row-J-R row) source)))
  (check-proof-multiset 'feature/decompose core-D-proofs disjunction-D-proofs)
  (define core-D (only 'core-D (outputs core-D-proofs 1)))
  (define disjunction-D (only 'disjunction-D (outputs disjunction-D-proofs 1)))
  (check-equal? ((embedding-row-J-D row) core-D) disjunction-D)
  (check-proof-multiset
   'feature/D-step
   ((embedding-row-core-D-step row) core-D)
   ((embedding-row-disjunction-D-step row) disjunction-D))

  (define core-Z ((embedding-row-core-refocus row) core-D))
  (define disjunction-Z ((embedding-row-disjunction-refocus row) disjunction-D))
  (check-equal? ((embedding-row-J-Z row) core-Z) disjunction-Z)
  (check-proof-multiset
   'feature/Z-step
   ((embedding-row-core-Z-step row) core-Z)
   ((embedding-row-disjunction-Z-step row) disjunction-Z))

  (define core-M ((embedding-row-core-machineize row) core-Z))
  (define disjunction-M ((embedding-row-disjunction-machineize row) disjunction-Z))
  (check-equal? ((embedding-row-J-M row) core-M) disjunction-M)
  (check-proof-multiset
   'feature/M-step
   ((embedding-row-core-M-step row) core-M)
   ((embedding-row-disjunction-M-step row) disjunction-M))

  (define core-B ((embedding-row-core-compress row) core-M))
  (define disjunction-B ((embedding-row-disjunction-compress row) disjunction-M))
  (check-equal? ((embedding-row-J-B row) core-B) disjunction-B)
  (check-proof-multiset
   'feature/B-step
   ((embedding-row-core-B-step row) core-B)
   ((embedding-row-disjunction-B-step row) disjunction-B))

  (define core-Big-proofs ((embedding-row-core-promote row) core-B))
  (define disjunction-Big-proofs ((embedding-row-disjunction-promote row) disjunction-B))
  (check-proof-multiset 'feature/Big core-Big-proofs disjunction-Big-proofs)
  (for ([core-Big (in-list (outputs core-Big-proofs 1))]
        [disjunction-Big (in-list (outputs disjunction-Big-proofs 1))])
    (check-equal? ((embedding-row-J-Big row) core-Big) disjunction-Big)))

(define (canonical-multiset values)
  (sort values string<? #:key ~s))

(define GENERATED-DISJUNCTION-EMBEDDING-TESTS
  (test-suite
   "separately staged Core-to-Disjunction feature embeddings"

   (test-case "all thirteen inherited rules commute through every phase"
     (for ([row (in-list ROWS)])
       (for ([rule-name (in-list core-corpus:CORE-RULE-NAMES)])
         (define source
           (core-corpus:row-source-ref
            (embedding-row-core-corpus row)
            rule-name))
         (check-equal?
          source
          (disjunction-row-source-ref
           (embedding-row-disjunction-corpus row)
           rule-name))
         (check-feature-chain row source))))

   (test-case "core embeddings reject Disjunction-only coordinates"
     (for ([row (in-list ROWS)])
       (define disjunction-source
         (disjunction-rule-case-source
          (first
           (disjunction-row-corpus-owned-rule-cases
            (embedding-row-disjunction-corpus row)))))
       (check-exn exn:fail:contract?
                  (lambda () ((embedding-row-J-R row) disjunction-source)))
       (define disjunction-D
         (only 'disjunction-only-D
               (outputs
                ((embedding-row-disjunction-decompose row) disjunction-source)
                1)))
       (check-exn exn:fail:contract?
                  (lambda () ((embedding-row-J-D row) disjunction-D)))))))

(module+ test
  (run-tests GENERATED-DISJUNCTION-EMBEDDING-TESTS))
