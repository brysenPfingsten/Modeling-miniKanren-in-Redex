#lang racket

(require redex/reduction-semantics)

(provide substitute-goal/delay
         raw-named-successors
         finite-named-trace
         canonical-multiset)

;; Representation-neutral structural traversal for extending lexical
;; substitution through Delay.  Each source oracle supplies its own term
;; substitution equation; this helper knows neither S, E, nor N carriers.
(define (substitute-goal/delay goal bindings substitute-term [who 'substitute-goal/delay])
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
     `(,(substitute-goal/delay left bindings substitute-term who)
       ∧
       ,(substitute-goal/delay right bindings substitute-term who)
       ,tag)]
    [`(∃ ,binders ,body ,tag)
     `(∃ ,binders
         ,(substitute-goal/delay
           body
           (for/list ([binding (in-list bindings)]
                      #:unless (member (first binding) binders))
             binding)
           substitute-term
           who)
         ,tag)]
    [`(suspend ,body ,tag)
     `(suspend
       ,(substitute-goal/delay body bindings substitute-term who)
       ,tag)]
    [_
     (error who "unsupported Delay goal: ~e" goal)]))

;; Keep rule names and duplicate derivations.  No test in this subtree is
;; allowed to establish correspondence on a deduplicated target set.
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
            "trace exceeded the ~a-step bound from ~e"
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
