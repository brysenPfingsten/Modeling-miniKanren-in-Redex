#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "../decomposition.rkt"
         "../kernel-toy.rkt"
         "../labels.rkt"
         "../refocused.rkt"
         "../refocused-spec.rkt"
         "../source.rkt"
         (prefix-in corpus:
                    "../../whole-tree-pipeline-pilot/corpus.rkt"))

(provide refocused-tests)

(define outside-work
  '(Work (put (sym "outside") (label "outside")) (state unit)))

(define witness-trees
  (list corpus:nested-scope-witness-tree
        corpus:late-hoist-witness-tree
        corpus:rail-turn-witness-tree
        corpus:right-active-fresh-witness-tree
        '(More (Work (fail (label "fail")) (state unit)))
        '(More Dead)
        `(More
          (DisjL
           (Work
            (fresh (x:q)
                   (fail (label "local-failure"))
                   (label "local-fresh"))
            (state unit))
           ,outside-work))
        '(More (Conj Dead (succeed (label "continue"))))
        `(More (DisjL Dead ,outside-work))
        `(More (DisjR ,outside-work Dead))
        `(More
          (DisjR
           ,outside-work
           (DisjL
            (Returned (state (sym "inside")))
            (Work (put (sym "later") (label "later")) (state unit)))))
        '(More
          (Work
           (suspend (put (sym "later") (label "later"))
                    (label "delay"))
           (state unit)))))

(define expected-labels
  '((expose-frontier-fresh core)
    (finish-success core)
    (finish-failure core)
    (force-delay delay)
    (commit-choice-answer disj)
    (commit-right-choice-answer search-join)
    (work-succeed core)
    (work-fail core)
    (work-put core)
    (allocate-fresh core)
    (expand-conjunction core)
    (expand-disjunction disj)
    (suspend-goal delay)
    (expose-choice-through-work-fresh disj)
    (expose-choice-through-work-fresh search-join)
    (erase-dead-fresh core)
    (bubble-delay-through-fresh delay)
    (conj-return core)
    (conj-fail core)
    (bubble-delay-through-conj delay)
    (late-distribute-settled disj)
    (late-distribute-right-settled search-join)
    (skip-left-failure disj)
    (rail-enter-right search-join)
    (reassociate-left-result disj)
    (skip-right-failure search-join)
    (rail-return-left search-join)
    (reassociate-right-result search-join)))

(define (source-successors frontier)
  (for/list ([named
              (in-list
               (apply-reduction-relation/tag-with-names source-red frontier))])
    (match-define (list name next) named)
    (list (term (redex-name->label ,(~a name))) next)))

