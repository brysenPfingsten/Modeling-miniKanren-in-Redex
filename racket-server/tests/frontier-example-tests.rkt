#lang racket

(require rackunit rackunit/text-ui
         "../src/program-runner.rkt"
         (only-in "../derivations/strict-search/shared/wf.rkt" wf-s-rel?)
         "./example-compat-tests.rkt" "./runtime-test-support.rkt")

(provide FRONTIER-EXAMPLES)

(define fresh-delay-source
  "(run* (q) (fresh (x) (conj (Zzz (== x 'nap)) (== q x))))")
(define nested-rail-source
  "(run* (q)
     (disj (disj (== q 'left-now) (Zzz (== q 'left-later)))
           (disj (== q 'right-now) (Zzz (== q 'right-later)))))")

(define (example-source label)
  (match (assoc label (frontend-example-programs))
    [(cons _ source) source]
    [_ (error 'example-source "missing frontend example: ~a" label)]))

(define (trace-session session [fuel 200] [reversed '()])
  (define configuration (model-session-current-config session))
  (check-true (wf-s-rel? configuration) (format "scope/trail failure: ~s" configuration))
  (define accumulated (cons session reversed))
  (cond
    [(model-session-done? session) (reverse accumulated)]
    [(zero? fuel) (error 'trace-session "finite Frontier witness exhausted its budget")]
    [else (trace-session (model-session-step session) (sub1 fuel) accumulated)]))

(define (trace-example label)
  (trace-session (open-source (example-source label))))

(define (label-count trace label)
  (count (lambda (session) (equal? (model-session-current-step-name session) label)) trace))

(define (owner-groups datum)
  (match datum
    [`(Owner ,variables ,tag) (list (list variables tag))]
    [(? list? parts) (append-map owner-groups parts)]
    [_ '()]))

;; Count only the persistent observer spine, never a suspended computation.
(define (forced-count configuration)
  (match configuration
    [`(program ,_ ,frontier) (forced-count frontier)]
    [`(Forced ,_ ,frontier) (add1 (forced-count frontier))]
    [`(Emit ,_ ,_ ,frontier) (forced-count frontier)]
    [`(,(or 'advance 'collect) ,frontier) (forced-count frontier)]
    [_ 0]))

(define (answer-scopes session)
  (map (lambda (answer) (hash-ref answer 'scope))
       (model-session-current-answer-nodes session)))

(define/provide-test-suite FRONTIER-EXAMPLES
  (test-case "fresh witness retains its query and local introductions in the completed Frontier"
    (define trace (trace-example "fresh witness"))
    (define final (last trace))
    (check-true (final-config? (model-session-current-config final)))
    (check-equal? (label-count trace "allocate-fresh") 2)
    (check-equal? (forced-count (model-session-current-config final)) 0)
    (check-equal? (model-session-current-host-answers final) '(fresh))
    (check-equal? (answer-scopes final) '((0 1))))

  (test-case "shared introductions belong to both answers; branch introductions retain their separate sites"
    (define shared (trace-example "fresh shared disj"))
    (define branch (trace-example "fresh branch disj"))
    (define shared-config (model-session-current-config (last shared)))
    (define branch-config (model-session-current-config (last branch)))
    (check-equal? (label-count shared "allocate-fresh") 2)
    (check-equal? (label-count branch "allocate-fresh") 3)
    (check-equal? (length (owner-groups shared-config)) 2)
    (check-equal? (length (owner-groups branch-config)) 3)
    (match-define `(program ,_ (Emit ,shared-common ,_ ,_)) shared-config)
    (match-define `(program ,_ (Emit ,branch-common ,_ ,_)) branch-config)
    (check-equal? (map first (owner-groups shared-common)) '((u:0) (u:1)))
    (check-equal? (map first (owner-groups branch-common)) '((u:0)))
    (for ([trace (list shared branch)])
      (check-equal? (model-session-current-host-answers (last trace)) '(left right))
      (check-equal? (answer-scopes (last trace)) '((0 1) (0 1)))))

  (test-case "split fresh conjunction preserves both introductions through eager bind"
    (define trace (trace-example "fresh split conj"))
    (define final (last trace))
    (check-equal? (label-count trace "allocate-fresh") 3)
    (check-equal? (model-session-current-host-answers final) '((left . tail)))
    (check-equal? (answer-scopes final) '((0 1 2))))

  (test-case "fresh across Delay retains scope and pending bind through public resumption"
    (define trace (trace-session (open-source fresh-delay-source #:source-mode "micro")))
    (define final (last trace))
    (check-equal? (label-count trace "allocate-fresh") 2)
    (check-equal? (label-count trace "advance") 1)
    (check-equal? (label-count trace "advance-delay") 1)
    ;; bind-delay retains the body directly; this witness crosses one public
    ;; boundary. Internal force-delay is exercised by the nested rail below.
    (check-equal? (label-count trace "force-delay") 0)
    (check-equal? (forced-count (model-session-current-config final)) 1)
    (check-equal? (model-session-current-host-answers final) '(nap))
    (check-equal? (answer-scopes final) '((0 1)))
    (define paused (findf (lambda (session) (eq? (model-session-status session) 'paused)) trace))
    (check-not-false paused)
    (check-false (final-config? (model-session-current-config paused)))
    (check-equal? (model-session-current-answer-nodes paused) '()))

  (test-case "nested rail advances exact paused Frontiers and preserves every committed prefix"
    (define trace (trace-session (open-source nested-rail-source #:source-mode "micro")))
    (define final (last trace))
    (check-equal? (model-session-current-host-answers final)
                  '(left-now right-now left-later right-later))
    (check-equal? (label-count trace "allocate-fresh") 1)
    (check-true (positive? (label-count trace "force-delay")))
    (check-equal? (forced-count (model-session-current-config final))
                  (label-count trace "advance-delay"))
    (for ([before (in-list trace)] [after (in-list (rest trace))])
      (define answers-before (model-session-current-host-answers before))
      (define answers-after (model-session-current-host-answers after))
      (check-equal? answers-before (take answers-after (length answers-before)))
      (when (eq? (model-session-status before) 'paused)
        (match-define `(program ,definitions ,frontier) (model-session-current-config before))
        (check-equal? (model-session-current-config after)
                      `(program ,definitions (advance ,frontier)))
        (check-equal? (model-session-current-step-kind after) 'public-operation)
        (check-equal? answers-after answers-before)))))

(module+ test (run-tests FRONTIER-EXAMPLES))
