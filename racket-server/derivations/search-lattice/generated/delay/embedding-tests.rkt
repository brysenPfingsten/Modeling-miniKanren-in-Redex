#lang racket

(require racket/list
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in core-source-s: "../core/source/s.rkt")
         (prefix-in core-source-e: "../core/source/e.rkt")
         (prefix-in core-source-n: "../core/source/n.rkt")
         (prefix-in delay-source-s: "source/s.rkt")
         (prefix-in delay-source-e: "source/e.rkt")
         (prefix-in delay-source-n: "source/n.rkt")
         (prefix-in core-stage-s: "../core/stages/s.rkt")
         (prefix-in core-stage-e: "../core/stages/e.rkt")
         (prefix-in core-stage-n: "../core/stages/n.rkt")
         (prefix-in delay-stage-s: "stages/s.rkt")
         (prefix-in delay-stage-e: "stages/e.rkt")
         (prefix-in delay-stage-n: "stages/n.rkt")
         (prefix-in core-corpus: "../core/stages/corpus.rkt")
         "corpus.rkt")

(provide GENERATED-DELAY-EMBEDDING-TESTS)

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
   delay-corpus
   core-raw
   delay-raw
   J-R
   core-decompose
   delay-decompose
   J-D
   core-D-step
   delay-D-step
   core-refocus
   delay-refocus
   J-Z
   core-Z-step
   delay-Z-step
   core-machineize
   delay-machineize
   J-M
   core-M-step
   delay-M-step
   core-compress
   delay-compress
   J-B
   core-B-step
   delay-B-step
   core-promote
   delay-promote
   J-Big)
  #:transparent)

(define-syntax-rule
  (define-embedding-row
    row-id row-name core-corpus-id delay-corpus-id
    core-raw-id delay-raw-id J-R-id
    core-decompose-id delay-decompose-id J-D-id
    core-D-step-id delay-D-step-id
    core-refocus-id delay-refocus-id J-Z-id
    core-Z-step-id delay-Z-step-id
    core-machineize-id delay-machineize-id J-M-id
    core-M-step-id delay-M-step-id
    core-compress-id delay-compress-id J-B-id
    core-B-step-id delay-B-step-id
    core-promote-id delay-promote-id J-Big-id)
  (define row-id
    (embedding-row
     row-name core-corpus-id delay-corpus-id
     core-raw-id delay-raw-id J-R-id
     (lambda (source) (build-derivations (core-decompose-id ,source D)))
     (lambda (source) (build-derivations (delay-decompose-id ,source D)))
     J-D-id
     (lambda (D) (build-derivations (core-D-step-id ,D RuleName D_next)))
     (lambda (D) (build-derivations (delay-D-step-id ,D RuleName D_next)))
     (lambda (D) (term (core-refocus-id ,D)))
     (lambda (D) (term (delay-refocus-id ,D)))
     J-Z-id
     (lambda (Z) (build-derivations (core-Z-step-id ,Z RuleName Z_next)))
     (lambda (Z) (build-derivations (delay-Z-step-id ,Z RuleName Z_next)))
     (lambda (Z) (term (core-machineize-id ,Z)))
     (lambda (Z) (term (delay-machineize-id ,Z)))
     J-M-id
     (lambda (M) (build-derivations (core-M-step-id ,M RuleName M_next)))
     (lambda (M) (build-derivations (delay-M-step-id ,M RuleName M_next)))
     (lambda (M) (term (core-compress-id ,M)))
     (lambda (M) (term (delay-compress-id ,M)))
     J-B-id
     (lambda (B) (build-derivations (core-B-step-id ,B TransitionSpan B_next)))
     (lambda (B) (build-derivations (delay-B-step-id ,B TransitionSpan B_next)))
     (lambda (B) (build-derivations (core-promote-id ,B Big)))
     (lambda (B) (build-derivations (delay-promote-id ,B Big)))
     J-Big-id)))

