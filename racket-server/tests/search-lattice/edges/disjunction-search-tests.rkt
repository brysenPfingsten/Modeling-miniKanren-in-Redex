#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in disj-lang:
                    "../../../src/search-lattice/languages/disj-lang.rkt")
         (prefix-in search-lang:
                    "../../../src/search-lattice/languages/search-lang.rkt")
         (prefix-in disj:
                    "../../../src/search-lattice/reduction-relations/disj-red.rkt")
         (prefix-in search:
                    "../../../src/search-lattice/reduction-relations/search-red.rkt")
         (prefix-in disj-wf:
                    "../../../src/search-lattice/wf/disj-wf.rkt")
         (prefix-in search-wf:
                    "../../../src/search-lattice/wf/search-wf.rkt")
         (only-in "../../search-lattice-support.rkt"
                  sigma-a
                  sigma-s)
         "../support.rkt"
         "./embedding-audit.rkt")

(provide DISJUNCTION-SEARCH-EDGE)

(define DISJUNCTION-OWNED-REPRESENTATIVES
  (list
   (term
    (More
     (Work (Owners)
           ((succeed (label "left"))
            ∨
            (fail (label "right"))
            (label "disj"))
           ,sigma-s)))
   (term
    (More
     (DisjL (Owners (Owner (u:o) (label "choice")))
            (Dead (Owners (Owner (u:d) (label "dead"))))
            (Work (Owners (Owner (u:p) (label "survivor")))
                  (succeed (label "right"))
                  ,sigma-s))))
   (term
    (More
     (DisjL (Owners (Owner (u:k) (label "outer")))
            (DisjL (Owners (Owner (u:o) (label "inner")))
                   (Returned (Owners (Owner (u:a) (label "answer"))) ,sigma-a)
                   (Work (Owners (Owner (u:p) (label "residual")))
                         (succeed (label "tail"))
                         ,sigma-s))
            (Dead (Owners)))))
   (term
    (More
     (DisjL (Owners (Owner (u:o) (label "choice")))
            (Returned (Owners (Owner (u:a) (label "answer"))) ,sigma-a)
            (Dead (Owners)))))
   (term
    (Emit (Owners (Owner (u:e) (label "emit")))
          (Answer (Owners) ,sigma-a)
          (More
           (Work (Owners) (succeed (label "emitted")) ,sigma-s))))))

(define FACTORED-REPRESENTATIVES
  (list
   (term
    (More
     (Conj (Owners (Owner (u:k) (label "conj")))
           (DisjL (Owners (Owner (u:o) (label "choice")))
                  (Returned (Owners (Owner (u:a) (label "answer"))) ,sigma-a)
                  (Dead (Owners)))
           (succeed (label "k")))))))

(define DISJUNCTION-REPRESENTATIVES
  (append CORE-RULE-REPRESENTATIVES
          DISJUNCTION-OWNED-REPRESENTATIVES
          FACTORED-REPRESENTATIVES))

(define (generate-disjunction-frontier)
  (generate-term disj-lang:disj-lang F GENERATED-TERM-DEPTH))

(define DISJUNCTION-GENERATED
  (generated-corpus generate-disjunction-frontier 2026081703))

(define (disjunction-frontier? t)
  (redex-match? disj-lang:disj-lang F t))

(define (search-frontier? t)
  (redex-match? search-lang:search-lang F t))

(define (disjunction-wf? t)
  (judgment-holds (disj-wf:wf-cfg/disj? ,t)))

(define (search-wf? t)
  (judgment-holds (search-wf:wf-cfg/search? ,t)))

(define/provide-test-suite DISJUNCTION-SEARCH-EDGE
  (test-case "disjunction embeds conservatively in the search join"
    (audit-identity-edge
     #:label "disjunction -> search join"
     #:source-relation disj:disj-red
     #:target-relation search:search-red
     #:source? disjunction-frontier?
     #:target? search-frontier?
     #:source-wf? disjunction-wf?
     #:target-wf? search-wf?
     #:representatives DISJUNCTION-REPRESENTATIVES
     #:generated DISJUNCTION-GENERATED)))

(module+ test
  (run-tests DISJUNCTION-SEARCH-EDGE))
