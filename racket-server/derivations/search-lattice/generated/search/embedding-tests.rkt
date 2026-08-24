#lang racket

(require racket/list
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in delay: "../delay/corpus.rkt")
         (prefix-in disjunction: "../disjunction/corpus.rkt")
         (prefix-in delay-source-s: "../delay/source/s.rkt")
         (prefix-in delay-source-e: "../delay/source/e.rkt")
         (prefix-in delay-source-n: "../delay/source/n.rkt")
         (prefix-in disjunction-source-s: "../disjunction/source/s.rkt")
         (prefix-in disjunction-source-e: "../disjunction/source/e.rkt")
         (prefix-in disjunction-source-n: "../disjunction/source/n.rkt")
         (prefix-in search-source-s: "source/s.rkt")
         (prefix-in search-source-e: "source/e.rkt")
         (prefix-in search-source-n: "source/n.rkt")
         (prefix-in delay-stage-s: "../delay/stages/s.rkt")
         (prefix-in delay-stage-e: "../delay/stages/e.rkt")
         (prefix-in delay-stage-n: "../delay/stages/n.rkt")
         (prefix-in disjunction-stage-s: "../disjunction/stages/s.rkt")
         (prefix-in disjunction-stage-e: "../disjunction/stages/e.rkt")
         (prefix-in disjunction-stage-n: "../disjunction/stages/n.rkt")
         (prefix-in search-stage-s: "stages/s.rkt")
         (prefix-in search-stage-e: "stages/e.rkt")
         (prefix-in search-stage-n: "stages/n.rkt")
         "corpus.rkt")

(provide GENERATED-SEARCH-EMBEDDING-TESTS)

