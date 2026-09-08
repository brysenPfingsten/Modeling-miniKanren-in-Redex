#lang racket

(require redex/reduction-semantics
         "../languages/core-lang.rkt"
         "./kernel-base.rkt"
         "./relcall-arity.rkt")

(provide define-relcall-well-formedness
         define-search-relcall-well-formedness)

;; Relation-call counterpart of wf-schema. Γ is threaded only through
;; judgments that can inspect goals. The final argument remains the inherited
;; list of introductions visible at the subject.
(define-syntax-rule
  (define-relcall-well-formedness
    language-id
    wf-goal-id
    wf-answer-id
    wf-settled-id
    wf-work-id
    wf-frontier-id
    wf-rel-env-id
    wf-config-id
    (goal-extra ...)
    (answer-extra ...)
    (work-extra ...)
    (frontier-extra ...))
  (begin
    (define-judgment-form
      language-id
      #:contract (wf-goal-id g Γ (x_1 (... ...)) intro)
      #:mode (wf-goal-id I I I I)

      [---------------------------------------------------- "wf succeed"
       (wf-goal-id
        (succeed tag)
        Γ
        (x_bound (... ...))
        intro_visible)]

      [---------------------------------------------------- "wf fail"
       (wf-goal-id
        (fail tag)
        Γ
        (x_bound (... ...))
        intro_visible)]

      [(wf-goal-id
        g
        Γ
        (x_new (... ...) x_outer (... ...))
        intro_visible)
       ---------------------------------------------------- "wf fresh goal"
       (wf-goal-id
        (∃ (x_new (... ...)) g tag)
        Γ
        (x_outer (... ...))
        intro_visible)]

      [(wf-goal-id g_1 Γ (x_bound (... ...)) intro_visible)
       (wf-goal-id g_2 Γ (x_bound (... ...)) intro_visible)
       ---------------------------------------------------- "wf conjunction goal"
       (wf-goal-id
        (g_1 ∧ g_2 tag)
        Γ
        (x_bound (... ...))
        intro_visible)]

      [(wf-term? t_1 (x_bound (... ...)) intro_visible)
       (wf-term? t_2 (x_bound (... ...)) intro_visible)
       ---------------------------------------------------- "wf equality goal"
       (wf-goal-id
        (t_1 =? t_2 tag)
        Γ
        (x_bound (... ...))
        intro_visible)]

      [(wf-term? t_1 (x_bound (... ...)) intro_visible)
       (wf-term? t_2 (x_bound (... ...)) intro_visible)
       ---------------------------------------------------- "wf disequality goal"
       (wf-goal-id
        (t_1 != t_2 tag)
        Γ
        (x_bound (... ...))
        intro_visible)]

      [(wf-term? t (x_bound (... ...)) intro_visible) (... ...)
       (where #t
              ,(relcall-arity-ok/host
                (term r)
                (term (t (... ...)))
                (term Γ)))
       ---------------------------------------------------- "wf relation call"
       (wf-goal-id
        (r t (... ...) tag)
        Γ
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
      #:contract (wf-work-id W Γ intro)
      #:mode (wf-work-id I I I)

      [(wf-owner-stack? owners intro_visible intro_body)
       (wf-goal-id g Γ () intro_body)
       (wf-state? σ intro_body)
       ---------------------------------------------------- "wf atomic work"
       (wf-work-id (Work owners g σ) Γ intro_visible)]

      [(wf-owner-stack? owners intro_visible intro_body)
       (wf-state? σ intro_body)
       ---------------------------------------------------- "wf returned work"
       (wf-work-id (Returned owners σ) Γ intro_visible)]

      [(wf-owner-stack? owners intro_visible intro_body)
       ---------------------------------------------------- "wf dead work"
       (wf-work-id (Dead owners) Γ intro_visible)]

      [(wf-owner-stack? owners intro_visible intro_body)
       (wf-work-id W Γ intro_body)
       (wf-goal-id g Γ () intro_body)
       ---------------------------------------------------- "wf conjunction work"
       (wf-work-id (Conj owners W g) Γ intro_visible)]

      work-extra ...)

    (define-judgment-form
      language-id
      #:contract (wf-frontier-id F Γ intro)
      #:mode (wf-frontier-id I I I)

      [(wf-work-id W Γ intro_visible)
       ---------------------------------------------------- "wf unfinished frontier"
       (wf-frontier-id (More W) Γ intro_visible)]

      [(wf-owner-stack? owners intro_visible intro_body)
       ---------------------------------------------------- "wf done frontier"
       (wf-frontier-id (Done owners) Γ intro_visible)]

      [(wf-owner-stack? owners intro_visible intro_body)
       (wf-answer-id A intro_body)
       ---------------------------------------------------- "wf last frontier"
       (wf-frontier-id (Last owners A) Γ intro_visible)]

      frontier-extra ...)

    (define-judgment-form
      language-id
      #:contract (wf-rel-env-id Γ)
      #:mode (wf-rel-env-id I)

      [(wf-goal-id
        g
        ((r d g) (... ...))
        d
        ())
       (... ...)
       ---------------------------------------------------- "wf relation environment"
       (wf-rel-env-id ((r d g) (... ...)))])

    (define-judgment-form
      language-id
      #:contract (wf-config-id config)
      #:mode (wf-config-id I)

      [(wf-rel-env-id Γ)
       (wf-frontier-id F Γ ())
       ---------------------------------------------------- "wf relation configuration"
       (wf-config-id (Γ F))])))

;; Relcall counterpart of define-search-well-formedness. Search-relcall is the
;; literal union of the independently delayed-rooted overlay and search; a real
;; execution-carrier extension contributes only work-extra.
(define-syntax-rule
  (define-search-relcall-well-formedness
    language-id
    wf-goal-id
    wf-answer-id
    wf-settled-id
    wf-work-id
    wf-frontier-id
    wf-rel-env-id
    wf-config-id
    disjunction-goal-rule-name
    suspended-goal-rule-name
    pending-delay-rule-name
    left-active-rule-name
    forced-frontier-rule-name
    emitted-frontier-rule-name
    (work-extra ...))
  (define-relcall-well-formedness
    language-id
    wf-goal-id
    wf-answer-id
    wf-settled-id
    wf-work-id
    wf-frontier-id
    wf-rel-env-id
    wf-config-id
    (
     [(wf-goal-id
       g_1 Γ (x_bound (... ...)) intro_visible)
      (wf-goal-id
       g_2 Γ (x_bound (... ...)) intro_visible)
      ---------------------------------------------------- disjunction-goal-rule-name
      (wf-goal-id
       (g_1 ∨ g_2 tag)
       Γ
       (x_bound (... ...))
       intro_visible)]
     [(wf-goal-id
       g Γ (x_bound (... ...)) intro_visible)
      ---------------------------------------------------- suspended-goal-rule-name
      (wf-goal-id
       (suspend g tag)
       Γ
       (x_bound (... ...))
       intro_visible)])
    ()
    (
     [(wf-owner-stack? owners intro_visible intro_body)
      (wf-work-id W Γ intro_body)
      ---------------------------------------------------- pending-delay-rule-name
      (wf-work-id
       (PendingDelay owners W)
       Γ
       intro_visible)]
     [(wf-owner-stack? owners intro_visible intro_body)
      (wf-work-id W_1 Γ intro_body)
      (wf-work-id W_2 Γ intro_body)
      ---------------------------------------------------- left-active-rule-name
      (wf-work-id
       (DisjL owners W_1 W_2)
       Γ
       intro_visible)]
     work-extra ...)
    (
     [(wf-owner-stack? owners intro_visible intro_body)
      (wf-frontier-id F Γ intro_body)
      ---------------------------------------------------- forced-frontier-rule-name
      (wf-frontier-id
       (Forced owners F)
       Γ
       intro_visible)]
     [(wf-owner-stack? owners intro_visible intro_body)
      (wf-answer-id A intro_body)
      (wf-frontier-id F Γ intro_body)
      ---------------------------------------------------- emitted-frontier-rule-name
      (wf-frontier-id
       (Emit owners A F)
       Γ
       intro_visible)])))
