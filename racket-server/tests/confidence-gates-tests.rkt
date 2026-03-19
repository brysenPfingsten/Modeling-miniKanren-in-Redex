#lang racket

(require rackunit
         rackunit/text-ui
         racket/match
         racket/string
         json
         web-server/http/response-structs
         "../src/app.rkt"
         "../src/zipper.rkt"
         "../src/transpiler.rkt"
         "../src/sexpr-read.rkt"
         "../src/model-registry.rkt"
         "./test-http-helpers.rkt"
         "./variant-test-support.rkt"
         "./example-compat-tests.rkt")

(provide CONFIDENCE-GATES)

(define TRACE-STEP-CAP 30)

(define (example-src label)
  (for/first ([pr (in-list (frontend-example-programs))]
              #:do [(match-define (cons example-label src) pr)]
              #:when (equal? example-label label))
    src))

(define (trace-steps model-id label)
  (define src (example-src label))
  (unless src
    (error 'trace-steps (format "missing example label: ~a" label)))
  (define-values (cfg0 _html)
    (parse-prog/canonical (read-all-sexprs (open-input-string src))))
  (define step-once (lookup-model-step-once model-id))
  (unless step-once
    (error 'trace-steps (format "unknown model id: ~a" model-id)))
  (let loop ([cfg cfg0] [i 0] [acc '()])
    (define next* (step-once cfg))
    (cond
      [(null? next*)
       (values (reverse acc) (if (final-config? cfg) 'value 'stuck) cfg)]
      [(>= i TRACE-STEP-CAP)
       (values (reverse acc) 'cap cfg)]
      [else
       (match-define (list nm cfg1) (first next*))
       (loop cfg1 (add1 i) (cons nm acc))])))

(define (named-step? nm)
  (and (string? nm)
       (> (string-length (string-trim nm)) 0)))

(define (length+last steps)
  (for/fold ([count 0]
             [last-step "<none>"])
            ([nm (in-list steps)])
    (values (add1 count) nm)))

(define GOLDEN-PREFIXES
  (list
   (list "l0-core"
         "core/fresh+conj+unify"
         '("l0/fresh-substitute"
           "l0/fresh-substitute"
           "l0/conj-distribute-state"
           "l0/conj-distribute-state"
           "l0/conj-distribute-state"
           "l0/unify-success"
           "l0/conj-bring-success"
           "l0/unify-success"))
   (list "l4-rail-lazy"
         "appendoh 1"
         '("l0/fresh-substitute"
           "l3-base/lazy-expand"
           "l3-base/suspend-goal"
           "l3-base/invoke-delay"
           "l3-base/goal-to-tree"
           "l0/conj-distribute-state"
           "l0/unify-fail"
           "l0/conj-prune-fail"
           "l3-base/skip-left-fail"
           "l0/fresh-substitute"))
   (list "l4-rail-lazy"
         "fives/fours"
         '("l0/fresh-substitute"
           "l3-base/goal-to-tree"
           "l3-base/lazy-expand"
           "l3-base/suspend-goal"
           "l4-rail/enter-right"
           "l3-base/invoke-delay"
           "l3-base/lazy-expand"
           "l3-base/suspend-goal"
           "l4-rail/return-left"
           "l3-base/invoke-delay"))
   (list "l3-flip-lazy"
         "fives/fours"
         '("l0/fresh-substitute"
           "l3-base/goal-to-tree"
           "l3-base/lazy-expand"
           "l3-base/suspend-goal"
           "l3-flip/delay-swap-left"
           "l3-base/invoke-delay"
           "l3-base/lazy-expand"
           "l3-base/suspend-goal"
           "l3-flip/delay-swap-left"
           "l3-base/invoke-delay"))
   (list "l3-dfs-lazy"
         "same"
         '("l0/fresh-substitute"
           "l3-base/goal-to-tree"
           "l3-base/goal-to-tree"
           "l3-base/lazy-expand"
           "l3-base/suspend-goal"
           "l3-dfs/delay-through-left"
           "l3-dfs/delay-through-left"
           "l3-base/invoke-delay"
           "l0/unify-success"
           "l3-base/bubble-left-answer"))))

(define/provide-test-suite CONFIDENCE-GATES
  (test-case "golden trace prefixes stay stable and step names are always named"
    (for ([entry (in-list GOLDEN-PREFIXES)])
      (match-define (list model-id label expected-prefix) entry)
      (define-values (steps status final-cfg) (trace-steps model-id label))
      (define-values (step-count last-step) (length+last steps))
      (check-true (or (eq? status 'value) (eq? status 'cap))
                  (format "~a / ~a unexpectedly ~a (steps=~a last=~a cfg=~s)"
                          model-id
                          label
                          status
                          step-count
                          last-step
                          final-cfg))
      (for ([nm (in-list steps)]
            [idx (in-naturals 1)])
        (check-true (named-step? nm)
                    (format "~a / ~a has unnamed step at position ~a: ~v"
                            model-id label idx nm)))

      (define expected-count (length expected-prefix))
      (check-true (>= step-count expected-count)
                  (format "~a / ~a produced too few steps: got ~a, expected >= ~a"
                          model-id label step-count expected-count))
      (check-equal? (take steps expected-count)
                    expected-prefix
                    (format "~a / ~a prefix drifted" model-id label))))

  (test-case "init/step payloads satisfy UI contract for canonical programs"
    (define pairs
      (list (list "l4-rail-lazy" "appendoh 1")
            (list "l3-flip-lazy" "fives/fours")
            (list "l3-dfs-lazy" "same")))
    (for ([pr (in-list pairs)])
      (match-define (list model-id label) pr)
      (define src (example-src label))
      (define ses
        (session (zipper '() #f '() 0)
                 (make-stepper (lookup-model-step-once default-model-id))
                 1))
      (define init-resp (init! ses (make-post-init-request src #:model model-id) 'shape-id))
      (check-equal? (response-code init-resp) 200
                    (format "init failed for ~a / ~a" model-id label))
      (check-equal? (session-model-id ses) model-id
                    (format "session model binding drifted for ~a / ~a" model-id label))
      (assert-step-payload-shape (string->jsexpr (response-body->string init-resp))
                                 (format "~a / ~a init" model-id label))
      (define seen 0)
      (for ([i (in-range 25)])
        (define step-resp (step! ses))
        (define body (response-body->string step-resp))
        (unless (string=? body "null")
          (set! seen (add1 seen))
          (assert-step-payload-shape (string->jsexpr body)
                                     (format "~a / ~a step ~a" model-id label i))))
      (check-true (> seen 0)
                  (format "~a / ~a produced no non-null steps" model-id label)))))

(module+ test
  (run-tests CONFIDENCE-GATES))
