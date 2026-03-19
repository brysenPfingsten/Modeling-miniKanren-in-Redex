#lang racket

(require rackunit
         rackunit/text-ui
         racket/file
         racket/list
         racket/runtime-path
         redex/reduction-semantics
         (prefix-in rt: "../src/random-test-support.rkt")
         "../src/languages/l0.rkt"
         "../src/wf/all.rkt"
         "../src/languages/all.rkt"
         (prefix-in l0: "../src/reduction-relations/l0.rkt")
         "../src/reduction-relations/all.rkt"
         "../src/model-registry.rkt"
         "../src/model-surface-policy.rkt"
         "../src/transpiler.rkt"
         "../src/sexpr-read.rkt"
         "./example-compat-tests.rkt"
         "./variant-test-support.rkt")

(provide DETERMINISM-OVERLAP)

(define OVERLAP-TRACE-CAP 25)
(define OVERLAP-RANDOM-SEEDS '(424242 777777 20260227))
(define OVERLAP-RANDOM-SAMPLES-PER-MODEL 16)
(define OVERLAP-RANDOM-TERM-DEPTH 8)
(define OVERLAP-RANDOM-MAX-REJECTS 800)

(define-runtime-path REDUCTION-RELATIONS-DIR
  "../src/reduction-relations")

(define (extension-source-file? p)
  (define name
    (path->string (file-name-from-path p)))
  (and (regexp-match? #rx"\\.rkt$" name)
       (not (regexp-match? #rx"^(?:\\.#|#)" name))
       (file-exists? p)
       (not (link-exists? p))
       (not (regexp-match? #rx"/archive/" (path->string p)))))

(define (model-id->relation model-id)
  (case (string->symbol model-id)
    [(l0-core) l0:Rl0-core]
    [(l1-call-lazy) Rl1-call-lazy]
    [(l1-call-eager) Rl1-call-eager]
    [(l2-disj-left) Rl2-disj-left]
    [(l3-dfs-lazy) Rl3-dfs-lazy]
    [(l3-dfs-eager) Rl3-dfs-eager]
    [(l3-flip-lazy) Rl3-flip-lazy]
    [(l3-flip-eager) Rl3-flip-eager]
    [(l4-rail-lazy) Rl4-rail-lazy]
    [(l4-rail-eager) Rl4-rail-eager]
    [else
     (error 'model-id->relation
            (format "unsupported model-id: ~a" model-id))]))

(define (model-domain? model-id cfg)
  (case (string->symbol model-id)
    [(l0-core) (redex-match? L0 config cfg)]
    [(l1-call-lazy l1-call-eager) (redex-match? L1 config cfg)]
    [(l2-disj-left) (redex-match? L2 config cfg)]
    [(l3-dfs-lazy l3-dfs-eager l3-flip-lazy l3-flip-eager)
     (redex-match? L3 config cfg)]
    [(l4-rail-lazy l4-rail-eager) (redex-match? L4 config cfg)]
    [else #f]))

(define (model-wf? model-id cfg)
  (case (string->symbol model-id)
    [(l0-core) (judgment-holds (wf-config? ,cfg))]
    [(l1-call-lazy l1-call-eager) (judgment-holds (wf-config/L1? ,cfg))]
    [(l2-disj-left) (judgment-holds (wf-config/L2? ,cfg))]
    [(l3-dfs-lazy l3-dfs-eager l3-flip-lazy l3-flip-eager)
     (judgment-holds (wf-config/L3? ,cfg))]
    [(l4-rail-lazy l4-rail-eager) (judgment-holds (wf-config/L4? ,cfg))]
    [else #f]))

(define (parse-src/canonical src)
  (parse-prog/canonical (read-all-sexprs (open-input-string src))))

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
          [(l0-core) (generate-term L0 config OVERLAP-RANDOM-TERM-DEPTH)]
          [(l1-call-lazy l1-call-eager)
           (generate-term L1 config OVERLAP-RANDOM-TERM-DEPTH)]
          [(l2-disj-left) (generate-term L2 config OVERLAP-RANDOM-TERM-DEPTH)]
          [(l3-dfs-lazy l3-dfs-eager l3-flip-lazy l3-flip-eager)
           (generate-term L3 config OVERLAP-RANDOM-TERM-DEPTH)]
          [(l4-rail-lazy l4-rail-eager)
           (generate-term L4 config OVERLAP-RANDOM-TERM-DEPTH)]
          [else
           (error 'generate-random-config
                  (format "unsupported model-id: ~a" model-id))])))
    (if (and (model-domain? model-id cfg)
             (model-wf? model-id cfg))
        cfg
        (loop (add1 attempt)))))

(define (compatible-example-seeds model-ids)
  (define examples (frontend-example-programs))
  (for*/list ([model-id (in-list model-ids)]
              [ex (in-list examples)])
    (match-define (cons _label src) ex)
    (define-values (cfg0 _html) (parse-src/canonical src))
    (and (model-domain? model-id cfg0)
         (model-wf? model-id cfg0)
         (hash 'model-id model-id
               'cfg cfg0))))

(define (drop-false xs)
  (for/list ([x (in-list xs)]
             #:when x)
    x))

(define (heavy-overlap-events)
  (define matrix-seeds (drop-false (compatible-example-seeds surfaced-model-ids)))
  (define matrix-events
    (for/list ([seed (in-list matrix-seeds)])
      (trace-overlap-events
       (hash-ref seed 'model-id)
       (model-id->relation (hash-ref seed 'model-id))
       (hash-ref seed 'cfg))))
  (define random-events
    (for*/list ([seed (in-list OVERLAP-RANDOM-SEEDS)]
                [model-id (in-list surfaced-model-ids)])
      (define rng (rt:make-seeded-rng seed))
      (for/list ([cfg
                  (in-list
                   (for/list ([_ (in-range OVERLAP-RANDOM-SAMPLES-PER-MODEL)])
                     (generate-random-config model-id rng)))])
        (trace-overlap-events model-id
                              (model-id->relation model-id)
                              cfg))))
  (append* (append matrix-events (append* random-events))))

(define (internal-seam-model-cfgs)
  (for/list ([model-id (in-list internal-smoke-model-ids)])
    (define cfgs
      (for/list ([cfg (in-list seam-config-candidates)]
                 #:when (and (model-domain? model-id cfg)
                             (model-wf? model-id cfg)))
        cfg))
    (hash 'model-id model-id
          'cfgs cfgs)))

(define (internal-seam-overlap-events seam-model-cfgs)
  (for*/list ([entry (in-list seam-model-cfgs)]
              [cfg (in-list (hash-ref entry 'cfgs))])
    (trace-overlap-events (hash-ref entry 'model-id)
                          (model-id->relation (hash-ref entry 'model-id))
                          cfg)))

(define/provide-test-suite DETERMINISM-OVERLAP
  (test-case "policy guard: no rule-priority/name-based precedence in extension semantics"
    (for ([p (in-list (find-files extension-source-file? REDUCTION-RELATIONS-DIR))])
      (define src (file->string p))
      (check-false
       (regexp-match? #px"step-priority" src)
       (format "forbidden priority-based determinizer found in ~a" p))
      (check-false
       (regexp-match?
        #px"side-condition[^\\]]*apply-reduction-relation/tag-with-names"
        src)
       (format "forbidden rule-name-based precedence fence found in ~a" p))))

  (test-case "regression: rail/disj overlap shape has a single next step"
    (define cfg
      (term
       (()
        ((empty-tree)
         +-> (⊤ (state () () () () (label "XAfR"))))
        (empty-stream))))
    (define tagged-next*
      (apply-reduction-relation/tag-with-names Rl4-rail-lazy cfg))
    (check-equal? (length tagged-next*) 1
                  (format "expected single successor, got ~a: ~s"
                          (length tagged-next*)
                          tagged-next*))
    (check-true
     (regexp-match? #rx"^l4-rail/promote-right-answer"
                    (tagged-successor-name (first tagged-next*)))
     (format "expected rail right-answer promotion step, got ~s" tagged-next*)))

  (test-case "overlap audit: heavy L3/L4 variants"
    (define events (heavy-overlap-events))
    (check-true (null? events)
                (if (null? events)
                    "no heavy-model overlaps"
                    (format "heavy overlap events found: ~s" events))))

  (test-case "overlap audit: internal L0/L1/L2 seam smoke"
    (define seam-model-cfgs (internal-seam-model-cfgs))
    (for ([entry (in-list seam-model-cfgs)])
      (define model-id (hash-ref entry 'model-id))
      (define cfgs (hash-ref entry 'cfgs))
      (check-true (pair? cfgs)
                  (format "no seam-corpus configs in domain/wf for ~a" model-id)))
    (define events (append* (internal-seam-overlap-events seam-model-cfgs)))
    (check-true (null? events)
                (if (null? events)
                    "no internal seam overlaps"
                    (format "internal seam overlap events found: ~s" events)))))

(module+ test
  (run-tests DETERMINISM-OVERLAP))