(define-embedding-row
  ROW/S 'S core-corpus:CORE-CORPUS/S DELAY-CORPUS/S
  core-source-s:raw-successors/generated/s
  delay-source-s:raw-successors/generated/delay/s
  delay-source-s:J-core->delay/R/S
  core-stage-s:generated-stage-decompose/s
  delay-stage-s:delay/stage-extension/S/D-decompose
  delay-stage-s:J-core->delay/D/S
  core-stage-s:generated-stage-decomposed-step/s
  delay-stage-s:delay/stage-extension/S/D-step
  core-stage-s:generated-stage-refocus-phase/s
  delay-stage-s:delay/stage-extension/S/Z-refocus-phase
  delay-stage-s:J-core->delay/Z/S
  core-stage-s:generated-stage-refocused-step/direct/s
  delay-stage-s:delay/stage-extension/S/Z-step
  core-stage-s:generated-stage-machineize/s
  delay-stage-s:delay/stage-extension/S/M-machineize
  delay-stage-s:J-core->delay/M/S
  core-stage-s:generated-stage-machine-step/direct/s
  delay-stage-s:delay/stage-extension/S/M-step
  core-stage-s:generated-stage-compress/s
  delay-stage-s:delay/stage-extension/S/B-compress
  delay-stage-s:J-core->delay/B/S
  core-stage-s:generated-stage-compressed-step/direct/s
  delay-stage-s:delay/stage-extension/S/B-step
  core-stage-s:generated-stage-promote-B/direct/s
  delay-stage-s:delay/stage-extension/S/Big-promote
  delay-stage-s:J-core->delay/Big/S)

(define-embedding-row
  ROW/E 'E core-corpus:CORE-CORPUS/E DELAY-CORPUS/E
  core-source-e:raw-successors/generated/e
  delay-source-e:raw-successors/generated/delay/e
  delay-source-e:J-core->delay/R/E
  core-stage-e:generated-stage-decompose/e
  delay-stage-e:delay/stage-extension/E/D-decompose
  delay-stage-e:J-core->delay/D/E
  core-stage-e:generated-stage-decomposed-step/e
  delay-stage-e:delay/stage-extension/E/D-step
  core-stage-e:generated-stage-refocus-phase/e
  delay-stage-e:delay/stage-extension/E/Z-refocus-phase
  delay-stage-e:J-core->delay/Z/E
  core-stage-e:generated-stage-refocused-step/direct/e
  delay-stage-e:delay/stage-extension/E/Z-step
  core-stage-e:generated-stage-machineize/e
  delay-stage-e:delay/stage-extension/E/M-machineize
  delay-stage-e:J-core->delay/M/E
  core-stage-e:generated-stage-machine-step/direct/e
  delay-stage-e:delay/stage-extension/E/M-step
  core-stage-e:generated-stage-compress/e
  delay-stage-e:delay/stage-extension/E/B-compress
  delay-stage-e:J-core->delay/B/E
  core-stage-e:generated-stage-compressed-step/direct/e
  delay-stage-e:delay/stage-extension/E/B-step
  core-stage-e:generated-stage-promote-B/direct/e
  delay-stage-e:delay/stage-extension/E/Big-promote
  delay-stage-e:J-core->delay/Big/E)

(define-embedding-row
  ROW/N 'N core-corpus:CORE-CORPUS/N DELAY-CORPUS/N
  core-source-n:raw-successors/generated/n
  delay-source-n:raw-successors/generated/delay/n
  delay-source-n:J-core->delay/R/N
  core-stage-n:generated-stage-decompose/n
  delay-stage-n:delay/stage-extension/N/D-decompose
  delay-stage-n:J-core->delay/D/N
  core-stage-n:generated-stage-decomposed-step/n
  delay-stage-n:delay/stage-extension/N/D-step
  core-stage-n:generated-stage-refocus-phase/n
  delay-stage-n:delay/stage-extension/N/Z-refocus-phase
  delay-stage-n:J-core->delay/Z/N
  core-stage-n:generated-stage-refocused-step/direct/n
  delay-stage-n:delay/stage-extension/N/Z-step
  core-stage-n:generated-stage-machineize/n
  delay-stage-n:delay/stage-extension/N/M-machineize
  delay-stage-n:J-core->delay/M/N
  core-stage-n:generated-stage-machine-step/direct/n
  delay-stage-n:delay/stage-extension/N/M-step
  core-stage-n:generated-stage-compress/n
  delay-stage-n:delay/stage-extension/N/B-compress
  delay-stage-n:J-core->delay/B/N
  core-stage-n:generated-stage-compressed-step/direct/n
  delay-stage-n:delay/stage-extension/N/B-step
  core-stage-n:generated-stage-promote-B/direct/n
  delay-stage-n:delay/stage-extension/N/Big-promote
  delay-stage-n:J-core->delay/Big/N)

