#lang racket

(require redex/reduction-semantics
         "./shared-host.rkt")

(provide define-pk-well-formedness)

;; Common marker-indexed well-formedness.  A kernel validates only its atomic
;; leaves and opaque states; the control schema owns lexical and marker scope
;; traversal.  The root judgment fixes both ambient scopes to empty.
(define-syntax-rule
  (define-pk-well-formedness
    language-id
    wf-atomic-id
    wf-state-at-id
    wf-goal-id
    wf-answer-at-id
    wf-work-at-id
    wf-frontier-at-id
    wf-frontier-id)
  (begin
    (define-judgment-form
      language-id
      #:contract (wf-goal-id g lexical intro)
      #:mode (wf-goal-id I I I)

      [(wf-atomic-id katom lexical intro)
       ---------------------------------------------------- "wf atomic goal"
       (wf-goal-id katom lexical intro)]

      [(where #t
              ,(fresh-extension? (term (x_new (... ...)))
                                 (term (x_outer (... ...)))))
       (wf-goal-id g (x_new (... ...) x_outer (... ...)) intro)
       ---------------------------------------------------- "wf lexical fresh"
       (wf-goal-id (fresh (x_new (... ...)) g tag)
                   (x_outer (... ...))
                   intro)]

      [(wf-goal-id g_1 lexical intro)
       (wf-goal-id g_2 lexical intro)
       ---------------------------------------------------- "wf conjunction goal"
       (wf-goal-id (conj g_1 g_2 tag) lexical intro)]

      [(wf-goal-id g_1 lexical intro)
       (wf-goal-id g_2 lexical intro)
       ---------------------------------------------------- "wf disjunction goal"
       (wf-goal-id (disj g_1 g_2 tag) lexical intro)]

      [(wf-goal-id g lexical intro)
       ---------------------------------------------------- "wf suspended goal"
       (wf-goal-id (suspend g tag) lexical intro)])

    (define-judgment-form
      language-id
      #:contract (wf-answer-at-id A intro)
      #:mode (wf-answer-at-id I I)

      [(wf-state-at-id kst intro)
       ---------------------------------------------------- "wf raw answer"
       (wf-answer-at-id (Answer kst) intro)]

      [(where #t
              ,(fresh-extension? (term (u_new (... ...)))
                                 (term (u_outer (... ...)))))
       (wf-answer-at-id A (u_new (... ...) u_outer (... ...)))
       ---------------------------------------------------- "wf marked answer"
       (wf-answer-at-id (AnswerFresh (u_new (... ...)) A tag)
                        (u_outer (... ...)))])

    (define-judgment-form
      language-id
      #:contract (wf-work-at-id W intro)
      #:mode (wf-work-at-id I I)

      [(wf-goal-id g () intro)
       (wf-state-at-id kst intro)
       ---------------------------------------------------- "wf atomic work"
       (wf-work-at-id (Work g kst) intro)]

      [(wf-state-at-id kst intro)
       ---------------------------------------------------- "wf returned work"
       (wf-work-at-id (Returned kst) intro)]

      [---------------------------------------------------- "wf dead work"
       (wf-work-at-id Dead intro)]

      [(where #t
              ,(fresh-extension? (term (u_new (... ...)))
                                 (term (u_outer (... ...)))))
       (wf-work-at-id W (u_new (... ...) u_outer (... ...)))
       ---------------------------------------------------- "wf marked work"
       (wf-work-at-id (WorkFresh (u_new (... ...)) W tag)
                      (u_outer (... ...)))]

      [(wf-work-at-id W intro)
       (wf-goal-id g () intro)
       ---------------------------------------------------- "wf conjunction work"
       (wf-work-at-id (Conj W g) intro)]

      [(wf-work-at-id W intro)
       ---------------------------------------------------- "wf delayed work"
       (wf-work-at-id (PendingDelay W) intro)]

      [(wf-work-at-id W_1 intro)
       (wf-work-at-id W_2 intro)
       ---------------------------------------------------- "wf left-active choice"
       (wf-work-at-id (DisjL W_1 W_2) intro)]

      [(wf-work-at-id W_1 intro)
       (wf-work-at-id W_2 intro)
       ---------------------------------------------------- "wf right-active choice"
       (wf-work-at-id (DisjR W_1 W_2) intro)])

    (define-judgment-form
      language-id
      #:contract (wf-frontier-at-id F intro)
      #:mode (wf-frontier-at-id I I)

      [(wf-work-at-id W intro)
       ---------------------------------------------------- "wf more frontier"
       (wf-frontier-at-id (More W) intro)]

      [---------------------------------------------------- "wf done frontier"
       (wf-frontier-at-id Done intro)]

      [(wf-answer-at-id A intro)
       ---------------------------------------------------- "wf last frontier"
       (wf-frontier-at-id (Last A) intro)]

      [(where #t
              ,(fresh-extension? (term (u_new (... ...)))
                                 (term (u_outer (... ...)))))
       (wf-frontier-at-id F (u_new (... ...) u_outer (... ...)))
       ---------------------------------------------------- "wf marked frontier"
       (wf-frontier-at-id (FrontierFresh (u_new (... ...)) F tag)
                          (u_outer (... ...)))]

      [(wf-answer-at-id A intro)
       (wf-frontier-at-id F intro)
       ---------------------------------------------------- "wf emitted frontier"
       (wf-frontier-at-id (Emit A F) intro)]

      [(wf-frontier-at-id F intro)
       ---------------------------------------------------- "wf forced frontier"
       (wf-frontier-at-id (Forced F) intro)])

    (define-judgment-form
      language-id
      #:contract (wf-frontier-id F)
      #:mode (wf-frontier-id I)
      [(wf-frontier-at-id F ())
       ---------------------------------------------------- "wf root frontier"
       (wf-frontier-id F)])))
