#lang racket

(require redex/reduction-semantics
         "./shared-host.rkt")

(provide define-lean-well-formedness)

;; Lean well-formedness retains lexical closure and kernel validity, but it has
;; no runtime ownership index: persistent intro evidence is precisely what the
;; representation omits.
(define-syntax-rule
  (define-lean-well-formedness
    language-id
    wf-atomic-id
    wf-state-id
    wf-goal-id
    wf-answer-id
    wf-work-id
    wf-frontier-id)
  (begin
    (define-judgment-form
      language-id
      #:contract (wf-goal-id g lexical)
      #:mode (wf-goal-id I I)

      [(wf-atomic-id katom lexical)
       ---------------------------------------------------- "wf atomic goal"
       (wf-goal-id katom lexical)]

      [(where #t
              ,(fresh-extension? (term (x_new (... ...)))
                                 (term (x_outer (... ...)))))
       (wf-goal-id g (x_new (... ...) x_outer (... ...)))
       ---------------------------------------------------- "wf lexical fresh"
       (wf-goal-id (fresh (x_new (... ...)) g tag)
                   (x_outer (... ...)))]

      [(wf-goal-id g_1 lexical)
       (wf-goal-id g_2 lexical)
       ---------------------------------------------------- "wf conjunction goal"
       (wf-goal-id (conj g_1 g_2 tag) lexical)]

      [(wf-goal-id g_1 lexical)
       (wf-goal-id g_2 lexical)
       ---------------------------------------------------- "wf disjunction goal"
       (wf-goal-id (disj g_1 g_2 tag) lexical)]

      [(wf-goal-id g lexical)
       ---------------------------------------------------- "wf suspended goal"
       (wf-goal-id (suspend g tag) lexical)])

    (define-judgment-form
      language-id
      #:contract (wf-answer-id A)
      #:mode (wf-answer-id I)
      [(wf-state-id kst)
       ---------------------------------------------------- "wf answer"
       (wf-answer-id (Answer kst))])

    (define-judgment-form
      language-id
      #:contract (wf-work-id W)
      #:mode (wf-work-id I)

      [(wf-goal-id g ())
       (wf-state-id kst)
       ---------------------------------------------------- "wf atomic work"
       (wf-work-id (Work g kst))]

      [(wf-state-id kst)
       ---------------------------------------------------- "wf returned work"
       (wf-work-id (Returned kst))]

      [---------------------------------------------------- "wf dead work"
       (wf-work-id Dead)]

      [(wf-work-id W)
       (wf-goal-id g ())
       ---------------------------------------------------- "wf conjunction work"
       (wf-work-id (Conj W g))]

      [(wf-work-id W)
       ---------------------------------------------------- "wf delayed work"
       (wf-work-id (PendingDelay W))]

      [(wf-work-id W_1)
       (wf-work-id W_2)
       ---------------------------------------------------- "wf left-active choice"
       (wf-work-id (DisjL W_1 W_2))]

      [(wf-work-id W_1)
       (wf-work-id W_2)
       ---------------------------------------------------- "wf right-active choice"
       (wf-work-id (DisjR W_1 W_2))])

    (define-judgment-form
      language-id
      #:contract (wf-frontier-id F)
      #:mode (wf-frontier-id I)

      [(wf-work-id W)
       ---------------------------------------------------- "wf unfinished frontier"
       (wf-frontier-id (More W))]

      [---------------------------------------------------- "wf done frontier"
       (wf-frontier-id Done)]

      [(wf-answer-id A)
       ---------------------------------------------------- "wf last frontier"
       (wf-frontier-id (Last A))]

      [(wf-answer-id A)
       (wf-frontier-id F)
       ---------------------------------------------------- "wf emitted frontier"
       (wf-frontier-id (Emit A F))]

      [(wf-frontier-id F)
       ---------------------------------------------------- "wf forced frontier"
       (wf-frontier-id (Forced F))])))
