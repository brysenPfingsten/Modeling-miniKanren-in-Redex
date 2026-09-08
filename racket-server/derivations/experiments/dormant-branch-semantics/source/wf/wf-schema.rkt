#lang racket

(require redex/reduction-semantics
         "../languages/core-lang.rkt"
         "./kernel-base.rkt")

(provide define-well-formedness
         define-search-well-formedness)

;; Generate the common structural judgments for one feature language.
;; The final argument of each non-root judgment is the list of introductions
;; visible along the grammatical path to the subject. Feature modules supply
;; only the clauses for constructors they own.
(define-syntax-rule
  (define-well-formedness
    language-id
    wf-goal-id
    wf-answer-id
    wf-settled-id
    wf-work-id
    wf-frontier-id
    wf-cfg-id
    (goal-extra ...)
    (answer-extra ...)
    (work-extra ...)
    (frontier-extra ...))
  (begin
    (define-judgment-form
      language-id
      #:contract (wf-goal-id g (x_1 (... ...)) intro)
      #:mode (wf-goal-id I I I)

      [---------------------------------------------------- "wf succeed"
       (wf-goal-id
        (succeed tag)
        (x_bound (... ...))
        intro_visible)]

      [---------------------------------------------------- "wf fail"
       (wf-goal-id
        (fail tag)
        (x_bound (... ...))
        intro_visible)]

      [(wf-goal-id
        g
        (x_new (... ...) x_outer (... ...))
        intro_visible)
       ---------------------------------------------------- "wf fresh goal"
       (wf-goal-id
        (∃ (x_new (... ...)) g tag)
        (x_outer (... ...))
        intro_visible)]

      [(wf-goal-id g_1 (x_bound (... ...)) intro_visible)
       (wf-goal-id g_2 (x_bound (... ...)) intro_visible)
       ---------------------------------------------------- "wf conjunction goal"
       (wf-goal-id
        (g_1 ∧ g_2 tag)
        (x_bound (... ...))
        intro_visible)]

      [(wf-term? t_1 (x_bound (... ...)) intro_visible)
       (wf-term? t_2 (x_bound (... ...)) intro_visible)
       ---------------------------------------------------- "wf equality goal"
       (wf-goal-id
        (t_1 =? t_2 tag)
        (x_bound (... ...))
        intro_visible)]

      [(wf-term? t_1 (x_bound (... ...)) intro_visible)
       (wf-term? t_2 (x_bound (... ...)) intro_visible)
       ---------------------------------------------------- "wf disequality goal"
       (wf-goal-id
        (t_1 != t_2 tag)
        (x_bound (... ...))
        intro_visible)]

      goal-extra ...)

    (define-judgment-form
      language-id
      #:contract (wf-answer-id A intro)
      #:mode (wf-answer-id I I)

      [(wf-owner-stack? owners intro_visible intro_body)
       (wf-state? σ intro_body)
       ---------------------------------------------------- "wf raw answer"
       (wf-answer-id (Answer owners σ) intro_visible)]

      answer-extra ...)

    (define-judgment-form
      language-id
      #:contract (wf-settled-id S intro)
      #:mode (wf-settled-id I I)

      [(wf-owner-stack? owners intro_visible intro_body)
       (wf-state? σ intro_body)
       ---------------------------------------------------- "wf returned work"
       (wf-settled-id (Returned owners σ) intro_visible)])

    (define-judgment-form
      language-id
      #:contract (wf-work-id W intro)
      #:mode (wf-work-id I I)

      [(wf-owner-stack? owners intro_visible intro_body)
       (wf-goal-id g () intro_body)
       (wf-state? σ intro_body)
       ---------------------------------------------------- "wf atomic work"
       (wf-work-id (Work owners g σ) intro_visible)]

      [(wf-owner-stack? owners intro_visible intro_body)
       (wf-state? σ intro_body)
       ---------------------------------------------------- "wf returned work"
       (wf-work-id (Returned owners σ) intro_visible)]

      [(wf-owner-stack? owners intro_visible intro_body)
       ---------------------------------------------------- "wf dead work"
       (wf-work-id (Dead owners) intro_visible)]

      [(wf-owner-stack? owners intro_visible intro_body)
       (wf-work-id W intro_body)
       (wf-goal-id g () intro_body)
       ---------------------------------------------------- "wf conjunction work"
       (wf-work-id (Conj owners W g) intro_visible)]

      work-extra ...)

    (define-judgment-form
      language-id
      #:contract (wf-frontier-id F intro)
      #:mode (wf-frontier-id I I)

      [(wf-work-id W intro_visible)
       ---------------------------------------------------- "wf unfinished frontier"
       (wf-frontier-id (More W) intro_visible)]

      [(wf-owner-stack? owners intro_visible intro_body)
       ---------------------------------------------------- "wf done frontier"
       (wf-frontier-id (Done owners) intro_visible)]

      [(wf-owner-stack? owners intro_visible intro_body)
       (wf-answer-id A intro_body)
       ---------------------------------------------------- "wf last frontier"
       (wf-frontier-id (Last owners A) intro_visible)]

      frontier-extra ...)

    (define-judgment-form
      language-id
      #:contract (wf-cfg-id F)
      #:mode (wf-cfg-id I)

      [(wf-frontier-id F ())
       ---------------------------------------------------- "wf root frontier"
       (wf-cfg-id F)])))

