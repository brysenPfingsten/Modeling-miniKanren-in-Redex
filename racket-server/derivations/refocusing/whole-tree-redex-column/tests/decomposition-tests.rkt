#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "../decomposition.rkt"
         "../kernel-toy.rkt"
         "../language.rkt"
         "../source.rkt"
         (prefix-in corpus:
                    "../../whole-tree-pipeline-pilot/corpus.rkt"))

(provide decomposition-tests)

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

(define (source-successors frontier)
  (for/list ([named
              (in-list
               (apply-reduction-relation/tag-with-names source-red frontier))])
    (match-define (list name next) named)
    (list (term (redex-name->label ,(~a name))) next)))

(define (decompositions frontier)
  (remove-duplicates
   (judgment-holds (decompose/redex ,frontier D) D)))

(define (contractions decomposition)
  (remove-duplicates
   (judgment-holds (contract/redex ,decomposition C) C)))

(define (contract-source-successors frontier)
  (for*/list ([decomposition (in-list (decompositions frontier))]
              [contraction (in-list (contractions decomposition))])
    (list (term (contract-label ,contraction))
          (term (plug-C ,contraction)))))

(define (spec-successors decomposition)
  (remove-duplicates
   (judgment-holds
    (decomposed-step/spec ,decomposition ell D_next)
    (ell D_next))))

(define (direct-successors decomposition)
  (for/list ([named
              (in-list
               (apply-reduction-relation/tag-with-names
                decomposed-red/direct
                decomposition))])
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

(define decomposition-tests
  (test-suite
   "whole-tree Redex column: indexed decomposition"

   (test-case
    "contexts contain real holes and retain their grammatical indices"
    (check-true
     (redex-match? redex-column-decomposition-lang
                   WW
                   (term (WorkFresh (u:0)
                                    (DisjL hole Dead)
                                    (label "scope")))))
    (check-true
     (redex-match? redex-column-decomposition-lang
                   WF
                   (term (Forced (More (Conj hole
                                             (succeed (label "k"))))))))
    (check-true
     (redex-match? redex-column-decomposition-lang
                   FF
                   (term (Emit (Answer (state unit))
                               (FrontierFresh (u:0)
                                              hole
                                              (label "scope"))))))
    (check-false
     (redex-match? redex-column-decomposition-lang WW 'ww-hole))
    (check-false
     (redex-match? redex-column-decomposition-lang FF 'ff-hole)))

   (test-case
    "decomposition is unique and reconstructs every reachable source state"
    (for ([frontier (in-list all-trace-states)])
      (define result* (decompositions frontier))
      (check-equal? (length result*) 1 (format "~e" frontier))
      (check-equal? (term (plug-D ,(first result*)))
                    frontier
                    (format "~e" frontier))))

   (test-case
    "decomposition and contraction preserve and reflect source steps"
    (for ([frontier (in-list all-trace-states)])
      (check-equal? (contract-source-successors frontier)
                    (source-successors frontier)
                    (format "~e" frontier))))

   (test-case
    "direct and compositional decomposed relations have identical successors"
    (for ([frontier (in-list all-trace-states)])
      (define decomposition (first (decompositions frontier)))
      (define spec* (spec-successors decomposition))
      (define direct* (direct-successors decomposition))
      (check-equal? direct* spec* (format "~e" frontier))
      (check-equal?
       (for/list ([successor (in-list direct*)])
         (match-define (list label next) successor)
         (list label (term (plug-D ,next))))
       (source-successors frontier)
       (format "~e" frontier))))

   (test-case
    "reachable corpus locks all 28 valid rule/owner pairs"
    (define observed
      (remove-duplicates
       (append*
        (for/list ([frontier (in-list all-trace-states)])
          (for/list ([successor (in-list (source-successors frontier))])
            (first successor))))))
    (check-equal? (length observed) 28)
    (for ([label (in-list observed)])
      (check-true (label-in-language? label) (format "~e" label))))

   (test-case
    "boundary and branch-local fresh decompositions select different contexts"
    (define success '(Returned (state unit)))
    (define alternate
      '(Work (put (sym "later") (label "later")) (state unit)))
    (define fresh-choice
      `(WorkFresh (u:0)
                  (DisjL ,success ,alternate)
                  (label "fresh")))
    (define boundary-tree `(Forced (More ,fresh-choice)))
    (define local-tree `(More (DisjL ,fresh-choice ,outside-work)))
    (define boundary-D (first (decompositions boundary-tree)))
    (define local-D (first (decompositions local-tree)))
    (check-equal?
     boundary-D
     (term
      (DecWork
       ,fresh-choice
       (Forced (More hole)))))
    (check-equal?
     local-D
     (term
      (DecWork
       ,fresh-choice
       (More (DisjL hole ,outside-work)))))
    (check-equal?
     (term (contract-label ,(first (contractions boundary-D))))
     '(expose-frontier-fresh core))
    (check-equal?
     (term (contract-label ,(first (contractions local-D))))
     '(expose-choice-through-work-fresh disj)))

   (test-case
    "trace-carrying reachability witnesses the exact final decomposition"
    (define initial corpus:nested-scope-witness-tree)
    (define states (trace-states initial))
    (define labels
      (for/list ([frontier (in-list (drop-right states 1))])
        (first (first (source-successors frontier)))))
    (define final-D (first (decompositions (last states))))
    (check-not-false
     (member
      (list labels final-D)
      (judgment-holds
       (reachable-decomposition/via ,initial Labels D)
       (Labels D)))))

   (test-case
    "bounded Redex generation asks totality, uniqueness, and reconstruction"
    (redex-check
     redex-column-decomposition-lang
     F
     (let ([frontier (term F)])
       (or (not (judgment-holds (wf-frontier/toy F)))
           (match (decompositions frontier)
             [(list decomposition)
              (equal? (term (plug-D ,decomposition)) frontier)]
             [_ #f])))
     #:attempts 1000))

   (test-case
    "bounded Redex generation asks the full source/contract iff"
    (redex-check
     redex-column-decomposition-lang
     F
     (let ([frontier (term F)])
       (or (not (judgment-holds (wf-frontier/toy F)))
           (equal? (contract-source-successors frontier)
                   (source-successors frontier))))
     #:attempts 1000))

   (test-case
    "bounded Redex generation compares direct and compositional D steps"
    (redex-check
     redex-column-decomposition-lang
     F
     (let ([frontier (term F)])
       (or (not (judgment-holds (wf-frontier/toy F)))
           (let* ([decomposition (first (decompositions frontier))]
                  [direct* (direct-successors decomposition)]
                  [spec* (spec-successors decomposition)])
             (and
              (equal? direct* spec*)
              (equal?
               (for/list ([successor (in-list direct*)])
                 (match-define (list label next) successor)
                 (list label (term (plug-D ,next))))
               (source-successors frontier))))))
     #:attempts 1000))))

(module+ test
  (run-tests decomposition-tests))
