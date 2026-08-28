#lang racket

(require redex/reduction-semantics)

(provide define-reference-source-Q)

;; Q_R is stated constructor by constructor in the marked language.  Its
;; result belongs to the marker-free subset that the corresponding lean
;; language names F.  Keeping the equations here avoids implementing the
;; reference map as an untyped host traversal.
(define-syntax-rule
  (define-reference-source-Q
    marked-language-id
    Q-answer-id
    Q-work-id
    Q-frontier-id)
  (begin
    (define-metafunction marked-language-id
      Q-answer-id : A -> A
      [(Q-answer-id (Answer kst))
       (Answer kst)]
      [(Q-answer-id (AnswerFresh intro A tag))
       (Q-answer-id A)])

    (define-metafunction marked-language-id
      Q-work-id : W -> W
      [(Q-work-id (Work g kst))
       (Work g kst)]
      [(Q-work-id (Returned kst))
       (Returned kst)]
      [(Q-work-id Dead) Dead]
      [(Q-work-id (WorkFresh intro W tag))
       (Q-work-id W)]
      [(Q-work-id (Conj W g))
       (Conj (Q-work-id W) g)]
      [(Q-work-id (PendingDelay W))
       (PendingDelay (Q-work-id W))]
      [(Q-work-id (DisjL W_1 W_2))
       (DisjL (Q-work-id W_1) (Q-work-id W_2))]
      [(Q-work-id (DisjR W_1 W_2))
       (DisjR (Q-work-id W_1) (Q-work-id W_2))])

    (define-metafunction marked-language-id
      Q-frontier-id : F -> F
      [(Q-frontier-id (More W))
       (More (Q-work-id W))]
      [(Q-frontier-id Done) Done]
      [(Q-frontier-id (Last A))
       (Last (Q-answer-id A))]
      [(Q-frontier-id (FrontierFresh intro F tag))
       (Q-frontier-id F)]
      [(Q-frontier-id (Emit A F))
       (Emit (Q-answer-id A) (Q-frontier-id F))]
      [(Q-frontier-id (Forced F))
       (Forced (Q-frontier-id F))])))
