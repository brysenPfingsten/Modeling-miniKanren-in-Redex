#lang racket

(require rackunit
         redex/reduction-semantics
         (prefix-in red: "../../src/search-lattice/reduction-relations/all.rkt")
         (prefix-in lang: "../../src/search-lattice/languages/all.rkt")
         (prefix-in wf: "../../src/search-lattice/wf/all.rkt")
         "../../src/search-strategy.rkt"
         "../search-lattice-support.rkt")

(provide named-step
         check-static-rule-inventory
         check-live-rule-coverage
         online-relation
         online-in-domain?
         online-well-formed?
         compiled-goal->online-fixture
         CORE-RULE-REPRESENTATIVES)

;; Historical lattice tests select their native sources explicitly. Application
;; scheduler routing now selects strict matrix rows with a different carrier.
(define/match (online-relation strategy)
  [((search-strategy "dfs")) red:search-dfs-relcall-red]
  [((search-strategy "flip")) red:search-flip-relcall-red]
  [((search-strategy "rail")) red:rail-relcall-red])

(define (online-in-domain? strategy cfg)
  (match strategy
    [(search-strategy "rail") (redex-match? lang:rail-relcall-lang config cfg)]
    [_ (redex-match? lang:search-relcall-lang config cfg)]))

(define (online-well-formed? strategy cfg)
  (match strategy
    [(search-strategy "rail") (judgment-holds (wf:wf-config/rail-relcall? ,cfg))]
    [_ (judgment-holds (wf:wf-config/search-relcall? ,cfg))]))

;; Compile once using the current compiler, then initialize the older source
;; from its goal. This is test setup, never an execution-state conversion.
(define (compiled-goal->online-fixture cfg)
  (match cfg
    [`(program ,definitions (commit (eval ,owners ,goal ,state)))
     `(,definitions (More (Work ,owners ,goal ,state)))]))

;; Preserve raw Redex proof cardinality: callers receive a step only when the
;; tagged relation produced exactly one proof, before any deduplication.
(define (named-step successors)
  (match successors
    [(list (list name configuration))
     (values name configuration)]
    [_
     (error 'named-step
            "expected exactly one tagged successor, got ~e"
            successors)]))

(define (sort-symbols symbols)
  (sort symbols symbol<?))

(define (tagged-rule-symbol successor)
  (match successor
    [(list name _configuration)
     (string->symbol (~a name))]))

(define (check-static-rule-inventory label relation expected)
  (define actual
    (reduction-relation->rule-names relation))
  (check-equal? (length actual)
                (length (remove-duplicates actual))
                (format "~a repeats a static rule name" label))
  (check-equal? (sort-symbols actual)
                (sort-symbols expected)
                (format "~a static rule inventory drifted" label)))

(define (check-live-rule-coverage label relation representatives expected)
  (define observed
    (sort-symbols
     (remove-duplicates
      (for*/list ([source (in-list representatives)]
                  [successor
                   (in-list
                    (apply-reduction-relation/tag-with-names relation source))])
        (tagged-rule-symbol successor)))))
  (check-equal? observed
                (sort-symbols expected)
                (format "~a live witnesses no longer cover every static rule"
                        label)))

;; Core witnesses are shared by the core node and both additive feature nodes.
;; Feature-owned witnesses and expected inventories remain in their owners.
(define CORE-RULE-REPRESENTATIVES
  (list
   (term
    (More
     (Work (Owners)
           ((succeed (label "left"))
            ∧
            (fail (label "right"))
            (label "conj"))
           ,sigma-s)))
   (term (More (Work (Owners) (succeed (label "succeed")) ,sigma-s)))
   (term (More (Work (Owners) (fail (label "fail")) ,sigma-s)))
   (term
    (More
     (Conj (Owners)
           (Returned (Owners) ,sigma-a)
           (succeed (label "resume")))))
   (term
    (More
     (Conj (Owners)
           (Dead (Owners))
           (succeed (label "never")))))
   (term
    (More
     (Work (Owners)
           (∃ (x:q)
               (succeed (label "body"))
               (label "fresh"))
           ,sigma-s)))
   (term
    (More
     (Work (Owners)
           (u:0 =? (nat 0) (label "unify"))
           ,sigma-s)))
   (term
    (More
     (Work (Owners)
           (u:0 =? (nat 0) (label "violates"))
           (state ()
                  ((u:0 (nat 0)))
                  ()
                  (label "violates-state")))))
   (term
    (More
     (Work (Owners)
           ((nat 0) =? (nat 1) (label "unify-fail"))
           ,sigma-s)))
   (term
    (More
     (Work (Owners)
           ((nat 0) != (nat 1) (label "disequality-ok"))
           ,sigma-s)))
   (term
    (More
     (Work (Owners)
           ((nat 0) != (nat 0) (label "disequality-fail"))
           ,sigma-s)))
   (term (More (Returned (Owners) ,sigma-a)))
   (term (More (Dead (Owners))))))
