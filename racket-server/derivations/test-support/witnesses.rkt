#lang racket

(require "corpus.rkt")

(provide (struct-out witness) witnesses witness-initial coverage-witnesses
         settlement-witnesses validation-witnesses)

;; The fixtures are first-order syntax and S input data. They neither call a
;; semantic stage nor prescribe a functional kernel interface. Lexical x:
;; binders in goals are distinct from allocated logical u: names in Owners.
(struct witness (name goal owners state rationale) #:transparent)

(define initial-owners '(Owners))
(define initial-state '(state () () () (label "initial")))

(define (corpus-goal corpus label)
  (or (findf (lambda (goal) (equal? (last goal) `(label ,label))) corpus)
      (error 'corpus-goal "missing existing corpus witness: ~a" label)))

(define (example name goal rationale
                 [owners initial-owners] [state initial-state])
  (witness name goal owners state rationale))

(define (witness-initial example)
  `(eval ,(witness-owners example) ,(witness-goal example)
         ,(witness-state example)))

(define witnesses
  (list
   (example
    'empty-binder
    (corpus-goal core-corpus "empty-fresh")
    "An empty introduction still retains its Owner group and binder label.")
   (example
    'unused-binder
    (corpus-goal core-corpus "multi")
    "The unused variable remains in the same ordered Owner group as the used variable.")
   (example
    'shadowed-binder
    (corpus-goal core-corpus "outer-fresh")
    "The outer and inner x:q binders introduce different u: names and retain both binder labels.")
   (example
    'shared-outer
    (corpus-goal disjunction-corpus "shared")
    "Both answers use the outer u:0, whose Owner belongs to their shared structural ancestry.")
   (example
    'sibling-reuse
    '((∃ (x:left) (x:left =? (sym "A") (label "left-value"))
         (label "left-owner"))
      ∨ (∃ (x:right) (x:right =? (sym "B") (label "right-value"))
           (label "right-owner"))
      (label "independent-siblings"))
    "Sibling worlds may independently allocate u:0; the first answer's Owner does not occupy the right world.")
   (example
    'answer-local-continuation
    '(((∃ (x:unused x:left) (x:left =? (sym "A") (label "left-value"))
          (label "left-two"))
       ∨ (∃ (x:right) (x:right =? (sym "B") (label "right-value"))
            (label "right-one"))
       (label "different-answer-worlds"))
      ∧ (∃ (x:later) (x:later =? (nat 9) (label "later-value"))
           (label "later-owner"))
      (label "answer-local-bind"))
    "The same continuation allocates u:2 for the two-variable answer and u:1 for the one-variable answer.")
   (example
    'allocated-failure
    '(∃ (x:unused) (fail (label "allocated-failure"))
        (label "failed-owner"))
    "A terminal failure still retains the allocation that occurred on that world.")
   (example
    'failed-sibling
    '((∃ (x:lost) (fail (label "left-failure")) (label "discarded-owner"))
      ∨ (∃ (x:kept) (x:kept =? (sym "B") (label "right-value"))
           (label "surviving-owner"))
      (label "failure-choice"))
    "mplus discards the failed left world's local Owner; the surviving sibling still allocates u:0.")
   (example
    'allocation-across-delay
    '(∃ (x:outer)
        ((x:outer =? (sym "A") (label "outer-value"))
         ∧ (suspend
            (∃ (x:inner) (x:inner =? x:outer (label "inner-alias"))
                (label "inner-owner"))
            (label "allocation-delay"))
         (label "before-delay"))
        (label "outer-owner"))
    "The Delay retains the outer variable and its ancestry; forcing allocates inner u:1 while keeping the outer Owner on Forced.")
   (example
    'delayed-sibling-capture
    '(∃ (x:outer)
        ((suspend
          (∃ (x:delayed) (x:delayed =? x:outer (label "delayed-alias"))
              (label "delayed-owner"))
          (label "left-delay"))
         ∨ (∃ (x:unused x:eager)
              (x:eager =? x:outer (label "eager-alias"))
              (label "eager-owner"))
         (label "delay-and-sibling"))
        (label "shared-owner"))
    "A resumption captures the shared world, not the eager sibling's local allocation; delayed x:delayed becomes u:1, even though the sibling allocated u:1 and u:2.")
   (example
    'eager-bind-residual
    (corpus-goal disjunction-corpus "bind-eager-tail")
    "The continuation for the eager Yield tail must run before the resulting Search can commit its settled frontier; inspect eager work as well as final answers.")
   (example
    'nested-rail
    nested-rail-goal
    "The nested right rail retains its orientation across four forcing boundaries; compare the exact Forced/Emit/Done structure.")
   (example
    'sparse-inherited-ancestry
    '(∃ (x:new)
        ((u:9 =? (sym "outer") (label "outer"))
         ∧ (x:new =? u:2 (label "new")) (label "conj"))
        (label "fresh"))
    "Incoming Owner order is u:9,u:2,u:7, while least-unused fresh is u:0; support order and name arithmetic are different information."
    '(Owners (Owner (u:9 u:2) (label "outer-pair"))
             (Owner (u:7) (label "unused-ancestor"))))
   (example
    'inherited-state-and-trail
    '(∃ (x:new)
        ((x:new =? u:9 (label "new-alias"))
         ∧ (x:new != (sym "other") (label "new-disequality"))
         (label "continue-inherited-state"))
        (label "new-owner"))
    "The unchanged four-field S state retains its alias structure, disequalities, complete replay trail, and original state label while new allocation lives in Owners."
    '(Owners (Owner (u:9 u:2) (label "sparse")))
    '(state ((u:2 (sym "A")) (u:9 u:2))
            ((u:9 (sym "avoid")))
            ((u:9 =? u:2 (label "alias"))
             (u:2 =? (sym "A") (label "value")))
            (label "replay")))))

