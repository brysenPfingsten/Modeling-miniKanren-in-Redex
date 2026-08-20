#lang racket

(require json
         racket/list
         racket/runtime-path
         rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "../src/app.rkt"
         "../src/search-lattice/picture.rkt"
         "../src/search-strategy.rkt"
         "./frontier-observable-support.rkt"
         "./example-compat-tests.rkt"
         "./test-http-helpers.rkt")

(provide VISIBLE-CONTRACTS)

(define-runtime-path VISIBLE-CONTRACT-PATH
  "../../contracts/visible-node-contract.json")

(define VISIBLE-STEP-CAP 10)

(define REPRESENTATIVE-VISIBLE-LABELS
  '("fives/fours"
    "same"
    "factored continuation"
    "fresh branch disj"))

;; The operational picture intentionally forgets two phase boundaries: More
;; and Last are not rendered around their answer node, and Dead and Done share
;; the Empty node. A repeated picture therefore needs one of these explicit
;; transition certificates.
(define VISIBLE-NEUTRAL-PHASE-LABELS
  '("finish-success"
    "finish-failure"))

(define/match (strategy-label strategy)
  [((search-strategy scheduler)) scheduler])

(define (read-visible-contract)
  (call-with-input-file VISIBLE-CONTRACT-PATH read-json))