;; Instantiate the literal delay/disjunction union, with an optional work
;; delta for a real carrier extension such as rail's right-active state.
;; Keeping this bundle in the schema makes search exact and rail-wf a thin
;; local extension.
(define-syntax-rule
  (define-search-well-formedness
    language-id
    wf-goal-id
    wf-answer-id
    wf-settled-id
    wf-work-id
    wf-frontier-id
    wf-cfg-id
    disjunction-goal-rule-name
    suspended-goal-rule-name
    pending-delay-rule-name
    left-active-rule-name
    forced-frontier-rule-name
    emitted-frontier-rule-name
    (work-extra ...))
  (define-well-formedness
    language-id
    wf-goal-id
    wf-answer-id
    wf-settled-id
    wf-work-id
    wf-frontier-id
    wf-cfg-id
    (
     [(wf-goal-id g_1 (x_bound (... ...)) intro_visible)
      (wf-goal-id g_2 (x_bound (... ...)) intro_visible)
      ---------------------------------------------------- disjunction-goal-rule-name
      (wf-goal-id
       (g_1 ∨ g_2 tag)
       (x_bound (... ...))
       intro_visible)]
     [(wf-goal-id g (x_bound (... ...)) intro_visible)
      ---------------------------------------------------- suspended-goal-rule-name
      (wf-goal-id
       (suspend g tag)
       (x_bound (... ...))
       intro_visible)])
    ()
    (
     [(wf-owner-stack? owners intro_visible intro_body)
      (wf-work-id W intro_body)
      ---------------------------------------------------- pending-delay-rule-name
      (wf-work-id (PendingDelay owners W) intro_visible)]
     [(wf-owner-stack? owners intro_visible intro_body)
      (wf-work-id W_1 intro_body)
      (wf-work-id W_2 intro_body)
      ---------------------------------------------------- left-active-rule-name
      (wf-work-id (DisjL owners W_1 W_2) intro_visible)]
     work-extra ...)
    (
     [(wf-owner-stack? owners intro_visible intro_body)
      (wf-frontier-id F intro_body)
      ---------------------------------------------------- forced-frontier-rule-name
      (wf-frontier-id (Forced owners F) intro_visible)]
     [(wf-owner-stack? owners intro_visible intro_body)
      (wf-answer-id A intro_body)
      (wf-frontier-id F intro_body)
      ---------------------------------------------------- emitted-frontier-rule-name
      (wf-frontier-id (Emit owners A F) intro_visible)])))
