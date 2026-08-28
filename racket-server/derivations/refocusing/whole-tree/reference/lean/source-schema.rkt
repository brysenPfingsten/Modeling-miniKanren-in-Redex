#lang racket

(require redex/reduction-semantics
         "./shared-host.rkt")

(provide define-lean-source)

;; The lean source relation owns 20 direct, individually named control clauses.
;; Each precise kernel contributes a similarly direct leaf relation over W;
;; context-closure lifts those leaves along the one grammatical active path.
(define-syntax-rule
  (define-lean-source
    language-id
    kernel-leaf-red-id
    kernel-initial-state-id
    kernel-open-fresh-id
    whole-runtime-support-id
    control-resume-id
    control-freeze-id
    initial-tree-id
    settled-choice-success-id
    settled-choice-alternate-id
    source-red-id)
  (begin
    (define-metafunction language-id
      whole-runtime-support-id : F -> intro
      [(whole-runtime-support-id F)
       ,(logical-vars-in (term F))])

    (define-metafunction language-id
      control-resume-id : S g -> W
      [(control-resume-id (Returned kst) g)
       (Work g kst)])

    (define-metafunction language-id
      control-freeze-id : S -> A
      [(control-freeze-id (Returned kst))
       (Answer kst)])

    (define-metafunction language-id
      initial-tree-id : g -> F
      [(initial-tree-id g)
       (More (Work g (kernel-initial-state-id)))])

    (define-metafunction language-id
      settled-choice-success-id : SC -> S
      [(settled-choice-success-id (DisjL S W)) S]
      [(settled-choice-success-id (DisjR W S)) S])

    (define-metafunction language-id
      settled-choice-alternate-id : SC -> W
      [(settled-choice-alternate-id (DisjL S W)) W]
      [(settled-choice-alternate-id (DisjR W S)) W])

    (define source-red-id
      (union-reduction-relations
       (reduction-relation
        language-id
        #:domain F

        [--> (in-hole FF (More (Returned kst)))
             (in-hole FF (Last (Answer kst)))
             "finish-success/core"]
        [--> (in-hole FF (More Dead))
             (in-hole FF Done)
             "finish-failure/core"]
        [--> (in-hole FF (More (PendingDelay W)))
             (in-hole FF (Forced (More W)))
             "force-delay/delay"]
        [--> (in-hole FF (More (DisjL S W)))
             (in-hole FF
                      (Emit (control-freeze-id S) (More W)))
             "commit-choice-answer/disj"]
        [--> (in-hole FF (More (DisjR W S)))
             (in-hole FF
                      (Emit (control-freeze-id S) (More W)))
             "commit-right-choice-answer/search-join"]

        [--> (name F_whole
                   (in-hole WF
                            (Work (fresh (x (... ...))
                                         g
                                         tag_fresh)
                                  kst)))
             (in-hole WF (Work g_new kst))
             (where intro_used
                    (whole-runtime-support-id F_whole))
             (where (OpenedFresh (u_new (... ...)) g_new)
                    (kernel-open-fresh-id
                     (x (... ...))
                     g
                     intro_used))
             "allocate-fresh/core"]
        [--> (in-hole WF (Work (conj g_1 g_2 tag) kst))
             (in-hole WF (Conj (Work g_1 kst) g_2))
             "expand-conjunction/core"]
        [--> (in-hole WF (Work (disj g_1 g_2 tag) kst))
             (in-hole WF
                      (DisjL (Work g_1 kst) (Work g_2 kst)))
             "expand-disjunction/disj"]
        [--> (in-hole WF (Work (suspend g tag) kst))
             (in-hole WF (PendingDelay (Work g kst)))
             "suspend-goal/delay"]

        [--> (in-hole WF (Conj S g))
             (in-hole WF (control-resume-id S g))
             "conj-return/core"]
        [--> (in-hole WF (Conj Dead g))
             (in-hole WF Dead)
             "conj-fail/core"]
        [--> (in-hole WF (Conj (PendingDelay W) g))
             (in-hole WF (PendingDelay (Conj W g)))
             "bubble-delay-through-conj/delay"]
        [--> (in-hole WF (Conj (DisjL S W) g))
             (in-hole WF
                      (DisjL (control-resume-id S g)
                             (Conj W g)))
             "late-distribute-settled/disj"]
        [--> (in-hole WF (Conj (DisjR W S) g))
             (in-hole WF
                      (DisjR (Conj W g)
                             (control-resume-id S g)))
             "late-distribute-right-settled/search-join"]

        [--> (in-hole WF (DisjL Dead W))
             (in-hole WF W)
             "skip-left-failure/disj"]
        [--> (in-hole WF (DisjL (PendingDelay W_1) W_2))
             (in-hole WF (PendingDelay (DisjR W_1 W_2)))
             "rail-enter-right/search-join"]
        [--> (in-hole WF (DisjL SC W_2))
             (in-hole WF
                      (DisjL
                       (settled-choice-success-id SC)
                       (DisjL
                        (settled-choice-alternate-id SC)
                        W_2)))
             "reassociate-left-result/disj"]

        [--> (in-hole WF (DisjR W Dead))
             (in-hole WF W)
             "skip-right-failure/search-join"]
        [--> (in-hole WF (DisjR W_1 (PendingDelay W_2)))
             (in-hole WF (PendingDelay (DisjL W_1 W_2)))
             "rail-return-left/search-join"]
        [--> (in-hole WF (DisjR W_1 SC))
             (in-hole WF
                      (DisjR
                       (DisjR
                        W_1
                        (settled-choice-alternate-id SC))
                       (settled-choice-success-id SC)))
             "reassociate-right-result/search-join"])
       (context-closure kernel-leaf-red-id language-id WF)))))