(define (json-node-names node [acc '()])
  (match node
    [(? hash? h)
     (define acc^
       (match (hash-ref h 'name #f)
         [(? string? nm) (cons nm acc)]
         [_ acc]))
     (for/fold ([names acc^]) ([value (in-hash-values h)])
       (json-node-names value names))]
    [(list xs ...)
     (for/fold ([names acc]) ([x (in-list xs)])
       (json-node-names x names))]
    [_ acc]))

(define (response->payload response)
  (string->jsexpr (response-body->string response)))

(define (payload->program payload)
  (string->jsexpr (hash-ref payload 'program)))

(define (trace-programs src [strategy default-search-strategy] [cap VISIBLE-STEP-CAP])
  (for/list ([payload (in-list (trace-payloads src strategy cap))])
    (payload->program payload)))

(define trace-payload-cache (make-hash))

(define (trace-payloads src [strategy default-search-strategy] [cap VISIBLE-STEP-CAP])
  (hash-ref!
   trace-payload-cache
   (list src strategy cap)
   (lambda ()
     (define req (make-post-init-request src #:strategy strategy))
     (define ses0 (make-empty-session))
     (define-values (init-response ses1)
       (init! ses0 req 'visible-contract-id))
     (define init-payload (response->payload init-response))
     (define (loop ses remaining [acc (list init-payload)])
       (cond
         [(zero? remaining) (reverse acc)]
         [else
          (define-values (response ses^) (step! ses))
          (match (response-body->string response)
            ["null" (reverse acc)]
            [out
             (loop ses^
                   (sub1 remaining)
                   (cons (string->jsexpr out) acc))])]))
     (loop ses1 cap))))

(define (adjacent-program-pairs payloads)
  (for/list ([left (in-list payloads)]
             [right (in-list (rest payloads))])
    (list left right)))

(define (payload-node-names src [strategy default-search-strategy])
  (append*
   (for/list ([payload (in-list (trace-payloads src strategy))])
     (json-node-names (payload->program payload)))))

(define/provide-test-suite VISIBLE-CONTRACTS
  (test-case "owner records render outer-to-inner while operational and extensional pictures distinguish Forced"
    (define cfg
      (term
       (()
        (Forced
         (Owners
          (Owner () (label "outer"))
          (Owner (u:0 u:1) (label "inner")))
         (Done (Owners))))))
    (define operational
      (cfg->operational-picture cfg))
    (define extensional
      (cfg->extensional-picture cfg))

    (check-equal? (hash-ref operational 'name) "Freshened")
    (check-equal? (hash-ref operational 'id) "outer")
    (check-equal? (hash-ref operational 'vars) '())
    (define operational-inner
      (first (hash-ref operational 'children)))
    (check-equal? (hash-ref operational-inner 'name) "Freshened")
    (check-equal? (hash-ref operational-inner 'id) "inner")
    (check-equal? (hash-ref operational-inner 'vars) '(0 1))
    (check-equal?
     (hash-ref (first (hash-ref operational-inner 'children)) 'name)
     "Deferred")
    (check-equal? (hash-ref extensional 'name) "Freshened")
    (check-equal? (hash-ref extensional 'id) "outer")
    (check-equal? (hash-ref extensional 'vars) '())
    (define extensional-inner
      (first (hash-ref extensional 'children)))
    (check-equal? (hash-ref extensional-inner 'name) "Freshened")
    (check-equal? (hash-ref extensional-inner 'id) "inner")
    (check-equal? (hash-ref extensional-inner 'vars) '(0 1))
    (check-equal?
     (hash-ref (first (hash-ref extensional-inner 'children)) 'name)
     "Empty"))

  (test-case "serializer emits only visible node kinds for the full example corpus under the default strategy"
    (define contract (read-visible-contract))
    (define allowed
      (sort (hash-ref contract 'visibleNodeNames) string<?))
    (define seen
      (sort
       (remove-duplicates
        (append*
         (for/list ([pr (in-list (frontend-example-programs))])
           (match-define (cons _label src) pr)
           (payload-node-names src))))
       string<?))
    (check-true (pair? seen))
    (for ([nm (in-list seen)])
      (check-not-false (member nm allowed)
                       (format "unexpected visible node kind from serializer: ~a" nm))))

  (test-case "serializer emits visible trees that satisfy the explicit stream/search AST shape"
    (for ([pr (in-list (frontend-example-programs))])
      (match-define (cons label src) pr)
      (for ([program (in-list (trace-programs src))])
        (check-true (visible-json-wf? program)
                    (format "visible AST wf failed for default strategy / ~a" label)))))

  (test-case "serializer emits only visible node kinds for surfaced strategies on the representative visible corpus"
    (define contract (read-visible-contract))
    (define allowed
      (sort (hash-ref contract 'visibleNodeNames) string<?))
    (define seen
      (sort
       (remove-duplicates
        (append*
         (for*/list ([strategy (in-list all-surfaced-search-strategies)]
                     [pr (in-list (frontend-example-programs))]
                     #:when (member (car pr) REPRESENTATIVE-VISIBLE-LABELS))
           (match-define (cons _label src) pr)
           (payload-node-names src strategy))))
       string<?))
    (check-true (pair? seen))
    (for ([nm (in-list seen)])
      (check-not-false (member nm allowed)
                       (format "unexpected visible node kind from serializer: ~a" nm))))

  (test-case "representative surfaced strategies satisfy the explicit visible AST shape"
    (for* ([strategy (in-list all-surfaced-search-strategies)]
           [pr (in-list (frontend-example-programs))]
           #:when (member (car pr) REPRESENTATIVE-VISIBLE-LABELS))
      (match-define (cons label src) pr)
      (for ([program (in-list (trace-programs src strategy))])
        (check-true
         (visible-json-wf? program)
         (format "~a / ~a violates visible AST wf"
                 (strategy-label strategy)
                 label)))))

  (test-case "only named phase boundaries may repeat a visible tree on adjacent steps"
    (define seen-edge-labels '())
    (define repeated-edge-labels '())
    (for* ([strategy (in-list all-surfaced-search-strategies)]
           [pr (in-list (frontend-example-programs))]
           #:when (member (car pr) REPRESENTATIVE-VISIBLE-LABELS))
      (match-define (cons label src) pr)
      (for ([pair (in-list (adjacent-program-pairs (trace-payloads src strategy)))])
        (match-define (list left right) pair)
        (define left-program (hash-ref left 'program))
        (define right-program (hash-ref right 'program))
        (define left-step (hash-ref left 'step))
        (define right-step (hash-ref right 'step))
        (define left-name (hash-ref left 'stepName))
        (define right-name (hash-ref right 'stepName))
        ;; right-name is the certificate for the edge from left to right: each
        ;; response names the transition that produced its current program.
        (set! seen-edge-labels (cons right-name seen-edge-labels))
        (define repeats?
          (equal? (string->jsexpr left-program)
                  (string->jsexpr right-program)))
        (when repeats?
          (set! repeated-edge-labels
                (cons right-name repeated-edge-labels)))
        (unless (member right-name VISIBLE-NEUTRAL-PHASE-LABELS)
          (check-false
           repeats?
           (format "~a / ~a repeats visible tree without a phase-only certificate on edge ~a (~a) -> ~a (~a)"
                   (strategy-label strategy)
                   label
                   left-step
                   left-name
                   right-step
                   right-name)))))
    (define seen-labels (remove-duplicates seen-edge-labels))
    (define repeated-labels (remove-duplicates repeated-edge-labels))
    (for ([phase-label (in-list VISIBLE-NEUTRAL-PHASE-LABELS)]
          #:when (member phase-label seen-labels))
      (check-not-false
       (member phase-label repeated-labels)
       (format "representative traces contain phase-only edge ~a but do not exercise its visibility-neutral case; repeated labels were ~s"
               phase-label
               (sort repeated-labels string<?)))))
  )

(module+ test
  (run-tests VISIBLE-CONTRACTS))