(define ROWS (list ROW/S ROW/E ROW/N))

(define (check-proof-multiset who core-proofs delay-proofs)
  (check-equal? (length core-proofs) (length delay-proofs)
                (~a who " multiplicity"))
  (check-equal? (canonical-top-level-proof-multiset core-proofs)
                (canonical-top-level-proof-multiset delay-proofs)
                (~a who " top-level proofs")))

(define (check-feature-chain row source)
  (check-equal? ((embedding-row-J-R row) source) source)
  (check-equal?
   (canonical-multiset ((embedding-row-core-raw row) source))
   (canonical-multiset ((embedding-row-delay-raw row) source)))

  (define core-D-proofs ((embedding-row-core-decompose row) source))
  (define delay-D-proofs
    ((embedding-row-delay-decompose row) ((embedding-row-J-R row) source)))
  (check-proof-multiset 'feature/decompose core-D-proofs delay-D-proofs)
  (define core-D (only 'core-D (outputs core-D-proofs 1)))
  (define delay-D (only 'delay-D (outputs delay-D-proofs 1)))
  (check-equal? ((embedding-row-J-D row) core-D) delay-D)
  (check-proof-multiset
   'feature/D-step
   ((embedding-row-core-D-step row) core-D)
   ((embedding-row-delay-D-step row) delay-D))

  (define core-Z ((embedding-row-core-refocus row) core-D))
  (define delay-Z ((embedding-row-delay-refocus row) delay-D))
  (check-equal? ((embedding-row-J-Z row) core-Z) delay-Z)
  (check-proof-multiset
   'feature/Z-step
   ((embedding-row-core-Z-step row) core-Z)
   ((embedding-row-delay-Z-step row) delay-Z))

  (define core-M ((embedding-row-core-machineize row) core-Z))
  (define delay-M ((embedding-row-delay-machineize row) delay-Z))
  (check-equal? ((embedding-row-J-M row) core-M) delay-M)
  (check-proof-multiset
   'feature/M-step
   ((embedding-row-core-M-step row) core-M)
   ((embedding-row-delay-M-step row) delay-M))

  (define core-B ((embedding-row-core-compress row) core-M))
  (define delay-B ((embedding-row-delay-compress row) delay-M))
  (check-equal? ((embedding-row-J-B row) core-B) delay-B)
  (check-proof-multiset
   'feature/B-step
   ((embedding-row-core-B-step row) core-B)
   ((embedding-row-delay-B-step row) delay-B))

  (define core-Big-proofs ((embedding-row-core-promote row) core-B))
  (define delay-Big-proofs ((embedding-row-delay-promote row) delay-B))
  (check-proof-multiset 'feature/Big core-Big-proofs delay-Big-proofs)
  (for ([core-Big (in-list (outputs core-Big-proofs 1))]
        [delay-Big (in-list (outputs delay-Big-proofs 1))])
    (check-equal? ((embedding-row-J-Big row) core-Big) delay-Big)))

(define (canonical-multiset values)
  (sort values string<? #:key ~s))

(define GENERATED-DELAY-EMBEDDING-TESTS
  (test-suite
   "separately staged Core-to-Delay feature embeddings"

   (test-case "all thirteen inherited rules commute through every phase"
     (for ([row (in-list ROWS)])
       (for ([rule-name (in-list core-corpus:CORE-RULE-NAMES)])
         (define source
           (core-corpus:row-source-ref
            (embedding-row-core-corpus row)
            rule-name))
         (check-equal?
          source
          (delay-row-source-ref
           (embedding-row-delay-corpus row)
           rule-name))
         (check-feature-chain row source))))

   (test-case "core embeddings reject Delay-only coordinates"
     (for ([row (in-list ROWS)])
       (define delay-source
         (delay-rule-case-source
          (first
           (delay-row-corpus-owned-rule-cases
            (embedding-row-delay-corpus row)))))
       (check-exn exn:fail:contract?
                  (lambda () ((embedding-row-J-R row) delay-source)))
       (define delay-D
         (only 'delay-only-D
               (outputs
                ((embedding-row-delay-decompose row) delay-source)
                1)))
       (check-exn exn:fail:contract?
                  (lambda () ((embedding-row-J-D row) delay-D)))))))

(module+ test
  (run-tests GENERATED-DELAY-EMBEDDING-TESTS))
