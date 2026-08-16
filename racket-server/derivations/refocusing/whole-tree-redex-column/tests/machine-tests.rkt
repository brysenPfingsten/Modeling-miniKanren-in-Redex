#lang racket

(require rackunit
         rackunit/text-ui
         racket/runtime-path
         redex/reduction-semantics
         "../decomposition.rkt"
         "../kernel-toy.rkt"
         "../labels.rkt"
         "../machine.rkt"
         "../machine-spec.rkt"
         "../refocused.rkt"
         "../refocused-spec.rkt"
         "../source.rkt"
         (prefix-in corpus:
                    "../../whole-tree-pipeline-pilot/corpus.rkt"))

(provide machine-tests)

(define-runtime-path machine-module "../machine.rkt")

(define witness-trees
  (list corpus:nested-scope-witness-tree
        corpus:late-hoist-witness-tree
        corpus:rail-turn-witness-tree
        corpus:right-active-fresh-witness-tree
        '(More (Work (fail (label "fail")) (state unit)))
        '(More Dead)))

(define (source-successors frontier)
  (for/list ([named
              (in-list
               (apply-reduction-relation/tag-with-names source-red frontier))])
    (match-define (list name next) named)
    (list (term (redex-name->label ,(~a name))) next)))

(define (trace-states initial [limit 256] [states (list initial)])
  (match (source-successors initial)
    ['() (reverse states)]
    [(list (list _ next))
     (unless (positive? limit)
       (error 'trace-states "step cap reached"))
     (trace-states next (sub1 limit) (cons next states))]))

(define all-trace-states
  (remove-duplicates
   (append*
    (for/list ([initial (in-list witness-trees)])
      (trace-states initial)))))

(define (initial-z frontier)
  (term (D->Z (decompose-one ,frontier))))

(define (z-successors z)
  ;; Deliberately retain the raw derivation list: duplicate derivations of the
  ;; same edge are a failure, not something the test harness should hide.
  (judgment-holds
   (refocused-step/direct ,z ell Z_next)
   (ell Z_next)))

(define (m-direct-successors machine)
  (judgment-holds
   (machine-step/direct ,machine ell M_next)
   (ell M_next)))

(define (m-spec-successors machine)
  (judgment-holds
   (machine-step/spec ,machine ell M_next)
   (ell M_next)))

(define (machine-refocus-query-results query)
  (judgment-holds (machine-refocus-query/direct ,query M) M))

(define (m-relation-successors machine)
  (for/list ([named
              (in-list
               (apply-reduction-relation/tag-with-names
                machine-red/direct
                machine))])
    (match-define (list name next) named)
    (list (term (redex-name->label ,(~a name))) next)))

(define (terminal-z? z)
  (redex-match? redex-column-machine-lang (ZFrontier T FF) z))

(define (terminal-machine? machine)
  (redex-match? redex-column-machine-lang (MFrontier T FF) machine))

(define (z/m-trace-from z machine [limit 256])
  (unless (equal? machine (term (encode-ZM ,z)))
    (error 'z/m-trace-from "states are outside the codec image: ~e / ~e"
           z machine))
  (define z* (z-successors z))
  (define machine* (m-direct-successors machine))
  (match* (z* machine*)
    [('() '()) (list (list z machine))]
    [((list (list label z-next))
      (list (list machine-label machine-next)))
     (unless (positive? limit)
       (error 'z/m-trace-from "step cap reached"))
     (unless (and (equal? label machine-label)
                  (equal? machine-next (term (encode-ZM ,z-next))))
       (error 'z/m-trace-from
              "Z/M traces diverged: ~e / ~e" z* machine*))
     (cons (list z machine)
           (z/m-trace-from z-next machine-next (sub1 limit)))]
    [(_ _)
     (error 'z/m-trace-from
            "non-unique or unmatched Z/M successors: ~e / ~e" z* machine*)]))

(define (z/m-trace initial)
  (z/m-trace-from (term (initial-Z ,initial))
                  (term (initial-M ,initial))))

(define (suffixes values)
  (match values
    ['() '()]
    [(cons _ rest)
     (cons values (suffixes rest))]))

(define (trace-prefix-records trace [reverse-labels '()])
  (match trace
    ['() '()]
    [(list (list z machine))
     (list (list (reverse reverse-labels) z machine))]
    [(cons (list z machine) rest)
     (match (z-successors z)
       [(list (list label _))
        (cons (list (reverse reverse-labels) z machine)
              (trace-prefix-records rest
                                    (cons label reverse-labels)))]
       [other
        (error 'trace-prefix-records
               "trace has a tail but its Z state has successors ~e" other)])]))

(define (canonical-order values)
  (sort values string<? #:key (lambda (value) (format "~s" value))))

(define (check-raw-exact-set actual expected message)
  (check-equal? (length actual)
                (length (remove-duplicates actual))
                (string-append message ": duplicate raw derivations"))
  (check-equal? (canonical-order actual)
                (canonical-order expected)
                message))

(define (machine-module-require-form)
  (define module-datum
    (call-with-input-file machine-module
      (lambda (input)
        (parameterize ([read-accept-reader #t])
          (syntax->datum (read-syntax machine-module input))))))
  (match module-datum
    [`(module ,_ ,_ (#%module-begin ,forms ...))
     (match (filter (lambda (form)
                      (and (pair? form) (eq? (first form) 'require)))
                    forms)
       [(list require-form) require-form]
       [other
        (error 'machine-module-require-form
               "expected one require form, found ~e" other)])]
    [other
     (error 'machine-module-require-form
            "unexpected module shape: ~e" other)]))

(define machine-tests
  (test-suite
   "whole-tree Redex column: explicit marked machine"

   (test-case
    "Z/M codecs round trip on the source-decomposition image"
    (for ([frontier (in-list all-trace-states)])
      (define z (initial-z frontier))
      (define machine (term (encode-ZM ,z)))
      (check-true (redex-match? redex-column-machine-lang M machine))
      (check-equal? (term (decode-MZ ,machine)) z)
      (check-equal? (term (encode-ZM (decode-MZ ,machine))) machine)
      (check-equal? (term (readback-M ,machine)) frontier)
      (check-equal?
       (judgment-holds (machine-corresponds ,z M) M)
       (list machine))))

   (test-case
    "bounded raw Z and M terms satisfy both codec inverse laws"
    (redex-check
     redex-column-machine-lang
     Z
     (let ([z (term Z)])
       (equal? (term (decode-MZ (encode-ZM ,z))) z))
     #:attempts 1000)
    (redex-check
     redex-column-machine-lang
     M
     (let ([machine (term M)])
       (equal? (term (encode-ZM (decode-MZ ,machine))) machine))
     #:attempts 1000))

   (test-case
    "the direct machine query grammar is total and single-valued"
    (redex-check
     redex-column-machine-lang
     MQ
     (= (length
         (machine-refocus-query-results (term MQ)))
        1)
     #:attempts 1000))

   (test-case
    "transported and independently direct machine successors coincide"
    (for ([frontier (in-list all-trace-states)])
      (define machine (term (initial-M ,frontier)))
      (check-equal? (m-direct-successors machine)
                    (m-spec-successors machine)
                    (format "~e" frontier))
      (check-equal?
       (for/list ([successor (in-list (m-direct-successors machine))])
         (match-define (list label next) successor)
         (list label (term (readback-M ,next))))
       (source-successors frontier)
       (format "~e" frontier))))

   (test-case
    "commuting-square judgment witnesses preservation and reflection"
    (for ([frontier (in-list all-trace-states)])
      (define z (initial-z frontier))
      (define square*
        (judgment-holds
         (ZM-step-square ,z ell Z_next M_0 M_1)
         (ell Z_next M_0 M_1)))
      (define expected
        (for/list ([successor (in-list (z-successors z))])
          (match-define (list label z-next) successor)
          (list label
                z-next
                (term (encode-ZM ,z))
                (term (encode-ZM ,z-next)))))
      (check-equal? square* expected (format "~e" frontier))))

   (test-case
    "named machine relation projects the direct judgment exactly"
    (for ([frontier (in-list all-trace-states)])
      (define machine (term (initial-M ,frontier)))
      (check-equal? (m-relation-successors machine)
                    (m-direct-successors machine)
                    (format "~e" frontier))))

   (test-case
    "paired Z/M traces are suffix closed and have the exact reachable image"
    (for ([initial (in-list witness-trees)])
      (define trace (z/m-trace initial))
      (for ([suffix (in-list (suffixes trace))])
        (match-define (cons (list z machine) _) suffix)
        (check-equal? (z/m-trace-from z machine)
                      suffix
                      (format "suffix from ~e" machine)))

      (define prefixes (trace-prefix-records trace))
      (define expected-z
        (for/list ([prefix (in-list prefixes)])
          (match-define (list labels z _) prefix)
          (list labels z)))
      (define expected-machines
        (for/list ([prefix (in-list prefixes)])
          (match-define (list labels _ machine) prefix)
          (list labels machine)))
      (define reachable-z
        (judgment-holds
         (reachable-refocused/via ,initial ZLabels Z)
         (ZLabels Z)))
      (define reachable-machines
        (judgment-holds
         (reachable-machine/via ,initial MLabels M)
         (MLabels M)))

      (check-raw-exact-set reachable-z
                           expected-z
                           (format "reachable Z from ~e" initial))
      (check-raw-exact-set reachable-machines
                           expected-machines
                           (format "reachable M from ~e" initial))
      (check-raw-exact-set
       reachable-machines
       (for/list ([reachable (in-list reachable-z)])
         (match-define (list labels z) reachable)
         (list labels (term (encode-ZM ,z))))
       (format "reachable codec image from ~e" initial))))

   (test-case
    "reachable terminal states are exactly the no-step terminal readbacks"
    (for* ([initial (in-list witness-trees)]
           [pair (in-list (z/m-trace initial))])
      (match-define (list z machine) pair)
      (define z-terminal?* (terminal-z? z))
      (define machine-terminal?* (terminal-machine? machine))
      (define z-readback (term (readback-Z ,z)))
      (define machine-readback (term (readback-M ,machine)))
      (check-equal? machine-terminal?* z-terminal?*)
      (check-equal? machine-readback z-readback)
      (check-equal? machine-terminal?*
                    (redex-match? redex-column-machine-lang V machine-readback))
      (check-equal? machine-terminal?*
                    (null? (m-direct-successors machine)))
      (check-equal? z-terminal?*
                    (null? (z-successors z)))
      (check-equal? machine-terminal?*
                    (null? (source-successors machine-readback)))))

   (test-case
    "reachable states have unique exact Z and M derivations"
    (for* ([initial (in-list witness-trees)]
           [pair (in-list (z/m-trace initial))])
      (match-define (list z machine) pair)
      (define expected-count (if (terminal-machine? machine) 0 1))
      (define z* (z-successors z))
      (define direct* (m-direct-successors machine))
      (define spec* (m-spec-successors machine))
      (define relation* (m-relation-successors machine))
      (check-equal? (length z*) expected-count (format "Z: ~e" z))
      (check-equal? (length direct*) expected-count
                    (format "direct M: ~e" machine))
      (check-equal? (length spec*) expected-count
                    (format "spec M: ~e" machine))
      (check-equal? (length relation*) expected-count
                    (format "relation M: ~e" machine))
      (check-equal? direct* spec* (format "~e" machine))
      (check-equal? direct* relation* (format "~e" machine))
      (check-equal?
       (judgment-holds (machine-corresponds ,z M) M)
       (list machine)
       (format "correspondence: ~e" z)))

    ;; The exact M grammar now rejects the unfocused pair admitted by the
    ;; earlier broad W/WF product.
    (define unfocused-machine
      (term
       (MWork
        (Conj (Work (succeed (label "inside")) (state unit))
              (fail (label "after")))
        (More hole))))
    (check-false
     (redex-match? redex-column-machine-lang M unfocused-machine)))

   (test-case
    "every raw M state has the exact expected successor count"
    (redex-check
     redex-column-machine-lang
     M
     (let* ([machine (term M)]
            [expected-count (if (terminal-machine? machine) 0 1)]
            [direct* (m-direct-successors machine)]
            [spec* (m-spec-successors machine)]
            [relation* (m-relation-successors machine)])
       (and (= (length direct*) expected-count)
            (= (length spec*) expected-count)
            (= (length relation*) expected-count)
            (equal? direct* spec*)
            (equal? direct* relation*)))
     #:attempts 1000))

   (test-case
    "direct machine module has only the declared lower-stage dependencies"
    (check-equal?
     (machine-module-require-form)
     '(require
       redex/reduction-semantics
       (only-in "./decomposition.rkt" contract/redex contract-label)
       "./labels.rkt"
       (only-in "./refocused.rkt"
                redex-column-refocused-lang))))

   (test-case
    "trace-certified reachability reaches the exact final machine"
    (define initial corpus:nested-scope-witness-tree)
    (define states (trace-states initial))
    (define labels
      (for/list ([frontier (in-list (drop-right states 1))])
        (first (first (source-successors frontier)))))
    (define final-machine (term (initial-M ,(last states))))
    (check-not-false
     (member
      (list labels final-machine)
      (judgment-holds
       (reachable-machine/via ,initial MLabels M)
       (MLabels M)))))

   (test-case
    "bounded generated roots preserve the labeled Z/M square"
    (redex-check
     redex-column-machine-lang
     F
     (let ([frontier (term F)])
       (or (not (judgment-holds (wf-frontier/toy F)))
           (let* ([z (initial-z frontier)]
                  [machine (term (encode-ZM ,z))]
                  [z* (z-successors z)]
                  [m* (m-direct-successors machine)]
                  [spec* (m-spec-successors machine)])
             (and (<= (length z*) 1)
                  (<= (length m*) 1)
                  (equal? m* spec*)
                  (equal?
                   m*
                   (for/list ([successor (in-list z*)])
                     (match-define (list label z-next) successor)
                     (list label (term (encode-ZM ,z-next)))))))))
     #:attempts 1000))))

(module+ test
  (run-tests machine-tests))