;; These small additions cover control families absent from the 14 allocation
;; witnesses. Keeping them named lets the more expensive correspondence gate
;; cover the same families without replaying the whole corpus there.
(define coverage-witnesses
  (list
   (witness
    'left-nested-eager-merge
    '(((∃ (x:a) (x:a =? (sym "A") (label "A")) (label "fresh-A"))
       ∨ (∃ (x:b) (x:b =? (sym "B") (label "B")) (label "fresh-B"))
       (label "left-choice"))
      ∨ (∃ (x:c) (x:c =? (sym "C") (label "C")) (label "fresh-C"))
      (label "left-nested-merge"))
    '(Owners) '(state () () () (label "initial"))
    "Merging an eager Yield left operand retains its head and Owners in KMergeYield while recursively merging its tail.")
   (witness
    'bind-delayed-left
    '((suspend
       (∃ (x:before) (x:before =? (sym "A") (label "before-value"))
           (label "before-owner"))
       (label "left-delay"))
      ∧ (∃ (x:after) (x:after =? (sym "B") (label "after-value"))
           (label "after-owner"))
      (label "bind-delayed-left"))
    '(Owners) '(state () () () (label "initial"))
    "Binding a Delay constructs RBind; forcing it uses KBindForced before the continuation allocates after the resumed world's local Owners.")))

;; These distinguish intermediate search answers from answers settled only
;; after the pending goal has finished. They remain pure first-order goals.
(define settlement-witnesses
  (list
   (example
    'intermediate-success-then-failure
    '(∃ (x:q)
        ((x:q =? (sym "temporary") (label "intermediate-success"))
         ∧ (fail (label "pending-failure")) (label "pending-conjunction"))
        (label "temporary-owner"))
    "An intermediate successful Search answer is consumed by a failing continuation; no settled Emit may be constructed for it.")
   (example
    'delayed-continuation-schedule
    '(∃ (x:q)
        (((x:q =? (sym "A") (label "input-A"))
          ∨ (x:q =? (sym "B") (label "input-B")) (label "inputs"))
         ∧ (suspend (succeed (label "continuation-finished"))
                    (label "pending-continuation"))
         (label "bind-pending-answers"))
        (label "shared-input-owner"))
    "Both input answers mature eagerly, but both still have suspended conjunction work; run must return unfinished More, not a settled answer.")
   (example
    'strict-sibling-maturation
    '((succeed (label "left-ready"))
      ∨ ((succeed (label "right-start"))
         ∧ (succeed (label "right-finished")) (label "right-conjunction"))
      (label "strict-siblings"))
    "All left/right atomic work finishes before the top-level commit can construct the first settled Emit.")
   (example
    'settled-prefix-resumption
    '((∃ (x:a) (x:a =? (sym "A") (label "settled-A")) (label "settled-left-owner"))
      ∨ (suspend
         (suspend
          (∃ (x:b) (x:b =? (sym "B") (label "later-B")) (label "settled-right-owner"))
          (label "inner-settled-delay"))
         (label "outer-settled-delay"))
      (label "settled-prefix"))
    "An already settled answer and its exact ownership survive both resumptions unchanged while the independent sibling later reuses u:0.")))

(define validation-witnesses (append witnesses coverage-witnesses settlement-witnesses))
