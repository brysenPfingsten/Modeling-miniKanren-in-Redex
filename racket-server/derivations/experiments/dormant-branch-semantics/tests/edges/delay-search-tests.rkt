#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in delay-lang:
                    "../../source/languages/delay-lang.rkt")
         (prefix-in search-lang:
                    "../../source/languages/search-lang.rkt")
         (prefix-in delay:
                    "../../source/reduction-relations/delay-red.rkt")
         (prefix-in search:
                    "../../source/reduction-relations/search-red.rkt")
         (prefix-in delay-wf:
                    "../../source/wf/delay-wf.rkt")
         (prefix-in search-wf:
                    "../../source/wf/search-wf.rkt")
         (only-in "../search-lattice-support.rkt"
                  final-program?
                  produced-answer-spine-only?
                  sigma-s)
         (only-in "../frontier-observable-support.rkt"
                  structurally-well-formed?)
         "../support.rkt"
         "./embedding-audit.rkt")

(provide DELAY-SEARCH-EDGE)

(define DELAY-OWNED-REPRESENTATIVES
  (list
   (term
    (More
     (Work (Owners)
           (suspend (succeed (label "body")) (label "suspend"))
           ,sigma-s)))
   (term
    (More
     (Conj (Owners (Owner (u:k) (label "conj")))
           (PendingDelay
            (Owners (Owner (u:d) (label "delay")))
            (Work (Owners (Owner (u:p) (label "payload")))
                  (succeed (label "pending"))
                  ,sigma-s))
           (succeed (label "k")))))
   (term
    (More
     (PendingDelay (Owners)
                   (Work (Owners) (succeed (label "forced")) ,sigma-s))))
   (term
    (Forced (Owners (Owner (u:f) (label "forced")))
            (More
             (Work (Owners)
                   (suspend (succeed (label "nested-body"))
                            (label "nested-suspend"))
                   ,sigma-s))))))

(define DELAY-TRACE-SEED
  (term
   (More
    (Work (Owners)
          (suspend (succeed (label "body")) (label "delay"))
          ,sigma-s))))

(define DELAY-REPRESENTATIVES
  (append CORE-RULE-REPRESENTATIVES DELAY-OWNED-REPRESENTATIVES))

(define (generate-delay-frontier)
  (generate-term delay-lang:delay-lang F GENERATED-TERM-DEPTH))

(define DELAY-GENERATED
  (generated-corpus generate-delay-frontier 2026081702))

(define (delay-frontier? t)
  (redex-match? delay-lang:delay-lang F t))

(define (search-frontier? t)
  (redex-match? search-lang:search-lang F t))

(define (delay-wf? t)
  (judgment-holds (delay-wf:wf-cfg/delay? ,t)))

(define (search-wf? t)
  (judgment-holds (search-wf:wf-cfg/search? ,t)))

(define (trace-locked? relation wf? shape? cfg [remaining 64])
  (cond
    [(negative? remaining) #f]
    [(not (and (wf? cfg)
               (shape? cfg)
               (produced-answer-spine-only? cfg)
               (structurally-well-formed? cfg)))
     #f]
    [else
     (match (apply-reduction-relation/tag-with-names relation cfg)
       ['() (final-program? cfg)]
       [(list (list _ cfg^))
        (trace-locked? relation wf? shape? cfg^ (sub1 remaining))]
       [_ #f])]))

(define/provide-test-suite DELAY-SEARCH-EDGE
  (test-case "delay embeds conservatively in the search join"
    (audit-identity-edge
     #:label "delay -> search join"
     #:source-relation delay:delay-red
     #:target-relation search:search-red
     #:source? delay-frontier?
     #:target? search-frontier?
     #:source-wf? delay-wf?
     #:target-wf? search-wf?
     #:representatives DELAY-REPRESENTATIVES
     #:generated DELAY-GENERATED))

  (test-case "the inherited delay trace remains inside the search join"
    (check-true
     (trace-locked? search:search-red
                    search-wf?
                    search-frontier?
                    DELAY-TRACE-SEED))))

(module+ test
  (run-tests DELAY-SEARCH-EDGE))
