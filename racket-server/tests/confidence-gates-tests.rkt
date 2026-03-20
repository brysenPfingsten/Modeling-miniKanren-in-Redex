#lang racket

(require rackunit
         rackunit/text-ui
         racket/match
         racket/string
         json
         web-server/http/response-structs
         "../src/app.rkt"
         "../src/search-runtime.rkt"
         "../src/search-strategy.rkt"
         "../src/zipper.rkt"
         "../src/transpiler.rkt"
         "../src/sexpr-read.rkt"
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

(define (strategy-label strategy)
  (format "~a/~a"
          (search-strategy-hoist strategy)
          (search-strategy-scheduler strategy)))

(define (trace-steps strategy label [compile-profile #f])
  (define src (example-src label))
  (unless src
    (error 'trace-steps (format "missing example label: ~a" label)))
  (define-values (cfg0 _html)
    (parse-prog/canonical (read-all-sexprs (open-input-string src))
                          #:compile-profile compile-profile))
  (define step-once (lookup-search-step-once strategy))
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

(define REPRESENTATIVE-TRACES
  (list
   (list (search-strategy "early" "rail")
         "fives/fours"
         #f
         "rail-seq-calls/enter-right")
   (list (search-strategy "late" "flip")
         "fives/fours"
         #f
         "search-flip-fused-calls/delay-swap-left")
   (list (search-strategy "late" "dfs")
         "same"
         (hasheq 'conjAssoc "left"
                 'disjAssoc "right"
                 'delayPlacement "relcall")
         "search-base-fused-calls/expand")))

(define/provide-test-suite CONFIDENCE-GATES
  (test-case "representative structured strategies stay live and produce named search-lattice rules"
    (for ([entry (in-list REPRESENTATIVE-TRACES)])
      (match-define (list strategy label compile-profile required-step) entry)
      (define-values (steps status final-cfg) (trace-steps strategy label compile-profile))
      (define-values (step-count last-step) (length+last steps))
      (check-true (or (eq? status 'value) (eq? status 'cap))
                  (format "~a / ~a unexpectedly ~a (steps=~a last=~a cfg=~s)"
                          (strategy-label strategy)
                          label
                          status
                          step-count
                          last-step
                          final-cfg))
      (for ([nm (in-list steps)]
            [idx (in-naturals 1)])
        (check-true (named-step? nm)
                    (format "~a / ~a has unnamed step at position ~a: ~v"
                            (strategy-label strategy) label idx nm)))
      (check-not-false (member required-step steps)
                       (format "~a / ~a missing representative step ~a"
                               (strategy-label strategy)
                               label
                               required-step))))

  (test-case "init/step payloads satisfy UI contract for structured search strategies"
    (define pairs
      (list (list (search-strategy "early" "rail") "appendoh 1")
            (list (search-strategy "late" "flip") "fives/fours")
            (list (search-strategy "late" "dfs") "same")))
    (for ([pr (in-list pairs)])
      (match-define (list strategy label) pr)
      (define src (example-src label))
      (define ses
        (session (zipper '() #f '() 0)
                 (make-stepper (lookup-search-step-once default-search-strategy))
                 1))
      (define init-resp (init! ses (make-post-init-request src #:strategy strategy) 'shape-id))
      (check-equal? (response-code init-resp) 200
                    (format "init failed for ~a / ~a" (strategy-label strategy) label))
      (check-equal? (session-search-strategy ses) strategy
                    (format "session strategy binding drifted for ~a / ~a"
                            (strategy-label strategy)
                            label))
      (assert-step-payload-shape (string->jsexpr (response-body->string init-resp))
                                 (format "~a / ~a init" (strategy-label strategy) label))
      (define seen 0)
      (for ([i (in-range 25)])
        (define step-resp (step! ses))
        (define body (response-body->string step-resp))
        (unless (string=? body "null")
          (set! seen (add1 seen))
          (assert-step-payload-shape (string->jsexpr body)
                                     (format "~a / ~a step ~a"
                                             (strategy-label strategy)
                                             label
                                             i))))
      (check-true (> seen 0)
                  (format "~a / ~a produced no non-null steps"
                          (strategy-label strategy)
                          label)))))

(module+ test
  (run-tests CONFIDENCE-GATES))
