#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         (prefix-in red:
                    "../../../src/search-lattice/reduction-relations/all.rkt")
         (prefix-in distributed:
                    "../../../derivations/distributed-search/all.rkt")
         (prefix-in lang:
                    "../../../src/search-lattice/languages/all.rkt")
         (prefix-in wf:
                    "../../../src/search-lattice/wf/all.rkt")
         "../../../src/search-runtime.rkt"
         "../../../src/search-strategy.rkt"
         "../../../src/sexpr-read.rkt"
         "../../../src/transpiler.rkt"
         "../../example-compat-tests.rkt"
         "../../frontier-observable-support.rkt"
         "../../search-lattice-support.rkt")

(provide WF-PRESERVATION)

(define TRACE-CAP 64)

(define cfg-core-fresh
  (term (More
         (Work (Owners)
          (∃ (x:0)
             ((x:0 =? (sym "fresh") (label "eq-1"))
              ∧
              (x:0 =? (sym "fresh") (label "eq-2"))
              (label "and-0"))
             (label "ex-0"))
          (state () () () (label "s"))))))

(define (example-src label)
  (for/first ([pr (in-list (frontend-example-programs))]
              #:do [(match-define (cons example-label src) pr)]
              #:when (equal? example-label label))
    src))

(define (example-cfg label)
  (define src (example-src label))
  (unless src
    (error 'example-cfg "missing example label: ~a" label))
  (define-values (config _html)
    (parse-prog/canonical (read-all-sexprs (open-input-string src))))
  config)

(define (example-frontier label)
  (match (example-cfg label)
    [`(() ,frontier) frontier]
    [cfg
     (error 'example-frontier
            "expected an empty-Γ config for ~a, got ~s"
            label
            cfg)]))

(define (trace-summary stepper
                       invariant?
                       cfg
                       [remaining TRACE-CAP]
                       [steps 0]
                       [last-step "<start>"])
  (cond
    [(negative? remaining)
     (values 'cap steps last-step cfg)]
    [(not (invariant? cfg))
     (values 'invariant-fail steps last-step cfg)]
    [else
     (match (stepper cfg)
       ['()
        (values (if (final-program? cfg) 'value 'stuck)
                steps
                last-step
                cfg)]
       [(list (list name cfg^))
        (trace-summary stepper
                       invariant?
                       cfg^
                       (sub1 remaining)
                       (add1 steps)
                       (~a name))]
       [_ (values 'nondeterministic steps last-step cfg)])]))

(define (check-trace-invariant label stepper invariant? cfg)
  (define-values (status steps last-step final-cfg)
    (trace-summary stepper invariant? cfg))
  (check-true (or (eq? status 'value) (eq? status 'cap))
              (format "~a failed (~a after ~a steps, last=~a, cfg=~s)"
                      label
                      status
                      steps
                      last-step
                      final-cfg)))

(define (check-finite-trace-invariant label stepper invariant? cfg)
  (define-values (status steps last-step final-cfg)
    (trace-summary stepper invariant? cfg))
  (check-equal? status
                'value
                (format "~a failed (~a after ~a steps, last=~a, cfg=~s)"
                        label
                        status
                        steps
                        last-step
                        final-cfg)))

(define cfg-core-fresh-fail
  (term
   (More
    (Work (Owners)
     (∃ (x:0)
        ((x:0 =? (sym "cat") (label "eq-left"))
         ∧
         (x:0 =? (sym "dog") (label "eq-right"))
         (label "and"))
        (label "fresh"))
     ,sigma-s))))

(define cfg-double-delay
  (term
   (More
    (Work (Owners)
     (suspend
      (suspend (succeed (label "inner"))
               (label "zz-inner"))
      (label "zz-outer"))
     ,sigma-s))))

(define cfg-fresh-inside-delay
  (term
   (More
    (Work (Owners)
     (suspend
      (∃ (x:0)
         (x:0 =? (sym "nap") (label "eq"))
         (label "fresh"))
      (label "zz"))
     ,sigma-s))))

(define cfg-delay-inside-fresh
  (term
   (More
    (Work (Owners)
     (∃ (x:0)
        (suspend (x:0 =? (sym "nap") (label "eq"))
                 (label "zz"))
        (label "fresh"))
     ,sigma-s))))

(define (core-trace-invariant? cfg)
  (and (judgment-holds (wf:wf-cfg/core? ,cfg))
       (redex-match? lang:core-lang F cfg)
       (produced-answer-spine-only? cfg)
       (structurally-well-formed? cfg)))

(define (delay-trace-invariant? cfg)
  (and (judgment-holds (wf:wf-cfg/delay? ,cfg))
       (redex-match? lang:delay-lang F cfg)
       (produced-answer-spine-only? cfg)
       (structurally-well-formed? cfg)))

(define (only-successor relation cfg)
  (match (apply-reduction-relation relation cfg)
    [(list cfg^) cfg^]
    [other
     (error 'only-successor
            "expected one successor for ~s, got ~s"
            cfg
            other)]))

(define internal-trace-cases
  (list
   (list "core"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:core-red cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-cfg/core? ,cfg))
                (produced-answer-spine-only? cfg)))
         cfg-core-fresh)
   (list "delay"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:delay-red cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-cfg/delay? ,cfg))
                (produced-answer-spine-only? cfg)))
         cfg-delay-goal)
   (list "disjunction/factored"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:disj-red cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-cfg/disj? ,cfg))
                (redex-match? lang:disj-lang F cfg)
                (produced-answer-spine-only? cfg)))
         cfg-mixed-answer)
   (list "search/distributed"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names
            distributed:search-distributed-red
            cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-cfg/rail? ,cfg))
                (redex-match? lang:rail-lang F cfg)
                (produced-answer-spine-only? cfg)))
         cfg-disj)
   (list "search/factored"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:search-red cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-cfg/search? ,cfg))
                (produced-answer-spine-only? cfg)))
         cfg-disj)
   (list "search-dfs/factored"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:search-dfs-red cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-cfg/search? ,cfg))
                (redex-match? lang:search-lang F cfg)
                (produced-answer-spine-only? cfg)))
         cfg-flip)
   (list "search-flip/factored"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:search-flip-red cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-cfg/search? ,cfg))
                (redex-match? lang:search-lang F cfg)
                (produced-answer-spine-only? cfg)))
         cfg-flip)
   (list "rail/distributed"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names
            distributed:rail-distributed-red
            cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-cfg/rail? ,cfg))
                (redex-match? lang:rail-lang F cfg)
                (produced-answer-spine-only? cfg)))
         cfg-rail)
   (list "rail/factored"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:rail-red cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-cfg/rail? ,cfg))
                (redex-match? lang:rail-lang F cfg)
                (produced-answer-spine-only? cfg)))
         cfg-rail)
   (list "relcall"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:relcall-red cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-config/relcall? ,cfg))
                (produced-answer-spine-only? cfg)))
         cfg-call)
   (list "search-dfs/distributed-relcall"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names
            distributed:search-dfs-distributed-relcall-red
            cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-config/rail-relcall? ,cfg))
                (redex-match? lang:rail-relcall-lang config cfg)
                (produced-answer-spine-only? cfg)))
         cfg-call-branch)
   (list "search-dfs/factored-relcall"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names
            red:search-dfs-relcall-red
            cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-config/search-relcall? ,cfg))
                (produced-answer-spine-only? cfg)))
         cfg-call-branch)
   (list "search-flip/distributed-relcall"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names
            distributed:search-flip-distributed-relcall-red
            cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-config/rail-relcall? ,cfg))
                (redex-match? lang:rail-relcall-lang config cfg)
                (produced-answer-spine-only? cfg)))
         cfg-call-branch)
   (list "search-flip/factored-relcall"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names
            red:search-flip-relcall-red
            cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-config/search-relcall? ,cfg))
                (produced-answer-spine-only? cfg)))
         cfg-call-branch)
   (list "rail/distributed-relcall"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names
            distributed:rail-distributed-relcall-red
            cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-config/rail-relcall? ,cfg))
                (redex-match? lang:rail-relcall-lang config cfg)
                (produced-answer-spine-only? cfg)))
         cfg-call-rail)
   (list "rail/factored-relcall"
         (lambda (cfg)
           (apply-reduction-relation/tag-with-names red:rail-relcall-red cfg))
         (lambda (cfg)
           (and (judgment-holds (wf:wf-config/rail-relcall? ,cfg))
                (redex-match? lang:rail-relcall-lang config cfg)
                (produced-answer-spine-only? cfg)))
         cfg-call-rail)))

(define surfaced-trace-cases
  (for*/list ([strategy (in-list all-surfaced-search-strategies)]
              [label (in-list '("same"
                                "fresh branch disj"
                                "fives/fours"))])
    (list strategy
          label
          (example-cfg label))))

(define rail-right-active-witness
  (term
   (More
    (DisjR (Owners)
           (Dead (Owners))
           (PendingDelay (Owners) (Dead (Owners)))))))

(define/provide-test-suite WF-PRESERVATION
  (test-case "ordinary production search excludes right-active rail syntax"
    (check-false (redex-match? lang:search-lang F rail-right-active-witness))
    ;; A term outside search-lang is outside the search-WF judgment's contract,
    ;; rather than a grammatical input for which the judgment returns false.
    (check-exn
     #rx"judgment input values do not match its contract"
     (lambda ()
       (judgment-holds (wf:wf-cfg/search? ,rail-right-active-witness))))
    (check-true (redex-match? lang:rail-lang F rail-right-active-witness))
    (check-true
     (judgment-holds (wf:wf-cfg/rail? ,rail-right-active-witness)))
    (check-true
     (redex-match? distributed:distributed-search-lang
                   F
                   rail-right-active-witness))
    (define rail-relcall-witness
      (term (() ,rail-right-active-witness)))
    (check-false
     (redex-match? lang:search-relcall-lang config rail-relcall-witness))
    (check-exn
     #rx"judgment input values do not match its contract"
     (lambda ()
       (judgment-holds
        (wf:wf-config/search-relcall? ,rail-relcall-witness))))
    (check-true
     (redex-match? lang:rail-relcall-lang config rail-relcall-witness))
    (check-true
     (judgment-holds
      (wf:wf-config/rail-relcall? ,rail-relcall-witness)))
    (check-true
     (redex-match? distributed:distributed-search-relcall-lang
                   config
                   rail-relcall-witness)))

  (test-case "representative internal traces preserve wf and exact ownership"
    (for ([entry (in-list internal-trace-cases)])
      (match-define (list label stepper invariant? cfg) entry)
      (check-trace-invariant label stepper invariant? cfg)))

  (test-case "surfaced runtime traces stay inside the selected strategy domain"
    (for ([entry (in-list surfaced-trace-cases)])
      (match-define (list strategy label cfg0) entry)
      (check-trace-invariant
       (format "~a / ~a" (search-strategy->jsexpr strategy) label)
       (lookup-search-step-once strategy)
       (lambda (cfg)
         (and (search-config-in-domain? strategy cfg)
              (produced-answer-spine-only? cfg)))
       cfg0)))

  (test-case "core representative traces preserve WF and structural ownership"
    (for ([entry
           (in-list
            (list (list "fresh witness"
                        (example-frontier "fresh witness"))
                  (list "core/fresh+conj+unify"
                        (example-frontier "core/fresh+conj+unify"))
                  (list "fresh/unification failure"
                        cfg-core-fresh-fail)))])
      (match-define (list label cfg) entry)
      (check-finite-trace-invariant
       label
       (lambda (current)
         (apply-reduction-relation/tag-with-names red:core-red current))
       core-trace-invariant?
       cfg)))

  (test-case "nested-delay trace preserves WF and structural ownership"
    (check-finite-trace-invariant
     "nested delay"
     (lambda (current)
       (apply-reduction-relation/tag-with-names red:delay-red current))
     delay-trace-invariant?
     cfg-double-delay))

  (test-case "fresh and delay traces preserve WF in either nesting order"
    (for ([entry
           (in-list
            (list (list "fresh inside delay" cfg-fresh-inside-delay)
                  (list "delay inside fresh" cfg-delay-inside-fresh)))])
      (match-define (list label cfg) entry)
      (check-finite-trace-invariant
       label
       (lambda (current)
         (apply-reduction-relation/tag-with-names red:delay-red current))
       delay-trace-invariant?
       cfg)))

  (test-case "Forced choice intermediates satisfy each presentation's WF"
    (define forced-branch
      (term
       (Forced (Owners)
        (More
         (DisjL (Owners)
                (DisjL (Owners)
                       (Returned (Owners) ,sigma-a)
                       (Dead (Owners)))
                (Returned (Owners) ,sigma-b))))))
    (define prefixed-forced
      (term
       (Forced (Owners)
        (Emit (Owners)
              (Answer (Owners) ,sigma-a)
              (More
               (DisjL (Owners)
                      (Returned (Owners) ,sigma-b)
                      (Dead (Owners))))))))
    (for ([entry
           (in-list
            (list
             (list distributed:search-distributed-red
                   (lambda (cfg)
                     (judgment-holds (wf:wf-cfg/rail? ,cfg))))
             (list red:search-red
                   (lambda (cfg)
                     (judgment-holds (wf:wf-cfg/search? ,cfg))))))])
      (match-define (list relation wf?) entry)
      (define reassociated
        (only-successor relation forced-branch))
      (define committed
        (only-successor relation reassociated))
      (define prefixed-next
        (only-successor relation prefixed-forced))
      (check-true (wf? reassociated))
      (check-true (wf? committed))
      (check-true (wf? prefixed-next)))))

(module+ test
  (run-tests WF-PRESERVATION))
