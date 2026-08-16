#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "../kernel-toy.rkt"
         "../language.rkt"
         "../source.rkt"
         (prefix-in oracle:
                    "../../whole-tree-pipeline-pilot/source.rkt")
         (prefix-in corpus:
                    "../../whole-tree-pipeline-pilot/corpus.rkt"))

(provide source-tests)

(define witness-trees
  (list corpus:nested-scope-witness-tree
        corpus:late-hoist-witness-tree
        corpus:rail-turn-witness-tree
        corpus:right-active-fresh-witness-tree))

(define all-redex-rule-names
  '("expose-frontier-fresh/core"
    "finish-success/core"
    "finish-failure/core"
    "force-delay/delay"
    "commit-choice-answer/disj"
    "commit-right-choice-answer/search-join"
    "work-succeed/core"
    "work-fail/core"
    "work-put/core"
    "allocate-fresh/core"
    "expand-conjunction/core"
    "expand-disjunction/disj"
    "suspend-goal/delay"
    "expose-choice-through-work-fresh/disj"
    "expose-choice-through-work-fresh/search-join"
    "erase-dead-fresh/core"
    "bubble-delay-through-fresh/delay"
    "conj-return/core"
    "conj-fail/core"
    "bubble-delay-through-conj/delay"
    "late-distribute-settled/disj"
    "late-distribute-right-settled/search-join"
    "skip-left-failure/disj"
    "rail-enter-right/search-join"
    "reassociate-left-result/disj"
    "skip-right-failure/search-join"
    "rail-return-left/search-join"
    "reassociate-right-result/search-join"))

(define (named-successors frontier)
  (for/list ([named
              (in-list
               (apply-reduction-relation/tag-with-names
                source-red
                frontier))])
    (match-define (list name next) named)
    (list (term (redex-name->label ,(~a name))) next)))

(define (oracle-successor frontier)
  (match (oracle:source-step frontier)
    [#f '()]
    [(oracle:transition name owner next)
     (list (list `(,(string->symbol name) ,owner) next))]))

(define (trace/redex frontier [limit 256] [labels '()] [trees (list frontier)])
  (match (named-successors frontier)
    ['() (values (reverse labels) frontier (reverse trees))]
    [(list (list label next))
     (unless (positive? limit)
       (error 'trace/redex "step cap reached"))
     (trace/redex next
                  (sub1 limit)
                  (cons label labels)
                  (cons next trees))]
    [other
     (error 'trace/redex "nondeterministic successors: ~e" other)]))

(define source-tests
  (test-suite
   "whole-tree Redex column: marked source"

   (test-case
    "stratified source grammar and actual-hole contexts"
    (check-true
     (redex-match? redex-column-source-lang
                   WF
                   (term
                    (FrontierFresh (u:0)
                                   (More (Conj hole
                                               (succeed (label "k"))))
                                   (label "outer")))))
    (check-true
     (redex-match? redex-column-source-lang
                   WF+
                   (term
                    (More (DisjL (WorkFresh (u:0)
                                                hole
                                                (label "local"))
                                      Dead)))))
    (check-false
     (redex-match? redex-column-source-lang
                   WF+
                   (term (More hole))))
    (check-false
     (frontier-in-language?
      '(More (Emit (Answer (state unit)) Done))))
    (check-false (label-in-language? '(work-succeed delay)))
    (check-false
     (label-in-language?
      '(expose-choice-through-work-fresh core))))

   (test-case
    "toy well-formedness is an executable judgment"
    (for ([tree (in-list witness-trees)])
      (check-equal?
       (judgment-holds (wf-frontier/toy ,tree))
       #t))
    (check-equal?
     (judgment-holds
      (wf-frontier/toy
       (More
        (Work
         (fresh (x:q x:q)
                (succeed (label "bad"))
                (label "duplicate"))
         (state unit)))))
     #f))

   (test-case
    "label/name maps are inverse on every source rule"
    (for ([name (in-list all-redex-rule-names)])
      (define label
        (term (redex-name->label ,name)))
      (check-true (label-in-language? label))
      (check-equal?
       (term (label->redex-name ,label))
       name)))

   (test-case
    "bounded Redex generation preserves determinism and well-formedness"
    (redex-check
     redex-column-source-lang
     F
     (let ([frontier (term F)])
       (or (not (judgment-holds (wf-frontier/toy F)))
           (let ([next* (named-successors frontier)])
             (and (<= (length next*) 1)
                  (for/and ([named (in-list next*)])
                    (match-define (list _label next) named)
                    (judgment-holds (wf-frontier/toy ,next)))))))
     #:attempts 1000))

   (test-case
    "Redex relation exactly matches the frozen source oracle"
    (for ([initial (in-list witness-trees)])
      (let loop ([tree initial] [remaining 256])
        (check-equal? (named-successors tree)
                      (oracle-successor tree))
        (match (named-successors tree)
          ['() (void)]
          [(list (list _ next))
           (check-true (positive? remaining))
           (loop next (sub1 remaining))]))))

   (test-case
    "global and branch-local fresh exposure are syntactically distinct"
    (define global
      '(More
        (WorkFresh (u:0)
                   (DisjL (Returned (state unit)) Dead)
                   (label "global"))))
    (define local
      '(More
        (DisjL
         (WorkFresh (u:0)
                    (DisjL (Returned (state unit)) Dead)
                    (label "local"))
         Dead)))
    (check-equal?
     (first (first (named-successors global)))
     '(expose-frontier-fresh core))
    (check-equal?
     (first (first (named-successors local)))
     '(expose-choice-through-work-fresh disj)))

   (test-case
    "representative traces agree completely"
    (for ([initial (in-list witness-trees)])
      (define-values (labels final trees)
        (trace/redex initial))
      (define-values (oracle-labels oracle-final oracle-status oracle-trees)
        (oracle:source-trace initial))
      (check-equal?
       labels
       (for/list ([entry (in-list oracle-labels)])
         (match-define (list name owner) entry)
         `(,(string->symbol name) ,owner)))
      (check-equal? final oracle-final)
      (check-equal? trees oracle-trees)
      (check-equal? oracle-status 'value)))))

(module+ test
  (run-tests source-tests))
