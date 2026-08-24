#lang racket

(require redex/reduction-semantics)

(provide substitute-goal/disjunction
         raw-named-successors
         finite-named-trace
         canonical-multiset)

;; Representation-neutral structural traversal for extending lexical
;; substitution through disjunction.  Each source oracle supplies the term
;; substitution equation belonging to its own carrier.
(define (substitute-goal/disjunction
         goal bindings substitute-term [who 'substitute-goal/disjunction])
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
     `(,(substitute-goal/disjunction
         left bindings substitute-term who)
       ∧
       ,(substitute-goal/disjunction
         right bindings substitute-term who)
       ,tag)]
    [`(,left ∨ ,right ,tag)
     `(,(substitute-goal/disjunction
         left bindings substitute-term who)
       ∨
       ,(substitute-goal/disjunction
         right bindings substitute-term who)
       ,tag)]
    [`(∃ ,binders ,body ,tag)
     `(∃ ,binders
         ,(substitute-goal/disjunction
           body
           (for/list ([binding (in-list bindings)]
                      #:unless (member (first binding) binders))
             binding)
           substitute-term
           who)
         ,tag)]
    [_
     (error who "unsupported Disjunction goal: ~e" goal)]))

;; Correspondence is proof-multiset correspondence: keep names and duplicate
;; derivations exactly as Redex returns them.
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
            "trace exceeded its ~a-step bound from ~e"
            (+ fuel (length reversed-steps))
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