(define (trace-states initial [limit 256] [states (list initial)])
  (match (source-successors initial)
    ['() (reverse states)]
    [(list (list _label next))
     (unless (positive? limit)
       (error 'trace-states "step cap reached"))
     (trace-states next (sub1 limit) (cons next states))]
    [other
     (error 'trace-states "nondeterministic source: ~e" other)]))

(define all-trace-states
  (remove-duplicates
   (append*
    (for/list ([initial (in-list witness-trees)])
      (trace-states initial)))))

(define (decomposition-of frontier)
  (match (judgment-holds (decompose/redex ,frontier D) D)
    [(list decomposition) decomposition]
    [other (error 'decomposition-of "unexpected results: ~e" other)]))

(define (contracts-of decomposition)
  (judgment-holds (contract/redex ,decomposition C) C))

(define (refocus-spec-results contraction)
  (judgment-holds (refocus-spec ,contraction Z) Z))

(define (refocus-direct-results contraction)
  (judgment-holds (refocus-direct ,contraction Z) Z))

(define (z-spec-successors z)
  (remove-duplicates
   (judgment-holds
    (refocused-step/spec ,z ell Z_next)
    (ell Z_next))))

(define (z-direct-successors z)
  (remove-duplicates
   (judgment-holds
    (refocused-step/direct ,z ell Z_next)
    (ell Z_next))))

(define (z-relation-successors z)
  (for/list ([named
              (in-list
               (apply-reduction-relation/tag-with-names
                refocused-red/direct
                z))])
    (match-define (list name next) named)
    (list (term (redex-name->label ,(~a name))) next)))

(define refocused-tests
  (test-suite
   "whole-tree Redex column: refocusing"

   (test-case
    "D and Z are explicit isomorphic stage grammars"
    (for ([frontier (in-list all-trace-states)])
      (define decomposition (decomposition-of frontier))
      (define z (term (D->Z ,decomposition)))
      (check-true
       (redex-match? redex-column-refocused-lang Z z))
      (check-equal? (term (Z->D ,z)) decomposition)
      (check-equal? (term (D->Z (Z->D ,z))) z)
      (check-equal? (term (readback-Z ,z)) frontier)))

   (test-case
    "direct refocusing equals plug-and-redecompose for every contraction"
    (for ([frontier (in-list all-trace-states)])
      (define decomposition (decomposition-of frontier))
      (for ([contraction (in-list (contracts-of decomposition))])
        (define spec* (refocus-spec-results contraction))
        (define direct* (refocus-direct-results contraction))
        (check-equal? (length spec*) 1 (format "~e" contraction))
        (check-equal? (length direct*) 1 (format "~e" contraction))
        (check-equal? direct* spec* (format "~e" contraction))
        (check-equal?
         (term (readback-Z ,(first direct*)))
         (term (plug-C ,contraction))))))

   (test-case
    "direct and specification refocused steps agree exactly"
    (for ([frontier (in-list all-trace-states)])
      (define z (term (D->Z ,(decomposition-of frontier))))
      (define spec* (z-spec-successors z))
      (define direct* (z-direct-successors z))
      (check-equal? direct* spec* (format "~e" frontier))
      (check-equal?
       (for/list ([successor (in-list direct*)])
         (match-define (list label z-next) successor)
         (list label (term (readback-Z ,z-next))))
       (source-successors frontier)
       (format "~e" frontier))))

   (test-case
    "named relation is the exact projection of the direct judgment"
    (for ([frontier (in-list all-trace-states)])
      (define z (term (D->Z ,(decomposition-of frontier))))
      (check-equal? (z-relation-successors z)
                    (z-direct-successors z)
                    (format "~e" frontier))))

   (test-case
    "all 28 source rule/owner marks survive refocusing"
    (define observed
      (remove-duplicates
       (append*
        (for/list ([initial (in-list witness-trees)])
          (for/list ([frontier (in-list (drop-right (trace-states initial) 1))])
            (first (first
                    (z-direct-successors
                     (term (D->Z ,(decomposition-of frontier)))))))))))
    (for ([expected (in-list expected-labels)])
      (check-not-false (member expected observed) (format "~e" expected))))

   (test-case
    "allocation refocuses to the pending More-boundary WorkFresh"
    (define initial
      '(More
        (Work
         (fresh (x:q)
                (put x:q (label "answer"))
                (label "fresh"))
         (state unit))))
    (define z0 (term (initial-Z ,initial)))
    (match-define
      (list (list allocation-label z1))
      (z-direct-successors z0))
    (check-equal? allocation-label '(allocate-fresh core))
    (check-equal?
     z1
     (term
      (ZWork
       (WorkFresh (u:0)
                  (Work (put u:0 (label "answer")) (state unit))
                  (label "fresh"))
       (More hole))))
    (check-equal?
     (first (first (z-direct-successors z1)))
     '(expose-frontier-fresh core)))

   (test-case
    "trace-carrying reachability reaches the exact final Z"
    (define initial corpus:rail-turn-witness-tree)
    (define states (trace-states initial))
    (define labels
      (for/list ([frontier (in-list (drop-right states 1))])
        (first (first (source-successors frontier)))))
    (define final-z
      (term (D->Z ,(decomposition-of (last states)))))
    (check-not-false
     (member
      (list labels final-z)
      (judgment-holds
       (reachable-refocused/via ,initial ZLabels Z)
       (ZLabels Z)))))

   (test-case
    "bounded generated contractions compare direct and slow refocusing"
    (redex-check
     redex-column-refocused-lang
     F
     (let ([frontier (term F)])
       (or (not (judgment-holds (wf-frontier/toy F)))
           (let* ([decomposition (decomposition-of frontier)]
                  [contraction* (contracts-of decomposition)])
             (for/and ([contraction (in-list contraction*)])
               (equal? (refocus-direct-results contraction)
                       (refocus-spec-results contraction))))))
     #:attempts 1000))))

(module+ test
  (run-tests refocused-tests))
