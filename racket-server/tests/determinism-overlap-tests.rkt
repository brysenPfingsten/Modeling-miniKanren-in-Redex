#lang racket

(require rackunit
         rackunit/text-ui
         racket/list
         redex/reduction-semantics
         (prefix-in rt: "../src/random-test-support.rkt")
         "../src/core-definitions.rkt"
         "../src/wf-core.rkt"
         "../src/wf-variants.rkt"
         "../src/extensions/variant-languages.rkt"
         (prefix-in core: "../src/reduction-relations/core-reduction-relations.rkt")
         "../src/reduction-relations/extensions/variant-relations.rkt"
         "../src/model-registry.rkt"
         "../src/capability-analysis.rkt"
         "../src/transpiler.rkt"
         "./example-compat-tests.rkt"
         "./variant-test-support.rkt")

(provide DETERMINISM-OVERLAP)

(define OVERLAP-TRACE-CAP 25)
(define OVERLAP-RANDOM-SEEDS '(424242 777777 20260227))
(define OVERLAP-RANDOM-SAMPLES-PER-MODEL 16)
(define OVERLAP-RANDOM-TERM-DEPTH 8)
(define OVERLAP-RANDOM-MAX-REJECTS 800)

(define (read-all port)
  (let ([expr (read port)])
    (if (eof-object? expr)
        '()
        (cons expr (read-all port)))))

(define (model-id->relation model-id)
  (case (string->symbol model-id)
    [(mk-l0-core) core:-->cfg]
    [(mk-l1-call-lazy) Rl1-call-lazy]
    [(mk-l1-call-eager) Rl1-call-eager]
    [(mk-l2-disj-left) Rl2-disj-left]
    [(mk-l3-dfs-lazy) Rl3-dfs-lazy]
    [(mk-l3-dfs-eager) Rl3-dfs-eager]
    [(mk-l3-flip-lazy) Rl3-flip-lazy]
    [(mk-l3-flip-eager) Rl3-flip-eager]
    [(mk-l4-rail-lazy) Rl4-rail-lazy]
    [(mk-l4-rail-eager) Rl4-rail-eager]
    [else
     (error 'model-id->relation
            (format "unsupported model-id: ~a" model-id))]))

(define (model-domain? model-id cfg)
  (case (string->symbol model-id)
    [(mk-l0-core) (redex-match? Core config cfg)]
    [(mk-l1-call-lazy mk-l1-call-eager) (redex-match? L1 config cfg)]
    [(mk-l2-disj-left) (redex-match? L2 config cfg)]
    [(mk-l3-dfs-lazy mk-l3-dfs-eager mk-l3-flip-lazy mk-l3-flip-eager)
     (redex-match? L3 config cfg)]
    [(mk-l4-rail-lazy mk-l4-rail-eager) (redex-match? L4 config cfg)]
    [else #f]))

(define (model-wf? model-id cfg)
  (case (string->symbol model-id)
    [(mk-l0-core) (judgment-holds (wf-config? ,cfg))]
    [(mk-l1-call-lazy mk-l1-call-eager) (judgment-holds (wf-config/L1? ,cfg))]
    [(mk-l2-disj-left) (judgment-holds (wf-config/L2? ,cfg))]
    [(mk-l3-dfs-lazy mk-l3-dfs-eager mk-l3-flip-lazy mk-l3-flip-eager)
     (judgment-holds (wf-config/L3? ,cfg))]
    [(mk-l4-rail-lazy mk-l4-rail-eager) (judgment-holds (wf-config/L4? ,cfg))]
    [else #f]))

(define (parse-src/canonical src)
  (parse-prog/canonical (read-all (open-input-string src))))

(define (trace-overlap-events rel-name rel cfg0)
  (let loop ([cfg cfg0] [step-index 0] [acc '()])
    (define tagged-next* (apply-reduction-relation/tag-with-names rel cfg))
    (define kind (overlap-kind tagged-next*))
    (define acc*
      (if kind
          (cons (overlap-event rel-name cfg tagged-next* step-index) acc)
          acc))
    (cond
      [(or (null? tagged-next*) (>= step-index OVERLAP-TRACE-CAP))
       (reverse acc*)]
      [else
       (loop (tagged-successor-cfg (first tagged-next*))
             (add1 step-index)
             acc*)])))

(define (generate-random-config model-id rng)
  (let loop ([attempt 0])
    (when (>= attempt OVERLAP-RANDOM-MAX-REJECTS)
      (error 'generate-random-config
             (format "failed to generate wf config for ~a after ~a attempts"
                     model-id
                     OVERLAP-RANDOM-MAX-REJECTS)))
    (define cfg
      (parameterize ([current-pseudo-random-generator rng])
        (case (string->symbol model-id)
          [(mk-l0-core) (generate-term Core config OVERLAP-RANDOM-TERM-DEPTH)]
          [(mk-l1-call-lazy mk-l1-call-eager)
           (generate-term L1 config OVERLAP-RANDOM-TERM-DEPTH)]
          [(mk-l2-disj-left) (generate-term L2 config OVERLAP-RANDOM-TERM-DEPTH)]
          [(mk-l3-dfs-lazy mk-l3-dfs-eager mk-l3-flip-lazy mk-l3-flip-eager)
           (generate-term L3 config OVERLAP-RANDOM-TERM-DEPTH)]
          [(mk-l4-rail-lazy mk-l4-rail-eager)
           (generate-term L4 config OVERLAP-RANDOM-TERM-DEPTH)]
          [else
           (error 'generate-random-config
                  (format "unsupported model-id: ~a" model-id))])))
    (if (and (model-domain? model-id cfg)
             (model-wf? model-id cfg))
        cfg
        (loop (add1 attempt)))))

(define (compatible-example-seeds)
  (define examples (frontend-example-programs))
  (for*/list ([spec (in-list all-model-specs)]
              [ex (in-list examples)])
    (match-define (cons label src) ex)
    (define model-id (model-spec-id spec))
    (define reqs (hash-ref (analyze-source-capabilities src) 'requirements))
    (define compatible-models (compatible-model-ids reqs all-model-specs))
    (if (member model-id compatible-models)
        (let ()
          (define-values (cfg0 _html) (parse-src/canonical src))
          (and (model-domain? model-id cfg0)
               (hash 'model-id model-id
                     'label label
                     'cfg cfg0)))
        #f)))

(define (drop-false xs)
  (for/list ([x (in-list xs)]
             #:when x)
    x))

(define (sample-with-rng rng xs count)
  (for/list ([_ (in-range count)])
    (list-ref xs (rt:rng-random rng (length xs)))))

(define (all-overlap-events)
  (define matrix-seeds (drop-false (compatible-example-seeds)))
  (define matrix-events
    (for*/list ([seed (in-list matrix-seeds)])
      (trace-overlap-events
       (hash-ref seed 'model-id)
       (model-id->relation (hash-ref seed 'model-id))
       (hash-ref seed 'cfg))))
  (define random-events
    (for*/list ([seed (in-list OVERLAP-RANDOM-SEEDS)]
                [spec (in-list all-model-specs)])
      (define model-id (model-spec-id spec))
      (define rng (rt:make-seeded-rng seed))
      (for/list ([cfg
                  (in-list
                   (for/list ([_ (in-range OVERLAP-RANDOM-SAMPLES-PER-MODEL)])
                     (generate-random-config model-id rng)))])
        (trace-overlap-events model-id
                              (model-id->relation model-id)
                              cfg))))
  (append* (append matrix-events random-events)))

(define/provide-test-suite DETERMINISM-OVERLAP
  (test-case "overlap audit captures multi-rule overlap events"
    (define events (all-overlap-events))
    (check-true (list? events))
    ;; Commit A baseline: capture overlap events before priority removal.
    (check-false (null? events)
                 "expected at least one overlap before priority elimination")
    (displayln
     (format "[determinism-overlap] captured ~a overlap event(s)"
             (length events)))))

(module+ test
  (run-tests DETERMINISM-OVERLAP))