(define (canonical values)
  (sort values string<? #:key ~s))

(define (canonical-top-level-proof-multiset proofs)
  (canonical
   (for/list ([proof (in-list proofs)])
     (match (derivation-term proof)
       [(cons _judgment arguments) (cons 'judgment arguments)]))))

(define (outputs proofs count)
  (for/list ([proof (in-list proofs)])
    (define values (take-right (derivation-term proof) count))
    (if (= count 1) (first values) values)))

(define (only who values)
  (match values
    [(list value) value]
    [_ (error who "expected one raw proof, received ~e" values)]))

(define (check-proof-multiset who child-proofs search-proofs)
  (check-equal? (length child-proofs) (length search-proofs)
                (~a who " raw proof multiplicity"))
  (check-equal? (canonical-top-level-proof-multiset child-proofs)
                (canonical-top-level-proof-multiset search-proofs)
                (~a who " complete top-level proof multiset")))

(struct embedding-row
  (name
   child-kind
   child-sources
   search-corpus
   child-raw search-raw J-R
   child-decompose search-decompose J-D
   child-D-step search-D-step
   child-refocus search-refocus J-Z
   child-Z-step search-Z-step
   child-machineize search-machineize J-M
   child-M-step search-M-step
   child-compress search-compress J-B
   child-B-step search-B-step
   child-promote search-promote J-Big)
  #:transparent)

(define-syntax-rule
  (define-embedding-row
    row-id row-name child-kind-id child-sources-id search-corpus-id
    child-raw-id search-raw-id J-R-id
    child-decompose-id search-decompose-id J-D-id
    child-D-step-id search-D-step-id
    child-refocus-id search-refocus-id J-Z-id
    child-Z-step-id search-Z-step-id
    child-machineize-id search-machineize-id J-M-id
    child-M-step-id search-M-step-id
    child-compress-id search-compress-id J-B-id
    child-B-step-id search-B-step-id
    child-promote-id search-promote-id J-Big-id)
  (define row-id
    (embedding-row
     row-name child-kind-id child-sources-id search-corpus-id
     child-raw-id search-raw-id J-R-id
     (lambda (source) (build-derivations (child-decompose-id ,source D)))
     (lambda (source) (build-derivations (search-decompose-id ,source D)))
     J-D-id
     (lambda (D) (build-derivations (child-D-step-id ,D RuleName D_next)))
     (lambda (D) (build-derivations (search-D-step-id ,D RuleName D_next)))
     (lambda (D) (term (child-refocus-id ,D)))
     (lambda (D) (term (search-refocus-id ,D)))
     J-Z-id
     (lambda (Z) (build-derivations (child-Z-step-id ,Z RuleName Z_next)))
     (lambda (Z) (build-derivations (search-Z-step-id ,Z RuleName Z_next)))
     (lambda (Z) (term (child-machineize-id ,Z)))
     (lambda (Z) (term (search-machineize-id ,Z)))
     J-M-id
     (lambda (M) (build-derivations (child-M-step-id ,M RuleName M_next)))
     (lambda (M) (build-derivations (search-M-step-id ,M RuleName M_next)))
     (lambda (M) (term (child-compress-id ,M)))
     (lambda (M) (term (search-compress-id ,M)))
     J-B-id
     (lambda (B) (build-derivations (child-B-step-id ,B TransitionSpan B_next)))
     (lambda (B) (build-derivations (search-B-step-id ,B TransitionSpan B_next)))
     (lambda (B) (build-derivations (child-promote-id ,B Big)))
     (lambda (B) (build-derivations (search-promote-id ,B Big)))
     J-Big-id)))

(define-embedding-row
  DELAY/S 'S 'Delay
  (delay:delay-row-corpus-rule-sources delay:DELAY-CORPUS/S) SEARCH-CORPUS/S
  delay-source-s:raw-successors/generated/delay/s
  search-source-s:raw-successors/generated/search/s
  search-source-s:J-delay->search/R/S
  delay-stage-s:delay/stage-extension/S/D-decompose
  search-stage-s:search/delay-stage-extension/S/D-decompose
  search-stage-s:J-delay->search/D/S
  delay-stage-s:delay/stage-extension/S/D-step
  search-stage-s:search/delay-stage-extension/S/D-step
  delay-stage-s:delay/stage-extension/S/Z-refocus-phase
  search-stage-s:search/delay-stage-extension/S/Z-refocus-phase
  search-stage-s:J-delay->search/Z/S
  delay-stage-s:delay/stage-extension/S/Z-step
  search-stage-s:search/delay-stage-extension/S/Z-step
  delay-stage-s:delay/stage-extension/S/M-machineize
  search-stage-s:search/delay-stage-extension/S/M-machineize
  search-stage-s:J-delay->search/M/S
  delay-stage-s:delay/stage-extension/S/M-step
  search-stage-s:search/delay-stage-extension/S/M-step
  delay-stage-s:delay/stage-extension/S/B-compress
  search-stage-s:search/delay-stage-extension/S/B-compress
  search-stage-s:J-delay->search/B/S
  delay-stage-s:delay/stage-extension/S/B-step
  search-stage-s:search/delay-stage-extension/S/B-step
  delay-stage-s:delay/stage-extension/S/Big-promote
  search-stage-s:search/delay-stage-extension/S/Big-promote
  search-stage-s:J-delay->search/Big/S)

(define-embedding-row
  DELAY/E 'E 'Delay
  (delay:delay-row-corpus-rule-sources delay:DELAY-CORPUS/E) SEARCH-CORPUS/E
  delay-source-e:raw-successors/generated/delay/e
  search-source-e:raw-successors/generated/search/e
  search-source-e:J-delay->search/R/E
  delay-stage-e:delay/stage-extension/E/D-decompose
  search-stage-e:search/delay-stage-extension/E/D-decompose
  search-stage-e:J-delay->search/D/E
  delay-stage-e:delay/stage-extension/E/D-step
  search-stage-e:search/delay-stage-extension/E/D-step
  delay-stage-e:delay/stage-extension/E/Z-refocus-phase
  search-stage-e:search/delay-stage-extension/E/Z-refocus-phase
  search-stage-e:J-delay->search/Z/E
  delay-stage-e:delay/stage-extension/E/Z-step
  search-stage-e:search/delay-stage-extension/E/Z-step
  delay-stage-e:delay/stage-extension/E/M-machineize
  search-stage-e:search/delay-stage-extension/E/M-machineize
  search-stage-e:J-delay->search/M/E
  delay-stage-e:delay/stage-extension/E/M-step
  search-stage-e:search/delay-stage-extension/E/M-step
  delay-stage-e:delay/stage-extension/E/B-compress
  search-stage-e:search/delay-stage-extension/E/B-compress
  search-stage-e:J-delay->search/B/E
  delay-stage-e:delay/stage-extension/E/B-step
  search-stage-e:search/delay-stage-extension/E/B-step
  delay-stage-e:delay/stage-extension/E/Big-promote
  search-stage-e:search/delay-stage-extension/E/Big-promote
  search-stage-e:J-delay->search/Big/E)

(define-embedding-row
  DELAY/N 'N 'Delay
  (delay:delay-row-corpus-rule-sources delay:DELAY-CORPUS/N) SEARCH-CORPUS/N
  delay-source-n:raw-successors/generated/delay/n
  search-source-n:raw-successors/generated/search/n
  search-source-n:J-delay->search/R/N
  delay-stage-n:delay/stage-extension/N/D-decompose
  search-stage-n:search/delay-stage-extension/N/D-decompose
  search-stage-n:J-delay->search/D/N
  delay-stage-n:delay/stage-extension/N/D-step
  search-stage-n:search/delay-stage-extension/N/D-step
  delay-stage-n:delay/stage-extension/N/Z-refocus-phase
  search-stage-n:search/delay-stage-extension/N/Z-refocus-phase
  search-stage-n:J-delay->search/Z/N
  delay-stage-n:delay/stage-extension/N/Z-step
  search-stage-n:search/delay-stage-extension/N/Z-step
  delay-stage-n:delay/stage-extension/N/M-machineize
  search-stage-n:search/delay-stage-extension/N/M-machineize
  search-stage-n:J-delay->search/M/N
  delay-stage-n:delay/stage-extension/N/M-step
  search-stage-n:search/delay-stage-extension/N/M-step
  delay-stage-n:delay/stage-extension/N/B-compress
  search-stage-n:search/delay-stage-extension/N/B-compress
  search-stage-n:J-delay->search/B/N
  delay-stage-n:delay/stage-extension/N/B-step
  search-stage-n:search/delay-stage-extension/N/B-step
  delay-stage-n:delay/stage-extension/N/Big-promote
  search-stage-n:search/delay-stage-extension/N/Big-promote
  search-stage-n:J-delay->search/Big/N)

(define-embedding-row
  DISJUNCTION/S 'S 'Disjunction
  (disjunction:disjunction-row-corpus-rule-sources
   disjunction:DISJUNCTION-CORPUS/S)
  SEARCH-CORPUS/S
  disjunction-source-s:raw-successors/generated/disjunction/s
  search-source-s:raw-successors/generated/search/s
  search-source-s:J-disjunction->search/R/S
  disjunction-stage-s:disjunction/stage-extension/S/D-decompose
  search-stage-s:search/delay-stage-extension/S/D-decompose
  search-stage-s:J-disjunction->search/D/S
  disjunction-stage-s:disjunction/stage-extension/S/D-step
  search-stage-s:search/delay-stage-extension/S/D-step
  disjunction-stage-s:disjunction/stage-extension/S/Z-refocus-phase
  search-stage-s:search/delay-stage-extension/S/Z-refocus-phase
  search-stage-s:J-disjunction->search/Z/S
  disjunction-stage-s:disjunction/stage-extension/S/Z-step
  search-stage-s:search/delay-stage-extension/S/Z-step
  disjunction-stage-s:disjunction/stage-extension/S/M-machineize
  search-stage-s:search/delay-stage-extension/S/M-machineize
  search-stage-s:J-disjunction->search/M/S
  disjunction-stage-s:disjunction/stage-extension/S/M-step
  search-stage-s:search/delay-stage-extension/S/M-step
  disjunction-stage-s:disjunction/stage-extension/S/B-compress
  search-stage-s:search/delay-stage-extension/S/B-compress
  search-stage-s:J-disjunction->search/B/S
  disjunction-stage-s:disjunction/stage-extension/S/B-step
  search-stage-s:search/delay-stage-extension/S/B-step
  disjunction-stage-s:disjunction/stage-extension/S/Big-promote
  search-stage-s:search/delay-stage-extension/S/Big-promote
  search-stage-s:J-disjunction->search/Big/S)

(define-embedding-row
  DISJUNCTION/E 'E 'Disjunction
  (disjunction:disjunction-row-corpus-rule-sources
   disjunction:DISJUNCTION-CORPUS/E)
  SEARCH-CORPUS/E
  disjunction-source-e:raw-successors/generated/disjunction/e
  search-source-e:raw-successors/generated/search/e
  search-source-e:J-disjunction->search/R/E
  disjunction-stage-e:disjunction/stage-extension/E/D-decompose
  search-stage-e:search/delay-stage-extension/E/D-decompose
  search-stage-e:J-disjunction->search/D/E
  disjunction-stage-e:disjunction/stage-extension/E/D-step
  search-stage-e:search/delay-stage-extension/E/D-step
  disjunction-stage-e:disjunction/stage-extension/E/Z-refocus-phase
  search-stage-e:search/delay-stage-extension/E/Z-refocus-phase
  search-stage-e:J-disjunction->search/Z/E
  disjunction-stage-e:disjunction/stage-extension/E/Z-step
  search-stage-e:search/delay-stage-extension/E/Z-step
  disjunction-stage-e:disjunction/stage-extension/E/M-machineize
  search-stage-e:search/delay-stage-extension/E/M-machineize
  search-stage-e:J-disjunction->search/M/E
  disjunction-stage-e:disjunction/stage-extension/E/M-step
  search-stage-e:search/delay-stage-extension/E/M-step
  disjunction-stage-e:disjunction/stage-extension/E/B-compress
  search-stage-e:search/delay-stage-extension/E/B-compress
  search-stage-e:J-disjunction->search/B/E
  disjunction-stage-e:disjunction/stage-extension/E/B-step
  search-stage-e:search/delay-stage-extension/E/B-step
  disjunction-stage-e:disjunction/stage-extension/E/Big-promote
  search-stage-e:search/delay-stage-extension/E/Big-promote
  search-stage-e:J-disjunction->search/Big/E)

(define-embedding-row
  DISJUNCTION/N 'N 'Disjunction
  (disjunction:disjunction-row-corpus-rule-sources
   disjunction:DISJUNCTION-CORPUS/N)
  SEARCH-CORPUS/N
  disjunction-source-n:raw-successors/generated/disjunction/n
  search-source-n:raw-successors/generated/search/n
  search-source-n:J-disjunction->search/R/N
  disjunction-stage-n:disjunction/stage-extension/N/D-decompose
  search-stage-n:search/delay-stage-extension/N/D-decompose
  search-stage-n:J-disjunction->search/D/N
  disjunction-stage-n:disjunction/stage-extension/N/D-step
  search-stage-n:search/delay-stage-extension/N/D-step
  disjunction-stage-n:disjunction/stage-extension/N/Z-refocus-phase
  search-stage-n:search/delay-stage-extension/N/Z-refocus-phase
  search-stage-n:J-disjunction->search/Z/N
  disjunction-stage-n:disjunction/stage-extension/N/Z-step
  search-stage-n:search/delay-stage-extension/N/Z-step
  disjunction-stage-n:disjunction/stage-extension/N/M-machineize
  search-stage-n:search/delay-stage-extension/N/M-machineize
  search-stage-n:J-disjunction->search/M/N
  disjunction-stage-n:disjunction/stage-extension/N/M-step
  search-stage-n:search/delay-stage-extension/N/M-step
  disjunction-stage-n:disjunction/stage-extension/N/B-compress
  search-stage-n:search/delay-stage-extension/N/B-compress
  search-stage-n:J-disjunction->search/B/N
  disjunction-stage-n:disjunction/stage-extension/N/B-step
  search-stage-n:search/delay-stage-extension/N/B-step
  disjunction-stage-n:disjunction/stage-extension/N/Big-promote
  search-stage-n:search/delay-stage-extension/N/Big-promote
  search-stage-n:J-disjunction->search/Big/N)

(define ROWS
  (list DELAY/S DELAY/E DELAY/N DISJUNCTION/S DISJUNCTION/E DISJUNCTION/N))

(define (check-embedding-chain row source)
  (check-equal? ((embedding-row-J-R row) source) source)
  (define child-raw ((embedding-row-child-raw row) source))
  (define search-raw ((embedding-row-search-raw row) source))
  (check-equal? (length child-raw) (length search-raw)
                "source raw proof multiplicity")
  (check-equal? (canonical child-raw) (canonical search-raw)
                "source raw proof multiset")

  (define child-D-proofs ((embedding-row-child-decompose row) source))
  (define search-D-proofs ((embedding-row-search-decompose row) source))
  (check-proof-multiset 'child/decompose child-D-proofs search-D-proofs)
  (define child-D (only 'child-D (outputs child-D-proofs 1)))
  (define search-D (only 'search-D (outputs search-D-proofs 1)))
  (check-equal? ((embedding-row-J-D row) child-D) search-D)
  (check-proof-multiset
   'child/D-step
   ((embedding-row-child-D-step row) child-D)
   ((embedding-row-search-D-step row) search-D))

  (define child-Z ((embedding-row-child-refocus row) child-D))
  (define search-Z ((embedding-row-search-refocus row) search-D))
  (check-equal? ((embedding-row-J-Z row) child-Z) search-Z)
  (check-proof-multiset
   'child/Z-step
   ((embedding-row-child-Z-step row) child-Z)
   ((embedding-row-search-Z-step row) search-Z))

  (define child-M ((embedding-row-child-machineize row) child-Z))
  (define search-M ((embedding-row-search-machineize row) search-Z))
  (check-equal? ((embedding-row-J-M row) child-M) search-M)
  (check-proof-multiset
   'child/M-step
   ((embedding-row-child-M-step row) child-M)
   ((embedding-row-search-M-step row) search-M))

  (define child-B ((embedding-row-child-compress row) child-M))
  (define search-B ((embedding-row-search-compress row) search-M))
  (check-equal? ((embedding-row-J-B row) child-B) search-B)
  (check-proof-multiset
   'child/B-step
   ((embedding-row-child-B-step row) child-B)
   ((embedding-row-search-B-step row) search-B))

  (define child-Big-proofs ((embedding-row-child-promote row) child-B))
  (define search-Big-proofs ((embedding-row-search-promote row) search-B))
  (check-proof-multiset 'child/Big child-Big-proofs search-Big-proofs)
  (for ([child-Big (in-list (outputs child-Big-proofs 1))]
        [search-Big (in-list (outputs search-Big-proofs 1))])
    (check-equal? ((embedding-row-J-Big row) child-Big) search-Big)))

(define GENERATED-SEARCH-EMBEDDING-TESTS
  (test-suite
   "separately staged child-to-Search embeddings"

   (test-case "Delay and Disjunction children embed through R D Z M B and Big"
     (check-equal? (length SEARCH-RULE-NAMES) 21)
     (for ([row (in-list ROWS)])
       (for ([pair (in-list (embedding-row-child-sources row))])
         (match-define (list label source) pair)
         (check-equal?
          source
          (search-row-source-ref (embedding-row-search-corpus row) label)
          (~a (embedding-row-child-kind row) " representative " label))
         (check-embedding-chain row source))))))

(module+ test
  (run-tests GENERATED-SEARCH-EMBEDDING-TESTS))
