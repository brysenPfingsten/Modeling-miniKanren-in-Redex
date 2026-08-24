#lang racket

(require redex/reduction-semantics)

(provide substitute-goal/search
         raw-named-successors
         finite-named-trace
         canonical-multiset
         CORE-RULE-NAMES/SEARCH-ORACLE
         DELAY-RULE-NAMES/SEARCH-ORACLE
         DISJUNCTION-RULE-NAMES/SEARCH-ORACLE
         SEARCH-OWNED-RULE-NAMES/SEARCH-ORACLE
         SEARCH-RULE-NAMES/SEARCH-ORACLE)

;; The join owns no rewrite.  Keep the inherited inventories separate so a
;; test cannot accidentally turn a scheduler policy into a Search rule.
(define CORE-RULE-NAMES/SEARCH-ORACLE
  '(allocate-fresh
    conj-fail
    conj-return
    disequality-fail
    disequality-success
    expand-conjunction
    fail
    finish-failure
    finish-success
    succeed
    unify-fail
    unify-success
    unify-violates-disequality))

(define DELAY-RULE-NAMES/SEARCH-ORACLE
  '(bubble-delay-through-conj
    force-delay
    suspend-goal))

(define DISJUNCTION-RULE-NAMES/SEARCH-ORACLE
  '(commit-choice-answer
    expand-disjunction
    reassociate-left-result
    resume-left-choice-success
    skip-left-failure))

(define SEARCH-OWNED-RULE-NAMES/SEARCH-ORACLE '())

(define SEARCH-RULE-NAMES/SEARCH-ORACLE
  (sort
   (append CORE-RULE-NAMES/SEARCH-ORACLE
           DELAY-RULE-NAMES/SEARCH-ORACLE
           DISJUNCTION-RULE-NAMES/SEARCH-ORACLE)
   symbol<?))

;; Representation-neutral lexical substitution traverses both child goal
;; grammars.  The row supplies only its term substitution equation.
(define (substitute-goal/search
         goal bindings substitute-term [who 'substitute-goal/search])
  (match goal
    [`(succeed ,tag) `(succeed ,tag)]
    [`(fail ,tag) `(fail ,tag)]
    [`(,left =? ,right ,tag)
     `(,(substitute-term left bindings)
       =?
       ,(substitute-term right bindings)
       ,tag)]
    [`(,left != ,right ,tag)
     `(,(substitute-term left bindings)
       !=
       ,(substitute-term right bindings)
       ,tag)]
    [`(,left ∧ ,right ,tag)
     `(,(substitute-goal/search left bindings substitute-term who)
       ∧
       ,(substitute-goal/search right bindings substitute-term who)
       ,tag)]
    [`(,left ∨ ,right ,tag)
     `(,(substitute-goal/search left bindings substitute-term who)
       ∨
       ,(substitute-goal/search right bindings substitute-term who)
       ,tag)]
    [`(∃ ,binders ,body ,tag)
     `(∃ ,binders
         ,(substitute-goal/search
           body
           (for/list ([binding (in-list bindings)]
                      #:unless (member (first binding) binders))
             binding)
           substitute-term
           who)
         ,tag)]
    [`(suspend ,body ,tag)
     `(suspend
       ,(substitute-goal/search body bindings substitute-term who)
       ,tag)]
    [_
     (error who "unsupported Search goal: ~e" goal)]))

;; Preserve rule names and duplicate derivations.  Correspondence in this
;; subtree is always proof-multiset correspondence, never target-set equality.
(define (raw-named-successors relation source)
  (for/list ([named-step
              (in-list
               (apply-reduction-relation/tag-with-names relation source))])
    (match-define (list name target) named-step)
    (list (string->symbol (~a name)) target)))

(define (finite-named-trace relation source [fuel 64] [reversed-steps '()])
  (cond
    [(zero? fuel)
     (error 'finite-named-trace
            "trace exceeded the bounded fuel from ~e"
            source)]
    [else
     (match (raw-named-successors relation source)
       ['() (reverse reversed-steps)]
       [(list (and step (list _ target)))
        (finite-named-trace relation
                            target
                            (sub1 fuel)
                            (cons step reversed-steps))]
       [steps
        (error 'finite-named-trace
               "nondeterministic successors for ~e: ~e"
               source
               steps)])]))

(define (canonical-multiset values)
  (sort values string<? #:key ~s))
