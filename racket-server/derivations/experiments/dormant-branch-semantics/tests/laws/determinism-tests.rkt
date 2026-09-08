#lang racket

(require racket/runtime-path
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in rt:
                    "../../../../test-support/random-test-support.rkt")
         (prefix-in red:
                    "../../source/reduction-relations/all.rkt")
         (prefix-in lang:
                    "../../source/languages/all.rkt")
         (prefix-in wf:
                    "../../source/wf/all.rkt")
         (prefix-in distributed:
                    "../../../early-conjunction-distribution/all.rkt")
         "../support.rkt"
         "../../../../../src/search-strategy.rkt"
         "../../../../../src/sexpr-read.rkt"
         "../../../../../src/transpiler.rkt"
         "../../../../../tests/example-compat-tests.rkt"
         (only-in "../search-lattice-support.rkt"
                  sigma-a)
         "../../../../test-support/runtime-test-support.rkt")

(provide DETERMINISM-LAWS)

(define OVERLAP-TRACE-CAP 25)
(define OVERLAP-RANDOM-SEEDS '(424242 777777 20260320))
(define OVERLAP-RANDOM-SAMPLES-PER-STRATEGY 10)
(define OVERLAP-RANDOM-TERM-DEPTH 8)
(define OVERLAP-RANDOM-MAX-REJECTS 800)

(define-runtime-path SEARCH-LATTICE-REDUCTION-RELATIONS-DIR
  "../../source/reduction-relations")

(define (extension-source-file? p)
  (define name
    (path->string (file-name-from-path p)))
  (and (regexp-match? #rx"\\.rkt$" name)
       (not (regexp-match? #rx"^(?:\\.#|#)" name))
       (file-exists? p)
       (not (link-exists? p))
       (not (regexp-match? #rx"/archive/" (path->string p)))))

(define (parse-src/canonical src)
  (define-values (cfg html query)
    (parse-prog/canonical (read-all-sexprs (open-input-string src))
                          #:search-strategy (search-strategy "rail")))
  (values (compiled-goal->online-fixture cfg) html query))

(define/match (strategy-label strategy)
  [((search-strategy scheduler)) scheduler])

(define/match (strategy-relation strategy)
  [((search-strategy "dfs")) red:search-dfs-relcall-red]
  [((search-strategy "flip")) red:search-flip-relcall-red]
  [((search-strategy "rail")) red:rail-relcall-red])

(define (overlap-event/raw relation-name cfg raw-next* named-next* step-index)
  (cond
    [(> (length raw-next*) (length named-next*))
     (hash-set
      (overlap-event relation-name cfg raw-next* step-index)
      'kind
      'duplicate-proof)]
    [(overlap-kind named-next*)
     (overlap-event relation-name cfg named-next* step-index)]
    [else #f]))

(define (trace-overlap-events strategy
                              cfg
                              [normalized (normalize-search-strategy strategy)]
                              [relation (strategy-relation normalized)]
                              [step-index 0]
                              [acc '()])
  ;; Keep the raw tagged list: removing duplicates would hide two distinct
  ;; grammatical reduction proofs with the same name and contractum.
  (define raw-next*
    (apply-reduction-relation/tag-with-names relation cfg))
  (define named-next*
    (remove-duplicates raw-next*))
  (define event
    (overlap-event/raw (strategy-label normalized)
                       cfg
                       raw-next*
                       named-next*
                       step-index))
  (define acc*
    (if event (cons event acc) acc))
  (cond
    [(or (null? named-next*)
         (> (length named-next*) 1)
         (>= step-index OVERLAP-TRACE-CAP))
     (reverse acc*)]
    [else
     (trace-overlap-events strategy
                           (tagged-successor-cfg (first named-next*))
                           normalized
                           relation
                           (add1 step-index)
                           acc*)]))

(define (strategy-matches-generated? strategy cfg)
  (and (online-in-domain? strategy cfg)
       (online-well-formed? strategy cfg)))

(define (generate-random-config strategy
                                rng
                                [normalized (normalize-search-strategy strategy)]
                                [attempt 0])
  (when (>= attempt OVERLAP-RANDOM-MAX-REJECTS)
    (error 'generate-random-config
           "failed to generate wf config for ~a after ~a attempts"
           (strategy-label normalized)
           OVERLAP-RANDOM-MAX-REJECTS))
  (define cfg
    (parameterize ([current-pseudo-random-generator rng])
      (match normalized
        [(search-strategy "rail")
         (generate-term lang:rail-relcall-lang
                        config
                        OVERLAP-RANDOM-TERM-DEPTH)]
        [_
         (generate-term lang:search-relcall-lang
                        config
                        OVERLAP-RANDOM-TERM-DEPTH)])))
  (cond
    [(strategy-matches-generated? normalized cfg) cfg]
    [else
     (generate-random-config strategy
                             rng
                             normalized
                             (add1 attempt))]))

(define (compatible-example-seeds strategies)
  (define examples
    (frontend-example-programs))
  (for*/list ([strategy (in-list strategies)]
              [ex (in-list examples)])
    (match-define (cons _label src) ex)
    (define-values (cfg0 _html _query) (parse-src/canonical src))
    (and (online-in-domain? strategy cfg0)
         (online-well-formed? strategy cfg0)
         (hash 'strategy strategy
               'cfg cfg0))))

(define (drop-false xs)
  (for/list ([x (in-list xs)]
             #:when x)
    x))

(define (example-overlap-events)
  (define examples
    (frontend-example-programs))
  (define seeds
    (drop-false
     (compatible-example-seeds all-surfaced-search-strategies)))
  (check-true (pair? seeds)
              "example overlap audit generated no in-domain seeds")
  (check-equal? (length seeds)
                (* (length all-surfaced-search-strategies)
                   (length examples))
                "example overlap audit silently dropped a strategy/example pair")
  (for/list ([seed (in-list seeds)])
    (match-define (hash* ['strategy strategy]
                         ['cfg cfg]
                         #:open)
      seed)
    (trace-overlap-events strategy cfg)))

(define (random-overlap-events)
  (for*/list ([seed (in-list OVERLAP-RANDOM-SEEDS)]
              [strategy (in-list all-surfaced-search-strategies)])
    (define rng
      (rt:make-seeded-rng seed))
    (for/list ([cfg
                (in-list
                 (for/list ([_ (in-range OVERLAP-RANDOM-SAMPLES-PER-STRATEGY)])
                   (generate-random-config strategy rng)))])
      (trace-overlap-events strategy cfg))))

(define (check-only-rule relation source expected-name)
  (define raw-next*
    (apply-reduction-relation/tag-with-names relation source))
  (check-equal? (length raw-next*)
                1
                (format "expected one raw proof for ~s, got ~s"
                        source
                        raw-next*))
  (when (pair? raw-next*)
    (check-equal? (tagged-successor-name (first raw-next*))
                  expected-name
                  (format "unexpected rule for ~s" source))))

(define/provide-test-suite DETERMINISM-LAWS
  (test-case "grammar-selection guard: no rule-priority/name-based precedence in active search-lattice semantics"
    (for ([p (in-list (find-files extension-source-file? SEARCH-LATTICE-REDUCTION-RELATIONS-DIR))])
      (define src
        (file->string p))
      (check-false
       (regexp-match? #px"step-priority" src)
       (format "forbidden priority-based determinizer found in ~a" p))
      (check-false
       (regexp-match?
        #px"side-condition[^\\]]*apply-reduction-relation/tag-with-names"
        src)
       (format "forbidden rule-name-based precedence fence found in ~a" p))
      (check-false
       (regexp-match? #rx"remove-duplicates" src)
       (format "forbidden raw-successor deduplication found in ~a" p))))

  (test-case "owner-bearing choice contexts stay uniquely decomposed"
    (define settled-left
      (term
       (More
        (Conj (Owners (Owner (u:k) (label "conj")))
              (DisjL (Owners (Owner (u:o) (label "choice")))
                     (Returned (Owners (Owner (u:a) (label "answer"))) ,sigma-a)
                     (Dead (Owners)))
              (succeed (label "k"))))))
    (define settled-right
      (term
       (More
        (Conj (Owners (Owner (u:k) (label "conj")))
              (DisjR (Owners (Owner (u:o) (label "choice")))
                     (Dead (Owners))
                     (Returned (Owners (Owner (u:a) (label "answer"))) ,sigma-a))
              (succeed (label "k"))))))

    (check-only-rule distributed:search-distributed-red
                     settled-left
                     "distribute-choice")
    (check-only-rule distributed:rail-distributed-red
                     settled-right
                     "distribute-right-choice")
    (check-only-rule red:search-red
                     settled-left
                     "resume-left-choice-success")
    (check-only-rule red:rail-red
                     settled-right
                     "resume-right-choice-success"))

  (test-case "overlap audit: surfaced structured strategies over frontend examples"
    (define events
      (append* (example-overlap-events)))
    (check-true (null? events)
                (if (null? events)
                    "no example-corpus overlaps"
                    (format "example overlap events found: ~s" events))))

  (test-case "overlap audit: surfaced strategies have unique named successors and raw proofs over generated configs"
    (define events
      (append* (append* (random-overlap-events))))
    (check-true (null? events)
                (if (null? events)
                    "no generated-config overlaps"
                    (format "generated overlap events found: ~s" events)))))

(module+ test
  (run-tests DETERMINISM-LAWS))
