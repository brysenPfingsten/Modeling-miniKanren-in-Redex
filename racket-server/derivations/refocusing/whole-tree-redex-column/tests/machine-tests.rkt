#lang racket

(require rackunit
         rackunit/text-ui
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
  (remove-duplicates
   (judgment-holds
    (refocused-step/direct ,z ell Z_next)
    (ell Z_next))))

(define (m-direct-successors machine)
  (remove-duplicates
   (judgment-holds
    (machine-step/direct ,machine ell M_next)
    (ell M_next))))

(define (m-spec-successors machine)
  (remove-duplicates
   (judgment-holds
    (machine-step/spec ,machine ell M_next)
    (ell M_next))))

(define (m-relation-successors machine)
  (for/list ([named
              (in-list
               (apply-reduction-relation/tag-with-names
                machine-red/direct
                machine))])
    (match-define (list name next) named)
    (list (term (redex-name->label ,(~a name))) next)))

(define machine-tests
  (test-suite
   "whole-tree Redex column: explicit marked machine"

   (test-case
    "Z/M codecs round trip on the reachable image"
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
                  [m* (m-direct-successors machine)])
             (equal?
              m*
              (for/list ([successor (in-list z*)])
                (match-define (list label z-next) successor)
                (list label (term (encode-ZM ,z-next))))))))
     #:attempts 1000))))

(module+ test
  (run-tests machine-tests))

